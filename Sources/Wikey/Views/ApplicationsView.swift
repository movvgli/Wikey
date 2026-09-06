import AppKit
import SwiftUI
import WikeyCore

struct ApplicationsView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @State private var applications: [InstalledApplication] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showsAssignedOnly = false

    private var missingApplications: [ApplicationShortcut] {
        runtime.store.applicationShortcuts.filter { shortcut in
            !applications.contains { $0.bundleIdentifier == shortcut.bundleIdentifier }
                && NSWorkspace.shared.urlForApplication(withBundleIdentifier: shortcut.bundleIdentifier) == nil
        }
    }

    private var filteredApplications: [InstalledApplication] {
        return applications.filter { application in
            let savedShortcut = runtime.store.applicationShortcuts.first {
                $0.bundleIdentifier == application.bundleIdentifier
            }
            let matchesSearch = searchText.isEmpty
                || application.displayName.localizedCaseInsensitiveContains(searchText)
                || application.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
                || URL(fileURLWithPath: application.path).deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(searchText)
                || savedShortcut?.displayName.localizedCaseInsensitiveContains(searchText) == true
            let hasShortcut = savedShortcut != nil
            return matchesSearch && (!showsAssignedOnly || hasShortcut)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("설치된 앱을 불러오는 중입니다.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else if filteredApplications.isEmpty {
                    ContentUnavailableView {
                        Label(showsAssignedOnly && searchText.isEmpty ? "지정된 단축키가 없습니다" : "앱을 찾을 수 없습니다", systemImage: "app.dashed")
                    } description: {
                        Text(showsAssignedOnly ? "‘단축키 지정된 앱만’을 끄고 앱에 단축키를 지정하세요." : "다른 이름으로 검색하거나 앱 목록을 새로고침해 주세요.")
                    }
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    applicationList
                }

                if !isLoading && !missingApplications.isEmpty {
                    WikeySection(title: "설치 위치를 찾을 수 없는 앱", detail: "앱을 다시 설치하거나 사용하지 않는 단축키를 지워 주세요.") {
                        PlainPanel {
                            VStack(spacing: 12) {
                                ForEach(missingApplications) { application in
                                    HStack {
                                        Label(application.displayName, systemImage: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                        Spacer()
                                        ShortcutBadge(text: application.shortcut.displayName)
                                        Button("단축키 삭제") {
                                            runtime.setApplicationShortcut(
                                                bundleIdentifier: application.bundleIdentifier,
                                                displayName: application.displayName,
                                                shortcut: ShortcutGesture()
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(WikeyPageMetrics.padding)
            .frame(maxWidth: WikeyPageMetrics.maximumWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("앱")
        .task {
            await reloadApplications()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            WikeyPageHeader(title: "앱", subtitle: "설치된 앱에 단축키를 지정하고 바로 실행합니다.") {
                Button("새로고침", systemImage: "arrow.clockwise") {
                    Task { await reloadApplications() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isLoading)
            }

            WikeySearchField(prompt: "앱 검색", text: $searchText)
            HStack {
                Text("설치된 앱 \(applications.count)개 · 단축키 \(runtime.store.applicationShortcuts.count)개")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("단축키 지정된 앱만", isOn: $showsAssignedOnly)
                    .toggleStyle(.checkbox)
            }
        }
    }

    private var applicationList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("앱")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("단축키")
                    .frame(width: 228, alignment: .leading)
                Text("실행")
                    .frame(width: 32)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .frame(height: 44)

            Divider()
                .padding(.horizontal, 18)

            LazyVStack(spacing: 0) {
                ForEach(filteredApplications) { application in
                    ApplicationShortcutRow(
                        application: application,
                        shortcut: shortcutBinding(for: application),
                        conflictMessage: conflictMessage(for: application),
                        launchError: runtime.applicationLaunchError(bundleIdentifier: application.bundleIdentifier),
                        isRunning: isRunning(application),
                        run: {
                            runtime.runApplication(
                                bundleIdentifier: application.bundleIdentifier,
                                displayName: application.displayName
                            )
                        }
                    )
                    if application.id != filteredApplications.last?.id {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
        }
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
    }

    private func shortcutBinding(for application: InstalledApplication) -> Binding<ShortcutGesture> {
        Binding(
            get: {
                runtime.store.applicationShortcuts.first(where: {
                    $0.bundleIdentifier == application.bundleIdentifier
                })?.shortcut ?? ShortcutGesture()
            },
            set: { shortcut in
                runtime.setApplicationShortcut(
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.displayName,
                    shortcut: shortcut
                )
            }
        )
    }

    private func conflictMessage(for application: InstalledApplication) -> String? {
        guard let shortcut = runtime.store.applicationShortcuts.first(where: {
            $0.bundleIdentifier == application.bundleIdentifier
        }) else { return nil }
        return runtime.hotkeys.applicationRegistrationErrors[shortcut.id]
    }

    private func reloadApplications() async {
        isLoading = true
        applications = await InstalledApplicationCatalog.load()
        isLoading = false
    }

    private func isRunning(_ application: InstalledApplication) -> Bool {
        guard let id = runtime.applicationRunID(bundleIdentifier: application.bundleIdentifier) else { return false }
        return runtime.runner.runningWorkflowID == id || runtime.runner.queuedWorkflowIDs.contains(id)
    }
}

private struct ApplicationShortcutRow: View {
    var application: InstalledApplication
    @Binding var shortcut: ShortcutGesture
    var conflictMessage: String?
    var launchError: String?
    var isRunning: Bool
    var run: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 16) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    if conflictMessage != nil {
                        Text("단축키 확인 필요")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CompactShortcutRecorderView(shortcut: $shortcut)
                    .frame(width: 228, alignment: .leading)
                Button(action: run) {
                    Group {
                        if isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
                .foregroundStyle(Color.wikeyAccent)
                .help("\(application.displayName) 열기")
                .accessibilityLabel("\(application.displayName) 열기")
            }
            if let launchError {
                Label(launchError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 48)
            }

            if let conflictMessage {
                Label(conflictMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 48)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, conflictMessage == nil ? 12 : 9)
    }
}
