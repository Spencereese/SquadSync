import Combine
import SwiftUI

struct ThreadView: View {
    @Bindable var store: MockStore
    let conversation: Conversation
    @State private var draft = ""
    @State private var reply: ChatMessage?
    @State private var showVoice = false
    @State private var showHandoff = false
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            PartyCardView(store: store, now: now)
                .padding(.horizontal, SQSpace.l)
                .padding(.top, SQSpace.s)
            List {
                ForEach(store.messages(in: conversation.id)) { message in
                    bubble(message)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if !store.typingNames.isEmpty {
                    Text("\(store.typingNames.joined(separator: ", ")) is typing")
                        .font(.footnote)
                        .foregroundStyle(SQColor.muted)
                        .accessibilityLabel("\(store.typingNames.joined(separator: ", ")) is typing")
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear { store.markSeen(in: conversation.id) }
            composer
        }
        .background(SQColor.canvas)
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(conversation.title).font(.headline)
                    Text("\(store.onCount) of \(SpotRules.squadCap) on")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(SQColor.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(conversation.title), \(store.onCount) of \(SpotRules.squadCap) on")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showVoice = true } label: {
                    Image(systemName: "waveform")
                }
                .accessibilityLabel("Voice room")
                Button { showHandoff = true } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .accessibilityLabel("Handoff menu")
            }
        }
        .sheet(isPresented: $showVoice) { VoiceRoomView(store: store) }
        .sheet(isPresented: $showHandoff) { HandoffSheet(store: store) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .sensoryFeedback(.success, trigger: store.party?.locked ?? false)
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
            HStack(alignment: .bottom) {
                Button("@here") {
                    if !draft.contains("@here") { draft = "@here " + draft }
                }
                .font(.caption.weight(.semibold))
                .accessibilityHint("Ping everyone who is on")
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    store.send(text: draft, in: conversation.id, reply: reply)
                    draft = ""
                    reply = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(SQSpace.m)
        .background(.ultraThinMaterial)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let mine = message.senderId == store.viewerId
        let name = store.person(message.senderId)?.name ?? (message.senderId == "system" ? "SquadSync" : "Someone")
        return HStack {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
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
                    .padding(.horizontal, SQSpace.m)
                    .padding(.vertical, SQSpace.s)
                    .background(mine ? SQColor.mine : SQColor.theirs, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                if !message.tapbacks.isEmpty {
                    Text(message.tapbacks.values.map(\.spoken).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                }
                if mine, !message.seenBy.isEmpty {
                    Text("Seen by \(message.seenBy.compactMap { store.person($0)?.name }.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                }
            }
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
            .accessibilityLabel("\(name) said \(message.text)")
            .accessibilityHint("Long press for tapbacks. Swipe to reply.")
            if !mine { Spacer(minLength: 48) }
        }
    }
}

#Preview("Thread") {
    NavigationStack {
        ThreadView(store: .preview(), conversation: Seed.conversations[1])
    }
}
