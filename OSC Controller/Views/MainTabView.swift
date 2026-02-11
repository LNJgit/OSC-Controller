import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                LayoutExplorerView()
            }
            .tabItem { Label("Layouts", systemImage: "square.grid.2x2") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
