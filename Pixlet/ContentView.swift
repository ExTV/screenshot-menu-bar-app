import SwiftUI

struct MenuBarView: View {
    @Environment(CaptureEngine.self) private var engine
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().opacity(0.3).padding(.horizontal, 12)
            captureSection
            Divider().opacity(0.3).padding(.horizontal, 12)
            timedSection
            if !engine.recentCaptures.isEmpty {
                Divider().opacity(0.3).padding(.horizontal, 12)
                recentSection
            }
            Divider().opacity(0.3).padding(.horizontal, 12)
            footerSection
        }
        .frame(width: 300)
        // No .background() — let the MenuBarExtra window's automatic
        // Liquid Glass show through on macOS 26
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "viewfinder.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            Text("Pixlet")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.callout)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Capture Buttons

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTURE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)

            // GlassEffectContainer groups the three buttons into one
            // unified Liquid Glass surface that morphs between them
            GlassEffectContainer {
                HStack(spacing: 0) {
                    ForEach(CaptureMode.allCases) { mode in
                        Button {
                            triggerCapture(mode: mode)
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                Text(mode.label)
                                    .font(.caption2.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Timed Capture

    private var timedSection: some View {
        HStack(spacing: 10) {
            Text("Timed")
                .font(.caption)
                .foregroundStyle(.secondary)

            GlassEffectContainer {
                HStack(spacing: 0) {
                    ForEach([3, 5, 10], id: \.self) { delay in
                        Menu {
                            ForEach(CaptureMode.allCases) { mode in
                                Button {
                                    triggerCapture(mode: mode, delay: delay)
                                } label: {
                                    Label(mode.label, systemImage: mode.icon)
                                }
                            }
                        } label: {
                            Text("\(delay)s")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Recent Captures

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RECENT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Clear") { engine.recentCaptures = [] }
                    .font(.caption)
                    .buttonStyle(.glass)
            }

            ForEach(engine.recentCaptures.prefix(5), id: \.self) { url in
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.glass)
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 8) {
            Button {
                if let url = engine.folderURL(),
                   url.startAccessingSecurityScopedResource() {
                    NSWorkspace.shared.open(url)
                    url.stopAccessingSecurityScopedResource()
                }
            } label: {
                Label("Open Folder", systemImage: "folder")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.glass)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .font(.caption.weight(.medium))
                .buttonStyle(.glass)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Capture Trigger

    private func triggerCapture(mode: CaptureMode, delay: Int = 0) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            engine.capture(mode: mode, delay: delay)
        }
    }
}

#Preview {
    MenuBarView()
        .environment(CaptureEngine.shared)
}
