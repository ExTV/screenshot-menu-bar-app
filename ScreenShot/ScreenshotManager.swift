import Cocoa
import UserNotifications

/// Supported screenshot image formats.
enum ScreenshotFormat: String, CaseIterable {
    case png, jpg, heic, tiff

    var displayName: String {
        switch self {
        case .jpg: return "JPEG"
        default: return rawValue.uppercased()
        }
    }
}

/// Screenshot capture mode.
enum CaptureMode: Int {
    case fullscreen = 0, window = 1, crop = 2

    var arguments: [String] {
        switch self {
        case .fullscreen: return []
        case .window: return ["-w"]
        case .crop: return ["-s"]
        }
    }
}

/// Manages screenshot capture, preferences, and file bookmarks.
class ScreenshotManager {
    static let shared = ScreenshotManager()
    private let defaults = UserDefaults.standard
    private let maxRecent = 5

    // MARK: - Preferences

    var screenshotFormat: ScreenshotFormat {
        get {
            guard let raw = defaults.string(forKey: "ScreenshotFormat"),
                  let fmt = ScreenshotFormat(rawValue: raw) else { return .png }
            return fmt
        }
        set { defaults.set(newValue.rawValue, forKey: "ScreenshotFormat") }
    }

    var openAfterCapture: Bool {
        get { defaults.bool(forKey: "OpenAfterCapture") }
        set { defaults.set(newValue, forKey: "OpenAfterCapture") }
    }

    var showNotification: Bool {
        get {
            defaults.object(forKey: "ShowNotification") == nil
                ? true
                : defaults.bool(forKey: "ShowNotification")
        }
        set { defaults.set(newValue, forKey: "ShowNotification") }
    }

    var runInBackground: Bool {
        get { defaults.bool(forKey: "RunInBackground") }
        set { defaults.set(newValue, forKey: "RunInBackground") }
    }

    var isFirstRun: Bool { !defaults.bool(forKey: "HasLaunchedBefore") }

    func markLaunched() { defaults.set(true, forKey: "HasLaunchedBefore") }

    /// Returns the folder path for display without triggering error dialogs.
    var screenshotFolderDisplayPath: String {
        guard let data = defaults.data(forKey: "ScreenshotFolderBookmark") else { return "Not set" }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return "Not set" }
        return url.path
    }

    // MARK: - Recent Screenshots

    var recentScreenshots: [URL] {
        get {
            (defaults.array(forKey: "RecentScreenshots") as? [String])?
                .compactMap { URL(fileURLWithPath: $0) } ?? []
        }
        set {
            defaults.set(
                Array(newValue.prefix(maxRecent)).map(\.path),
                forKey: "RecentScreenshots"
            )
        }
    }

    private func addRecent(_ url: URL) {
        var list = recentScreenshots
        list.insert(url, at: 0)
        recentScreenshots = list
    }

    // MARK: - Bookmark Management

    func saveScreenshotFolderBookmark(url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: "ScreenshotFolderBookmark")
        } catch {
            showError("Failed to save folder access: \(error.localizedDescription)")
        }
    }

    func getScreenshotFolderURL() -> URL? {
        guard let data = defaults.data(forKey: "ScreenshotFolderBookmark") else {
            showError(
                "No screenshot folder selected.\n"
                + "Use \"Change Folder…\" from the menu bar to set one."
            )
            return nil
        }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale { saveScreenshotFolderBookmark(url: url) }
            return url
        } catch {
            showError(
                "Cannot access screenshot folder: \(error.localizedDescription)\n"
                + "Please re-select it via \"Change Folder…\"."
            )
            return nil
        }
    }

    // MARK: - Capture

    func capture(mode: CaptureMode, delay: Int = 0) {
        guard let folderURL = getScreenshotFolderURL() else { return }
        guard folderURL.startAccessingSecurityScopedResource() else {
            showError("Cannot access the screenshot folder. Please re-select it.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        let filename = "screenshot-\(formatter.string(from: Date())).\(screenshotFormat.rawValue)"
        let filePath = folderURL.appendingPathComponent(filename)

        var args = mode.arguments
        args += ["-t", screenshotFormat.rawValue]
        if delay > 0 { args += ["-T", "\(delay)"] }
        args.append(filePath.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                defer { folderURL.stopAccessingSecurityScopedResource() }
                guard let self,
                      proc.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: filePath.path) else { return }

                if let image = NSImage(contentsOf: filePath) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([image])
                }

                self.addRecent(filePath)

                if self.showNotification {
                    self.sendNotification(filename: filePath.lastPathComponent)
                }
                if self.openAfterCapture {
                    NSWorkspace.shared.open(filePath)
                }
            }
        }

        do {
            try process.run()
        } catch {
            folderURL.stopAccessingSecurityScopedResource()
            showError("Failed to capture screenshot: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(filename: String) {
        let content = UNMutableNotificationContent()
        content.title = "Screenshot Saved"
        content.body = filename
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Errors

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "ScreenShot"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
