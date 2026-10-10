import Foundation
import Testing

@testable import Replo

@Suite("WOD 自建草稿")
struct WodDraftTests {
    private func filledDraft() -> WodDraft {
        var draft = WodDraft()
        draft.name = "WOD 9"
        var station = StationDraft()
        station.title = "壶铃摆动"
        station.repsText = "10"
        draft.stations = [station]
        return draft
    }

    @Test("默认草稿不通过：站点空、名称空")
    func emptyDraftFails() {
        let reasons = WodDraft().failureReasons
        #expect(reasons.contains("名称不能为空"))
        #expect(reasons.contains("站点名称不能为空"))
    }

    @Test("补全名称与站点后通过")
    func filledDraftPasses() {
        #expect(filledDraft().failureReasons.isEmpty)
    }

    @Test("无站点、空名称、站点无数值、For Time 零轮各自报错")
    func eachViolationReported() {
        var noStation = filledDraft()
        noStation.stations = []
        #expect(noStation.failureReasons.contains("至少添加一个站点"))

        var noValue = filledDraft()
        noValue.stations[0].repsText = ""
        #expect(noValue.failureReasons.contains("「次数」需为正整数"))

        var noRounds = filledDraft()
        noRounds.format = .forTime
        noRounds.rounds = 0
        #expect(noRounds.failureReasons.contains("For Time 至少 1 轮"))
    }

    @Test("makeWod 字段映射正确且标记为自建")
    func makeWodMapsFields() {
        var draft = filledDraft()
        draft.format = .forTime
        draft.capMinutes = 15
        draft.rounds = 3

        let wod = draft.makeWod()
        #expect(wod.name == "WOD 9")
        #expect(wod.format == .forTime)
        #expect(wod.timeCapSeconds == 900)
        #expect(wod.rounds == 3)
        #expect(wod.stations.map(\.summary) == ["壶铃摆动 × 10"])
        #expect(wod.isCustom)
    }

    @Test("非 For Time 不存轮数；非 EMOM 不存奇偶分钟")
    func formatSpecificFieldsDropped() {
        var draft = filledDraft()
        draft.stations[0].parity = .even

        let amrap = draft.makeWod()
        #expect(amrap.rounds == nil)
        #expect(amrap.stations[0].parity == nil)

        draft.format = .emom
        let emom = draft.makeWod()
        #expect(emom.stations[0].parity == .even)
    }

    @Test("applyTo 写回字段，不动 id 与 isCustom")
    func applyToWritesBack() {
        let original = Wod(
            name: "内置",
            format: .amrap,
            timeCapSeconds: 600,
            stations: [Station(title: "俯卧撑", reps: 10)]
        )
        let originalId = original.id
        var draft = WodDraft(wod: original)
        draft.name = "改名"
        draft.capMinutes = 8

        draft.applyTo(original)
        #expect(original.name == "改名")
        #expect(original.timeCapSeconds == 480)
        #expect(original.id == originalId)
        #expect(original.isCustom == false)
    }

    @Test("从现有 Wod 拷草稿：次数/秒数与轮数还原")
    func draftFromWod() {
        let wod = Wod(
            name: "WOD 3 · For Time 15",
            format: .forTime,
            timeCapSeconds: 900,
            rounds: 5,
            stations: [
                Station(title: "壶铃摆动", reps: 10),
                Station(title: "战绳", durationSeconds: 20),
            ]
        )
        let draft = WodDraft(wod: wod)
        #expect(draft.capMinutes == 15)
        #expect(draft.rounds == 5)
        #expect(draft.stations[0].kind == .reps && draft.stations[0].repsText == "10")
        #expect(draft.stations[1].kind == .seconds && draft.stations[1].secondsText == "20")
        #expect(draft.failureReasons.isEmpty)
    }

    @Test("追加站点的奇偶分钟按序交替")
    func appendedParityAlternates() {
        var draft = WodDraft()
        draft.stations = []
        draft.appendStation()
        draft.appendStation()
        draft.appendStation()
        #expect(draft.stations.map(\.parity) == [.odd, .even, .odd])
    }
}
