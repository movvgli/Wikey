import AppKit
import Foundation
import Observation

@MainActor @Observable
public final class ICloudSyncService {
    public private(set) var isEnabled = false
    public private(set) var isBusy = false
    public private(set) var status = "꺼짐 · 설정은 이 Mac에만 저장됩니다."
    public private(set) var errorMessage: String?
    public private(set) var versions: [SyncBackup] = []
    public private(set) var conflicts: [SyncBackup] = []
    public private(set) var pendingVersion: SyncBackup?
    public private(set) var lastChecked: Date?
    public private(set) var folderName = ""
    public var resolutionParents: [UUID] { observedHeads }
    @ObservationIgnored public var canApply: () -> Bool = { true }
    @ObservationIgnored public var onApply: (() -> Void)?
    @ObservationIgnored private let store: WikeyStore
    @ObservationIgnored private let io = SyncFolderIO()
    @ObservationIgnored private var folder: URL?
    @ObservationIgnored private var scopedAccess = false
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var observedHeads: [UUID] = []
    @ObservationIgnored private var editingSessions: Set<UUID> = []
    @ObservationIgnored private var stagedBackup: (fingerprint: String, backup: SyncBackup)?
    @ObservationIgnored private var metadata = Metadata()
    private var metadataURL: URL { store.storageURL.appendingPathComponent("sync-device.json") }
    private var backupsURL: URL { store.storageURL.appendingPathComponent("Backups", isDirectory: true) }

    private struct Metadata: Codable {
        var bookmark: Data?
        var enabled = false
        var parents: [UUID] = []
        var fingerprint: String?
        // Deliberately avoid the user's computer name or account name.
        var device = "Mac-" + UUID().uuidString.prefix(6)
    }

    public init(store: WikeyStore) {
        self.store = store
        store.onSave = { [weak self] in self?.generation += 1 }
    }

    public func setEditing(_ editing: Bool, session: UUID) {
        if editing { editingSessions.insert(session) } else { editingSessions.remove(session) }
    }

    public func stop() {
        timer?.cancel(); timer = nil
    }

    public func createBackup() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let capturedGeneration = generation
            let original = try SyncPayload.encoder().encode(store.state)
            let payload = try await io.capture(store.state, root: store.storageURL)
            guard capturedGeneration == generation,
                  try SyncPayload.encoder().encode(store.state) == original else { throw SyncError.busy }
            try await io.write(SyncBackup(payload: payload, device: metadata.device), folder: backupsURL)
            await refreshBackups()
            errorMessage = nil
            status = "이 Mac에 복원용 백업을 저장했습니다."
        } catch { errorMessage = error.localizedDescription }
    }

    public func start() {
        guard timer == nil else { return }
        do {
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                metadata = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: metadataURL))
            }
            if metadata.enabled, let bookmark = metadata.bookmark {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale)
                guard !stale else { throw SyncError.notCloudFolder }
                scopedAccess = url.startAccessingSecurityScopedResource()
                folder = url; folderName = url.lastPathComponent; isEnabled = true
            }
        } catch { errorMessage = "동기화 폴더를 다시 연결해 주세요. \(error.localizedDescription)" }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.synchronize()
                try? await Task.sleep(for: .seconds(15))
            }
        }
        Task { await refreshBackups() }
    }

    /// Call only after an explicit opt-in and a native folder-picker grant.
    public func connect(to selected: URL) async {
        await connect(to: selected, requireICloud: true)
    }

    // Test seam: production always requires a user-selected ubiquitous directory.
    func connect(to selected: URL, requireICloud: Bool) async {
        guard !isBusy else { return }
        let accessed = selected.startAccessingSecurityScopedResource()
        do {
            let values = try selected.resourceValues(forKeys: [.isUbiquitousItemKey, .isDirectoryKey])
            guard (!requireICloud || values.isUbiquitousItem == true), values.isDirectory == true else { throw SyncError.notCloudFolder }
            let bookmark = try selected.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            var next = Metadata()
            next.bookmark = bookmark; next.enabled = true; next.device = metadata.device
            try saveMetadata(next)
            if scopedAccess { folder?.stopAccessingSecurityScopedResource() }
            metadata = next; folder = selected; scopedAccess = accessed
            folderName = selected.lastPathComponent; isEnabled = true
            conflicts = []; pendingVersion = nil; observedHeads = []; stagedBackup = nil; errorMessage = nil
            await synchronize()
        } catch {
            if accessed { selected.stopAccessingSecurityScopedResource() }
            errorMessage = error.localizedDescription
        }
    }

    public func disconnect() {
        guard !isBusy else { return }
        do {
            var next = metadata; next.enabled = false; next.bookmark = nil
            try saveMetadata(next)
            metadata = next; isEnabled = false
            if scopedAccess { folder?.stopAccessingSecurityScopedResource() }
            folder = nil; scopedAccess = false; conflicts = []; pendingVersion = nil
            status = "꺼짐 · 기존 설정과 백업은 삭제하지 않았습니다."
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    public func synchronize() async {
        guard isEnabled, let folder, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard store.lastPersistenceError == nil else { throw SyncError.invalidArchive }
            let capturedGeneration = generation
            let capturedState = try SyncPayload.encoder().encode(store.state)
            let local = try await io.capture(store.state, root: store.storageURL)
            let fingerprint = try await io.fingerprint(local)
            guard generation == capturedGeneration,
                  try SyncPayload.encoder().encode(store.state) == capturedState else { return }
            if fingerprint != metadata.fingerprint {
                if stagedBackup?.fingerprint != fingerprint {
                    let backup = SyncBackup(payload: local, parents: metadata.parents, device: metadata.device)
                    try await io.write(backup, folder: backupsURL)
                    stagedBackup = (fingerprint, backup)
                }
            }
            var remote = try await io.read(folder)
            if fingerprint != metadata.fingerprint, let backup = stagedBackup?.backup {
                try await io.write(backup, folder: folder)
                if !remote.contains(where: { $0.id == backup.id }) { remote.append(backup) }
                var next = metadata
                next.parents = [backup.id]; next.fingerprint = fingerprint
                try saveMetadata(next); metadata = next
                stagedBackup = nil
            }
            // An absent ancestor may still be downloading; never resolve incomplete history.
            let ids = Set(remote.map(\.id))
            guard remote.flatMap(\.parents).allSatisfy({ ids.contains($0) }) else {
                status = "이전 버전의 다운로드를 기다리는 중입니다."; return
            }
            let heads = SyncBackup.heads(in: remote)
            try SyncBackup.validateGraph(remote)
            for head in heads { try await io.write(head, folder: backupsURL) }
            observedHeads = heads.map(\.id)
            conflicts = heads.count > 1 ? heads : []
            pendingVersion = nil
            if heads.count > 1 {
                status = "서로 다른 설정이 있습니다. 사용할 버전을 선택해 주세요."
            } else if let head = heads.first, try await io.fingerprint(head.payload) != metadata.fingerprint {
                pendingVersion = head
                if !NSApplication.shared.isActive && editingSessions.isEmpty && canApply() && generation == capturedGeneration,
                   try SyncPayload.encoder().encode(store.state) == capturedState {
                    try await apply(head, parents: [head.id], publish: false, automatic: true)
                } else {
                    status = "다른 Mac의 설정이 도착했습니다. 편집·실행이 끝나면 적용합니다."
                }
            } else {
                if let head = heads.first {
                    var next = metadata; next.parents = [head.id]
                    try saveMetadata(next); metadata = next
                }
                status = "폴더 확인 완료 · 인터넷 전송은 iCloud Drive가 처리합니다."
            }
            lastChecked = Date(); errorMessage = nil
            await refreshBackups()
        } catch {
            errorMessage = error.localizedDescription
            status = "동기화 대기 · 이 Mac의 설정은 유지됩니다."
            await refreshBackups()
        }
    }

    public func restore(_ backup: SyncBackup, resolving parents: [UUID]? = nil) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard canApply() else { throw SyncError.busy }
            // Resolve only versions actually shown to the user. Unseen arrivals remain concurrent.
            try await apply(backup, parents: parents ?? observedHeads, publish: isEnabled)
            conflicts = []; pendingVersion = nil; errorMessage = nil
            await refreshBackups()
        } catch { errorMessage = error.localizedDescription }
    }

    private func apply(_ backup: SyncBackup, parents: [UUID], publish: Bool, automatic: Bool = false) async throws {
        guard canApply() else { throw SyncError.busy }
        guard editingSessions.isEmpty else { throw SyncError.editing }
        let original = try SyncPayload.encoder().encode(store.state)
        let capturedGeneration = generation
        let current = try await io.capture(store.state, root: store.storageURL)
        let fingerprint = try await io.fingerprint(backup.payload)
        try await io.write(SyncBackup(payload: current, device: metadata.device), folder: backupsURL)
        try await io.write(backup, folder: backupsURL)
        let imported = try await io.prepare(backup.payload, root: store.storageURL)
        guard canApply(), capturedGeneration == generation,
              try SyncPayload.encoder().encode(store.state) == original else { throw SyncError.busy }
        guard editingSessions.isEmpty, !automatic || !NSApplication.shared.isActive else { throw SyncError.editing }
        try store.commitImportedState(imported)
        generation += 1
        onApply?()
        // Leave metadata untouched on a failed write: the next check preserves it as a local edit.
        var next = metadata
        if publish, let folder {
            let resolved = SyncBackup(payload: backup.payload, parents: parents, device: metadata.device)
            try await io.write(resolved, folder: backupsURL)
            try await io.write(resolved, folder: folder)
            next.parents = [resolved.id]
        } else { next.parents = parents }
        next.fingerprint = fingerprint
        try saveMetadata(next); metadata = next
        stagedBackup = nil
        pendingVersion = nil
        status = "설정을 적용했습니다. 앱 설치·권한·모니터 연결은 이 Mac에서 확인해 주세요."
    }

    public func refreshBackups() async {
        do {
            if FileManager.default.fileExists(atPath: backupsURL.path) {
                versions = try await io.read(backupsURL).sorted { $0.createdAt > $1.createdAt }
            }
        } catch { errorMessage = "백업 목록을 읽지 못했습니다: \(error.localizedDescription)" }
    }

    private func saveMetadata(_ value: Metadata) throws {
        try FileManager.default.createDirectory(at: store.storageURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: metadataURL, options: .atomic)
    }
}
