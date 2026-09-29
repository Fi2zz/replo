import Foundation

/// 重量表里的一格：动作名 + 重量 + 组次。
struct SeedRow {
    var movementName: String
    var weight: Double
    var sets: Int
    var reps: Int
}

/// 重量表的一周：周次 + 该周的动作格（A 日的三条在前，B 日的三条在后）。
/// 每格归哪个训练日不在表里重复记，由 `Movement.pattern` 唯一决定。
/// 周次从 0 数起，和 `ActivePlan.currentWeekIndex` 对齐，界面上显示第 N+1 周。
struct SeedWeek {
    var weekIndex: Int
    var rows: [SeedRow]
}

/// 附录 A 的重量表。组数取自附录 C 的《练啥_完整训练与减脂计划_v1》逐周原文：
/// 前蹲全程 3×5（动作说明文档与 AB 常模都这么定），卧推/划船 3→4→5 组递增，推举 3→4→5 组。
enum SeedWeightTable {
    static let fourWeek: [SeedWeek] = [
        SeedWeek(weekIndex: 0, rows: [
            SeedRow(movementName: "卧推", weight: 40, sets: 3, reps: 5),
            SeedRow(movementName: "杠铃划船", weight: 40, sets: 3, reps: 5),
            SeedRow(movementName: "前蹲", weight: 40, sets: 3, reps: 5),
        ]),
        SeedWeek(weekIndex: 0, rows: [
            SeedRow(movementName: "深蹲", weight: 80, sets: 3, reps: 3),
            SeedRow(movementName: "推举", weight: 30, sets: 3, reps: 5),
            SeedRow(movementName: "硬拉", weight: 90, sets: 1, reps: 3),
        ]),
        SeedWeek(weekIndex: 1, rows: [
            SeedRow(movementName: "卧推", weight: 42.5, sets: 4, reps: 5),
            SeedRow(movementName: "杠铃划船", weight: 45, sets: 4, reps: 5),
            SeedRow(movementName: "前蹲", weight: 45, sets: 3, reps: 5),
        ]),
        SeedWeek(weekIndex: 1, rows: [
            SeedRow(movementName: "深蹲", weight: 85, sets: 3, reps: 3),
            SeedRow(movementName: "推举", weight: 30, sets: 4, reps: 5),
            SeedRow(movementName: "硬拉", weight: 100, sets: 1, reps: 3),
        ]),
        SeedWeek(weekIndex: 2, rows: [
            SeedRow(movementName: "卧推", weight: 45, sets: 5, reps: 5),
            SeedRow(movementName: "杠铃划船", weight: 50, sets: 5, reps: 5),
            SeedRow(movementName: "前蹲", weight: 50, sets: 3, reps: 5),
        ]),
        SeedWeek(weekIndex: 2, rows: [
            SeedRow(movementName: "深蹲", weight: 90, sets: 3, reps: 3),
            SeedRow(movementName: "推举", weight: 32.5, sets: 5, reps: 5),
            SeedRow(movementName: "硬拉", weight: 100, sets: 1, reps: 3),
        ]),
        SeedWeek(weekIndex: 3, rows: [
            SeedRow(movementName: "卧推", weight: 47.5, sets: 5, reps: 5),
            SeedRow(movementName: "杠铃划船", weight: 55, sets: 5, reps: 5),
            SeedRow(movementName: "前蹲", weight: 55, sets: 3, reps: 5),
        ]),
        SeedWeek(weekIndex: 3, rows: [
            SeedRow(movementName: "深蹲", weight: 95, sets: 3, reps: 3),
            SeedRow(movementName: "推举", weight: 35, sets: 5, reps: 5),
            SeedRow(movementName: "硬拉", weight: 105, sets: 1, reps: 3),
        ]),
    ]

    /// AB 常模。规格写明「起始重量取收官时决策值」，种子先落第 4 周的值占位，
    /// 10/19 收官后由 WeightDecision 的 nextWeight 覆盖。
    static let standing: [SeedWeek] = [
        SeedWeek(weekIndex: 0, rows: [
            SeedRow(movementName: "卧推", weight: 47.5, sets: 5, reps: 5),
            SeedRow(movementName: "杠铃划船", weight: 55, sets: 5, reps: 5),
            SeedRow(movementName: "前蹲", weight: 55, sets: 3, reps: 5),
        ]),
        SeedWeek(weekIndex: 0, rows: [
            SeedRow(movementName: "深蹲", weight: 95, sets: 3, reps: 3),
            SeedRow(movementName: "推举", weight: 35, sets: 5, reps: 5),
            SeedRow(movementName: "硬拉", weight: 105, sets: 1, reps: 3),
        ]),
    ]
}
