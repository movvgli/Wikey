import AppKit
import SwiftUI
import WikeyCore

struct OnboardingView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @Binding var isPresented: Bool
    @State private var launchAtLogin = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wikey 시작하기")
                            .font(.system(size: 28, weight: .semibold))
                        Text("먼저 필요한 기능만 켜 주세요.")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    OnboardingPermissionRow(
                        title: "창 배치와 자동 붙여넣기",
                        detail: "손쉬운 사용 권한을 사용합니다.",
                        granted: runtime.permissions.accessibilityGranted,
                        request: runtime.permissions.requestAccessibility
                    )
                    Divider().padding(.leading, 46)
                    OnboardingPermissionRow(
                        title: "두 단계 단축키",
                        detail: "입력 모니터링 권한을 사용합니다.",
                        granted: runtime.permissions.inputMonitoringGranted,
                        request: runtime.permissions.requestInputMonitoring
                    )
                }
                .padding(.horizontal, 16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Mac 로그인 시 Wikey 실행", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                    Text("메인 창은 띄우지 않고 메뉴 막대와 단축키만 준비합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("권한을 켜지 않아도 앱 실행, 웹사이트 열기와 템플릿 복사는 사용할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)

            Divider()

            HStack {
                Button("나중에 설정") { complete(enableLoginItem: false) }
                    .buttonStyle(.borderless)
                Spacer()
                Button("완료") { complete(enableLoginItem: launchAtLogin) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(.bar)
        }
        .frame(width: 600)
    }

    private func complete(enableLoginItem: Bool) {
        runtime.loginItem.setEnabled(enableLoginItem)
        didCompleteOnboarding = true
        isPresented = false
    }
}

private struct OnboardingPermissionRow: View {
    var title: String
    var detail: String
    var granted: Bool
    var request: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                StatusPill(title: "완료", tone: .good)
            } else {
                Button("권한 켜기", action: request)
            }
        }
        .padding(.vertical, 14)
    }
}
