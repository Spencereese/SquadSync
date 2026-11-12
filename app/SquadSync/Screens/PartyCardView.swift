import SwiftUI

struct PartyCardView: View {
    @Bindable var store: MockStore
    let conversation: Conversation
    var showsFullCard = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var open = false

    private var useCompactSummary: Bool {
        !showsFullCard && typeSize.isAccessibilitySize
    }

    var body: some View {
        if let party = store.party, store.showsParty(in: conversation) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if useCompactSummary {
                    compact(party, now: context.date)
                } else {
                    card(party, now: context.date)
                }
            }
        } else if let party = store.party, party.conversationId != conversation.id, isSquadThread {
            let home = store.conversations.first { $0.id == party.conversationId }?.title ?? "the squad thread"
            Text("\(party.game) is already forming in \(home).")
                .font(.footnote)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(party.game) is already forming in \(home)")
        } else if store.canOfferCall(in: conversation) {
            Button { _ = store.callSpot(game: "Warzone", size: 4, in: conversation.id) } label: {
                Text("Call a spot")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Starts a Warzone card for four in this thread")
        }
    }

    private func compact(_ party: Party, now: Date) -> some View {
        Button { open = true } label: {
            Text("\(party.game) · \(SpotRules.filled(party))/\(party.targetSize) · \(party.locked ? "Locked" : SpotRules.countdownText(party, now: now))")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SQSpace.s)
                .padding(.horizontal, SQSpace.m)
                .background(SQColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("party-summary")
        .accessibilityLabel("\(party.game), \(SpotRules.filled(party)) of \(party.targetSize). Open the party card")
        .sheet(isPresented: $open) {
            partySheet(party)
        }
    }

    private func partySheet(_ party: Party) -> some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: SQSpace.l) {
                                sheetDetails(party, now: context.date)
                                if typeSize.isAccessibilitySize, !party.locked {
                                    actionRow(party, now: context.date)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .accessibilityIdentifier("party-actions")
                                }
                            }
                            .padding(SQSpace.l)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if !typeSize.isAccessibilitySize, !party.locked {
                            actionBar(party, now: context.date)
                                .layoutPriority(1)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(SQColor.canvas)
                }
            }
            .navigationTitle(party.game)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { open = false }
                        .accessibilityIdentifier("party-close")
                }
            }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func actionBar(_ party: Party, now: Date) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SQColor.card)
                .frame(height: 12)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("party-actions-background")
                .accessibilityLabel("Party actions background")
            actionRow(party, now: now)
                .padding(SQSpace.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("party-actions")
        }
        .background(SQColor.card)
        .clipped()
    }

    private func sheetDetails(_ party: Party, now: Date) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            Text("\(SpotRules.filled(party))/\(party.targetSize) · \(party.locked ? "Locked" : SpotRules.countdownText(party, now: now))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(party.locked ? SQColor.online : SQColor.warning)
                .fixedSize(horizontal: false, vertical: true)
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
            Text("Spot already up. This is the card in play.")
                .font(.footnote)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("party-details-last")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Button {} label: {
                Text("Spot already up")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                            .fixedSize(horizontal: true, vertical: true)
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
            Button { _ = store.joinParty(personId: me.id, now: now) } label: {
                Text("I'm in").fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!SpotRules.canJoin(party: party, person: me, now: now))
            .accessibilityHint(SpotRules.isStarterExempt(me) ? "In-game starters can still join" : "Five minute window")
            Button { _ = store.toggleReady(personId: me.id) } label: {
                Text(store.readyButtonTitle).fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.bordered)
            .disabled(!store.canPressReady)
            .accessibilityHint(store.viewerSeat?.status == .ready ? "You are ready. Tap to unready." : "Mark yourself ready")
            Button { _ = store.lockParty() } label: {
                Text("Lock").fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.bordered)
            .disabled(!SpotRules.canLock(party: party, actor: me))
            .accessibilityHint("Locks once enough people are Ready")
        }
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SQSpace.xs) { actions }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { actions }
                    VStack(alignment: .leading, spacing: SQSpace.s) { actions }
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .dynamicTypeSize(.large ... (typeSize.isAccessibilitySize ? .xxxLarge : .accessibility5))
        .controlSize(typeSize.isAccessibilitySize ? .small : .regular)
    }
}

#Preview("Party") {
    PartyCardView(store: .preview(), conversation: Seed.conversations[1])
        .padding()
        .background(SQColor.canvas)
}
