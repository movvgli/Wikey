import AppKit
import Foundation
import Testing
@testable import WikeyCore

@MainActor
struct ClipboardServiceTests {
    @Test func copiesImageDataToPasteboard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let imageURL = root.appendingPathComponent("sample.png")
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let imageData = try #require(bitmap.representation(using: .png, properties: [:]))
        try imageData.write(to: imageURL)

        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        try service.copyImages(at: [imageURL.path])

        #expect(pasteboard.canReadObject(forClasses: [NSImage.self]))
    }

    @Test func copiesFileURLsToPasteboard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("brief.pdf")
        try Data("sample".utf8).write(to: fileURL)

        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        try service.copyFiles(at: [fileURL.path])

        let copied = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
        #expect(copied?.first?.path == fileURL.path)
    }

    @Test func missingFileProducesUsefulError() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)

        #expect(throws: AutomationError.self) {
            try service.copyFiles(at: ["/tmp/does-not-exist.pdf"])
        }
    }
}
