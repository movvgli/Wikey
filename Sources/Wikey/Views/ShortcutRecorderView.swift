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
            ? "첫 입력 뒤 1.2초 안에 두 번째 키를 누르세요. 손쉬운 사용과 입력 모니터링 권한이 필요합니다."
            : "이 단축키는 다른 앱을 사용 중일 때도 동작합니다."
    }

    private var visibleValidationMessage: String? {
        shortcut.steps.isEmpty ? nil : shortcut.validationMessage
    }
}

struct CompactShortcutRecorderView: View {
    @Binding var shortcut: ShortcutGesture
    @State private var recordingRequest = 0

    var body: some View {
        HStack(spacing: 8) {
            KeyRecorderRepresentable(
                shortcut: $shortcut,
                stepCount: 1,
                recordingRequest: recordingRequest
            )
                .frame(width: 190, height: 36)

            Button {
                if shortcut.steps.isEmpty {
                    recordingRequest += 1
                } else {
                    shortcut = ShortcutGesture()
                }
            } label: {
                Image(systemName: shortcut.steps.isEmpty ? "plus.circle" : "xmark.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(shortcut.steps.isEmpty ? Color.secondary : Color.wikeyAccent)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(shortcut.steps.isEmpty ? "단축키 지정" : "단축키 지우기")
        }
    }
}

private struct KeyRecorderRepresentable: NSViewRepresentable {
    @Environment(WikeyRuntime.self) private var runtime
    @Binding var shortcut: ShortcutGesture
    var stepCount: Int
    var recordingRequest: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(shortcut: $shortcut) }

    func makeNSView(context: Context) -> KeyRecorderControl {
        let control = KeyRecorderControl()
        control.maximumSteps = stepCount
        control.shortcut = shortcut
        control.onChange = { context.coordinator.shortcut.wrappedValue = $0 }
        let hotkeys = runtime.hotkeys
        let token = context.coordinator.recordingToken
        control.onRecordingChange = { recording in
            if recording { hotkeys.beginRecording(token: token) }
            else { hotkeys.endRecording(token: token) }
        }
        return control
    }

    func updateNSView(_ control: KeyRecorderControl, context: Context) {
        context.coordinator.shortcut = $shortcut
        control.maximumSteps = stepCount
        if control.shortcut != shortcut {
            // SwiftUI clear buttons need not resign this AppKit first responder.
            // An external value change must end recording and restore hotkeys too.
            control.endRecording()
            control.shortcut = shortcut
        }
        if context.coordinator.lastRecordingRequest != recordingRequest {
            context.coordinator.lastRecordingRequest = recordingRequest
            control.beginRecording()
        }
    }

    final class Coordinator {
        var shortcut: Binding<ShortcutGesture>
        let recordingToken = UUID()
        var lastRecordingRequest = 0
        init(shortcut: Binding<ShortcutGesture>) { self.shortcut = shortcut }
    }

    static func dismantleNSView(_ control: KeyRecorderControl, coordinator: Coordinator) {
        control.endRecording()
        control.onChange = nil
        control.onRecordingChange = nil
    }
}

private final class KeyRecorderControl: NSControl {
    var shortcut = ShortcutGesture() {
        didSet {
            needsDisplay = true
            setAccessibilityValue(shortcut.displayName)
        }
    }
    var maximumSteps = 1 {
        didSet { if oldValue != maximumSteps { endRecording() } }
    }
    var onChange: ((ShortcutGesture) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?
    private(set) var isRecording = false
    private var captured: [KeyChord] = []
    private var windowObserver: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
        windowObserver = nil
        if window == nil { endRecording() }
        if let window {
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.endRecording() }
            }
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("단축키 입력")
        setAccessibilityHelp("클릭한 뒤 원하는 단축키를 누르세요.")
        setAccessibilityValue(shortcut.displayName)
    }

    deinit {
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
    }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }

    func beginRecording() {
        guard window?.makeFirstResponder(self) == true else { return }
        captured = []
        if !isRecording { onRecordingChange?(true) }
        isRecording = true
        needsDisplay = true
        setAccessibilityValue("지금 단축키를 누르세요")
    }

    func endRecording() {
        let wasRecording = isRecording
        isRecording = false
        captured = []
        needsDisplay = true
        setAccessibilityValue(shortcut.displayName)
        if wasRecording { onRecordingChange?(false) }
    }

    override func accessibilityPerformPress() -> Bool {
        beginRecording()
        return isRecording
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            if event.keyCode == 36 || event.keyCode == 49 { beginRecording() }
            else { super.keyDown(with: event) }
            return
        }
        guard !event.isARepeat else { return }
        if event.keyCode == 53 {
            endRecording()
            return
        }
        if (event.keyCode == 51 || event.keyCode == 117), ShortcutModifiers(eventFlags: event.modifierFlags).isEmpty {
            shortcut = ShortcutGesture()
            onChange?(shortcut)
            endRecording()
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
            endRecording()
        }
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        endRecording()
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
