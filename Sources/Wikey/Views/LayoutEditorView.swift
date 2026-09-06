import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WikeyCore

struct LayoutEditorView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @Binding var layout: WindowLayout
    var onBack: () -> Void
    var onDelete: () -> Void
    @State private var previewDisplayID: String?
    @State private var showsDeleteConfirmation = false
    @State private var applicationSelectionError: String?

    private var displays: [DisplayInfo] { runtime.layoutController.availableDisplays }

    var body: some View {
        VStack(spacing: 0) {
            WikeyEditorHeader(
                title: $layout.name,
                subtitle: layout.placements.isEmpty
                    ? "앱을 추가하고 사용할 화면 영역을 정하세요."
                    : "앱 \(layout.placements.count)개의 창을 한 번에 정리합니다.",
                onBack: onBack
            ) {
                WikeyDeleteButton(title: "레이아웃 삭제") {
                    showsDeleteConfirmation = true
                }
                Button("앱 추가", systemImage: "plus", action: addApplication)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(displays.isEmpty)
            }

            Divider()

            if displays.isEmpty {
                ContentUnavailableView(
                    "연결된 모니터가 없습니다",
                    systemImage: "display.trianglebadge.exclamationmark",
                    description: Text("모니터 연결 상태를 확인한 뒤 다시 열어 주세요.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        WikeySection(title: "단축키", detail: "이 단축키로 레이아웃을 바로 적용합니다.") {
                            PlainPanel {
                                VStack(alignment: .leading, spacing: 12) {
                                    ShortcutRecorderView(shortcut: $layout.shortcut)
                                    if let error = runtime.hotkeys.layoutRegistrationErrors[layout.id] {
                                        Label(error, systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }

                        if !runtime.permissions.accessibilityGranted {
                            PlainPanel {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("창 배치에는 손쉬운 사용 권한이 필요합니다", systemImage: "lock.open.display")
                                        .font(.headline)
                                    Text("권한을 허용한 뒤 레이아웃을 다시 적용해 주세요.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button("권한 설정 열기", action: runtime.permissions.requestAccessibility)
                                }
                            }
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 28) {
                                previewSection.frame(minWidth: 280)
                                placementsSection.frame(minWidth: 330)
                            }
                            VStack(alignment: .leading, spacing: 28) {
                                previewSection
                                placementsSection
                            }
                        }

                        if let summary = runtime.lastRun, summary.workflowID == layout.id {
                            PlainPanel { RunSummaryView(summary: summary) }
                        }
                    }
                    .padding(WikeyPageMetrics.padding)
                    .frame(maxWidth: WikeyPageMetrics.maximumWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            Divider()
            HStack(spacing: 12) {
                WikeySaveStatus()
                Spacer()
                Text("\(layout.placements.count)개 앱 배치")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("레이아웃 적용", systemImage: "play.fill") {
                    runtime.run(layoutID: layout.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(layout.placements.isEmpty || displays.isEmpty
                          || runtime.runner.runningWorkflowID == layout.id
                          || runtime.runner.queuedWorkflowIDs.contains(layout.id))
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, WikeyPageMetrics.padding)
            .padding(.vertical, 13)
            .background(.bar)
        }
        .navigationTitle(layout.name)
        .onAppear {
            previewDisplayID = previewDisplayID ?? displays.first?.id
        }
        .alert("레이아웃을 삭제할까요?", isPresented: $showsDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: onDelete)
        } message: {
            Text("‘\(layout.name)’과 이 레이아웃을 사용하는 워크플로 동작이 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("앱을 추가하지 못했습니다", isPresented: Binding(
            get: { applicationSelectionError != nil },
            set: { if !$0 { applicationSelectionError = nil } }
        )) {
            Button("확인", role: .cancel) { applicationSelectionError = nil }
        } message: {
            Text(applicationSelectionError ?? "")
        }
    }

    private var previewSection: some View {
        WikeySection(
            title: "미리보기",
            detail: "메뉴 막대와 Dock을 제외한 실제 작업 영역을 기준으로 배치합니다."
        ) {
            Picker("모니터", selection: Binding(
                get: { previewDisplayID ?? displays.first?.id ?? "" },
                set: { previewDisplayID = $0 }
            )) {
                ForEach(displays) { display in
                    Text(display.target.name).tag(display.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 280)

            DisplayPreview(
                placements: layout.placements.filter {
                    $0.display.uuid == (previewDisplayID ?? displays.first?.id)
                }
            )
        }
    }

    private var placementsSection: some View {
        WikeySection(
            title: "앱 배치",
            detail: "앱마다 가장 앞에 있는 일반 창 하나를 사용합니다."
        ) {
            if layout.placements.isEmpty {
                PlainPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("배치할 앱이 없습니다", systemImage: "macwindow")
                            .font(.headline)
                        Text("앱을 추가하면 모니터와 화면 영역을 선택할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("앱 추가…", action: addApplication)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(layout.placements) { placement in
                        PlacementRow(
                            placement: Binding(
                                get: { layout.placements.first(where: { $0.id == placement.id }) ?? placement },
                                set: { updated in
                                    guard let index = layout.placements.firstIndex(where: { $0.id == placement.id }) else { return }
                                    layout.placements[index] = updated
                                }
                            ),
                            displays: displays.map(\.target),
                            delete: { layout.placements.removeAll { $0.id == placement.id } }
                        )
                        if placement.id != layout.placements.last?.id {
                            Divider().padding(.leading, 46)
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
        }
    }

    private func addApplication() {
        guard let display = displays.first(where: { $0.id == previewDisplayID })?.target ?? displays.first?.target else { return }
        let panel = NSOpenPanel()
        panel.title = "배치할 앱 선택"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        guard !layout.placements.contains(where: { $0.bundleIdentifier == identifier }) else {
            applicationSelectionError = "‘\(name)’은 이미 추가되어 있습니다. 아래 앱 배치에서 기존 항목의 모니터와 영역을 변경하세요."
            return
        }
        layout.placements.append(AppWindowPlacement(
            bundleIdentifier: identifier,
            appName: name,
            display: display,
            zone: nextSuggestedZone
        ))
    }

    private var nextSuggestedZone: LayoutZone {
        switch layout.placements.count % 4 {
        case 0: .leftHalf
        case 1: .rightHalf
        case 2: .bottomLeft
        default: .bottomRight
        }
    }
}

private struct DisplayPreview: View {
    var placements: [AppWindowPlacement]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.separator, lineWidth: 1)

                if placements.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "rectangle.dashed")
                            .font(.title2)
                        Text("이 모니터에 배치된 앱이 없습니다")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }

                ForEach(placements) { placement in
                    let rect = placement.zone.normalizedRect
                    let width = geometry.size.width * rect.width
                    let height = geometry.size.height * rect.height
                    let x = geometry.size.width * rect.minX
                    let y = geometry.size.height * (1 - rect.maxY)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                        .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
                        .frame(width: max(0, width - 2), height: max(0, height - 2))
                        .overlay {
                            Text(placement.appName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .padding(6)
                        }
                        .position(x: x + width / 2, y: y + height / 2)
                }
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: 560)
    }
}

private struct PlacementRow: View {
    @Binding var placement: AppWindowPlacement
    var displays: [DisplayTarget]
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "app.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(placement.appName)
                            .font(.headline)
                        Text(placement.bundleIdentifier)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("배치에서 제거")
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("모니터").foregroundStyle(.secondary)
                        Picker("모니터", selection: Binding(
                            get: { placement.display.uuid },
                            set: { id in
                                guard let display = displays.first(where: { $0.uuid == id }) else { return }
                                placement.display = display
                            }
                        )) {
                            if !displays.contains(where: { $0.uuid == placement.display.uuid }) {
                                Text("\(placement.display.name) · 연결 안 됨").tag(placement.display.uuid)
                            }
                            ForEach(displays, id: \.uuid) { display in
                                // Names can change with system language; UUID is identity.
                                Text(display.name).tag(display.uuid)
                            }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("영역").foregroundStyle(.secondary)
                        Picker("영역", selection: $placement.zone) {
                            ForEach(LayoutZone.allCases) { zone in
                                Text(zone.title).tag(zone)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .font(.subheadline)
                if !displays.contains(where: { $0.uuid == placement.display.uuid }) {
                    Label("저장한 모니터가 연결되어 있지 않습니다. 사용할 모니터를 선택하세요.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 16)
    }
}
