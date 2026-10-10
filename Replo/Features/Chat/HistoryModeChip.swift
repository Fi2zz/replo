import SwiftUI

/// 对话页输入区上方的训练参考快捷切换：当前档位一目了然，点开直接换。
/// 不自己持久化，换档交给宿主的 onChange（与设置面板共享同一份 UserDefaults）。
struct HistoryModeChip: View {
    let mode: CoachHistoryMode
    let planIncluded: Bool
    let onChange: (CoachHistoryMode) -> Void
    let onPlanIncludedChange: (Bool) -> Void

    var body: some View {
        Menu {
            Picker("训练参考", selection: modeBinding) {
                ForEach(CoachHistoryMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            Toggle("当前计划与今天安排", isOn: planIncludedBinding)
        } label: {
            Label(labelText, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        // 同行右侧是动作条，chip 按内容收宽，不抢占整行。
        .padding(.leading, 20)
        .padding(.bottom, 6)
    }

    /// 计划被关掉时在 chip 上看得出来，不然发出去的上下文和看到的不一致。
    private var labelText: String {
        planIncluded ? "参考：\(mode.title)" : "参考：\(mode.title) · 无计划"
    }

    private var modeBinding: Binding<CoachHistoryMode> {
        Binding(
            get: { mode },
            set: { onChange($0) }
        )
    }

    private var planIncludedBinding: Binding<Bool> {
        Binding(
            get: { planIncluded },
            set: { onPlanIncludedChange($0) }
        )
    }
}
