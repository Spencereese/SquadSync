import Foundation

/// How a spot call ended, for the compact history card in the thread.
enum SpotOutcome: Equatable {
    case ended
    case cancelled
    case expired

    var title: String {
        switch self {
        case .ended: "Ended"
        case .cancelled: "Cancelled"
        case .expired: "Expired"
        }
    }
}

/// Where a spot call sits in the chat. Active calls stay pinned at the top of the
/// thread with their controls. Everything else is a compact history card.
enum SpotCardPhase: Equatable {
    case active
    case history(SpotOutcome)
}

/// One row of the chat thread: a message or a finished spot call.
enum SpotThreadItem: Identifiable, Equatable {
    case message(ChatEntry)
    case spot(SpotCall)

    var id: String {
        switch self {
        case .message(let entry): "message-\(entry.id.uuidString)"
        case .spot(let call): "spot-\(call.id.uuidString)"
        }
    }
}

enum SpotThread {
    /// History cards kept in the thread. Older calls drop off.
    static let historyLimit = 5
    static let historyUnavailable = "Earlier spot calls couldn't load."
    static let loadFailed = "The spot call couldn't load."
    static let localExpiryNote = "This phone's timer ended it. The server hasn't marked it expired yet."

    /// Server status wins. An open row past its window is expired by this phone's clock,
    /// unless the viewer is a starter who can still join (0013 exempts them).
    static func phase(_ call: SpotCall, viewerId: UUID?, now: Date) -> SpotCardPhase {
        switch call.status {
        case .cancelled:
            return .history(.cancelled)
        case .ended:
            return .history(.ended)
        case .expired:
            if let viewerId, SpotCallRules.canJoin(call, userId: viewerId, now: now) { return .active }
            return .history(.expired)
        case .locked:
            return call.closedAt == nil ? .active : .history(.ended)
        case .open:
            if call.closedAt != nil { return .history(.ended) }
            if SpotCallRules.showsExpired(call, now: now) {
                if let viewerId, SpotCallRules.canJoin(call, userId: viewerId, now: now) { return .active }
                return .history(.expired)
            }
            return .active
        }
    }

    static func outcome(_ call: SpotCall, viewerId: UUID?, now: Date) -> SpotOutcome? {
        if case .history(let outcome) = phase(call, viewerId: viewerId, now: now) { return outcome }
        return nil
    }

    /// The call that gets the full pinned card, if any.
    static func active(_ current: SpotCall?, viewerId: UUID?, now: Date) -> SpotCall? {
        guard let current, phase(current, viewerId: viewerId, now: now) == .active else { return nil }
        return current
    }

    /// When a finished call goes in the thread: when it closed, or when its window ran out.
    static func endedAt(_ call: SpotCall) -> Date {
        call.closedAt ?? call.lockedAt ?? call.joinUntil
    }

    /// Finished calls from the server for the thread, oldest first, newest `limit` kept.
    /// The current call is left out: it shows at the top of the thread, pinned or as
    /// history, until the next read moves it here.
    static func history(past: [SpotCall], excluding currentId: UUID?, viewerId: UUID?, now: Date, limit: Int = historyLimit) -> [SpotCall] {
        var seen = Set<UUID>()
        var finished: [SpotCall] = []
        for call in past where call.id != currentId && !seen.contains(call.id) {
            guard outcome(call, viewerId: viewerId, now: now) != nil else { continue }
            seen.insert(call.id)
            finished.append(call)
        }
        let ordered = finished.sorted { lhs, rhs in
            let left = endedAt(lhs)
            let right = endedAt(rhs)
            if left != right { return left < right }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return Array(ordered.suffix(max(0, limit)))
    }

    /// Messages and history cards interleaved by time. A card lands where its call ended.
    static func items(entries: [ChatEntry], history: [SpotCall]) -> [SpotThreadItem] {
        var result: [SpotThreadItem] = []
        var cards = history.sorted { endedAt($0) < endedAt($1) }[...]
        for entry in entries {
            while let next = cards.first, endedAt(next) <= entry.sentAt {
                result.append(.spot(next))
                cards = cards.dropFirst()
            }
            result.append(.message(entry))
        }
        result.append(contentsOf: cards.map { .spot($0) })
        return result
    }

    /// No call, a finished one, or an unlocked one past its window can take a new call.
    static func canCallNow(_ current: SpotCall?, now: Date) -> Bool {
        guard let current else { return true }
        if current.closedAt != nil || current.status == .cancelled || current.status == .ended { return true }
        return SpotCallRules.showsCallForm(current, now: now)
    }

    static func joinedCount(_ call: SpotCall) -> Int { call.filled }

    /// Short visible line under the game name.
    static func detail(_ call: SpotCall, outcome: SpotOutcome) -> String {
        "\(outcome.title) · \(joinedCount(call)) joined"
    }

    /// The whole card for VoiceOver, in one sentence.
    static func spoken(_ call: SpotCall, outcome: SpotOutcome, time: String) -> String {
        let joined = joinedCount(call) == 1 ? "1 person joined" : "\(joinedCount(call)) people joined"
        var line = "Spot call for \(call.game), \(outcome.title.lowercased()) at \(time). \(joined)."
        if showsLocalExpiryNote(call, outcome: outcome) { line += " " + localExpiryNote }
        return line
    }

    /// Without 0020 the row stays open after its window. Say so instead of claiming the server expired it.
    static func showsLocalExpiryNote(_ call: SpotCall, outcome: SpotOutcome) -> Bool {
        outcome == .expired && call.status == .open && !call.serverOwnsExpiry
    }
}

/// `/spots` and `/spots <game>` in the composer call spots instead of sending a message.
enum SpotCommand: Equatable {
    case call(game: String?)

    static let names = ["/spots", "/spot"]

    static func parse(_ text: String) -> SpotCommand? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let token = trimmed.prefix { !$0.isWhitespace }.lowercased()
        guard names.contains(token) else { return nil }
        let rest = trimmed.dropFirst(token.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return .call(game: rest.isEmpty ? nil : rest)
    }
}

/// The spot read's state, so the card area never shows a blank or a stale guess.
enum SpotLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    /// Only show "Loading…" before the first answer. A refresh keeps what's on screen:
    /// the card, or the settled "no call" state. Re-entering .loading on every poll
    /// put a spinner row at the top of the thread every 3 s when no call was open.
    static func beginning(_ previous: SpotLoadState, hasCard: Bool) -> SpotLoadState {
        hasCard || previous == .loaded ? previous : .loading
    }

    /// A failed read says so. It never pretends there is no call.
    static func finished(failure: String?) -> SpotLoadState {
        if let failure { return .failed(failure) }
        return .loaded
    }

    var showsLoadingRow: Bool { self == .loading }

    var failure: String? {
        if case .failed(let text) = self { return text }
        return nil
    }
}

/// What the call sheet shows while it works.
enum SpotSheetState: Equatable {
    case editing
    case calling
    case failed(String)

    static func after(success: Bool, message: String) -> SpotSheetState {
        success ? .editing : .failed(message)
    }
}
