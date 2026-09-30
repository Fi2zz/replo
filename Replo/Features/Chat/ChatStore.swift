import Foundation
import SwiftData
import SwiftusCredentials
import SwiftusLLM
import Observation

/// 对话状态：消息、发送中、错误。对话只读，模型不写任何数据（规格 8）。
@MainActor
@Observable
final class ChatStore {
    private(set) var messages: [KimiChatMessage] = []
    private(set) var isSending = false
    /// 最近一次发问失败的原因。v1 不静默失败：发不出去就要在界面上说清楚。
    private(set) var failure: String?
    /// 拼给模型的最近几轮对话，超出就丢最老的。
    private(set) var context: CoachContext

    private let modelContext: ModelContext
    private let runtime: RuntimeStore
    private static let maxTurns = 6

    init(modelContext: ModelContext, runtime: RuntimeStore, context: CoachContext) {
        self.modelContext = modelContext
        self.runtime = runtime
        self.context = context
    }

    /// 每次回到页面重新拉一遍：消息落库了，聊天历史要能跨启动看得到。
    func reload() {
        let descriptor = FetchDescriptor<KimiChatMessage>(sortBy: [SortDescriptor(\.createdAt)])
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 把最新的训练上下文换进去（进入页面时调一次）。
    func update(context: CoachContext) {
        self.context = context
    }

    /// 失败提示看过就收起来。
    func dismissFailure() {
        failure = nil
    }

    func send(_ question: String) async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        // 先取历史再记录：这一句要拼进前缀，不能同时又当历史发一遍。
        let history = recentTurns()
        record(role: .user, content: text)
        isSending = true
        failure = nil
        defer { isSending = false }

        do {
            let answer = try await runtime.askCoach(
                context: context,
                question: text,
                conversation: history
            )
            record(role: .assistant, content: answer.isEmpty ? "（模型没返回内容）" : answer)
        } catch {
            failure = Self.reason(error)
        }
    }

    /// 只把最近几轮交给模型，避免越聊越贵；训练上下文另走前缀。
    private func recentTurns() -> [LlmMessage] {
        messages
            .suffix(ChatStore.maxTurns)
            .map { LlmMessage($0.role == .user ? "user" : "assistant", $0.content) }
    }

    private func record(role: ChatRole, content: String) {
        let message = KimiChatMessage(role: role, content: content)
        modelContext.insert(message)
        try? modelContext.save()
        messages.append(message)
    }

    /// Swiftus 的异常自带中文原因，`localizedDescription` 只会给「error 1」。
    /// 模型服务端的报错原文也一并带出来，别让人去翻控制台。
    private static func reason(_ error: any Error) -> String {
        ErrorText.reason(error)
    }
}
