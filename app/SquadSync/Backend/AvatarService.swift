import Foundation

/// Profile photos in the live `avatars` bucket: public read, and each user can
/// only write inside their own folder (`<uid>/...`). One file per person,
/// overwritten on change, so there's nothing to clean up and no table column.
protocol AvatarServing: AnyObject {
    /// The public URL if this person has a photo, nil if not. Throws `notSetUp(.avatars)`
    /// when the bucket isn't there.
    func photoURL(userId: UUID) async throws -> URL?
    func upload(userId: UUID, jpeg: Data) async throws -> URL
}

enum AvatarPath {
    static let bucket = "avatars"
    static let maxBytes = 2 * 1024 * 1024

    static func object(userId: UUID) -> String {
        "\(userId.uuidString.lowercased())/sq8-avatar.jpg"
    }

    static func publicURL(base: URL, userId: UUID, version: Date? = nil) -> URL {
        var url = base
        for part in ["storage", "v1", "object", "public", bucket] { url.appendPathComponent(part) }
        for part in object(userId: userId).split(separator: "/") { url.appendPathComponent(String(part)) }
        guard let version else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: String(Int(version.timeIntervalSince1970)))]
        return components?.url ?? url
    }

    static func isMissingBucket(_ text: String) -> Bool {
        text.lowercased().contains("bucket not found")
    }
}

final class SupabaseAvatarService: AvatarServing {
    private let http: SupabaseHTTP
    private let config: BackendConfig

    init(config: BackendConfig, accessToken: String, refresher: TokenRefreshing? = nil, transport: HTTPTransport = URLSessionTransport.shared) {
        self.config = config
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
    }

    /// One list call in your own folder: is the file there?
    func photoURL(userId: UUID) async throws -> URL? {
        guard let base = config.url else { throw BackendFailure.notConfigured }
        let body = try JSONSerialization.data(withJSONObject: [
            "prefix": userId.uuidString.lowercased(),
            "search": "sq8-avatar.jpg",
            "limit": 1
        ])
        let data: Data
        do {
            data = try await http.send(path: "storage/v1/object/list/\(AvatarPath.bucket)", method: "POST", body: body, feature: .avatars, probe: true)
        } catch let failure as BackendFailure {
            if case .rejected(let text) = failure, AvatarPath.isMissingBucket(text) { throw BackendFailure.notSetUp(.avatars) }
            throw failure
        }
        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        guard let row = rows.first(where: { ($0["name"] as? String) == "sq8-avatar.jpg" }) else { return nil }
        let stamp = (row["updated_at"] as? String).flatMap(BackendJSON.parse)
        return AvatarPath.publicURL(base: base, userId: userId, version: stamp)
    }

    func upload(userId: UUID, jpeg: Data) async throws -> URL {
        guard let base = config.url else { throw BackendFailure.notConfigured }
        do {
            _ = try await http.send(
                path: "storage/v1/object/\(AvatarPath.bucket)/\(AvatarPath.object(userId: userId))",
                method: "POST",
                body: jpeg,
                feature: .avatars,
                contentType: "image/jpeg",
                headers: ["x-upsert": "true", "cache-control": "60"]
            )
        } catch let failure as BackendFailure {
            if case .rejected(let text) = failure, AvatarPath.isMissingBucket(text) { throw BackendFailure.notSetUp(.avatars) }
            throw failure
        }
        return AvatarPath.publicURL(base: base, userId: userId, version: Date())
    }
}

final class MockAvatarService: AvatarServing {
    var photos: [UUID: URL] = [:]
    var bucketMissing: Bool
    var uploadsDown: Bool
    private(set) var uploads = 0

    init(bucketMissing: Bool = false, uploadsDown: Bool = false) {
        self.bucketMissing = bucketMissing
        self.uploadsDown = uploadsDown
    }

    func photoURL(userId: UUID) async throws -> URL? {
        if bucketMissing { throw BackendFailure.notSetUp(.avatars) }
        return photos[userId]
    }

    func upload(userId: UUID, jpeg: Data) async throws -> URL {
        if bucketMissing { throw BackendFailure.notSetUp(.avatars) }
        if uploadsDown { throw BackendFailure.reconnecting }
        uploads += 1
        let url = URL(string: "https://example.invalid/avatars/\(AvatarPath.object(userId: userId))?v=\(uploads)")!
        photos[userId] = url
        return url
    }
}
