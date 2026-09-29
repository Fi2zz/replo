import SwiftData
import SwiftUI

@main
struct ReploApp: App {
    @State private var runtime = RuntimeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(runtime)
        }
        .modelContainer(ReploContainer.shared)
    }
}

/// 存储容器。建不出来就没法跑，失败即崩，不做降级。
enum ReploContainer {
    static let shared: ModelContainer = {
        do {
            return try ReploSchema.makeContainer()
        } catch {
            fatalError("ModelContainer 装配失败：\(error)")
        }
    }()
}
