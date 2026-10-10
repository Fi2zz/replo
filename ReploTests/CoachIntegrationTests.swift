import Foundation
import SwiftusLLM
import Testing

@testable import Replo

/// 真打到假服务上的联调用例（运行时层：装配、请求、SSE、错误透传）。
/// ChatStore 层的联调在 ChatStoreIntegrationTests。
///
/// 只在假服务起着的时候跑（`make test-llm` 会先把它拉起来），平时 `make test`
/// 自动跳过，不因为「本机没起服务」而红。
@Suite("教练联调", .enabled(if: MockKimiServer.reachable), .serialized)
@MainActor
struct CoachIntegrationTests {
    @Test("走完整链路：钥匙串 → provider → SSE → 回答")
    func answersThroughTheWire() async throws {
        let runtime = try await bootstrapAgainstMock()

        let answer = try await runtime.ask(
            system: CoachPrompt.system(),
            conversation: [],
            question: CoachPrompt.userMessage(context: .sample, question: "今天练什么")
        )

        // 假服务把收到的东西回述一遍，所以这几条同时证明了「发出去的是什么」。
        #expect(answer.contains("（mock）收到了"))
        #expect(answer.contains("三份文档：训练计划、WOD 手册、动作说明"))
        #expect(answer.contains("最近 7 天记录 ✓"))
        #expect(answer.contains("周次 ✓"))
        #expect(answer.contains("今天练什么"), "本人问句要跟着前缀一起发出去")
    }

    @Test("带上历史对话再问一轮")
    func carriesConversationHistory() async throws {
        let runtime = try await bootstrapAgainstMock()

        let answer = try await runtime.ask(
            system: CoachPrompt.system(),
            conversation: [
                LlmMessage("user", "硬拉这周为什么没加"),
                LlmMessage("assistant", "余力只剩 1 次，原地重复。"),
            ],
            question: CoachPrompt.userMessage(context: .sample, question: "那下周呢")
        )

        #expect(answer.contains("历史消息 2 条"))
    }

    @Test("服务端报错要把原文和状态码带出来，不许静默成功")
    func surfacesServerErrors() async throws {
        let runtime = try await bootstrapAgainstMock(pathSuffix: "/unauthorized")

        do {
            _ = try await runtime.ask(system: "s", conversation: [], question: "在吗")
            Issue.record("服务端返回 401 时不该当成成功")
        } catch {
            let reason = ErrorText.reason(error)
            #expect(reason.contains("不认"), "要把服务端给的原因带出来：\(reason)")
            #expect(reason.contains("401"))
        }
    }

    @Test("流式：增量真的分片到达，拼起来是完整回答")
    func streamsDeltas() async throws {
        let runtime = try await bootstrapAgainstMock()

        let stream = await runtime.askStream(system: "s", conversation: [], question: "今天练什么")
        var deltas: [String] = []
        for try await event in stream {
            if case .textDelta(let delta) = event { deltas.append(delta) }
        }

        #expect(deltas.count > 1, "要边生成边到，不能一次给完")
        #expect(deltas.joined().contains("（mock）收到了"))
    }

    @Test("K3 的请求真的带上了 reasoning_effort=high")
    func carriesEffortForK3() async throws {
        setenv("KIMI_MODEL", "kimi-k3", 1)
        defer { unsetenv("KIMI_MODEL") }
        let runtime = try await bootstrapAgainstMock()

        let answer = try await runtime.ask(system: "s", conversation: [], question: "今天练什么")

        #expect(answer.contains("reasoning_effort：high"))
    }

    @Test("K2.6 的请求里没有 reasoning_effort")
    func omitsEffortForK26() async throws {
        setenv("KIMI_MODEL", "kimi-k2.6", 1)
        defer { unsetenv("KIMI_MODEL") }
        let runtime = try await bootstrapAgainstMock()

        let answer = try await runtime.ask(system: "s", conversation: [], question: "今天练什么")

        #expect(answer.contains("reasoning_effort：（无）"))
    }

    private func bootstrapAgainstMock(pathSuffix: String = "") async throws -> ReploRuntime {
        // 这次装配会读环境变量，所以先指过去；App 里的默认端点不受影响。
        setenv("KIMI_BASE_URL", MockKimiServer.baseUrl + pathSuffix, 1)
        defer { unsetenv("KIMI_BASE_URL") }
        let restoreProvider = MockKimiServer.pinKimiProvider()
        defer { restoreProvider() }
        let restoreKey = MockKimiServer.stashKey()
        defer { restoreKey() }
        try CoachKeyStore.save("sk-mock", provider: .kimi)
        return try await ReploRuntime.bootstrap()
    }
}
