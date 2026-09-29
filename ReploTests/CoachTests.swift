import Foundation
import SwiftData
import Testing

@testable import Replo

@Suite("教练 prompt 与上下文")
struct CoachPromptTests {
    @Test("system 里带角色设定和三份文档全文")
    func systemCarriesRoleAndDocuments() {
        let system = CoachPrompt.system

        #expect(system.contains("你是 Replo 的教练"))
        #expect(system.contains("不超过 150 字"))
        #expect(system.contains("练啥 · 完整训练与减脂计划"))
        #expect(system.contains("练啥 · WOD 训练手册"))
        #expect(system.contains("动作说明文档"))
    }

    @Test("三份文档的关键规则确实在 prompt 里")
    func documentsKeepTheRules() {
        let text = CoachDocuments.all

        #expect(text.contains("下肢（深蹲/硬拉）每周最多 +5kg"))
        #expect(text.contains("警示区"))
        #expect(text.contains("壶铃摆动 ≤100 次"))
        #expect(text.contains("【前蹲 · A日 3×5】"))
    }

    @Test("文档拼起来没有多余空行，标题紧跟内容")
    func documentsAreTrimmed() {
        for document in [CoachDocuments.plan, CoachDocuments.wod, CoachDocuments.movement] {
            #expect(document.first != "\n")
        }
    }

    @Test("上下文前缀带周次、今天和最近 7 天的记录")
    func contextPrefixLayout() throws {
        let context = CoachContext(
            weekIndex: 1,
            templateName: "4周重建 v2",
            recentSessions: [
                CoachContext.SessionSummary(
                    date: try #require(date(2026, 9, 21)),
                    dayType: .dayB,
                    lines: ["- 深蹲：完成 3/3 组，末组 3 次，RIR 2，RPE 8 → 下次 85kg（通过，+5）"]
                ),
            ],
            todayNote: "2026年9月22日 星期二 · 低强度有氧｜坡度走"
        )

        let prefix = context.prefix

        #expect(prefix.contains("【当前计划】4周重建 v2 第 2 周"))
        #expect(prefix.contains("【今天】"))
        #expect(prefix.contains("【最近 7 天训练记录】"))
        #expect(prefix.contains("9月21日 星期一 · B 日"))
        #expect(prefix.contains("下次 85kg（通过，+5）"))
    }

    @Test("没有记录时明说没有，不留空段")
    func contextWithoutSessions() {
        let context = CoachContext(
            weekIndex: 0,
            templateName: "4周重建 v2",
            recentSessions: [],
            todayNote: "今天"
        )

        #expect(context.prefix.contains("这 7 天没有训练记录"))
    }

    @Test("周次显示成第 N+1 周，存储是 0 起")
    func weekIndexIsOneBasedForDisplay() {
        let context = CoachContext(weekIndex: 3, templateName: "AB 常模", recentSessions: [], todayNote: "")

        #expect(context.prefix.contains("第 4 周"))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))
    }
}

@MainActor
@Suite(.serialized)
struct CoachContextBuilderTests {
    @Test("最近 7 天的记录带上动作、组数、余力与决策")
    func builderJoinsLogsAndDecisions() throws {
        let harness = try CoachHarness()
        let deepSquat = try #require(harness.movements.first { $0.name == "深蹲" })
        let day = harness.date(2026, 9, 21)

        let log = SessionLog(
            date: day,
            dayType: .dayB,
            entries: [
                SetEntry(
                    movementId: deepSquat.id,
                    plannedSets: 3, plannedReps: 3, completedSets: 3, lastSetReps: 3,
                    rir: 2, discomfort: false, rpe: 8
                ),
            ]
        )
        harness.context.insert(log)
        let decision = WeightDecision(
            sessionLogId: log.id,
            date: day,
            movementId: deepSquat.id,
            currentWeight: 80,
            nextWeight: 85,
            action: .add,
            reasons: ["通过，+5"]
        )
        harness.context.insert(decision)
        try harness.context.save()

        let summaries = CoachContextBuilder.recent(
            logs: [log],
            decisions: [decision],
            movements: harness.movements,
            today: harness.date(2026, 9, 22)
        )
        let line = try #require(summaries.first?.lines.first)

        #expect(summaries.count == 1)
        #expect(summaries.first?.dayType == .dayB)
        #expect(line.contains("深蹲"))
        #expect(line.contains("完成 3/3 组，末组 3 次"))
        #expect(line.contains("RIR 2，RPE 8"))
        #expect(line.contains("下次 85kg（通过，+5）"))
    }

    @Test("7 天之外的记录不进上下文")
    func builderDropsOldSessions() throws {
        let harness = try CoachHarness()
        let old = SessionLog(date: harness.date(2026, 9, 1), dayType: .dayB)
        harness.context.insert(old)
        try harness.context.save()

        let summaries = CoachContextBuilder.recent(
            logs: [old],
            decisions: [],
            movements: harness.movements,
            today: harness.date(2026, 9, 22)
        )

        #expect(summaries.isEmpty)
    }

    @Test("没有决策时只报完成度，不编下次重量")
    func builderWithoutDecisions() throws {
        let harness = try CoachHarness()
        let deepSquat = try #require(harness.movements.first { $0.name == "深蹲" })
        let log = SessionLog(
            date: harness.date(2026, 9, 21),
            dayType: .dayB,
            entries: [SetEntry(movementId: deepSquat.id, plannedSets: 3, plannedReps: 3, completedSets: 2)]
        )
        harness.context.insert(log)
        try harness.context.save()

        let line = try #require(CoachContextBuilder.recent(
            logs: [log], decisions: [], movements: harness.movements, today: harness.date(2026, 9, 22)
        ).first?.lines.first)

        #expect(line.contains("完成 2/3 组"))
        #expect(line.contains("下次") == false)
    }

    @Test("make 组出完整上下文：周次、模板名、今天安排")
    func makeAssemblesFullContext() throws {
        let harness = try CoachHarness()
        let context = CoachContextBuilder.make(
            logs: [],
            decisions: [],
            movements: harness.movements,
            activePlan: harness.activePlan,
            templates: harness.templates,
            today: harness.date(2026, 9, 21)
        )

        #expect(context.templateName == SeedData.fourWeekTemplateName)
        #expect(context.weekIndex == 0)
        #expect(context.prefix.contains("第 1 周"))
        #expect(context.todayNote.contains("B 日"))
    }
}

/// 真库 + 固定日期，跨 actor 的取数都走它。
@MainActor
private struct CoachHarness {
    let context: ModelContext
    let movements: [Movement]
    let templates: [PlanTemplate]
    let activePlan: ActivePlan

    init() throws {
        let context = try TestStore.seededContext()
        self.context = context
        self.movements = try context.fetch(FetchDescriptor<Movement>())
        self.templates = try context.fetch(FetchDescriptor<PlanTemplate>())
        self.activePlan = try #require(try context.fetch(FetchDescriptor<ActivePlan>()).first)
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? Date()
    }
}
