import Cocoa
import CoreGraphics
import UserNotifications
import Observation

// MARK: - Enums

enum ScreenshotFormat: String, CaseIterable, Identifiable {
    case png, jpg, heic, tiff
    var id: String { rawValue }
    var displayName: String { rawValue == "jpg" ? "JPEG" : rawValue.uppercased() }
}

enum CaptureMode: Int, CaseIterable, Identifiable {
    case fullscreen, window, crop
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fullscreen: "Full Screen"
        case .window:     "Window"
        case .crop:       "Selection"
        }
    }

    var icon: String {
        switch self {
        case .fullscreen: "rectangle.fill"
        case .window:     "macwindow"
        case .crop:       "crop"
        }
    }

    var arguments: [String] {
        switch self {
        case .fullscreen: []
        case .window:     ["-w"]
        case .crop:       ["-s"]
        }
    }
}

// MARK: - CaptureEngine

@Observable
@MainActor
final class CaptureEngine {
    static let shared = CaptureEngine()

    var recentCaptures: [URL] = []

    private let defaults = UserDefaults.standard
    private let maxRecent = 8

    var isFirstRun: Bool { !defaults.bool(forKey: "pixlet.launched") }

    private init() {
        defaults.register(defaults: [
            "pixlet.showNotifications": true,
            "pixlet.format": "png"
        ])
        recentCaptures = (defaults.array(forKey: "pixlet.recentCaptures") as? [String])?
            .compactMap { URL(fileURLWithPath: $0) } ?? []
    }

    // MARK: - Preferences (read at capture time via UserDefaults)

    private var format: ScreenshotFormat {
        ScreenshotFormat(rawValue: defaults.string(forKey: "pixlet.format") ?? "png") ?? .png
    }

    private var openAfterCapture: Bool {
        defaults.bool(forKey: "pixlet.openAfterCapture")
    }

    private var showNotifications: Bool {
        defaults.bool(forKey: "pixlet.showNotifications")
    }

    func markLaunched() {
        defaults.set(true, forKey: "pixlet.launched")
    }

    // MARK: - Folder Bookmark

    var folderDisplayPath: String {
        resolveBookmark()?.path ?? "Not Set"
    }

    func saveFolderBookmark(url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        defaults.set(data, forKey: "pixlet.folderBookmark")
    }

    func folderURL() -> URL? {
        resolveBookmark()
    }

    private func resolveBookmark() -> URL? {
        guard let data = defaults.data(forKey: "pixlet.folderBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if stale { saveFolderBookmark(url: url) }
        return url
    }

    // MARK: - Notifications

    func requestScreenRecordingAccess() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    var hasScreenRecordingAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    // MARK: - Capture

    func capture(mode: CaptureMode, delay: Int = 0) {
        guard hasScreenRecordingAccess else {
            requestScreenRecordingAccess()
            showError("Screen Recording permission is required.\n\nGo to System Settings → Privacy & Security → Screen Recording and enable Pixlet, then relaunch.")
            return
        }
        guard let folder = folderURL() else {
            showError("No capture folder set. Open Settings to choose one.")
            return
        }
        guard folder.startAccessingSecurityScopedResource() else {
            showError("Cannot access the capture folder. Please re-select it in Settings.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        let filename = "capture-\(formatter.string(from: Date())).\(format.rawValue)"
        let dest = folder.appendingPathComponent(filename)

        var args = mode.arguments + ["-t", format.rawValue, "-c"]  // -c = also copy to clipboard
        if delay > 0 { args += ["-T", "\(delay)"] }
        args.append(dest.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = args
        proc.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                defer { folder.stopAccessingSecurityScopedResource() }
                guard let self,
                      p.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: dest.path) else { return }
                self.copyToClipboard(dest)
                var list = self.recentCaptures
                list.insert(dest, at: 0)
                self.recentCaptures = Array(list.prefix(self.maxRecent))
                self.defaults.set(self.recentCaptures.map(\.path), forKey: "pixlet.recentCaptures")
                if self.showNotifications { self.postNotification(filename: filename, fileURL: dest) }
                if self.openAfterCapture { NSWorkspace.shared.open(dest) }
            }
        }

        do {
            try proc.run()
        } catch {
            folder.stopAccessingSecurityScopedResource()
            showError("Capture failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ url: URL) {
        guard let img = NSImage(contentsOf: url),
              let tiff = img.tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff),
              let png  = rep.representation(using: .png, properties: [:]) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        // PNG + TIFF data for design tools, NSImage for native apps, file URL for Finder paste
        pb.declareTypes([.png, .tiff, .fileURL], owner: nil)
        pb.setData(png,  forType: .png)
        pb.setData(tiff, forType: .tiff)
        pb.writeObjects([url as NSURL])
    }

    private func postNotification(filename: String, fileURL: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Capture Saved"
        content.body = filename
        content.sound = .default
        // Attach the screenshot as thumbnail — shows actual capture instead of app icon
        if let attachment = try? UNNotificationAttachment(
            identifier: UUID().uuidString,
            url: fileURL,
            options: [UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                CGRect(x: 0, y: 0, width: 1, height: 1) as AnyObject]
        ) {
            content.attachments = [attachment]
        }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Pixlet"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
