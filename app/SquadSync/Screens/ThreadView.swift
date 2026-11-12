import SwiftUI

struct ThreadView: View {
    @Bindable var store: MockStore
    let conversation: Conversation
    @State private var draft = ""
    @State private var reply: ChatMessage?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var messages: [ChatMessage] { store.messages(in: conversation.id) }
    private var typing: [String] { store.typingNames(in: conversation.id) }
    private var isGroup: Bool { conversation.kind != .dm }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(store.onCount) of \(SpotRules.squadCap) on")
                .font(.caption.monospacedDigit())
                .foregroundStyle(SQColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SQSpace.l)
                .padding(.top, SQSpace.s)
                .accessibilityLabel("\(store.onCount) of \(SpotRules.squadCap) on")
            PartyCardView(store: store, conversation: conversation)
                .padding(.horizontal, SQSpace.l)
                .padding(.top, SQSpace.s)
            List {
                ForEach(messages) { message in
                    bubble(message)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)
            .onAppear { store.markSeen(in: conversation.id) }
            if store.showsVoicePill {
                VoicePill(room: store.voice) { store.openVoice() }
                    .padding(.top, SQSpace.s)
                    .accessibilityIdentifier("voice-pill")
                    .layoutPriority(1)
            }
            if !typing.isEmpty {
                Text(typingLine)
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SQSpace.l)
                    .padding(.top, SQSpace.s)
                    .accessibilityLabel(typingLine)
                    .accessibilityIdentifier("typing-indicator")
                    .layoutPriority(1)
            }
            composer
                .layoutPriority(1)
        }
        .background(SQColor.canvas)
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Voice room") { store.openVoice() }
                    .accessibilityLabel("Voice room")
                    .accessibilityIdentifier("voice-room")
                    .accessibilityAddTraits(.isButton)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Handoff menu") { store.handoffSheetPresented = true }
                    .accessibilityLabel("Handoff menu")
                    .accessibilityIdentifier("handoff-menu")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .sensoryFeedback(.success, trigger: store.party?.locked ?? false)
    }

    private var typingLine: String {
        let names = typing.joined(separator: ", ")
        return typing.count == 1 ? "\(names) is typing" : "\(names) are typing"
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            if let reply {
                HStack {
                    Text("Replying to \(reply.text)")
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button("Clear") { self.reply = nil }
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SQSpace.s) {
                    hereButton
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                    sendButton
                }
            } else {
                composerRow
            }
        }
        .padding(SQSpace.m)
        .background(.ultraThinMaterial)
    }

    private var composerRow: some View {
        HStack(alignment: .bottom) {
            hereButton
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            sendButton
        }
    }

    private var hereButton: some View {
        Button("@here") {
            if !draft.contains("@here") { draft = "@here " + draft }
        }
        .font(.caption.weight(.semibold))
        .fixedSize()
        .accessibilityHint("Ping everyone who is on")
    }

    private var sendButton: some View {
        Button {
            store.send(text: draft, in: conversation.id, reply: reply)
            draft = ""
            reply = nil
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .dynamicTypeSize(.large ... .xxxLarge)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Send")
        .accessibilityIdentifier("send")
    }

    private func startsRun(_ message: ChatMessage) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return true }
        guard index > 0 else { return true }
        return messages[index - 1].senderId != message.senderId
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let mine = message.senderId == store.viewerId
        let name = store.person(message.senderId)?.name ?? (message.senderId == "system" ? "SquadSync" : "Someone")
        let lead = isGroup && startsRun(message)
        return HStack(alignment: .bottom, spacing: SQSpace.s) {
            if !mine && isGroup {
                if lead, let person = store.person(message.senderId) {
                    PresenceAvatar(person: person, size: 28)
                } else {
                    Color.clear.frame(width: typeSize.isAccessibilitySize ? 0 : 28, height: 28)
                }
            }
            if mine && !typeSize.isAccessibilitySize { Spacer(minLength: 24) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if lead && isGroup {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SQColor.muted)
                }
                if let quote = message.replyQuote {
                    Text(quote)
                        .font(.caption)
                        .padding(SQSpace.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SQColor.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(SQColor.accent).frame(width: 3)
                        }
                        .accessibilityLabel("Quoted, \(quote)")
                }
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(mine ? Color.white : SQColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SQSpace.m)
                    .padding(.vertical, SQSpace.s)
                    .background(mine ? SQColor.mine : SQColor.theirs, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                tapbackChips(message)
                if mine, !message.seenBy.isEmpty {
                    Text("Seen by \(message.seenBy.compactMap { store.person($0)?.name }.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: mine ? .trailing : .leading)
            .contextMenu {
                ForEach(Tapback.allCases) { reaction in
                    Button(reaction.spoken) { store.tapback(reaction, on: message.id, in: conversation.id) }
                }
                Button("Reply") { reply = message }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button("Reply") { reply = message }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spoken(name: name, message: message))
            .accessibilityHint("Long press for tapbacks. Swipe to reply.")
            if !mine && !typeSize.isAccessibilitySize { Spacer(minLength: 24) }
        }
    }

    private func spoken(name: String, message: ChatMessage) -> String {
        var line = "\(name) said \(message.text)"
        let chips = Tapback.allCases.compactMap { reaction -> String? in
            let count = message.tapbacks.values.filter { $0 == reaction }.count
            guard count > 0 else { return nil }
            return "\(reaction.spoken) \(count)"
        }
        if !chips.isEmpty { line += ". " + chips.joined(separator: ", ") }
        return line
    }

    @ViewBuilder
    private func tapbackChips(_ message: ChatMessage) -> some View {
        let chips = Tapback.allCases.compactMap { reaction -> TapbackChip? in
            let count = message.tapbacks.values.filter { $0 == reaction }.count
            guard count > 0 else { return nil }
            return TapbackChip(reaction: reaction, count: count)
        }
        if !chips.isEmpty {
            HStack(spacing: 4) {
                ForEach(chips) { chip in
                    HStack(spacing: 3) {
                        Image(systemName: chip.reaction.rawValue)
                        Text("\(chip.count)")
                    }
                    .font(.caption2.weight(.semibold))
                    .dynamicTypeSize(.xSmall ... .xxxLarge)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SQColor.card, in: Capsule())
                    .accessibilityLabel("\(chip.reaction.spoken), \(chip.count)")
                }
            }
        }
    }
}

private struct TapbackChip: Identifiable {
    let reaction: Tapback
    let count: Int
    var id: String { reaction.id }
}

#Preview("Thread") {
    NavigationStack {
        ThreadView(store: .preview(), conversation: Seed.conversations[1])
    }
}
