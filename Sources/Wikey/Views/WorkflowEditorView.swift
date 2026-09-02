import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WikeyCore

struct WorkflowEditorView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @Binding var workflow: Workflow

    private var isRunning: Bool {
        runtime.runner.runningWorkflowID == workflow.id
    }

    var body: some View {
        VStack(spacing: 0) {
            WikeyEditorHeader(
                title: $workflow.name,
                subtitle: workflow.actions.isEmpty
                    ? "단축키를 정하고 실행할 동작을 추가하세요."
                    : "동작 \(workflow.actions.count)개를 위에서 아래 순서로 실행합니다."
            ) {
                Toggle("사용", isOn: $workflow.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button {
                    runtime.run(workflowID: workflow.id)
                } label: {
                    if isRunning {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text("실행 중")
                        }
                    } else {
                        Label("시험 실행", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(workflow.actions.isEmpty || isRunning)
                .keyboardShortcut(.return, modifiers: [.command])
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    WikeySection(
                        title: "단축키",
                        detail: "다른 앱을 사용 중일 때도 이 워크플로를 실행합니다."
                    ) {
                        ShortcutRecorderView(shortcut: $workflow.shortcut)
                        if let error = runtime.hotkeys.registrationErrors[workflow.id] {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }

                    Divider()

                    WikeySection(
                        title: "실행 순서",
                        detail: "동작이 실패해도 다음 동작은 계속 실행됩니다."
                    ) {
                        if workflow.actions.isEmpty {
                            EmptyActionsView()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(workflow.actions.indices, id: \.self) { index in
                                    ActionEditorRow(
                                        number: index + 1,
                                        action: Binding(
                                            get: { workflow.actions[index] },
                                            set: { workflow.actions[index] = $0 }
                                        ),
                                        templates: runtime.store.templates,
                                        layouts: runtime.store.layouts,
                                        moveUp: { move(index, offset: -1) },
                                        moveDown: { move(index, offset: 1) },
                                        delete: { workflow.actions.remove(at: index) },
                                        canMoveUp: index > 0,
                                        canMoveDown: index < workflow.actions.count - 1
                                    )
                                    if index < workflow.actions.count - 1 {
                                        Divider().padding(.leading, 54)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                            }
                        }

                        addActionMenu
                    }
                }
                .padding(28)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(workflow.name)
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
            Label("동작 추가", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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

private struct EmptyActionsView: View {
    var body: some View {
        PlainPanel {
            HStack(spacing: 14) {
                Image(systemName: "list.number")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("아직 실행할 동작이 없습니다")
                        .font(.headline)
                    Text("앱 실행, 웹사이트 열기, 템플릿 복사, 창 배치를 추가할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ActionEditorRow: View {
    var number: Int
    @Binding var action: WorkflowAction
    var templates: [RichTemplate]
    var layouts: [WindowLayout]
    var moveUp: () -> Void
    var moveDown: () -> Void
    var delete: () -> Void
    var canMoveUp: Bool
    var canMoveDown: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 25, height: 25)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(.tint)
                    Text(actionTitle)
                        .font(.headline)
                    Spacer()
                    ControlGroup {
                        Button(action: moveUp) { Image(systemName: "chevron.up") }
                            .help("위로 이동")
                            .disabled(!canMoveUp)
                        Button(action: moveDown) { Image(systemName: "chevron.down") }
                            .help("아래로 이동")
                            .disabled(!canMoveDown)
                    }
                    .controlSize(.small)
                    .fixedSize()
                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("동작 삭제")
                }
                editor
            }
        }
        .padding(.vertical, 16)
    }

    private var actionTitle: String {
        switch action {
        case .launchApplication: "앱 실행"
        case .copyTemplate: "템플릿 복사"
        case .openURL: "웹사이트 열기"
        case .applyLayout: "창 레이아웃 적용"
        }
    }

    private var icon: String {
        switch action {
        case .launchApplication: "app"
        case .copyTemplate: "doc.on.clipboard"
        case .openURL: "globe"
        case .applyLayout: "rectangle.3.group"
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch action {
        case .launchApplication(let bundleID, let name):
            HStack {
                Text(name)
                Spacer()
                Text(bundleID)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
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
            HStack(spacing: 12) {
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
