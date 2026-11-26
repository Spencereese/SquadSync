import PhotosUI
import SwiftUI
import UIKit

// MARK: Header

/// The chat-first header: the group's name and a Members button, nothing else.
/// Voice, side threads and sign out live in the Members panel. The identifiers
/// `squad-title` and `members` are the ones the UI tests have always used.
struct GroupHomeHeader: View {
    let squad: SquadRecord?
    let linkNote: String?
    let onMembers: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var large: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        HStack(alignment: .center, spacing: SQSpace.s) {
            Button {
                SQHaptics.play(.tap)
                onMembers()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SQSpace.xs) {
                        if linkNote != nil {
                            Circle()
                                .fill(SQColor.warning)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                        }
                        Text(SquadHeader.title(squad: squad))
                            .font(SQType.display)
                            .foregroundStyle(SQColor.ink)
                            .lineLimit(large ? 2 : 1)
                            .minimumScaleFactor(0.6)
                    }
                    if let linkNote, !large {
                        Text(linkNote)
                            .font(SQType.caption)
                            .foregroundStyle(SQColor.subtle)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(SquadHeader.spoken(squad: squad) ?? SquadHeader.noSquadTitle)
            .accessibilityValue(linkNote ?? "")
            .accessibilityHint("Opens members")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(squad == nil ? "squad-header-empty" : "squad-title")

            Button {
                SQHaptics.play(.tap)
                onMembers()
            } label: {
                Group {
                    if large {
                        Image(systemName: "person.2.fill")
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .accessibilityHidden(true)
                    } else {
                        Label("Members", systemImage: "person.2.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(SQType.label)
                .foregroundStyle(SQColor.ink)
                .padding(.horizontal, large ? 0 : SQSpace.m)
                .frame(minWidth: 44, minHeight: 44)
                .background(large ? Color.clear : SQColor.surface2, in: Capsule())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // One element: the symbol inside the label was exposed on its own, so
            // VoiceOver met "person.2.fill" and the tree had a second, unnamed button.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Members")
            .accessibilityHint("Invite, voice, side threads, your profile and sign out")
            .accessibilityIdentifier("members")
        }
        .padding(.vertical, SQSpace.xs)
    }
}

// MARK: Pinned area

/// Over the chat: open Game on cards (two at most), planned sessions that are
/// starting, and a small Game on button. With nothing on, only the button shows.
/// At accessibility sizes with the keyboard up it all steps aside for the composer.
struct GameOnPinnedArea: View {
    let model: LiveSessionModel
    let onInvite: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Idle expiry and planned starts are minutes apart, so a 30-second tick is plenty.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if typeSize.isAccessibilitySize {
                // At accessibility sizes two cards could push the chat off screen, so the
                // pinned area stops at a fixed height and scrolls inside it.
                // The cards' text stops growing at the first accessibility size, so one
                // card (with its Join, Ready, End) fits under the cap at AX5 and its
                // buttons stay on screen instead of scrolled out of the clipped area.
                ViewThatFits(in: .vertical) {
                    content(now: context.date)
                    ScrollView { content(now: context.date) }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .frame(maxHeight: Self.largeTextMaxHeight)
            } else {
                content(now: context.date)
            }
        }
    }

    /// Leaves the chat at least 40% of an iPhone screen at AX5.
    static let largeTextMaxHeight: CGFloat = 240

    @ViewBuilder
    private func content(now: Date) -> some View {
        let live = model.liveGameOns(now: now)
        let starting = model.startingSessions(now: now)
        VStack(alignment: .leading, spacing: SQSpace.s) {
            ForEach(live) { call in
                GameOnCard(
                    call: call,
                    names: model.memberNames,
                    viewerId: model.chatViewerId,
                    memberIds: model.groupMemberIds,
                    photo: { model.photoURL(for: $0) },
                    busy: model.gameOnBusy.contains(call.id),
                    error: model.gameOnErrors[call.id],
                    showsInvite: HomePrompts.showsInvite(memberCount: model.squad?.members.count ?? 0, dismissed: false),
                    onJoin: { Task { await model.joinGameOn(call.id) } },
                    onLeave: { Task { await model.leaveGameOn(call.id) } },
                    onReady: { ready in Task { await model.setGameOnReady(call.id, ready: ready) } },
                    onEnd: { Task { await model.closeGameOn(call.id) } },
                    onInvite: onInvite
                )
            }
            ForEach(starting) { session in
                PlannedGameOnCard(
                    session: session,
                    names: model.memberNames,
                    viewerId: model.chatViewerId,
                    busy: model.playBusy.contains(session.id),
                    error: model.playErrors[session.id],
                    onRespond: { response in Task { await model.respondToPlaySession(session.id, response) } }
                )
            }
            statusRow(liveCount: live.count)
            if !model.gameOnNote.isEmpty {
                Text(model.gameOnNote)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("game-on-note")
            }
            if model.gameOnLoad != .unavailable, GameOnRules.canStart(live: live) {
                GameOnButton { model.openGameOn() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusRow(liveCount: Int) -> some View {
        switch model.gameOnLoad {
        case .loading:
            if liveCount == 0 {
                HStack(spacing: SQSpace.s) {
                    ProgressView()
                    Text(GameOnCopy.loading)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.subtle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("game-on-loading")
            }
        case .failed(let text):
            HStack(spacing: SQSpace.s) {
                Text(text)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                // The frame sits on the label, not the Button, so the hit target and
                // the accessibility frame are both at least 44 pt.
                Button { Task { await model.retryGameOns() } } label: {
                    Text("Retry")
                        .font(SQType.label)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("game-on-retry")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("game-on-failed")
        case .unavailable:
            Text(GameOnCopy.unavailable)
                .font(SQType.caption)
                .foregroundStyle(SQColor.subtle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("game-on-unavailable")
        case .idle, .loaded:
            EmptyView()
        }
    }
}

/// The small "Game on" button. It's the only thing on top when nobody's playing.
struct GameOnButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            SQHaptics.play(.tap)
            action()
        } label: {
            Label(GameOnCopy.button, systemImage: "gamecontroller.fill")
                .font(SQType.label)
                .foregroundStyle(SQColor.onSignal)
                .padding(.horizontal, SQSpace.m)
                .frame(minHeight: 44)
                .background(SQColor.signal, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GameOnCopy.button)
        .accessibilityHint(GameOnCopy.buttonHint)
        .accessibilityIdentifier("game-on-button")
    }
}

// MARK: Card

struct GameOnCard: View {
    let call: GameOn
    let names: [UUID: String]
    let viewerId: UUID?
    let memberIds: Set<UUID>?
    let photo: (UUID) -> URL?
    let busy: Bool
    let error: String?
    let showsInvite: Bool
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onReady: (Bool) -> Void
    let onEnd: () -> Void
    let onInvite: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var seatSize: CGFloat = 30

    private var players: [GameOnSeat] { GameOnRules.players(call, memberIds: memberIds) }
    private var need: Int { GameOnRules.need(call, memberIds: memberIds) }
    private var state: GameOnRules.ViewerState { GameOnRules.viewerState(call, viewerId: viewerId, memberIds: memberIds) }

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            summary
            if !typeSize.isAccessibilitySize {
                seats
            }
            if showsInvite && need > 0 {
                Button {
                    SQHaptics.play(.tap)
                    onInvite()
                } label: {
                    Label("Invite someone to fill a seat", systemImage: "person.badge.plus")
                        .font(SQType.caption.weight(.semibold))
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("game-on-invite")
            }
            actions
            if let error {
                Text(error)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("game-on-error")
            }
        }
        .padding(SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.card, in: RoundedRectangle(cornerRadius: SQRadius.l))
        .overlay {
            RoundedRectangle(cornerRadius: SQRadius.l).stroke(SQColor.signal.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game-on-card")
    }

    /// One element for VoiceOver: who's on what, how many more, who's in.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: SQSpace.s)
                    needPill
                }
                VStack(alignment: .leading, spacing: SQSpace.xs) {
                    title
                    needPill
                }
            }
            // At accessibility sizes the names are read from the label, not drawn, so the card stays short.
            if !typeSize.isAccessibilitySize {
                Text("In: \(GameOnCopy.players(call, names: names, viewerId: viewerId, memberIds: memberIds))")
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameOnCopy.spoken(call, names: names, viewerId: viewerId, memberIds: memberIds))
        .accessibilityIdentifier("game-on-summary")
    }

    private var title: some View {
        Text(GameOnCopy.title(call, names: names, viewerId: viewerId))
            .font(SQType.section)
            .foregroundStyle(SQColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var needPill: some View {
        Text(GameOnCopy.needLabel(need))
            .font(SQType.label)
            .foregroundStyle(need == 0 ? SQColor.subtle : SQColor.signal)
            .padding(.horizontal, SQSpace.s)
            .padding(.vertical, 2)
            .background(SQColor.surface2, in: Capsule())
    }

    /// Faces for who's in, dashed circles for the open seats.
    private var seats: some View {
        HStack(spacing: SQSpace.xs) {
            ForEach(players) { seat in
                MemberAvatar(
                    url: photo(seat.userId),
                    name: GameOnCopy.name(seat.userId, names: names, viewerId: nil),
                    size: seatSize
                )
                .overlay(alignment: .bottomTrailing) {
                    if seat.ready {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(SQColor.signal)
                            .background(Circle().fill(SQColor.card))
                            .accessibilityHidden(true)
                    }
                }
            }
            ForEach(0..<min(need, SpotRules.squadCap), id: \.self) { _ in
                Circle()
                    .strokeBorder(SQColor.subtle, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: seatSize, height: seatSize)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SQSpace.s) { actionButtons }
            VStack(alignment: .leading, spacing: SQSpace.s) { actionButtons }
        }
        .disabled(busy)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .canJoin:
            Button {
                SQHaptics.play(.tap)
                onJoin()
            } label: {
                Text(busy ? "Joining…" : GameOnCopy.join)
                    .frame(minWidth: 88, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(SQColor.signal)
            .accessibilityLabel("Join \(call.game)")
            .accessibilityIdentifier("game-on-join")
        case .full:
            Text(GameOnCopy.full)
                .font(SQType.label)
                .foregroundStyle(SQColor.subtle)
                .frame(minHeight: 44)
                .accessibilityIdentifier("game-on-full")
        case .joined(let ready, let starter):
            Button {
                SQHaptics.play(.tap)
                onReady(!ready)
            } label: {
                Label(ready ? GameOnCopy.ready : "I'm ready", systemImage: ready ? "checkmark.circle.fill" : "circle")
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(ready ? "Ready" : "Mark yourself ready")
            .accessibilityValue(ready ? "On" : "Off")
            .accessibilityHint("Optional. Lets everyone know you're set.")
            .accessibilityIdentifier("game-on-ready")
            if starter {
                Button(role: .destructive) {
                    SQHaptics.play(.tap)
                    onEnd()
                } label: {
                    Text(GameOnCopy.end)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("End \(call.game)")
                .accessibilityIdentifier("game-on-end")
            } else {
                Button {
                    SQHaptics.play(.tap)
                    onLeave()
                } label: {
                    Text(GameOnCopy.leave)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Leave \(call.game)")
                .accessibilityIdentifier("game-on-leave")
            }
        }
    }
}

/// A planned session whose time has come, as a Game on card with "I'm in".
struct PlannedGameOnCard: View {
    let session: PlaySession
    let names: [UUID: String]
    let viewerId: UUID?
    let busy: Bool
    let error: String?
    let onRespond: (PlaySessionResponse) -> Void

    private var going: [String] {
        session.rsvps
            .filter { $0.response == .going }
            .map { GameOnCopy.name($0.userId, names: names, viewerId: viewerId) }
    }

    private var mine: PlaySessionResponse? {
        viewerId.flatMap { me in session.rsvps.first { $0.userId == me }?.response }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlannedGameOn.title(session, names: names, viewerId: viewerId))
                    .font(SQType.section)
                    .foregroundStyle(SQColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(going.isEmpty ? "Nobody's in yet" : "In: \(PlaySessionRoster.list(going))")
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("planned-game-on-summary")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SQSpace.s) { buttons }
                VStack(alignment: .leading, spacing: SQSpace.s) { buttons }
            }
            .disabled(busy)
            if let error {
                Text(error)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.card, in: RoundedRectangle(cornerRadius: SQRadius.l))
        .overlay {
            RoundedRectangle(cornerRadius: SQRadius.l).stroke(SQColor.signal.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("planned-game-on-card")
    }

    @ViewBuilder
    private var buttons: some View {
        if mine == .going {
            Label("You're in", systemImage: "checkmark.circle.fill")
                .font(SQType.label)
                .foregroundStyle(SQColor.signal)
                .frame(minHeight: 44)
                .accessibilityIdentifier("planned-you-are-in")
            Button("Can't make it") { onRespond(.out) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("planned-out")
        } else {
            Button {
                SQHaptics.play(.tap)
                onRespond(.going)
            } label: {
                Text("I'm in").frame(minWidth: 88, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(SQColor.signal)
            .accessibilityIdentifier("planned-im-in")
            if mine != .out {
                Button("Can't make it") { onRespond(.out) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("planned-out")
            }
        }
    }
}

// MARK: Chat line

/// Where a Game on started, as a small line between messages.
struct GameOnLineRow: View {
    let call: GameOn
    let names: [UUID: String]
    let viewerId: UUID?

    var body: some View {
        HStack(spacing: SQSpace.xs) {
            Image(systemName: "gamecontroller.fill")
                .foregroundStyle(SQColor.signal)
                .accessibilityHidden(true)
            Text(GameOnCopy.line(call, names: names, viewerId: viewerId))
                .foregroundStyle(SQColor.subtle)
                .fixedSize(horizontal: false, vertical: true)
            Text(ChatClock.current.time(call.calledAt))
                .foregroundStyle(SQColor.subtle.opacity(0.8))
        }
        .font(SQType.caption)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, SQSpace.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameOnCopy.spokenLine(call, names: names, viewerId: viewerId))
        .accessibilityIdentifier("game-on-line")
    }
}

// MARK: Sheet

struct GameOnSheet: View {
    let model: LiveSessionModel
    @State private var otherGame = ""
    @State private var choosingOther = false
    @FocusState private var otherFocused: Bool

    private var draft: GameOnDraft { model.gameOnDraft }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(draft.games, id: \.self) { game in
                        Button {
                            choosingOther = false
                            model.gameOnDraft.game = game
                        } label: {
                            HStack {
                                Text(game).foregroundStyle(SQColor.ink)
                                Spacer()
                                if !choosingOther && draft.game == game {
                                    Image(systemName: "checkmark").foregroundStyle(SQColor.signal).accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(!choosingOther && draft.game == game ? .isSelected : [])
                        .accessibilityIdentifier("game-on-game-\(game)")
                    }
                    Button {
                        choosingOther = true
                        model.gameOnDraft.game = otherGame
                        otherFocused = true
                    } label: {
                        HStack {
                            Text(draft.games.isEmpty ? "Type a game" : GameOnDraft.other).foregroundStyle(SQColor.ink)
                            Spacer()
                            if choosingOther || draft.games.isEmpty {
                                Image(systemName: "checkmark").foregroundStyle(SQColor.signal).accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(choosingOther || draft.games.isEmpty ? .isSelected : [])
                    .accessibilityIdentifier("game-on-game-other")
                    if choosingOther || draft.games.isEmpty {
                        TextField(GameOnCopy.otherGame, text: $otherGame)
                            .focused($otherFocused)
                            .textInputAutocapitalization(.words)
                            .onChange(of: otherGame) { _, value in model.gameOnDraft.game = value }
                            .accessibilityIdentifier("game-on-other-field")
                    }
                } header: {
                    Text(GameOnCopy.gamePrompt)
                }
                Section {
                    Stepper(value: Binding(get: { model.gameOnDraft.need }, set: { model.gameOnDraft.need = $0 }), in: GameOnRules.needRange) {
                        Text(model.gameOnDraft.need == 1 ? "1 more" : "\(model.gameOnDraft.need) more")
                            .accessibilityIdentifier("game-on-need-value")
                    }
                    .accessibilityIdentifier("game-on-need")
                } header: {
                    Text(GameOnCopy.needPrompt)
                } footer: {
                    Text("Everyone in the group gets a notification. Anyone can join until the seats fill.")
                }
                if !model.gameOnSheetError.isEmpty {
                    Section {
                        Text(model.gameOnSheetError)
                            .foregroundStyle(SQColor.danger)
                            .accessibilityIdentifier("game-on-sheet-error")
                    }
                }
            }
            .navigationTitle(GameOnCopy.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.gameOnSheetOpen = false }
                        .accessibilityIdentifier("game-on-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.gameOnStarting ? "Starting…" : GameOnCopy.start) {
                        SQHaptics.play(.tap)
                        Task { await model.startGameOn() }
                    }
                    .disabled(model.gameOnStarting || !model.gameOnDraft.canSubmit)
                    .accessibilityIdentifier("game-on-start")
                }
            }
            .onAppear {
                if draft.games.isEmpty { choosingOther = true }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: Prompts

/// The end of the thread when there's a nudge worth showing: "I'm on" right after
/// you join, an invite when the group is small, a photo early on.
struct HomePromptRows: View {
    let model: LiveSessionModel
    let onInvite: () -> Void
    @State private var picked: PhotosPickerItem?

    var body: some View {
        let live = model.liveGameOns().count
        VStack(alignment: .leading, spacing: SQSpace.s) {
            if HomePrompts.showsWelcome(justJoined: model.justJoined, liveCount: live) {
                promptCard(identifier: "welcome-prompt", onDismiss: { model.dismissWelcome() }, dismissId: "welcome-dismiss") {
                    Text(HomePrompts.welcomeTitle).font(SQType.section).foregroundStyle(SQColor.ink)
                    Text(HomePrompts.welcomeBody).font(SQType.caption).foregroundStyle(SQColor.subtle)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: SQSpace.s) { welcomeButtons }
                        VStack(alignment: .leading, spacing: SQSpace.s) { welcomeButtons }
                    }
                }
            }
            if live == 0, !model.justJoined,
               HomePrompts.showsInvite(memberCount: model.squad?.members.count ?? 0, dismissed: model.invitePromptDismissed) {
                promptCard(identifier: "invite-prompt", onDismiss: { model.dismissInvitePrompt() }, dismissId: "invite-prompt-dismiss") {
                    Text(HomePrompts.invitePrompt).font(SQType.detail).foregroundStyle(SQColor.ink)
                    Button {
                        SQHaptics.play(.tap)
                        onInvite()
                    } label: {
                        Label("Invite a friend", systemImage: "person.badge.plus").frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("invite-prompt-share")
                }
            }
            if HomePrompts.showsPhoto(hasPhoto: model.avatarURL != nil, dismissed: model.photoPromptDismissed, storageReady: model.avatarReady) {
                promptCard(identifier: "photo-prompt", onDismiss: { model.dismissPhotoPrompt() }, dismissId: "photo-prompt-dismiss") {
                    Text(HomePrompts.photoPrompt).font(SQType.detail).foregroundStyle(SQColor.ink)
                    PhotosPicker(selection: $picked, matching: .images) {
                        Label(model.avatarUploading ? "Uploading…" : HomePrompts.addPhoto, systemImage: "camera.fill")
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.avatarUploading)
                    .accessibilityIdentifier("photo-prompt-add")
                    if !model.avatarError.isEmpty {
                        Text(model.avatarError)
                            .font(SQType.caption)
                            .foregroundStyle(SQColor.danger)
                            .accessibilityIdentifier("photo-prompt-error")
                    }
                }
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                defer { picked = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let jpeg = AvatarImage.jpeg(from: data) else {
                    model.avatarError = "That photo couldn't be read. Try another."
                    return
                }
                await model.uploadAvatar(jpeg)
            }
        }
    }

    @ViewBuilder
    private var welcomeButtons: some View {
        Button {
            SQHaptics.play(.tap)
            Task { await model.sayImOn() }
        } label: {
            Text(HomePrompts.imOnMessage).frame(minWidth: 88, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(SQColor.signal)
        .accessibilityHint("Sends \"I'm on\" to the group")
        .accessibilityIdentifier("welcome-im-on")
        Button {
            SQHaptics.play(.tap)
            model.openGameOn()
        } label: {
            Label(GameOnCopy.button, systemImage: "gamecontroller.fill").frame(minHeight: 36)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("welcome-game-on")
    }

    private func promptCard<Content: View>(
        identifier: String,
        onDismiss: @escaping () -> Void,
        dismissId: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: SQSpace.s) {
            VStack(alignment: .leading, spacing: SQSpace.s) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(SQType.caption.weight(.bold))
                    .foregroundStyle(SQColor.subtle)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(HomePrompts.notNow)
            .accessibilityIdentifier(dismissId)
        }
        .padding(SQSpace.m)
        .background(SQColor.surface2, in: RoundedRectangle(cornerRadius: SQRadius.l))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// Shrinks a picked photo to a 512-point square-ish JPEG before upload.
enum AvatarImage {
    static let side: CGFloat = 512

    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

// MARK: Avatar

/// A member's photo when there is one; their initial when there isn't (or it
/// hasn't loaded). Decorative: the name is always said next to it.
struct MemberAvatar: View {
    let url: URL?
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(SQColor.surface3)
            Text(ChatBubbleSide.initial(name))
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(SQColor.ink)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

// MARK: Invite (Members panel)

/// Any member can share the link. The owner role only matters for removing people.
struct InviteShareSection: View {
    let model: LiveSessionModel

    private var full: Bool { (model.squad?.members.count ?? 0) >= SpotRules.squadCap }

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            if full {
                Text("The group is full (8). Someone has to leave before anyone new can join.")
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("invite-full")
            } else if model.inviteCode.isEmpty {
                Text("Share a link. Whoever taps it joins, until the group has 8.")
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("invite-empty")
                Button {
                    Task { await model.shareInvite() }
                } label: {
                    Text("Make an invite link").frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy)
                .accessibilityIdentifier("create-invite")
            } else {
                Text(model.inviteCode)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .accessibilityLabel("Invite code \(model.inviteCode.map(String.init).joined(separator: " "))")
                    .accessibilityIdentifier("invite-code")
                Text(InviteLink.expiryNote(model.inviteExpires, now: Date()))
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SQSpace.s) { shareButtons }
                    VStack(alignment: .leading, spacing: SQSpace.s) { shareButtons }
                }
            }
        }
    }

    @ViewBuilder
    private var shareButtons: some View {
        let text = model.inviteShareText.isEmpty
            ? InviteLink.shareText(groupName: model.squad?.name ?? "", code: model.inviteCode)
            : model.inviteShareText
        ShareLink(item: text) {
            Label("Share link", systemImage: "square.and.arrow.up").frame(minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("share-invite-link")
        Button {
            UIPasteboard.general.string = InviteLink.url(code: model.inviteCode)?.absoluteString ?? model.inviteCode
            model.membershipIsError = false
            model.status = "Copied."
        } label: {
            Text("Copy").frame(minHeight: 36)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("copy-invite")
    }
}

/// Your photo in the Members panel: add or change it. Shown only when the
/// photo storage answered, so it never offers something that can't save.
struct ProfilePhotoRow: View {
    let model: LiveSessionModel
    @State private var picked: PhotosPickerItem?

    var body: some View {
        HStack(spacing: SQSpace.m) {
            MemberAvatar(url: model.avatarURL, name: model.displayName, size: 48)
            VStack(alignment: .leading, spacing: SQSpace.xs) {
                PhotosPicker(selection: $picked, matching: .images) {
                    Text(model.avatarUploading ? "Uploading…" : (model.avatarURL == nil ? "Add a photo" : "Change photo"))
                        .frame(minHeight: 44)
                }
                .disabled(model.avatarUploading)
                .accessibilityIdentifier("profile-photo")
                if !model.avatarError.isEmpty {
                    Text(model.avatarError)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                defer { picked = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let jpeg = AvatarImage.jpeg(from: data) else {
                    model.avatarError = "That photo couldn't be read. Try another."
                    return
                }
                await model.uploadAvatar(jpeg)
            }
        }
    }
}
