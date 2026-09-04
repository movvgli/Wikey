import AppKit
import SwiftUI
import WikeyCore

enum SidebarSelection: Hashable {
    case overview
    case workflowCollection
    case workflow(UUID)
    case templateCollection
    case template(UUID)
    case layoutCollection
    case layout(UUID)
    case settings
    case trash
}

struct ContentView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var selection: SidebarSelection? = .overview
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            WikeySidebar(
                workflows: runtime.store.workflows,
                selection: selection ?? .overview,
                select: { selection = $0 },
                addWorkflow: addWorkflow,
                showTemplates: showTemplates,
                showLayouts: showLayouts,
                deleteWorkflow: deleteWorkflow
            )
            .ignoresSafeArea(.container, edges: .top)
            .navigationSplitViewColumnWidth(min: 238, ideal: 260, max: 300)
        } detail: {
            detail
                .ignoresSafeArea(.container, edges: .top)
        }
        .toolbar(removing: .sidebarToggle)
        .background(WindowToolbarConfigurator())
        .onAppear {
            if !didCompleteOnboarding { showOnboarding = true }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .environment(runtime)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .overview {
        case .overview:
            OverviewView(
                createWorkflow: addWorkflow,
                openWorkflow: { selection = .workflow($0) },
                openSettings: { selection = .settings }
            )
        case .workflowCollection:
            OverviewView(
                createWorkflow: addWorkflow,
                openWorkflow: { selection = .workflow($0) },
                openSettings: { selection = .settings }
            )
        case .workflow(let id):
            if let binding = workflowBinding(id) {
                WorkflowEditorView(
                    workflow: binding,
                    onBack: { selection = .workflowCollection },
                    onDelete: { deleteWorkflow(id) }
                )
            } else {
                ContentUnavailableView("워크플로를 찾을 수 없습니다", systemImage: "bolt.slash")
            }
        case .templateCollection:
            TemplateLibraryView(
                templates: runtime.store.templates,
                open: { selection = .template($0) },
                add: addTemplate
            )
        case .template(let id):
            if let binding = templateBinding(id) {
                TemplateEditorView(
                    template: binding,
                    onBack: { selection = .templateCollection }
                )
            } else {
                ContentUnavailableView("템플릿을 찾을 수 없습니다", systemImage: "doc.badge.ellipsis")
            }
        case .layoutCollection:
            LayoutLibraryView(
                layouts: runtime.store.layouts,
                open: { selection = .layout($0) },
                add: addLayout
            )
        case .layout(let id):
            if let binding = layoutBinding(id) {
                LayoutEditorView(layout: binding)
            } else {
                ContentUnavailableView("레이아웃을 찾을 수 없습니다", systemImage: "rectangle.3.group")
            }
        case .settings:
            WikeySettingsView()
        case .trash:
            ContentUnavailableView(
                "휴지통이 비어 있습니다",
                systemImage: "trash",
                description: Text("삭제한 항목을 보관하는 기능은 다음 업데이트에서 지원할 예정입니다.")
            )
        }
    }

    private func workflowBinding(_ id: UUID) -> Binding<Workflow>? {
        guard let fallback = runtime.store.workflows.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { runtime.store.workflows.first(where: { $0.id == id }) ?? fallback },
            set: { updated in
                guard let index = runtime.store.workflows.firstIndex(where: { $0.id == id }) else { return }
                runtime.store.workflows[index] = updated
                runtime.saveAndReloadHotkeys()
            }
        )
    }

    private func templateBinding(_ id: UUID) -> Binding<RichTemplate>? {
        guard let fallback = runtime.store.templates.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { runtime.store.templates.first(where: { $0.id == id }) ?? fallback },
            set: { updated in
                guard let index = runtime.store.templates.firstIndex(where: { $0.id == id }) else { return }
                runtime.store.templates[index] = updated
                runtime.store.save()
            }
        )
    }

    private func layoutBinding(_ id: UUID) -> Binding<WindowLayout>? {
        guard let fallback = runtime.store.layouts.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { runtime.store.layouts.first(where: { $0.id == id }) ?? fallback },
            set: { updated in
                guard let index = runtime.store.layouts.firstIndex(where: { $0.id == id }) else { return }
                runtime.store.layouts[index] = updated
                runtime.store.save()
            }
        )
    }

    private func addWorkflow() {
        selection = .workflow(runtime.store.addWorkflow())
    }

    private func addTemplate() {
        selection = .template(runtime.store.addTemplate())
    }

    private func addLayout() {
        selection = .layout(runtime.store.addLayout())
    }

    private func showTemplates() {
        selection = .templateCollection
    }

    private func showLayouts() {
        selection = .layoutCollection
    }

    private func deleteWorkflow(_ id: UUID) {
        runtime.store.deleteWorkflow(id: id)
        runtime.reloadHotkeys()
        selection = .workflowCollection
    }

    private func deleteTemplate(_ id: UUID) {
        runtime.store.deleteTemplate(id: id)
        selection = .overview
    }

    private func deleteLayout(_ id: UUID) {
        runtime.store.deleteLayout(id: id)
        selection = .overview
    }
}

private struct WindowToolbarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        scheduleConfiguration(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleConfiguration(for: nsView)
    }

    private func scheduleConfiguration(for view: NSView) {
        for delay in [0.0, 0.15, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                configure(view.window)
            }
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window, let toolbar = window.toolbar else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        toolbar.isVisible = false
        for index in toolbar.items.indices.reversed() {
            let item = toolbar.items[index]
            let identifier = item.itemIdentifier
            let looksLikeSidebarControl = identifier.rawValue.localizedCaseInsensitiveContains("sidebar")
                || item.label.localizedCaseInsensitiveContains("sidebar")
                || item.paletteLabel.localizedCaseInsensitiveContains("sidebar")
            if identifier == .toggleSidebar || identifier == .sidebarTrackingSeparator || looksLikeSidebarControl {
                toolbar.removeItem(at: index)
            }
        }
    }
}

private struct OverviewView: View {
    @Environment(WikeyRuntime.self) private var runtime
    var createWorkflow: () -> Void
    var openWorkflow: (UUID) -> Void
    var openSettings: () -> Void

    private var activeWorkflows: [Workflow] {
        runtime.store.workflows.filter(\.isEnabled)
    }

    private var needsSetup: Bool {
        !runtime.permissions.accessibilityGranted || !runtime.permissions.inputMonitoringGranted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("워크플로")
                            .font(.system(size: 30, weight: .semibold))
                        Text(activeWorkflows.isEmpty
                             ? "자주 하는 일을 단축키 하나로 묶어보세요."
                             : "활성화된 워크플로 \(activeWorkflows.count)개를 어디서든 실행할 수 있습니다.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("새 워크플로", systemImage: "plus", action: createWorkflow)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                if needsSetup {
                    SetupNotice(openSettings: openSettings)
                }

                WikeySection(
                    title: activeWorkflows.isEmpty ? "첫 워크플로 만들기" : "빠른 실행",
                    detail: activeWorkflows.isEmpty ? "이름과 단축키를 정한 뒤 실행할 동작을 순서대로 추가합니다." : nil
                ) {
                    if activeWorkflows.isEmpty {
                        PlainPanel {
                            HStack(spacing: 14) {
                                Image(systemName: "bolt")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("앱 열기부터 시작해 보세요")
                                        .font(.headline)
                                    Text("웹사이트, 템플릿, 창 배치도 같은 단축키에 이어 붙일 수 있습니다.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("만들기", action: createWorkflow)
                            }
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(activeWorkflows) { workflow in
                                WorkflowQuickRunCard(
                                    workflow: workflow,
                                    isRunning: runtime.runner.runningWorkflowID == workflow.id,
                                    hasConflict: runtime.hotkeys.registrationErrors[workflow.id] != nil,
                                    open: { openWorkflow(workflow.id) },
                                    run: { runtime.run(workflowID: workflow.id) }
                                )
                            }
                        }
                    }
                }

                if let lastRun = runtime.lastRun {
                    WikeySection(title: "최근 실행") {
                        PlainPanel {
                            RunSummaryView(summary: lastRun)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("홈")
    }
}

private struct SetupNotice: View {
    @Environment(WikeyRuntime.self) private var runtime
    var openSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.open.display")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("일부 기능을 사용하려면 권한이 필요합니다")
                    .font(.headline)
                Text(missingPermissionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("설정 확인", action: openSettings)
        }
        .padding(16)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        }
    }

    private var missingPermissionText: String {
        switch (runtime.permissions.accessibilityGranted, runtime.permissions.inputMonitoringGranted) {
        case (false, false): "창 배치·자동 붙여넣기와 두 단계 단축키가 아직 꺼져 있습니다."
        case (false, true): "창 배치와 자동 붙여넣기가 아직 꺼져 있습니다."
        case (true, false): "두 단계 단축키가 아직 꺼져 있습니다."
        case (true, true): ""
        }
    }
}

private struct WorkflowQuickRunCard: View {
    var workflow: Workflow
    var isRunning: Bool
    var hasConflict: Bool
    var open: () -> Void
    var run: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: open) {
                HStack(spacing: 16) {
                    Image(systemName: hasConflict ? "exclamationmark.triangle.fill" : "bolt.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(hasConflict ? Color.orange : Color.wikeyAccent)
                        .frame(width: 44, height: 44)
                        .background(
                            (hasConflict ? Color.orange : Color.wikeyAccent).opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workflow.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("동작 \(workflow.actions.count)개")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    ShortcutBadge(
                        text: workflow.shortcut.steps.isEmpty ? "미지정" : workflow.shortcut.displayName,
                        isMuted: workflow.shortcut.steps.isEmpty
                    )
                }
                .padding(.leading, 18)
                .padding(.trailing, 14)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("워크플로 편집")

            Button {
                run()
            } label: {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasConflict ? Color.secondary : Color.wikeyAccent)
            .help(hasConflict ? "단축키 충돌을 해결한 뒤 실행할 수 있습니다" : "워크플로 실행")
            .disabled(hasConflict || isRunning || workflow.actions.isEmpty)
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isHovering ? Color.wikeyAccent.opacity(0.22) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(isHovering ? 0.06 : 0.04), radius: isHovering ? 12 : 10, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
    }
}

private struct RunSummaryView: View {
    var summary: RunSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    summary.failures.isEmpty ? "완료" : "일부 동작을 실행하지 못했습니다",
                    systemImage: summary.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(summary.failures.isEmpty ? Color.green : Color.orange)
                .font(.headline)
                Spacer()
                Text(summary.finishedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(summary.workflowName)
            ForEach(summary.failures) { failure in
                Text("\(failure.actionTitle) — \(failure.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TemplateLibraryView: View {
    var templates: [RichTemplate]
    var open: (UUID) -> Void
    var add: () -> Void

    var body: some View {
        LibraryLandingView(
            title: "템플릿",
            subtitle: "자주 쓰는 문장을 저장하고 워크플로에서 바로 사용합니다.",
            addTitle: "템플릿 추가",
            add: add
        ) {
            ForEach(templates) { template in
                LibraryItemButton(
                    title: template.name,
                    subtitle: template.plainText.isEmpty ? "내용 없음" : template.plainText,
                    systemImage: "doc.on.clipboard",
                    action: { open(template.id) }
                )
            }
        }
    }
}

private struct LayoutLibraryView: View {
    var layouts: [WindowLayout]
    var open: (UUID) -> Void
    var add: () -> Void

    var body: some View {
        LibraryLandingView(
            title: "레이아웃",
            subtitle: "앱 창의 위치와 크기를 한 번에 배치합니다.",
            addTitle: "레이아웃 추가",
            add: add
        ) {
            ForEach(layouts) { layout in
                LibraryItemButton(
                    title: layout.name,
                    subtitle: "\(layout.placements.count)개 앱 배치",
                    systemImage: "rectangle.3.group",
                    action: { open(layout.id) }
                )
            }
        }
    }
}

private struct LibraryLandingView<Content: View>: View {
    var title: String
    var subtitle: String
    var addTitle: String
    var add: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 32, weight: .bold))
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(addTitle, systemImage: "plus", action: add)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                LazyVStack(spacing: 12) {
                    content
                }
            }
            .padding(38)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct LibraryItemButton: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.wikeyAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.wikeyAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WikeySidebar: View {
    var workflows: [Workflow]
    var selection: SidebarSelection
    var select: (SidebarSelection) -> Void
    var addWorkflow: () -> Void
    var showTemplates: () -> Void
    var showLayouts: () -> Void
    var deleteWorkflow: (UUID) -> Void

    private var isWorkflowSection: Bool {
        if case .workflow = selection { return true }
        return selection == .workflowCollection
    }

    private var isTemplateSection: Bool {
        if case .template = selection { return true }
        return selection == .templateCollection
    }

    private var isLayoutSection: Bool {
        if case .layout = selection { return true }
        return selection == .layoutCollection
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Wikey")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 24)
                        .padding(.top, 58)
                        .padding(.bottom, 12)

                    VStack(spacing: 3) {
                        SidebarNavigationRow(
                            title: "홈",
                            systemImage: "house",
                            isActive: selection == .overview,
                            action: { select(.overview) }
                        )
                        SidebarNavigationRow(
                            title: "워크플로",
                            systemImage: "point.3.connected.trianglepath.dotted",
                            isActive: isWorkflowSection,
                            action: { select(.workflowCollection) }
                        )
                        SidebarNavigationRow(
                            title: "템플릿",
                            systemImage: "square.grid.2x2",
                            isActive: isTemplateSection,
                            action: showTemplates
                        )
                        SidebarNavigationRow(
                            title: "레이아웃",
                            systemImage: "keyboard",
                            isActive: isLayoutSection,
                            action: showLayouts
                        )
                        SidebarNavigationRow(
                            title: "설정",
                            systemImage: "gearshape",
                            isActive: selection == .settings,
                            action: { select(.settings) }
                        )
                    }
                    .padding(.horizontal, 14)

                    HStack {
                        Text("내 워크플로")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: addWorkflow) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                        }
                        .help("워크플로 추가")
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 32)
                    .padding(.bottom, 6)

                    VStack(spacing: 5) {
                        ForEach(workflows) { workflow in
                            SidebarWorkflowButton(
                                workflow: workflow,
                                isActive: selection == .workflow(workflow.id),
                                action: { select(.workflow(workflow.id)) }
                            )
                            .contextMenu {
                                Button("삭제", role: .destructive) { deleteWorkflow(workflow.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 18)
            }

            SidebarNavigationRow(
                title: "휴지통 보기",
                systemImage: "trash",
                isActive: selection == .trash,
                action: { select(.trash) }
            )
            .frame(height: 42)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(.thinMaterial)
    }
}

private struct SidebarNavigationRow: View {
    var title: String
    var systemImage: String
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isActive ? Color.wikeyAccent : Color.primary.opacity(0.78))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                isActive ? Color.wikeyAccent.opacity(0.11) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct SidebarWorkflowButton: View {
    var workflow: Workflow
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(workflow.isEnabled ? Color.wikeyAccent.opacity(0.7) : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(workflow.name)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if !workflow.shortcut.steps.isEmpty {
                    ShortcutBadge(text: workflow.shortcut.displayName, isMuted: !isActive)
                }
            }
            .foregroundStyle(isActive ? Color.wikeyAccent : Color.primary.opacity(0.7))
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                isActive ? Color.wikeyAccent.opacity(0.11) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
