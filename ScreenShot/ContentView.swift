import SwiftUI

/// About window displaying app information.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)

            Text("ScreenShot")
                .font(.title)
                .bold()

            Text("Version \(appVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("A lightweight menu bar screenshot utility for macOS.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            Text("\u{00A9} 2025 ExTV. MIT License.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
    }
}

#Preview {
    AboutView()
}
