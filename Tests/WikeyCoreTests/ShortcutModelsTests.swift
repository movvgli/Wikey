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
}
