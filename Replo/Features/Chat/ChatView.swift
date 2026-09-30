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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "key")
                    }
                }
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
        let context = CoachContextBuilder.make(
            logs: logs,
            decisions: decisions,
            movements: movements,
            activePlan: activePlans.first { $0.active } ?? activePlans.first,
            templates: templates,
            today: Date()
        )
        if let store {
            store.update(context: context)
        } else {
            let created = ChatStore(modelContext: modelContext, runtime: runtime, context: context)
            created.reload()
            store = created
        }
    }

    private var keyFailureBinding: Binding<Bool> {
        Binding(get: { keyFailure != nil }, set: { if !$0 { keyFailure = nil } })
    }
}
