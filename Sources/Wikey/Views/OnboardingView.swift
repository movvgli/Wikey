import AppKit
import SwiftUI
import WikeyCore

struct OnboardingView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @Binding var isPresented: Bool
    @State private var page = 0
    @State private var launchAtLogin = true

    var body: some View {
        VStack(spacing: 0) {
            onboardingHeader

            ZStack {
                if page == 0 {
                    introduction
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    permissions
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Divider()
            onboardingFooter
        }
        .frame(width: 660, height: 580)
    }

    private var onboardingHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Wikey 시작하기")
                    .font(.system(size: 25, weight: .semibold))
                Text(page == 0 ? "무엇을 할 수 있는지 먼저 알아볼게요." : "필요한 기능만 선택해서 켜세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.wikeyAccent : Color.secondary.opacity(0.18))
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .animation(.easeOut(duration: 0.2), value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("온보딩 \(page + 1)단계, 총 2단계")
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("반복하는 일을\n단축키 하나로 끝내세요")
                    .font(.system(size: 32, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("자주 하는 작업을 원하는 순서로 연결하면 Wikey가 어디서든 빠르게 실행합니다.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                OnboardingFeatureCard(
                    systemImage: "point.3.connected.trianglepath.dotted",
                    title: "여러 작업을 하나의 워크플로로",
                    detail: "앱 실행, 웹사이트, 템플릿과 창 배치를 순서대로 연결합니다."
                )
                OnboardingFeatureCard(
                    systemImage: "bolt.fill",
                    title: "어디서나 빠르게 실행",
                    detail: "한 번 또는 두 단계 단축키와 메뉴 막대에서 바로 실행합니다."
                )
                OnboardingFeatureCard(
                    systemImage: "lock.shield.fill",
                    title: "내 Mac에만 안전하게 저장",
                    detail: "워크플로와 템플릿은 외부 서버로 보내지 않고 이 Mac에 저장합니다."
                )
            }

            HStack(spacing: 10) {
                OnboardingStepLabel(number: 1, title: "워크플로 만들기")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                OnboardingStepLabel(number: 2, title: "동작 추가")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                OnboardingStepLabel(number: 3, title: "단축키로 실행")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("필요한 기능만 권한을 켜세요")
                    .font(.system(size: 28, weight: .bold))
                Text("기본 워크플로는 권한 없이도 사용할 수 있고, 필요한 기능은 나중에 설정할 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                OnboardingPermissionRow(
                    systemImage: "macwindow",
                    title: "창 배치와 자동 붙여넣기",
                    detail: "손쉬운 사용 권한을 사용합니다.",
                    granted: runtime.permissions.accessibilityGranted,
                    request: runtime.permissions.requestAccessibility
                )
                Divider().padding(.leading, 60)
                OnboardingPermissionRow(
                    systemImage: "keyboard",
                    title: "두 단계 단축키",
                    detail: "입력 모니터링 권한을 사용합니다.",
                    granted: runtime.permissions.inputMonitoringGranted,
                    request: runtime.permissions.requestInputMonitoring
                )
            }
            .padding(.horizontal, 16)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            }

            if runtime.permissions.inputMonitoringRestartRecommended {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(Color.wikeyAccent)
                    Text("입력 모니터링을 켠 뒤에는 Wikey를 다시 열어야 적용됩니다.")
                        .font(.subheadline)
                    Spacer()
                    Button("다시 열기") {
                        runtime.permissions.relaunchApplication()
                    }
                }
                .padding(12)
                .background(Color.wikeyAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var onboardingFooter: some View {
        HStack {
            if page == 0 {
                Button("건너뛰기") { complete(enableLoginItem: false) }
                    .buttonStyle(.borderless)
                Spacer()
                Button("다음") {
                    withAnimation(.easeInOut(duration: 0.24)) { page = 1 }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("이전") {
                    withAnimation(.easeInOut(duration: 0.24)) { page = 0 }
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("나중에 설정") { complete(enableLoginItem: false) }
                    .buttonStyle(.borderless)
                Button("Wikey 시작") { complete(enableLoginItem: launchAtLogin) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(.bar)
    }

    private func complete(enableLoginItem: Bool) {
        runtime.loginItem.setEnabled(enableLoginItem)
        didCompleteOnboarding = true
        isPresented = false
    }
}

private struct OnboardingFeatureCard: View {
    var systemImage: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.wikeyAccent)
                .frame(width: 40, height: 40)
                .background(Color.wikeyAccent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }
}

private struct OnboardingStepLabel: View {
    var number: Int
    var title: String

    var body: some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.wikeyAccent)
                .frame(width: 20, height: 20)
                .background(Color.wikeyAccent.opacity(0.1), in: Circle())
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct OnboardingPermissionRow: View {
    var systemImage: String
    var title: String
    var detail: String
    var granted: Bool
    var request: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(granted ? Color.green : Color.wikeyAccent)
                .frame(width: 32, height: 32)
                .background(
                    (granted ? Color.green : Color.wikeyAccent).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
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
