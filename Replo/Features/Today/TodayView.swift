import SwiftUI

/// 模块 3：按周节律显示今天该练什么，从这里进入训练课流程。
struct TodayView: View {
    var body: some View {
        SkeletonScreen(title: "今日", systemImage: "figure.strengthtraining.traditional", module: "3")
    }
}
