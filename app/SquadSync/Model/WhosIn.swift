import Foundation

// Who's in (redesign S4). Who said they can play, when, and what they're on,
// with where each line came from. Foundation only, so the rules run in the
// Linux harness.
//
// Sources, strongest first:
//   - Spot call: a seat on the open call. The server owns it.
//   - Steam: the sq8-steam-presence function, for members who linked a public
//     profile. PC only. Off until 0015 and the function are deployed.
//   - Check-in: `sq8_check_ins` (0006, live). Honor system. The person says
//     when, and (with proposed 0022) the game and console. Nothing verifies it.
//   - Profile: the default game. "Usually plays", never "playing".
// Xbox and PlayStation have no presence source here. A console only appears
// because someone typed it into their own check-in.

/// `sq8_check_ins.kind`.
enum CheckInKind: String, Codable, CaseIterable, Equatable {
    case availableNow = "available_now"
    case availableLater = "available_later"
    case unavailable
}

/// The console someone says they're on. Honor system: nothing checks it.
enum CheckInPlatform: String, Codable, CaseIterable, Identifiable, Equatable {
    case playstation
    case xbox
    case nintendoSwitch = "switch"
    case pc
    case mobile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playstation: "PlayStation"
        case .xbox: "Xbox"
        case .nintendoSwitch: "Switch"
        case .pc: "PC"
        case .mobile: "Mobile"
        }
    }
}

/// One `sq8_check_ins` row. `game` and `platform` exist only once proposed 0022 is applied.
struct CheckInRecord: Equatable {
    let userId: UUID
    let squadId: UUID
    var kind: CheckInKind
    var checkedAt: Date
    var untilAt: Date?
    var game: String?
    var platform: CheckInPlatform?
}

extension CheckInRecord: Decodable {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case squadId = "squad_id"
        case kind
        case checkedAt = "checked_at"
        case untilAt = "until_at"
        case game
        case platform
    }

    /// An unknown kind is a decoding error, so a row the app doesn't understand is
    /// dropped (see `CheckInRows`) instead of being read as "can't play".
    /// An unknown platform is just left out.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        squadId = try container.decode(UUID.self, forKey: .squadId)
        let rawKind = try container.decode(String.self, forKey: .kind)
        guard let kind = CheckInKind(rawValue: rawKind) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: rawKind)
        }
        self.kind = kind
        checkedAt = try container.decode(Date.self, forKey: .checkedAt)
        untilAt = try container.decodeIfPresent(Date.self, forKey: .untilAt)
        game = CheckInRules.normalizedGame(try container.decodeIfPresent(String.self, forKey: .game) ?? "")
        platform = (try container.decodeIfPresent(String.self, forKey: .platform)).flatMap(CheckInPlatform.init(rawValue:))
    }
}

enum CheckInRows {
    private struct Lossy: Decodable {
        let record: CheckInRecord?
        init(from decoder: Decoder) throws {
            record = try? CheckInRecord(from: decoder)
        }
    }

    /// Rows that decode; anything else is skipped.
    static func decode(_ data: Data, decoder: JSONDecoder) throws -> [CheckInRecord] {
        try decoder.decode([Lossy].self, from: data).compactMap(\.record)
    }
}

/// The body for an upsert into `sq8_check_ins`. The trigger stamps `checked_at`
/// and the 60-minute window for "on now", so neither is sent. `game` and
/// `platform` are only named when the server has them (proposed 0022), and are
/// sent as null to clear an old value.
struct CheckInWrite: Encodable, Equatable {
    let userId: UUID
    let squadId: UUID
    let kind: CheckInKind
    let untilAt: Date?
    let game: String?
    let platform: CheckInPlatform?
    let includesDetails: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case squadId = "squad_id"
        case kind
        case untilAt = "until_at"
        case game
        case platform
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(squadId, forKey: .squadId)
        try container.encode(kind, forKey: .kind)
        if kind == .availableLater, let untilAt {
            try container.encode(untilAt, forKey: .untilAt)
        } else {
            try container.encodeNil(forKey: .untilAt)
        }
        guard includesDetails else { return }
        let showsDetails = kind != .unavailable
        if showsDetails, let game {
            try container.encode(game, forKey: .game)
        } else {
            try container.encodeNil(forKey: .game)
        }
        if showsDetails, let platform {
            try container.encode(platform.rawValue, forKey: .platform)
        } else {
            try container.encodeNil(forKey: .platform)
        }
    }
}

/// What the server lets check-ins do. Read-only probes decide it.
struct CheckInCapabilities: Equatable {
    /// `sq8_check_ins` exists (0006).
    var table: Bool
    /// `game` and `platform` columns exist (proposed 0022, not applied).
    var details: Bool

    static let unknown = CheckInCapabilities(table: false, details: false)
}

enum CheckInRules {
    /// The database caps "on now" at 60 minutes from its own clock.
    static let nowWindow: TimeInterval = 60 * 60
    /// A "later" time stays listed this long after it arrives ("said around 8:00 PM").
    static let laterGrace: TimeInterval = 60 * 60
    /// "Can't play" has no end in the database. The app stops showing it after this.
    static let cantPlayLifetime: TimeInterval = 12 * 60 * 60
    /// The database accepts a later time more than a minute out and at most 7 days out.
    static let laterMinimumLead: TimeInterval = 2 * 60
    static let laterMaximumLead: TimeInterval = 7 * 24 * 60 * 60
    static let maxGameLength = 40

    /// Trimmed, capped at 40 characters, and nil when empty.
    static func normalizedGame(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxGameLength))
    }

    /// True when the database would accept this later time.
    static func acceptsLater(_ at: Date, now: Date) -> Bool {
        let lead = at.timeIntervalSince(now)
        return lead >= laterMinimumLead && lead <= laterMaximumLead
    }

    /// What one row means right now.
    static func availability(_ record: CheckInRecord?, now: Date) -> WhosInAvailability {
        guard let record else { return .notCheckedIn }
        switch record.kind {
        case .availableNow:
            guard let until = record.untilAt, until > now else { return .notCheckedIn }
            return .now(until: until)
        case .availableLater:
            guard let at = record.untilAt, at.addingTimeInterval(laterGrace) > now else { return .notCheckedIn }
            return .later(at: at)
        case .unavailable:
            guard record.checkedAt.addingTimeInterval(cantPlayLifetime) > now else { return .notCheckedIn }
            return .cantPlay
        }
    }

    /// Later choices for the check-in sheet: in 30 minutes, in an hour, in two hours,
    /// and 8 PM (today if it's at least an hour away, else tomorrow). Only times the
    /// database accepts, de-duplicated, in order.
    static func laterOptions(now: Date, calendar: Calendar = .current) -> [LaterOption] {
        var options = [
            LaterOption(label: "In 30 min", at: now.addingTimeInterval(30 * 60)),
            LaterOption(label: "In 1 hour", at: now.addingTimeInterval(60 * 60)),
            LaterOption(label: "In 2 hours", at: now.addingTimeInterval(2 * 60 * 60))
        ]
        if var evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) {
            var label = "Tonight 8 PM"
            if evening.timeIntervalSince(now) < 60 * 60 {
                evening = calendar.date(byAdding: .day, value: 1, to: evening) ?? evening
                label = "Tomorrow 8 PM"
            }
            options.append(LaterOption(label: label, at: evening))
        }
        var seen = Set<Date>()
        return options.filter { acceptsLater($0.at, now: now) && seen.insert($0.at).inserted }
    }

    /// The server's failure text for a check-in, in plain words.
    static func message(for serverText: String) -> String {
        let text = serverText.lowercased()
        if text.contains("sq8_check_in_later_invalid") || text.contains("sq8_check_ins_window") {
            return "Pick a time between a few minutes and 7 days from now."
        }
        if text.contains("sq8_check_in_squad") || text.contains("sq8_check_in_spoof") || text.contains("row-level security") {
            return "You can only check in for your own squad."
        }
        return "Check-in didn't save. Try again."
    }
}

struct LaterOption: Equatable, Identifiable {
    let label: String
    let at: Date
    var id: Date { at }
}

/// What a member's check-in says now.
enum WhosInAvailability: Equatable {
    case now(until: Date)
    case later(at: Date)
    case cantPlay
    case notCheckedIn
    /// The server has no check-ins, so nothing can be said.
    case untracked

    var section: WhosInSection {
        switch self {
        case .now: .now
        case .later: .later
        case .cantPlay: .cantPlay
        case .notCheckedIn, .untracked: .notCheckedIn
        }
    }
}

enum WhosInSection: Int, CaseIterable, Identifiable {
    case now
    case later
    case cantPlay
    case notCheckedIn

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .now: "On now"
        case .later: "Later"
        case .cantPlay: "Can't play"
        case .notCheckedIn: "Haven't checked in"
        }
    }

    var identifier: String {
        switch self {
        case .now: "whos-in-section-now"
        case .later: "whos-in-section-later"
        case .cantPlay: "whos-in-section-cant"
        case .notCheckedIn: "whos-in-section-none"
        }
    }
}

/// One member's Steam line from sq8-steam-presence. Steam ids never reach the phone.
enum SteamPresence: Equatable {
    case playing(String)
    case notInGame
    case privateProfile
    case notLinked
}

/// The Steam read for the squad.
enum SteamRead: Equatable {
    /// Not asked yet.
    case notChecked
    /// The function isn't deployed, or has no Steam key. The usual live answer today.
    case notSetUp
    /// The function answered with something else, or the request failed.
    case failed
    case members([UUID: SteamPresence])

    /// Parses the function's JSON. `not_set_up` stays `notSetUp`; anything unreadable is `failed`.
    static func parse(_ data: Data) -> SteamRead {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .failed }
        let status = object["status"] as? String
        if status == "not_set_up" { return .notSetUp }
        guard status == "ok", let rows = object["members"] as? [[String: Any]] else { return .failed }
        var members: [UUID: SteamPresence] = [:]
        for row in rows {
            guard let text = row["user_id"] as? String, let id = UUID(uuidString: text) else { continue }
            switch row["state"] as? String {
            case "playing":
                let game = (row["game"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                members[id] = game.isEmpty ? .notInGame : .playing(game)
            case "private": members[id] = .privateProfile
            case "not_in_game": members[id] = .notInGame
            case "not_linked": members[id] = .notLinked
            default: continue
            }
        }
        return .members(members)
    }

    func presence(for id: UUID) -> SteamPresence? {
        if case .members(let map) = self { return map[id] }
        return nil
    }
}

/// Where a game line came from. Drawn as a small tag beside the game and spoken.
enum WhosInGameSource: Equatable {
    case spot
    case steam
    case checkIn(CheckInPlatform?)
    case profile

    var tag: String {
        switch self {
        case .spot: "Spot call"
        case .steam: "Steam"
        case .checkIn: "Check-in"
        case .profile: "Profile"
        }
    }
}

struct WhosInEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let isViewer: Bool
    let isOwner: Bool
    let availability: WhosInAvailability
    /// A seat on the spot call, if any: locked, ready, or in spot.
    let seat: SquadPresenceStatus?
    let game: String?
    let gameSource: WhosInGameSource?
    /// "Steam profile private", shown only for linked members.
    let steamNote: String?

    var displayName: String { isViewer ? "You" : name }

    var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    /// The avatar ring: a seat wins, then the check-in.
    var ringStatus: SquadPresenceStatus {
        if let seat { return seat }
        return SquadPresence.status(for: availability, isViewer: isViewer)
    }

    func statusLine(now: Date, timeZone: TimeZone = .current) -> String {
        switch availability {
        case .now(let until):
            return "On now · until \(WhosIn.time(until, timeZone: timeZone))"
        case .later(let at):
            let time = WhosIn.time(at, timeZone: timeZone)
            return at > now ? "Later · around \(time)" : "Said around \(time)"
        case .cantPlay:
            return "Can't play"
        case .notCheckedIn:
            return isViewer ? "You haven't checked in" : "Hasn't checked in"
        case .untracked:
            return "Check-ins aren't on this server"
        }
    }

    /// The status for VoiceOver: words instead of the visible "·".
    func spokenStatus(now: Date, timeZone: TimeZone = .current) -> String {
        switch availability {
        case .now(let until): return "on now until \(WhosIn.time(until, timeZone: timeZone))"
        case .later(let at):
            let time = WhosIn.time(at, timeZone: timeZone)
            return at > now ? "on later, around \(time)" : "said around \(time)"
        case .cantPlay: return "can't play"
        case .notCheckedIn: return "hasn't checked in"
        case .untracked: return "check-ins aren't on this server"
        }
    }

    /// "Halo · Xbox", "Counter-Strike 2", "Usually plays Warzone". The source is a separate tag.
    var gameLine: String? {
        guard let game else { return nil }
        switch gameSource {
        case .some(.checkIn(let platform?)): return "\(game) · \(platform.label)"
        case .some(.profile), .none: return "Usually plays \(game)"
        default: return game
        }
    }

    var seatLine: String? {
        switch seat {
        case .some(.locked): "Locked in on the spot call"
        case .some(.ready): "Ready on the spot call"
        case .some(.inSpot): "In the spot call"
        default: nil
        }
    }

    func spokenLabel(now: Date, timeZone: TimeZone = .current) -> String {
        var bits = [name]
        if isViewer && name.lowercased() != "you" { bits.append("you") }
        if isOwner { bits.append("owner") }
        bits.append(spokenStatus(now: now, timeZone: timeZone))
        if let seatLine { bits.append(seatLine.lowercased()) }
        if let game {
            switch gameSource {
            case .some(.spot): bits.append("spot game \(game)")
            case .some(.steam): bits.append("playing \(game) on Steam")
            case .some(.checkIn(let platform)):
                let on = platform.map { " on \($0.label)" } ?? ""
                bits.append("says \(game)\(on), from their check-in")
            case .some(.profile), .none: bits.append("usually plays \(game)")
            }
        }
        if let steamNote { bits.append(steamNote) }
        return bits.joined(separator: ", ")
    }
}

enum WhosIn {
    static let title = "Who's in"
    static let honorNote = "Check-ins are on the honor system. Nobody checks the game or console."
    static let detailsMissing = "This server saves when you're on, not the game or console yet."
    static let untrackedNote = "Check-ins aren't set up on this server, so nobody's availability is shown."
    static let emptyNote = "Just you so far. Invite the squad from the squad panel."
    static let loadingText = "Loading who's in…"
    static let failedPrefix = "Who's in couldn't load."
    static let staleNote = "Couldn't refresh. Showing the last check-ins."

    /// A short time like "9:40 PM". POSIX locale so it reads the same everywhere it's tested.
    static func time(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// The newest row per person in this squad, in case the server ever sends two.
    static func newest(_ checkIns: [CheckInRecord], squadId: UUID?) -> [UUID: CheckInRecord] {
        var newest: [UUID: CheckInRecord] = [:]
        for record in checkIns where squadId == nil || record.squadId == squadId {
            if let held = newest[record.userId], held.checkedAt >= record.checkedAt { continue }
            newest[record.userId] = record
        }
        return newest
    }

    /// For the header strip. nil when the server has no check-ins, so the strip
    /// keeps saying presence isn't tracked.
    static func availabilityByMember(
        checkIns: [CheckInRecord],
        squadId: UUID?,
        caps: CheckInCapabilities,
        now: Date
    ) -> [UUID: WhosInAvailability]? {
        guard caps.table else { return nil }
        return newest(checkIns, squadId: squadId).mapValues { CheckInRules.availability($0, now: now) }
    }

    static func entries(
        members: [SquadMemberRecord],
        squadId: UUID?,
        ownerId: UUID?,
        viewerId: UUID?,
        spot: SpotCall?,
        checkIns: [CheckInRecord],
        caps: CheckInCapabilities,
        steam: SteamRead,
        now: Date
    ) -> [WhosInEntry] {
        let latest = caps.table ? Self.newest(checkIns, squadId: squadId) : [:]
        let built = members.map { member -> WhosInEntry in
            let record = latest[member.id]
            let availability: WhosInAvailability = caps.table ? CheckInRules.availability(record, now: now) : .untracked
            let seatStatus = SquadPresence.status(memberId: member.id, viewerId: nil, spot: spot, now: now)
            let seat: SquadPresenceStatus? = [.locked, .ready, .inSpot].contains(seatStatus) ? seatStatus : nil
            let steamPresence = steam.presence(for: member.id)
            let checkInCounts: Bool
            switch availability {
            case .now, .later: checkInCounts = true
            default: checkInCounts = false
            }
            let fallback = member.defaultGame.trimmingCharacters(in: .whitespacesAndNewlines)
            var game: String?
            var source: WhosInGameSource?
            if seat != nil, let spot {
                game = spot.game
                source = .spot
            } else if case .playing(let title) = steamPresence {
                game = title
                source = .steam
            } else if checkInCounts, caps.details, let typed = record?.game {
                game = typed
                source = .checkIn(record?.platform)
            } else if !fallback.isEmpty {
                game = fallback
                source = .profile
            }
            let note: String? = steamPresence == .privateProfile ? "Steam profile private" : nil
            let trimmedName = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return WhosInEntry(
                id: member.id,
                name: trimmedName.isEmpty ? "Player" : trimmedName,
                isViewer: member.id == viewerId,
                isOwner: member.isOwner || member.id == ownerId,
                availability: availability,
                seat: seat,
                game: game,
                gameSource: source,
                steamNote: note
            )
        }
        return built.sorted { lhs, rhs in
            if lhs.availability.section != rhs.availability.section {
                return lhs.availability.section.rawValue < rhs.availability.section.rawValue
            }
            if (lhs.seat != nil) != (rhs.seat != nil) { return lhs.seat != nil }
            if lhs.isViewer != rhs.isViewer { return lhs.isViewer }
            let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    struct Section: Identifiable, Equatable {
        let section: WhosInSection
        let entries: [WhosInEntry]
        var id: Int { section.rawValue }
    }

    /// Non-empty sections in order. Everyone sits in "Haven't checked in" when the server has no check-ins.
    static func sections(_ entries: [WhosInEntry]) -> [Section] {
        WhosInSection.allCases.compactMap { section in
            let rows = entries.filter { $0.availability.section == section }
            return rows.isEmpty ? nil : Section(section: section, entries: rows)
        }
    }

    /// "2 on now · 1 later", or "Nobody's checked in".
    static func summary(_ entries: [WhosInEntry]) -> String {
        let now = entries.filter { $0.availability.section == .now }.count
        let later = entries.filter { $0.availability.section == .later }.count
        var bits: [String] = []
        if now > 0 { bits.append("\(now) on now") }
        if later > 0 { bits.append("\(later) later") }
        return bits.isEmpty ? "Nobody's checked in" : bits.joined(separator: " · ")
    }

    // MARK: Sources footer

    static func checkInSource(_ caps: CheckInCapabilities) -> String {
        if !caps.table { return "Check-ins: not set up on this server." }
        return caps.details
            ? "Check-ins: what each person says, game and console included. Honor system."
            : "Check-ins: when each person says they're on. Honor system."
    }

    static func steamSource(_ steam: SteamRead) -> String {
        switch steam {
        case .notChecked: return "Steam: not checked yet."
        case .notSetUp: return "Steam: not set up on this server yet."
        case .failed: return "Steam: couldn't reach it just now."
        case .members: return "Steam: the game on linked public profiles. PC only."
        }
    }

    static let xboxSource = "Xbox and PlayStation: no presence from them. A console only shows if someone puts it in their check-in."
    static let spotSource = "Spot call: seats on the open call."
}

/// Loading state for the who's-in read.
enum WhosInLoad: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    enum Display: Equatable {
        case loading
        case failed(String)
        /// A refresh failed but earlier check-ins are still shown.
        case stale
    }

    func display(hasData: Bool) -> Display? {
        switch self {
        case .idle, .loaded: return nil
        case .loading: return hasData ? nil : .loading
        case .failed(let reason): return hasData ? .stale : .failed(reason)
        }
    }

    static func failure(_ error: Error) -> WhosInLoad {
        if let failure = error as? BackendFailure {
            switch failure {
            case .reconnecting: return .failed("\(WhosIn.failedPrefix) Check your connection.")
            case .rejected(let text): return .failed("\(WhosIn.failedPrefix) \(text)")
            default: break
            }
        }
        return .failed(WhosIn.failedPrefix)
    }
}
