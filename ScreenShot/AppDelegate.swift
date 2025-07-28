import Cocoa

/// AppDelegate manages the menu bar app lifecycle and screenshot functionality.
class AppDelegate: NSObject, NSApplicationDelegate {
    /// The status item displayed in the menu bar.
    var statusItem: NSStatusItem!
    
    /// Returns true if the app is running for the first time.
    var isFirstRun: Bool {
        !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
    }
    
    /// Controls whether the app runs in background (hidden from Dock).
    var runInBackground: Bool {
        get { UserDefaults.standard.bool(forKey: "RunInBackground") }
        set { UserDefaults.standard.set(newValue, forKey: "RunInBackground") }
    }

    /// Called when the app finishes launching. Sets up menu and status item.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if isFirstRun {
            showSetupDialog()
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        } else {
            setActivationPolicy()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera", accessibilityDescription: nil)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Fullscreen", action: #selector(fullscreen), keyEquivalent: "f"))
        menu.addItem(NSMenuItem(title: "Window", action: #selector(window), keyEquivalent: "w"))
        menu.addItem(NSMenuItem(title: "Crop", action: #selector(crop), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Screenshot Folder", action: #selector(openFolder), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Change Folder…", action: #selector(changeFolder), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    /// Sets the app's activation policy based on user preference.
    func setActivationPolicy() {
        NSApp.setActivationPolicy(runInBackground ? .accessory : .regular)
    }

    /// Capture fullscreen screenshot.
    @objc func fullscreen() { runCaptureCommand(args: []) }
    /// Capture window screenshot.
    @objc func window() { runCaptureCommand(args: ["-w"]) }
    /// Capture cropped screenshot.
    @objc func crop() { runCaptureCommand(args: ["-s"]) }

    /// Runs the screencapture command with given arguments and copies result to clipboard.
    func runCaptureCommand(args: [String]) {
        guard let folderURL = getScreenshotFolderURL() else { return }

        if folderURL.startAccessingSecurityScopedResource() {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                .replacingOccurrences(of: "/", with: ".")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: ":", with: ".")

            let path = folderURL.appendingPathComponent("screenshot-\(timestamp).png")

            let process = Process()
            process.launchPath = "/usr/sbin/screencapture"
            process.arguments = args + [path.path]

            process.terminationHandler = { _ in
                if let image = NSImage(contentsOf: path) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([image])
                }
                folderURL.stopAccessingSecurityScopedResource()
            }

            process.launch()
        }
    }

    /// Opens the screenshot folder in Finder.
    @objc func openFolder() {
        guard let folderURL = getScreenshotFolderURL() else { return }
        if folderURL.startAccessingSecurityScopedResource() {
            NSWorkspace.shared.open(folderURL)
            folderURL.stopAccessingSecurityScopedResource()
        }
    }

    /// Prompts user to select a new screenshot folder.
    @objc func changeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select New Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            saveScreenshotFolderBookmark(url: url)
        }
    }

    /// Saves a security-scoped bookmark for the screenshot folder.
    func saveScreenshotFolderBookmark(url: URL) {
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "ScreenshotFolderBookmark")
        } catch {
            print("Bookmark save failed: \(error)")
        }
    }

    /// Retrieves the screenshot folder URL from stored bookmark.
    func getScreenshotFolderURL() -> URL? {
        if let data = UserDefaults.standard.data(forKey: "ScreenshotFolderBookmark") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale { saveScreenshotFolderBookmark(url: url) }
                return url
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        } else {
            return nil
        }
        return nil
    }

    /// Shows the initial setup dialog for first run.
    func showSetupDialog() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Screenshot Tool Setup"
        alert.informativeText = "You can choose to run the app in background (hidden from Dock). You will also need to select a download folder."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")

        let checkbox = NSButton(checkboxWithTitle: "Run in background (hide from Dock)", target: nil, action: nil)
        checkbox.state = .on
        alert.accessoryView = checkbox

        alert.runModal()

        runInBackground = (checkbox.state == .on)
        setActivationPolicy()

        // Prompt for screenshot folder
        let panel = NSOpenPanel()
        panel.title = "Choose Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            saveScreenshotFolderBookmark(url: url)
        }
    }

    /// Quits the application.
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
