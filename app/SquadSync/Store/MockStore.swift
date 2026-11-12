import Foundation
import Observation

@MainActor
@Observable
final class MockStore {
    var people: [Person]
    var conversations: [Conversation]
    var messages: [String: [ChatMessage]]
    var party: Party?
    var voice: VoiceRoom
    var screen: ScreenState
    var viewerId: String
    var typingNames: [String]
    var handoffNote: String?
    let voiceService: VoiceRoomService
    private var nextId = 100

    init(
        people: [Person],
        conversations: [Conversation],
        messages: [String: [ChatMessage]],
        party: Party?,
        voice: VoiceRoom,
        voiceService: VoiceRoomService,
        screen: ScreenState = .ready,
        viewerId: String = "spencer"
    ) {
        self.people = people
        self.conversations = conversations
        self.messages = messages
        self.party = party
        self.voice = voice
        self.voiceService = voiceService
        self.screen = screen
        self.viewerId = viewerId
        self.typingNames = ["Jordan"]
        applyVoiceSnapshot()
    }

    static func preview() -> MockStore { MockStore.seeded() }

    var viewer: Person { people.first { $0.id == viewerId } ?? people[0] }

    var squadMembers: [Person] { people.filter(\.countsTowardCap) }

    var onCount: Int { SpotRules.onCount(people) }

    func person(_ id: String) -> Person? { people.first { $0.id == id } }

    func visibleConversations() -> [Conversation] {
        SpotRules.visibleConversations(viewer: viewer, conversations: conversations)
    }

    func messages(in id: String) -> [ChatMessage] {
        (messages[id] ?? []).sorted { $0.sentAt < $1.sentAt }
    }

    func send(text: String, in conversationId: String, reply: ChatMessage?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        nextId += 1
        let message = ChatMessage(
            id: "m-\(nextId)",
            conversationId: conversationId,
            senderId: viewerId,
            text: trimmed,
            sentAt: Date(),
            replyToId: reply?.id,
            replyQuote: reply.map { String($0.text.prefix(80)) },
            tapbacks: [:],
            seenBy: [],
            mentionsHere: trimmed.localizedCaseInsensitiveContains("@here")
        )
        messages[conversationId, default: []].append(message)
        if message.mentionsHere {
            handoffNote = "You pinged everyone who's on."
        }
    }

    func tapback(_ reaction: Tapback, on messageId: String, in conversationId: String) {
        guard var thread = messages[conversationId],
              let index = thread.firstIndex(where: { $0.id == messageId }) else { return }
        if thread[index].tapbacks[viewerId] == reaction {
            thread[index].tapbacks[viewerId] = nil
        } else {
            thread[index].tapbacks[viewerId] = reaction
        }
        messages[conversationId] = thread
    }

    func markSeen(in conversationId: String) {
        guard var thread = messages[conversationId], let last = thread.indices.last else { return }
        if thread[last].senderId == viewerId { return }
        if !thread[last].seenBy.contains(viewerId) {
            thread[last].seenBy.append(viewerId)
        }
        messages[conversationId] = thread
    }

    @discardableResult
    func joinParty(personId: String, now: Date = Date()) -> Bool {
        guard var party else { return false }
        guard let person = person(personId) else { return false }
        guard SpotRules.canJoin(party: party, person: person, now: now) else { return false }
        party.seats.append(Seat(userId: personId, status: .in))
        self.party = party
        return true
    }

    @discardableResult
    func markReady(personId: String) -> Bool {
        guard var party else { return false }
        let ok = SpotRules.markReady(party: &party, personId: personId)
        self.party = party
        return ok
    }

    @discardableResult
    func lockParty() -> Bool {
        guard var party else { return false }
        let ok = SpotRules.lock(party: &party, actor: viewer)
        self.party = party
        return ok
    }

    func callSpot(game: String, size: Int) {
        let clamped = min(max(size, 1), SpotRules.squadCap)
        party = Party(
            id: "party-new",
            game: game,
            targetSize: clamped,
            callerId: viewerId,
            calledAt: Date(),
            seats: [Seat(userId: viewerId, status: .ready)],
            locked: false
        )
    }

    func joinVoice() async {
        voice.connection = .connecting
        await voiceService.join(userId: viewerId)
        applyVoiceSnapshot()
        voice.collapsed = false
    }

    func leaveVoice() async {
        await voiceService.leave(userId: viewerId)
        applyVoiceSnapshot()
    }

    func toggleMute() async {
        let muted = voice.mutedIds.contains(viewerId)
        await voiceService.mute(userId: viewerId, muted: !muted)
        applyVoiceSnapshot()
    }

    private func applyVoiceSnapshot() {
        voice.occupantIds = voiceService.participants.map(\.id)
        voice.mutedIds = voiceService.participants.filter(\.muted).map(\.id)
        voice.speakingLevels = Dictionary(
            uniqueKeysWithValues: voiceService.participants.map { ($0.id, $0.speakingLevel) }
        )
        voice.connection = voiceService.connection
        for index in people.indices {
            let id = people[index].id
            let participant = voiceService.participants.first { $0.id == id }
            people[index].inVoice = participant != nil
            let level = participant?.speakingLevel ?? 0
            people[index].isSpeaking = participant != nil && participant?.muted != true && level > 0.2
        }
    }

    func postSystem(_ text: String, in conversationId: String = "general") {
        nextId += 1
        messages[conversationId, default: []].append(
            ChatMessage(
                id: "sys-\(nextId)",
                conversationId: conversationId,
                senderId: "system",
                text: text,
                sentAt: Date(),
                replyToId: nil,
                replyQuote: nil,
                tapbacks: [:],
                seenBy: [],
                mentionsHere: false
            )
        )
    }

    static func seeded(now: Date = Date()) -> MockStore {
        let people = Seed.people
        let conversations = Seed.conversations
        let party = Party(
            id: "party-warzone",
            game: "Warzone",
            targetSize: 4,
            callerId: "spencer",
            calledAt: now.addingTimeInterval(-90),
            seats: [
                Seat(userId: "spencer", status: .ready),
                Seat(userId: "alex", status: .in)
            ],
            locked: false
        )
        let service = InMemoryVoiceRoomService(
            participants: [
                VoiceParticipant(id: "spencer", muted: false, speakingLevel: 0.8),
                VoiceParticipant(id: "quinn", muted: false, speakingLevel: 0.15)
            ],
            connection: .connected
        )
        let voice = VoiceRoom(
            title: "Lounge",
            occupantIds: [],
            mutedIds: [],
            speakingLevels: [:],
            connection: .idle,
            collapsed: false
        )
        return MockStore(
            people: people,
            conversations: conversations,
            messages: Seed.messages(now: now),
            party: party,
            voice: voice,
            voiceService: service
        )
    }
}

enum Seed {
    static let people: [Person] = [
        Person(id: "spencer", name: "Spencer", role: .owner, availability: .upToPlay, game: nil, inVoice: true, isSpeaking: true, isStarter: true),
        Person(id: "alex", name: "Alex", role: .member, availability: .upToPlay, game: "Warzone", inVoice: false, isSpeaking: false, isStarter: true),
        Person(id: "jordan", name: "Jordan", role: .admin, availability: .upToPlay, game: nil, inVoice: false, isSpeaking: false, isStarter: false),
        Person(id: "sam", name: "Sam", role: .member, availability: .onlineOnly, game: nil, inVoice: false, isSpeaking: false, isStarter: false),
        Person(id: "casey", name: "Casey", role: .member, availability: .later, game: nil, inVoice: false, isSpeaking: false, isStarter: false),
        Person(id: "morgan", name: "Morgan", role: .member, availability: .cant, game: nil, inVoice: false, isSpeaking: false, isStarter: false),
        Person(id: "quinn", name: "Quinn", role: .member, availability: .upToPlay, game: nil, inVoice: true, isSpeaking: false, isStarter: false),
        Person(id: "avery", name: "Avery", role: .member, availability: .upToPlay, game: "Halo", inVoice: false, isSpeaking: false, isStarter: false),
        Person(id: "riley", name: "Riley", role: .guest, availability: .onlineOnly, game: nil, inVoice: false, isSpeaking: false, isStarter: false)
    ]

    static let conversations: [Conversation] = [
        Conversation(id: "space", title: "The Eight", kind: .squadSpace, parentId: nil, participantIds: people.filter(\.countsTowardCap).map(\.id), guestIds: [], unread: 0, folded: true),
        Conversation(id: "general", title: "#general", kind: .channel, parentId: "space", participantIds: people.filter(\.countsTowardCap).map(\.id), guestIds: [], unread: 2, folded: true),
        Conversation(id: "warzone", title: "#warzone", kind: .channel, parentId: "space", participantIds: people.filter(\.countsTowardCap).map(\.id), guestIds: [], unread: 0, folded: true),
        Conversation(id: "friday", title: "Friday crew", kind: .sideGroup, parentId: nil, participantIds: ["spencer", "jordan", "riley"], guestIds: ["riley"], unread: 1, folded: false),
        Conversation(id: "dm-riley", title: "Riley", kind: .dm, parentId: nil, participantIds: ["spencer", "riley"], guestIds: ["riley"], unread: 0, folded: false)
    ]

    static func messages(now: Date) -> [String: [ChatMessage]] {
        [
            "general": [
                ChatMessage(id: "m1", conversationId: "general", senderId: "alex", text: "Warzone in five if you're actually up.", sentAt: now.addingTimeInterval(-400), replyToId: nil, replyQuote: nil, tapbacks: ["jordan": .game], seenBy: ["spencer"], mentionsHere: false),
                ChatMessage(id: "m2", conversationId: "general", senderId: "spencer", text: "I'm in. Give me the card.", sentAt: now.addingTimeInterval(-200), replyToId: "m1", replyQuote: "Warzone in five if you're actually up.", tapbacks: [:], seenBy: ["alex", "jordan"], mentionsHere: false),
                ChatMessage(id: "m3", conversationId: "general", senderId: "jordan", text: "@here one more and we lock.", sentAt: now.addingTimeInterval(-40), replyToId: nil, replyQuote: nil, tapbacks: [:], seenBy: [], mentionsHere: true)
            ],
            "friday": [
                ChatMessage(id: "f1", conversationId: "friday", senderId: "riley", text: "Guest check. I can hear you from outside the eight.", sentAt: now.addingTimeInterval(-800), replyToId: nil, replyQuote: nil, tapbacks: [:], seenBy: ["spencer"], mentionsHere: false)
            ],
            "dm-riley": [
                ChatMessage(id: "d1", conversationId: "dm-riley", senderId: "riley", text: "Save me a side-group seat.", sentAt: now.addingTimeInterval(-1200), replyToId: nil, replyQuote: nil, tapbacks: [:], seenBy: ["spencer"], mentionsHere: false)
            ]
        ]
    }
}
