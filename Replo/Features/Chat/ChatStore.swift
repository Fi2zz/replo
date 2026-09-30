import Foundation
import SwiftData
import SwiftusCredentials
import SwiftusLLM
import Observation

/// 对话状态：消息、流式草稿、发送中、错误。对话只读，模型不写任何数据（规格 8）。
@MainActor
@Observable
final class ChatStore {
    private(set) var messages: [KimiChatMessage] = []
    private(set) var isSending = false
    /// 正在流式接收的正文，界面拿它当「正在说的那句」渲染。
    private(set) var streamingText = ""
    /// 正在流式接收的思考过程（K3 会先想再答）。
    private(set) var streamingReasoning = ""
    /// 最近一次发问失败的原因。v1 不静默失败：发不出去就要在界面上说清楚。
    private(set) var failure: String?
    /// 拼给模型的最近几轮对话，超出就丢最老的。
    private(set) var context: CoachContext

    /// 当前会话 id。历史只在这一段里取，开新会话就是换掉它。
    private(set) var conversationID: UUID
    /// 当前会话里还没说过话。
    var conversationIsEmpty: Bool {
        !messages.contains { $0.conversationID == conversationID }
    }

    private let modelContext: ModelContext
    private let runtime: RuntimeStore
    private let defaults: UserDefaults
    private var inFlight: _Concurrency.Task<Void, Never>?
    private static let maxTurns = 6

    init(
        modelContext: ModelContext,
        runtime: RuntimeStore,
        context: CoachContext,
        defaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.runtime = runtime
        self.context = context
        self.defaults = defaults
        self.conversationID = KimiConversationStore.current(in: defaults)
    }

    /// 每次回到页面重新拉一遍：消息落库了，聊天历史要能跨启动看得到。
    /// 拉的是全部会话——旧的还要能往回翻，只是不再发给模型。
    func reload() {
        let descriptor = FetchDescriptor<KimiChatMessage>(sortBy: [SortDescriptor(\.createdAt)])
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 开新会话。旧消息留着，模型的上下文从零开始。
    func startNewConversation() {
        stop()
        conversationID = KimiConversationStore.startNew(in: defaults)
    }

    /// 把最新的训练上下文换进去（进入页面时调一次）。
    func update(context: CoachContext) {
        self.context = context
    }

    /// 失败提示看过就收起来。
    func dismissFailure() {
        failure = nil
    }

    /// 发一句。流式接收：先建一条空的助手消息占位，增量往里填，收完落库。
    func send(_ question: String) async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        // 先取历史再记录：这一句要拼进前缀，不能同时又当历史发一遍。
        let history = recentTurns()
        record(role: .user, content: text)
        isSending = true
        failure = nil
        streamingText = ""
        streamingReasoning = ""

        let task = _Concurrency.Task { await receive(history: history, question: text) }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// 停止生成。已经收到的部分照实留下，标一下是被停的。
    func stop() {
        inFlight?.cancel()
    }

    /// 收流：正文增量拼成答案，思考增量单独走，收完写一条助手消息。
    private func receive(history: [LlmMessage], question: String) async {
        defer { clearStreamingState() }
        do {
            let stream = try await runtime.askCoachStream(
                context: context,
                question: question,
                conversation: history
            )
            try await consume(stream)
            commitAnswer()
        } catch is CancellationError {
            finishPartial()
        } catch {
            failure = ErrorText.reason(error)
        }
    }

    /// 边收边填。被取消时抛出去，交给上面按「已停止」收尾。
    private func consume(_ stream: AsyncThrowingStream<LlmStreamEvent, Error>) async throws {
        for try await event in stream {
            if _Concurrency.Task.isCancelled { throw CancellationError() }
            ingest(event)
        }
    }

    private func ingest(_ event: LlmStreamEvent) {
        switch event {
        case .textDelta(let delta):
            streamingText += delta
        case .reasoningDelta(let delta):
            streamingReasoning += delta
        case .done:
            break
        }
    }

    private func clearStreamingState() {
        isSending = false
        streamingText = ""
        streamingReasoning = ""
    }

    /// 流正常收完：落一条助手消息。空回复也如实说，不留一条看不出所以然的气泡。
    private func commitAnswer() {
        let answer = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        record(role: .assistant, content: answer.isEmpty ? "（模型没返回内容）" : answer)
    }

    /// 被中止：收到多少留多少。
    private func finishPartial() {
        let partial = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !partial.isEmpty else { return }
        record(role: .assistant, content: partial + "\n\n（已停止）")
    }

    /// 只把**当前会话**的最近几轮交给模型：避免越聊越贵，也避免上一段会话的
    /// 话题把新会话带偏。训练上下文另走前缀，不受这里影响。
    func recentTurns() -> [LlmMessage] {
        messages
            .filter { $0.conversationID == conversationID }
            .suffix(ChatStore.maxTurns)
            .map { LlmMessage($0.role == .user ? "user" : "assistant", $0.content) }
    }

    private func record(role: ChatRole, content: String) {
        let message = KimiChatMessage(role: role, content: content, conversationID: conversationID)
        modelContext.insert(message)
        try? modelContext.save()
        messages.append(message)
    }
}
