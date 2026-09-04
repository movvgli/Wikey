import Carbon.HIToolbox
import Foundation
import Observation

@Observable
public final class HotkeyRegistrar {
    public private(set) var registrationErrors: [UUID: String] = [:]
    public private(set) var applicationRegistrationErrors: [UUID: String] = [:]
    public var onWorkflow: ((UUID) -> Void)?
    public var onApplication: ((UUID) -> Void)?

    private let sequenceMonitor: SequenceMonitor
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var routes: [UInt32: Route] = [:]
    private var nextID: UInt32 = 1

    private enum Route {
        case single(Target)
        case sequence([KeyChord: Target])
    }

    private enum Target: Hashable {
        case workflow(UUID)
        case application(UUID)
    }

    private struct Candidate {
        var target: Target
        var name: String
        var shortcut: ShortcutGesture
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

    public func configure(
        workflows: [Workflow],
        applicationShortcuts: [ApplicationShortcut] = []
    ) {
        unregisterAll()
        let conflicts = ShortcutConflictDetector.conflicts(
            workflows: workflows,
            applicationShortcuts: applicationShortcuts
        )
        registrationErrors = conflicts.workflows
        applicationRegistrationErrors = conflicts.applications

        let workflowCandidates = workflows.compactMap { workflow -> Candidate? in
            guard workflow.isEnabled,
                  workflow.shortcut.validationMessage == nil,
                  registrationErrors[workflow.id] == nil else { return nil }
            return Candidate(
                target: .workflow(workflow.id),
                name: workflow.name,
                shortcut: workflow.shortcut
            )
        }

        let applicationCandidates = applicationShortcuts.compactMap { application -> Candidate? in
            guard application.shortcut.validationMessage == nil,
                  applicationRegistrationErrors[application.id] == nil else { return nil }
            return Candidate(
                target: .application(application.id),
                name: application.displayName,
                shortcut: application.shortcut
            )
        }

        let grouped = Dictionary(grouping: workflowCandidates + applicationCandidates) {
            $0.shortcut.steps[0]
        }

        for (firstChord, group) in grouped {
            let route: Route
            if let single = group.first(where: { $0.shortcut.steps.count == 1 }) {
                route = .single(single.target)
            } else {
                var endings: [KeyChord: Target] = [:]
                for candidate in group where candidate.shortcut.steps.count == 2 {
                    endings[candidate.shortcut.steps[1]] = candidate.target
                }
                route = .sequence(endings)
            }
            register(firstChord, route: route, affected: group.map(\.target))
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
        case .single(let target):
            trigger(target)
        case .sequence(let endings):
            do {
                try sequenceMonitor.begin(acceptable: Set(endings.keys)) { [weak self] chord in
                    guard let chord, let target = endings[chord] else { return }
                    self?.trigger(target)
                }
            } catch {
                for target in endings.values {
                    setRegistrationError(error.localizedDescription, for: target)
                }
            }
        }
        return noErr
    }

    private func register(_ chord: KeyChord, route: Route, affected targets: [Target]) {
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
            for target in targets {
                setRegistrationError(
                    "다른 앱 또는 macOS가 이 단축키를 사용 중입니다. (\(status))",
                    for: target
                )
            }
        }
    }

    private func trigger(_ target: Target) {
        switch target {
        case .workflow(let id): onWorkflow?(id)
        case .application(let id): onApplication?(id)
        }
    }

    private func setRegistrationError(_ message: String, for target: Target) {
        switch target {
        case .workflow(let id): registrationErrors[id] = message
        case .application(let id): applicationRegistrationErrors[id] = message
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
