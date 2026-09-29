import Foundation
import SwiftData

/// 计划模板里的一条动作分配。用值类型而非关系，避开 CloudKit 的反向关系约束（模块 7）。
struct MovementAssignment: Codable, Equatable {
    var movementId: UUID = UUID()
    var weight: Double = 0
    var sets: Int = 0
    var reps: Int = 0
}

/// 模板的一周。
struct PlanWeek: Codable, Equatable {
    var weekIndex: Int = 0
    var movements: [MovementAssignment] = []
}

/// 计划模板。种子数据，只读（规格 4.2）。
@Model
final class PlanTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var weeks: [PlanWeek] = []

    init(id: UUID = UUID(), name: String, weeks: [PlanWeek]) {
        self.id = id
        self.name = name
        self.weeks = weeks
    }

    /// 指定周次的动作分配（该周 A 日与 B 日的动作都在里面）；周次越界返回空周而不是崩。
    func week(_ index: Int) -> PlanWeek {
        weeks.first { $0.weekIndex == index } ?? PlanWeek()
    }
}

/// 当前激活计划，单例（规格 4.3）。
@Model
final class ActivePlan {
    var id: UUID = UUID()
    var templateId: UUID = UUID()
    var currentWeekIndex: Int = 0
    var active: Bool = true

    init(id: UUID = UUID(), templateId: UUID, currentWeekIndex: Int = 0, active: Bool = true) {
        self.id = id
        self.templateId = templateId
        self.currentWeekIndex = currentWeekIndex
        self.active = active
    }
}
