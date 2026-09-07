import SwiftUI
import UniformTypeIdentifiers
import WikeyCore

struct ICloudSyncSettingsSection: View {
    @Environment(WikeyRuntime.self) private var runtime
    @State private var showConsent = false
    @State private var showFolderPicker = false
    @State private var selectedBackup: SyncBackup?
    @State private var selectedParents: [UUID] = []
    @State private var showRestore = false
    @State private var showHistory = false
    @State private var pickerError: String?
    @State private var historyLimit = 30

    private var sync: ICloudSyncService { runtime.iCloudSync }

    var body: some View {
        WikeySection(title: "iCloud 동기화 및 백업", detail: "같은 Apple 계정을 사용하는 Mac에서 설정을 이어서 사용합니다.") {
            PlainPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "icloud").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sync.isEnabled ? "iCloud Drive 연결됨" : "이 Mac에만 저장 중").font(.headline)
                            Text(sync.status).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if sync.isBusy { ProgressView().controlSize(.small) }
                    }
                    Text("각 Mac에서 iCloud Drive의 같은 개인 폴더를 한 번 연결하세요. 앱이 실행 중일 때 자동으로 확인합니다.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Button(sync.isEnabled ? "폴더 변경…" : "동기화 시작…") { showConsent = true }
                        Button("지금 백업") { Task { await sync.createBackup() } }
                        if sync.isEnabled {
                            Button("지금 확인") { Task { await sync.synchronize() } }
                            Button("동기화 끄기") { sync.disconnect() }
                        }
                    }.disabled(sync.isBusy)
                    if sync.isEnabled {
                        Text("연결 폴더: \(sync.folderName)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let date = sync.lastChecked {
                        Text("마지막 폴더 확인: \(date.formatted(date: .abbreviated, time: .shortened)) · 다른 Mac 도착 여부는 해당 Mac에서 확인하세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = sync.errorMessage ?? pickerError {
                        Label(error, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(.orange)
                    }
                    if !sync.conflicts.isEmpty {
                        Divider()
                        Text("설정 충돌 · 두 버전 모두 보관 중").font(.headline)
                        Text("동시에 수정되었거나 처음 연결한 Mac의 설정이 다릅니다. 사용할 전체 설정을 선택하세요. 선택하지 않은 내용도 백업에 남습니다.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(sync.conflicts) { backup in backupRow(backup, action: "이 버전 사용…") }
                    } else if let pending = sync.pendingVersion {
                        Divider()
                        backupRow(pending, action: "지금 적용…")
                    }
                    DisclosureGroup("백업 및 복원 (\(sync.versions.count))", isExpanded: $showHistory) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("설정 변경·복원 전 사본을 보관합니다. 백업은 자동 삭제하지 않으며 저장 공간을 사용합니다. 동기화를 꺼도 복원할 수 있습니다.")
                                .font(.caption).foregroundStyle(.secondary)
                            if sync.versions.isEmpty { Text("아직 백업이 없습니다.").foregroundStyle(.secondary) }
                            ForEach(sync.versions.prefix(historyLimit)) { backup in backupRow(backup, action: "복원…") }
                            if sync.versions.count > historyLimit {
                                Button("이전 백업 더 보기") { historyLimit += 30 }
                            }
                        }.padding(.top, 8)
                    }
                    Text("앱 설치와 손쉬운 사용·입력 모니터링 권한은 각 Mac에서 설정해야 합니다. 첨부 파일은 각각 20MB, 백업은 총 50MB까지 지원합니다. 공유 폴더는 사용하지 마세요.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !missingApps.isEmpty {
                        Label("이 Mac에 없는 앱: " + missingApps.joined(separator: ", "), systemImage: "app.badge.checkmark")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    localDisplayMappings
                }.padding(18)
            }
        }
        .confirmationDialog("개인 설정을 iCloud Drive에 저장할까요?", isPresented: $showConsent, titleVisibility: .visible) {
            Button("개인 폴더 선택…") { showFolderPicker = true }
            Button("취소", role: .cancel) {}
        } message: {
            Text("단축키, 워크플로, 템플릿 내용, 레이아웃과 연결된 이미지·파일의 사본이 선택한 폴더로 전송됩니다.")
        }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): pickerError = nil; Task { await sync.connect(to: url) }
            case .failure(let error): pickerError = error.localizedDescription
            }
        }
        .confirmationDialog("선택한 버전의 전체 설정으로 바꿀까요?", isPresented: $showRestore, titleVisibility: .visible) {
            Button("백업 후 적용") {
                if let selectedBackup { Task { await sync.restore(selectedBackup, resolving: selectedParents) } }
            }
            Button("취소", role: .cancel) { selectedBackup = nil }
        } message: {
            Text("현재 설정을 먼저 백업합니다. 동기화가 켜져 있으면 선택한 설정이 다른 Mac에도 전달됩니다. 현재 편집 내용을 마친 후 적용해 주세요.")
        }
    }

    private func backupRow(_ backup: SyncBackup, action: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(backup.device) · \(backup.createdAt.formatted(date: .abbreviated, time: .shortened))")
                Text("워크플로 \(backup.payload.state.workflows.count) · 템플릿 \(backup.payload.state.templates.count) · 앱 단축키 \(backup.payload.state.applicationShortcuts.count) · 레이아웃 \(backup.payload.state.layouts.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action) {
                selectedBackup = backup; selectedParents = sync.resolutionParents; showRestore = true
            }.disabled(sync.isBusy)
        }.font(.subheadline)
    }

    private var missingApps: [String] {
        var apps = runtime.store.applicationShortcuts.map { ($0.bundleIdentifier, $0.displayName) }
        apps += runtime.store.layouts.flatMap(\.placements).map { ($0.bundleIdentifier, $0.appName) }
        apps += runtime.store.workflows.flatMap(\.actions).compactMap {
            if case .launchApplication(let bundle, let name) = $0 { return (bundle, name) }
            return nil
        }
        return Array(Set(apps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.0) == nil }.map(\.1))).sorted()
    }

    @ViewBuilder private var localDisplayMappings: some View {
        let displays = runtime.layoutController.availableDisplays
        let targets = Array(Set(runtime.store.layouts.flatMap(\.placements).map(\.display)))
            .filter { target in !displays.contains { $0.id == target.uuid } }.sorted { $0.uuid < $1.uuid }
        if !targets.isEmpty {
            Divider()
            Text("이 Mac의 모니터 연결").font(.headline)
            Text("다른 Mac의 모니터를 여기서 사용할 화면에 연결하세요. 이 연결은 다른 Mac에 동기화하지 않습니다.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(targets, id: \.uuid) { target in
                Picker(target.name, selection: Binding(
                    get: { runtime.layoutController.displayMappings[target.uuid] ?? "" },
                    set: { runtime.layoutController.setDisplayMapping(source: target.uuid, target: $0) }
                )) {
                    Text("화면 선택 필요").tag("")
                    ForEach(displays) { display in Text(display.target.name).tag(display.id) }
                }
            }
            if let error = runtime.layoutController.mappingError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
    }
}
