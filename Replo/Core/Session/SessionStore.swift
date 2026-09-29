import Foundation
import SwiftData
import Observation

/// 一次训练课的全部过程状态：逐组打勾 → 复盘 → 出决策 → 写库。
/// 纯逻辑，不含界面；`@Observable` 是为了让 View 直接读草稿变化。
@MainActor
@Observable
final class SessionStore {
    /// 组间休息默认 180 秒，可在训练页调（规格 7）。
    static let defaultRestSeconds = 180

    let plan: TodayPlan
    private(set) var drafts: [MovementDraft]
    /// 每个动作的历史上下文，提交与出决策时喂给引擎。
    let histories: [UUID: MovementHistory]
    var restSeconds: Int = SessionStore.defaultRestSeconds
    private(set) var committedLog: SessionLog?

    init(plan: TodayPlan, histories: [UUID: MovementHistory] = [:]) {
        self.plan = plan
        self.drafts = plan.movements.map { MovementDraft(movement: $0) }
        self.histories = histories
    }

    var allFinished: Bool { drafts.allSatisfy(\.finished) }
    var finishedCount: Int { drafts.filter(\.finished).count }

    func draft(for movementId: UUID) -> MovementDraft? {
        drafts.first { $0.movementId == movementId }
    }

    /// 打勾一组。点满计划组数后停手，不允许超组。
    func completeSet(for movementId: UUID) {
        update(movementId) { draft in
            guard !draft.finished else { return }
            draft.completedSets += 1
            draft.lastSetReps = draft.movement.reps
        }
    }

    /// 撤销最后一组，练歪了要能退回去。
    func undoSet(for movementId: UUID) {
        update(movementId) { draft in
            draft.completedSets = max(0, draft.completedSets - 1)
        }
    }

    /// 写复盘。传 nil 的字段保持原值，界面按字段分开写就行。
    func recap(
        for movementId: UUID,
        rir: Int? = nil,
        discomfort: Bool? = nil,
        rpe: Int? = nil,
        lastSetReps: Int? = nil,
        note: String? = nil
    ) {
        update(movementId) { draft in
            if let rir { draft.rir = rir }
            if let discomfort { draft.discomfort = discomfort }
            if let rpe { draft.rpe = rpe }
            if let lastSetReps { draft.lastSetReps = lastSetReps }
            if let note { draft.note = note }
        }
    }

    /// 人工改重。配不出目标重量时才用，原因由调用方补进 note。
    func overrideWeight(for movementId: UUID, to weight: Double) {
        update(movementId) { draft in
            draft.manualWeight = weight
        }
    }

    /// 这个动作的引擎结论。已提交后不再变，避免界面显示的和库里对不上。
    func decision(for movementId: UUID) -> DecisionOutput? {
        guard let draft = draft(for: movementId) else { return nil }
        return WeightEngine.decide(input(for: draft))
    }

    /// 写 SessionLog + WeightDecision。已提交过就返回原记录，不写第二份。
    @discardableResult
    func commit(to context: ModelContext) throws -> SessionLog {
        if let committedLog { return committedLog }
        let log = SessionLog(
            date: plan.date,
            dayType: plan.dayType,
            entries: drafts.map(\.entry)
        )
        context.insert(log)
        for draft in drafts {
            context.insert(decisionRecord(for: draft, logID: log.id))
        }
        try context.save()
        committedLog = log
        return log
    }

    func input(for draft: MovementDraft) -> DecisionInput {
        let history = histories[draft.movementId] ?? .none
        return DecisionInput(
            movement: draft.movement.spec,
            currentWeight: draft.trainedWeight,
            plannedSets: draft.movement.sets,
            plannedReps: draft.movement.reps,
            completedSets: draft.completedSets,
            lastSetReps: draft.lastSetRepsOrPlanned,
            rir: draft.rir,
            discomfort: draft.discomfort,
            failStreak: history.failStreak,
            lastSessionDate: history.lastSessionDate,
            today: plan.date
        )
    }

    private func update(_ movementId: UUID, _ change: (inout MovementDraft) -> Void) {
        guard let index = drafts.firstIndex(where: { $0.movementId == movementId }) else { return }
        change(&drafts[index])
    }

    private func decisionRecord(for draft: MovementDraft, logID: UUID) -> WeightDecision {
        let output = WeightEngine.decide(input(for: draft))
        return WeightDecision(
            sessionLogId: logID,
            date: plan.date,
            movementId: draft.movementId,
            currentWeight: draft.trainedWeight,
            nextWeight: output.nextWeight,
            action: output.action,
            reasons: output.reasons,
            warning: output.warning
        )
    }
}
