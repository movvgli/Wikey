import Foundation

struct InstalledApplication: Identifiable, Hashable, Sendable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var displayName: String
    var path: String
}

enum InstalledApplicationCatalog {
    static func load() async -> [InstalledApplication] {
        await Task.detached(priority: .userInitiated) {
            scan()
        }.value
    }

    private static func scan() -> [InstalledApplication] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        var applicationsByIdentifier: [String: InstalledApplication] = [:]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else { continue }
                enumerator.skipDescendants()
                guard let bundle = Bundle(url: url),
                      let bundleIdentifier = bundle.bundleIdentifier,
                      !bundleIdentifier.isEmpty else { continue }

                let localizedFileName = fileManager.displayName(atPath: url.path)
                let displayName = localizedFileName.isEmpty
                    ? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                    : localizedFileName.replacingOccurrences(of: ".app", with: "")
                let application = InstalledApplication(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    path: url.path
                )

                if let existing = applicationsByIdentifier[bundleIdentifier] {
                    if preferredPath(application.path, over: existing.path) {
                        applicationsByIdentifier[bundleIdentifier] = application
                    }
                } else {
                    applicationsByIdentifier[bundleIdentifier] = application
                }
            }
        }

        return applicationsByIdentifier.values.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private static func preferredPath(_ candidate: String, over existing: String) -> Bool {
        let candidateIsUserApp = candidate.hasPrefix("/Applications/")
        let existingIsUserApp = existing.hasPrefix("/Applications/")
        if candidateIsUserApp != existingIsUserApp { return candidateIsUserApp }
        return candidate.count < existing.count
    }
}
