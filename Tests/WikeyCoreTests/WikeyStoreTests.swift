import AppKit
import Testing
@testable import WikeyCore

@MainActor
struct WikeyStoreTests {
    @Test func stateAndRichTemplateRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = WikeyStore(rootURL: root)
        store.load()
        let workflowID = store.addWorkflow()
        let templateID = store.addTemplate()
        let document = NSAttributedString(
            string: "서식 템플릿",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 15), .link: URL(string: "https://example.com")!]
        )
        store.saveTemplateDocument(document, for: templateID)

        let reloaded = WikeyStore(rootURL: root)
        reloaded.load()
        #expect(reloaded.workflows.first?.id == workflowID)
        #expect(reloaded.templateDocument(id: templateID).string == "서식 템플릿")
        #expect(reloaded.lastPersistenceError == nil)
    }

    @Test func corruptStateStartsEmptyAndCreatesBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("config.json"))

        let store = WikeyStore(rootURL: root)
        store.load()
        #expect(store.workflows.isEmpty)
        #expect(store.lastPersistenceError != nil)
        let backups = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(backups.contains(where: { $0.hasPrefix("config-corrupt-") }))
    }
}
