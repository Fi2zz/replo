import SwiftUI

/// 模块 6：Kimi 教练对话。当前只回读运行时状态——
/// 先确认 Swiftus 上下文树在 iOS 上装配得通，凭据与请求链路随后再接。
struct ChatView: View {
    @Environment(RuntimeStore.self) private var runtime

    var body: some View {
        NavigationStack {
            List {
                Section("Swiftus 运行时") {
                    LabeledContent("状态", value: runtime.state.label)
                }
                Section("模块 6 待实现") {
                    Text("Keychain 存 API Key、最近 7 天训练上下文注入、只读对话。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("教练")
            .task { runtime.start() }
        }
    }
}
