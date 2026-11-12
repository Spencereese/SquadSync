import SwiftUI

struct PartyCardView: View {
    @Bindable var store: MockStore
    let conversation: Conversation

    var body: some View {
        if let party = store.party, store.showsParty(in: conversation) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                card(party, now: context.date)
            }
        } else if let party = store.party, party.conversationId != conversation.id, isSquadThread {
            let home = store.conversations.first { $0.id == party.conversationId }?.title ?? "the squad thread"
            Text("\(party.game) is already forming in \(home).")
                .font(.footnote)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(party.game) is already forming in \(home)")
        } else if store.canOfferCall(in: conversation) {
            Button("Call a spot") { _ = store.callSpot(game: "Warzone", size: 4, in: conversation.id) }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Starts a Warzone card for four in this thread")
        }
    }

    private func card(_ party: Party, now: Date) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(party.game).font(.title3.weight(.semibold))
                    Text("\(SpotRules.filled(party))/\(party.targetSize) · \(party.locked ? "Locked" : SpotRules.countdownText(party, now: now))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(party.locked ? SQColor.online : SQColor.warning)
                }
                Spacer(minLength: SQSpace.s)
                if party.locked {
                    Image(systemName: "lock.fill")
                        .accessibilityLabel("Squad locked")
                }
            }
            Text(availabilityLine)
                .font(.footnote)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            slotRow(party)
            if store.people.contains(where: { SpotRules.isStarterExempt($0) && party.seat(for: $0.id) != nil }) {
                Text("Starters already in a game stay in after the five minutes.")
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !party.locked {
                actionRow(party, now: now)
            } else {
                Text("Squad locked. Open voice or hand off.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Spot already up") {}
                .buttonStyle(.bordered)
                .disabled(true)
                .accessibilityLabel("Spot already up")
                .accessibilityHint("The \(party.game) card above is the one in play")
        }
        .sqCard()
    }

    private var isSquadThread: Bool {
        conversation.kind == .channel || conversation.kind == .squadSpace
    }

    private var availabilityLine: String {
        let up = store.people.filter { $0.availability == .upToPlay && $0.countsTowardCap }.count
        let online = store.people.filter { $0.availability == .onlineOnly && $0.countsTowardCap }.count
        return "\(up) up to play · \(online) just online"
    }

    private func slotRow(_ party: Party) -> some View {
        ViewThatFits(in: .horizontal) {
            slotLine(party)
            ScrollView(.horizontal, showsIndicators: false) { slotLine(party) }
        }
    }

    private func slotLine(_ party: Party) -> some View {
        HStack(spacing: SQSpace.s) {
            ForEach(party.seats) { seat in
                if let person = store.person(seat.userId) {
                    VStack(spacing: 2) {
                        PresenceAvatar(person: person, size: 36)
                        Text(seat.status == .ready ? "Ready" : "In")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            let open = max(0, party.targetSize - party.seats.count)
            ForEach(0..<open, id: \.self) { _ in
                Circle()
                    .stroke(SQColor.line, style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .frame(width: 36, height: 36)
                    .accessibilityLabel("Open slot")
            }
        }
    }

    private func actionRow(_ party: Party, now: Date) -> some View {
        let me = store.viewer
        let actions = Group {
            Button("I'm in") { _ = store.joinParty(personId: me.id, now: now) }
                .buttonStyle(.borderedProminent)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(!SpotRules.canJoin(party: party, person: me, now: now))
                .accessibilityHint(SpotRules.isStarterExempt(me) ? "In-game starters can still join" : "Five minute window")
            Button(store.readyButtonTitle) { _ = store.toggleReady(personId: me.id) }
                .buttonStyle(.bordered)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(!store.canPressReady)
                .accessibilityHint(store.viewerSeat?.status == .ready ? "You are ready. Tap to unready." : "Mark yourself ready")
            Button("Lock") { _ = store.lockParty() }
                .buttonStyle(.bordered)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(!SpotRules.canLock(party: party, actor: me))
                .accessibilityHint("Locks once enough people are Ready")
        }
        return ViewThatFits(in: .horizontal) {
            HStack { actions }
            VStack(alignment: .leading, spacing: SQSpace.s) { actions }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }
}

#Preview("Party") {
    PartyCardView(store: .preview(), conversation: Seed.conversations[1])
        .padding()
        .background(SQColor.canvas)
}
