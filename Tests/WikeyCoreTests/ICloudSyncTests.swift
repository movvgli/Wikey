import AppKit
import Foundation
import Testing
@testable import WikeyCore

@MainActor struct ICloudSyncTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WikeySyncTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func portableAttachmentsAndRichTemplateRoundTrip() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = WikeyStore(rootURL: root.appendingPathComponent("source")); source.load()
        let id = source.addTemplate()
        source.saveTemplateDocument(NSAttributedString(string: "동기화 테스트", attributes: [.link: URL(string: "https://example.com")!]), for: id)
        let attachment = root.appendingPathComponent("example.txt")
        try Data("file contents".utf8).write(to: attachment)
        source.workflows = [Workflow(name: "Test", actions: [.copyTemplate(templateID: id, mode: .copyAndPaste), .pasteFiles(filePaths: [attachment.path]), .pressKey(.enter)])]
        source.save()
        let payload = try SyncPayload.capture(state: source.state, root: source.storageURL)
        let backup = SyncBackup(payload: payload, device: "Test Mac")
        let data = try backup.encoded()
        #expect(!String(decoding: data, as: UTF8.self).contains(root.path))
        let destination = WikeyStore(rootURL: root.appendingPathComponent("destination")); destination.load()
        try destination.installBackup(SyncBackup.decode(data).payload)
        #expect(destination.templateDocument(id: id).string == "동기화 테스트")
        #expect(destination.templateDocument(id: id).attribute(.link, at: 0, effectiveRange: nil) != nil)
        guard case .pasteFiles(let paths) = destination.workflows[0].actions[1] else { Issue.record("Missing attachment action"); return }
        #expect(paths[0] != attachment.path)
        #expect(try Data(contentsOf: URL(fileURLWithPath: paths[0])) == Data("file contents".utf8))
        #expect(try SyncPayload.capture(state: destination.state, root: destination.storageURL).fingerprint == payload.fingerprint)
        let reloaded = WikeyStore(rootURL: destination.storageURL); reloaded.load()
        #expect(reloaded.workflows == destination.workflows)
    }

    @Test func invalidArchiveDoesNotReplaceExistingConfiguration() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root); store.load(); _ = store.addWorkflow()
        let original = try Data(contentsOf: root.appendingPathComponent("config.json"))
        var payload = try SyncPayload.capture(state: store.state, root: root)
        payload.assets["../escape"] = SyncAsset(name: "../escape", data: Data())
        #expect(throws: (any Error).self) { try store.installBackup(payload) }
        #expect(try Data(contentsOf: root.appendingPathComponent("config.json")) == original)
        #expect(store.workflows.count == 1)
    }

    @Test func missingAndOversizedFilesAreNotSilentlyOmitted() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root); store.load()
        store.workflows = [Workflow(actions: [.pasteImages(filePaths: [root.appendingPathComponent("missing.png").path])])]
        #expect(throws: (any Error).self) { try SyncPayload.capture(state: store.state, root: root) }
        let file = root.appendingPathComponent("large.dat")
        try Data(count: 21 * 1_024 * 1_024).write(to: file)
        store.workflows = [Workflow(actions: [.pasteFiles(filePaths: [file.path])])]
        #expect(throws: SyncError.self) { try SyncPayload.capture(state: store.state, root: root) }
    }

    @Test func concurrentEditsAreNotOrderedByDeviceClock() throws {
        let payload = SyncPayload(state: PersistedState(), templateDocuments: [:], assets: [:])
        let base = SyncBackup(payload: payload, device: "A")
        var left = SyncBackup(payload: payload, parents: [base.id], device: "A")
        left.createdAt = Date.distantFuture
        let right = SyncBackup(payload: payload, parents: [base.id], device: "B")
        let versions = [base, left, right]
        try SyncBackup.validateGraph(versions)
        #expect(Set(SyncBackup.heads(in: versions).map(\.id)) == [left.id, right.id])
        let resolved = SyncBackup(payload: payload, parents: [left.id, right.id], device: "A")
        #expect(SyncBackup.heads(in: versions + [resolved]).map(\.id) == [resolved.id])
    }

    @Test func cyclesAndMissingParentsAreRejected() throws {
        let payload = SyncPayload(state: PersistedState(), templateDocuments: [:], assets: [:])
        var a = SyncBackup(payload: payload, device: "A")
        let b = SyncBackup(payload: payload, parents: [a.id], device: "B")
        a.parents = [b.id]
        #expect(throws: SyncError.self) { try SyncBackup.validateGraph([a, b]) }
        #expect(throws: SyncError.self) { try SyncBackup.validateGraph([b]) }
    }

    @Test func twoMacConflictResolutionDeletionAndDisable() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let a = WikeyStore(rootURL: root.appendingPathComponent("A")); a.load()
        let b = WikeyStore(rootURL: root.appendingPathComponent("B")); b.load()
        a.workflows = [Workflow(name: "A setting")]; a.save()
        b.workflows = [Workflow(name: "B setting")]; b.save()
        let sa = ICloudSyncService(store: a), sb = ICloudSyncService(store: b)
        #expect(!sa.isEnabled)
        await sa.synchronize()
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        await sa.connect(to: folder, requireICloud: false)
        await sb.connect(to: folder, requireICloud: false)
        #expect(sa.errorMessage == nil)
        #expect(sb.conflicts.count == 2)
        let selected = try #require(sb.conflicts.first { $0.payload.state.workflows.first?.name == "A setting" })
        await sb.restore(selected)
        #expect(b.workflows.first?.name == "A setting")
        await sa.synchronize()
        #expect(sa.conflicts.isEmpty)
        // A deletion is a new causal version rather than an ignored missing entry.
        b.deleteWorkflow(id: b.workflows[0].id)
        await sb.synchronize()
        sa.canApply = { false }
        await sa.synchronize()
        #expect(a.workflows.count == 1)
        let deletion = try #require(sa.pendingVersion)
        sa.canApply = { true }
        await sa.restore(deletion)
        #expect(a.workflows.isEmpty)
        #expect(!sa.versions.isEmpty)
        sa.disconnect()
        let count = try FileManager.default.contentsOfDirectory(atPath: folder.path).count
        _ = a.addWorkflow()
        await sa.synchronize()
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).count == count)
        #expect(a.workflows.count == 1)
    }

    @Test func productionConnectionRejectsLocalFolder() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root.appendingPathComponent("store")); store.load()
        let sync = ICloudSyncService(store: store)
        await sync.connect(to: root)
        #expect(!sync.isEnabled)
        #expect(sync.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("store/sync-device.json").path))
    }

    @Test func unresolvedPlaceholderDoesNotAppearAsEmptyCloud() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent(".\(UUID()).wikeybackup.icloud"))
        await #expect(throws: (any Error).self) { try await SyncFolderIO().read(root) }
    }

    @Test func unseenConcurrentVersionSurvivesResolution() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = WikeyStore(rootURL: root.appendingPathComponent("store")); store.load(); _ = store.addWorkflow()
        let sync = ICloudSyncService(store: store)
        await sync.connect(to: folder, requireICloud: false)
        let io = SyncFolderIO()
        let initial = try #require(try await io.read(folder).first)
        var unseen = initial.payload; unseen.state.workflows[0].name = "Unseen edit"
        let incoming = SyncBackup(payload: unseen, parents: [initial.id], device: "Other Mac")
        try await io.write(incoming, folder: folder)
        await sync.restore(initial)
        let heads = SyncBackup.heads(in: try await io.read(folder))
        #expect(heads.count == 2)
        #expect(heads.contains { $0.id == incoming.id })
    }

    @Test func openEditorPreventsRestoreAndKeepsCurrentData() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root); store.load(); _ = store.addWorkflow()
        let sync = ICloudSyncService(store: store)
        let backup = SyncBackup(payload: SyncPayload(state: PersistedState(), templateDocuments: [:], assets: [:]), device: "Other")
        let session = UUID()
        sync.setEditing(true, session: session)
        await sync.restore(backup)
        #expect(store.workflows.count == 1)
        #expect(sync.errorMessage != nil)
        sync.setEditing(false, session: session)
        await sync.restore(backup)
        #expect(store.workflows.isEmpty)
        #expect(sync.errorMessage == nil)
        #expect(sync.versions.contains { $0.payload.state.workflows.count == 1 })
    }

    @Test func offlineBackupAndRestoreWithoutCloudOptIn() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root); store.load(); _ = store.addWorkflow()
        let sync = ICloudSyncService(store: store)
        await sync.createBackup()
        let backup = try #require(sync.versions.first)
        store.deleteWorkflow(id: store.workflows[0].id)
        await sync.restore(backup)
        #expect(store.workflows.count == 1)
        #expect(!sync.isEnabled)
    }

    @Test func failedAttachmentInstallationKeepsCommittedState() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root); store.load(); _ = store.addWorkflow()
        let original = try Data(contentsOf: root.appendingPathComponent("config.json"))
        // A file in place of the destination directory simulates an unwritable asset destination.
        try Data().write(to: root.appendingPathComponent("SyncedAttachments"))
        let payload = SyncPayload(state: PersistedState(), templateDocuments: [:], assets: [:])
        #expect(throws: (any Error).self) { try store.installBackup(payload) }
        #expect(try Data(contentsOf: root.appendingPathComponent("config.json")) == original)
        #expect(store.workflows.count == 1)
    }

    @Test func cloudHistoryIsImmutable() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let io = SyncFolderIO()
        var backup = SyncBackup(payload: SyncPayload(state: PersistedState(), templateDocuments: [:], assets: [:]), device: "A")
        try await io.write(backup, folder: root)
        backup.device = "Modified"
        await #expect(throws: (any Error).self) { try await io.write(backup, folder: root) }
        #expect(try await io.read(root).first?.device == "A")
    }

    @Test func preparingRestoreNeverOverwritesActiveTemplateFiles() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = WikeyStore(rootURL: root); store.load()
        let id = store.addTemplate()
        let old = try SyncPayload.capture(state: store.state, root: root)
        try store.installBackup(old)
        store.saveTemplateDocument(NSAttributedString(string: "New unsynced content"), for: id)
        let before = store.templates[0].fileName
        _ = try WikeyStore.prepareBackup(old, rootURL: root)
        #expect(store.templates[0].fileName == before)
        #expect(store.templateDocument(id: id).string == "New unsynced content")
    }
}
