import CryptoKit
import Foundation

public enum SyncError: LocalizedError {
    case invalidArchive, oversized, missingFile, notCloudFolder, busy, editing
    public var errorDescription: String? {
        switch self {
        case .invalidArchive: "백업이 손상되었거나 지원하지 않는 형식입니다. 기존 설정은 유지됩니다."
        case .oversized: "백업은 총 50MB, 첨부 파일은 각각 20MB까지 지원합니다."
        case .missingFile: "첨부 파일을 읽을 수 없습니다. 파일의 위치와 다운로드 상태를 확인해 주세요. 폴더 첨부는 지원하지 않습니다."
        case .notCloudFolder: "iCloud Drive 안의 개인 폴더를 선택해 주세요. Finder에서 폴더 다운로드가 완료됐는지도 확인해 주세요."
        case .busy: "워크플로우 실행이 끝난 후 다시 시도해 주세요."
        case .editing: "열려 있는 워크플로·템플릿·레이아웃 편집 화면에서 뒤로 이동한 후 다시 적용해 주세요."
        }
    }
}

public struct SyncAsset: Codable, Sendable {
    public var name: String
    public var data: Data
}

/// No local paths, bookmarks, permissions, or account credentials leave the Mac.
public struct SyncPayload: Codable, Sendable {
    public var state: PersistedState
    public var templateDocuments: [String: Data]
    public var assets: [String: SyncAsset]
    public static let maximumBytes = 50 * 1_024 * 1_024

    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public var fingerprint: String { get throws { Self.digest(try Self.encoder().encode(self)) } }

    public static func capture(state: PersistedState, root: URL) throws -> Self {
        var result = Self(state: state, templateDocuments: [:], assets: [:])
        var total = 0
        func read(_ url: URL) throws -> Data {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw SyncError.missingFile }
            guard (values.fileSize ?? Int.max) <= 20 * 1_024 * 1_024 else { throw SyncError.oversized }
            let data = try Data(contentsOf: url)
            total += data.count
            guard total <= maximumBytes else { throw SyncError.oversized }
            return data
        }
        for index in result.state.templates.indices {
            let template = result.state.templates[index]
            guard safeName(template.fileName) else { throw SyncError.invalidArchive }
            result.templateDocuments[template.id.uuidString] = try read(root.appendingPathComponent("Templates").appendingPathComponent(template.fileName))
            result.state.templates[index].fileName = "\(template.id.uuidString).rtfd"
        }
        func archive(_ paths: [String]) throws -> [String] {
            try paths.map { path in
                let url = URL(fileURLWithPath: path)
                let data = try read(url)
                let name = url.lastPathComponent
                guard safeName(name) else { throw SyncError.invalidArchive }
                let key = digest(Data(name.utf8) + data)
                result.assets[key] = SyncAsset(name: name, data: data)
                return key
            }
        }
        for index in result.state.workflows.indices {
            result.state.workflows[index].actions = try state.workflows[index].actions.map { action in
                switch action {
                case .pasteFiles(let paths): return .pasteFiles(filePaths: try archive(paths))
                case .pasteImages(let paths): return .pasteImages(filePaths: try archive(paths))
                default: return action
                }
            }
        }
        try result.validate()
        return result
    }

    public func validate() throws {
        guard state.schemaVersion == 1, assets.count <= 1_000,
              Set(state.workflows.map(\.id)).count == state.workflows.count,
              Set(state.templates.map(\.id)).count == state.templates.count,
              Set(state.layouts.map(\.id)).count == state.layouts.count,
              Set(state.applicationShortcuts.map(\.id)).count == state.applicationShortcuts.count
        else { throw SyncError.invalidArchive }
        var total = 0
        for (key, asset) in assets {
            guard Self.safeName(asset.name), key == Self.digest(Data(asset.name.utf8) + asset.data) else { throw SyncError.invalidArchive }
            guard asset.data.count <= 20 * 1_024 * 1_024 else { throw SyncError.oversized }
            total += asset.data.count
        }
        for template in state.templates {
            guard let data = templateDocuments[template.id.uuidString],
                  template.fileName == "\(template.id.uuidString).rtfd" else { throw SyncError.invalidArchive }
            total += data.count
        }
        guard total <= Self.maximumBytes else { throw SyncError.oversized }
        for workflow in state.workflows {
            for action in workflow.actions {
                switch action {
                case .pasteFiles(let keys), .pasteImages(let keys):
                    guard keys.allSatisfy({ assets[$0] != nil }) else { throw SyncError.invalidArchive }
                default: break
                }
            }
        }
    }

    private static func safeName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && !name.contains("\0") && name.utf8.count <= 240
    }
}

public struct SyncBackup: Codable, Identifiable, Sendable {
    public var schemaVersion = 1
    public var id: UUID
    public var parents: [UUID]
    public var device: String
    public var createdAt: Date
    public var payload: SyncPayload

    public init(payload: SyncPayload, parents: [UUID] = [], device: String) {
        id = UUID(); self.parents = parents; self.device = device
        createdAt = Date(); self.payload = payload
    }

    public func encoded() throws -> Data {
        try payload.validate()
        let data = try SyncPayload.encoder().encode(self)
        guard data.count <= SyncPayload.maximumBytes * 2 else { throw SyncError.oversized }
        return data
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= SyncPayload.maximumBytes * 2 else { throw SyncError.oversized }
        let backup = try JSONDecoder().decode(Self.self, from: data)
        guard backup.schemaVersion == 1, !backup.parents.contains(backup.id) else { throw SyncError.invalidArchive }
        try backup.payload.validate()
        return backup
    }

    /// Parent links, not wall-clock timestamps, decide whether edits are concurrent.
    public static func heads(in versions: [SyncBackup]) -> [SyncBackup] {
        let parents = Set(versions.flatMap(\.parents))
        return versions.filter { !parents.contains($0.id) }
    }

    public static func validateGraph(_ versions: [SyncBackup]) throws {
        let ids = Set(versions.map(\.id))
        guard ids.count == versions.count else { throw SyncError.invalidArchive }
        var remaining = versions
        var visited: Set<UUID> = []
        while !remaining.isEmpty {
            let roots = remaining.filter { Set($0.parents).isSubset(of: visited) }
            guard !roots.isEmpty else { throw SyncError.invalidArchive }
            visited.formUnion(roots.map(\.id))
            remaining.removeAll { visited.contains($0.id) }
        }
    }
}
