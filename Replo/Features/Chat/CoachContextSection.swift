import SwiftUI

/// 「会发给模型的上下文」设置区：历史参考档位 + 当前计划/今天安排开关。
/// 纯展示，值由宿主的双向绑定驱动，落盘与刷上下文都在宿主侧完成。
struct CoachContextSection: View {
    @Binding var historyMode: CoachHistoryMode
    @Binding var planIncluded: Bool

    var body: some View {
        Section {
            Picker("训练参考", selection: $historyMode) {
                ForEach(CoachHistoryMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .pickerStyle(.inline)
            Text(historyMode.note)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("当前计划与今天安排", isOn: $planIncluded)
        } header: {
            Text("会发给模型的上下文")
        } footer: {
            Text("system 里是三份计划文档全文（训练计划 / WOD 手册 / 动作说明）；每次提问前在 user 消息前缀里附上当前周次和按档位选出的训练记录，两段都可以关掉。对话只读，模型没有写数据的工具。对话页输入框上方也能快速切换，两处是同一份设置。")
        }
    }
}
