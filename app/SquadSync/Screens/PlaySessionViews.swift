import SwiftUI

/// The scroll id of a session's card in the chat (the ForEach's row id too).
enum PlaySessionAnchor {
    static func id(_ session: UUID) -> String { "session-\(session.uuidString)" }
}

/// A play session as a card in the chat: what and when, who's in and who's
/// out, the note, and your own In / Out. Cancelled or finished sessions stay as
/// a muted card with no buttons. Rules and copy live in PlaySessions.swift.
///
/// VoiceOver reads the card's details as one element (game, time, how soon,
/// who's in and out, the note), then In, Out and Cancel as their own buttons.
/// Text wraps at every size; at accessibility sizes the buttons stack full width.
struct PlaySessionCard: View {
    let session: PlaySession
    let members: [SquadMemberRecord]
    let viewerId: UUID?
    var busy = false
    var error: String?
    let onRespond: (PlaySessionResponse) -> Void
    let onCancel: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Once a minute is enough for "Starts in 25 min" and for the card to mute when it ends.
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let roster = PlaySessionRoster.make(session, members: members, viewerId: viewerId)
        let time = PlaySessionTime.label(session.startsAt, now: now, clock: .current)
        let relative = PlaySessionTime.relative(session, now: now)
        let phase = PlaySessionRules.phase(session, now: now)
        let done = phase == .cancelled || phase == .over
        return VStack(alignment: .leading, spacing: SQSpace.s) {
            details(roster: roster, time: time, relative: relative, phase: phase, done: done)
            if !done {
                answers(roster.viewerResponse)
            }
            if let error, !error.isEmpty {
                Text(error)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("play-session-error-\(session.id.uuidString)")
            }
            if PlaySessionRules.canCancel(session, viewerId: viewerId, now: now) {
                Button(role: .destructive) {
                    onCancel()
                } label: {
                    Text("Cancel session")
                        .font(SQType.label)
                        .foregroundStyle(SQColor.danger)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .accessibilityLabel("Cancel the \(session.game) session")
                .accessibilityIdentifier("play-session-cancel-\(session.id.uuidString)")
            }
        }
        .padding(.horizontal, SQSpace.m)
        .padding(.vertical, SQSpace.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqSurface(.card, radius: SQRadius.m)
        .overlay {
            RoundedRectangle(cornerRadius: SQRadius.m)
                .stroke(done ? Color.clear : SQColor.signal.opacity(0.35), lineWidth: 1)
        }
        .padding(.vertical, SQSpace.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("play-session-card")
    }

    private func details(roster: PlaySessionRoster, time: String, relative: String?, phase: PlaySessionPhase, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SQSpace.xs) {
                Image(systemName: phase == .cancelled ? "calendar.badge.minus" : "calendar")
                    .foregroundStyle(done ? SQColor.subtle : SQColor.signal)
                Text("Play session")
                    .font(SQType.micro.weight(.semibold))
                    .foregroundStyle(SQColor.subtle)
                    .textCase(.uppercase)
            }
            Text(session.game)
                .font(SQType.section)
                .foregroundStyle(done ? SQColor.subtle : SQColor.ink)
                .strikethrough(phase == .cancelled)
                .fixedSize(horizontal: false, vertical: true)
            Text(time)
                .font(SQType.detail.weight(.semibold))
                .foregroundStyle(done ? SQColor.subtle : SQColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let relative {
                Text(relative)
                    .font(SQType.caption.weight(.semibold))
                    .foregroundStyle(relativeTint(phase))
                    .fixedSize(horizontal: false, vertical: true)
            }
            peopleLine("In", roster.going, done: done)
            peopleLine("Out", roster.out, done: done)
            if roster.going.isEmpty && roster.out.isEmpty {
                Text(PlaySessionCopy.noAnswers)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
            }
            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlaySessionCopy.spoken(session, roster: roster, time: time, relative: relative))
        .accessibilityValue(done ? "" : PlaySessionCopy.yourAnswer(roster.viewerResponse))
        .accessibilityIdentifier("play-session-summary-\(session.id.uuidString)")
    }

    @ViewBuilder
    private func peopleLine(_ title: String, _ names: [String], done: Bool) -> some View {
        if !names.isEmpty {
            (Text("\(title) \(names.count): ").font(SQType.caption.weight(.semibold))
                + Text(PlaySessionRoster.list(names)).font(SQType.caption))
                .foregroundStyle(done ? SQColor.subtle : SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func relativeTint(_ phase: PlaySessionPhase) -> Color {
        switch phase {
        case .live: SQColor.online
        case .upcoming: SQColor.warning
        case .over, .cancelled: SQColor.subtle
        }
    }

    private func answers(_ mine: PlaySessionResponse?) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
        return layout {
            answerButton(.going, selected: mine == .going)
            answerButton(.out, selected: mine == .out)
        }
    }

    private func answerButton(_ response: PlaySessionResponse, selected: Bool) -> some View {
        let going = response == .going
        let fill: Color = selected ? (going ? SQColor.signal : SQColor.surface3) : Color.clear
        let ink: Color = selected && going ? SQColor.onSignal : SQColor.ink
        return Button {
            SQHaptics.play(.tap)
            onRespond(response)
        } label: {
            HStack(spacing: SQSpace.xs) {
                if selected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text(going ? "In" : "Out")
            }
            .font(SQType.label)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fill, in: RoundedRectangle(cornerRadius: SQRadius.s))
            .overlay {
                RoundedRectangle(cornerRadius: SQRadius.s)
                    .stroke(selected ? Color.clear : SQColor.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(going ? "I'm in" : "I'm out")
        .accessibilityHint("For \(session.game)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("play-session-\(going ? "in" : "out")-\(session.id.uuidString)")
    }
}

/// The next session, pinned above the chat while it's coming up or on. Tapping
/// it opens the list. It's a thin strip: its text stops growing at AX1 and stays
/// one line, and its VoiceOver label reads the whole thing.
struct PlaySessionNextBar: View {
    let next: PlaySession
    let others: Int
    let members: [SquadMemberRecord]
    let viewerId: UUID?
    let now: Date
    let onOpen: () -> Void

    var body: some View {
        let roster = PlaySessionRoster.make(next, members: members, viewerId: viewerId)
        let live = PlaySessionRules.phase(next, now: now) == .live
        let time = live ? PlaySessionCopy.live : PlaySessionTime.label(next.startsAt, now: now, clock: .current)
        let line = PlaySessionCopy.nextLine(next, roster: roster, others: others, time: time)
        return Button {
            SQHaptics.play(.tap)
            onOpen()
        } label: {
            HStack(alignment: .center, spacing: SQSpace.s) {
                Image(systemName: "calendar")
                    .foregroundStyle(live ? SQColor.online : SQColor.signal)
                    .accessibilityHidden(true)
                Text(line)
                    .font(SQType.detail.weight(.semibold))
                    .foregroundStyle(SQColor.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: SQSpace.xs)
                Image(systemName: "chevron.right")
                    .font(SQType.caption.weight(.semibold))
                    .foregroundStyle(SQColor.subtle)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqSurface(.card, radius: SQRadius.m)
        .accessibilityLabel("Next play session: \(next.game), \(time). \(roster.summary). \(PlaySessionCopy.yourAnswer(roster.viewerResponse)).\(others > 0 ? " \(others) more scheduled." : "")")
        .accessibilityHint("Opens play sessions")
        .accessibilityIdentifier("play-next-bar")
    }
}

/// Play sessions: what's coming up (with your In / Out on each), or the form to
/// schedule one. Loading, a failed read, a stale list and a server without the
/// tables each say so in plain words.
struct PlaySessionsSheet: View {
    let model: LiveSessionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var cancelTarget: PlaySession?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case game
        case note
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: SQSpace.l) {
                        if model.playSheetSchedules {
                            form(now: context.date)
                        } else {
                            list(now: context.date)
                        }
                    }
                    .padding(SQSpace.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await model.retryPlaySessions() }
            }
            .background(SQColor.surface0)
            .navigationTitle(model.playSheetSchedules ? PlaySessionCopy.schedule : PlaySessionCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.playSheetSchedules ? "Not now" : "Done") { dismiss() }
                        .accessibilityIdentifier("play-sheet-close")
                }
            }
        }
        .presentationDetents(typeSize.isAccessibilitySize || model.playSheetSchedules ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SQColor.surface0)
        .task {
            if model.playLoad != .loaded { await model.refreshPlaySessions() }
        }
        .alert(
            cancelTarget.map { "Cancel \($0.game)?" } ?? "",
            isPresented: Binding(get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }),
            presenting: cancelTarget
        ) { target in
            Button("Cancel session", role: .destructive) {
                Task { await model.cancelPlaySession(target.id) }
            }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("Everyone in the group will see it's cancelled.")
        }
        .onDisappear {
            model.playSheetOpen = false
            model.playSheetSchedules = false
        }
    }

    // MARK: List

    @ViewBuilder
    private func list(now: Date) -> some View {
        let upcoming = PlaySessionRules.upcoming(model.playSessions, now: now)
        let display = model.playLoad.display(hasData: !model.playSessions.isEmpty)
        if let display {
            status(display)
        }
        if !model.playNote.isEmpty {
            Text(model.playNote)
                .font(SQType.caption)
                .foregroundStyle(SQColor.subtle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("play-note")
        }
        if display != .loading && !isBlocking(display) {
            if upcoming.isEmpty {
                Text(PlaySessionCopy.empty)
                    .font(SQType.detail)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("play-empty")
            } else {
                ForEach(upcoming) { session in
                    PlaySessionCard(
                        session: session,
                        members: model.squad?.members ?? [],
                        viewerId: model.chatViewerId,
                        busy: model.playBusy.contains(session.id),
                        error: model.playErrors[session.id],
                        onRespond: { response in Task { await model.respondToPlaySession(session.id, response) } },
                        onCancel: { cancelTarget = session }
                    )
                }
            }
        }
        if display != .unavailable {
            Button {
                SQHaptics.play(.tap)
                model.resetPlayDraft()
                model.playSheetSchedules = true
            } label: {
                Text(PlaySessionCopy.schedule)
                    .font(SQType.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(SQColor.signal)
            .foregroundStyle(SQColor.onSignal)
            .accessibilityIdentifier("play-open-form")
        }
    }

    private func isBlocking(_ display: PlaySessionLoad.Display?) -> Bool {
        switch display {
        case .failed, .unavailable: return true
        default: return false
        }
    }

    @ViewBuilder
    private func status(_ display: PlaySessionLoad.Display) -> some View {
        switch display {
        case .loading:
            HStack(spacing: SQSpace.s) {
                ProgressView()
                    .accessibilityHidden(true)
                Text(PlaySessionCopy.loading)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("play-loading")
        case .failed(let text):
            problem(text, identifier: "play-load-error", retry: true)
        case .stale:
            problem(PlaySessionCopy.stale, identifier: "play-stale", retry: true)
        case .unavailable:
            problem(PlaySessionCopy.unavailable, identifier: "play-unavailable", retry: false)
        }
    }

    private func problem(_ text: String, identifier: String, retry: Bool) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
        return layout {
            Text(text)
                .font(SQType.caption)
                .foregroundStyle(retry ? SQColor.danger : SQColor.subtle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            if retry {
                Button {
                    Task { await model.retryPlaySessions() }
                } label: {
                    Text("Try again")
                        .font(SQType.label)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Try loading sessions again")
                .accessibilityIdentifier("play-retry")
            }
        }
    }

    // MARK: Form

    @ViewBuilder
    private func form(now: Date) -> some View {
        let unavailable = model.playLoad.isUnavailable
        // A read that failed doesn't stop scheduling, but the sheet still says so.
        if let display = model.playLoad.display(hasData: !model.playSessions.isEmpty), display != .loading {
            status(display)
        }
        whenSection(now: now)
        gameSection
        noteSection
        if !model.playScheduleError.isEmpty {
            Text(model.playScheduleError)
                .font(SQType.caption)
                .foregroundStyle(SQColor.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("play-schedule-error")
        }
        Button {
            focused = nil
            SQHaptics.play(.tap)
            Task {
                if await model.schedulePlaySession() {
                    SQHaptics.play(.success)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: SQSpace.s) {
                if model.playScheduling {
                    ProgressView()
                        .accessibilityHidden(true)
                }
                Text(model.playScheduling ? "Scheduling…" : "Schedule")
            }
            .font(SQType.label)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(SQColor.signal)
        .foregroundStyle(SQColor.onSignal)
        .disabled(model.playScheduling || unavailable)
        .accessibilityIdentifier("play-schedule")
        Text("The group sees it in the chat and can say In or Out. You're put down as In.")
            .font(SQType.caption)
            .foregroundStyle(SQColor.subtle)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func whenSection(now: Date) -> some View {
        let start = model.playDraft.startsAt
        let label = PlaySessionTime.label(start, now: now, clock: .current)
        let soon = PlaySessionTime.relative(
            PlaySession(id: UUID(), squadId: UUID(), creatorId: UUID(), game: "", startsAt: start, durationMinutes: nil, note: nil, cancelledAt: nil, createdAt: now, rsvps: []),
            now: now
        )
        return VStack(alignment: .leading, spacing: SQSpace.s) {
            sectionTitle("When")
            Text(soon.map { "\(label) · \($0)" } ?? label)
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("play-form-when")
            quickPicks(now: now)
            DatePicker(
                "Pick a time",
                selection: Binding(get: { model.playDraft.startsAt }, set: { model.playDraft.startsAt = $0 }),
                in: now...now.addingTimeInterval(PlaySessionRules.horizon),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .font(SQType.detail)
            .accessibilityIdentifier("play-form-date")
        }
    }

    private func quickPicks(now: Date) -> some View {
        let picks = PlaySessionTime.quickPicks(now: now, clock: .current)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
        return layout {
            ForEach(picks) { pick in
                let selected = abs(model.playDraft.startsAt.timeIntervalSince(pick.date)) < 30
                Button {
                    SQHaptics.play(.selection)
                    model.playDraft.startsAt = pick.date
                } label: {
                    Text(pick.title)
                        .font(SQType.caption.weight(.semibold))
                        .foregroundStyle(selected ? SQColor.onSignal : SQColor.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, SQSpace.s)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                        .background(selected ? SQColor.signal : SQColor.surface2, in: RoundedRectangle(cornerRadius: SQRadius.s))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("play-pick-\(pick.id)")
            }
        }
    }

    private var gameSection: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            sectionTitle("Game")
            TextField(
                model.defaultGame.isEmpty ? "Game" : model.defaultGame,
                text: Binding(get: { model.playDraft.game }, set: { model.playDraft.game = $0 })
            )
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.words)
            .submitLabel(.next)
            .focused($focused, equals: .game)
            .onSubmit { focused = .note }
            .accessibilityLabel("Game")
            .accessibilityIdentifier("play-form-game")
            Text(PlaySessionCopy.gameHint)
                .font(SQType.caption)
                .foregroundStyle(SQColor.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noteSection: some View {
        let count = model.playDraft.note.count
        return VStack(alignment: .leading, spacing: SQSpace.xs) {
            sectionTitle("Note (optional)")
            TextField(
                "Quads, bring mics…",
                text: Binding(get: { model.playDraft.note }, set: { model.playDraft.note = $0 }),
                axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.roundedBorder)
            .focused($focused, equals: .note)
            .accessibilityLabel("Note, optional")
            .accessibilityIdentifier("play-form-note")
            if count > PlaySessionRules.maxNoteLength - 40 {
                Text("\(count) of \(PlaySessionRules.maxNoteLength)")
                    .font(SQType.caption.monospacedDigit())
                    .foregroundStyle(count > PlaySessionRules.maxNoteLength ? SQColor.danger : SQColor.subtle)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(SQType.label)
            .foregroundStyle(SQColor.subtle)
            .accessibilityAddTraits(.isHeader)
    }
}
