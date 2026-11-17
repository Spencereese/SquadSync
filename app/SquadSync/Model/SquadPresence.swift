import Foundation

/// What the presence strip can honestly say about one member.
///
/// There is no live presence feed yet (no heartbeat table, no realtime
/// presence channel). The only real signals are the open spot call's seats
/// and the fact that the viewer has the app open. Everyone else is
/// `.unknown`, which the UI draws as a neutral ring and speaks as
/// "presence isn't tracked yet". Nothing here ever claims "online".
enum SquadPresenceStatus: Equatable, CaseIterable {
    /// Seated on a locked spot call: the squad locked in for this game.
    case locked
    /// Seated on the open spot call and marked Ready.
    case ready
    /// Seated on the open spot call, not Ready yet.
    case inSpot
    /// The viewer. Their app is open, so this one is known.
    case you
    /// No signal. Presence isn't tracked yet.
    case unknown

    /// Lower sorts first in the strip.
    var rank: Int {
        switch self {
        case .locked: 0
        case .ready: 1
        case .inSpot: 2
        case .you: 3
        case .unknown: 4
        }
    }

    /// Short visible word under the avatar. Unknown stays blank instead of guessing.
    var shortLabel: String {
        switch self {
        case .locked: "Locked in"
        case .ready: "Ready"
        case .inSpot: "In spot"
        case .you: "You"
        case .unknown: ""
        }
    }

    /// VoiceOver phrase.
    var spoken: String {
        switch self {
        case .locked: "locked in"
        case .ready: "ready"
        case .inSpot: "in the spot call"
        case .you: "you"
        case .unknown: "presence isn't tracked yet"
        }
    }
}

/// Where a game line came from. A profile default is not a claim that they are playing it.
enum SquadPresenceGameSource: Equatable {
    case spot
    case profileDefault
}

struct SquadPresenceEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let status: SquadPresenceStatus
    let game: String?
    let gameSource: SquadPresenceGameSource?
    let isOwner: Bool
    let isViewer: Bool

    var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    /// The visible game caption. A profile default reads as "Usually …".
    var gameCaption: String? {
        guard let game else { return nil }
        switch gameSource {
        case .some(.spot): return game
        case .some(.profileDefault): return "Usually \(game)"
        case .none: return game
        }
    }

    var spokenLabel: String {
        var bits = [name]
        if isOwner { bits.append("owner") }
        if status != .you { bits.append(status.spoken) }
        if isViewer && status != .you { bits.append("you") }
        if let game {
            switch gameSource {
            case .some(.spot): bits.append("spot game \(game)")
            case .some(.profileDefault), .none: bits.append("usually plays \(game)")
            }
        }
        return bits.joined(separator: ", ")
    }
}

enum SquadPresence {
    /// A seat only counts while the call is open and not past its window, or once it is locked.
    static func status(memberId: UUID, viewerId: UUID?, spot: SpotCall?, now: Date) -> SquadPresenceStatus {
        if let spot, let seat = spot.seat(for: memberId), seat.isIn {
            if spot.status == .locked { return .locked }
            if spot.status == .open, spot.closedAt == nil, !SpotCallRules.showsExpired(spot, now: now) {
                return seat.ready ? .ready : .inSpot
            }
        }
        if let viewerId, viewerId == memberId { return .you }
        return .unknown
    }

    /// Strip order: status rank (locked, ready, in spot, you, unknown), then the
    /// owner, then name (case-insensitive), then id so ties never reshuffle.
    static func entries(
        members: [SquadMemberRecord],
        ownerId: UUID?,
        viewerId: UUID?,
        spot: SpotCall?,
        now: Date
    ) -> [SquadPresenceEntry] {
        let built = members.map { member -> SquadPresenceEntry in
            let state = Self.status(memberId: member.id, viewerId: viewerId, spot: spot, now: now)
            let seated = state == .locked || state == .ready || state == .inSpot
            let fallback = member.defaultGame.trimmingCharacters(in: .whitespacesAndNewlines)
            let game: String?
            let source: SquadPresenceGameSource?
            if seated, let spot {
                game = spot.game
                source = .spot
            } else if !fallback.isEmpty {
                game = fallback
                source = .profileDefault
            } else {
                game = nil
                source = nil
            }
            let trimmedName = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return SquadPresenceEntry(
                id: member.id,
                name: trimmedName.isEmpty ? "Player" : trimmedName,
                status: state,
                game: game,
                gameSource: source,
                isOwner: member.isOwner || member.id == ownerId,
                isViewer: member.id == viewerId
            )
        }
        return built.sorted { lhs, rhs in
            if lhs.status.rank != rhs.status.rank { return lhs.status.rank < rhs.status.rank }
            if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
            let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// True when at least one member's presence is a guess the app refuses to make.
    static func hasUntracked(_ entries: [SquadPresenceEntry]) -> Bool {
        entries.contains { $0.status == .unknown }
    }
}

/// Header copy for the chat-first home.
enum SquadHeader {
    static let noSquadTitle = "SquadSync"
    static let unnamedTitle = "Your squad"

    /// The big visible name. A null or blank name falls back to "Your squad".
    static func title(name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? unnamedTitle : trimmed
    }

    static func title(squad: SquadRecord?) -> String {
        guard let squad else { return noSquadTitle }
        return title(name: squad.name)
    }

    /// The small line under the name.
    static func detail(squad: SquadRecord?, cap: Int = SpotCallRules.cap) -> String {
        guard let squad else { return "Not in a squad yet" }
        return "\(squad.members.count) of \(cap)"
    }

    /// VoiceOver and the `squad-title` identifier keep the existing "Name · n of 8" line.
    static func spoken(squad: SquadRecord?) -> String? {
        guard let squad else { return nil }
        return SquadTitle.line(name: squad.name, memberCount: squad.members.count)
    }
}

/// The voice-room pill on the home header. Voice is a mock: the pill drives
/// the in-memory `VoiceRoomService` and says so.
struct VoicePillState: Equatable {
    var joined = false
    var count = 0
    var connection: VoiceConnectionState = .idle

    static let mockTag = "mock"

    var title: String {
        switch connection {
        case .connecting: return "Voice · connecting"
        case .reconnecting: return "Voice · reconnecting"
        case .failed: return "Voice · failed"
        case .idle, .connected:
            return joined ? "In voice · \(count)" : "Voice"
        }
    }

    var spoken: String {
        let who = count == 0 ? "Nobody is in it." : (count == 1 ? "1 person is in it." : "\(count) people are in it.")
        let action = joined ? "Double tap to leave." : "Double tap to join."
        return "Voice room, mock. Nothing is sent over the network. \(who) \(action)"
    }
}
