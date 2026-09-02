import CoreGraphics
import Foundation

public final class SequenceMonitor {
    public typealias Completion = (KeyChord?) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timeoutWorkItem: DispatchWorkItem?
    private var acceptable: Set<KeyChord> = []
    private var completion: Completion?

    public init() {}

    deinit {
        stop(result: nil)
    }

    public func begin(acceptable: Set<KeyChord>, timeout: TimeInterval = 1.2, completion: @escaping Completion) throws {
        stop(result: nil)
        guard CGPreflightListenEventAccess() else {
            throw AutomationError.permissionRequired("입력 모니터링")
        }

        self.acceptable = acceptable
        self.completion = completion
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
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
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard eventType == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode == 53 {
            stop(result: nil)
            return nil
        }
        let chord = KeyChord(keyCode: keyCode, modifiers: ShortcutModifiers(cgFlags: event.flags))
        if acceptable.contains(chord) {
            stop(result: chord)
            return nil
        }
        stop(result: nil)
        return Unmanaged.passUnretained(event)
    }

    private func stop(result: KeyChord?) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        acceptable = []
        let callback = completion
        completion = nil
        if let callback { callback(result) }
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
