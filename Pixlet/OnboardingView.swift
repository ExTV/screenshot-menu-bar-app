import SwiftUI
import CoreGraphics
import UserNotifications

// MARK: - OnboardingManager

@MainActor
final class OnboardingManager {
    static let shared = OnboardingManager()
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show() {
        guard window == nil else { window?.makeKeyAndOrderFront(nil); return }
        let vc = NSHostingController(rootView: OnboardingView().environment(CaptureEngine.shared))
        let w = NSWindow(contentViewController: vc)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
        // Nil the reference when the user closes via the ✕ button
        // so show() works correctly on subsequent calls
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if let self {
                    NotificationCenter.default.removeObserver(self.closeObserver as Any)
                    self.closeObserver = nil
                    self.window = nil
                }
            }
        }
    }

    func dismiss() {
        window?.close() // triggers willCloseNotification → window = nil
    }
}

// MARK: - Permission State

enum PermStatus {
    case unknown, granted, denied
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(CaptureEngine.self) private var engine

    @State private var screenRecording: PermStatus = .unknown
    @State private var notifications: PermStatus = .unknown
    @State private var folderChosen = false

    private var canStart: Bool { screenRecording == .granted && folderChosen }

    var body: some View {
        VStack(spacing: 0) {
            heroSection
            permissionsSection
            footerSection
        }
        .frame(width: 480)
        .onAppear { refreshStatuses() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatuses()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 96, height: 96)
                    .glassEffect(in: Circle())
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, 36)

            VStack(spacing: 4) {
                Text("Welcome to Pixlet")
                    .font(.largeTitle.bold())
                Text("Let's set up a few things before you start capturing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 28)
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(spacing: 10) {
            PermissionRow(
                icon: "rectangle.dashed.badge.record",
                iconColor: .blue,
                title: "Screen Recording",
                description: "Required to capture your screen content.",
                badge: "Required",
                badgeColor: .red,
                status: screenRecording
            ) {
                grantScreenRecording()
            } openSettings: {
                openPrivacySettings(pane: "Privacy_ScreenCapture")
            }

            PermissionRow(
                icon: "bell.badge.fill",
                iconColor: .orange,
                title: "Notifications",
                description: "Get notified when a capture is saved.",
                badge: "Optional",
                badgeColor: .secondary,
                status: notifications
            ) {
                grantNotifications()
            } openSettings: {
                openPrivacySettings(pane: "Privacy_Notifications")
            }

            PermissionRow(
                icon: "folder.fill.badge.plus",
                iconColor: .green,
                title: "Capture Folder",
                description: "Choose where your captures are saved.",
                badge: "Required",
                badgeColor: .red,
                status: folderChosen ? .granted : .unknown,
                actionLabel: folderChosen ? "Change…" : "Choose…"
            ) {
                chooseFolder()
            } openSettings: {
                chooseFolder()
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 10) {
            if !canStart {
                Text("Grant Screen Recording and choose a folder to continue.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button {
                engine.markLaunched()
                OnboardingManager.shared.dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .disabled(!canStart)
            .padding(.horizontal, 28)
            .animation(.default, value: canStart)
        }
        .padding(.vertical, 28)
    }

    // MARK: - Actions

    private func refreshStatuses() {
        screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .unknown
        folderChosen = engine.folderURL() != nil
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional: notifications = .granted
                case .denied:                   notifications = .denied
                default:                        notifications = .unknown
                }
            }
        }
    }

    private func grantScreenRecording() {
        CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { refreshStatuses() }
    }

    private func grantNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in refreshStatuses() }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Capture Folder"
        panel.prompt = "Use This Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            engine.saveFolderBookmark(url: url)
            folderChosen = true
        }
    }

    private func openPrivacySettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String
    let badgeColor: Color
    let status: PermStatus
    var actionLabel: String = "Grant"
    let onGrant: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(badgeColor == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(badgeColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            badgeColor == .secondary
                                ? AnyShapeStyle(.quaternary)
                                : AnyShapeStyle(badgeColor.opacity(0.15)),
                            in: Capsule()
                        )
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status / Action
            Group {
                switch status {
                case .granted:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))

                case .denied:
                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.glass)
                        .tint(.orange)
                        .controlSize(.small)

                case .unknown:
                    Button(actionLabel, action: onGrant)
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(iconColor)
                }
            }
            .animation(.spring(duration: 0.3), value: status)
        }
        .padding(14)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    OnboardingView()
        .environment(CaptureEngine.shared)
}
