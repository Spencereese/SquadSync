import SwiftUI

struct PartyCardView: View {
    @Bindable var store: MockStore
    var now: Date = Date()

    var body: some View {
        if let party = store.party {
            VStack(alignment: .leading, spacing: SQSpace.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(party.game).font(.title3.weight(.semibold))
                        Text("\(SpotRules.filled(party))/\(party.targetSize) · \(party.locked ? "Locked" : countdown(party))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(party.locked ? SQColor.online : SQColor.warning)
                    }
                    Spacer()
                    if party.locked {
                        Image(systemName: "lock.fill")
                            .accessibilityLabel("Squad locked")
                    }
                }
                Text(availabilityLine)
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                slotRow(party)
                if store.people.contains(where: { SpotRules.isStarterExempt($0) && party.seat(for: $0.id) != nil }) {
                    Text("Starters already in a game stay in after the five minutes.")
                        .font(.footnote)
                        .foregroundStyle(SQColor.muted)
                }
                if !party.locked {
                    actionRow(party)
                } else {
                    Text("Squad locked. Open voice or hand off.")
                        .font(.subheadline)
                }
                Button("Call a spot") { store.callSpot(game: "Warzone", size: 4) }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Starts a new Warzone card for four")
            }
            .sqCard()
        } else {
            Button("Call a spot") { store.callSpot(game: "Warzone", size: 4) }
                .buttonStyle(.borderedProminent)
        }
    }

    private var availabilityLine: String {
        let up = store.people.filter { $0.availability == .upToPlay && $0.countsTowardCap }.count
        let online = store.people.filter { $0.availability == .onlineOnly && $0.countsTowardCap }.count
        return "\(up) up to play · \(online) just online"
    }

    private func countdown(_ party: Party) -> String {
        let left = Int(SpotRules.remaining(party, now: now))
        return String(format: "%d:%02d", left / 60, left % 60)
    }

    private func slotRow(_ party: Party) -> some View {
        HStack(spacing: SQSpace.s) {
            ForEach(party.seats) { seat in
                if let person = store.person(seat.userId) {
                    VStack(spacing: 2) {
                        PresenceAvatar(person: person, size: 36)
                        Text(seat.status == .ready ? "Ready" : "In")
                            .font(.caption2)
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

    private func actionRow(_ party: Party) -> some View {
        let me = store.viewer
        return HStack {
            Button("I'm in") { _ = store.joinParty(personId: me.id, now: now) }
                .buttonStyle(.borderedProminent)
                .disabled(!SpotRules.canJoin(party: party, person: me, now: now))
                .accessibilityHint(SpotRules.isStarterExempt(me) ? "In-game starters can still join" : "Five minute window")
            Button("Ready") { _ = store.markReady(personId: me.id) }
                .buttonStyle(.bordered)
            Button("Lock") { _ = store.lockParty() }
                .buttonStyle(.bordered)
                .disabled(!SpotRules.canLock(party: party, actor: me))
        }
        .font(.subheadline.weight(.semibold))
    }
}

#Preview("Party") {
    PartyCardView(store: .preview())
        .padding()
        .background(SQColor.canvas)
}
