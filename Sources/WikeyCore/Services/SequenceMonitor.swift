import ApplicationServices
import CoreGraphics
import Foundation

public final class SequenceMonitor {
    public typealias Completion = (KeyChord?) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timeoutWorkItem: DispatchWorkItem?
    private var keyState = SequenceKeyState(acceptable: [])
    private var completion: Completion?

    public init() {}

    public func cancel() {
        stop(result: nil)
    }

    deinit {
        stop(result: nil)
    }

    public func begin(acceptable: Set<KeyChord>, timeout: TimeInterval = 1.2, completion: @escaping Completion) throws {
        stop(result: nil)
        guard CGPreflightListenEventAccess() else {
            throw AutomationError.permissionRequired("입력 모니터링")
        }
        guard AXIsProcessTrusted() else {
            throw AutomationError.permissionRequired("손쉬운 사용 · 연속 단축키가 다른 앱에 입력되지 않도록 필요")
        }

        keyState = SequenceKeyState(acceptable: acceptable)
        self.completion = completion
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: sequenceEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            self.completion = nil
            throw AutomationError.permissionRequired("입력 모니터링")
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        let item = DispatchWorkItem { [weak self] in self?.stop(result: nil) }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: item)
    }

    fileprivate func receive(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == KeyboardService.syntheticEventUserData {
            return Unmanaged.passUnretained(event)
        }
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard eventType == .keyDown || eventType == .keyUp else { return Unmanaged.passUnretained(event) }
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let chord = KeyChord(keyCode: keyCode, modifiers: ShortcutModifiers(cgFlags: event.flags))
        switch keyState.receive(chord: chord, isKeyDown: eventType == .keyDown,
                                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case .matched:
            timeoutWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.stop(result: nil) }
            timeoutWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
            return nil
        case .finish(let result, let consume):
            stop(result: result)
            return consume ? nil : Unmanaged.passUnretained(event)
        }
    }

    private func stop(result: KeyChord?) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        if let eventTap { CFMachPortInvalidate(eventTap) }
        eventTap = nil
        keyState = SequenceKeyState(acceptable: [])
        let callback = completion
        completion = nil
        if let callback { callback(result) }
    }
}

/// Consume the second key through release, including repeat events. Otherwise a
/// held second key starts typing into the destination as soon as the tap closes.
struct SequenceKeyState {
    enum Decision: Equatable {
        case passThrough, consume, matched
        case finish(KeyChord?, consume: Bool)
    }

    var acceptable: Set<KeyChord>
    private var matchedChord: KeyChord?

    init(acceptable: Set<KeyChord>) { self.acceptable = acceptable }

    mutating func receive(chord: KeyChord, isKeyDown: Bool, isRepeat: Bool) -> Decision {
        if let matchedChord, chord.keyCode == matchedChord.keyCode {
            return isKeyDown ? .consume : .finish(matchedChord, consume: true)
        }
        guard isKeyDown else { return .passThrough }
        if chord.keyCode == 53 { return .finish(nil, consume: true) }
        if isRepeat { return .consume }
        guard matchedChord == nil, acceptable.contains(chord) else { return .finish(nil, consume: false) }
        matchedChord = chord
        return .matched
    }
}

private func sequenceEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<SequenceMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.receive(eventType: type, event: event)
}
