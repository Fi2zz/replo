import SwiftUI

/// 输入框上方的「选动作」条：入口按钮 + 已选动作 chip（点了移除）。
/// 选中动作随下一条消息发出，发完由 ChatView 清空；不持久化、不进上下文开关。
struct MovementPickBar: View {
    @Binding var selected: [String]
    @Binding var isPicking: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    isPicking = true
                } label: {
                    Label("选动作", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                ForEach(selected, id: \.self) { name in
                    chip(name)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    private func chip(_ name: String) -> some View {
        Button {
            selected.removeAll { $0 == name }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                Image(systemName: "xmark")
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
