import SwiftUI

struct SettingsView: View {
    @Environment(CaptureEngine.self) private var engine
    @AppStorage("pixlet.format") private var format: String = "png"
    @AppStorage("pixlet.openAfterCapture") private var openAfterCapture: Bool = false
    @AppStorage("pixlet.showNotifications") private var showNotifications: Bool = true
    @State private var folderPath: String = "Not Set"
    @State private var showingAbout = false

    var body: some View {
        Form {
            Section("Capture") {
                Picker("Format", selection: $format) {
                    ForEach(ScreenshotFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Open in default app after capture", isOn: $openAfterCapture)
                Toggle("Show notification after capture", isOn: $showNotifications)
            }

            Section("Storage") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Capture Folder")
                        Text(folderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Change…") { changeFolder() }
                        .buttonStyle(.bordered)
                }
            }

            Section {
                Button {
                    showingAbout = true
                } label: {
                    Label("About Pixlet", systemImage: "info.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 340)
        .onAppear { folderPath = engine.folderDisplayPath }
        .sheet(isPresented: $showingAbout) {
            AboutView()
                .frame(minWidth: 300, minHeight: 300)
        }
    }

    private func changeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Capture Folder"
        panel.prompt = "Use This Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            engine.saveFolderBookmark(url: url)
            folderPath = url.path
        }
    }
}

#Preview {
    SettingsView()
        .environment(CaptureEngine.shared)
}
