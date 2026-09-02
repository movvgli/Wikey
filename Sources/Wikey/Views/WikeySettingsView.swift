import SwiftUI
import WikeyCore

struct WikeySettingsView: View {
    @Environment(WikeyRuntime.self) private var runtime

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("설정")
                        .font(.system(size: 30, weight: .semibold))
                    Text("필요한 기능만 권한을 켜고, Wikey의 실행 방식을 정할 수 있습니다.")
                        .foregroundStyle(.secondary)
                }

                WikeySection(
                    title: "권한",
                    detail: "단일 단축키, 앱 실행, 웹사이트 열기와 클립보드 복사는 권한 없이도 사용할 수 있습니다."
                ) {
                    if !isRunningFromApplications {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Wikey를 응용 프로그램 폴더에서 실행해 주세요")
                                    .font(.headline)
                                Text("macOS 권한은 앱의 설치 위치와 서명을 구분합니다. 위치가 바뀌면 기존 권한이 적용되지 않을 수 있습니다.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                        }
                    }

                    PlainPanel {
                        VStack(spacing: 0) {
                            PermissionSettingRow(
                                title: "손쉬운 사용",
                                detail: "창 배치와 자동 붙여넣기에 사용",
                                granted: runtime.permissions.accessibilityGranted,
                                request: runtime.permissions.requestAccessibility,
                                open: runtime.permissions.openAccessibilitySettings
                            )
                            Divider().padding(.leading, 42)
                            PermissionSettingRow(
                                title: "입력 모니터링",
                                detail: "두 단계로 이어 누르는 단축키에 사용",
                                granted: runtime.permissions.inputMonitoringGranted,
                                request: runtime.permissions.requestInputMonitoring,
                                open: runtime.permissions.openInputMonitoringSettings
                            )
                        }
                    }

                    Button("권한 상태 새로고침", systemImage: "arrow.clockwise") {
                        runtime.permissions.refresh()
                    }
                    .buttonStyle(.borderless)
                }

                Divider()

                WikeySection(title: "일반") {
                    PlainPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("로그인 시 Wikey 실행")
                                        .font(.headline)
                                    Text("메인 창은 열지 않고 메뉴 막대와 단축키만 준비합니다.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle(
                                    "로그인 시 실행",
                                    isOn: Binding(
                                        get: { runtime.loginItem.isEnabled },
                                        set: { runtime.loginItem.setEnabled($0) }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                            }

                            if runtime.loginItem.status == .requiresApproval {
                                Label("macOS 설정에서 로그인 항목을 허용해 주세요.", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("로그인 항목 설정 열기") { runtime.loginItem.openSystemSettings() }
                            }
                            if let error = runtime.loginItem.lastError {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                if !runtime.hotkeys.registrationErrors.isEmpty || runtime.store.lastPersistenceError != nil {
                    Divider()
                    WikeySection(title: "확인 필요") {
                        PlainPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(runtime.hotkeys.registrationErrors.keys), id: \.self) { id in
                                    let name = runtime.store.workflows.first(where: { $0.id == id })?.name ?? "워크플로"
                                    Label(
                                        "\(name): \(runtime.hotkeys.registrationErrors[id] ?? "단축키 오류")",
                                        systemImage: "exclamationmark.triangle.fill"
                                    )
                                    .foregroundStyle(.orange)
                                }
                                if let error = runtime.store.lastPersistenceError {
                                    Label(error, systemImage: "externaldrive.badge.exclamationmark")
                                        .foregroundStyle(.red)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 560, minHeight: 460)
        .navigationTitle("설정")
    }

    private var isRunningFromApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }
}

private struct PermissionSettingRow: View {
    var title: String
    var detail: String
    var granted: Bool
    var request: () -> Void
    var open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .font(.title3)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(title: granted ? "허용됨" : "꺼짐", tone: granted ? .good : .neutral)
            Button(granted ? "시스템 설정" : "권한 켜기", action: granted ? open : request)
        }
        .padding(.vertical, 12)
    }
}
