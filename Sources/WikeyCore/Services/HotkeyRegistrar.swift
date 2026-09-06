import Carbon.HIToolbox
import Foundation
import Observation
import OSLog

private let shortcutLogger = Logger(subsystem: "com.wikey.app", category: "shortcuts")

@Observable
public final class HotkeyRegistrar {
    public private(set) var registrationErrors: [UUID: String] = [:]
    public private(set) var applicationRegistrationErrors: [UUID: String] = [:]
    public private(set) var layoutRegistrationErrors: [UUID: String] = [:]
    public var onWorkflow: ((UUID) -> Void)?
    public var onApplication: ((UUID) -> Void)?
    public var onLayout: ((UUID) -> Void)?

    private let sequenceMonitor: SequenceMonitor
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var routes: [UInt32: Route] = [:]
    private var nextID: UInt32 = 1
    private var pressedIDs = Set<UInt32>()
    private var recordingTokens = Set<UUID>()
    private var configuredWorkflows: [Workflow] = []
    private var configuredApplications: [ApplicationShortcut] = []
    private var configuredLayouts: [WindowLayout] = []
    private var installationStatus: OSStatus = noErr

    private enum Route {
        case single(Target)
        case sequence([KeyChord: Target])
    }

    private enum Target: Hashable {
        case workflow(UUID)
        case application(UUID)
        case layout(UUID)
    }

    private struct Candidate {
        var target: Target
        var name: String
        var shortcut: ShortcutGesture
    }

    public init(sequenceMonitor: SequenceMonitor = SequenceMonitor()) {
        self.sequenceMonitor = sequenceMonitor
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        installationStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            2,
            &eventTypes,
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
        applicationShortcuts: [ApplicationShortcut] = [],
        layouts: [WindowLayout] = []
    ) {
        configuredWorkflows = workflows
        configuredApplications = applicationShortcuts
        configuredLayouts = layouts
        unregisterAll()
        let conflicts = ShortcutConflictDetector.conflicts(
            workflows: workflows,
            applicationShortcuts: applicationShortcuts,
            layouts: layouts
        )
        registrationErrors = conflicts.workflows
        applicationRegistrationErrors = conflicts.applications
        layoutRegistrationErrors = conflicts.layouts
        guard recordingTokens.isEmpty else { return }

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

        let layoutCandidates = layouts.compactMap { layout -> Candidate? in
            guard layout.shortcut.validationMessage == nil,
                  layoutRegistrationErrors[layout.id] == nil else { return nil }
            return Candidate(target: .layout(layout.id), name: layout.name, shortcut: layout.shortcut)
        }

        let grouped = Dictionary(grouping: workflowCandidates + applicationCandidates + layoutCandidates) {
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
        shortcutLogger.info("Global shortcuts ready: \(self.routes.count, privacy: .public) registered prefixes")
    }

    /// Temporarily release global shortcuts so recording cannot launch another action.
    public func beginRecording(token: UUID) {
        recordingTokens.insert(token)
        unregisterAll()
    }

    public func endRecording(token: UUID) {
        guard recordingTokens.remove(token) != nil, recordingTokens.isEmpty else { return }
        configure(workflows: configuredWorkflows, applicationShortcuts: configuredApplications, layouts: configuredLayouts)
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
        guard status == noErr else { return status }
        guard hotKeyID.signature == fourCharacterCode("WKEY"),
              let route = routes[hotKeyID.id], recordingTokens.isEmpty else {
            return OSStatus(eventNotHandledErr)
        }
        if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
            pressedIDs.remove(hotKeyID.id)
            return noErr
        }
        guard pressedIDs.insert(hotKeyID.id).inserted else { return noErr }
        shortcutLogger.info("Global shortcut received: \(hotKeyID.id, privacy: .public)")

        switch route {
        case .single(let target):
            trigger(target)
        case .sequence(let endings):
            do {
                try sequenceMonitor.begin(acceptable: Set(endings.keys)) { [weak self] chord in
                    guard let chord, let target = endings[chord] else { return }
                    self?.trigger(target)
                }
                for target in endings.values { setRegistrationError(nil, for: target) }
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
        nextID &+= 1
        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("WKEY"), id: id)
        var ref: EventHotKeyRef?
        let status = installationStatus == noErr ? RegisterEventHotKey(
            chord.keyCode,
            chord.modifiers.carbonValue,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &ref
        ) : installationStatus
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
            routes[id] = route
        } else {
            shortcutLogger.error("Global shortcut registration failed: \(status, privacy: .public)")
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
        case .layout(let id): onLayout?(id)
        }
    }

    private func setRegistrationError(_ message: String?, for target: Target) {
        switch target {
        case .workflow(let id): registrationErrors[id] = message
        case .application(let id): applicationRegistrationErrors[id] = message
        case .layout(let id): layoutRegistrationErrors[id] = message
        }
    }

    private func unregisterAll() {
        sequenceMonitor.cancel()
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        routes.removeAll()
        pressedIDs.removeAll()
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
