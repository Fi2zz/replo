import Foundation
import SwiftData
import Testing

@testable import Replo

@MainActor
@Suite(.serialized)
struct SeedDataTests {
    @Test("首次导入后动作 6、模板 2、WOD 8、激活计划 1")
    func importProducesFullSeed() throws {
        let context = try TestStore.seededContext()

        #expect(try context.fetchCount(FetchDescriptor<Movement>()) == 6)
        #expect(try context.fetchCount(FetchDescriptor<PlanTemplate>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Wod>()) == 8)
        #expect(try context.fetchCount(FetchDescriptor<ActivePlan>()) == 1)
    }

    @Test("重复导入不产生第二份种子")
    func importIsIdempotent() throws {
        let context = try TestStore.seededContext()
        try SeedImporter.applyOnce(to: context)
        try SeedImporter.applyOnce(to: context)

        #expect(try context.fetchCount(FetchDescriptor<Movement>()) == 6)
        #expect(try context.fetchCount(FetchDescriptor<Wod>()) == 8)
    }

    @Test("四周表每周六条动作，A/B 日各三条")
    func fourWeekHoldsBothDays() throws {
        let context = try TestStore.seededContext()
        let template = try fourWeekTemplate(in: context)
        let movements = try context.fetch(FetchDescriptor<Movement>())
        let byID = Dictionary(uniqueKeysWithValues: movements.map { ($0.id, $0) })

        #expect(template.weeks.count == 4)
        for week in template.weeks {
            #expect(week.movements.count == 6)
            #expect(week.movements.filter { byID[$0.movementId]?.pattern == .dayA }.count == 3)
            #expect(week.movements.filter { byID[$0.movementId]?.pattern == .dayB }.count == 3)
        }
    }

    @Test("四周重量表与附录 A 原文一致（周次从 0 数）")
    func fourWeekTableMatchesAppendixA() throws {
        let context = try TestStore.seededContext()
        let template = try fourWeekTemplate(in: context)
        let ids = try movementIDs(in: context)

        #expect(try weight(template, ids, week: 0, "深蹲") == 80)
        #expect(try sets(template, ids, week: 0, "深蹲") == 3)
        #expect(try reps(template, ids, week: 0, "硬拉") == 3)
        #expect(try weight(template, ids, week: 1, "前蹲") == 45)
        #expect(try sets(template, ids, week: 1, "前蹲") == 3)
        #expect(try reps(template, ids, week: 1, "前蹲") == 5)
        #expect(try weight(template, ids, week: 2, "硬拉") == 100)
        #expect(try weight(template, ids, week: 3, "硬拉") == 105)
        #expect(try weight(template, ids, week: 3, "推举") == 35)
    }

    @Test("AB 常模是单周模板，前蹲维持 3×5")
    func standingTemplateShape() throws {
        let context = try TestStore.seededContext()
        let ids = try movementIDs(in: context)
        let template = try #require(
            try context.fetch(FetchDescriptor<PlanTemplate>())
                .first { $0.name == SeedData.standingTemplateName }
        )

        #expect(template.weeks.count == 1)
        #expect(template.weeks.allSatisfy { $0.weekIndex == 0 })
        #expect(template.weeks.first?.movements.count == 6)
        #expect(try sets(template, ids, week: 0, "前蹲") == 3)
        #expect(try reps(template, ids, week: 0, "硬拉") == 3)
    }

    @Test("激活计划指向四周重建的第 1 周")
    func activePlanPointsAtFourWeek() throws {
        let context = try TestStore.seededContext()
        let template = try fourWeekTemplate(in: context)
        let plan = try #require(try context.fetch(FetchDescriptor<ActivePlan>()).first)

        #expect(plan.templateId == template.id)
        #expect(plan.currentWeekIndex == 0)
        #expect(plan.active)
    }

    @Test("WOD 种子覆盖四种格式，EMOM 带奇偶分钟")
    func wodSeedsCoverFormats() throws {
        let context = try TestStore.seededContext()
        let wods = try context.fetch(FetchDescriptor<Wod>())

        #expect(Set(wods.map(\.format)) == Set(WodFormat.allCases))
        let emom = try #require(wods.first { $0.format == .emom })
        #expect(emom.stations.allSatisfy { $0.parity != nil })
        let forTime = try #require(wods.first { $0.format == .forTime })
        #expect(forTime.rounds != nil)
    }

    @Test("枚举与值类型经存储往返不丢")
    func valuesSurviveRoundTrip() throws {
        let context = try TestStore.seededContext()
        let squat = try #require(
            try context.fetch(FetchDescriptor<Movement>()).first { $0.name == "深蹲" }
        )
        let wod = try #require(try context.fetch(FetchDescriptor<Wod>()).first)

        #expect(squat.category == .lower)
        #expect(squat.pattern == .dayB)
        #expect(wod.timeCapSeconds > 0)
        #expect(wod.stations.isEmpty == false)
        #expect(wod.stations.allSatisfy { !$0.summary.isEmpty })
    }

    private func fourWeekTemplate(in context: ModelContext) throws -> PlanTemplate {
        try #require(
            try context.fetch(FetchDescriptor<PlanTemplate>())
                .first { $0.name == SeedData.fourWeekTemplateName }
        )
    }

    private func movementIDs(in context: ModelContext) throws -> [String: UUID] {
        let movements = try context.fetch(FetchDescriptor<Movement>())
        return Dictionary(uniqueKeysWithValues: movements.map { ($0.name, $0.id) })
    }

    private func assignment(
        _ template: PlanTemplate,
        _ ids: [String: UUID],
        week index: Int,
        _ name: String
    ) throws -> MovementAssignment {
        let movementId = try #require(ids[name])
        return try #require(template.week(index).movements.first { $0.movementId == movementId })
    }

    private func weight(
        _ template: PlanTemplate,
        _ ids: [String: UUID],
        week index: Int,
        _ name: String
    ) throws -> Double {
        try assignment(template, ids, week: index, name).weight
    }

    private func sets(
        _ template: PlanTemplate,
        _ ids: [String: UUID],
        week index: Int,
        _ name: String
    ) throws -> Int {
        try assignment(template, ids, week: index, name).sets
    }

    private func reps(
        _ template: PlanTemplate,
        _ ids: [String: UUID],
        week index: Int,
        _ name: String
    ) throws -> Int {
        try assignment(template, ids, week: index, name).reps
    }
}
