import SwiftUI

struct PresenceAvatar: View {
    let person: Person
    var size: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(String(person.name.prefix(1)))
                .font(.headline)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: dimension, height: dimension)
                .background(SQColor.card, in: Circle())
                .overlay(Circle().stroke(ring, lineWidth: person.inVoice || person.isOnline ? 2.5 : 1))
            if person.inGame {
                badge("gamecontroller.fill", fill: SQColor.accent, foreground: .white)
            } else if person.inVoice {
                badge("speaker.wave.2.fill", fill: SQColor.online, foreground: .black)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var dimension: CGFloat {
        typeSize.isAccessibilitySize ? size + 18 : size
    }

    private func badge(_ symbol: String, fill: Color, foreground: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .dynamicTypeSize(.large)
            .padding(3)
            .background(fill, in: Circle())
            .foregroundStyle(foreground)
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
    var compact = false

    var body: some View {
        if compact {
            Label(role.title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .dynamicTypeSize(.large ... .xxxLarge)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .accessibilityLabel("\(role.title) role")
        } else {
            Text(role.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(SQColor.ink)
                .background(SQColor.role(role).opacity(0.85), in: Capsule())
                .accessibilityLabel("\(role.title) role")
        }
    }

    private var symbol: String {
        switch role {
        case .owner: "crown.fill"
        case .admin: "shield.fill"
        case .member: "person.fill"
        case .guest: "person.badge.plus"
        }
    }
}

struct FormingDock: View {
    let party: Party
    var now: Date
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let timer = party.locked ? "Locked" : "\(SpotRules.countdownText(party, now: now)) left"
        return HStack(spacing: SQSpace.m) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(SQColor.warning)
                        .lineLimit(1)
                    Text("\(party.game) · \(SpotRules.filled(party))/\(party.targetSize)")
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: SQSpace.s)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(party.game) · \(SpotRules.filled(party))/\(party.targetSize)")
                        .font(.headline)
                        .lineLimit(2)
                    Text(timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(SQColor.warning)
                }
                Spacer(minLength: SQSpace.s)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(SQColor.muted)
        }
        .sqCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(party.game), \(SpotRules.filled(party)) of \(party.targetSize), \(timer)")
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
