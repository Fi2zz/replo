import SwiftData
import SwiftUI

/// 一次训练课的三步：逐组打勾 → 复盘 → 决策写入（规格 7）。
struct SessionView: View {
    private enum Step: Int, CaseIterable {
        case logging, recap, decision

        var title: String {
            switch self {
            case .logging: "记录"
            case .recap: "复盘"
            case .decision: "决策"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let plan: TodayPlan
    let histories: [UUID: MovementHistory]

    @State private var store: SessionStore
    @State private var restTimer = RestTimer()
    @State private var step: Step = .logging

    init(plan: TodayPlan, histories: [UUID: MovementHistory] = [:]) {
        self.plan = plan
        self.histories = histories
        _store = State(initialValue: SessionStore(plan: plan, histories: histories))
    }

    var body: some View {
        VStack(spacing: 0) {
            stepBar
            content
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { trailingControl }
        }
        .onDisappear { restTimer.stop() }
    }

    private var stepBar: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Text(item.title)
                    .font(.caption.weight(item == step ? .bold : .regular))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        item == step
                            ? AnyShapeStyle(Color.accentColor.opacity(0.2))
                            : AnyShapeStyle(Color.clear),
                        in: .capsule
                    )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .logging: loggingList
        case .recap: RecapView(drafts: store.drafts, onRecap: apply)
        case .decision: DecisionView(store: store, onCommit: commit)
        }
    }

    private var loggingList: some View {
        List {
            Section {
                RestTimerView(timer: restTimer, defaultSeconds: store.restSeconds) {
                    store.restSeconds = $0
                }
            } header: {
                Text("打满一组自动开始计时，默认 \(SessionStore.defaultRestSeconds) 秒")
            }
            Section {
                ForEach(store.drafts) { draft in
                    MovementLoggingView(
                        draft: draft,
                        onCompleteSet: { completeSet(draft.id) },
                        onUndoSet: { store.undoSet(for: draft.id) }
                    )
                }
            } header: {
                Text("已完成 \(store.finishedCount)/\(store.drafts.count) 项")
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch step {
        case .logging:
            Button("去复盘") { step = .recap }
                .disabled(!store.allFinished)
        case .recap:
            Button("出决策") { step = .decision }
        case .decision:
            EmptyView()
        }
    }

    /// 打勾一组顺手把休息计时拨起来：组间休息是流程的一部分，不该手动另开。
    private func completeSet(_ movementId: UUID) {
        store.completeSet(for: movementId)
        restTimer.reset(to: store.restSeconds)
        restTimer.start()
    }

    private func apply(_ movementId: UUID, _ change: RecapChange) {
        store.recap(
            for: movementId,
            rir: change.rir,
            discomfort: change.discomfort,
            rpe: change.rpe,
            lastSetReps: change.lastSetReps,
            note: change.note
        )
    }

    private func commit() throws {
        try store.commit(to: context)
        dismiss()
    }
}
