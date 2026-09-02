import Foundation

public struct Workflow: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var shortcut: ShortcutGesture
    public var actions: [WorkflowAction]

    public init(
        id: UUID = UUID(),
        name: String = "새 워크플로",
        isEnabled: Bool = true,
        shortcut: ShortcutGesture = .init(),
        actions: [WorkflowAction] = []
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.actions = actions
    }
}

public enum TemplateDeliveryMode: String, Codable, CaseIterable, Sendable {
    case copyOnly
    case copyAndPaste

    public var title: String {
        switch self {
        case .copyOnly: "클립보드에 복사"
        case .copyAndPaste: "복사 후 자동 붙여넣기"
        }
    }
}

public enum WorkflowAction: Identifiable, Codable, Hashable, Sendable {
    case launchApplication(bundleIdentifier: String, displayName: String)
    case copyTemplate(templateID: UUID, mode: TemplateDeliveryMode)
    case openURL(String)
    case applyLayout(layoutID: UUID)

    public var id: String {
        switch self {
        case .launchApplication(let bundleID, _): "app:\(bundleID)"
        case .copyTemplate(let id, _): "template:\(id)"
        case .openURL(let url): "url:\(url)"
        case .applyLayout(let id): "layout:\(id)"
        }
    }

    public var title: String {
        switch self {
        case .launchApplication(_, let name): "앱 실행 · \(name)"
        case .copyTemplate: "템플릿 복사"
        case .openURL: "웹사이트 열기"
        case .applyLayout: "창 레이아웃 적용"
        }
    }
}

public struct RichTemplate: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var fileName: String
    public var plainText: String

    public init(id: UUID = UUID(), name: String = "새 템플릿", plainText: String = "") {
        self.id = id
        self.name = name
        self.fileName = "\(id.uuidString).rtfd"
        self.plainText = plainText
    }
}

public enum LayoutZone: String, Codable, CaseIterable, Identifiable, Sendable {
    case full
    case leftHalf, rightHalf
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case leftOneThird, rightOneThird
    case topLeft, topRight, bottomLeft, bottomRight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .full: "전체"
        case .leftHalf: "왼쪽 1/2"
        case .rightHalf: "오른쪽 1/2"
        case .leftThird: "왼쪽 1/3"
        case .centerThird: "가운데 1/3"
        case .rightThird: "오른쪽 1/3"
        case .leftTwoThirds: "왼쪽 2/3"
        case .rightTwoThirds: "오른쪽 2/3"
        case .leftOneThird: "왼쪽 1/3"
        case .rightOneThird: "오른쪽 1/3"
        case .topLeft: "왼쪽 위 1/4"
        case .topRight: "오른쪽 위 1/4"
        case .bottomLeft: "왼쪽 아래 1/4"
        case .bottomRight: "오른쪽 아래 1/4"
        }
    }

    public var normalizedRect: CGRect {
        switch self {
        case .full: CGRect(x: 0, y: 0, width: 1, height: 1)
        case .leftHalf: CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .leftThird, .leftOneThird: CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1)
        case .centerThird: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .rightThird, .rightOneThird: CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .leftTwoThirds: CGRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1)
        case .rightTwoThirds: CGRect(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1)
        case .topLeft: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .topRight: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .bottomLeft: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .bottomRight: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        }
    }

    public func frame(in visibleFrame: CGRect) -> CGRect {
        let rect = normalizedRect
        return CGRect(
            x: visibleFrame.minX + visibleFrame.width * rect.minX,
            y: visibleFrame.minY + visibleFrame.height * rect.minY,
            width: visibleFrame.width * rect.width,
            height: visibleFrame.height * rect.height
        ).integral
    }
}

public struct DisplayTarget: Codable, Hashable, Sendable {
    public var uuid: String
    public var name: String

    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
}

public struct AppWindowPlacement: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var bundleIdentifier: String
    public var appName: String
    public var display: DisplayTarget
    public var zone: LayoutZone

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        display: DisplayTarget,
        zone: LayoutZone = .full
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.display = display
        self.zone = zone
    }
}

public struct WindowLayout: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var placements: [AppWindowPlacement]

    public init(id: UUID = UUID(), name: String = "새 레이아웃", placements: [AppWindowPlacement] = []) {
        self.id = id
        self.name = name
        self.placements = placements
    }
}

public struct PersistedState: Codable, Sendable {
    public var schemaVersion: Int
    public var workflows: [Workflow]
    public var templates: [RichTemplate]
    public var layouts: [WindowLayout]

    public init(
        schemaVersion: Int = 1,
        workflows: [Workflow] = [],
        templates: [RichTemplate] = [],
        layouts: [WindowLayout] = []
    ) {
        self.schemaVersion = schemaVersion
        self.workflows = workflows
        self.templates = templates
        self.layouts = layouts
    }
}

public struct ActionFailure: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var actionTitle: String
    public var message: String
}

public struct RunSummary: Hashable, Sendable {
    public var workflowName: String
    public var startedAt: Date
    public var finishedAt: Date
    public var failures: [ActionFailure]

    public var menuTitle: String {
        failures.isEmpty ? "최근 실행 성공 · \(workflowName)" : "최근 실행 실패 \(failures.count)건 · \(workflowName)"
    }
}
