import Combine
import SwiftUI
import UIKit

/// Onboarding (S5): email, code, and profile, one step at a time. The squad step
/// lives in the session screen under the home header (`OnboardingSquadStep`).
///
/// Each step is a scroll view, so it works up to AX5. Primary buttons are at least
/// 50pt tall; every other control is at least 44pt. Errors are read out when they appear.
struct OnboardingView: View {
    let model: LiveSessionModel
    let step: OnboardingStep
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focus: Field?

    enum Field: Hashable {
        case email, code, name, game, addGame
    }

    private var motion: MotionPolicy { .current(systemReduceMotion: systemReduceMotion) }

    /// At accessibility sizes "name@example.com" wrapped and hyphenated as
    /// "name@example.-com", so the big sizes get a placeholder with no address in it.
    static func emailPlaceholder(_ size: DynamicTypeSize) -> String {
        size.isAccessibilitySize ? "Your email" : "name@example.com"
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: errorKey) { _, _ in revealError(proxy) }
                .onChange(of: focus) { _, field in
                    if field != nil, field == errorField { revealError(proxy) }
                }
                // The keyboard arrives after focus moves; at AX5 it would cover the
                // error's lower lines, so line it up again once the keyboard is in.
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    if focus != nil, focus == errorField { revealError(proxy) }
                }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.l) {
                OnboardingHeader(step: step)
                Group {
                    switch step {
                    case .email: emailStep
                    case .code: codeStep
                    case .profile: OnboardingProfileStep(model: model, motion: motion, focus: $focus)
                    case .squad, .home: EmptyView()
                    }
                }
                .id(step)
                .transition(motion.stepTransition)
            }
            .padding(.vertical, SQSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .statusBarScrim()
        .animation(motion.animation(.stepChange), value: step)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding")
        // Not spoken as a value of anything useful; lets UI tests see the motion policy.
        .accessibilityValue(motion.label)
        .onAppear { focus = Self.firstField(step) }
        .onChange(of: step) { _, next in
            focus = Self.firstField(next)
            // VoiceOver moves to the new step's heading.
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    // MARK: Keeping errors above the keyboard

    /// The error showing on this step, as its identifier (also its scroll id). On the
    /// profile step the first one down the form wins.
    private var errorAnchor: String? {
        switch step {
        case .email, .code:
            return model.signInError.isEmpty ? nil : "signin-error"
        case .profile:
            if case .failed = model.profileLoad { return "onboarding-profile-load-error" }
            let draft = model.profileDraft
            if model.showProfileErrors, draft.nameError != nil { return "onboarding-name-error" }
            if model.showProfileErrors, draft.gameError != nil { return "onboarding-game-error" }
            if !model.gamesError.isEmpty { return "onboarding-games-error" }
            if !model.profileError.isEmpty { return "onboarding-profile-error" }
            return nil
        case .squad, .home:
            return nil
        }
    }

    /// Changes whenever a different error, or different text, appears.
    private var errorKey: String {
        guard let anchor = errorAnchor else { return "" }
        let text: String
        switch anchor {
        case "signin-error": text = model.signInError
        case "onboarding-name-error": text = model.profileDraft.nameError ?? ""
        case "onboarding-game-error": text = model.profileDraft.gameError ?? ""
        case "onboarding-games-error": text = model.gamesError
        case "onboarding-profile-error": text = model.profileError
        default: text = ""
        }
        return "\(anchor)|\(text)"
    }

    /// The field an error sits under. Focusing that field (and its keyboard coming
    /// up) brings the error back into view; focusing another field doesn't.
    private var errorField: Field? {
        switch errorAnchor ?? "" {
        case "signin-error": step == .code ? Field.code : Field.email
        case "onboarding-name-error": .name
        case "onboarding-game-error": .game
        case "onboarding-games-error": .addGame
        default: nil
        }
    }

    /// Scrolls so the whole error sits at the bottom of the visible area, which is
    /// above the keyboard when it's up. Waits a beat so the error has laid out.
    private func revealError(_ proxy: ScrollViewProxy) {
        guard let anchor = errorAnchor else { return }
        let motion = motion
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            withMotion(motion, .scroll) { proxy.scrollTo(anchor, anchor: .bottom) }
        }
    }

    private static func firstField(_ step: OnboardingStep) -> Field? {
        switch step {
        case .email: .email
        case .code: .code
        case .profile, .squad, .home: nil
        }
    }

    // MARK: Email

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            Text("We'll email you a 6-digit code. No password needed.")
                .font(SQType.detail)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingField(label: "Email") {
                TextField(Self.emailPlaceholder(typeSize), text: Binding(get: { model.email }, set: { model.email = $0 }))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .focused($focus, equals: .email)
                    .onSubmit { Task { await model.sendCode() } }
                    .accessibilityIdentifier("signin-email")
            }
            if !model.status.isEmpty {
                OnboardingNote(text: model.status, identifier: "signin-status")
            }
            OnboardingError(text: model.signInError, identifier: "signin-error", motion: motion)
            OnboardingPrimaryButton(
                title: "Send code",
                busyTitle: "Sending code…",
                busy: model.onboardingAction == .sending,
                identifier: "signin-send"
            ) {
                Task { await model.sendCode() }
            }
            .disabled(model.onboardingAction != nil)
            OnboardingFootnotes(lines: model.notes)
        }
    }

    // MARK: Code

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            Text("We sent a code to \(model.email). It can take a minute to arrive.")
                .font(SQType.detail)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("signin-sent-to")
            OnboardingField(label: "6-digit code") {
                TextField("Code", text: Binding(
                    get: { model.code },
                    set: { model.codeChanged($0) }
                ))
                .font(SQType.title.monospacedDigit())
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focus, equals: .code)
                .accessibilityIdentifier("signin-code")
            }
            OnboardingError(text: model.signInError, identifier: "signin-error", motion: motion)
            if !model.resentNote.isEmpty {
                OnboardingNote(text: model.resentNote, identifier: "signin-resent")
            }
            OnboardingPrimaryButton(
                title: "Verify",
                busyTitle: "Checking code…",
                busy: model.onboardingAction == .verifying,
                identifier: "signin-verify"
            ) {
                Task { await model.verify() }
            }
            .disabled(model.onboardingAction != nil)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let ready = model.resend.canResend(now: context.date)
                OnboardingSecondaryButton(
                    title: model.onboardingAction == .resending ? "Sending a new code…" : model.resend.label(now: context.date),
                    identifier: "signin-resend"
                ) {
                    Task { await model.resendCode() }
                }
                .disabled(!ready || model.onboardingAction != nil)
                .accessibilityLabel(model.resend.spoken(now: context.date))
            }
            OnboardingSecondaryButton(title: "Use a different email", identifier: "signin-change-email") {
                withMotion(motion, .stepChange) { model.changeEmail() }
            }
            .disabled(model.onboardingAction != nil)
        }
    }
}

// MARK: Profile

struct OnboardingProfileStep: View {
    let model: LiveSessionModel
    let motion: MotionPolicy
    var focus: FocusState<OnboardingView.Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            switch model.profileLoad {
            case .idle, .loading:
                OnboardingLoading(text: "Loading your profile…", identifier: "onboarding-profile-loading")
            case .failed(let reason):
                OnboardingError(text: reason, identifier: "onboarding-profile-load-error", motion: motion)
                OnboardingSecondaryButton(title: "Try again", identifier: "onboarding-profile-retry") {
                    Task { await model.loadOnboardingProfile() }
                }
            case .loaded:
                form
            }
            OnboardingSecondaryButton(title: "Use a different email", identifier: "onboarding-sign-out") {
                Task { await model.signOut() }
            }
            .disabled(model.onboardingAction != nil)
        }
    }

    private var draft: ProfileDraft { model.profileDraft }

    private var form: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            Text("This is how your group sees you. You can change it later in Members.")
                .font(SQType.detail)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingField(label: "Name") {
                TextField("Your name", text: Binding(get: { draft.name }, set: { model.profileDraft.name = $0 }))
                    .textContentType(.nickname)
                    .submitLabel(.next)
                    .focused(focus, equals: .name)
                    .onSubmit { focus.wrappedValue = .game }
                    .accessibilityIdentifier("onboarding-name")
            }
            OnboardingError(text: model.showProfileErrors ? (draft.nameError ?? "") : "", identifier: "onboarding-name-error", motion: motion)
            OnboardingField(label: "Default game") {
                TextField("Call of Duty", text: Binding(get: { draft.defaultGame }, set: { model.profileDraft.defaultGame = $0 }))
                    .submitLabel(.next)
                    .focused(focus, equals: .game)
                    .onSubmit { focus.wrappedValue = .addGame }
                    .accessibilityIdentifier("onboarding-default-game")
            }
            OnboardingError(text: model.showProfileErrors ? (draft.gameError ?? "") : "", identifier: "onboarding-game-error", motion: motion)
            games
            OnboardingError(text: model.profileError, identifier: "onboarding-profile-error", motion: motion)
            OnboardingPrimaryButton(
                title: "Continue",
                busyTitle: "Saving profile…",
                busy: model.onboardingAction == .savingProfile,
                identifier: "onboarding-save-profile"
            ) {
                Task { await model.saveOnboardingProfile() }
            }
            .disabled(model.onboardingAction != nil)
        }
    }

    private var games: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text("Games you play")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
            if draft.games.isEmpty {
                Text("No games yet. Add the ones you play so your group knows what to call.")
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding-games-empty")
            } else {
                ForEach(draft.games, id: \.self) { game in
                    gameRow(game)
                }
            }
            HStack(alignment: .center, spacing: SQSpace.s) {
                TextField("Add a game", text: Binding(get: { model.gameEntry }, set: { model.gameEntry = $0 }))
                    .padding(.horizontal, SQSpace.m)
                    .frame(minHeight: 44)
                    .background(SQColor.surface2, in: RoundedRectangle(cornerRadius: SQRadius.m, style: .continuous))
                    .submitLabel(.done)
                    .focused(focus, equals: .addGame)
                    .onSubmit { withMotion(motion, .appear) { model.addGameFromEntry() } }
                    .accessibilityLabel("Add a game")
                    .accessibilityIdentifier("onboarding-add-game")
                Button {
                    withMotion(motion, .appear) { model.addGameFromEntry() }
                } label: {
                    Text("Add")
                        .font(SQType.label)
                        .padding(.horizontal, SQSpace.m)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add game")
                .accessibilityIdentifier("onboarding-add-game-button")
            }
            OnboardingError(text: model.gamesError, identifier: "onboarding-games-error", motion: motion)
            let open = Array(draft.openSuggestions.prefix(4))
            if !open.isEmpty {
                Text("Popular")
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                WrapLayout(spacing: SQSpace.s) {
                    ForEach(open, id: \.self) { game in
                        Button {
                            withMotion(motion, .appear) { model.addSuggestedGame(game) }
                        } label: {
                            Text("+ \(game)")
                                .font(SQType.label)
                                .padding(.horizontal, SQSpace.m)
                                .frame(minHeight: 44)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SQColor.ink)
                        .background(SQColor.surface3, in: Capsule())
                        .accessibilityLabel("Add \(game)")
                        .accessibilityIdentifier("onboarding-suggest-\(game)")
                    }
                }
            }
            if let note = model.gamesHome?.note {
                OnboardingNote(text: note, identifier: "onboarding-games-note")
            }
        }
    }

    private func gameRow(_ game: String) -> some View {
        let isDefault = game.lowercased() == ProfileDraft.tidy(draft.defaultGame).lowercased()
        return HStack(alignment: .center, spacing: SQSpace.s) {
            Text(isDefault ? "\(game) · default" : game)
                .font(SQType.body)
                .foregroundStyle(SQColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withMotion(motion, .appear) { model.removeGame(game) }
            } label: {
                Image(systemName: "xmark")
                    .font(SQType.label)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SQColor.muted)
            .accessibilityLabel("Remove \(game)")
            .accessibilityIdentifier("onboarding-remove-\(game)")
        }
        .padding(.leading, SQSpace.m)
        .background(SQColor.surface2, in: RoundedRectangle(cornerRadius: SQRadius.m, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-game-\(game)")
    }
}

// MARK: Squad

/// The last setup step, under the home header so the account menu is there.
/// Also what someone sees after leaving a squad.
struct OnboardingSquadStep: View {
    let model: LiveSessionModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var motion: MotionPolicy { .current(systemReduceMotion: systemReduceMotion) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.l) {
                if model.reconnecting {
                    offline
                } else {
                    OnboardingHeader(step: .squad, showsProgress: model.onboardedThisSession)
                    Text("You're not in a group yet.")
                        .font(SQType.detail)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    join
                    create
                    if !model.status.isEmpty {
                        Text(model.status)
                            .font(SQType.caption)
                            .foregroundStyle(model.membershipIsError ? SQColor.danger : SQColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("onboarding-squad-status")
                    }
                }
                OnboardingFootnotes(lines: model.notes)
            }
            .padding(.vertical, SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .statusBarScrim()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-squad")
        .accessibilityValue(motion.label)
    }

    private var offline: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            Text("Reconnecting…")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reconnecting")
            Text("You're offline or the server didn't answer. Your group will load when the connection is back.")
                .font(SQType.detail)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingSecondaryButton(title: "Try again", identifier: "onboarding-retry") {
                Task { await model.retryConnection() }
            }
            .disabled(model.busy)
        }
    }

    private var join: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text("Join with an invite code")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
            OnboardingField(label: "Invite code") {
                TextField("ABCD2345", text: Binding(get: { model.joinCode }, set: { model.joinCode = $0 }))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.join)
                    .onSubmit { Task { await model.joinSquad() } }
                    .accessibilityIdentifier("join-code")
            }
            OnboardingPrimaryButton(title: "Join", busyTitle: "Joining…", busy: model.onboardingAction == .joining, identifier: "join-squad") {
                Task { await model.joinSquad() }
            }
            .disabled(model.busy)
        }
        .padding(SQSpace.m)
        .background(SQColor.surface1, in: RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous))
    }

    private var create: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text("Or start a group")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
            OnboardingField(label: "Group name") {
                TextField("Friday crew", text: Binding(get: { model.squadName }, set: { model.squadName = $0 }))
                    .submitLabel(.done)
                    .onSubmit { Task { await model.createSquad() } }
                    .accessibilityIdentifier("squad-name")
            }
            OnboardingError(text: model.squadNameError, identifier: "squad-name-error", motion: motion)
            OnboardingPrimaryButton(title: "Create group", busyTitle: "Creating group…", busy: model.onboardingAction == .creating, identifier: "create-squad") {
                Task { await model.createSquad() }
            }
            .disabled(model.busy)
        }
        .padding(SQSpace.m)
        .background(SQColor.surface1, in: RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous))
    }
}

// MARK: Pieces

struct OnboardingHeader: View {
    let step: OnboardingStep
    var showsProgress = true

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            if showsProgress, let progress = step.progress {
                Text(progress)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
            }
            Text(step.title)
                .font(SQType.title)
                .foregroundStyle(SQColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // One stop for VoiceOver, title first: "Sign in with email, Step 1 of 4, heading".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.spokenHeader(showsProgress: showsProgress))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding-header")
    }
}

/// A visible label above a rounded field. The label is the field's spoken name.
struct OnboardingField<Field: View>: View {
    let label: String
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            Text(label)
                .font(SQType.label)
                .foregroundStyle(SQColor.muted)
                .accessibilityHidden(true)
            field
                .accessibilityLabel(label)
                .padding(.horizontal, SQSpace.m)
                .frame(minHeight: 50)
                .background(SQColor.surface2, in: RoundedRectangle(cornerRadius: SQRadius.m, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SQRadius.m, style: .continuous)
                        .stroke(SQColor.hairline, lineWidth: 1)
                }
        }
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let busyTitle: String
    let busy: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SQSpace.s) {
                if busy {
                    ProgressView()
                        .tint(SQColor.onSignal)
                        .accessibilityHidden(true)
                }
                Text(busy ? busyTitle : title)
                    .font(SQType.label.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(SQColor.onSignal)
            .padding(.horizontal, SQSpace.l)
            .padding(.vertical, SQSpace.s)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(SQColor.signal, in: RoundedRectangle(cornerRadius: SQRadius.m, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(busy ? busyTitle : title)
        .accessibilityIdentifier(identifier)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SQType.label)
                .foregroundStyle(SQColor.accent)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// With the navigation bar hidden, scrolled content would slide under the status
/// bar and run into the clock. A zero-height top inset whose background fills the
/// top safe area keeps that strip opaque.
private struct StatusBarScrim: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(SQColor.surface0)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func statusBarScrim() -> some View { modifier(StatusBarScrim()) }
}

/// An error line. It appears with the motion policy and VoiceOver reads it out.
struct OnboardingError: View {
    let text: String
    let identifier: String
    let motion: MotionPolicy

    var body: some View {
        Group {
            if !text.isEmpty {
                // One Text with the icon inline: a separate hidden Image still showed up
                // to VoiceOver on iOS 26 as "exclamationmark.circle.fill".
                Text("\(Image(systemName: "exclamationmark.circle.fill")) \(text)")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.danger)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(text)
                    .accessibilityIdentifier(identifier)
                    // Scroll target, so the screen can keep the error above the keyboard.
                    .id(identifier)
                    .transition(motion.appearTransition)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: text) }
            }
        }
        .animation(motion.animation(.appear), value: text)
    }
}

struct OnboardingNote: View {
    let text: String
    let identifier: String

    var body: some View {
        Text(text)
            .font(SQType.caption)
            .foregroundStyle(SQColor.muted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }
}

struct OnboardingLoading: View {
    let text: String
    let identifier: String

    var body: some View {
        HStack(spacing: SQSpace.s) {
            ProgressView()
                .accessibilityHidden(true)
            Text(text)
                .font(SQType.detail)
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

struct OnboardingFootnotes: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, SQSpace.s)
    }
}

/// Lays chips out in rows, wrapping to the next row when one doesn't fit.
/// At AX5 each chip usually takes its own row.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
