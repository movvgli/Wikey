import Foundation
import Testing
@testable import WikeyCore

struct ShortcutModelsTests {
    @Test func gestureRoundTripAndDisplayName() throws {
        let gesture = ShortcutGesture(steps: [
            KeyChord(keyCode: 40, modifiers: [.control, .option]),
            KeyChord(keyCode: 13, modifiers: []),
        ])
        let data = try JSONEncoder().encode(gesture)
        #expect(try JSONDecoder().decode(ShortcutGesture.self, from: data) == gesture)
        #expect(gesture.displayName == "⌃⌥K → W")
    }

    @Test func firstStepRequiresModifier() {
        let gesture = ShortcutGesture(steps: [KeyChord(keyCode: 0, modifiers: [])])
        #expect(gesture.validationMessage != nil)
    }

    @Test func duplicateShortcutConflicts() {
        let gesture = ShortcutGesture(steps: [KeyChord(keyCode: 40, modifiers: [.command])])
        let first = Workflow(name: "첫 번째", shortcut: gesture)
        let second = Workflow(name: "두 번째", shortcut: gesture)
        let conflicts = ShortcutConflictDetector.conflicts(in: [first, second])
        #expect(conflicts[first.id] != nil)
        #expect(conflicts[second.id] != nil)
    }

    @Test func singleAndSequencePrefixConflict() {
        let prefix = KeyChord(keyCode: 40, modifiers: [.control, .option])
        let single = Workflow(name: "단일", shortcut: ShortcutGesture(steps: [prefix]))
        let sequence = Workflow(
            name: "연속",
            shortcut: ShortcutGesture(steps: [prefix, KeyChord(keyCode: 13, modifiers: [])])
        )
        let conflicts = ShortcutConflictDetector.conflicts(in: [single, sequence])
        #expect(conflicts.count == 2)
    }

    @Test func applicationShortcutConflictsWithWorkflow() {
        let gesture = ShortcutGesture(steps: [KeyChord(keyCode: 1, modifiers: [.command, .shift])])
        let workflow = Workflow(name: "메시지 보내기", shortcut: gesture)
        let application = ApplicationShortcut(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            shortcut: gesture
        )

        let conflicts = ShortcutConflictDetector.conflicts(
            workflows: [workflow],
            applicationShortcuts: [application]
        )

        #expect(conflicts.workflows[workflow.id] != nil)
        #expect(conflicts.applications[application.id] != nil)
    }

    @Test func layoutConflictsWithBothApplicationAndWorkflow() {
        let shortcut = ShortcutGesture(steps: [.init(keyCode: 23, modifiers: [.command])])
        let workflow = Workflow(name: "작업", shortcut: shortcut)
        let application = ApplicationShortcut(bundleIdentifier: "com.apple.TextEdit", displayName: "텍스트 편집기", shortcut: shortcut)
        let layout = WindowLayout(name: "작업 배치", shortcut: shortcut)
        let result = ShortcutConflictDetector.conflicts(workflows: [workflow], applicationShortcuts: [application], layouts: [layout])
        #expect(result.workflows[workflow.id] != nil)
        #expect(result.applications[application.id] != nil)
        #expect(result.layouts[layout.id] != nil)
    }

    @Test func distinctSequenceEndingsCanSharePrefixAcrossTabs() {
        let prefix = KeyChord(keyCode: 40, modifiers: [.control, .option])
        let workflow = Workflow(shortcut: .init(steps: [prefix, .init(keyCode: 0, modifiers: [])]))
        let layout = WindowLayout(shortcut: .init(steps: [prefix, .init(keyCode: 1, modifiers: [])]))
        let result = ShortcutConflictDetector.conflicts(workflows: [workflow], applicationShortcuts: [], layouts: [layout])
        #expect(result.workflows.isEmpty)
        #expect(result.layouts.isEmpty)
    }

    @Test func disabledWorkflowDoesNotBlockAppOrLayoutShortcut() {
        let shortcut = ShortcutGesture(steps: [.init(keyCode: 23, modifiers: [.command])])
        let workflow = Workflow(isEnabled: false, shortcut: shortcut)
        let layout = WindowLayout(shortcut: shortcut)
        let result = ShortcutConflictDetector.conflicts(workflows: [workflow], applicationShortcuts: [], layouts: [layout])
        #expect(result.workflows.isEmpty)
        #expect(result.layouts.isEmpty)
    }

    @Test func legacyLayoutLoadsAndNewShortcutRoundTrips() throws {
        let id = UUID()
        let data = Data("{\"id\":\"\(id)\",\"name\":\"기존 배치\",\"placements\":[]}".utf8)
        var layout = try JSONDecoder().decode(WindowLayout.self, from: data)
        #expect(layout.id == id)
        #expect(layout.shortcut.steps.isEmpty)
        layout.shortcut = .init(steps: [.init(keyCode: 23, modifiers: [.command, .option])])
        let encoded = try JSONEncoder().encode(layout)
        #expect(try JSONDecoder().decode(WindowLayout.self, from: encoded) == layout)
    }

    @Test func sequenceConsumesMatchedKeyUntilRelease() {
        let chord = KeyChord(keyCode: 1, modifiers: [.command])
        var state = SequenceKeyState(acceptable: [chord])
        #expect(state.receive(chord: chord, isKeyDown: true, isRepeat: false) == .matched)
        #expect(state.receive(chord: chord, isKeyDown: true, isRepeat: true) == .consume)
        // Releasing a modifier before the physical key must still finish the match.
        let released = KeyChord(keyCode: 1, modifiers: [])
        #expect(state.receive(chord: released, isKeyDown: false, isRepeat: false) == .finish(chord, consume: true))
    }

    @Test func sequenceCancelsOnWrongKeyWithoutSwallowingTyping() {
        var state = SequenceKeyState(acceptable: [.init(keyCode: 1, modifiers: [])])
        #expect(state.receive(chord: .init(keyCode: 0, modifiers: []), isKeyDown: true, isRepeat: false) == .finish(nil, consume: false))
    }

    @Test func sequenceIgnoresPrefixReleaseAndConsumesEscape() {
        var state = SequenceKeyState(acceptable: [.init(keyCode: 1, modifiers: [])])
        #expect(state.receive(chord: .init(keyCode: 40, modifiers: [.control]), isKeyDown: false, isRepeat: false) == .passThrough)
        #expect(state.receive(chord: .init(keyCode: 53, modifiers: []), isKeyDown: true, isRepeat: false) == .finish(nil, consume: true))
    }
}
