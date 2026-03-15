import SwiftUI
import ServiceManagement

@main
struct PixletApp: App {
    init() {
        try? SMAppService.mainApp.register()
        if CaptureEngine.shared.isFirstRun {
            DispatchQueue.main.async {
                OnboardingManager.shared.show()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(CaptureEngine.shared)
        } label: {
            Image(systemName: "viewfinder.circle.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(CaptureEngine.shared)
        }
    }
}
