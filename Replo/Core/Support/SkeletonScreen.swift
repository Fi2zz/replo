import SwiftUI

/// 骨架阶段的占位屏：对应模块落地后整体替换为真实页面。
struct SkeletonScreen: View {
    let title: String
    let systemImage: String
    let module: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text("模块 \(module) 待实现")
            }
            .navigationTitle(title)
        }
    }
}
