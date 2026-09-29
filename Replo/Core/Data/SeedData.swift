import Foundation
import SwiftData

/// 动作定义的种子行。名字是全 App 的连接键：重量表、WOD 手册、警示区都按它对。
struct MovementSeed {
    var name: String
    var category: MovementCategory
    var pattern: DayPattern
}

/// 一次装配出的全套种子：动作先建，模板与 WOD 再引用它们的 id。
struct SeedBundle {
    var movements: [Movement] = []
    var templates: [PlanTemplate] = []
    var wods: [Wod] = []
    var activePlan: ActivePlan?

    var models: [any PersistentModel] {
        let flat = movements.map { $0 as any PersistentModel }
        let withTemplates = flat + templates.map { $0 as any PersistentModel }
        let withWods = withTemplates + wods.map { $0 as any PersistentModel }
        return withWods + (activePlan.map { [$0] } ?? [])
    }
}

/// 全部种子数据（规格 4、附录 A/B）。模板与重量表以动作名做连接键。
enum SeedData {
    static let fourWeekTemplateName = "4周重建 v2"
    static let standingTemplateName = "AB 常模"

    static func make() -> SeedBundle {
        let movements = makeMovements()
        let ids = Dictionary(uniqueKeysWithValues: movements.map { ($0.name, $0.id) })
        let fourWeek = makeTemplate(name: fourWeekTemplateName, table: SeedWeightTable.fourWeek, ids: ids)
        let standing = makeTemplate(name: standingTemplateName, table: SeedWeightTable.standing, ids: ids)
        return SeedBundle(
            movements: movements,
            templates: [fourWeek, standing],
            wods: SeedWods.make(),
            activePlan: ActivePlan(templateId: fourWeek.id, currentWeekIndex: 0)
        )
    }

    /// 动作定义的声明式出处。引擎按名字查类别与警示区，模板按名字连 id，
    /// 所以这张表是动作名 → 类别 / 归属日的唯一真源。
    static let movements: [MovementSeed] = [
        MovementSeed(name: "深蹲", category: .lower, pattern: .dayB),
        MovementSeed(name: "硬拉", category: .lower, pattern: .dayB),
        MovementSeed(name: "前蹲", category: .lower, pattern: .dayA),
        MovementSeed(name: "卧推", category: .upper, pattern: .dayA),
        MovementSeed(name: "杠铃划船", category: .upper, pattern: .dayA),
        MovementSeed(name: "推举", category: .upper, pattern: .dayB),
    ]

    /// 动作定义。类别决定加重步长，归属决定它出现在 A 日还是 B 日。
    static func makeMovements() -> [Movement] {
        movements.map { Movement(name: $0.name, category: $0.category, pattern: $0.pattern) }
    }

    /// 把重量表按周次合并成模板：一周里的 A 日、B 日动作都在同一个 `PlanWeek` 下，
    /// 走哪一天由 `Movement.pattern` 决定，模板本身不再记一遍课型。
    private static func makeTemplate(
        name: String,
        table: [SeedWeek],
        ids: [String: UUID]
    ) -> PlanTemplate {
        let weekIndexes = Array(Set(table.map(\.weekIndex))).sorted()
        let weeks = weekIndexes.map { index in
            PlanWeek(weekIndex: index, movements: assignments(ofWeek: index, in: table, ids: ids))
        }
        return PlanTemplate(name: name, weeks: weeks)
    }

    private static func assignments(
        ofWeek index: Int,
        in table: [SeedWeek],
        ids: [String: UUID]
    ) -> [MovementAssignment] {
        table.filter { $0.weekIndex == index }
            .flatMap(\.rows)
            .compactMap { row in
                guard let movementId = ids[row.movementName] else { return nil }
                return MovementAssignment(
                    movementId: movementId,
                    weight: row.weight,
                    sets: row.sets,
                    reps: row.reps
                )
            }
    }
}
