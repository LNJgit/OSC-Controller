import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            InterfaceView()
                .tabItem { Label("Interface", systemImage: "slider.horizontal.3") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
