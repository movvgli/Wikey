import AppKit
import SwiftUI
import WikeyCore

struct ApplicationsView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @State private var applications: [InstalledApplication] = []
    @State private var searchText = ""
    @State private var isLoading = true

    private var filteredApplications: [InstalledApplication] {
        guard !searchText.isEmpty else { return applications }
        return applications.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
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
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    applicationList
                }
            }
            .padding(38)
            .frame(maxWidth: 940, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("앱")
        .task {
            await reloadApplications()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("앱")
                        .font(.system(size: 32, weight: .bold))
                    Text("설치된 앱에 바로 실행 단축키를 지정합니다.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("새로고침", systemImage: "arrow.clockwise") {
                    Task { await reloadApplications() }
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("앱 검색", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
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
                        conflictMessage: conflictMessage(for: application)
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
}

private struct ApplicationShortcutRow: View {
    var application: InstalledApplication
    @Binding var shortcut: ShortcutGesture
    var conflictMessage: String?

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
                        Text("단축키 충돌")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CompactShortcutRecorderView(shortcut: $shortcut)
                    .frame(width: 228, alignment: .leading)
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
