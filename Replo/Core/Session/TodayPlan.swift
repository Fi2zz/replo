import Foundation

/// 今日课程里的一条动作。字段是纯值拷贝，不持有 `@Model Movement`：
/// 草稿要能 Equatable、能进 `Sendable` 上下文，也不用为了比一下就回主线程查库。
struct PlannedMovement: Identifiable, Equatable, Sendable {
    var movementId: UUID
    var name: String
    var category: MovementCategory
    var pattern: DayPattern
    var weight: Double
    var sets: Int
    var reps: Int

    var id: UUID { movementId }

    /// 引擎要的形状。
    var spec: MovementSpec {
        MovementSpec(name: name, category: category, pattern: pattern)
    }

    init(movement: Movement, weight: Double, sets: Int, reps: Int) {
        self.movementId = movement.id
        self.name = movement.name
        self.category = movement.category
        self.pattern = movement.pattern
        self.weight = weight
        self.sets = sets
        self.reps = reps
    }

    /// 「卧推 42.5kg 4×5」这样的课表文案。
    var summary: String { "\(name) \(weightText)kg \(sets)×\(reps)" }

    var weightText: String { WeightFormat.text(weight) }
}

/// 今天该练什么：周节律定课型，课型 + 当前周次定动作清单（规格 7、附录 A 周节律）。
struct TodayPlan: Equatable {
    var date: Date
    var dayType: DayType
    var weekIndex: Int
    /// 力量课才有动作；其余课型是空数组，文案看 `dayType.note`。
    var movements: [PlannedMovement]

    var isStrength: Bool { dayType.isStrength }
    var title: String { dayType.isStrength ? "\(dayType.title) · 第 \(weekIndex + 1) 周" : dayType.title }
    var note: String { dayType.note }
}

extension DayType {
    /// 力量课才走「动作 + 重量 + 组次」这条路。
    var isStrength: Bool { self == .dayA || self == .dayB }

    /// 力量课对应哪一组动作；其余课型没有对应动作。
    var pattern: DayPattern? {
        switch self {
        case .dayA: .dayA
        case .dayB: .dayB
        case .wod, .cardio, .rest: nil
        }
    }

    /// 计划文档里对这堂课的固定交代，直接当今日文案用。
    var note: String {
        switch self {
        case .dayA, .dayB: "主课。课后不加体能，保恢复；加重留 2 次余力，腰膝无不适才加。"
        case .cardio: "低强度有氧：坡度走 30 分钟或轻松骑行，RPE 4-5。"
        case .wod: "高强度有氧：TABATA 或 WOD 二选一，RPE 8.5 封顶，每周最多一次。"
        case .rest: "全休。缓冲带，不可挪用。"
        }
    }
}
