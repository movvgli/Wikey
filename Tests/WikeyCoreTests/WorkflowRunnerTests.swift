import AppKit
import Foundation
import Testing
@testable import WikeyCore

@MainActor
struct WorkflowRunnerTests {
    @Test func rapidSubmissionsHaveOneWorkerAndIgnoreDuplicates() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let started = RunnerGate()
        let release = RunnerGate()
        fixture.applications.beforeLaunch = { id in
            if id == "first" {
                started.open()
                await release.wait()
            }
        }
        let first = Workflow(name: "첫 번째", actions: [.launchApplication(bundleIdentifier: "first", displayName: "First")])
        let second = Workflow(name: "두 번째", actions: [.launchApplication(bundleIdentifier: "second", displayName: "Second")])
        let done = fixture.finishAfter(2)

        fixture.runner.submit(workflow: first)
        fixture.runner.submit(workflow: second)
        fixture.runner.submit(workflow: first)
        await started.wait()
        await Task.yield()
        #expect(fixture.events.values == ["launch.begin:first"])
        #expect(fixture.runner.queuedWorkflowIDs == [second.id])
        release.open()
        await done.wait()

        #expect(fixture.events.values == ["launch.begin:first", "launch.end:first", "launch.begin:second", "launch.end:second"])
        #expect(fixture.summaries.map(\.workflowID) == [first.id, second.id])
        #expect(fixture.runner.runningWorkflowID == nil)
        #expect(fixture.runner.currentActionTitle == nil)
    }

    @Test func launchAndNestedWorkflowRetainTheirInputTarget() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        fixture.applications.original = nil
        let nested = Workflow(name: "앱 열기", actions: [.launchApplication(bundleIdentifier: "editor", displayName: "Editor")])
        fixture.store.workflows = [nested]
        let done = fixture.finishAfter(1)

        fixture.runner.submit(workflow: Workflow(actions: [
            .runWorkflow(workflowID: nested.id),
            .pressKey(.shiftEnter),
            .pasteFiles(filePaths: ["test.pdf"]),
        ]))
        await done.wait()

        #expect(fixture.keyboard.targets.map { $0?.processIdentifier } == [NSRunningApplication.current.processIdentifier])
        #expect(fixture.clipboard.targets.map { $0?.processIdentifier } == [NSRunningApplication.current.processIdentifier])
        #expect(fixture.summaries.first?.failures.isEmpty == true)
    }

    @Test func URLBecomesInputTarget() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        fixture.applications.original = nil
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [.openURL("https://example.com"), .pressKey(.enter)]))
        await done.wait()

        #expect(fixture.events.values == ["url:https://example.com", "key:enter"])
        #expect(fixture.keyboard.targets.first??.processIdentifier == NSRunningApplication.current.processIdentifier)
    }

    @Test func queuedRunCapturesInputTargetWhenSubmitted() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let started = RunnerGate()
        let release = RunnerGate()
        fixture.applications.beforeLaunch = { _ in
            started.open()
            await release.wait()
        }
        let done = fixture.finishAfter(2)
        fixture.runner.submit(workflow: Workflow(actions: [.launchApplication(bundleIdentifier: "wait", displayName: "Wait")]))
        await started.wait()
        fixture.applications.original = .current
        fixture.runner.submit(workflow: Workflow(actions: [.pressKey(.enter)]))
        fixture.applications.original = nil
        release.open()
        await done.wait()

        #expect(fixture.keyboard.targets.first??.processIdentifier == NSRunningApplication.current.processIdentifier)
    }

    @Test func failedLaunchStopsBeforePasteOrEnter() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        fixture.applications.beforeLaunch = { _ in throw AutomationError.applicationNotFound("missing") }
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [
            .launchApplication(bundleIdentifier: "missing", displayName: "Missing"),
            .pasteImages(filePaths: ["test.png"]),
            .pressKey(.enter),
        ]))
        await done.wait()

        #expect(fixture.events.values == ["launch.begin:missing"])
        #expect(fixture.summaries.first?.failures.count == 1)
        #expect(fixture.summaries.first?.failures.first?.actionTitle == "앱 실행 · Missing")
    }

    @Test func nestedFailureStopsOuterActionsAndReportsNestedName() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let nested = Workflow(name: "내용 붙여넣기", actions: [.copyTemplate(templateID: UUID(), mode: .copyAndPaste)])
        fixture.store.workflows = [nested]
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [.runWorkflow(workflowID: nested.id), .pressKey(.enter)]))
        await done.wait()

        #expect(fixture.events.values.isEmpty)
        #expect(fixture.summaries.first?.failures.first?.actionTitle == "내용 붙여넣기 · 템플릿 붙여넣기")
    }

    @Test func pasteMustFinishBeforeEnterAndNextClipboardWrite() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let started = RunnerGate()
        let release = RunnerGate()
        fixture.clipboard.beforePaste = {
            started.open()
            await release.wait()
        }
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [
            .pasteImages(filePaths: ["first.png"]),
            .pressKey(.enter),
            .pasteFiles(filePaths: ["second.pdf"]),
        ]))
        await started.wait()
        #expect(fixture.events.values == ["copy.images", "paste.begin"])
        release.open()
        await done.wait()

        #expect(fixture.events.values == ["copy.images", "paste.begin", "paste.end", "key:enter", "copy.files", "paste.begin", "paste.end"])
    }

    @Test func cancellationStopsCurrentRunAndClearsQueuedRuns() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let started = RunnerGate()
        fixture.clipboard.beforePaste = {
            started.open()
            try await Task.sleep(for: .seconds(30))
        }
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [.pasteFiles(filePaths: ["test.pdf"]), .pressKey(.enter)]))
        fixture.runner.submit(workflow: Workflow(actions: [.launchApplication(bundleIdentifier: "queued", displayName: "Queued")]))
        await started.wait()
        fixture.runner.cancel()
        await done.wait()

        #expect(fixture.events.values == ["copy.files", "paste.begin"])
        #expect(fixture.runner.queuedWorkflowIDs.isEmpty)
        #expect(fixture.runner.runningWorkflowID == nil)
        #expect(fixture.summaries.first?.failures.first?.message == "실행을 중단했습니다.")
    }

    @Test func cyclicWorkflowStopsWithoutRecursingOrSendingInput() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let id = UUID()
        let workflow = Workflow(id: id, actions: [.runWorkflow(workflowID: id), .pressKey(.enter)])
        fixture.store.workflows = [workflow]
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflowID: id)
        await done.wait()

        #expect(fixture.events.values.isEmpty)
        #expect(fixture.summaries.first?.failures.count == 1)
    }

    @Test func emptyWorkflowReportsFailure() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow())
        await done.wait()

        #expect(fixture.summaries.first?.failures.first?.message == AutomationError.workflowIsEmpty.localizedDescription)
    }

    @Test func cancellationInterruptsWaitBeforeEnter() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [.wait(seconds: 30), .pressKey(.enter)]))
        for _ in 0..<100 {
            if fixture.runner.currentActionTitle != nil { break }
            await Task.yield()
        }
        #expect(fixture.runner.currentActionTitle != nil)
        fixture.runner.cancel()
        await done.wait()

        #expect(fixture.events.values.isEmpty)
        #expect(fixture.summaries.first?.failures.first?.message == "실행을 중단했습니다.")
    }

    @Test func invalidWaitStopsBeforeEnter() async {
        let fixture = RunnerFixture()
        defer { fixture.cleanUp() }
        let done = fixture.finishAfter(1)
        fixture.runner.submit(workflow: Workflow(actions: [.wait(seconds: .infinity), .pressKey(.enter)]))
        await done.wait()

        #expect(fixture.events.values.isEmpty)
        #expect(fixture.summaries.first?.failures.first?.message == AutomationError.invalidWaitDuration.localizedDescription)
    }
}

@MainActor
private final class RunnerGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

@MainActor
private final class RunnerEvents {
    var values: [String] = []
}

@MainActor
private final class RunnerFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let events = RunnerEvents()
    let store: WikeyStore
    let applications: RunnerApplications
    let clipboard: RunnerClipboard
    let keyboard: RunnerKeyboard
    let runner: WorkflowRunner
    var summaries: [RunSummary] = []

    init() {
        store = WikeyStore(rootURL: root)
        applications = RunnerApplications(events: events)
        clipboard = RunnerClipboard(events: events)
        keyboard = RunnerKeyboard(events: events)
        runner = WorkflowRunner(
            store: store,
            applicationService: applications,
            clipboardService: clipboard,
            keyboardService: keyboard,
            layoutService: RunnerLayouts()
        )
    }

    func finishAfter(_ count: Int) -> RunnerGate {
        let gate = RunnerGate()
        runner.onSummary = { [weak self] summary in
            guard let self else { return }
            summaries.append(summary)
            if summaries.count == count { gate.open() }
        }
        return gate
    }

    func cleanUp() {
        runner.cancel()
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
private final class RunnerApplications: WorkflowApplicationControlling {
    let events: RunnerEvents
    var original: NSRunningApplication? = .current
    var beforeLaunch: ((String) async throws -> Void)?

    init(events: RunnerEvents) { self.events = events }
    func inputTargetApplication() -> NSRunningApplication? { original }

    func launch(bundleIdentifier: String, activates: Bool) async throws -> NSRunningApplication {
        events.values.append("launch.begin:\(bundleIdentifier)")
        try await beforeLaunch?(bundleIdentifier)
        events.values.append("launch.end:\(bundleIdentifier)")
        return .current
    }

    func openURL(_ value: String) async throws -> NSRunningApplication {
        events.values.append("url:\(value)")
        return .current
    }
}

@MainActor
private final class RunnerClipboard: WorkflowClipboardControlling {
    let events: RunnerEvents
    var targets: [NSRunningApplication?] = []
    var beforePaste: (() async throws -> Void)?

    init(events: RunnerEvents) { self.events = events }
    func copy(_ document: NSAttributedString) throws { events.values.append("copy.template") }
    func copyImages(at filePaths: [String]) throws { events.values.append("copy.images") }
    func copyFiles(at filePaths: [String]) throws { events.values.append("copy.files") }

    func paste(into application: NSRunningApplication?) async throws {
        targets.append(application)
        events.values.append("paste.begin")
        try await beforePaste?()
        events.values.append("paste.end")
    }
}

@MainActor
private final class RunnerKeyboard: WorkflowKeyboardControlling {
    let events: RunnerEvents
    var targets: [NSRunningApplication?] = []
    init(events: RunnerEvents) { self.events = events }

    func press(_ key: WorkflowKeyPress, into application: NSRunningApplication?) async throws {
        targets.append(application)
        events.values.append("key:\(key.rawValue)")
    }
}

@MainActor
private final class RunnerLayouts: WorkflowLayoutControlling {
    func apply(_ layout: WindowLayout) async -> [ActionFailure] { [] }
}
