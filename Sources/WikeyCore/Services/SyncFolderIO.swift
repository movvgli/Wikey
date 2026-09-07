import Foundation

/// Serialized, coordinated I/O runs off the main actor. iCloud owns network transfer.
actor SyncFolderIO {
    func read(_ folder: URL) throws -> [SyncBackup] {
        let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        let placeholders = urls.filter { $0.lastPathComponent.hasSuffix(".wikeybackup.icloud") }
        if !placeholders.isEmpty {
            for placeholder in placeholders {
                let name = String(placeholder.lastPathComponent.dropFirst().dropLast(".icloud".count))
                try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(name))
            }
            throw SyncError.missingFile
        }
        var backups: [SyncBackup] = []
        for url in urls where url.pathExtension == "wikeybackup" {
            let cloud = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let status = cloud.ubiquitousItemDownloadingStatus, status != .current {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                throw SyncError.missingFile
            }
            var coordinationError: NSError?
            var outcome: Result<SyncBackup, Error>?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                outcome = Result {
                    let values = try readable.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true,
                          (values.fileSize ?? Int.max) <= SyncPayload.maximumBytes * 2 else { throw SyncError.invalidArchive }
                    let backup = try SyncBackup.decode(Data(contentsOf: readable))
                    guard readable.deletingPathExtension().lastPathComponent == backup.id.uuidString else { throw SyncError.invalidArchive }
                    return backup
                }
            }
            if let coordinationError { throw coordinationError }
            guard let outcome else { throw SyncError.invalidArchive }
            backups.append(try outcome.get())
        }
        return backups
    }

    func write(_ backup: SyncBackup, folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(backup.id.uuidString).wikeybackup")
        let data = try backup.encoded()
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { writable in
            do {
                if FileManager.default.fileExists(atPath: writable.path) {
                    guard try Data(contentsOf: writable) == data else { throw SyncError.invalidArchive }
                } else { try data.write(to: writable, options: .atomic) }
            } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    func capture(_ state: PersistedState, root: URL) throws -> SyncPayload {
        try SyncPayload.capture(state: state, root: root)
    }

    func fingerprint(_ payload: SyncPayload) throws -> String { try payload.fingerprint }

    func prepare(_ payload: SyncPayload, root: URL) throws -> PersistedState {
        try WikeyStore.prepareBackup(payload, rootURL: root)
    }
}
