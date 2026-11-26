import SwiftUI

/// Your side threads (side groups and DMs) for this squad, with a way to start one.
/// It sits over the squad chat like `SideThreadView`, and tapping a row opens that
/// same view. Loading, empty, and error each say what's happening.
struct SideThreadListView: View {
    let model: LiveSessionModel
    @FocusState private var nameFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    /// How often the open list reads again.
    static let refreshSeconds: UInt64 = 8

    var body: some View {
        VStack(spacing: 0) {
            if model.sideThreadDraft != nil {
                form
            } else {
                list
            }
        }
        .background(SQColor.surface0.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SideThreadIdentifiers.listPanel)
        .accessibilityAddTraits(.isModal)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.refreshSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                // Covered by a thread opened from it: Back reads it again anyway.
                if model.sideThreadDraft == nil, model.sideThread == nil { await model.loadSideThreads(showLoading: false) }
            }
        }
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 0) {
            bar(
                title: SideThreadCopy.listTitle,
                leading: (SideThreadCopy.close, SideThreadIdentifiers.listClose, { model.closeSideThreadList() }),
                trailing: (SideThreadCopy.newThread, SideThreadIdentifiers.listNew, { model.beginNewSideThread() })
            )
            Rectangle().fill(SQColor.hairline).frame(height: 1)
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let state = model.sideThreadList
        switch state.load {
        case .idle, .loading:
            centered {
                ProgressView()
                Text(SideThreadCopy.listLoading)
                    .font(SQType.detail)
                    .foregroundStyle(SQColor.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(SideThreadIdentifiers.listLoading)
        case .failed:
            centered {
                Text(SideThreadCopy.listFailed)
                    .font(SQType.body)
                    .foregroundStyle(SQColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(SideThreadIdentifiers.listError)
                Button("Try again") {
                    Task { await model.loadSideThreads() }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier(SideThreadIdentifiers.listRetry)
            }
        case .ready:
            if state.rows.isEmpty {
                centered {
                    Text(SideThreadCopy.listEmpty)
                        .font(SQType.body)
                        .foregroundStyle(SQColor.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(SideThreadIdentifiers.listEmpty)
                    Button(SideThreadCopy.newTitle) { model.beginNewSideThread() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
            } else {
                rows(state.rows)
            }
        }
    }

    private func rows(_ rows: [SideThreadRow]) -> some View {
        let names = model.memberNames
        let now = Date()
        return ScrollView {
            // A plain stack: a lazy one hangs the layout at accessibility sizes (known-issues.md), and a squad has few threads.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    rowButton(row, names: names, now: now)
                    Rectangle().fill(SQColor.hairline).frame(height: 1)
                }
            }
            .padding(.horizontal, SQSpace.l)
        }
        .accessibilityIdentifier(SideThreadIdentifiers.listScroll)
    }

    private func rowButton(_ row: SideThreadRow, names: [UUID: String], now: Date) -> some View {
        let title = SideThreadCopy.title(info: row.info, memberIds: row.memberIds, viewerId: model.viewerId, names: names)
        let preview = SideThreadCopy.preview(row, viewerId: model.viewerId, names: names)
        let when = row.last.map { SideThreadCopy.when($0.sentAt, now: now) }
        return Button {
            model.openThreadFromList(row.id)
        } label: {
            HStack(alignment: .top, spacing: SQSpace.m) {
                Image(systemName: row.isDirect ? "person.fill" : "person.3.fill")
                    .font(.body)
                    .foregroundStyle(SQColor.muted)
                    .frame(width: 28)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    if typeSize.isAccessibilitySize {
                        Text(title).font(SQType.section)
                        if let when { Text(when).font(SQType.caption).foregroundStyle(SQColor.subtle) }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text(title).font(SQType.section).lineLimit(1)
                            Spacer(minLength: SQSpace.s)
                            if let when { Text(when).font(SQType.caption).foregroundStyle(SQColor.subtle) }
                        }
                    }
                    Text(preview)
                        .font(SQType.detail)
                        .foregroundStyle(SQColor.muted)
                        .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(SQColor.ink)
            .padding(.vertical, SQSpace.m)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SideThreadCopy.spoken(row, title: title, viewerId: model.viewerId, names: names, now: now))
        .accessibilityHint("Opens this side thread")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(SideThreadIdentifiers.listRow(row.id))
    }

    // MARK: New side thread

    private var form: some View {
        let draft = model.sideThreadDraft ?? SideThreadDraft()
        let people = model.sideThreadCandidates
        return VStack(spacing: 0) {
            bar(
                title: SideThreadCopy.newTitle,
                leading: ("Cancel", SideThreadIdentifiers.formCancel, {
                    nameFocused = false
                    model.cancelNewSideThread()
                }),
                trailing: nil
            )
            Rectangle().fill(SQColor.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: SQSpace.s) {
                    Text(SideThreadCopy.pickPrompt)
                        .font(SQType.section)
                        .foregroundStyle(SQColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    if people.isEmpty {
                        Text(SideThreadCopy.noOneToPick)
                            .font(SQType.detail)
                            .foregroundStyle(SQColor.muted)
                            .accessibilityIdentifier(SideThreadIdentifiers.formEmpty)
                    }
                    ForEach(people) { person in
                        pickRow(person, selected: draft.isSelected(person.id))
                    }
                    if draft.isGroup {
                        TextField(
                            SideThreadCopy.namePlaceholder,
                            text: Binding(
                                get: { model.sideThreadDraft?.title ?? "" },
                                set: { model.sideThreadDraft?.title = $0 }
                            )
                        )
                        .textFieldStyle(.plain)
                        .padding(SQSpace.m)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous).fill(SQColor.surface2))
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier(SideThreadIdentifiers.formName)
                        if draft.titleTooLong {
                            Text("Use \(SideThreadDraft.titleLimit) characters or fewer.")
                                .font(SQType.caption)
                                .foregroundStyle(SQColor.danger)
                        }
                    }
                    if !people.isEmpty {
                        Text(draft.isGroup ? SideThreadCopy.groupHint : SideThreadCopy.directHint)
                            .font(SQType.caption)
                            .foregroundStyle(SQColor.muted)
                    }
                }
                .padding(SQSpace.l)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(alignment: .leading, spacing: SQSpace.xs) {
                if !draft.error.isEmpty {
                    Text(draft.error)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.danger)
                        .accessibilityIdentifier(SideThreadIdentifiers.formError)
                }
                Button {
                    nameFocused = false
                    Task { await model.createSideThread() }
                } label: {
                    Text(draft.creating ? "Starting…" : SideThreadCopy.start)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.canCreate)
                .accessibilityIdentifier(SideThreadIdentifiers.formStart)
            }
            .padding(.horizontal, SQSpace.l)
            .padding(.vertical, SQSpace.s)
            .background(SQColor.surface1)
        }
    }

    private func pickRow(_ person: SquadMemberRecord, selected: Bool) -> some View {
        Button {
            model.toggleSideThreadMember(person.id)
        } label: {
            HStack(spacing: SQSpace.m) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? SQColor.signal : SQColor.subtle)
                    .accessibilityHidden(true)
                Text(person.displayName)
                    .font(SQType.body)
                    .foregroundStyle(SQColor.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, SQSpace.s)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.displayName)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
        .accessibilityIdentifier(SideThreadIdentifiers.pick(person.displayName))
    }

    // MARK: Pieces

    private func bar(
        title: String,
        leading: (String, String, () -> Void),
        trailing: (String, String, () -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: SQSpace.s) {
            Button(leading.0, action: leading.2)
                .font(SQType.label)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .accessibilityIdentifier(leading.1)
            Spacer(minLength: SQSpace.s)
            Text(title)
                .font(SQType.title)
                .foregroundStyle(SQColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: SQSpace.s)
            if let trailing {
                Button(trailing.0, action: trailing.2)
                    .font(SQType.label)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .accessibilityIdentifier(trailing.1)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, SQSpace.l)
        .padding(.vertical, SQSpace.xs)
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: SQSpace.m) {
            content()
        }
        .padding(SQSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
