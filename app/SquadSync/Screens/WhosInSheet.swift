import SwiftUI

/// Who's in (redesign S4): your own check-in, then the squad by availability,
/// each with what they're playing and where that came from, then the sources.
/// Rules and copy live in `WhosIn.swift`; this only draws them.
///
/// Every row is one VoiceOver element whose label says the status, the game,
/// and its source. Text wraps at every size; at accessibility sizes the sheet
/// opens large and the check-in buttons stack full width.
struct WhosInSheet: View {
    let model: LiveSessionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsLater = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(now: context.date)
            }
            .background(SQColor.surface0)
            .navigationTitle(WhosIn.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("whos-in-done")
                }
            }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SQColor.surface0)
        .onDisappear { model.whosInOpen = false }
    }

    private func content(now: Date) -> some View {
        let entries = model.whosInEntries(now: now)
        let others = entries.filter { !$0.isViewer }
        let display = model.whosInLoad.display(hasData: !model.checkIns.isEmpty)
        let blocking = display == .loading || isFailed(display)
        return ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.l) {
                if !blocking && model.checkInCaps.table {
                    Text(WhosIn.summary(others))
                        .font(SQType.detail.weight(.semibold))
                        .foregroundStyle(SQColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("whos-in-summary")
                }
                if let display {
                    loadRow(display)
                }
                checkInCard(now: now)
                if !blocking {
                    if others.isEmpty {
                        Text(WhosIn.emptyNote)
                            .font(SQType.detail)
                            .foregroundStyle(SQColor.subtle)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("whos-in-empty")
                    } else {
                        ForEach(WhosIn.sections(others)) { group in
                            section(group, now: now)
                        }
                    }
                }
                sources
            }
            .padding(SQSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .refreshable { await model.loadWhosIn(includeSteam: true) }
        .accessibilityIdentifier("whos-in-sheet")
    }

    private func isFailed(_ display: WhosInLoad.Display?) -> Bool {
        if case .failed = display { return true }
        return false
    }

    // MARK: Load states

    @ViewBuilder
    private func loadRow(_ display: WhosInLoad.Display) -> some View {
        switch display {
        case .loading:
            HStack(spacing: SQSpace.s) {
                ProgressView()
                    .accessibilityHidden(true)
                Text(WhosIn.loadingText)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("whos-in-loading")
        case .failed(let reason):
            problemRow(reason, identifier: "whos-in-error")
        case .stale:
            problemRow(WhosIn.staleNote, identifier: "whos-in-stale")
        }
    }

    private func problemRow(_ text: String, identifier: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
        return layout {
            Text(text)
                .font(SQType.caption)
                .foregroundStyle(SQColor.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            Button {
                Task { await model.retryWhosIn() }
            } label: {
                Text("Retry")
                    .font(SQType.label)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Retry loading who's in")
            .accessibilityIdentifier("whos-in-retry")
        }
    }

    // MARK: Your check-in

    private func checkInCard(now: Date) -> some View {
        let mine = model.myAvailability(now: now)
        return VStack(alignment: .leading, spacing: SQSpace.s) {
            Text("Your check-in")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
            if !model.checkInCaps.table {
                Text(WhosIn.untrackedNote)
                    .font(SQType.detail)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("check-in-unavailable")
            } else {
                Text(myStatus(mine, now: now))
                    .font(SQType.detail)
                    .foregroundStyle(SQColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("check-in-status")
                if model.checkInCaps.details {
                    detailFields
                } else {
                    Text(WhosIn.detailsMissing)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("check-in-details-missing")
                }
                checkInButtons(mine)
                if showsLater {
                    laterOptions(now: now)
                }
                if !model.checkInError.isEmpty {
                    Text(model.checkInError)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("check-in-error")
                }
                Text(WhosIn.honorNote)
                    .font(SQType.micro)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("check-in-honor")
            }
        }
        .padding(SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.surface1, in: RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("check-in-card")
    }

    private func myStatus(_ availability: WhosInAvailability, now: Date) -> String {
        switch availability {
        case .now(let until): return "You're on until \(WhosIn.time(until))."
        case .later(let at): return at > now ? "You said around \(WhosIn.time(at))." : "You said around \(WhosIn.time(at)). That time has passed."
        case .cantPlay: return "You said you can't play."
        case .notCheckedIn: return "You haven't checked in."
        case .untracked: return WhosIn.untrackedNote
        }
    }

    private var detailFields: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            TextField("Game (optional)", text: Binding(get: { model.checkInGame }, set: { model.checkInGame = $0 }))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .accessibilityIdentifier("check-in-game")
            Picker(selection: Binding(get: { model.checkInPlatform }, set: { model.checkInPlatform = $0 })) {
                Text("No console").tag(CheckInPlatform?.none)
                ForEach(CheckInPlatform.allCases) { platform in
                    Text(platform.label).tag(Optional(platform))
                }
            } label: {
                Text("Console")
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("check-in-platform")
        }
    }

    private func checkInButtons(_ mine: WhosInAvailability) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SQSpace.s) { checkInButtonSet(mine) }
            VStack(alignment: .leading, spacing: SQSpace.s) { checkInButtonSet(mine) }
        }
        .disabled(model.checkInBusy)
    }

    @ViewBuilder
    private func checkInButtonSet(_ mine: WhosInAvailability) -> some View {
        actionButton("I'm on now", identifier: "check-in-now", prominent: true) {
            showsLater = false
            Task { await model.checkIn(.availableNow) }
        }
        actionButton("Later", identifier: "check-in-later", prominent: false) {
            showsLater.toggle()
        }
        .accessibilityValue(showsLater ? "Times shown" : "")
        actionButton("Can't play", identifier: "check-in-cant", prominent: false) {
            showsLater = false
            Task { await model.checkIn(.unavailable) }
        }
        if mine != .notCheckedIn && mine != .untracked {
            actionButton("Clear", identifier: "check-in-clear", prominent: false) {
                showsLater = false
                Task { await model.clearCheckIn() }
            }
        }
    }

    private func actionButton(_ title: String, identifier: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SQType.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, SQSpace.s)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(prominent ? SQColor.signal : SQColor.subtle)
        .accessibilityIdentifier(identifier)
    }

    private func laterOptions(now: Date) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ForEach(CheckInRules.laterOptions(now: now)) { option in
                Button {
                    showsLater = false
                    Task { await model.checkIn(.availableLater, laterAt: option.at) }
                } label: {
                    Text("\(option.label) · \(WhosIn.time(option.at))")
                        .font(SQType.detail)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(option.label), around \(WhosIn.time(option.at))")
                .accessibilityIdentifier("check-in-later-option")
            }
        }
    }

    // MARK: The squad

    private func section(_ group: WhosIn.Section, now: Date) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text("\(group.section.title) · \(group.entries.count)")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(group.section.identifier)
            ForEach(group.entries) { entry in
                WhosInRow(entry: entry, now: now)
            }
        }
    }

    // MARK: Sources

    private var sources: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            Text("Where this comes from")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(sourceLines, id: \.self) { line in
                Text(line)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("whos-in-sources")
    }

    private var sourceLines: [String] {
        [
            WhosIn.checkInSource(model.checkInCaps),
            WhosIn.steamSource(model.steam),
            WhosIn.xboxSource,
            WhosIn.spotSource
        ]
    }
}

/// One member: avatar, name, availability, seat, and the game with its source tag.
struct WhosInRow: View {
    let entry: WhosInEntry
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: SQSpace.s) {
            SQAvatar(initial: entry.initial, status: entry.ringStatus, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(SQType.detail.weight(.semibold))
                    .foregroundStyle(SQColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.statusLine(now: now))
                    .font(SQType.caption)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
                if let seat = entry.seatLine {
                    Text(seat)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.signal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let game = entry.gameLine, let source = entry.gameSource {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: SQSpace.xs) {
                            gameText(game, source: source)
                            tag(source)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            gameText(game, source: source)
                            tag(source)
                        }
                    }
                }
                if let note = entry.steamNote {
                    Text(note)
                        .font(SQType.micro)
                        .foregroundStyle(SQColor.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, SQSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.spokenLabel(now: now))
        .accessibilityIdentifier("whos-in-row-\(entry.displayName)")
    }

    private var statusColor: Color {
        switch entry.availability {
        case .now: SQColor.online
        case .later: SQColor.warning
        case .cantPlay: SQColor.danger
        case .notCheckedIn, .untracked: SQColor.subtle
        }
    }

    private func gameText(_ game: String, source: WhosInGameSource) -> some View {
        Text(game)
            .font(SQType.caption)
            .italic(source == .profile)
            .foregroundStyle(source == .profile ? SQColor.subtle : SQColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tag(_ source: WhosInGameSource) -> some View {
        Text(source.tag)
            .font(SQType.micro.weight(.semibold))
            .foregroundStyle(SQColor.subtle)
            .padding(.horizontal, SQSpace.xs)
            .padding(.vertical, 1)
            .overlay(Capsule().stroke(SQColor.hairline, lineWidth: 1))
            .fixedSize()
    }
}
