import SwiftUI

/// 对话页输入区上方的训练参考快捷切换：当前档位一目了然，点开直接换。
/// 不自己持久化，换档交给宿主的 onChange（与设置面板共享同一份 UserDefaults）。
struct HistoryModeChip: View {
    let mode: CoachHistoryMode
    let onChange: (CoachHistoryMode) -> Void

    var body: some View {
        Menu {
            Picker("训练参考", selection: binding) {
                ForEach(CoachHistoryMode.allCases) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
        } label: {
            Label("参考：\(mode.title)", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var binding: Binding<CoachHistoryMode> {
        Binding(
            get: { mode },
            set: { onChange($0) }
        )
    }
}
