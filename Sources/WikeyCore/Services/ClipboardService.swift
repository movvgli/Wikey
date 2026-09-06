import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class ClipboardService {
    private let pasteboard: NSPasteboard
    private let sender: KeyboardEventSender
    private var settlingDelay: Duration = .milliseconds(500)

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.sender = KeyboardEventSender()
    }

    init(pasteboard: NSPasteboard, sender: KeyboardEventSender) {
        self.pasteboard = pasteboard
        self.sender = sender
    }

    public func copy(_ document: NSAttributedString) throws {
        pasteboard.clearContents()
        guard pasteboard.writeObjects([document]) else {
            throw AutomationError.clipboardWriteFailed
        }
        settlingDelay = .milliseconds(500)
    }

    public func copyImages(at filePaths: [String]) throws {
        var images: [NSImage] = []
        for path in filePaths {
            guard FileManager.default.fileExists(atPath: path),
                  let image = NSImage(contentsOfFile: path) else {
                throw AutomationError.imageNotFound(URL(fileURLWithPath: path).lastPathComponent)
            }
            images.append(image)
        }

        guard !images.isEmpty else { throw AutomationError.clipboardWriteFailed }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(images) else {
            throw AutomationError.clipboardWriteFailed
        }
        settlingDelay = .milliseconds(800)
    }

    public func copyFiles(at filePaths: [String]) throws {
        let fileURLs = try filePaths.map { path in
            guard FileManager.default.fileExists(atPath: path) else {
                throw AutomationError.fileNotFound(URL(fileURLWithPath: path).lastPathComponent)
            }
            return NSURL(fileURLWithPath: path)
        }

        guard !fileURLs.isEmpty else { throw AutomationError.clipboardWriteFailed }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(fileURLs) else {
            throw AutomationError.clipboardWriteFailed
        }
        settlingDelay = .milliseconds(800)
    }

    public func paste(into application: NSRunningApplication?) async throws {
        try await sender.send(
            keyCode: 9,
            flags: .maskCommand,
            into: application,
            settlingDelay: settlingDelay
        )
    }
}
