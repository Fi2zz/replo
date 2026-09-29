import Foundation

/// 每周节律：周一 B / 周二低强度有氧 / 周三高强度有氧 / 周四全休 / 周五 A /
/// 周六低强度有氧 / 周日全休（附录 A 周节律）。
enum WeekRhythm {
    /// `Calendar.component(.weekday:)` 的口径：1=周日 … 7=周六。
    static func dayType(weekday: Int) -> DayType {
        switch weekday {
        case 2: .dayB
        case 3: .cardio
        case 4: .wod
        case 6: .dayA
        case 7: .cardio
        default: .rest
        }
    }
}

/// 把库里的计划数据摊平成「今天这一堂课」。UI 与测试都从这里拿当日清单，
/// 不各自去 join ActivePlan / PlanTemplate / Movement。
struct PlanContext {
    var activePlan: ActivePlan?
    var templates: [PlanTemplate]
    var movements: [Movement]
    var calendar: Calendar = .current

    func plan(on date: Date) -> TodayPlan {
        let weekIndex = activePlan?.currentWeekIndex ?? 0
        let dayType = WeekRhythm.dayType(weekday: calendar.component(.weekday, from: date))
        return TodayPlan(
            date: date,
            dayType: dayType,
            weekIndex: weekIndex,
            movements: plannedMovements(for: dayType, weekIndex: weekIndex)
        )
    }

    /// 当前模板是否还有下一周。
    var hasNextWeek: Bool {
        guard let plan = activePlan, let template = template else { return false }
        return template.weeks.contains { $0.weekIndex == plan.currentWeekIndex + 1 }
    }

    private var template: PlanTemplate? {
        guard let id = activePlan?.templateId else { return nil }
        return templates.first { $0.id == id }
    }

    private func plannedMovements(for dayType: DayType, weekIndex: Int) -> [PlannedMovement] {
        guard let pattern = dayType.pattern else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: movements.map { ($0.id, $0) })
        let assignments = template?.week(weekIndex).movements ?? []
        return assignments.compactMap { assignment in
            guard let movement = byID[assignment.movementId], movement.pattern == pattern else {
                return nil
            }
            return PlannedMovement(
                movement: movement,
                weight: assignment.weight,
                sets: assignment.sets,
                reps: assignment.reps
            )
        }
    }
}
