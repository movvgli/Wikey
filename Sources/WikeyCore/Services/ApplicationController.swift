import AppKit
import Foundation

@MainActor
public final class ApplicationController {
    public init() {}

    public func frontmostApplication() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    @discardableResult
    public func launch(bundleIdentifier: String, activates: Bool = true) async throws -> NSRunningApplication {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            if activates { running.activate() }
            return running
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AutomationError.applicationNotFound(bundleIdentifier)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        configuration.addsToRecentItems = false
        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                if let app {
                    continuation.resume(returning: app)
                } else {
                    continuation.resume(throwing: error ?? AutomationError.applicationDidNotLaunch(bundleIdentifier))
                }
            }
        }
    }

    public func openURL(_ value: String) async throws {
        guard let url = URL(string: value), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            throw AutomationError.invalidURL(value)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(url, configuration: configuration) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}

public enum AutomationError: LocalizedError {
    case applicationNotFound(String)
    case applicationDidNotLaunch(String)
    case invalidURL(String)
    case templateNotFound
    case layoutNotFound
    case permissionRequired(String)
    case clipboardWriteFailed
    case keyboardEventCreationFailed
    case workflowNotFound
    case workflowCycleDetected
    case displayNotFound(String)
    case windowNotFound(String)
    case windowIsFullScreen(String)
    case windowMoveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let id): "설치된 앱을 찾을 수 없습니다: \(id)"
        case .applicationDidNotLaunch(let id): "앱을 실행하지 못했습니다: \(id)"
        case .invalidURL(let url): "유효한 HTTP/HTTPS 주소가 아닙니다: \(url)"
        case .templateNotFound: "템플릿을 찾을 수 없습니다."
        case .layoutNotFound: "레이아웃을 찾을 수 없습니다."
        case .permissionRequired(let name): "\(name) 권한이 필요합니다."
        case .clipboardWriteFailed: "클립보드에 템플릿을 기록하지 못했습니다."
        case .keyboardEventCreationFailed: "키 입력을 만들지 못했습니다."
        case .workflowNotFound: "연결된 워크플로를 찾을 수 없습니다."
        case .workflowCycleDetected: "워크플로가 서로 반복 실행되도록 연결되어 중단했습니다."
        case .displayNotFound(let name): "연결된 모니터를 찾을 수 없습니다: \(name)"
        case .windowNotFound(let app): "10초 안에 ‘\(app)’ 창을 찾지 못했습니다."
        case .windowIsFullScreen(let app): "‘\(app)’의 전체 화면 창은 이동하지 않았습니다."
        case .windowMoveFailed(let app): "‘\(app)’ 창의 크기나 위치를 변경할 수 없습니다."
        }
    }
}
