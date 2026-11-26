import SwiftUI

/// A side thread (side group or DM), opened over the squad chat by a reply's push.
/// It loads the thread's newest page with the tapped reply scrolled into view, picks
/// up new replies while it's open, and lets you answer. Close returns to the chat.
struct SideThreadView: View {
    let model: LiveSessionModel
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How often an open thread reads newer replies.
    static let refreshSeconds: UInt64 = 4

    var body: some View {
        if let panel = model.sideThread {
            VStack(spacing: 0) {
                header(panel)
                Rectangle()
                    .fill(SQColor.hairline)
                    .frame(height: 1)
                content(panel)
                if panel.load == .ready {
                    composer(panel)
                }
            }
            .background(SQColor.surface0.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(SideThreadIdentifiers.panel)
            .accessibilityAddTraits(.isModal)
            .task(id: panel.threadId) {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Self.refreshSeconds * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    await model.refreshSideThread()
                }
            }
        }
    }

    private func header(_ panel: SideThreadPanel) -> some View {
        HStack(alignment: .center, spacing: SQSpace.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SideThreadCopy.title(
                    info: panel.info,
                    memberIds: panel.memberIds,
                    viewerId: model.viewerId,
                    names: model.memberNames
                ))
                .font(SQType.title)
                .foregroundStyle(SQColor.ink)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(SideThreadIdentifiers.title)
                let context = SideThreadCopy.context(info: panel.info, memberIds: panel.memberIds)
                if !context.isEmpty {
                    Text(context)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.muted)
                        .accessibilityIdentifier(SideThreadIdentifiers.context)
                }
            }
            Spacer(minLength: SQSpace.s)
            Button(model.sideThreadsOpen ? SideThreadCopy.back : SideThreadCopy.close) {
                composerFocused = false
                model.closeSideThread()
            }
            .font(SQType.label)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier(SideThreadIdentifiers.close)
        }
        .padding(.horizontal, SQSpace.l)
        .padding(.vertical, SQSpace.s)
    }

    @ViewBuilder
    private func content(_ panel: SideThreadPanel) -> some View {
        switch panel.load {
        case .loading:
            centered {
                ProgressView()
                Text(SideThreadCopy.loading)
                    .font(SQType.detail)
                    .foregroundStyle(SQColor.muted)
            }
        case .failed:
            centered {
                Text(SideThreadCopy.failed)
                    .font(SQType.body)
                    .foregroundStyle(SQColor.ink)
                    .accessibilityIdentifier(SideThreadIdentifiers.note)
                Button("Try again") {
                    Task { await model.loadSideThread() }
                }
                .buttonStyle(.bordered)
            }
        case .notFound:
            centered {
                Text(SideThreadCopy.notFound)
                    .font(SQType.body)
                    .foregroundStyle(SQColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(SideThreadIdentifiers.note)
            }
        case .ready:
            messageList(panel)
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: SQSpace.m) {
            content()
        }
        .padding(SQSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageList(_ panel: SideThreadPanel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: SQSpace.s) {
                    if !panel.note.isEmpty {
                        Text(panel.note)
                            .font(SQType.caption)
                            .foregroundStyle(SQColor.muted)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier(SideThreadIdentifiers.note)
                    }
                    if panel.messages.isEmpty {
                        Text(SideThreadCopy.empty)
                            .font(SQType.detail)
                            .foregroundStyle(SQColor.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, SQSpace.xl)
                    }
                    ForEach(Array(panel.messages.enumerated()), id: \.element.id) { index, message in
                        let previous = index > 0 ? panel.messages[index - 1] : nil
                        row(message, showsName: previous?.senderId != message.senderId)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, SQSpace.l)
                .padding(.vertical, SQSpace.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier(SideThreadIdentifiers.list)
            .onAppear {
                // After the first layout, so the rows exist to scroll to.
                DispatchQueue.main.async { scroll(proxy, panel: panel, animated: false) }
            }
            .onChange(of: panel.focus) { _, _ in scroll(proxy, panel: panel, animated: true) }
            .onChange(of: panel.messages.count) { _, _ in
                // A new reply while you're reading the tapped one doesn't yank you away;
                // only your own send moves focus (and so the scroll) to the bottom.
                if panel.focus == nil { scroll(proxy, panel: panel, animated: true) }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, panel: SideThreadPanel, animated: Bool) {
        let target = panel.focusLoaded ? panel.focus : panel.messages.last?.id
        guard let target else { return }
        let anchor: UnitPoint = target == panel.messages.last?.id ? .bottom : .center
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(target, anchor: anchor) }
        } else {
            proxy.scrollTo(target, anchor: anchor)
        }
    }

    private func row(_ message: SideThreadMessage, showsName: Bool) -> some View {
        let mine = message.senderId == model.viewerId
        let name = model.senderName(message.senderId)
        return VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            if showsName && !mine {
                Text(name)
                    .font(SQType.caption.weight(.semibold))
                    .foregroundStyle(SQColor.muted)
            }
            Text(message.body)
                .font(SQType.body)
                .foregroundStyle(mine ? Color.white : SQColor.ink)
                .padding(.horizontal, SQSpace.m)
                .padding(.vertical, SQSpace.s)
                .background(
                    RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous)
                        .fill(mine ? SQColor.mine : SQColor.theirs)
                )
                .textSelection(.enabled)
            Text(message.sentAt, style: .time)
                .font(SQType.micro)
                .foregroundStyle(SQColor.subtle)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mine ? ChatThread.you : name): \(message.body)")
        .accessibilityIdentifier(SideThreadIdentifiers.row(message.id))
    }

    private func composer(_ panel: SideThreadPanel) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            if !panel.sendError.isEmpty {
                Text(panel.sendError)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.danger)
            }
            HStack(alignment: .bottom, spacing: SQSpace.s) {
                TextField(
                    SideThreadCopy.placeholder,
                    text: Binding(
                        get: { model.sideThread?.draft ?? "" },
                        set: { model.sideThread?.draft = $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, SQSpace.m)
                .padding(.vertical, SQSpace.s)
                .background(
                    RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous)
                        .fill(SQColor.surface2)
                )
                .focused($composerFocused)
                .accessibilityIdentifier(SideThreadIdentifiers.composer)
                Button {
                    Task { await model.sendSideThreadReply() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!panel.canSend)
                .accessibilityLabel("Send")
                .accessibilityIdentifier(SideThreadIdentifiers.send)
            }
        }
        .padding(.horizontal, SQSpace.l)
        .padding(.vertical, SQSpace.s)
        .background(SQColor.surface1)
    }
}
