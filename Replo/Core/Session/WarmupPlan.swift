import Foundation

/// 一次热身组：做什么、多少次、约等于多少重量。
struct WarmupStep: Identifiable, Equatable {
    var label: String
    var weight: Double
    var reps: String
    /// label 里写了具体重量（硬拉的 40kg/60kg）时就不再重复一遍。
    var showsWeight: Bool = true

    var id: String { label }

    /// 界面文案，如「空杆 20kg × 8-10」「40kg × 5」。
    var caption: String {
        let head = showsWeight ? "\(label) \(WeightFormat.text(weight))kg" : label
        return "\(head) \(reps)"
    }
}

/// 正式组之前的热身组。计划文档里写死的两套：常规动作空杆 → 50% → 70%，
/// 硬拉组数更少，40×5 → 60×2 → 75%×1。
enum WarmupPlan {
    private static let plateStep = 2.5
    private static let deadliftName = "硬拉"

    static func steps(for movement: PlannedMovement, barWeight: Double = 20) -> [WarmupStep] {
        movement.name == deadliftName
            ? deadliftSteps(for: movement.weight)
            : standardSteps(for: movement.weight, barWeight: barWeight)
    }

    private static func standardSteps(for weight: Double, barWeight: Double) -> [WarmupStep] {
        [
            WarmupStep(label: "空杆", weight: barWeight, reps: "× 8-10"),
            WarmupStep(label: "50%", weight: near(weight * 0.5), reps: "× 5"),
            WarmupStep(label: "70%", weight: near(weight * 0.7), reps: "× 3"),
        ]
    }

    private static func deadliftSteps(for weight: Double) -> [WarmupStep] {
        [
            WarmupStep(label: "40kg", weight: 40, reps: "× 5", showsWeight: false),
            WarmupStep(label: "60kg", weight: 60, reps: "× 2", showsWeight: false),
            WarmupStep(label: "75%", weight: near(weight * 0.75), reps: "× 1"),
        ]
    }

    /// 落到 2.5kg 这档能配出来的重量，比 28kg 这种数字实用。
    private static func near(_ weight: Double) -> Double {
        (weight / plateStep).rounded() * plateStep
    }
}
