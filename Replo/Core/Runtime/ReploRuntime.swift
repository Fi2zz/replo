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

    /// 装配：凭据（沙盒文件）→ 校验 Key → LLM wire 层。整条链随 `context` 释放。
    static func bootstrap() async throws -> ReploRuntime {
        let context = Context.root(name: "replo")
        let source = FileCredentials(path: credentialsPath())
        let credentials = try provideCredentials(context, credentials: source)
        try await credentials.refresh()
        _ = try credentials.require(KimiConfig.credentialKey)
        _ = OpenAiCompatibleProvider(config: KimiConfig.openAi(), credentials: credentials)
        return ReploRuntime(context: context, credentials: credentials)
    }

    private init(context: Context, credentials: any Credentials) {
        self.context = context
        self.credentials = credentials
    }

    /// 凭据文件落在 Application Support，内容形如 `{"KIMI_API_KEY": "sk-…"}`。
    /// Keychain 来源按规格第 8 节在模块 6 落地，届时只替换这一处构造。
    private static func credentialsPath() -> String {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return support.appending(path: "moonshot-key.json").path
    }
}
