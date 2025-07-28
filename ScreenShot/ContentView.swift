import SwiftUI

/// ContentView displays a simple status message for the ScreenShot menu bar app.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)

            Text("ScreenShot")
                .font(.title)
                .bold()

            Text("Menu bar app is running.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
}
