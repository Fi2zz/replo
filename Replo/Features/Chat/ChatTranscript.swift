import SwiftData
import SwiftUI

/// 对话流：历史消息 + 正在流式说的那句 + 思考中提示。
///
/// 一次会话的消息之间画一条分隔线；开新会话后旧消息仍留在上面可以往回翻，
/// 但模型不会记得它们——所以分隔线要看得见，别让人以为教练失忆。
struct ChatTranscript: View {
    let messages: [KimiChatMessage]
    let conversationID: UUID
    let streamingText: String
    let streamingReasoning: String
    let isSending: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty && !isSending {
                        emptyHint
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if startsConversation(at: index) {
                            ConversationDivider(date: message.createdAt)
                        }
                        Bubble(message: message)
                    }
                    if isSending {
                        streamingBubble
                    }
                    if conversationIsEmpty {
                        newConversationHint
                    }
                    // 滚动锚点：流式追加时把它滚进视野。
                    Color.clear.frame(height: 1).id(anchor)
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: streamingText) { _, _ in scrollToEnd(proxy) }
            .onChange(of: isSending) { _, _ in scrollToEnd(proxy) }
        }
    }

    private var anchor: String { "chat-bottom" }

    /// 当前会话还没说过话，但上面还有旧会话的消息。
    private var conversationIsEmpty: Bool {
        !isSending && !messages.isEmpty && !messages.contains { $0.conversationID == conversationID }
    }

    private func startsConversation(at index: Int) -> Bool {
        guard index > 0 else { return false }
        return messages[index - 1].conversationID != messages[index].conversationID
    }

    private var emptyHint: some View {
        Text("问点具体的，比如「硬拉这周为什么没加」「周三练完腰有点紧」。")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var newConversationHint: some View {
        Text("新会话：教练不会记得上面的内容，但会带上最近 7 天的训练记录。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if streamingText.isEmpty {
                TypingIndicator(reasoning: streamingReasoning)
            } else {
                MarkdownText(text: streamingText)
                    .padding(10)
                    .background(bubbleBackground(for: .assistant), in: .rect(cornerRadius: 12))
                TypingIndicator(reasoning: "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(anchor, anchor: .bottom)
        }
    }
}

/// 会话分界。开新会话时靠它把「教练不记得上面了」摆在明面上。
struct ConversationDivider: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            line
            Text("新会话 · \(DateFormat.monthDayText(date))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            line
        }
        .padding(.vertical, 6)
    }

    private var line: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 0.5)
    }
}

/// 一个气泡。助手消息走 markdown，用户消息是纯文本。
struct Bubble: View {
    let message: KimiChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            content
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.role == .assistant {
            MarkdownText(text: message.content)
                .padding(10)
                .background(bubbleBackground(for: .assistant), in: .rect(cornerRadius: 12))
        } else {
            Text(message.content)
                .padding(10)
                .background(bubbleBackground(for: .user), in: .rect(cornerRadius: 12))
        }
    }
}

/// 气泡底色。用户淡强调色，助手淡灰。
func bubbleBackground(for role: ChatRole) -> Color {
    role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12)
}

/// 「思考中」提示。K3 会先想再答，思考增量有内容时就把最后一行露出来。
private struct TypingIndicator: View {
    let reasoning: String

    var body: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var label: String {
        let last = reasoning
            .components(separatedBy: .newlines)
            .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let last else { return "思考中…" }
        return String(last.prefix(40))
    }
}
