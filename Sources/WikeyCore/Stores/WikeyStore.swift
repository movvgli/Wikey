import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class WikeyStore {
    public private(set) var state = PersistedState()
    public private(set) var lastPersistenceError: String?

    public var workflows: [Workflow] {
        get { state.workflows }
        set { state.workflows = newValue }
    }

    public var templates: [RichTemplate] {
        get { state.templates }
        set { state.templates = newValue }
    }

    public var layouts: [WindowLayout] {
        get { state.layouts }
        set { state.layouts = newValue }
    }

    private let rootURL: URL
    private let stateURL: URL
    private let templatesURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL? = nil) {
        let baseURL = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wikey", isDirectory: true)
        self.rootURL = baseURL
        self.stateURL = baseURL.appendingPathComponent("config.json")
        self.templatesURL = baseURL.appendingPathComponent("Templates", isDirectory: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() {
        do {
            try FileManager.default.createDirectory(at: templatesURL, withIntermediateDirectories: true)
            guard FileManager.default.fileExists(atPath: stateURL.path) else {
                state = PersistedState()
                lastPersistenceError = nil
                return
            }
            let data = try Data(contentsOf: stateURL)
            let decoded = try decoder.decode(PersistedState.self, from: data)
            guard decoded.schemaVersion == 1 else {
                throw StoreError.unsupportedSchema(decoded.schemaVersion)
            }
            state = decoded
            lastPersistenceError = nil
        } catch {
            backUpCorruptStateIfPresent()
            state = PersistedState()
            lastPersistenceError = "설정을 불러오지 못해 안전한 빈 상태로 시작했습니다: \(error.localizedDescription)"
        }
    }

    @discardableResult
    public func save() -> Bool {
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: templatesURL, withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
            lastPersistenceError = nil
            return true
        } catch {
            lastPersistenceError = "설정을 저장하지 못했습니다: \(error.localizedDescription)"
            return false
        }
    }

    public func addWorkflow() -> UUID {
        let workflow = Workflow()
        state.workflows.append(workflow)
        save()
        return workflow.id
    }

    public func addTemplate() -> UUID {
        let template = RichTemplate()
        state.templates.append(template)
        let initial = NSAttributedString(string: "새 템플릿")
        saveTemplateDocument(initial, for: template.id)
        save()
        return template.id
    }

    public func addLayout() -> UUID {
        let layout = WindowLayout()
        state.layouts.append(layout)
        save()
        return layout.id
    }

    public func deleteWorkflow(id: UUID) {
        state.workflows.removeAll { $0.id == id }
        save()
    }

    public func deleteTemplate(id: UUID) {
        guard let template = state.templates.first(where: { $0.id == id }) else { return }
        state.templates.removeAll { $0.id == id }
        state.workflows = state.workflows.map { workflow in
            var workflow = workflow
            workflow.actions.removeAll {
                if case .copyTemplate(let templateID, _) = $0 { return templateID == id }
                return false
            }
            return workflow
        }
        try? FileManager.default.removeItem(at: templatesURL.appendingPathComponent(template.fileName))
        save()
    }

    public func deleteLayout(id: UUID) {
        state.layouts.removeAll { $0.id == id }
        state.workflows = state.workflows.map { workflow in
            var workflow = workflow
            workflow.actions.removeAll {
                if case .applyLayout(let layoutID) = $0 { return layoutID == id }
                return false
            }
            return workflow
        }
        save()
    }

    public func templateDocument(id: UUID) -> NSAttributedString {
        guard let template = state.templates.first(where: { $0.id == id }) else {
            return NSAttributedString()
        }
        let url = templatesURL.appendingPathComponent(template.fileName)
        guard let data = try? Data(contentsOf: url),
              let document = NSAttributedString(rtfd: data, documentAttributes: nil) else {
            return NSAttributedString(string: template.plainText)
        }
        return document
    }

    public func saveTemplateDocument(_ document: NSAttributedString, for id: UUID) {
        guard let index = state.templates.firstIndex(where: { $0.id == id }) else { return }
        do {
            try FileManager.default.createDirectory(at: templatesURL, withIntermediateDirectories: true)
            let range = NSRange(location: 0, length: document.length)
            guard let data = document.rtfd(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) else {
                throw StoreError.couldNotEncodeTemplate
            }
            let url = templatesURL.appendingPathComponent(state.templates[index].fileName)
            try data.write(to: url, options: .atomic)
            state.templates[index].plainText = document.string
            save()
        } catch {
            lastPersistenceError = "템플릿을 저장하지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func backUpCorruptStateIfPresent() {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        let formatter = ISO8601DateFormatter()
        let suffix = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = rootURL.appendingPathComponent("config-corrupt-\(suffix).json")
        try? FileManager.default.copyItem(at: stateURL, to: backupURL)
    }
}

public enum StoreError: LocalizedError {
    case unsupportedSchema(Int)
    case couldNotEncodeTemplate

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "지원하지 않는 설정 버전입니다: \(version)"
        case .couldNotEncodeTemplate: "서식 템플릿을 RTFD로 변환할 수 없습니다."
        }
    }
}
