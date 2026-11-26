import Foundation

@MainActor
final class RealtimeClient {
    enum Event {
        case message(RemoteMessage)
        case messageRemoved(UUID)
        case roster
        case reaction(ReactionMark, removed: Bool)
        case read(MemberRead)
        case spots
        /// 0016 publishes `sq8_sessions` and `sq8_session_rsvps`; any change rereads the squad's sessions.
        case sessions
        /// 0009 publishes `sq8_check_ins`; an insert or update in this squad rereads its rows.
        case checkIns
        /// A check-in was deleted (Clear, or the trigger when someone leaves). It may
        /// carry only the user id; the model decides whether it touches this squad.
        case checkInRemoved(UUID?)
        case phase(RealtimeLink)
    }

    var onEvent: (Event) -> Void = { _ in }

    private var task: URLSessionWebSocketTask?
    private var listen: Task<Void, Never>?
    private var heart: Task<Void, Never>?
    private var reconnect: Task<Void, Never>?
    private var attempt = 0
    private var stopped = false
    private var reconnecting = false
    private var generation = 0
    private var squadId = UUID()
    private var config = BackendConfig(urlText: "", anonKey: "")
    /// The JWT the next join uses, and the one an open channel was last given.
    private(set) var accessToken = ""
    /// True once the channel join is acknowledged; false while (re)connecting.
    private(set) var joined = false
    private var nextRef = 100
    private let topicPrefix = "realtime:sq8"
    /// Tests pass a sender to capture frames; the app leaves it nil and uses a socket.
    private let sender: ((String) async -> Void)?

    init(sender: ((String) async -> Void)? = nil) {
        self.sender = sender
    }

    private var topic: String { "\(topicPrefix):\(squadId.uuidString.lowercased())" }
    private static let socketSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    func start(config: BackendConfig, accessToken: String, squadId: UUID) {
        stop()
        stopped = false
        self.config = config
        self.accessToken = accessToken
        self.squadId = squadId
        attempt = 0
        open(link: .connecting)
    }

    func stop() {
        stopped = true
        joined = false
        listen?.cancel()
        heart?.cancel()
        reconnect?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func open(link: RealtimeLink) {
        listen?.cancel()
        heart?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        joined = false
        guard !stopped, let url = socketURL() else {
            onEvent(.phase(.down))
            return
        }
        reconnecting = false
        generation += 1
        let current = generation
        onEvent(.phase(link))
        if sender != nil {
            listen = Task { [weak self] in await self?.sendJoin() }
            return
        }
        let socket = Self.socketSession.webSocketTask(with: url)
        task = socket
        socket.resume()
        listen = Task { [weak self] in
            await self?.sendJoin()
            await self?.receiveLoop(generation: current)
        }
        heart = Task { [weak self] in
            await self?.beat()
        }
    }

    private func socketURL() -> URL? {
        guard let base = config.url else { return nil }
        var parts = URLComponents(url: base, resolvingAgainstBaseURL: false)
        parts?.scheme = base.scheme == "http" ? "ws" : "wss"
        parts?.path = "/realtime/v1/websocket"
        parts?.queryItems = [
            URLQueryItem(name: "apikey", value: config.anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        return parts?.url
    }

    private func sendJoin() async {
        let squad = squadId.uuidString.lowercased()
        let changes: [[String: Any]] = [
            change("sq8_messages", filter: "squad_id=eq.\(squad)"),
            change("sq8_squad_members", filter: "squad_id=eq.\(squad)"),
            change("sq8_squads", filter: "id=eq.\(squad)"),
            change("sq8_message_reads", filter: "squad_id=eq.\(squad)"),
            change("sq8_message_reactions", filter: nil),
            change("sq8_spot_calls", filter: "squad_id=eq.\(squad)"),
            change("sq8_spot_rsvps", filter: nil),
            change("sq8_sessions", filter: "squad_id=eq.\(squad)"),
            // RSVP rows carry no squad id; RLS only delivers this squad's (0016 select policy).
            change("sq8_session_rsvps", filter: nil),
            change("sq8_check_ins", filter: "squad_id=eq.\(squad)"),
            // Supabase doesn't deliver DELETEs to a filtered subscription, so Clear
            // would never reach the others. Listen to every check-in delete instead.
            change("sq8_check_ins", filter: nil, event: "DELETE")
        ]
        let payload: [String: Any] = [
            "access_token": accessToken,
            "config": [
                "broadcast": ["ack": false, "self": false],
                "presence": ["key": ""],
                "postgres_changes": changes,
                "private": false
            ]
        ]
        await send(topic: topic, event: "phx_join", payload: payload, ref: "1")
    }

    private func change(_ table: String, filter: String?, event: String = "*") -> [String: Any] {
        var row: [String: Any] = [
            "event": event,
            "schema": "public",
            "table": table
        ]
        if let filter { row["filter"] = filter }
        return row
    }

    private func beat() async {
        var ref = 2
        while !Task.isCancelled && !stopped {
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            if Task.isCancelled || stopped { return }
            await send(topic: "phoenix", event: "heartbeat", payload: [:], ref: "\(ref)")
            ref += 1
        }
    }

    /// A refreshed session's JWT. An open channel gets it right away with an
    /// `access_token` frame; a channel that's still joining picks it up in the
    /// join, which always reads the newest token.
    func updateAccessToken(_ token: String) {
        let fresh = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fresh.isEmpty, fresh != accessToken else { return }
        accessToken = fresh
        guard joined, !stopped else { return }
        nextRef += 1
        let frame = RealtimeFrames.accessToken(topic: topic, token: fresh, ref: "\(nextRef)")
        Task { [weak self] in await self?.send(frame) }
    }

    private func send(topic: String, event: String, payload: [String: Any], ref: String) async {
        await send([
            "topic": topic,
            "event": event,
            "payload": payload,
            "ref": ref,
            "join_ref": "1"
        ])
    }

    private func send(_ body: [String: Any]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let text = String(data: data, encoding: .utf8) else { return }
        if let sender {
            await sender(text)
            return
        }
        guard let task else { return }
        try? await task.send(.string(text))
    }

    private func receiveLoop(generation: Int) async {
        guard let task else { return }
        while !Task.isCancelled && !stopped && generation == self.generation {
            do {
                let incoming = try await task.receive()
                let text: String
                switch incoming {
                case .string(let value):
                    text = value
                case .data(let data):
                    text = String(data: data, encoding: .utf8) ?? ""
                @unknown default:
                    text = ""
                }
                if !text.isEmpty { handle(text) }
            } catch {
                if !stopped && generation == self.generation { scheduleReconnect() }
                return
            }
        }
    }

    private func scheduleReconnect() {
        guard !stopped, !reconnecting else { return }
        reconnecting = true
        joined = false
        attempt += 1
        let delay = UInt64(min(attempt, 4)) * 1_000_000_000
        onEvent(.phase(.reconnecting))
        reconnect = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !self.stopped else { return }
            self.open(link: .reconnecting)
        }
    }

    /// One incoming frame. Internal so tests can play server replies.
    func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let event = object["event"] as? String ?? ""
        let topic = object["topic"] as? String ?? ""
        let payload = object["payload"] as? [String: Any] ?? [:]
        if event == "phx_reply", topic.hasPrefix(topicPrefix) {
            let status = payload["status"] as? String ?? ""
            if status == "ok" {
                attempt = 0
                joined = true
                onEvent(.phase(.connected))
            } else {
                onEvent(.phase(.down))
                scheduleReconnect()
            }
            return
        }
        if event == "phx_error" || event == "phx_close" {
            scheduleReconnect()
            return
        }
        guard event == "postgres_changes" else { return }
        let change = payload["data"] as? [String: Any] ?? payload
        let table = change["table"] as? String ?? ""
        let kind = (change["eventType"] as? String) ?? (change["type"] as? String) ?? ""
        let record = (change["record"] as? [String: Any]) ?? (change["new"] as? [String: Any]) ?? [:]
        let previous = (change["old_record"] as? [String: Any]) ?? (change["old"] as? [String: Any]) ?? [:]
        let removed = kind == "DELETE"
        switch table {
        case "sq8_messages":
            if removed, let id = uuid(previous["id"] ?? record["id"]) {
                onEvent(.messageRemoved(id))
            } else if let message = RemoteMessage(record: record) {
                onEvent(.message(message))
            }
        case "sq8_squad_members":
            let squad = uuid(record["squad_id"] ?? previous["squad_id"])
            if squad == nil || squad == squadId { onEvent(.roster) }
        case "sq8_squads":
            // 0021 publishes this table. A rename arrives here; the roster reload reads name.
            let id = uuid(record["id"] ?? previous["id"])
            if id == nil || id == squadId { onEvent(.roster) }
        case "sq8_message_reads":
            guard let user = uuid(record["user_id"]),
                  let stamp = record["last_read_at"] as? String,
                  let at = BackendJSON.parse(stamp) else { return }
            let squad = uuid(record["squad_id"])
            if squad == nil || squad == squadId {
                onEvent(.read(MemberRead(userId: user, lastReadAt: at)))
            }
        case "sq8_message_reactions":
            let source = removed ? previous : record
            guard let message = uuid(source["message_id"] ?? record["message_id"]),
                  let user = uuid(source["user_id"] ?? record["user_id"]),
                  let emoji = (source["emoji"] as? String) ?? (record["emoji"] as? String) else { return }
            let squad = uuid(record["squad_id"])
            if !removed, let squad, squad != squadId { return }
            onEvent(.reaction(ReactionMark(messageId: message, userId: user, emoji: emoji), removed: removed))
        case "sq8_spot_calls", "sq8_spot_rsvps":
            onEvent(.spots)
        case "sq8_sessions", "sq8_session_rsvps":
            onEvent(.sessions)
        case "sq8_check_ins":
            switch CheckInChange.parse(kind: kind, record: record, previous: previous, squadId: squadId) {
            case .changed: onEvent(.checkIns)
            case .removed(let user): onEvent(.checkInRemoved(user))
            case nil: break
            }
        default:
            break
        }
    }

    private func uuid(_ value: Any?) -> UUID? {
        if let id = value as? UUID { return id }
        if let text = value as? String { return UUID(uuidString: text) }
        return nil
    }
}

extension RemoteMessage {
    init?(record: [String: Any]) {
        guard let idText = record["id"] as? String, let id = UUID(uuidString: idText),
              let squadText = record["squad_id"] as? String, let squadId = UUID(uuidString: squadText),
              let senderText = record["sender_id"] as? String, let senderId = UUID(uuidString: senderText),
              let body = record["body"] as? String,
              let stamp = record["sent_at"] as? String,
              let sentAt = BackendJSON.parse(stamp) else { return nil }
        let reply = (record["reply_to_id"] as? String).flatMap(UUID.init(uuidString:))
        self.init(id: id, squadId: squadId, senderId: senderId, body: body, sentAt: sentAt, replyToId: reply)
    }
}
