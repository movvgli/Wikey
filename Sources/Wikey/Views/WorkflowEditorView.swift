import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WikeyCore

struct WorkflowEditorView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @Binding var workflow: Workflow
    var onBack: () -> Void
    var onDelete: () -> Void

    @State private var showsShortcutEditor = false
    @State private var showsDeleteConfirmation = false

    private var isRunning: Bool {
        runtime.runner.runningWorkflowID == workflow.id
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editorHeader

                    shortcutSummary
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 0) {
                        TriggerSummaryRow(continues: !workflow.actions.isEmpty)

                        if workflow.actions.isEmpty {
                            EmptyActionsView()
                                .padding(.leading, 60)
                                .padding(.top, 12)
                        } else {
                            ForEach(Array(workflow.actions.enumerated()), id: \.offset) { index, fallback in
                                FlowActionRow(
                                    number: index + 1,
                                    isLast: index == workflow.actions.count - 1,
                                    action: Binding(
                                        get: {
                                            workflow.actions.indices.contains(index)
                                                ? workflow.actions[index]
                                                : fallback
                                        },
                                        set: { updated in
                                            guard workflow.actions.indices.contains(index) else { return }
                                            workflow.actions[index] = updated
                                        }
                                    ),
                                    templates: runtime.store.templates,
                                    layouts: runtime.store.layouts,
                                    moveUp: { move(index, offset: -1) },
                                    moveDown: { move(index, offset: 1) },
                                    delete: {
                                        guard workflow.actions.indices.contains(index) else { return }
                                        workflow.actions.remove(at: index)
                                    },
                                    canMoveUp: index > 0,
                                    canMoveDown: index < workflow.actions.count - 1
                                )
                            }
                        }

                        addActionMenu
                            .padding(.leading, 60)
                            .padding(.top, 10)
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            HStack(spacing: 12) {
                Spacer()
                Text("\(workflow.actions.count)개 동작")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    runtime.run(workflowID: workflow.id)
                } label: {
                    if isRunning {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text("실행 중")
                        }
                    } else {
                        Label("테스트 실행", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(workflow.actions.isEmpty || isRunning)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 13)
            .background(.bar)
        }
        .confirmationDialog(
            "이 워크플로를 삭제할까요?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive, action: onDelete)
            Button("취소", role: .cancel) {}
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.72), in: Circle())
                .overlay { Circle().stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1) }
                Spacer()
            }

            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("워크플로 이름", text: $workflow.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 32, weight: .bold))
                        .fixedSize()
                    Text("업무에 집중할 수 있도록 필요한 앱과 작업을 순서대로 실행합니다.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)

                HStack(spacing: 16) {
                    Label("자동 저장됨", systemImage: "checkmark.circle.fill")
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                    }
                    workflowMenu
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var workflowMenu: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.72))
            Circle()
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            Menu {
                Button(workflow.isEnabled ? "워크플로 끄기" : "워크플로 켜기") {
                    workflow.isEnabled.toggle()
                }
                Divider()
                Button("워크플로 삭제", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(width: 38, height: 38)
        .help("워크플로 메뉴")
    }

    private var shortcutSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text("단축키")
                    .font(.headline)
                ShortcutBadge(
                    text: workflow.shortcut.steps.isEmpty ? "미지정" : workflow.shortcut.displayName,
                    isMuted: workflow.shortcut.steps.isEmpty
                )
                Spacer()
                Button("단축키 변경") {
                    showsShortcutEditor.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .popover(isPresented: $showsShortcutEditor, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("단축키 변경")
                            .font(.headline)
                        ShortcutRecorderView(shortcut: $workflow.shortcut)
                    }
                    .padding(20)
                    .frame(width: 480)
                }
            }

            if let error = runtime.hotkeys.registrationErrors[workflow.id] {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(FlowCardBackground())
    }

    private var addActionMenu: some View {
        Menu {
            Button("앱 실행…", systemImage: "app") { chooseApplication() }
            Button("웹사이트 열기", systemImage: "globe") {
                workflow.actions.append(.openURL("https://"))
            }
            Button("템플릿 복사", systemImage: "doc.on.clipboard") {
                if let template = runtime.store.templates.first {
                    workflow.actions.append(.copyTemplate(templateID: template.id, mode: .copyOnly))
                }
            }
            .disabled(runtime.store.templates.isEmpty)
            Button("창 레이아웃 적용", systemImage: "rectangle.3.group") {
                if let layout = runtime.store.layouts.first {
                    workflow.actions.append(.applyLayout(layoutID: layout.id))
                }
            }
            .disabled(runtime.store.layouts.isEmpty)
        } label: {
            HStack {
                Spacer()
                Label("동작 추가", systemImage: "plus")
                    .font(.headline)
                Spacer()
            }
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Color.wikeyAccent.opacity(0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    Color.wikeyAccent.opacity(0.36),
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                )
        }
    }

    private func move(_ index: Int, offset: Int) {
        let destination = index + offset
        guard workflow.actions.indices.contains(destination) else { return }
        workflow.actions.swapAt(index, destination)
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "실행할 앱 선택"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        workflow.actions.append(.launchApplication(bundleIdentifier: identifier, displayName: name))
    }
}

private struct FlowCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.045), radius: 10, y: 3)
    }
}

private struct EmptyActionsView: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "list.number")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("첫 동작을 추가해 보세요")
                    .font(.headline)
                Text("앱 실행, 웹사이트 열기, 템플릿 복사, 창 배치를 연결할 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowCardBackground())
    }
}

private struct TriggerSummaryRow: View {
    var continues: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FlowMarker(symbol: "bolt.fill", continues: continues)
            VStack(alignment: .leading, spacing: 5) {
                Text("트리거")
                    .font(.title3.weight(.semibold))
                Text("단축키 사용 시 실행")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
        .padding(.leading, 4)
        .padding(.bottom, 15)
    }
}

private struct FlowActionRow: View {
    var number: Int
    var isLast: Bool
    @Binding var action: WorkflowAction
    var templates: [RichTemplate]
    var layouts: [WindowLayout]
    var moveUp: () -> Void
    var moveDown: () -> Void
    var delete: () -> Void
    var canMoveUp: Bool
    var canMoveDown: Bool

    @State private var showsEditor = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FlowMarker(number: number, continues: true, endsFlow: isLast)

            HStack(spacing: 16) {
                ActionIcon(action: action)
                VStack(alignment: .leading, spacing: 5) {
                    Text(actionTitle)
                        .font(.headline)
                    Text(actionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 16)
                Image(systemName: "circle.grid.2x3.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                Menu {
                    Button("세부 설정…", systemImage: "slider.horizontal.3") {
                        showsEditor = true
                    }
                    Button("위로 이동", systemImage: "arrow.up", action: moveUp)
                        .disabled(!canMoveUp)
                    Button("아래로 이동", systemImage: "arrow.down", action: moveDown)
                        .disabled(!canMoveDown)
                    Divider()
                    Button("삭제", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .popover(isPresented: $showsEditor, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(actionTitle)
                            .font(.headline)
                        actionEditor
                        Divider()
                        HStack {
                            Button("위로 이동", systemImage: "arrow.up", action: moveUp)
                                .disabled(!canMoveUp)
                            Button("아래로 이동", systemImage: "arrow.down", action: moveDown)
                                .disabled(!canMoveDown)
                            Spacer()
                            Button("삭제", systemImage: "trash", role: .destructive, action: delete)
                        }
                    }
                    .padding(20)
                    .frame(width: 440)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 66)
            .background(FlowCardBackground())
            .padding(.bottom, 10)
        }
    }

    private var actionTitle: String {
        switch action {
        case .launchApplication: "앱 열기"
        case .copyTemplate: "템플릿 복사"
        case .openURL: "웹사이트 열기"
        case .applyLayout: "창 배치"
        }
    }

    private var actionSubtitle: String {
        switch action {
        case .launchApplication(let bundleID, let name):
            return name.isEmpty ? bundleID : name
        case .copyTemplate(let templateID, let mode):
            let name = templates.first(where: { $0.id == templateID })?.name ?? "템플릿 선택"
            return "\(name) · \(mode.title)"
        case .openURL(let url):
            return URL(string: url)?.host ?? url
        case .applyLayout(let layoutID):
            return layouts.first(where: { $0.id == layoutID })?.name ?? "레이아웃 선택"
        }
    }

    @ViewBuilder
    private var actionEditor: some View {
        switch action {
        case .launchApplication(let bundleID, let name):
            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                Text(bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .openURL(let url):
            TextField(
                "https://example.com",
                text: Binding(
                    get: { url },
                    set: { action = .openURL($0) }
                )
            )
            .textFieldStyle(.roundedBorder)

        case .copyTemplate(let templateID, let mode):
            VStack(alignment: .leading, spacing: 14) {
                Picker(
                    "템플릿",
                    selection: Binding(
                        get: { templateID },
                        set: { action = .copyTemplate(templateID: $0, mode: mode) }
                    )
                ) {
                    ForEach(templates) { Text($0.name).tag($0.id) }
                }
                Picker(
                    "처리",
                    selection: Binding(
                        get: { mode },
                        set: { action = .copyTemplate(templateID: templateID, mode: $0) }
                    )
                ) {
                    ForEach(TemplateDeliveryMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }

        case .applyLayout(let layoutID):
            Picker(
                "레이아웃",
                selection: Binding(
                    get: { layoutID },
                    set: { action = .applyLayout(layoutID: $0) }
                )
            ) {
                ForEach(layouts) { Text($0.name).tag($0.id) }
            }
        }
    }
}

private struct FlowMarker: View {
    var number: Int?
    var symbol: String?
    var continues: Bool
    var endsFlow: Bool

    init(number: Int, continues: Bool) {
        self.number = number
        self.symbol = nil
        self.continues = continues
        self.endsFlow = false
    }

    init(number: Int, continues: Bool, endsFlow: Bool) {
        self.number = number
        self.symbol = nil
        self.continues = continues
        self.endsFlow = endsFlow
    }

    init(symbol: String, continues: Bool) {
        self.number = nil
        self.symbol = symbol
        self.continues = continues
        self.endsFlow = false
    }

    var body: some View {
        ZStack(alignment: .top) {
            if continues {
                Rectangle()
                    .fill(Color.wikeyAccent.opacity(0.24))
                    .frame(width: 2)
                    .padding(.top, symbol == nil ? 44 : 54)
            }

            if endsFlow {
                VStack {
                    Spacer()
                    Circle()
                        .fill(Color.wikeyAccent)
                        .frame(width: 6, height: 6)
                }
            }

            Group {
                if let number {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.wikeyAccent)
                        .frame(width: 38, height: 38)
                        .background(Color.wikeyAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.31, green: 0.27, blue: 0.94), Color(red: 0.25, green: 0.45, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: Color.indigo.opacity(0.24), radius: 8, y: 4)
                }
            }
        }
        .frame(width: 46)
        .frame(maxHeight: .infinity)
    }
}

private struct ActionIcon: View {
    var action: WorkflowAction

    var body: some View {
        Group {
            if case .launchApplication(let bundleIdentifier, _) = action,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.wikeyAccent)
            }
        }
        .frame(width: 24, height: 24)
        .padding(6)
        .background(Color.wikeyAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var symbol: String {
        switch action {
        case .launchApplication: "app"
        case .copyTemplate: "doc.on.clipboard"
        case .openURL: "globe"
        case .applyLayout: "rectangle.3.group"
        }
    }
}
