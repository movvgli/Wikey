import Foundation
import Observation

@MainActor
@Observable
public final class WikeyRuntime {
    public let store: WikeyStore
    public let permissions: PermissionCenter
    public let loginItem: LoginItemService
    public let applications: ApplicationController
    public let clipboard: ClipboardService
    public let layoutController: WindowLayoutController
    public let hotkeys: HotkeyRegistrar
    public let runner: WorkflowRunner

    public private(set) var lastRun: RunSummary?
    public private(set) var hasStarted = false

    public init(storeRootURL: URL? = nil) {
        let store = WikeyStore(rootURL: storeRootURL)
        let applications = ApplicationController()
        let clipboard = ClipboardService()
        let layoutController = WindowLayoutController(applications: applications)
        let hotkeys = HotkeyRegistrar()

        self.store = store
        self.permissions = PermissionCenter()
        self.loginItem = LoginItemService()
        self.applications = applications
        self.clipboard = clipboard
        self.layoutController = layoutController
        self.hotkeys = hotkeys
        self.runner = WorkflowRunner(
            store: store,
            applications: applications,
            clipboard: clipboard,
            layouts: layoutController
        )

        hotkeys.onWorkflow = { [weak runner = self.runner] id in
            Task { @MainActor in runner?.submit(workflowID: id) }
        }
        self.runner.onSummary = { [weak self] summary in
            self?.lastRun = summary
        }
    }

    public func start() {
        guard !hasStarted else { return }
        store.load()
        reloadHotkeys()
        permissions.refresh()
        loginItem.refresh()
        hasStarted = true
    }

    public func saveAndReloadHotkeys() {
        store.save()
        reloadHotkeys()
    }

    public func reloadHotkeys() {
        hotkeys.configure(workflows: store.workflows)
    }

    public func run(workflowID: UUID) {
        runner.submit(workflowID: workflowID)
    }
}
