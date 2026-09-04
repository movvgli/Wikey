import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class ClipboardService {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func copy(_ document: NSAttributedString) throws {
        pasteboard.clearContents()
        guard pasteboard.writeObjects([document]) else {
            throw AutomationError.clipboardWriteFailed
        }
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
    }

    public func paste(into application: NSRunningApplication?) async throws {
        guard AXIsProcessTrusted() else {
            throw AutomationError.permissionRequired("손쉬운 사용")
        }
        application?.activate()
        try? await Task.sleep(for: .milliseconds(180))
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw AutomationError.clipboardWriteFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(350))
    }
}
