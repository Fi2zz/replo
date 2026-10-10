import SwiftUI

/// 五个 Tab：今日内容已并进日历页，TABATA 从 WOD 里独立成单独入口。各 Feature 目录按委托提示词的模块顺序逐个填实。
struct RootView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }

            WodListView()
                .tabItem { Label("WOD", systemImage: "stopwatch") }

            NavigationStack {
                TabataTimerView()
            }
            .tabItem { Label("TABATA", systemImage: "timer") }

            WeightView()
                .tabItem { Label("体重", systemImage: "chart.line.downtrend.xyaxis") }

            ChatView()
                .tabItem { Label("教练", systemImage: "bubble.left.and.bubble.right") }
        }
    }
}
