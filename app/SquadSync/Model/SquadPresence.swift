import Foundation

/// What the presence strip can honestly say about one member.
///
/// There is no heartbeat or "online" feed. The real signals are the open spot
/// call's seats, the member's own check-in (`sq8_check_ins`, honor system; see
/// `WhosIn.swift`), and the fact that the viewer has the app open. Without
/// check-ins on the server everyone else is `.unknown` ("presence isn't tracked
/// yet"); with them, a member who hasn't checked in is `.notCheckedIn`.
/// Nothing here ever claims "online".
enum SquadPresenceStatus: Equatable, CaseIterable {
    /// Seated on a locked spot call: the squad locked in for this game.
    case locked
    /// Seated on the open spot call. Joining means ready, so there is no separate Ready state.
    case inSpot
    /// Checked in as on now, inside the 60-minute window.
    case availableNow
    /// Checked in for a later time.
    case later
    /// Checked in as can't play.
    case cantPlay
    /// The viewer. Their app is open, so this one is known.
    case you
    /// Check-ins are on the server, and this member hasn't checked in.
    case notCheckedIn
    /// No signal. Presence isn't tracked yet.
    case unknown

    /// Lower sorts first in the strip.
    var rank: Int {
        switch self {
        case .locked: 0
        case .inSpot: 2
        case .availableNow: 3
        case .later: 4
        case .you: 5
        case .notCheckedIn: 6
        case .unknown: 7
        case .cantPlay: 8
        }
    }

    /// Short visible word under the avatar. Unknown stays blank instead of guessing.
    var shortLabel: String {
        switch self {
        case .locked: "Locked in"
        case .inSpot: "In spot"
        case .availableNow: "On now"
        case .later: "Later"
        case .cantPlay: "Can't play"
        case .you: "You"
        case .notCheckedIn, .unknown: ""
        }
    }

    /// VoiceOver phrase.
    var spoken: String {
        switch self {
        case .locked: "locked in"
        case .inSpot: "in the spot call"
        case .availableNow: "on now, from their check-in"
        case .later: "on later, from their check-in"
        case .cantPlay: "can't play, from their check-in"
        case .you: "you"
        case .notCheckedIn: "hasn't checked in"
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

    /// The visible game caption: just the game, so it fits under a 72-point avatar.
    /// A profile default is drawn muted (`gameIsGuess`) and spoken as "usually plays",
    /// so the short caption still never claims they are playing it now.
    var gameCaption: String? { game }

    /// True when the game line is only the profile default, not a live seat.
    var gameIsGuess: Bool { gameSource != .some(.spot) }

    /// Always identifies the viewer, seated or not. A display name of "You" is not repeated.
    var spokenLabel: String {
        var bits = [name]
        if isViewer && name.lowercased() != "you" { bits.append("you") }
        if isOwner { bits.append("owner") }
        if status != .you { bits.append(status.spoken) }
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
    /// After the seat, the check-in decides, when the server has check-ins.
    static func status(
        memberId: UUID,
        viewerId: UUID?,
        spot: SpotCall?,
        now: Date,
        availability: WhosInAvailability? = nil
    ) -> SquadPresenceStatus {
        if let spot, let seat = spot.seat(for: memberId), seat.isIn {
            if spot.status == .locked { return .locked }
            if spot.status == .open, spot.closedAt == nil, !SpotCallRules.showsExpired(spot, now: now) {
                return .inSpot
            }
        }
        let isViewer = viewerId != nil && viewerId == memberId
        if let availability { return status(for: availability, isViewer: isViewer) }
        return isViewer ? .you : .unknown
    }

    /// A check-in's status. The viewer without a check-in stays "you".
    static func status(for availability: WhosInAvailability, isViewer: Bool) -> SquadPresenceStatus {
        switch availability {
        case .now: return .availableNow
        case .later: return .later
        case .cantPlay: return .cantPlay
        case .notCheckedIn: return isViewer ? .you : .notCheckedIn
        case .untracked: return isViewer ? .you : .unknown
        }
    }

    /// Strip order: status rank (locked, in spot, you, unknown), then the
    /// owner, then name (case-insensitive), then id so ties never reshuffle.
    static func entries(
        members: [SquadMemberRecord],
        ownerId: UUID?,
        viewerId: UUID?,
        spot: SpotCall?,
        now: Date,
        availability: [UUID: WhosInAvailability]? = nil
    ) -> [SquadPresenceEntry] {
        let built = members.map { member -> SquadPresenceEntry in
            // nil map: the server has no check-ins. A map: a missing member hasn't checked in.
            let checkIn = availability.map { $0[member.id] ?? .notCheckedIn }
            let state = Self.status(memberId: member.id, viewerId: viewerId, spot: spot, now: now, availability: checkIn)
            let seated = state == .locked || state == .inSpot
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

    /// Visible pill text. Short so it fits beside two avatars at the default size.
    static let untrackedShort = "Presence not live"
    /// Spoken and the full-width line in the large-text roster.
    static let untrackedSpoken = "Presence isn't live yet"

    /// True when at least one member's presence is a guess the app refuses to make.
    static func hasUntracked(_ entries: [SquadPresenceEntry]) -> Bool {
        entries.contains { $0.status == .unknown }
    }

    /// Members who are on: checked in as on now, or seated on the spot call.
    static func onCount(_ entries: [SquadPresenceEntry]) -> Int {
        entries.filter { [.availableNow, .inSpot, .locked].contains($0.status) }.count
    }

    /// The strip's entry to the who's-in sheet: a count when anyone is on.
    static func whosInPill(_ entries: [SquadPresenceEntry]) -> String {
        let on = onCount(entries)
        return on > 0 ? "Who's in · \(on)" : "Who's in"
    }

    static func whosInSpoken(_ entries: [SquadPresenceEntry]) -> String {
        let on = onCount(entries)
        return on > 0 ? "Who's in, \(on) on" : "Who's in"
    }

    /// Row counts the large-text roster tries, longest first: everyone, then 4, 2, 1,
    /// and 0 (voice pill, "N more", and the untracked line). It shows the first that
    /// fits and folds the rest into "N more", so it never needs to scroll.
    /// Always five values so the view can lay out a fixed set of tries.
    static func rosterLimits(count: Int) -> [Int] {
        let all = max(0, count)
        return [all, min(all, 4), min(all, 2), min(all, 1), 0]
    }

    static func moreLabel(_ hidden: Int) -> String {
        hidden == 1 ? "1 more in Who's in" : "\(hidden) more in Who's in"
    }
}

/// Header copy for the chat-first home.
enum SquadHeader {
    static let noSquadTitle = "SquadSync"
    static let unnamedTitle = "Your group"

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
        guard let squad else { return "Not in a group yet" }
        return "\(squad.members.count) of \(cap)"
    }

    /// VoiceOver and the `squad-title` identifier keep the existing "Name · n of 8" line.
    static func spoken(squad: SquadRecord?) -> String? {
        guard let squad else { return nil }
        return SquadTitle.line(name: squad.name, memberCount: squad.members.count)
    }
}

/// The voice-room pill on the home header. With the mock backend it drives the
/// in-memory `VoiceRoomService` and says it's a mock. With the live backend
/// (`live` set) it shows the squad's real voice room (`SquadVoiceState`) and
/// opens the voice sheet; it never claims a connection that didn't happen.
struct VoicePillState: Equatable {
    var joined = false
    var count = 0
    var connection: VoiceConnectionState = .idle
    /// The live squad room. Nil with the mock backend.
    var live: SquadVoiceState?

    static let mockTag = "mock"

    /// In the room (live or mock), for the pill's icon and tint.
    var isIn: Bool { live?.joined ?? joined }

    var title: String {
        if let live { return live.pillTitle }
        switch connection {
        case .connecting: return "Voice · connecting"
        case .reconnecting: return "Voice · reconnecting"
        case .failed: return "Voice · failed"
        case .idle, .connected:
            return joined ? "In voice · \(count)" : "Voice"
        }
    }

    var spoken: String {
        if let live { return live.pillSpoken }
        let who = count == 0 ? "Nobody is in it." : (count == 1 ? "1 person is in it." : "\(count) people are in it.")
        let action = joined ? "Double tap to leave." : "Double tap to join."
        return "Voice room, mock. Nothing is sent over the network. \(who) \(action)"
    }
}
