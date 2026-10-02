import SwiftUI

@main
struct ATXPlayerApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(session.colorScheme)
        }
    }
}
