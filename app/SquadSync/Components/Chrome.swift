import SwiftUI

struct PresenceAvatar: View {
    let person: Person
    var size: CGFloat = 44

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(String(person.name.prefix(1)))
                .font(.headline)
                .frame(width: size, height: size)
                .background(SQColor.card, in: Circle())
                .overlay(Circle().stroke(ring, lineWidth: person.inVoice || person.isOnline ? 2.5 : 1))
            if person.inGame {
                Image(systemName: "gamecontroller.fill")
                    .font(.caption2)
                    .padding(3)
                    .background(SQColor.accent, in: Circle())
                    .foregroundStyle(.white)
                    .accessibilityLabel("In \(person.game ?? "a game")")
            } else if person.inVoice {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2)
                    .padding(3)
                    .background(SQColor.online, in: Circle())
                    .foregroundStyle(.black)
                    .accessibilityLabel("In the voice room")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var ring: Color {
        if person.inVoice { return SQColor.online }
        if person.isOnline { return SQColor.online }
        return SQColor.line
    }

    private var spoken: String {
        var bits = [person.name, person.role.title]
        switch person.availability {
        case .upToPlay: bits.append("up to play")
        case .onlineOnly: bits.append("online, not up to play")
        case .later: bits.append("maybe later")
        case .cant: bits.append("can't play")
        }
        if let game = person.game { bits.append("playing \(game)") }
        if person.inVoice { bits.append("in the voice room") }
        return bits.joined(separator: ", ")
    }
}

struct RoleTag: View {
    let role: Role
    var body: some View {
        Text(role.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(SQColor.ink)
            .background(SQColor.role(role).opacity(0.85), in: Capsule())
            .accessibilityLabel("\(role.title) role")
    }
}

struct FormingDock: View {
    let party: Party
    let now: Date
    var body: some View {
        HStack(spacing: SQSpace.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(party.game) · \(SpotRules.filled(party))/\(party.targetSize)")
                    .font(.headline)
                Text(timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(SQColor.warning)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(SQColor.muted)
        }
        .sqCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(party.game), \(SpotRules.filled(party)) of \(party.targetSize), \(timer)")
    }

    private var timer: String {
        let left = Int(SpotRules.remaining(party, now: now))
        return String(format: "%d:%02d left", left / 60, left % 60)
    }
}

struct VoicePill: View {
    let room: VoiceRoom
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: SQSpace.s) {
                Image(systemName: "waveform")
                Text("\(room.title) · \(room.occupantIds.count)")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, SQSpace.l)
            .padding(.vertical, SQSpace.s)
            .background(SQColor.accent, in: Capsule())
            .foregroundStyle(.white)
        }
        .accessibilityLabel("\(room.title), \(room.occupantIds.count) in the voice room. Open the room.")
    }
}

struct StateBanner: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text(title).font(.headline)
            Text(detail).font(.body).foregroundStyle(SQColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqCard()
        .accessibilityElement(children: .combine)
    }
}
