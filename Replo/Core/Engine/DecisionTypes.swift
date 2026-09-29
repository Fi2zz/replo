import Foundation

/// 一次决策的全部上下文。字段多于 4 个，按代码约束用 struct 打包（规格 5.1）。
///
/// 「今天」和「上次」都由调用方注入：引擎里不出现 `Date()`，全部路径无系统时钟。
struct DecisionInput: Equatable {
    var movement: MovementSpec
    var currentWeight: Double
    var plannedSets: Int
    var plannedReps: Int
    var completedSets: Int
    /// 末组实际次数，完整完成时等于 `plannedReps`。
    var lastSetReps: Int
    /// 每组还剩几次余力，0-5。低于 2 不许加重。
    var rir: Int
    /// 腰膝 / 关节不适。
    var discomfort: Bool
    /// 本次之前的连续未通过次数（不含本次）。
    var failStreak: Int
    /// 上次练这个动作的日期；该动作还没练过传 nil，此时不设间隔门槛。
    var lastSessionDate: Date?
    var today: Date

    /// 距上次练这个动作过了几天。固定用公历算天数，不受设备时区与用户日历设置影响。
    var gapDays: Int? {
        guard let lastSessionDate else { return nil }
        return Self.calendar.dateComponents([.day], from: lastSessionDate, to: today).day
    }

    private static let calendar = Calendar(identifier: .gregorian)
}

/// 引擎输出。`reasons` 直接进决策页文案，调用方不必二次加工。
struct DecisionOutput: Equatable {
    var nextWeight: Double
    var action: ProgressAction
    var reasons: [String]
    /// 决策时是否踩在警示区，UI 据此打徽章。
    var warning: Bool
    /// 本次之后的连续失败次数，由调用方落库。委托提示词给的签名里没有这一项，
    /// 但规格 5.2 要求 deload 与通过都清零，调用方拿不到就没法执行这条规则。
    var nextFailStreak: Int
}
