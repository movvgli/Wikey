import AppKit
import SwiftUI
import WikeyCore

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutGesture
    @State private var stepCount: Int

    init(shortcut: Binding<ShortcutGesture>) {
        _shortcut = shortcut
        _stepCount = State(initialValue: shortcut.wrappedValue.steps.count == 2 ? 2 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("입력 방식", selection: $stepCount) {
                Text("한 번에 누르기").tag(1)
                Text("두 번 이어서 누르기").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 390)

            HStack(spacing: 10) {
                KeyRecorderRepresentable(shortcut: $shortcut, stepCount: stepCount)
                    .frame(height: 42)
                    .frame(maxWidth: 390)
                if !shortcut.steps.isEmpty {
                    Button("지우기") { shortcut = ShortcutGesture() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }

            Text(visibleValidationMessage ?? helperText)
                .font(.caption)
                .foregroundStyle(visibleValidationMessage == nil ? Color.secondary : Color.red)
        }
        .onChange(of: stepCount) { _, count in
            if shortcut.steps.count > count {
                shortcut.steps = Array(shortcut.steps.prefix(count))
            }
        }
    }

    private var helperText: String {
        if shortcut.steps.isEmpty {
            return "입력란을 클릭한 뒤 원하는 키를 누르세요. 첫 입력에는 ⌘, ⌥, ⌃, ⇧ 중 하나가 필요합니다."
        }
        return stepCount == 2
            ? "첫 입력 뒤 1.2초 안에 두 번째 키를 누르면 실행됩니다."
            : "이 단축키는 다른 앱을 사용 중일 때도 동작합니다."
    }

    private var visibleValidationMessage: String? {
        shortcut.steps.isEmpty ? nil : shortcut.validationMessage
    }
}

private struct KeyRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: ShortcutGesture
    var stepCount: Int

    func makeCoordinator() -> Coordinator { Coordinator(shortcut: $shortcut) }

    func makeNSView(context: Context) -> KeyRecorderControl {
        let control = KeyRecorderControl()
        control.maximumSteps = stepCount
        control.shortcut = shortcut
        control.onChange = { context.coordinator.shortcut.wrappedValue = $0 }
        return control
    }

    func updateNSView(_ control: KeyRecorderControl, context: Context) {
        context.coordinator.shortcut = $shortcut
        control.maximumSteps = stepCount
        if !control.isRecording, control.shortcut != shortcut {
            control.shortcut = shortcut
        }
    }

    final class Coordinator {
        var shortcut: Binding<ShortcutGesture>
        init(shortcut: Binding<ShortcutGesture>) { self.shortcut = shortcut }
    }
}

private final class KeyRecorderControl: NSControl {
    var shortcut = ShortcutGesture() { didSet { needsDisplay = true } }
    var maximumSteps = 1
    var onChange: ((ShortcutGesture) -> Void)?
    private(set) var isRecording = false
    private var captured: [KeyChord] = []

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        captured = []
        isRecording = true
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            captured = []
            needsDisplay = true
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            shortcut = ShortcutGesture()
            isRecording = false
            captured = []
            onChange?(shortcut)
            return
        }

        let chord = KeyChord(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutModifiers(eventFlags: event.modifierFlags)
        )
        if captured.isEmpty && chord.modifiers.isEmpty {
            NSSound.beep()
            return
        }
        captured.append(chord)
        if captured.count >= maximumSteps {
            shortcut = ShortcutGesture(steps: captured)
            onChange?(shortcut)
            captured = []
            isRecording = false
        }
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        captured = []
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text: String
        if isRecording {
            text = captured.isEmpty ? "지금 단축키를 누르세요" : captured.map(\.displayName).joined(separator: " → ") + " → 다음 키"
        } else {
            text = shortcut.steps.isEmpty ? "클릭해 단축키 지정" : shortcut.displayName
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: shortcut.steps.isEmpty && !isRecording
                ? NSFont.systemFont(ofSize: 13)
                : NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: shortcut.steps.isEmpty && !isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attributes)
        let origin = NSPoint(x: 10, y: (bounds.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attributes)
    }
}
