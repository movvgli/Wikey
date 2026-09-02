import SwiftUI
import WikeyCore

enum SidebarSelection: Hashable {
    case overview
    case workflow(UUID)
    case template(UUID)
    case layout(UUID)
    case settings
}

struct ContentView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var selection: SidebarSelection? = .overview
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("홈", systemImage: "house")
                    .tag(SidebarSelection.overview)

                Section {
                    ForEach(runtime.store.workflows) { workflow in
                        WorkflowSidebarRow(workflow: workflow)
                            .tag(SidebarSelection.workflow(workflow.id))
                            .contextMenu {
                                Button("삭제", role: .destructive) { deleteWorkflow(workflow.id) }
                            }
                    }
                    SidebarAddButton(title: "워크플로 추가", action: addWorkflow)
                } header: {
                    SidebarSectionHeader(title: "워크플로", count: runtime.store.workflows.count)
                }

                Section {
                    ForEach(runtime.store.templates) { template in
                        Label(template.name, systemImage: "doc.on.clipboard")
                            .lineLimit(1)
                            .tag(SidebarSelection.template(template.id))
                            .contextMenu {
                                Button("삭제", role: .destructive) { deleteTemplate(template.id) }
                            }
                    }
                    SidebarAddButton(title: "템플릿 추가", action: addTemplate)
                } header: {
                    SidebarSectionHeader(title: "템플릿", count: runtime.store.templates.count)
                }

                Section {
                    ForEach(runtime.store.layouts) { layout in
                        Label(layout.name, systemImage: "rectangle.3.group")
                            .lineLimit(1)
                            .tag(SidebarSelection.layout(layout.id))
                            .contextMenu {
                                Button("삭제", role: .destructive) { deleteLayout(layout.id) }
                            }
                    }
                    SidebarAddButton(title: "레이아웃 추가", action: addLayout)
                } header: {
                    SidebarSectionHeader(title: "레이아웃", count: runtime.store.layouts.count)
                }

                Section {
                    Label("설정", systemImage: "gearshape")
                        .tag(SidebarSelection.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Wikey")
            .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 290)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("워크플로") { addWorkflow() }
                    Button("템플릿") { addTemplate() }
                    Button("레이아웃") { addLayout() }
                } label: {
                    Label("새로 만들기", systemImage: "plus")
                }
                .help("새 항목 만들기")
            }
        }
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
        case .workflow(let id):
            if let binding = workflowBinding(id) {
                WorkflowEditorView(workflow: binding)
            } else {
                ContentUnavailableView("워크플로를 찾을 수 없습니다", systemImage: "bolt.slash")
            }
        case .template(let id):
            if let binding = templateBinding(id) {
                TemplateEditorView(template: binding)
            } else {
                ContentUnavailableView("템플릿을 찾을 수 없습니다", systemImage: "doc.badge.ellipsis")
            }
        case .layout(let id):
            if let binding = layoutBinding(id) {
                LayoutEditorView(layout: binding)
            } else {
                ContentUnavailableView("레이아웃을 찾을 수 없습니다", systemImage: "rectangle.3.group")
            }
        case .settings:
            WikeySettingsView()
        }
    }

    private func workflowBinding(_ id: UUID) -> Binding<Workflow>? {
        guard runtime.store.workflows.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { runtime.store.workflows.first(where: { $0.id == id })! },
            set: { updated in
                guard let index = runtime.store.workflows.firstIndex(where: { $0.id == id }) else { return }
                runtime.store.workflows[index] = updated
                runtime.saveAndReloadHotkeys()
            }
        )
    }

    private func templateBinding(_ id: UUID) -> Binding<RichTemplate>? {
        guard runtime.store.templates.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { runtime.store.templates.first(where: { $0.id == id })! },
            set: { updated in
                guard let index = runtime.store.templates.firstIndex(where: { $0.id == id }) else { return }
                runtime.store.templates[index] = updated
                runtime.store.save()
            }
        )
    }

    private func layoutBinding(_ id: UUID) -> Binding<WindowLayout>? {
        guard runtime.store.layouts.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { runtime.store.layouts.first(where: { $0.id == id })! },
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

    private func deleteWorkflow(_ id: UUID) {
        runtime.store.deleteWorkflow(id: id)
        runtime.reloadHotkeys()
        selection = .overview
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
                        PlainPanel {
                            VStack(spacing: 0) {
                                ForEach(Array(activeWorkflows.enumerated()), id: \.element.id) { index, workflow in
                                    WorkflowQuickRunRow(
                                        workflow: workflow,
                                        isRunning: runtime.runner.runningWorkflowID == workflow.id,
                                        hasConflict: runtime.hotkeys.registrationErrors[workflow.id] != nil,
                                        open: { openWorkflow(workflow.id) },
                                        run: { runtime.run(workflowID: workflow.id) }
                                    )
                                    if index < activeWorkflows.count - 1 {
                                        Divider().padding(.leading, 42)
                                    }
                                }
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

private struct WorkflowQuickRunRow: View {
    var workflow: Workflow
    var isRunning: Bool
    var hasConflict: Bool
    var open: () -> Void
    var run: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hasConflict ? "exclamationmark.triangle" : "bolt.fill")
                .foregroundStyle(hasConflict ? Color.orange : Color.accentColor)
                .frame(width: 24)
            Button(action: open) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("동작 \(workflow.actions.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ShortcutBadge(text: workflow.shortcut.displayName, isMuted: workflow.shortcut.steps.isEmpty)
            Button {
                run()
            } label: {
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "play.fill")
                }
            }
            .buttonStyle(.borderless)
            .help("실행")
            .disabled(hasConflict || isRunning || workflow.actions.isEmpty)
        }
        .padding(.vertical, 9)
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

private struct WorkflowSidebarRow: View {
    var workflow: Workflow

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: workflow.isEnabled ? "bolt.fill" : "bolt.slash")
                .foregroundStyle(workflow.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 16)
            Text(workflow.name)
                .lineLimit(1)
            Spacer(minLength: 6)
            if !workflow.shortcut.steps.isEmpty {
                Text(workflow.shortcut.displayName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

private struct SidebarSectionHeader: View {
    var title: String
    var count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(count)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 17, height: 17)
                .background(.quaternary, in: Circle())
        }
    }
}

private struct SidebarAddButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
