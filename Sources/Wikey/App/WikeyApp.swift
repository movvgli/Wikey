import AppKit
import SwiftUI
import WikeyCore

extension Color {
    static let wikeyAccent = Color(red: 0.31, green: 0.29, blue: 0.93)
}

@main
struct WikeyApp: App {
    @NSApplicationDelegateAdaptor(WikeyAppDelegate.self) private var appDelegate
    @State private var runtime = WikeyRuntime()
    @State private var updates = UpdateController()

    var body: some Scene {
        Window("Wikey", id: "main") {
            ContentView()
                .environment(runtime)
                .environment(updates)
                .tint(.wikeyAccent)
                .task { runtime.start() }
                .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 760)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .appInfo) {
                Button("업데이트 확인…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }

            CommandMenu("워크플로") {
                ForEach(runtime.store.workflows.filter(\.isEnabled)) { workflow in
                    Button(shortMenuTitle(workflow.name)) {
                        runtime.run(workflowID: workflow.id)
                    }
                }
            }
        }

        MenuBarExtra("Wikey", systemImage: menuBarSymbol) {
            MenuBarContentView()
                .environment(runtime)
                .environment(updates)
                .task { runtime.start() }
        }

        Settings {
            WikeySettingsView()
                .environment(runtime)
                .environment(updates)
                .tint(.wikeyAccent)
        }
    }

    private var menuBarSymbol: String {
        if runtime.lastRun?.failures.isEmpty == false { return "bolt.trianglebadge.exclamationmark" }
        if runtime.runner.runningWorkflowID != nil { return "bolt.badge.clock" }
        return "bolt.circle"
    }
}

final class WikeyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if ProcessInfo.processInfo.arguments.contains("--background") {
            DispatchQueue.main.async { NSApp.hide(nil) }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

func shortMenuTitle(_ title: String) -> String {
    title.count <= 30 ? title : String(title.prefix(27)) + "..."
}
