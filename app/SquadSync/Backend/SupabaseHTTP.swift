import Foundation

struct SupabaseHTTP {
    let config: BackendConfig
    var accessToken: String?

    func send(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        prefer: String? = nil,
        feature: BackendFeature
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
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BackendFailure.rejected(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw BackendFailure.rejected("No HTTP response.")
        }
        if http.statusCode == 409 { return data }
        if http.statusCode >= 200 && http.statusCode < 300 { return data }
        if isMissing(data, status: http.statusCode) {
            throw BackendFailure.notSetUp(feature)
        }
        throw BackendFailure.rejected(message(from: data) ?? "Request failed (\(http.statusCode)).")
    }

    private func isMissing(_ data: Data, status: Int) -> Bool {
        guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data) else {
            return status == 404
        }
        if body.code == "PGRST205" || body.code == "42P01" { return true }
        let text = (body.message ?? "").lowercased()
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
