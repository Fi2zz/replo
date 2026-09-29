import SwiftUI

@main
struct ReploApp: App {
    @State private var runtime = RuntimeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(runtime)
        }
    }
}
