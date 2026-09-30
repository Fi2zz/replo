import SwiftData
import SwiftUI

/// 教练页：先填 Moonshot API Key 与模型，再问。问句会带上最近 7 天的训练上下文。
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RuntimeStore.self) private var runtime

    @Query private var logs: [SessionLog]
    @Query private var decisions: [WeightDecision]
    @Query private var movements: [Movement]
    @Query private var activePlans: [ActivePlan]
    @Query private var templates: [PlanTemplate]

    @State private var store: ChatStore?
    @State private var draft = ""
    @State private var keyFailure: String?
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChatTranscript(
                    messages: store?.messages ?? [],
                    conversationID: store?.conversationID ?? UUID(),
                    streamingText: store?.streamingText ?? "",
                    streamingReasoning: store?.streamingReasoning ?? "",
                    isSending: store?.isSending ?? false
                )
                failureBanner
                ChatComposer(
                    text: $draft,
                    isSending: store?.isSending ?? false,
                    onSend: send,
                    onStop: { store?.stop() }
                )
            }
            .navigationTitle("教练")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { newConversationButton }
                ToolbarItem(placement: .topBarTrailing) { keyButton }
            }
            .task { prepare() }
            .alert("保存失败", isPresented: keyFailureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(keyFailure ?? "")
            }
            .sheet(isPresented: $isShowingSettings) {
                KimiSettingsSheet(
                    hasKey: runtime.hasKey,
                    fingerprint: runtime.keyFingerprint,
                    state: runtime.state.label,
                    onSave: { saveKey($0) },
                    onClear: { clearKey() },
                    onModelChange: { pick($0) },
                    onReboot: { runtime.restart() }
                )
            }
        }
    }

    /// 开新会话：不断开旧消息，只是让模型从此不记得上文。
    private var newConversationButton: some View {
        Button {
            store?.startNewConversation()
            store?.update(context: currentContext)
            draft = ""
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .disabled(store == nil)
    }

    private var keyButton: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemName: "key")
        }
    }

    /// 发不出去时在输入条上方说清楚，不静默失败。
    @ViewBuilder
    private var failureBanner: some View {
        if let failure = store?.failure {
            Button {
                store?.dismissFailure()
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 动作

    private func send() {
        let text = draft
        draft = ""
        _Concurrency.Task { await store?.send(text) }
    }

    private func saveKey(_ value: String) {
        do {
            if !value.isEmpty { try KimiKeyStore.save(value) }
            runtime.restart()
        } catch {
            keyFailure = error.localizedDescription
        }
    }

    private func clearKey() {
        do {
            try KimiKeyStore.clear()
            runtime.restart()
        } catch {
            keyFailure = error.localizedDescription
        }
    }

    /// 换模型：先记住再重装，provider 的模型是装配时定死的。不关面板，方便来回试。
    private func pick(_ model: KimiModel) {
        KimiModelStore.save(model)
        runtime.restart()
    }

    // MARK: - 组装

    private func prepare() {
        runtime.start()
        if let store {
            store.update(context: currentContext)
        } else {
            let created = ChatStore(
                modelContext: modelContext,
                runtime: runtime,
                context: currentContext
            )
            created.reload()
            store = created
        }
    }

    /// 每次取都是最新的一版：换了会话、或者刚练完，都应该按当时的记录重新拼。
    private var currentContext: CoachContext {
        CoachContextBuilder.make(
            logs: logs,
            decisions: decisions,
            movements: movements,
            activePlan: activePlans.first { $0.active } ?? activePlans.first,
            templates: templates,
            today: Date()
        )
    }

    private var keyFailureBinding: Binding<Bool> {
        Binding(get: { keyFailure != nil }, set: { if !$0 { keyFailure = nil } })
    }
}
