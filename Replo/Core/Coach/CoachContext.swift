import Foundation

/// 每次提问前拼在 user message 前缀里的训练上下文（规格 8）：
/// 最近 7 天的 SessionLog 与对应决策，外加当前计划周次。
///
/// 纯函数，不查库：调用方把数据取过来，这里只负责排版。教练只能看到这里的东西，
/// 所以宁可多给也不要漏——它不知道 App 里还有什么。
struct CoachContext: Equatable {
    var weekIndex: Int
    var templateName: String
    /// 最近 7 天的训练课，从早到晚。
    var recentSessions: [SessionSummary]
    /// 今天该练什么，一句话。
    var todayNote: String

    struct SessionSummary: Equatable {
        var date: Date
        var dayType: DayType
        var lines: [String]
    }

    /// 拼成发出去的前缀。
    var prefix: String {
        var lines: [String] = []
        lines.append("【当前计划】\(templateName) 第 \(weekIndex + 1) 周")
        lines.append("【今天】\(todayNote)")
        lines.append("【最近 7 天训练记录】")
        lines.append(contentsOf: recentSessions.map(summaryText))
        if recentSessions.isEmpty {
            lines.append("（这 7 天没有训练记录）")
        }
        return lines.joined(separator: "\n")
    }

    private func summaryText(_ session: SessionSummary) -> String {
        let date = DateFormat.monthDayText(session.date)
        let head = "\(date) \(DateFormat.weekdayText(session.date)) · \(session.dayType.title)"
        return ([head] + session.lines).joined(separator: "\n")
    }
}

/// 从库里取数、组装 `CoachContext`。这是唯一碰 SwiftData 的地方。
@MainActor
enum CoachContextBuilder {
    /// 组一份完整的上下文：当前周次 + 今天 + 最近 7 天。
    static func make(
        logs: [SessionLog],
        decisions: [WeightDecision],
        movements: [Movement],
        activePlan: ActivePlan?,
        templates: [PlanTemplate],
        today: Date
    ) -> CoachContext {
        let planContext = PlanContext(activePlan: activePlan, templates: templates, movements: movements)
        let today_ = planContext.plan(on: today)
        return CoachContext(
            weekIndex: today_.weekIndex,
            templateName: templateName(activePlan: activePlan, templates: templates),
            recentSessions: recent(logs: logs, decisions: decisions, movements: movements, today: today),
            todayNote: "\(DateFormat.monthDayText(today)) \(DateFormat.weekdayText(today)) · \(today_.title)｜\(today_.note)"
        )
    }

    private static func templateName(activePlan: ActivePlan?, templates: [PlanTemplate]) -> String {
        guard let id = activePlan?.templateId else { return "未选择计划" }
        return templates.first { $0.id == id }?.name ?? "计划已丢失"
    }

    /// 最近 7 天的训练课（含今天）。决策按 sessionLogId 对上，缺了就只报完成度。
    static func recent(
        logs: [SessionLog],
        decisions: [WeightDecision],
        movements: [Movement],
        today: Date
    ) -> [CoachContext.SessionSummary] {
        let window = today.addingTimeInterval(-7 * 86_400)
        let byLog = Dictionary(grouping: decisions, by: \.sessionLogId)
        let names = Dictionary(uniqueKeysWithValues: movements.map { ($0.id, $0.name) })

        return logs
            .filter { $0.date >= window && $0.date <= today }
            .sorted { $0.date < $1.date }
            .map { log in
                CoachContext.SessionSummary(
                    date: log.date,
                    dayType: log.dayType,
                    lines: log.entries.map { line(for: $0, names: names, decisions: byLog[log.id] ?? []) }
                )
            }
    }

    private static func line(
        for entry: SetEntry,
        names: [UUID: String],
        decisions: [WeightDecision]
    ) -> String {
        let name = names[entry.movementId] ?? "动作"
        let done = "完成 \(entry.completedSets)/\(entry.plannedSets) 组，末组 \(entry.lastSetReps) 次"
        let feel = "RIR \(entry.rir)，RPE \(entry.rpe)\(entry.discomfort ? "，有不适" : "")"
        guard let decision = decisions.first(where: { $0.movementId == entry.movementId }) else {
            return "- \(name)：\(done)，\(feel)"
        }
        let why = decision.reasons.joined(separator: "；")
        return "- \(name)：\(done)，\(feel) → 下次 \(WeightFormat.text(decision.nextWeight))kg（\(why)）"
    }
}
