import Foundation
import SwiftData
import Testing

@testable import Replo

@MainActor
@Suite(.serialized)
struct SessionFlowTests {
    // MARK: - 周节律

    @Test("周节律：周一 B / 周三高强度 / 周五 A / 周日全休")
    func rhythmFollowsThePlan() {
        #expect(WeekRhythm.dayType(weekday: 2) == .dayB)
        #expect(WeekRhythm.dayType(weekday: 3) == .cardio)
        #expect(WeekRhythm.dayType(weekday: 4) == .wod)
        #expect(WeekRhythm.dayType(weekday: 5) == .rest)
        #expect(WeekRhythm.dayType(weekday: 6) == .dayA)
        #expect(WeekRhythm.dayType(weekday: 7) == .cardio)
        #expect(WeekRhythm.dayType(weekday: 1) == .rest)
    }

    // MARK: - 今日计划

    @Test("力量日取出该日的三条动作，重量与组次来自当前周")
    func strengthDayBuildsMovementList() throws {
        let harness = try SessionHarness()
        let plan = harness.plan(on: harness.monday)

        #expect(plan.dayType == .dayB)
        #expect(plan.movements.count == 3)
        #expect(plan.movements.map(\.name) == ["深蹲", "推举", "硬拉"])
        #expect(plan.movements.map(\.weight) == [80, 30, 90])
        #expect(plan.movements.map(\.sets) == [3, 3, 1])
    }

    @Test("周五是 A 日，取前蹲那组")
    func fridayIsDayA() throws {
        let harness = try SessionHarness()
        let plan = harness.plan(on: harness.friday)

        #expect(plan.dayType == .dayA)
        #expect(plan.movements.map(\.name) == ["卧推", "杠铃划船", "前蹲"])
        #expect(plan.movements.allSatisfy { $0.reps == 5 })
    }

    @Test("有氧日与全休日没有动作清单，只给文案")
    func nonStrengthDaysHaveNoMovements() throws {
        let harness = try SessionHarness()

        #expect(harness.plan(on: harness.tuesday).movements.isEmpty)
        #expect(harness.plan(on: harness.wednesday).movements.isEmpty)
        #expect(harness.plan(on: harness.sunday).movements.isEmpty)
        #expect(harness.plan(on: harness.sunday).note.contains("全休"))
    }

    @Test("周次跟着 ActivePlan 走，改周次换整周重量")
    func weekIndexDrivesWeights() throws {
        let harness = try SessionHarness()
        try harness.advanceToWeek(2)
        let plan = harness.plan(on: harness.monday)

        #expect(plan.weekIndex == 2)
        #expect(plan.movements.map(\.weight) == [90, 32.5, 100])
        #expect(harness.planContext.hasNextWeek)
    }

    @Test("四周表走完后没有下一周")
    func noNextWeekAfterLast() throws {
        let harness = try SessionHarness()
        try harness.advanceToWeek(3)

        #expect(harness.planContext.hasNextWeek == false)
    }

    // MARK: - 草稿与提交

    @Test("打勾到计划组数后练完，超出的勾点不动")
    func setsStopAtPlannedCount() throws {
        let store = try SessionHarness().makeStore()
        let id = try #require(store.drafts.first?.id)

        for _ in 0..<6 { store.completeSet(for: id) }

        #expect(store.draft(for: id)?.completedSets == 3)
        #expect(store.draft(for: id)?.finished == true)
        #expect(store.finishedCount == 1)
        #expect(store.allFinished == false)
    }

    @Test("撤销一组能把完成数退回去")
    func undoSet() throws {
        let store = try SessionHarness().makeStore()
        let id = try #require(store.drafts.first?.id)
        store.completeSet(for: id)
        store.undoSet(for: id)

        #expect(store.draft(for: id)?.completedSets == 0)
        #expect(store.allFinished == false)
    }

    @Test("全通过就把三组都做完，决策是加权")
    func finishedSessionProducesAddDecisions() throws {
        let store = try SessionHarness().makeStore()
        store.finishAll()
        store.recapAll(rir: 3)

        #expect(store.allFinished)
        #expect(store.decision(for: try #require(store.drafts.first?.id))?.nextWeight == 85)
        #expect(store.decision(for: try #require(store.drafts.last?.id))?.nextWeight == 95)
    }

    @Test("提交写入一份 SessionLog 与三条 WeightDecision")
    func commitWritesLogAndDecisions() throws {
        let store = try SessionHarness().makeStore()
        store.finishAll()
        let log = try store.commit(to: TestStore.context)

        #expect(log.entries.count == 3)
        #expect(try TestStore.context.fetchCount(FetchDescriptor<SessionLog>()) == 1)
        #expect(try TestStore.context.fetchCount(FetchDescriptor<WeightDecision>()) == 3)
        #expect(store.committedLog?.id == log.id)
    }

    @Test("重复提交不写第二份记录")
    func commitIsOnce() throws {
        let store = try SessionHarness().makeStore()
        store.finishAll()
        _ = try store.commit(to: TestStore.context)
        _ = try store.commit(to: TestStore.context)

        #expect(try TestStore.context.fetchCount(FetchDescriptor<SessionLog>()) == 1)
    }

    @Test("人工改重后决策按新重量算，理由进备注")
    func manualOverrideFlowsIntoDecision() throws {
        let store = try SessionHarness().makeStore()
        let id = try #require(store.drafts.last?.id)
        for _ in 0..<1 { store.completeSet(for: id) }
        store.overrideWeight(for: id, to: 100)
        store.recap(for: id, note: "95 配不出片，改 100")

        #expect(store.decision(for: id)?.nextWeight == 105)
        #expect(store.draft(for: id)?.note.contains("改 100") == true)
        #expect(store.draft(for: id)?.entry.note?.contains("95 配不出") == true)
    }

    @Test("人工加重的天花板是本周步长那一档")
    func overrideCeilingFollowsStep() throws {
        let store = try SessionHarness().makeStore()
        let first = try #require(store.drafts.first?.id)
        let last = try #require(store.drafts.last?.id)
        let squat = try #require(store.draft(for: first))
        let press = try #require(store.draft(for: last))

        #expect(squat.overrideCeiling == 85)
        #expect(press.overrideCeiling == 95)
    }

    @Test("不适立刻原地重复，不看组数")
    func discomfortShortCircuits() throws {
        let store = try SessionHarness().makeStore()
        let id = try #require(store.drafts.first?.id)
        store.recap(for: id, discomfort: true)
        let output = try #require(store.decision(for: id))

        #expect(output.action == .repeat)
        #expect(output.reasons == ["出现不适，原地重复"])
    }

    // MARK: - 连续失败

    @Test("连续原地重复累加 failStreak，加重或降级后清零")
    func failStreakCountsRepeats() throws {
        let id = UUID()
        // 数组按时间从新到旧排：第一个元素是最近一次决策。
        let held = WeightDecision(
            sessionLogId: UUID(), date: Date(), movementId: id,
            currentWeight: 90, nextWeight: 90, action: .repeat
        )
        let dropped = WeightDecision(
            sessionLogId: UUID(), date: Date(), movementId: id,
            currentWeight: 90, nextWeight: 82.5, action: .deload
        )
        let raised = WeightDecision(
            sessionLogId: UUID(), date: Date(), movementId: id,
            currentWeight: 85, nextWeight: 90, action: .add
        )

        #expect(FailStreak.count(for: id, in: [raised, held, held]) == 0)
        #expect(FailStreak.count(for: id, in: [held, raised, held]) == 1)
        #expect(FailStreak.count(for: id, in: [held, held, raised]) == 2)
        #expect(FailStreak.count(for: id, in: [dropped, held, held]) == 0)
        #expect(FailStreak.count(for: UUID(), in: [held, held]) == 0)
    }

    @Test("上次训练日期取最近一条包含该动作的记录")
    func lastSessionDateComesFromLogs() throws {
        let id = UUID()
        let older = SessionLog(
            date: Date(timeIntervalSince1970: 1_000),
            dayType: .dayB,
            entries: [SetEntry(movementId: id, plannedSets: 3, plannedReps: 3)]
        )
        let newer = SessionLog(
            date: Date(timeIntervalSince1970: 2_000),
            dayType: .dayB,
            entries: [SetEntry(movementId: UUID(), plannedSets: 3, plannedReps: 3)]
        )

        let last = FailStreak.lastSessionDate(
            for: id, in: [older, newer], before: Date(timeIntervalSince1970: 3_000)
        )

        #expect(last == older.date)
    }

    // MARK: - 热身组

    @Test("常规动作热身是空杆 → 50% → 70%，落到 2.5 档")
    func standardWarmupSteps() {
        let steps = WarmupPlan.steps(for: plannedMovement(name: "卧推", weight: 40))

        #expect(steps.map(\.weight) == [20, 20, 27.5])
        #expect(steps.map(\.reps) == ["× 8-10", "× 5", "× 3"])
        #expect(steps.map(\.caption) == ["空杆 20kg × 8-10", "50% 20kg × 5", "70% 27.5kg × 3"])
    }

    @Test("硬拉走 40×5 → 60×2 → 75%×1，文案不重复写重量")
    func deadliftWarmupSteps() {
        let steps = WarmupPlan.steps(for: plannedMovement(name: "硬拉", weight: 100))

        #expect(steps.map(\.weight) == [40, 60, 75])
        #expect(steps.map(\.reps) == ["× 5", "× 2", "× 1"])
        #expect(steps.map(\.caption) == ["40kg × 5", "60kg × 2", "75% 75kg × 1"])
    }

    private func plannedMovement(name: String, weight: Double) -> PlannedMovement {
        PlannedMovement(
            movement: Movement(name: name, category: .lower, pattern: .dayB),
            weight: weight,
            sets: 1,
            reps: 3
        )
    }
}

/// 测试里一次性打满整堂课，省得每个用例重复写循环。
private extension SessionStore {
    func finishAll() {
        for draft in drafts {
            for _ in 0..<draft.movement.sets { completeSet(for: draft.id) }
        }
    }

    func recapAll(rir: Int) {
        for draft in drafts { recap(for: draft.id, rir: rir) }
    }
}

/// 测试用的计划上下文：真库、真模板，日期固定在 2026-09-21 那一周的周一。
@MainActor
private struct SessionHarness {
    let planContext: PlanContext
    let monday: Date
    let tuesday: Date
    let wednesday: Date
    let friday: Date
    let sunday: Date

    init() throws {
        let context = try TestStore.seededContext()
        let calendar = Calendar(identifier: .gregorian)
        let activePlan = try #require(try context.fetch(FetchDescriptor<ActivePlan>()).first)
        self.planContext = PlanContext(
            activePlan: activePlan,
            templates: try context.fetch(FetchDescriptor<PlanTemplate>()),
            movements: try context.fetch(FetchDescriptor<Movement>()),
            calendar: calendar
        )
        self.monday = try #require(Self.date(2026, 9, 21, calendar: calendar))
        self.tuesday = try #require(Self.date(2026, 9, 22, calendar: calendar))
        self.wednesday = try #require(Self.date(2026, 9, 23, calendar: calendar))
        self.friday = try #require(Self.date(2026, 9, 25, calendar: calendar))
        self.sunday = try #require(Self.date(2026, 9, 27, calendar: calendar))
    }

    func plan(on date: Date) -> TodayPlan { planContext.plan(on: date) }

    func advanceToWeek(_ index: Int) throws {
        let activePlan = try #require(try TestStore.context.fetch(FetchDescriptor<ActivePlan>()).first)
        activePlan.currentWeekIndex = index
    }

    /// 上次训练定在 7 天前、failStreak 归零，模拟正常间隔。
    func makeStore() throws -> SessionStore {
        let mondayPlan = plan(on: monday)
        let ids = mondayPlan.movements.map(\.movementId)
        let histories = FailStreak.histories(
            movementIds: ids,
            logs: try TestStore.context.fetch(FetchDescriptor<SessionLog>()),
            decisions: try TestStore.context.fetch(FetchDescriptor<WeightDecision>()),
            before: monday
        )
        return SessionStore(plan: mondayPlan, histories: histories)
    }

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar
    ) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))
    }
}
