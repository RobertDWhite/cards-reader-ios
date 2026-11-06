import SwiftUI

@main
struct CardsApp: App {
    @State private var store = ArchiveStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(ArchiveStore.self) private var store

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Cards", systemImage: "rectangle.stack") }
            YearsView()
                .tabItem { Label("Years", systemImage: "calendar") }
            WebSiteView()
                .tabItem { Label("Collages", systemImage: "square.grid.3x3.square") }
        }
        .task { await store.refresh() }
    }
}
