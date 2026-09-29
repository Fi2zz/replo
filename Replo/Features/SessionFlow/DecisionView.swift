import SwiftUI

/// 决策页：下次重量 + 理由 + 警示区徽章；警示区里人工加重量要二次确认（规格 5.3）。
struct DecisionView: View {
    let store: SessionStore
    let onCommit: () throws -> Void

    @State private var errorMessage: String?
    @State private var overrideTarget: MovementDraft?
    @State private var overrideText = ""

    var body: some View {
        List {
            ForEach(store.drafts) { draft in
                Section {
                    decisionRow(draft)
                } header: {
                    Text(draft.movement.name)
                }
            }
            commitButton
        }
        .listStyle(.insetGrouped)
        .alert("写入失败", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("人工改重", isPresented: overrideBinding) {
            TextField("新重量（kg）", text: $overrideText)
                .keyboardType(.decimalPad)
            Button("就这么改") { applyOverride() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(overrideWarning)
        }
    }

    private func decisionRow(_ draft: MovementDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            weightHeader(draft)
            reasons(draft)
            if output(for: draft).warning {
                Label("警示区", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            overrideButton(draft)
        }
    }

    private func weightHeader(_ draft: MovementDraft) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(WeightFormat.text(output(for: draft).nextWeight))
                .font(.title2.monospacedDigit())
            Text("kg")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            actionBadge(draft)
        }
    }

    @ViewBuilder
    private func reasons(_ draft: MovementDraft) -> some View {
        ForEach(output(for: draft).reasons, id: \.self) { reason in
            Label(reason, systemImage: "text.bullet")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func actionBadge(_ draft: MovementDraft) -> some View {
        Text(output(for: draft).action.title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: .capsule)
    }

    @ViewBuilder
    private func overrideButton(_ draft: MovementDraft) -> some View {
        Button {
            overrideTarget = draft
            overrideText = WeightFormat.text(proposal(for: draft))
        } label: {
            Label("人工改重（步长上限 \(WeightFormat.text(draft.overrideCeiling))kg）", systemImage: "slider.horizontal.3")
        }
        .font(.caption)
    }

    /// 步长内能配出来的下一个重量；配不出就退回步长那一档，由用户自己填。
    private func proposal(for draft: MovementDraft) -> Double {
        LoadPlanner.nearestLoadable(draft.trainedWeight, upTo: draft.overrideCeiling)
            ?? draft.overrideCeiling
    }

    private var commitButton: some View {
        Section {
            Button {
                do {
                    try onCommit()
                } catch {
                    errorMessage = String(describing: error)
                }
            } label: {
                Label("确认并写入训练记录", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.allFinished || store.committedLog != nil)
        } footer: {
            Text(store.committedLog == nil
                ? "全部动作打满组数后才能写入。"
                : "已写入。")
        }
    }

    private func output(for draft: MovementDraft) -> DecisionOutput {
        store.decision(for: draft.id)
            ?? DecisionOutput(
                nextWeight: draft.trainedWeight,
                action: .repeat,
                reasons: [],
                warning: false,
                nextFailStreak: 0
            )
    }

    /// 确认文案按有没有越过本周步长、是否在警示区分别说明（规格 5.3）。
    private var overrideWarning: String {
        guard let draft = overrideTarget else { return "" }
        guard let weight = Double(overrideText) else { return "填一个数字。" }
        let ceiling = WeightFormat.text(draft.overrideCeiling)
        let reason = "\(WeightFormat.text(draft.trainedWeight))kg 配不出片，改 \(WeightFormat.text(weight))kg"
        if weight > draft.overrideCeiling {
            return "超过本周步长上限 \(ceiling)kg。\(reason)，会连原因一起记进备注，别当成常规路径。"
        }
        return "\(reason)。会连原因一起记进备注。"
    }

    private func applyOverride() {
        guard let draft = overrideTarget, let next = Double(overrideText) else { return }
        overrideTarget = nil
        let reason = "\(WeightFormat.text(draft.trainedWeight))kg 配不出片，改 \(WeightFormat.text(next))kg"
        store.overrideWeight(for: draft.id, to: next)
        store.recap(for: draft.id, note: draft.note.isEmpty ? reason : "\(draft.note)；\(reason)")
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var overrideBinding: Binding<Bool> {
        Binding(get: { overrideTarget != nil }, set: { if !$0 { overrideTarget = nil } })
    }
}
