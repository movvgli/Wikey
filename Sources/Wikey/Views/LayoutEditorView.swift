import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WikeyCore

struct LayoutEditorView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @Binding var layout: WindowLayout
    @State private var previewDisplayID: String?

    private var displays: [DisplayInfo] { runtime.layoutController.availableDisplays }

    var body: some View {
        VStack(spacing: 0) {
            WikeyEditorHeader(
                title: $layout.name,
                subtitle: layout.placements.isEmpty
                    ? "앱을 추가하고 사용할 화면 영역을 정하세요."
                    : "앱 \(layout.placements.count)개의 창을 한 번에 정리합니다."
            ) {
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
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 28) {
                            previewSection.frame(minWidth: 330)
                            placementsSection.frame(minWidth: 370)
                        }
                        VStack(alignment: .leading, spacing: 28) {
                            previewSection
                            placementsSection
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle(layout.name)
        .onAppear {
            previewDisplayID = previewDisplayID ?? displays.first?.id
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
                    ForEach(layout.placements.indices, id: \.self) { index in
                        PlacementRow(
                            placement: Binding(
                                get: { layout.placements[index] },
                                set: { layout.placements[index] = $0 }
                            ),
                            displays: displays.map(\.target),
                            delete: { layout.placements.remove(at: index) }
                        )
                        if index < layout.placements.count - 1 {
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
        guard let display = displays.first?.target else { return }
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
                        Picker("모니터", selection: $placement.display) {
                            ForEach(displays, id: \.uuid) { display in
                                Text(display.name).tag(display)
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
            }
        }
        .padding(.vertical, 16)
    }
}
