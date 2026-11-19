import Foundation

/// The games-you-play list on a profile (S5). Migration 0023 (live since PR36)
/// adds `sq8_profiles.games text[]` beside `default_game`. On a server without
/// it the list is kept on this phone and the profile says so.
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

    /// Reads `games` from your own row by name. Only a real missing-column
    /// answer (42703 / PGRST204) moves the list to this phone, and that answer is
    /// logged at info. Success means the column is there even when no row comes
    /// back yet. Any other failure throws and nothing is remembered.
    func load(userId: UUID) async throws -> ProfileGames {
        do {
            let data = try await http.send(
                path: "rest/v1/sq8_profiles",
                method: "GET",
                query: [
                    URLQueryItem(name: "id", value: "eq.\(userId.uuidString)"),
                    URLQueryItem(name: "select", value: "games")
                ],
                feature: .profile,
                probe: true
            )
            home = .server
            let rows = (try? JSONDecoder().decode([GamesRow].self, from: data)) ?? []
            return ProfileGames(games: rows.first?.games ?? [], home: .server)
        } catch let failure as BackendFailure {
            guard Self.columnMissing(failure) else { throw failure }
            home = .phone
            return ProfileGames(games: local.load(userId), home: .phone)
        }
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
        MissingColumn.matches(failure)
    }

    private struct GamesRow: Codable {
        let games: [String]?
    }
}

/// Mock games: kept "on the phone" (a server without 0023) unless told otherwise,
/// so the phone-only note stays covered. Live has the column since PR36.
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
        #if DEBUG
        if NetworkFault.shared.isOffline { throw BackendFailure.reconnecting }
        #endif
        return ProfileGames(games: stored[userId] ?? [], home: home)
    }

    func save(userId: UUID, games: [String]) async throws -> GamesHome {
        if savesDown { throw BackendFailure.reconnecting }
        #if DEBUG
        if NetworkFault.shared.isOffline { throw BackendFailure.reconnecting }
        #endif
        stored[userId] = games
        return home
    }
}
