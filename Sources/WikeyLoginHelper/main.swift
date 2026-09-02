import AppKit
import Foundation

let helperURL = Bundle.main.bundleURL
let mainAppURL = helperURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

guard mainAppURL.pathExtension == "app" else {
    exit(EXIT_FAILURE)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false
configuration.hides = true
configuration.arguments = ["--background"]

NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, _ in
    NSApplication.shared.terminate(nil)
}

NSApplication.shared.run()
