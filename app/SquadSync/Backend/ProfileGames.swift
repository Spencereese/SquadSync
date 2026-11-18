import Foundation

/// The games-you-play list on a profile (S5). The live `sq8_profiles` has only
/// `default_game`; proposed migration 0023 adds `games text[]`. Until it's applied the
/// list is kept on this phone and the profile step says so.
struct ProfileGames: Equatable {
    var games: [String]
    var home: GamesHome
}

protocol ProfileGamesServing: AnyObject {
    /// Throws only when the server can't be reached or refuses for another reason.
    func load(userId: UUID) async throws -> ProfileGames
    /// Saves where `load` found a home. Returns where it went.
    @discardableResult
    func save(userId: UUID, games: [String]) async throws -> GamesHome
}

/// Per-account games list in UserDefaults, for servers without the column.
struct LocalGamesStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ userId: UUID) -> String { "sq8.profile.games.\(userId.uuidString.lowercased())" }

    func load(_ userId: UUID) -> [String] { defaults.stringArray(forKey: key(userId)) ?? [] }

    func save(_ userId: UUID, games: [String]) { defaults.set(games, forKey: key(userId)) }
}

final class SupabaseProfileGames: ProfileGamesServing {
    private let http: SupabaseHTTP
    private let local: LocalGamesStore
    private var home: GamesHome?

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared,
        local: LocalGamesStore = LocalGamesStore()
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
        self.local = local
    }

    /// Reads your own profile row with `select=*`, so a server without 0023's
    /// `games` column answers normally instead of failing with 42703 (which the
    /// logs report as an error). The row's keys say where the list lives.
    func load(userId: UUID) async throws -> ProfileGames {
        do {
            let data = try await http.send(
                path: "rest/v1/sq8_profiles",
                method: "GET",
                query: [
                    URLQueryItem(name: "id", value: "eq.\(userId.uuidString)"),
                    URLQueryItem(name: "select", value: "*")
                ],
                feature: .profile
            )
            guard let found = Self.serverGames(in: data) else {
                home = .phone
                return ProfileGames(games: local.load(userId), home: .phone)
            }
            home = .server
            return ProfileGames(games: found, home: .server)
        } catch let failure as BackendFailure {
            guard Self.columnMissing(failure) else { throw failure }
            home = .phone
            return ProfileGames(games: local.load(userId), home: .phone)
        }
    }

    /// The server's list when the profile row has a `games` key (null reads as
    /// empty). Nil when the key is missing (0023 not applied) or no row came back,
    /// so the list stays on this phone.
    static func serverGames(in data: Data) -> [String]? {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let row = rows.first, row.keys.contains("games") else { return nil }
        return (row["games"] as? [Any])?.compactMap { $0 as? String } ?? []
    }

    func save(userId: UUID, games: [String]) async throws -> GamesHome {
        let target: GamesHome
        if let home { target = home } else { target = try await load(userId: userId).home }
        switch target {
        case .phone:
            local.save(userId, games: games)
        case .server:
            let body = try JSONEncoder().encode(GamesRow(games: games))
            _ = try await http.send(
                path: "rest/v1/sq8_profiles",
                method: "PATCH",
                query: [URLQueryItem(name: "id", value: "eq.\(userId.uuidString)")],
                body: body,
                prefer: "return=minimal",
                feature: .profile
            )
        }
        return target
    }

    /// 42703 / PGRST204 / "column ... does not exist" means 0023 isn't applied.
    static func columnMissing(_ failure: BackendFailure) -> Bool {
        guard case .rejected(let message) = failure else { return false }
        let text = message.lowercased()
        if text.contains("42703") || text.contains("pgrst204") { return true }
        return text.contains("column") && (text.contains("does not exist") || text.contains("could not find"))
    }

    private struct GamesRow: Codable {
        let games: [String]?
    }
}

/// Mock games: like live today (no column, so the phone keeps it) unless told otherwise.
@MainActor
final class MockProfileGames: ProfileGamesServing {
    var home: GamesHome
    var stored: [UUID: [String]] = [:]
    var loadsDown: Bool
    var savesDown: Bool

    init(home: GamesHome = .phone, loadsDown: Bool = false, savesDown: Bool = false) {
        self.home = home
        self.loadsDown = loadsDown
        self.savesDown = savesDown
    }

    func load(userId: UUID) async throws -> ProfileGames {
        if loadsDown { throw BackendFailure.reconnecting }
        return ProfileGames(games: stored[userId] ?? [], home: home)
    }

    func save(userId: UUID, games: [String]) async throws -> GamesHome {
        if savesDown { throw BackendFailure.reconnecting }
        stored[userId] = games
        return home
    }
}
