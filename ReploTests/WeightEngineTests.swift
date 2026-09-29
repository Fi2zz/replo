import Foundation
import Testing

@testable import Replo

/// 委托提示词验收表里的 12 条 + 真实案例。规则引擎是纯函数，用例不碰数据库。
@Suite("WeightEngine 验收")
struct WeightEngineTests {
    @Test("用例 1：下肢 80 全部完成余力 3，间隔 7 天 → 加到 85")
    func lowerPassesAddsFive() {
        let output = WeightEngine.decide(EngineFixture(weight: 80, sets: 3, reps: 3, rir: 3).input)

        #expect(output.action == .add)
        #expect(output.nextWeight == 85)
        #expect(output.reasons.contains("通过，+5"))
        #expect(output.warning == false)
    }

    @Test("用例 2：硬拉 100×3 余力 1 → 原地重复 100（9/28 真实案例）")
    func deadliftRealCase() {
        let output = WeightEngine.decide(
            EngineFixture(name: "硬拉", weight: 100, sets: 1, reps: 3, rir: 1, gapDays: 7).input
        )

        #expect(output.action == .repeat)
        #expect(output.nextWeight == 100)
        #expect(output.reasons == ["余力不足 2 次"])
        #expect(output.warning == false)
    }

    @Test("用例 3：上肢 40 4×5 全通过 → 加到 42.5")
    func upperPassesAddsTwoAndHalf() {
        let output = WeightEngine.decide(
            EngineFixture(
                category: .upper, weight: 40, sets: 4, reps: 5, completed: 4, rir: 3, gapDays: 7
            ).input
        )

        #expect(output.action == .add)
        #expect(output.nextWeight == 42.5)
        #expect(output.reasons.contains("通过，+2.5"))
    }

    @Test("用例 4：上肢 45 3×5 余力 1 → 原地重复 45")
    func upperLowRirRepeats() {
        let output = WeightEngine.decide(
            EngineFixture(
                category: .upper, weight: 45, sets: 3, reps: 5, completed: 3, rir: 1, gapDays: 7
            ).input
        )

        #expect(output.action == .repeat)
        #expect(output.nextWeight == 45)
        #expect(output.reasons == ["余力不足 2 次"])
    }

    @Test("用例 5：下肢 60 只完成 2/3 组 → 原地重复，余力够也不加")
    func incompleteSetsRepeat() {
        let output = WeightEngine.decide(
            EngineFixture(weight: 60, sets: 3, reps: 3, completed: 2, rir: 2, gapDays: 7).input
        )

        #expect(output.action == .repeat)
        #expect(output.nextWeight == 60)
        #expect(output.reasons == ["未完成计划组数"])
    }

    @Test("用例 6：出现不适 → 原地重复，且不计入 failStreak")
    func discomfortStops() {
        let output = WeightEngine.decide(
            EngineFixture(weight: 85, discomfort: true, failStreak: 1, gapDays: 7).input
        )

        #expect(output.action == .repeat)
        #expect(output.nextWeight == 85)
        #expect(output.reasons == ["出现不适，原地重复"])
        #expect(output.nextFailStreak == 0)
    }

    @Test("用例 7：连续失败到 2 次仍未通过 → 减 10% 并向上取整到 1.25 的倍数")
    func deloadAfterTwoFailures() {
        let output = WeightEngine.decide(
            EngineFixture(weight: 55, rir: 1, failStreak: 2, gapDays: 7).input
        )

        #expect(output.action == .deload)
        #expect(output.nextWeight == 50)
        #expect(output.reasons == ["连续失败，减 10% 重建"])
        #expect(output.nextFailStreak == 0)
    }

    @Test("用例 8：全通过但间隔只有 3 天 → 拒绝加重")
    func shortGapBlocksAdd() {
        let output = WeightEngine.decide(EngineFixture(weight: 100, gapDays: 3).input)

        #expect(output.action == .repeat)
        #expect(output.nextWeight == 100)
        #expect(output.reasons == ["间隔不足 5 天"])
    }

    @Test("用例 9：深蹲 88 全通过 → 加到 93，还没进警示区")
    func squatBelowWarningZone() {
        let output = WeightEngine.decide(EngineFixture(name: "深蹲", weight: 88, gapDays: 7).input)

        #expect(output.action == .add)
        #expect(output.nextWeight == 93)
        #expect(output.warning == false)
        #expect(output.reasons == ["通过，+5"])
    }

    @Test("用例 10：深蹲 90 余力 2 全通过 → 加到 95 并打警示区标记，理由追加从严")
    func squatInsideWarningZone() {
        let output = WeightEngine.decide(
            EngineFixture(name: "深蹲", weight: 90, rir: 2, gapDays: 7).input
        )

        #expect(output.action == .add)
        #expect(output.nextWeight == 95)
        #expect(output.warning == true)
        #expect(output.reasons == ["通过，+5", "警示区从严"])
    }

    @Test("用例 11：roundTo1p25 向上取整到 1.25 的倍数，整数保持不变")
    func roundsToPlateIncrement() {
        #expect(WeightEngine.roundTo1p25(37.4) == 37.5)
        #expect(WeightEngine.roundTo1p25(52.5) == 52.5)
        #expect(WeightEngine.roundTo1p25(49.5) == 50)
        #expect(WeightEngine.roundTo1p25(100) == 100)
    }

    @Test("硬拉 105 踩在警示区线上，余力 3 不追加从严")
    func deadliftAtWarningFloor() {
        let output = WeightEngine.decide(
            EngineFixture(name: "硬拉", weight: 105, sets: 1, reps: 3, rir: 3, gapDays: 7).input
        )

        #expect(output.warning == true)
        #expect(output.action == .add)
        #expect(output.reasons == ["通过，+5"])
    }

    @Test("硬拉 90 余力 3 → 加到 95（9/21 真实案例）")
    func deadliftSeptember21() {
        let output = WeightEngine.decide(
            EngineFixture(name: "硬拉", weight: 90, sets: 1, reps: 3, rir: 3, gapDays: 7).input
        )

        #expect(output.action == .add)
        #expect(output.nextWeight == 95)
    }

    @Test("未通过一次：failStreak 累加，下次仍失败才降级")
    func failStreakAccumulates() {
        let first = WeightEngine.decide(EngineFixture(weight: 90, rir: 1, gapDays: 7).input)
        #expect(first.action == .repeat)
        #expect(first.nextFailStreak == 1)

        let second = WeightEngine.decide(
            EngineFixture(weight: 90, rir: 1, failStreak: first.nextFailStreak, gapDays: 7).input
        )
        #expect(second.action == .repeat)
        #expect(second.nextFailStreak == 2)

        let third = WeightEngine.decide(
            EngineFixture(weight: 90, rir: 1, failStreak: second.nextFailStreak, gapDays: 7).input
        )
        #expect(third.action == .deload)
        #expect(third.nextFailStreak == 0)
    }

    @Test("通过一次 failStreak 清零")
    func passClearsFailStreak() {
        let output = WeightEngine.decide(EngineFixture(weight: 90, failStreak: 2, gapDays: 7).input)

        #expect(output.action == .add)
        #expect(output.nextFailStreak == 0)
    }

    @Test("没练过该动作：不设间隔门槛，直接按通过处理")
    func firstEverSessionHasNoGapRule() {
        let output = WeightEngine.decide(EngineFixture(weight: 40, gapDays: nil).input)

        #expect(output.action == .add)
        #expect(output.nextWeight == 45)
    }

    @Test("间隔刚好 5 天算够")
    func exactlyFiveDaysIsEnough() {
        let output = WeightEngine.decide(EngineFixture(weight: 85, gapDays: 5).input)

        #expect(output.action == .add)
        #expect(output.nextWeight == 90)
    }

    @Test("警示区下限只认深蹲与硬拉，其他动作再重也不打标")
    func warningFloorsOnlyForSquatAndDeadlift() {
        #expect(MovementSpec.named("深蹲")?.warningFloor == 90)
        #expect(MovementSpec.named("硬拉")?.warningFloor == 105)
        #expect(MovementSpec.named("卧推")?.warningFloor == nil)
        #expect(MovementSpec.named("前蹲")?.inWarningZone(atWeight: 200) == false)
        #expect(MovementSpec.named("不存在的动作") == nil)
    }

    @Test("上肢步长 2.5、下肢步长 5，警示区动作不因在区内而改变步长")
    func incrementsFollowCategory() {
        #expect(MovementCategory.lower.increment == 5)
        #expect(MovementCategory.upper.increment == 2.5)
        let output = WeightEngine.decide(EngineFixture(name: "硬拉", weight: 110, gapDays: 7).input)

        #expect(output.nextWeight == 115)
        #expect(output.warning == true)
    }
}

/// 用 struct 打包测试输入（代码约束：函数参数 ≤ 4，超出用 struct）。
private struct EngineFixture {
    var name = "深蹲"
    var category = MovementCategory.lower
    var pattern = DayPattern.dayB
    var weight = 80.0
    var sets = 3
    var reps = 3
    var completed = 3
    var lastReps = 3
    var rir = 3
    var discomfort = false
    var failStreak = 0
    var gapDays: Int? = 7
    /// 固定时间戳，间隔完全由 `gapDays` 决定，不受运行当天日期影响。
    var today = Date(timeIntervalSince1970: 1_789_000_000)

    var input: DecisionInput {
        DecisionInput(
            movement: MovementSpec(name: name, category: category, pattern: pattern),
            currentWeight: weight,
            plannedSets: sets,
            plannedReps: reps,
            completedSets: completed,
            lastSetReps: lastReps,
            rir: rir,
            discomfort: discomfort,
            failStreak: failStreak,
            lastSessionDate: gapDays.map { today.addingTimeInterval(-Double($0) * 86_400) },
            today: today
        )
    }
}
