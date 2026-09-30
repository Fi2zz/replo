import Foundation
import SwiftData
import Testing

@testable import Replo

@MainActor
@Suite("会话分组", .serialized)
struct ConversationTests {
    @Test("没记录时落在遗留会话上，升级前的消息不会各自成一段")
    func defaultsToLegacyConversation() throws {
        #expect(KimiConversationStore.current(in: try isolated()) == KimiChatMessage.legacyConversation)
    }

    @Test("开新会话换一个 id，而且记得住")
    func startNewPersists() throws {
        let defaults = try isolated()
        let first = KimiConversationStore.startNew(in: defaults)
        #expect(first != KimiChatMessage.legacyConversation)
        #expect(KimiConversationStore.current(in: defaults) == first)

        let second = KimiConversationStore.startNew(in: defaults)
        #expect(second != first)
        #expect(KimiConversationStore.current(in: defaults) == second)
    }

    @Test("存了个坏值就退回遗留会话，不崩")
    func corruptValueFallsBack() throws {
        let defaults = try isolated()
        defaults.set("not-a-uuid", forKey: KimiConversationStore.defaultsKey)

        #expect(KimiConversationStore.current(in: defaults) == KimiChatMessage.legacyConversation)
    }

    @Test("历史只取当前会话")
    func historyOnlyFromCurrentConversation() throws {
        let store = try makeStore()
        let old = KimiConversationStore.startNew(in: try isolated())
        try insert(role: .user, content: "上一段会话的问", conversation: old)
        try insert(role: .assistant, content: "上一段会话的答", conversation: old)
        try insert(role: .user, content: "这次的问", conversation: store.conversationID)
        store.reload()

        #expect(store.messages.count == 3, "旧消息仍然在列表里，能往回翻")
        #expect(store.recentTurns().map(\.content) == ["这次的问"])
    }

    @Test("历史最多带最近 6 条")
    func historyIsCapped() throws {
        let store = try makeStore()
        for index in 1...8 {
            try insert(role: .user, content: "第 \(index) 句", conversation: store.conversationID)
        }
        store.reload()

        let history = store.recentTurns()
        #expect(history.count == 6)
        #expect(history.first?.content == "第 3 句")
        #expect(history.last?.content == "第 8 句")
    }

    @Test("开新会话之后历史清空，但旧消息还在列表里")
    func startNewClearsHistoryOnly() throws {
        let store = try makeStore()
        try insert(role: .user, content: "旧问题", conversation: store.conversationID)
        store.reload()
        #expect(store.recentTurns().count == 1)

        store.startNewConversation()

        #expect(store.recentTurns().isEmpty)
        #expect(store.messages.count == 1, "旧消息不该被删")
        #expect(store.messages.allSatisfy { $0.conversationID != store.conversationID })
    }

    @Test("新会话还没说话时认得出是空的")
    func detectsEmptyConversation() throws {
        let store = try makeStore()
        try insert(role: .user, content: "旧问题", conversation: store.conversationID)
        store.reload()
        #expect(store.conversationIsEmpty == false)

        store.startNewConversation()
        #expect(store.conversationIsEmpty)
    }

    // MARK: - 夹具

    @MainActor
    private func makeStore() throws -> ChatStore {
        let defaults = try isolated()
        return ChatStore(
            modelContext: try TestStore.seededContext(),
            runtime: RuntimeStore(),
            context: .sample,
            defaults: defaults
        )
    }

    @MainActor
    private func insert(role: ChatRole, content: String, conversation: UUID) throws {
        TestStore.context.insert(
            KimiChatMessage(role: role, content: content, conversationID: conversation)
        )
        try TestStore.context.save()
    }

    private func isolated() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "conversation-tests-\(UUID().uuidString)"))
    }
}
