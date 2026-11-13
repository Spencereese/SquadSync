import Foundation

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
              let exp = json["exp"] as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: exp.doubleValue)
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
