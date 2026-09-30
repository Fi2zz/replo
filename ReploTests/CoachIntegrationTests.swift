import Foundation
import SwiftusLLM
import Testing

@testable import Replo

/// 真打到假服务上的联调用例。
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
            system: CoachPrompt.system,
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
            system: CoachPrompt.system,
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

    @Test("ChatStore 发一轮：落两条消息、不发失败")
    func chatStoreRoundTrip() async throws {
        setenv("KIMI_BASE_URL", MockKimiServer.baseUrl, 1)
        try KimiKeyStore.save("sk-mock")

        let runtimeStore = RuntimeStore()
        runtimeStore.start()
        defer { unsetenv("KIMI_BASE_URL") }
        let restoreKey = MockKimiServer.stashKey()
        defer { restoreKey() }
        try await waitUntilBooted(runtimeStore)

        let store = ChatStore(modelContext: TestStore.context, runtime: runtimeStore, context: .sample)
        await store.send("今天练什么")

        #expect(store.failure == nil)
        #expect(store.messages.count == 2)
        #expect(store.messages.first?.role == .user)
        #expect(store.messages.last?.role == .assistant)
        #expect(store.messages.last?.content.contains("（mock）收到了") == true)
    }

    /// 装配是异步的，轮询到就绪为止；超时当失败，免得后面报出难懂的错。
    private func waitUntilBooted(_ store: RuntimeStore) async throws {
        for _ in 0..<40 {
            if case .ready = store.state { return }
            try await _Concurrency.Task.sleep(for: .milliseconds(50))
        }
        Issue.record("运行时没在 2 秒内装好：\(store.state.label)")
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

    @Test("ChatStore 流式：收完落一条助手消息，草稿清空")
    func chatStoreStreamsThenPersists() async throws {
        setenv("KIMI_BASE_URL", MockKimiServer.baseUrl, 1)
        defer { unsetenv("KIMI_BASE_URL") }
        let restoreKey = MockKimiServer.stashKey()
        defer { restoreKey() }
        try KimiKeyStore.save("sk-mock")

        let runtimeStore = RuntimeStore()
        runtimeStore.start()
        try await waitUntilBooted(runtimeStore)

        let store = ChatStore(modelContext: TestStore.context, runtime: runtimeStore, context: .sample)
        await store.send("今天练什么")

        #expect(store.failure == nil)
        #expect(store.messages.count == 2)
        #expect(store.messages.last?.content.contains("（mock）收到了") == true)
        #expect(store.streamingText.isEmpty, "收完草稿要清掉，否则界面上会重影")
        #expect(store.isSending == false)
    }

    @Test("开新会话之后，下一次请求真的不带旧历史")
    func newConversationDropsHistory() async throws {
        setenv("KIMI_BASE_URL", MockKimiServer.baseUrl, 1)
        defer { unsetenv("KIMI_BASE_URL") }
        let restoreKey = MockKimiServer.stashKey()
        defer { restoreKey() }
        try KimiKeyStore.save("sk-mock")

        let runtimeStore = RuntimeStore()
        runtimeStore.start()
        try await waitUntilBooted(runtimeStore)
        let store = ChatStore(
            modelContext: TestStore.context,
            runtime: runtimeStore,
            context: .sample,
            defaults: try #require(UserDefaults(suiteName: "new-conversation-\(UUID().uuidString)"))
        )

        await store.send("第一句")
        await store.send("第二句")
        store.startNewConversation()
        await store.send("第三句")

        // 假服务把收到几条历史回述出来，所以这三条断言的是「真发出去的东西」。
        #expect(store.messages[1].content.contains("历史消息 0 条"))
        #expect(store.messages[3].content.contains("历史消息 2 条"), "同一会话里第二轮带上一问一答")
        #expect(store.messages[5].content.contains("历史消息 0 条"), "新会话不该带旧历史")
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
        let restoreKey = MockKimiServer.stashKey()
        defer { restoreKey() }
        try KimiKeyStore.save("sk-mock")
        return try await ReploRuntime.bootstrap()
    }
}

/// 联调用的假服务探针：端口能连上就算起着。
enum MockKimiServer {
    static let host = "127.0.0.1"
    static let port: UInt16 = 8099
    static var baseUrl: String { "http://\(host):\(port)/v1" }

    /// 用例会往钥匙串里塞一把假 Key。调用方拿这个动作用 defer 收尾还原：
    /// 测试宿主的钥匙串就是模拟器里 App 的钥匙串，留一把 sk-mock 会让 App
    /// 拿着假 Key 去撞真接口，还显示「已就绪」。
    static func stashKey() -> () -> Void {
        let previous = try? KeychainStore.read(
            service: KimiConfig.keychainService,
            account: KimiConfig.credentialKey
        )
        return {
            if let previous, !previous.isEmpty {
                try? KimiKeyStore.save(previous)
            } else {
                try? KimiKeyStore.clear()
            }
        }
    }

    /// 直接做一次 TCP 连接，不走 URLSession——这个值在读测试 trait 时求值，
    /// 不能挂起、也不该等太久。
    static var reachable: Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var timeout = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &address.sin_addr)

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}

extension CoachContext {
    /// 联调用的一份固定上下文：周次、7 天记录、今天都齐。
    static var sample: CoachContext {
        CoachContext(
            weekIndex: 1,
            templateName: "4周重建 v2",
            recentSessions: [
                CoachContext.SessionSummary(
                    date: Date(timeIntervalSince1970: 1_790_000_000),
                    dayType: .dayB,
                    lines: ["- 深蹲：完成 3/3 组，末组 3 次，RIR 2，RPE 8 → 下次 85kg（通过，+5）"]
                ),
            ],
            todayNote: "2026年9月22日 星期二 · 低强度有氧｜坡度走"
        )
    }
}
