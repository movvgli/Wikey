import AppKit
import Carbon.HIToolbox
import Foundation

public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)

    public init(eventFlags: NSEvent.ModifierFlags) {
        var value: Self = []
        if eventFlags.contains(.command) { value.insert(.command) }
        if eventFlags.contains(.option) { value.insert(.option) }
        if eventFlags.contains(.control) { value.insert(.control) }
        if eventFlags.contains(.shift) { value.insert(.shift) }
        self = value
    }

    public init(cgFlags: CGEventFlags) {
        var value: Self = []
        if cgFlags.contains(.maskCommand) { value.insert(.command) }
        if cgFlags.contains(.maskAlternate) { value.insert(.option) }
        if cgFlags.contains(.maskControl) { value.insert(.control) }
        if cgFlags.contains(.maskShift) { value.insert(.shift) }
        self = value
    }

    public var carbonValue: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.control) { value |= UInt32(controlKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    public var cgFlags: CGEventFlags {
        var value: CGEventFlags = []
        if contains(.command) { value.insert(.maskCommand) }
        if contains(.option) { value.insert(.maskAlternate) }
        if contains(.control) { value.insert(.maskControl) }
        if contains(.shift) { value.insert(.maskShift) }
        return value
    }

    public var displayName: String {
        var value = ""
        if contains(.control) { value += "⌃" }
        if contains(.option) { value += "⌥" }
        if contains(.shift) { value += "⇧" }
        if contains(.command) { value += "⌘" }
        return value
    }
}

public struct KeyChord: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: ShortcutModifiers

    public init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var displayName: String {
        modifiers.displayName + KeyNameResolver.name(for: keyCode)
    }
}

public struct ShortcutGesture: Codable, Hashable, Sendable {
    public var steps: [KeyChord]

    public init(steps: [KeyChord] = []) {
        self.steps = Array(steps.prefix(2))
    }

    public var displayName: String {
        steps.isEmpty ? "단축키 없음" : steps.map(\.displayName).joined(separator: " → ")
    }

    public var validationMessage: String? {
        guard (1...2).contains(steps.count) else { return "단축키는 한 단계 또는 두 단계여야 합니다." }
        guard !steps[0].modifiers.isEmpty else { return "첫 단계에는 보조키가 하나 이상 필요합니다." }
        return nil
    }
}

public enum ShortcutConflictDetector {
    public static func conflicts(in workflows: [Workflow]) -> [UUID: String] {
        let enabled = workflows.filter { $0.isEnabled && $0.shortcut.validationMessage == nil }
        var result: [UUID: String] = [:]

        for index in enabled.indices {
            for otherIndex in enabled.indices where otherIndex > index {
                let lhs = enabled[index]
                let rhs = enabled[otherIndex]
                if lhs.shortcut == rhs.shortcut {
                    result[lhs.id] = "‘\(rhs.name)’과 단축키가 같습니다."
                    result[rhs.id] = "‘\(lhs.name)’과 단축키가 같습니다."
                } else if lhs.shortcut.steps.first == rhs.shortcut.steps.first,
                          lhs.shortcut.steps.count != rhs.shortcut.steps.count {
                    result[lhs.id] = "단일 단축키와 연속 단축키의 첫 단계가 겹칩니다."
                    result[rhs.id] = "단일 단축키와 연속 단축키의 첫 단계가 겹칩니다."
                }
            }
        }
        return result
    }
}

public enum KeyNameResolver {
    private static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥",
        49: "Space", 50: "`", 51: "⌫", 53: "Esc", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12",
        115: "Home", 116: "Page Up", 117: "⌦", 119: "End", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
