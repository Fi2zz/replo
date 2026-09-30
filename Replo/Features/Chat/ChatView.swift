import SwiftData
import SwiftUI

/// 教练页：先填 Moonshot API Key，再问。问句会带上最近 7 天的训练上下文。
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
                transcript
                inputBar
            }
            .navigationTitle("教练")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { settingsButton }
            }
            .task { prepare() }
            .alert("保存失败", isPresented: keyFailureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(keyFailure ?? "")
            }
            .sheet(isPresented: settingsBinding) {
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

    // MARK: - 对话

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if store?.messages.isEmpty ?? true {
                    Text("问点具体的，比如「硬拉这周为什么没加」「周三练完腰有点紧」。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(store?.messages ?? []) { message in
                    Bubble(message: message)
                }
                if store?.isSending ?? false {
                    ProgressView().padding(.leading, 4)
                }
            }
            .padding()
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
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
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            HStack(spacing: 8) {
                TextField("问教练…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !(store?.isSending ?? true)
    }

    private func send() {
        let text = draft
        draft = ""
        _Concurrency.Task { await store?.send(text) }
    }

    // MARK: - 设置

    private var settingsButton: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemName: "key")
        }
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

    private var settingsBinding: Binding<Bool> {
        Binding(get: { isShowingSettings }, set: { isShowingSettings = $0 })
    }

    private var keyFailureBinding: Binding<Bool> {
        Binding(get: { keyFailure != nil }, set: { if !$0 { keyFailure = nil } })
    }
}

private struct Bubble: View {
    let message: KimiChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.content)
                .padding(10)
                .background(background, in: .rect(cornerRadius: 12))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var background: Color {
        message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12)
    }
}
