import Carbon.HIToolbox
import Foundation
import Observation

@Observable
public final class HotkeyRegistrar {
    public private(set) var registrationErrors: [UUID: String] = [:]
    public var onWorkflow: ((UUID) -> Void)?

    private let sequenceMonitor: SequenceMonitor
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var routes: [UInt32: Route] = [:]
    private var nextID: UInt32 = 1

    private enum Route {
        case single(UUID)
        case sequence([KeyChord: UUID])
    }

    public init(sequenceMonitor: SequenceMonitor = SequenceMonitor()) {
        self.sequenceMonitor = sequenceMonitor
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    deinit {
        unregisterAll()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    public func configure(workflows: [Workflow]) {
        unregisterAll()
        registrationErrors = ShortcutConflictDetector.conflicts(in: workflows)

        let eligible = workflows.filter {
            $0.isEnabled && $0.shortcut.validationMessage == nil && registrationErrors[$0.id] == nil
        }
        let grouped = Dictionary(grouping: eligible) { $0.shortcut.steps[0] }

        for (firstChord, group) in grouped {
            let route: Route
            if let single = group.first(where: { $0.shortcut.steps.count == 1 }) {
                route = .single(single.id)
            } else {
                var endings: [KeyChord: UUID] = [:]
                for workflow in group where workflow.shortcut.steps.count == 2 {
                    endings[workflow.shortcut.steps[1]] = workflow.id
                }
                route = .sequence(endings)
            }
            register(firstChord, route: route, affected: group.map(\.id))
        }
    }

    fileprivate func receive(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, let route = routes[hotKeyID.id] else { return status }

        switch route {
        case .single(let workflowID):
            onWorkflow?(workflowID)
        case .sequence(let endings):
            do {
                try sequenceMonitor.begin(acceptable: Set(endings.keys)) { [weak self] chord in
                    guard let chord, let workflowID = endings[chord] else { return }
                    self?.onWorkflow?(workflowID)
                }
            } catch {
                for workflowID in endings.values {
                    registrationErrors[workflowID] = error.localizedDescription
                }
            }
        }
        return noErr
    }

    private func register(_ chord: KeyChord, route: Route, affected workflowIDs: [UUID]) {
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("WKEY"), id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            chord.keyCode,
            chord.modifiers.carbonValue,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
            routes[id] = route
        } else {
            for workflowID in workflowIDs {
                registrationErrors[workflowID] = "다른 앱 또는 macOS가 이 단축키를 사용 중입니다. (\(status))"
            }
        }
    }

    private func unregisterAll() {
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        routes.removeAll()
        nextID = 1
    }
}

private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let registrar = Unmanaged<HotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    return registrar.receive(event)
}

private func fourCharacterCode(_ value: String) -> OSType {
    value.utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
}
