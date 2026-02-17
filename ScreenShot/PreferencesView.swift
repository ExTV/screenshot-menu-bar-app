import SwiftUI

/// Settings window for configuring screenshot preferences.
struct PreferencesView: View {
    @State private var selectedFormat: ScreenshotFormat = .png
    @State private var openAfterCapture = false
    @State private var showNotification = true
    @State private var runInBackground = false
    @State private var folderPath = "Not set"

    private let manager = ScreenshotManager.shared

    var body: some View {
        Form {
            Section("Screenshot") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ScreenshotFormat.allCases, id: \.self) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Open in default app after capture", isOn: $openAfterCapture)
                Toggle("Show notification after capture", isOn: $showNotification)
            }

            Section("General") {
                Toggle("Run in background (hide from Dock)", isOn: $runInBackground)

                HStack {
                    Text("Screenshot Folder:")
                    Text(folderPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change…") { changeFolder() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadPreferences() }
        .onChange(of: selectedFormat) { _, val in manager.screenshotFormat = val }
        .onChange(of: openAfterCapture) { _, val in manager.openAfterCapture = val }
        .onChange(of: showNotification) { _, val in manager.showNotification = val }
        .onChange(of: runInBackground) { _, val in
            manager.runInBackground = val
            NSApp.setActivationPolicy(val ? .accessory : .regular)
        }
    }

    private func loadPreferences() {
        selectedFormat = manager.screenshotFormat
        openAfterCapture = manager.openAfterCapture
        showNotification = manager.showNotification
        runInBackground = manager.runInBackground
        folderPath = manager.screenshotFolderDisplayPath
    }

    private func changeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            manager.saveScreenshotFolderBookmark(url: url)
            folderPath = url.path
        }
    }
}

#Preview {
    PreferencesView()
}
