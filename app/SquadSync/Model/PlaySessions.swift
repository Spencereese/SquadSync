import Foundation

// Play sessions: a member schedules a time to play inside the squad, everyone
// answers In or Out, and the session shows up in the chat as a card and above
// the chat while it's coming up. Rules, times and copy live here (Foundation
// only, so the Linux harness runs them); the views only draw them.
//
// Server: 0016 (`sq8_sessions`, `sq8_session_rsvps`, live since Nov 18, 2026).
// 0025 adds guards but isn't needed for any of this to work.

/// An RSVP. 0016 also allows `maybe`; the app only writes In and Out, and shows
/// a stored maybe as no answer.
enum PlaySessionResponse: String, Equatable, Codable {
    case going = "in"
    case out
    case maybe
}

struct PlaySessionRSVP: Equatable, Identifiable {
    let userId: UUID
    var response: PlaySessionResponse
    var updatedAt: Date?

    var id: UUID { userId }
}

struct PlaySession: Equatable, Identifiable {
    let id: UUID
    let squadId: UUID
    let creatorId: UUID
    var game: String
    var startsAt: Date
    /// 0016 allows 15–1440 minutes or none. The app doesn't set one yet.
    var durationMinutes: Int?
    var note: String?
    var cancelledAt: Date?
    var createdAt: Date
    var rsvps: [PlaySessionRSVP]

    func response(of userId: UUID?) -> PlaySessionResponse? {
        guard let userId else { return nil }
        return rsvps.first { $0.userId == userId }?.response
    }
}

enum PlaySessionPhase: Equatable {
    case upcoming
    case live
    case over
    case cancelled
}

enum PlaySessionRules {
    /// Without a stored duration a session counts as on for two hours after it
    /// starts. 0025's RSVP guard uses the same window.
    static let defaultLength: TimeInterval = 2 * 60 * 60
    static let maxGameLength = 60
    static let maxNoteLength = 280
    /// A time a few minutes ago is still fine (the form was open a while).
    static let pastGrace: TimeInterval = 5 * 60
    static let horizon: TimeInterval = 60 * 24 * 60 * 60
    /// How far back the read goes: cards for sessions that started in the last
    /// two weeks stay in the chat. Older ones drop off.
    static let readWindow: TimeInterval = 14 * 24 * 60 * 60
    static let readLimit = 50

    static func endsAt(_ session: PlaySession) -> Date {
        let length = session.durationMinutes.map { TimeInterval($0) * 60 } ?? defaultLength
        return session.startsAt.addingTimeInterval(length)
    }

    static func phase(_ session: PlaySession, now: Date) -> PlaySessionPhase {
        if session.cancelledAt != nil { return .cancelled }
        if now >= endsAt(session) { return .over }
        if now >= session.startsAt { return .live }
        return .upcoming
    }

    /// Still worth showing above the chat: not cancelled and not over. Soonest first.
    static func upcoming(_ sessions: [PlaySession], now: Date) -> [PlaySession] {
        sessions
            .filter { phase($0, now: now) == .upcoming || phase($0, now: now) == .live }
            .sorted { lhs, rhs in
                if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// Cancelled or over: the card is muted and has no buttons.
    static func isDone(_ session: PlaySession, now: Date) -> Bool {
        let current = phase(session, now: now)
        return current == .cancelled || current == .over
    }

    static func canRespond(_ session: PlaySession, now: Date) -> Bool {
        !isDone(session, now: now)
    }

    /// Only the person who scheduled it, and only while it isn't done.
    static func canCancel(_ session: PlaySession, viewerId: UUID?, now: Date) -> Bool {
        guard let viewerId, session.creatorId == viewerId else { return false }
        return !isDone(session, now: now)
    }

    /// Your answer on this phone right away, before the server confirms it.
    static func setting(_ response: PlaySessionResponse, for userId: UUID, in session: PlaySession, at now: Date) -> PlaySession {
        var copy = session
        if let index = copy.rsvps.firstIndex(where: { $0.userId == userId }) {
            copy.rsvps[index].response = response
            copy.rsvps[index].updatedAt = now
        } else {
            copy.rsvps.append(PlaySessionRSVP(userId: userId, response: response, updatedAt: now))
        }
        return copy
    }

    /// Puts one session back into the list (a new one, or a fresher copy).
    static func replacing(_ session: PlaySession, in sessions: [PlaySession]) -> [PlaySession] {
        var copy = sessions
        if let index = copy.firstIndex(where: { $0.id == session.id }) {
            copy[index] = session
        } else {
            copy.append(session)
        }
        return copy.sorted { lhs, rhs in
            if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

/// Who's in and who's out, by name, for the card. Only people still in the
/// squad count; you come first as "You", then everyone else by name.
struct PlaySessionRoster: Equatable {
    var going: [String]
    var out: [String]
    var viewerResponse: PlaySessionResponse?

    static func make(_ session: PlaySession, members: [SquadMemberRecord], viewerId: UUID?) -> PlaySessionRoster {
        let names = Dictionary(members.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        func label(_ id: UUID) -> String {
            if id == viewerId { return ChatThread.you }
            let name = names[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? ChatThread.unknownSender : name
        }
        func ordered(_ ids: [UUID]) -> [String] {
            let mine = ids.filter { $0 == viewerId }.map(label)
            let rest = ids.filter { $0 != viewerId }.map(label).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            return mine + rest
        }
        let current = session.rsvps.filter { names[$0.userId] != nil }
        return PlaySessionRoster(
            going: ordered(current.filter { $0.response == .going }.map(\.userId)),
            out: ordered(current.filter { $0.response == .out }.map(\.userId)),
            viewerResponse: session.response(of: viewerId).flatMap { $0 == .maybe ? nil : $0 }
        )
    }

    /// "3 in · 1 out", "2 in", "1 out", or "No answers yet".
    var summary: String {
        var parts: [String] = []
        if !going.isEmpty { parts.append("\(going.count) in") }
        if !out.isEmpty { parts.append("\(out.count) out") }
        return parts.isEmpty ? PlaySessionCopy.noAnswers : parts.joined(separator: " · ")
    }

    /// "You, Alex and Jordan", for a line of names.
    static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        }
    }
}

/// Times in the person's own zone: "Tonight 8:00 PM", "Tomorrow 7:30 PM",
/// "Saturday 8:00 PM", "Sat, Dec 12, 8:00 PM". The clock's calendar and locale
/// are injected so tests don't depend on the device.
enum PlaySessionTime {
    /// From 5 PM on, today is "Tonight".
    static let eveningHour = 17

    static func label(_ start: Date, now: Date, clock: ChatClock) -> String {
        let calendar = clock.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: start)).day ?? 0
        let time = clock.time(start)
        switch days {
        case 0:
            return calendar.component(.hour, from: start) >= eveningHour ? "Tonight \(time)" : "Today \(time)"
        case 1:
            return "Tomorrow \(time)"
        case -1:
            return "Yesterday \(time)"
        case 2...6:
            return "\(format(start, template: "EEEE", clock: clock)) \(time)"
        default:
            if calendar.component(.year, from: start) == calendar.component(.year, from: now) {
                return "\(format(start, template: "EEEMMMd", clock: clock)), \(time)"
            }
            return "\(format(start, template: "yMMMd", clock: clock)), \(time)"
        }
    }

    /// The short line under the time: how soon, or that it's on, over, or cancelled.
    /// Nil when it's more than 12 hours away (the day already says enough).
    static func relative(_ session: PlaySession, now: Date) -> String? {
        switch PlaySessionRules.phase(session, now: now) {
        case .cancelled: return PlaySessionCopy.cancelled
        case .over: return PlaySessionCopy.ended
        case .live: return PlaySessionCopy.live
        case .upcoming: break
        }
        let seconds = session.startsAt.timeIntervalSince(now)
        if seconds < 60 { return "Starting now" }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "Starts in \(minutes) min" }
        if minutes < 3 * 60 {
            let hours = minutes / 60
            let rest = minutes % 60
            return rest == 0 ? "Starts in \(hours) hr" : "Starts in \(hours) hr \(rest) min"
        }
        if seconds < 12 * 60 * 60 {
            return "Starts in \(Int((seconds / 3600).rounded())) hr"
        }
        return nil
    }

    /// The form's starting time: tonight at 8 when that's at least 30 minutes
    /// off, otherwise half an hour from now on the next quarter hour.
    static func suggestedStart(now: Date, calendar: Calendar) -> Date {
        if let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now),
           tonight.timeIntervalSince(now) >= 30 * 60 {
            return tonight
        }
        return roundedUp(now.addingTimeInterval(30 * 60), calendar: calendar)
    }

    struct QuickPick: Equatable, Identifiable {
        let id: String
        let title: String
        let date: Date
    }

    /// One-tap times in the form: soon, tonight at 8 (while it's still 15
    /// minutes off), and tomorrow at 8.
    static func quickPicks(now: Date, clock: ChatClock) -> [QuickPick] {
        let calendar = clock.calendar
        var picks: [QuickPick] = []
        let soon = roundedUp(now.addingTimeInterval(30 * 60), calendar: calendar)
        picks.append(QuickPick(id: "soon", title: "In 30 min", date: soon))
        if let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now),
           tonight.timeIntervalSince(now) >= 15 * 60,
           abs(tonight.timeIntervalSince(soon)) >= 60 {
            picks.append(QuickPick(id: "tonight", title: label(tonight, now: now, clock: clock), date: tonight))
        }
        if let tomorrowDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let tomorrow = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: tomorrowDay) {
            picks.append(QuickPick(id: "tomorrow", title: label(tomorrow, now: now, clock: clock), date: tomorrow))
        }
        return picks
    }

    /// The next quarter hour at or after `date`, with seconds dropped.
    static func roundedUp(_ date: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let minute = parts.minute ?? 0
        let second = parts.second ?? 0
        let needsBump = second > 0 || minute % 15 != 0
        parts.second = 0
        parts.minute = minute - minute % 15
        let floor = calendar.date(from: parts) ?? date
        return needsBump ? floor.addingTimeInterval(15 * 60) : floor
    }

    private static func format(_ date: Date, template: String, clock: ChatClock) -> String {
        ChatFormatterCache.shared.formatter(template: template, calendar: clock.calendar, locale: clock.locale).string(from: date)
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}

/// What the form holds. A blank game falls back to your default game.
struct PlaySessionDraft: Equatable {
    var startsAt: Date
    var game: String
    var note: String

    func resolvedGame(defaultGame: String) -> String {
        let typed = game.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return defaultGame.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedNote: String? {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Why it can't be scheduled yet, checked on the phone before anything is sent.
    func problem(now: Date, defaultGame: String) -> PlaySessionProblem? {
        let game = resolvedGame(defaultGame: defaultGame)
        if game.isEmpty { return .gameBlank }
        if game.count > PlaySessionRules.maxGameLength { return .gameLong }
        if (resolvedNote?.count ?? 0) > PlaySessionRules.maxNoteLength { return .noteLong }
        if startsAt < now.addingTimeInterval(-PlaySessionRules.pastGrace) { return .timePast }
        if startsAt > now.addingTimeInterval(PlaySessionRules.horizon) { return .timeFar }
        return nil
    }
}

/// Why a read or write didn't work, in plain words. Server codes come from
/// 0016 (`session_full`, RLS) and 0025 (the rest).
enum PlaySessionProblem: Error, Equatable {
    case unavailable
    case offline
    case full
    case cancelled
    case over
    case notInSquad
    case notAllowed
    case timePast
    case timeFar
    case gameBlank
    case gameLong
    case noteLong
    case failed

    var message: String {
        switch self {
        case .unavailable: PlaySessionCopy.unavailable
        case .offline: "You're offline. Nothing was saved. Try again when you're back."
        case .full: "Eight people are already in. That's the most a session holds."
        case .cancelled: "This session was cancelled."
        case .over: "This session is over."
        case .notInSquad: "You're not in this group anymore."
        case .notAllowed: "The server didn't allow that. The session may have changed. Pull to refresh."
        case .timePast: "Pick a time that hasn't passed yet."
        case .timeFar: "Pick a time in the next 60 days."
        case .gameBlank: "Add a game so the group knows what you're playing."
        case .gameLong: "Use \(PlaySessionRules.maxGameLength) characters or fewer for the game."
        case .noteLong: "Keep the note to \(PlaySessionRules.maxNoteLength) characters or fewer."
        case .failed: "That didn't save. Try again."
        }
    }

    /// A backend error as one of these. Sign-in failures are left to the caller
    /// (see `isSessionFailure`), which sends them through the sign-in path.
    static func from(_ error: Error) -> PlaySessionProblem {
        if let problem = error as? PlaySessionProblem { return problem }
        guard let failure = error as? BackendFailure else { return .failed }
        switch failure {
        case .notSetUp: return .unavailable
        case .reconnecting: return .offline
        case .rejected(let text):
            let lower = text.lowercased()
            if lower.contains("session_full") { return .full }
            if lower.contains("session_cancelled") { return .cancelled }
            if lower.contains("session_over") { return .over }
            if lower.contains("not_in_squad") { return .notInSquad }
            if lower.contains("session_time_past") { return .timePast }
            if lower.contains("session_time_far") { return .timeFar }
            if lower.contains("session_game_long") { return .gameLong }
            if lower.contains("sq8_sessions_game_not_blank") { return .gameBlank }
            if lower.contains("sq8_sessions_note") { return .noteLong }
            if lower.contains("row-level security") || lower.contains("permission denied") { return .notAllowed }
            return .failed
        case .notConfigured, .notSignedIn, .sessionEnded:
            return .failed
        }
    }

    /// Errors that mean the sign-in ended, not that sessions failed.
    static func isSessionFailure(_ error: Error) -> Bool {
        guard let failure = error as? BackendFailure else { return false }
        switch failure {
        case .notSignedIn, .sessionEnded: return true
        case .rejected(let text): return AuthFailure.mentionsJWT(text)
        default: return false
        }
    }
}

/// The sessions read for the open squad.
enum PlaySessionLoad: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
    /// The server has no session tables (0016): the feature says so and stays off.
    case unavailable

    /// A refresh keeps what's on screen; only the first read shows loading.
    static func beginning(_ previous: PlaySessionLoad) -> PlaySessionLoad {
        switch previous {
        case .idle, .failed: return .loading
        default: return previous
        }
    }

    var isUnavailable: Bool { self == .unavailable }

    enum Display: Equatable {
        case loading
        case failed(String)
        /// A refresh failed but earlier sessions are still showing.
        case stale
        case unavailable
    }

    /// What the sheet shows above (or instead of) the list.
    func display(hasData: Bool) -> Display? {
        switch self {
        case .idle, .loading: return hasData ? nil : .loading
        case .loaded: return nil
        case .failed(let text): return hasData ? .stale : .failed(text)
        case .unavailable: return .unavailable
        }
    }
}

enum PlaySessionCopy {
    static let title = "Play sessions"
    static let schedule = "Schedule a session"
    static let unavailable = "Play sessions aren't set up on this server yet."
    static let loading = "Loading sessions…"
    static let loadFailed = "Sessions couldn't load. Check your connection and try again."
    static let stale = "Couldn't refresh. Showing the sessions that loaded last."
    static let empty = "Nothing scheduled yet. Pick a time and the group can say In or Out."
    static let noAnswers = "No answers yet"
    static let cancelled = "Cancelled"
    static let ended = "Ended"
    static let live = "Happening now"
    static let gameHint = "Leave it blank to use your default game."

    static func scheduledNote(game: String, time: String) -> String {
        "Scheduled \(game) for \(time). You're in."
    }

    static func scheduledButRSVPFailed(game: String, time: String) -> String {
        "Scheduled \(game) for \(time), but your In didn't save. Tap In on the card."
    }

    /// "Next: Tonight 8:00 PM · Warzone · 3 in", plus "+2 more" when there are others.
    static func nextLine(_ session: PlaySession, roster: PlaySessionRoster, others: Int, time: String) -> String {
        var line = "\(time) · \(session.game) · \(roster.summary)"
        if others > 0 { line += " · +\(others) more" }
        return line
    }

    /// The whole card for VoiceOver, in order: what, when, how soon, who, you.
    static func spoken(_ session: PlaySession, roster: PlaySessionRoster, time: String, relative: String?) -> String {
        var parts: [String] = ["Play session: \(session.game), \(time)."]
        if let relative { parts.append("\(relative).") }
        if roster.going.isEmpty && roster.out.isEmpty {
            parts.append("No answers yet.")
        } else {
            if !roster.going.isEmpty { parts.append("In: \(PlaySessionRoster.list(roster.going)).") }
            if !roster.out.isEmpty { parts.append("Out: \(PlaySessionRoster.list(roster.out)).") }
        }
        if let note = session.note, !note.isEmpty { parts.append("Note: \(note)") }
        return parts.joined(separator: " ")
    }

    static func yourAnswer(_ response: PlaySessionResponse?) -> String {
        switch response {
        case .going: "You're in"
        case .out: "You're out"
        default: "You haven't answered"
        }
    }
}

/// Session cards in the chat: each sits where it was scheduled, between messages.
enum PlaySessionThread {
    /// Merges session cards into the thread by `createdAt`. A card goes before a
    /// row at the same time. Cards older than `earliest` (the oldest loaded
    /// message, while older pages are still unread) are left out so they don't
    /// pile up above a partial history; nil keeps them all.
    static func items(_ base: [SpotThreadItem], sessions: [PlaySession], earliest: Date?) -> [SpotThreadItem] {
        let cards = sessions
            .filter { session in earliest.map { session.createdAt >= $0 } ?? true }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        guard !cards.isEmpty else { return base }
        var result: [SpotThreadItem] = []
        var pending = cards[...]
        for item in base {
            let at = date(of: item)
            while let next = pending.first, next.createdAt <= at {
                result.append(.session(next))
                pending = pending.dropFirst()
            }
            result.append(item)
        }
        result.append(contentsOf: pending.map { .session($0) })
        return result
    }

    static func date(of item: SpotThreadItem) -> Date {
        switch item {
        case .message(let entry): entry.sentAt
        case .spot(let call): SpotThread.endedAt(call)
        case .session(let session): session.createdAt
        case .gameOn(let call): call.calledAt
        }
    }
}
