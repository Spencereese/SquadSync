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
        if DebugSendFailures.failIfNeeded(request) {
            throw URLError(.networkConnectionLost)
        }
        return try await session.data(for: request)
    }
}

enum DebugSendFailures {
    private static var remaining: Int = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-debug-fail-sends"),
              arguments.index(after: index) < arguments.endIndex,
              let count = Int(arguments[arguments.index(after: index)]),
              count > 0 else { return 0 }
        return count
        #else
        return 0
        #endif
    }()

    /// True when this message insert should fail. Later sends succeed.
    static func failIfNeeded(_ request: URLRequest) -> Bool {
        #if DEBUG
        guard remaining > 0 else { return false }
        let path = request.url?.path ?? ""
        guard request.httpMethod == "POST", path.hasSuffix("sq8_messages") else { return false }
        remaining -= 1
        return true
        #else
        return false
        #endif
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

/// 42703 / PGRST204 / "column ... does not exist" / "could not find the ...
/// column": the server answered that a column isn't there. Nothing else counts.
enum MissingColumn {
    static func matches(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("42703") || lower.contains("pgrst204") { return true }
        return lower.contains("column") && (lower.contains("does not exist") || lower.contains("could not find"))
    }

    static func matches(_ failure: BackendFailure) -> Bool {
        guard case .rejected(let message) = failure else { return false }
        return matches(message)
    }
}

enum HTTPFailureLog {
    /// A capability GET is supposed to fail this way. The function is there; the read-only transaction stopped the write.
    static func isExpectedProbeRefusal(status: Int, body: Data) -> Bool {
        guard status == 405 else { return false }
        let text = String(data: body, encoding: .utf8)?.lowercased() ?? ""
        return text.contains("read-only transaction") || text.contains("read only transaction")
    }

    enum Level: Equatable { case info, error }

    /// A request marked `probe` asks the server whether something exists, so an
    /// "isn't there" answer (missing column, function, or table) is information,
    /// not a failure; so is the read-only refusal above. Anything else, probe or
    /// not (a 500, a permission error), is still an error.
    static func level(status: Int, body: Data, probe: Bool) -> Level {
        if isExpectedProbeRefusal(status: status, body: body) { return .info }
        if probe && isAbsenceAnswer(status: status, body: body) { return .info }
        return .error
    }

    static func isAbsenceAnswer(status: Int, body: Data) -> Bool {
        if status == 404 { return true }
        let text = (String(data: body, encoding: .utf8) ?? "").lowercased()
        return MissingColumn.matches(text)
            || text.contains("pgrst202") || text.contains("pgrst205") || text.contains("42p01")
            || text.contains("could not find the function") || text.contains("could not find the table")
    }

    /// `optional` marks a real call to a function the server may not have yet
    /// (FunctionPresence). Its absence answer is information, like a probe's.
    static func record(method: String, path: String, status: Int, body: Data, probe: Bool = false, optional: Bool = false) {
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
        let tag = probe ? "probe " : optional ? "optional " : ""
        let text = "\(tag)HTTP \(method) \(path) \(status) \(code) \(message)"
        if level(status: status, body: body, probe: probe || optional) == .info {
            SquadLog.http.info("\(text, privacy: .public)")
        } else {
            SquadLog.http.error("\(text, privacy: .public)")
        }
        #endif
    }
}

/// Session memory for server functions that may not be deployed or migrated
/// yet. Nothing probes them: a function is assumed present, called only for a
/// real action, and a 404 or PGRST202 answer marks it missing until relaunch,
/// so it is asked (and logged, at info) once. No fake or null arguments are
/// ever sent to find out.
final class FunctionPresence: @unchecked Sendable {
    static let shared = FunctionPresence()

    static let leaveSquad = "sq8_leave_squad"
    static let renameSquad = "sq8_rename_squad"
    static let steamPresence = "sq8-steam-presence"
    static let registerDeviceToken = "sq8_register_device_token"
    static let unregisterDeviceToken = "sq8_unregister_device_token"

    private let lock = NSLock()
    private var missing: Set<String> = []

    init() {}

    func isMissing(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return missing.contains(name)
    }

    func markMissing(_ name: String) {
        lock.lock(); defer { lock.unlock() }
        missing.insert(name)
    }

    /// Sign-out: the next account may be on a server that has it.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        missing.removeAll()
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
        allowRefresh: Bool = true,
        probe: Bool = false,
        optional: Bool = false
    ) async throws -> Data {
        guard config.isConfigured, let base = config.url else { throw BackendFailure.notConfigured }
        var url = base
        for part in path.split(separator: "/") where !part.isEmpty {
            url.appendPathComponent(String(part))
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
            // URLComponents leaves "+" alone and servers read it as a space, which
            // breaks timestamps like "+00:00". Encode it.
            let encoded = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            components?.percentEncodedQuery = encoded
        }
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
            body: data,
            probe: probe,
            optional: optional
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
                    allowRefresh: false,
                    probe: probe,
                    optional: optional
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
        encoder.outputFormatting = .sortedKeys
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
