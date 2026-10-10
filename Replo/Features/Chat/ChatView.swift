import SwiftData
import SwiftUI

/// 教练页：先选提供商、填 API Key 与模型，再问。上下文内容用户可选：历史档位（默认最近 7 天）与计划/今天安排。
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RuntimeStore.self) private var runtime

    @Query private var logs: [SessionLog]
    @Query private var decisions: [WeightDecision]
    @Query private var movements: [Movement]
    @Query private var activePlans: [ActivePlan]
    @Query private var templates: [PlanTemplate]

    @State var store: ChatStore?
    @State private var draft = ""
    @State private var keyFailure: String?
    @State var isShowingSettings = false
    @State var isShowingHistory = false
    @State private var historyMode: CoachHistoryMode = .lastWeek
    @State private var planIncluded = true
    @State private var selectedMovements: [String] = []
    @State private var isPickingMovements = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChatTranscript(
                    messages: store?.messages ?? [],
                    streamingText: store?.streamingText ?? "",
                    streamingReasoning: store?.streamingReasoning ?? "",
                    isSending: store?.isSending ?? false
                )
                ChatFailureBanner(failure: store?.failure, onDismiss: { store?.dismissFailure() })
                HStack(spacing: 4) {
                    HistoryModeChip(
                        mode: historyMode,
                        planIncluded: planIncluded,
                        onChange: pickHistoryMode,
                        onPlanIncludedChange: pickPlanIncluded
                    )
                    MovementPickBar(selected: $selectedMovements, isPicking: $isPickingMovements)
                }
                ChatComposer(
                    text: $draft,
                    isSending: store?.isSending ?? false,
                    onSend: send,
                    onStop: { store?.stop() }
                )
            }
            .navigationTitle("教练")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { historyButton }
                ToolbarItem(placement: .topBarTrailing) { newConversationButton }
                ToolbarItem(placement: .topBarTrailing) { keyButton }
            }
            .task { prepare() }
            .alert("保存失败", isPresented: keyFailureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(keyFailure ?? "")
            }
            .sheet(isPresented: $isShowingHistory) {
                ConversationListSheet(
                    conversations: store?.conversations ?? [],
                    currentID: store?.conversationID ?? UUID(),
                    onSelect: { store?.switchTo($0) },
                    onDelete: { store?.deleteConversation($0) },
                    onStartNew: { startNewConversation() }
                )
            }
            .sheet(isPresented: $isShowingSettings) {
                CoachSettingsSheet(
                    state: runtime.state.label,
                    onSave: { saveKey($0, provider: $1) },
                    onClear: { clearKey($0) },
                    onProviderChange: { pickProvider($0) },
                    onModelChange: { pick($0) },
                    onHistoryModeChange: { pickHistoryMode($0) },
                    onPlanIncludedChange: { pickPlanIncluded($0) },
                    onReboot: { runtime.restart() }
                )
            }
            .sheet(isPresented: $isPickingMovements) {
                MovementPickerSheet(selected: $selectedMovements)
            }
        }
    }

    // MARK: - 动作

    func startNewConversation() {
        store?.startNewConversation()
        store?.update(context: currentContext)
        draft = ""
    }

    private func send() {
        let text = draft
        let movements = selectedMovements
        draft = ""
        selectedMovements = []
        _Concurrency.Task { await store?.send(text, movements: movements) }
    }

    private func saveKey(_ value: String, provider: CoachProvider) {
        do {
            if !value.isEmpty { try CoachKeyStore.save(value, provider: provider) }
            runtime.restart()
        } catch {
            keyFailure = error.localizedDescription
        }
    }

    private func clearKey(_ provider: CoachProvider) {
        do {
            try CoachKeyStore.clear(provider: provider)
            runtime.restart()
        } catch {
            keyFailure = error.localizedDescription
        }
    }

    /// 换提供商：先记住再重装，端点与凭据是装配时定死的。不关面板，方便来回试。
    private func pickProvider(_ provider: CoachProvider) {
        CoachProviderStore.save(provider)
        runtime.restart()
    }

    /// 换模型：先记住再重装，provider 的模型是装配时定死的。不关面板，方便来回试。
    private func pick(_ model: CoachModel) {
        CoachModelStore.save(model, provider: CoachProviderStore.selected())
        runtime.restart()
    }

    /// 换历史参考档位：落盘 + 立刻按新档位重拼上下文，下次提问生效。
    private func pickHistoryMode(_ mode: CoachHistoryMode) {
        historyMode = mode
        CoachHistoryModeStore.save(mode)
        store?.update(context: currentContext)
    }

    /// 开关「当前计划与今天安排」：同档位，落盘 + 立刻重拼上下文。
    private func pickPlanIncluded(_ included: Bool) {
        planIncluded = included
        CoachPlanReferenceStore.savePlanIncluded(included)
        store?.update(context: currentContext)
    }

    // MARK: - 组装

    private func prepare() {
        runtime.start()
        historyMode = CoachHistoryModeStore.selected()
        planIncluded = CoachPlanReferenceStore.planIncluded()
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

    /// 每次取都是最新的一版：换了会话、换了参考档位、或者刚练完，都应该按当时的记录重新拼。
    private var currentContext: CoachContext {
        CoachContextBuilder.make(
            logs: logs,
            decisions: decisions,
            movements: movements,
            activePlan: activePlans.first { $0.active } ?? activePlans.first,
            templates: templates,
            today: Date(),
            historyMode: historyMode,
            includePlan: planIncluded
        )
    }

    private var keyFailureBinding: Binding<Bool> {
        Binding(get: { keyFailure != nil }, set: { if !$0 { keyFailure = nil } })
    }
}
