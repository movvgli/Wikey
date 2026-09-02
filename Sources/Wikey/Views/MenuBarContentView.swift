import AppKit
import SwiftUI
import WikeyCore

struct MenuBarContentView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @Environment(UpdateController.self) private var updates
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let enabledWorkflows = runtime.store.workflows.filter(\.isEnabled)

        if enabledWorkflows.isEmpty {
            Text("활성화된 워크플로가 없습니다")
        } else {
            ForEach(enabledWorkflows) { workflow in
                Button {
                    runtime.run(workflowID: workflow.id)
                } label: {
                    Text(shortMenuTitle(workflow.name))
                    Text(workflow.shortcut.steps.isEmpty ? "미지정" : workflow.shortcut.displayName)
                }
                .disabled(
                    runtime.hotkeys.registrationErrors[workflow.id] != nil ||
                    runtime.runner.runningWorkflowID == workflow.id ||
                    workflow.actions.isEmpty
                )
            }
            Divider()
        }

        if let runningID = runtime.runner.runningWorkflowID,
           let workflow = runtime.store.workflows.first(where: { $0.id == runningID }) {
            Text("실행 중 · \(shortMenuTitle(workflow.name))")
            Divider()
        }

        if let lastRun = runtime.lastRun {
            Text(lastRun.failures.isEmpty ? "최근 실행 완료" : "최근 실행에서 오류 \(lastRun.failures.count)건")
            Text(shortMenuTitle(lastRun.workflowName))
            if let firstFailure = lastRun.failures.first {
                Text(shortMenuTitle(firstFailure.message))
            }
            Divider()
        }

        Button("Wikey 열기") {
            NSApp.unhide(nil)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("업데이트 확인…") {
            updates.checkForUpdates()
        }
        .disabled(!updates.canCheckForUpdates)
        SettingsLink { Text("설정…") }
        Divider()
        Button("Wikey 종료") { NSApp.terminate(nil) }
    }
}
