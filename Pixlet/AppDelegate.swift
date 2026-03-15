import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 4) {
                Text("Pixlet")
                    .font(.largeTitle.bold())
                Text("Version \(version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("A sleek, modern screen capture utility\nbuilt for macOS 26 and beyond.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            Text("© 2026 ExTV · MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 300)
    }
}

#Preview {
    AboutView()
}
