import SwiftUI

@main
struct OSC_ControllerApp: App {
    @StateObject private var store = ControlsStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
        }
    }
}
