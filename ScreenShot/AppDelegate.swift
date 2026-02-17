import Cocoa
import SwiftUI

/// AppDelegate manages the menu bar app lifecycle and screenshot functionality.
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    private let manager = ScreenshotManager.shared
    private var recentMenu: NSMenu!
    private var aboutWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if manager.isFirstRun {
            showSetupDialog()
            manager.markLaunched()
        } else {
            setActivationPolicy()
        }

        manager.requestNotificationPermission()
        setupMenuBar()
    }

    func setActivationPolicy() {
        NSApp.setActivationPolicy(manager.runInBackground ? .accessory : .regular)
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera",
            accessibilityDescription: "ScreenShot"
        )

        let menu = NSMenu()
        menu.delegate = self

        // Capture actions
        menu.addItem(withTitle: "Fullscreen", action: #selector(captureFullscreen), keyEquivalent: "f")
        menu.addItem(withTitle: "Window", action: #selector(captureWindow), keyEquivalent: "w")
        menu.addItem(withTitle: "Crop", action: #selector(captureCrop), keyEquivalent: "c")
        menu.addItem(.separator())

        // Timed capture
        let timedItem = NSMenuItem(title: "Timed Capture", action: nil, keyEquivalent: "")
        timedItem.submenu = buildTimedMenu()
        menu.addItem(timedItem)
        menu.addItem(.separator())

        // Recent screenshots
        let recentItem = NSMenuItem(title: "Recent Screenshots", action: nil, keyEquivalent: "")
        recentMenu = NSMenu()
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)
        menu.addItem(.separator())

        // Folder actions
        menu.addItem(withTitle: "Open Screenshot Folder", action: #selector(openFolder), keyEquivalent: "o")
        menu.addItem(withTitle: "Change Folder…", action: #selector(changeFolder), keyEquivalent: ",")
        menu.addItem(.separator())

        // Preferences & About
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: "p")
        menu.addItem(withTitle: "About ScreenShot", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(.separator())

        // Quit
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")

        statusItem.menu = menu
    }

    private func buildTimedMenu() -> NSMenu {
        let menu = NSMenu()
        for delay in [3, 5, 10] {
            let delayItem = NSMenuItem(title: "\(delay) Seconds", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for (title, mode) in [("Fullscreen", CaptureMode.fullscreen),
                                   ("Window", CaptureMode.window),
                                   ("Crop", CaptureMode.crop)] {
                let item = NSMenuItem(title: title, action: #selector(timedCapture(_:)), keyEquivalent: "")
                item.representedObject = ["delay": delay, "mode": mode.rawValue] as [String: Int]
                sub.addItem(item)
            }
            delayItem.submenu = sub
            menu.addItem(delayItem)
        }
        return menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateRecentMenu()
    }

    private func updateRecentMenu() {
        recentMenu.removeAllItems()
        let recents = manager.recentScreenshots

        if recents.isEmpty {
            let empty = NSMenuItem(title: "No Recent Screenshots", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentMenu.addItem(empty)
        } else {
            for url in recents {
                let item = NSMenuItem(
                    title: url.lastPathComponent,
                    action: #selector(openRecent(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = url
                item.image = NSWorkspace.shared.icon(forFile: url.path)
                item.image?.size = NSSize(width: 16, height: 16)
                recentMenu.addItem(item)
            }
            recentMenu.addItem(.separator())
            recentMenu.addItem(
                withTitle: "Clear Recents",
                action: #selector(clearRecents),
                keyEquivalent: ""
            )
        }
    }

    // MARK: - Capture Actions

    @objc func captureFullscreen() { manager.capture(mode: .fullscreen) }
    @objc func captureWindow() { manager.capture(mode: .window) }
    @objc func captureCrop() { manager.capture(mode: .crop) }

    @objc func timedCapture(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Int],
              let delay = info["delay"],
              let raw = info["mode"],
              let mode = CaptureMode(rawValue: raw) else { return }
        manager.capture(mode: mode, delay: delay)
    }

    // MARK: - Recent Screenshots

    @objc func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func clearRecents() {
        manager.recentScreenshots = []
    }

    // MARK: - Folder Actions

    @objc func openFolder() {
        guard let url = manager.getScreenshotFolderURL() else { return }
        if url.startAccessingSecurityScopedResource() {
            NSWorkspace.shared.open(url)
            url.stopAccessingSecurityScopedResource()
        }
    }

    @objc func changeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            manager.saveScreenshotFolderBookmark(url: url)
        }
    }

    // MARK: - Preferences & About

    @objc func openPreferences() {
        if preferencesWindow == nil {
            let hosting = NSHostingView(rootView: PreferencesView())
            hosting.sizingOptions = .intrinsicContentSize
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Preferences"
            window.contentView = hosting
            window.center()
            window.isReleasedWhenClosed = false
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            let hosting = NSHostingView(rootView: AboutView())
            hosting.sizingOptions = .intrinsicContentSize
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About ScreenShot"
            window.contentView = hosting
            window.center()
            window.isReleasedWhenClosed = false
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - First Run Setup

    private func showSetupDialog() {
        let alert = NSAlert()
        alert.messageText = "Welcome to ScreenShot"
        alert.informativeText = "Choose whether to run in the background, then pick a folder for your screenshots."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Quit")

        let checkbox = NSButton(checkboxWithTitle: "Run in background (hide from Dock)", target: nil, action: nil)
        checkbox.state = .on
        alert.accessoryView = checkbox

        if alert.runModal() != .alertFirstButtonReturn {
            NSApp.terminate(nil)
            return
        }

        manager.runInBackground = (checkbox.state == .on)
        setActivationPolicy()

        let panel = NSOpenPanel()
        panel.title = "Choose Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            manager.saveScreenshotFolderBookmark(url: url)
        } else {
            let warn = NSAlert()
            warn.messageText = "No Folder Selected"
            warn.informativeText = "You can set a screenshot folder anytime from the menu bar using \"Change Folder…\"."
            warn.alertStyle = .informational
            warn.addButton(withTitle: "OK")
            warn.runModal()
        }
    }

    // MARK: - Quit

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
