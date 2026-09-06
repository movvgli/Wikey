import AppKit
import Foundation

@MainActor
public final class ApplicationController {
    private var lastExternalApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    public init() {
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in self?.rememberExternalApplication(application) }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    public func frontmostApplication() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    /// Clicking Run inside Wikey should still type into the last external app.
    public func inputTargetApplication() -> NSRunningApplication? {
        rememberExternalApplication(frontmostApplication())
        guard let application = lastExternalApplication, !application.isTerminated else { return nil }
        return application
    }

    private func rememberExternalApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              application.activationPolicy == .regular,
              !application.isTerminated else { return }
        lastExternalApplication = application
    }

    @discardableResult
    public func launch(bundleIdentifier: String, activates: Bool = true) async throws -> NSRunningApplication {
        try Task.checkCancellation()
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AutomationError.applicationNotFound(bundleIdentifier)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        configuration.addsToRecentItems = false
        // Reopen through Launch Services even when already running. Merely activating
        // an app with its last window closed does not ask it to show a window again.
        let application: NSRunningApplication = try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                if let app {
                    continuation.resume(returning: app)
                } else {
                    continuation.resume(throwing: error ?? AutomationError.applicationDidNotLaunch(bundleIdentifier))
                }
            }
        }
        try Task.checkCancellation()
        if activates { try await Self.activateAndWait(application) }
        return application
    }

    @discardableResult
    public func openURL(_ value: String) async throws -> NSRunningApplication {
        try Task.checkCancellation()
        guard let url = URL(string: value), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            throw AutomationError.invalidURL(value)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let application: NSRunningApplication = try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.open(url, configuration: configuration) { app, error in
                if let error { continuation.resume(throwing: error) }
                else if let app { continuation.resume(returning: app) }
                else { continuation.resume(throwing: AutomationError.applicationDidNotLaunch("웹 브라우저")) }
            }
        }
        try Task.checkCancellation()
        try await Self.activateAndWait(application)
        return application
    }

    static func activateAndWait(_ application: NSRunningApplication) async throws {
        try Task.checkCancellation()
        let name = application.localizedName ?? application.bundleIdentifier ?? "앱"
        guard !application.isTerminated else {
            throw AutomationError.applicationDidNotLaunch(name)
        }
        if !application.isActive { application.activate() }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            try Task.checkCancellation()
            guard !application.isTerminated else {
                throw AutomationError.applicationDidNotLaunch(name)
            }
            if application.isFinishedLaunching,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                // Activation notifications precede a newly visible window receiving focus.
                try await Task.sleep(for: .milliseconds(150))
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                    return
                }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw AutomationError.applicationDidNotActivate(name)
    }
}

public enum AutomationError: LocalizedError {
    case applicationNotFound(String)
    case applicationDidNotLaunch(String)
    case applicationDidNotActivate(String)
    case inputTargetNotFound
    case shortcutKeysStillPressed
    case invalidURL(String)
    case templateNotFound
    case layoutNotFound
    case permissionRequired(String)
    case clipboardWriteFailed
    case imageNotFound(String)
    case fileNotFound(String)
    case keyboardEventCreationFailed
    case workflowNotFound
    case workflowIsEmpty
    case invalidWaitDuration
    case workflowCycleDetected
    case displayNotFound(String)
    case windowNotFound(String)
    case windowIsFullScreen(String)
    case windowMoveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let id): "설치된 앱을 찾을 수 없습니다: \(id)"
        case .applicationDidNotLaunch(let id): "앱을 실행하지 못했습니다: \(id)"
        case .applicationDidNotActivate(let name): "‘\(name)’ 앱으로 전환하지 못했습니다. 앱을 연 뒤 다시 실행해 주세요."
        case .inputTargetNotFound: "입력할 앱을 찾지 못했습니다. 대상 앱을 열거나 워크플로 첫 단계에 앱 실행을 추가해 주세요."
        case .shortcutKeysStillPressed: "단축키에서 손을 뗀 뒤 다시 실행해 주세요."
        case .invalidURL(let url): "유효한 HTTP/HTTPS 주소가 아닙니다: \(url)"
        case .templateNotFound: "템플릿을 찾을 수 없습니다."
        case .layoutNotFound: "레이아웃을 찾을 수 없습니다."
        case .permissionRequired(let name): "\(name) 권한이 필요합니다."
        case .clipboardWriteFailed: "클립보드에 내용을 기록하지 못했습니다."
        case .imageNotFound(let name): "이미지를 찾거나 열 수 없습니다: \(name)"
        case .fileNotFound(let name): "파일을 찾을 수 없습니다: \(name)"
        case .keyboardEventCreationFailed: "키 입력을 만들지 못했습니다."
        case .workflowNotFound: "연결된 워크플로를 찾을 수 없습니다."
        case .workflowIsEmpty: "워크플로에 실행할 동작을 먼저 추가해 주세요."
        case .invalidWaitDuration: "대기 시간은 0초보다 길고 30초 이하여야 합니다."
        case .workflowCycleDetected: "워크플로가 서로 반복 실행되도록 연결되어 중단했습니다."
        case .displayNotFound(let name): "연결된 모니터를 찾을 수 없습니다: \(name)"
        case .windowNotFound(let app): "10초 안에 ‘\(app)’ 창을 찾지 못했습니다."
        case .windowIsFullScreen(let app): "‘\(app)’의 전체 화면 창은 이동하지 않았습니다."
        case .windowMoveFailed(let app): "‘\(app)’ 창의 크기나 위치를 변경할 수 없습니다."
        }
    }
}
