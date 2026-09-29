import Foundation

/// 加重规则引擎：输入一次复盘，输出下次重量与理由。纯函数，不碰系统时钟（规格 5.2）。
enum WeightEngine {
    /// 余力至少剩 2 次才允许加重。
    static let minimumRir = 2
    /// 连续未通过到这个次数，本次仍未通过就减 10% 重建。
    static let deloadFailStreak = 2
    static let deloadFactor = 0.90
    /// 相邻两次同动作训练间隔不足这个天数就拒绝加重（规格 5.5）。
    static let minimumGapDays = 5
    /// 落在警示区、余力又不到这个数，理由追加「警示区从严」。
    static let strictRir = 3

    static func decide(_ input: DecisionInput) -> DecisionOutput {
        let verdict = verdict(for: input)
        let warning = input.movement.inWarningZone(atWeight: input.currentWeight)
        return DecisionOutput(
            nextWeight: verdict.nextWeight,
            action: verdict.action,
            reasons: verdict.reasons + strictReasons(input, warning: warning),
            warning: warning,
            nextFailStreak: failStreak(after: input, verdict: verdict)
        )
    }

    /// 向上取整到 1.25kg 的倍数：37.4 → 37.5，52.5 → 52.5。
    static func roundTo1p25(_ weight: Double) -> Double {
        let steps = (weight / 1.25).rounded(.up)
        return (steps * 1.25 * 100).rounded() / 100
    }

    // MARK: - 规则链

    /// 规则按优先级自上而下，命中即返回。
    private static func verdict(for input: DecisionInput) -> Verdict {
        if input.discomfort {
            return hold(input, reason: Reason.discomfort)
        }
        guard input.completedSets >= input.plannedSets else {
            return failed(input, reason: Reason.incompleteSets)
        }
        guard input.rir >= minimumRir else {
            return failed(input, reason: Reason.lowRir)
        }
        return increase(input)
    }

    /// 规则 1：不适即停。原地重复，且不计入 failStreak。
    private static func hold(_ input: DecisionInput, reason: String) -> Verdict {
        Verdict(action: .repeat, nextWeight: input.currentWeight, reasons: [reason], failed: false)
    }

    /// 规则 3/4 命中后的分叉：连续失败到顶就减 10%，否则原地重复。
    private static func failed(_ input: DecisionInput, reason: String) -> Verdict {
        guard input.failStreak >= deloadFailStreak else {
            return Verdict(action: .repeat, nextWeight: input.currentWeight, reasons: [reason], failed: true)
        }
        let reduced = roundTo1p25(input.currentWeight * deloadFactor)
        return Verdict(action: .deload, nextWeight: reduced, reasons: [Reason.deload], failed: true)
    }

    /// 规则 5：全通过就按类别步长加；间隔不够 5 天时拒绝加重（规格 5.5）。
    private static func increase(_ input: DecisionInput) -> Verdict {
        guard let gap = input.gapDays else {
            return add(input, reason: Reason.passed(input.movement.category.increment))
        }
        guard gap >= minimumGapDays else {
            return hold(input, reason: Reason.shortGap)
        }
        return add(input, reason: Reason.passed(input.movement.category.increment))
    }

    private static func add(_ input: DecisionInput, reason: String) -> Verdict {
        let step = input.movement.category.increment
        return Verdict(action: .add, nextWeight: input.currentWeight + step, reasons: [reason], failed: false)
    }

    /// 警示区从严：只追加理由，不改行为（规格 5.3）。
    private static func strictReasons(_ input: DecisionInput, warning: Bool) -> [String] {
        guard warning, input.rir < strictRir else { return [] }
        return [Reason.strict]
    }

    /// 规则 3/4 命中才累加；deload 与通过都清零（规格 5.2 附注）。
    private static func failStreak(after input: DecisionInput, verdict: Verdict) -> Int {
        guard verdict.failed, verdict.action != .deload else { return 0 }
        return input.failStreak + 1
    }
}

/// 一条规则命中后的结论。`failed` 记规则 3/4 是否命中，决定 failStreak 怎么走。
private struct Verdict {
    var action: ProgressAction
    var nextWeight: Double
    var reasons: [String]
    var failed: Bool
}

/// 理由文案。集中一处，决策页直接显示；测试里写的是字面量，改文案要连带改验收用例。
private enum Reason {
    static let discomfort = "出现不适，原地重复"
    static let incompleteSets = "未完成计划组数"
    static let lowRir = "余力不足 2 次"
    static let deload = "连续失败，减 10% 重建"
    static let shortGap = "间隔不足 5 天"
    static let strict = "警示区从严"

    static func passed(_ step: Double) -> String {
        "通过，+\(step == step.rounded() ? String(Int(step)) : String(step))"
    }
}
