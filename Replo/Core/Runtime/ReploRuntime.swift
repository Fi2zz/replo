import Foundation
import SwiftusCore
import SwiftusCredentials
import SwiftusLLM

/// 上下文树的持有者。`Context` 与它的成员都在 `@ContextTreeActor` 上，
/// 视图层只能经 `RuntimeStore` 跨 actor 调用（docs/ios-接入指南.md 坑 ②）。
@ContextTreeActor
final class ReploRuntime {
    let context: Context
    private let credentials: any Credentials
    private let provider: any LlmProvider

    /// 装配：凭据（钥匙串）→ 校验 Key → LLM wire 层。整条链随 `context` 释放。
    static func bootstrap() async throws -> ReploRuntime {
        let context = Context.root(name: "replo")
        let source = KeychainCredentials(service: KimiConfig.keychainService)
        let credentials = try provideCredentials(context, credentials: source)
        try await credentials.refresh()
        _ = try credentials.require(KimiConfig.credentialKey)
        let provider = OpenAiCompatibleProvider(config: KimiConfig.openAi(), credentials: credentials)
        return ReploRuntime(context: context, credentials: credentials, provider: provider)
    }

    private init(context: Context, credentials: any Credentials, provider: any LlmProvider) {
        self.context = context
        self.credentials = credentials
        self.provider = provider
    }

    /// 问教练一句。不传 tools：v1 对话只读，模型没有写数据的手段。
    func ask(system: String, conversation: [LlmMessage], question: String) async throws -> String {
        let request = LlmRequest(
            messages: [LlmMessage("system", system)] + conversation + [LlmMessage("user", question)],
            options: KimiConfig.requestOptions
        )
        let result = try await provider.chat(request)
        return result.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
