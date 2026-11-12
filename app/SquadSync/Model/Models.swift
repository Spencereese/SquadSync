import Foundation

enum Role: String, Codable, CaseIterable, Identifiable {
    case owner, admin, member, guest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .owner: "Owner"
        case .admin: "Admin"
        case .member: "Member"
        case .guest: "Guest"
        }
    }
}

enum Availability: String, Codable {
    case upToPlay
    case onlineOnly
    case later
    case cant
}

struct Person: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var role: Role
    var availability: Availability
    var game: String?
    var inVoice: Bool
    var isSpeaking: Bool
    var isStarter: Bool

    var inGame: Bool { game != nil }
    var isOnline: Bool { availability != .cant }
    var countsTowardCap: Bool { role != .guest }
}

enum SeatStatus: String, Codable {
    case `in`
    case ready
    case onTheWay
    case out
}

struct Seat: Identifiable, Hashable, Codable {
    var id: String { userId }
    let userId: String
    var status: SeatStatus
}

struct Party: Identifiable, Hashable, Codable {
    let id: String
    var game: String
    var targetSize: Int
    var callerId: String
    var calledAt: Date
    var seats: [Seat]
    var locked: Bool

    func seat(for userId: String) -> Seat? {
        seats.first { $0.userId == userId }
    }
}

enum ConversationKind: String, Codable {
    case squadSpace
    case channel
    case sideGroup
    case dm
}

struct Conversation: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var kind: ConversationKind
    var parentId: String?
    var participantIds: [String]
    var guestIds: [String]
    var unread: Int
    var folded: Bool
}

enum Tapback: String, Codable, CaseIterable, Identifiable {
    case love = "heart.fill"
    case laugh = "face.smiling"
    case emphasize = "exclamationmark"
    case question = "questionmark"
    case thumbs = "hand.thumbsup.fill"
    case game = "gamecontroller.fill"
    var id: String { rawValue }
    var spoken: String {
        switch self {
        case .love: "Love"
        case .laugh: "Haha"
        case .emphasize: "Emphasis"
        case .question: "Question"
        case .thumbs: "Thumbs up"
        case .game: "Game"
        }
    }
}

struct ChatMessage: Identifiable, Hashable, Codable {
    let id: String
    var conversationId: String
    var senderId: String
    var text: String
    var sentAt: Date
    var replyToId: String?
    var replyQuote: String?
    var tapbacks: [String: Tapback]
    var seenBy: [String]
    var mentionsHere: Bool
}

struct VoiceRoom: Hashable, Codable {
    var title: String
    var occupantIds: [String]
    var mutedIds: [String]
    var collapsed: Bool
}

enum ScreenState: String, Codable {
    case loading
    case ready
    case empty
    case failed
}

struct HandoffTarget: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let url: URL?
    let staysInApp: Bool
}
