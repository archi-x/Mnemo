import SwiftUI

@main
struct MnemoApp: App {
    @StateObject private var store: AppStore = {
        let s = AppStore()
        s.seedDemoIfNeeded()
        return s
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
