import Foundation
import os

struct URLSessionTransport: HTTPTransport {
    /// Kept off `URLSession.shared` so a websocket cancel cannot abort an insert.
    static let shared: URLSessionTransport = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        return URLSessionTransport(session: URLSession(configuration: configuration))
    }()

    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

enum AccessTokenClock {
    /// Refresh while the access token still has a minute left, and after it has expired.
    static let leadTime: TimeInterval = 60

    static func needsRefresh(_ token: String, now: Date) -> Bool {
        guard let exp = expiry(of: token) else { return true }
        return exp.timeIntervalSince(now) <= leadTime
    }

    /// Rewrites the `exp` claim to the past. The signature is left as-is; refresh uses the refresh token, not this access token.
    static func replacingExpiry(_ token: String, exp: Date) -> String {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              var payload = jsonObject(from: String(parts[1])) else {
            return unsignedToken(exp: exp)
        }
        payload["exp"] = Int(exp.timeIntervalSince1970)
        let encoded = base64URL(json(payload))
        let signature = parts.count >= 3 ? String(parts[2]) : "sig"
        return "\(parts[0]).\(encoded).\(signature)"
    }

    private static func unsignedToken(exp: Date) -> String {
        let header = base64URL("{\"alg\":\"none\"}")
        let payload = base64URL("{\"exp\":\(Int(exp.timeIntervalSince1970))}")
        return "\(header).\(payload).sig"
    }

    private static func jsonObject(from encoded: String) -> [String: Any]? {
        guard let data = base64Data(from: encoded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private static func base64Data(from encoded: String) -> Data? {
        var payload = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 { payload += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: payload)
    }

    private static func base64URL(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func expiry(of token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 { payload += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = Self.unixSeconds(json["exp"]) else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// JWT `exp` is unix seconds. A value that only makes sense as milliseconds is scaled down.
    private static func unixSeconds(_ value: Any?) -> TimeInterval? {
        let raw: TimeInterval?
        if let number = value as? NSNumber {
            raw = number.doubleValue
        } else if let text = value as? String, let number = TimeInterval(text) {
            raw = number
        } else {
            raw = nil
        }
        guard let raw else { return nil }
        if raw > 10_000_000_000 { return raw / 1000 }
        return raw
    }
}

enum SquadLog {
    static let http = Logger(subsystem: "com.spencereese.squadsync", category: "http")
}

enum RefreshRejection {
    /// Clear only when the token endpoint names this refresh token as refused.
    /// Other 400s, 5xx, and network errors keep the saved session.
    static func clearsSession(status: Int, body: Data) -> Bool {
        guard status == 400 || status == 401 else { return false }
        let text = String(data: body, encoding: .utf8)?.lowercased() ?? ""
        let codes = [
            "invalid_grant",
            "refresh_token_not_found",
            "refresh_token_already_used",
            "session_not_found"
        ]
        return codes.contains { text.contains($0) }
    }
}

enum HTTPFailureLog {
    static func record(method: String, path: String, status: Int, body: Data) {
        #if DEBUG
        let fields = (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
        let code = (fields["error_code"] as? String)
            ?? (fields["error"] as? String)
            ?? (fields["code"] as? String)
            ?? "-"
        let message = (fields["msg"] as? String)
            ?? (fields["error_description"] as? String)
            ?? (fields["message"] as? String)
            ?? "-"
        SquadLog.http.error("HTTP \(method, privacy: .public) \(path, privacy: .public) \(status, privacy: .public) \(code, privacy: .public) \(message, privacy: .public)")
        #endif
    }
}

enum AuthFailure {
    static func matches(status: Int, body: Data) -> Bool {
        guard status >= 400 else { return false }
        if status == 401 { return true }
        let raw = String(data: body, encoding: .utf8)?.lowercased() ?? ""
        return mentionsJWT(raw)
    }

    static func mentionsJWT(_ message: String) -> Bool {
        let text = message.lowercased()
        return text.contains("jwt expired") || text.contains("invalid jwt")
    }
}

struct SupabaseHTTP {
    let config: BackendConfig
    var accessToken: String?
    var transport: HTTPTransport = URLSessionTransport.shared
    var refresher: TokenRefreshing?

    func send(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        prefer: String? = nil,
        feature: BackendFeature,
        allowRefresh: Bool = true
    ) async throws -> Data {
        guard config.isConfigured, let base = config.url else { throw BackendFailure.notConfigured }
        var url = base
        for part in path.split(separator: "/") where !part.isEmpty {
            url.appendPathComponent(String(part))
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw BackendFailure.rejected("Bad request URL.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let bearer = accessToken ?? config.anonKey
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            if RequestNoise.isCancellation(error) { throw error }
            throw BackendFailure.reconnecting
        }
        guard let http = response as? HTTPURLResponse else {
            throw BackendFailure.rejected("No HTTP response.")
        }
        if http.statusCode == 409 { return data }
        if http.statusCode >= 200 && http.statusCode < 300 { return data }
        HTTPFailureLog.record(
            method: request.httpMethod ?? method,
            path: request.url?.path ?? path,
            status: http.statusCode,
            body: data
        )
        if allowRefresh, accessToken != nil, AuthFailure.matches(status: http.statusCode, body: data) {
            guard let refresher else {
                throw BackendFailure.rejected(message(from: data) ?? "JWT expired")
            }
            switch await refresher.refreshAfterRejection() {
            case .refreshed(let token):
                var retry = self
                retry.accessToken = token
                return try await retry.send(
                    path: path,
                    method: method,
                    query: query,
                    body: body,
                    prefer: prefer,
                    feature: feature,
                    allowRefresh: false
                )
            case .rejected:
                throw BackendFailure.sessionEnded
            case .unreachable:
                throw BackendFailure.reconnecting
            }
        }
        if isMissing(data, status: http.statusCode) {
            throw BackendFailure.notSetUp(feature)
        }
        throw BackendFailure.rejected(message(from: data) ?? "Request failed (\(http.statusCode)).")
    }

    private func isMissing(_ data: Data, status: Int) -> Bool {
        guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data) else {
            return status == 404
        }
        if body.code == "PGRST204" { return false }
        if body.code == "PGRST205" || body.code == "42P01" { return true }
        let text = (body.message ?? "").lowercased()
        if text.contains("could not find the") && text.contains("column") { return false }
        return text.contains("could not find the table") || text.contains("schema cache")
    }

    private func message(from data: Data) -> String? {
        (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message
            ?? (try? JSONDecoder().decode(AuthErrorBody.self, from: data))?.best
    }

    private struct ErrorBody: Decodable {
        let code: String?
        let message: String?
    }

    private struct AuthErrorBody: Decodable {
        let errorDescription: String?
        let msg: String?
        let message: String?
        var best: String? { errorDescription ?? message ?? msg }
        enum CodingKeys: String, CodingKey {
            case errorDescription = "error_description"
            case msg
            case message
        }
    }
}

enum BackendJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = BackendJSON.parse(text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: text)
        }
        return decoder
    }()

    static func parse(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }

    static func parseStamp(_ date: Date) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
