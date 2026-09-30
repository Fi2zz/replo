import SwiftUI

/// 输入条：一颗胶囊，里面是输入框。
///
/// 空的时候两侧干净（不挂附件、不挂语音），一旦有内容右侧才浮出发送键——
/// 这是图上那套的常见行为，也免得空状态堆一排用不上的按钮。
struct ChatComposer: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($focused)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.leading, 18)
                .padding(.trailing, canSend || isSending ? 4 : 18)

            trailingControl
        }
        .background(.background, in: .capsule)
        .overlay {
            Capsule().strokeBorder(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.18), value: canSend)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isSending {
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 8)
            .padding(.bottom, 6)
        } else if canSend {
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.trailing, 8)
            .padding(.bottom, 6)
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// 教练只答计划相关的事，占位文案别写成通用助手。
    private var placeholder: String { "尽管问，比如「硬拉这周为什么没加」" }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        onSend()
        focused = true
    }
}
