import Testing

@testable import Replo

@Suite("WOD 动作池")
struct WodMovementPoolTests {
    @Test("手册动作池：四类 8 个动作")
    func poolMatchesManual() {
        #expect(WodMovementPool.movements.count == 8)
        #expect(WodMovementPool.movements(in: .hinge).map(\.name) == ["壶铃摆动"])
        #expect(WodMovementPool.movements(in: .push).map(\.name) == ["俯卧撑", "单臂壶铃推举"])
        #expect(WodMovementPool.movements(in: .squat).map(\.name) == ["高脚杯深蹲", "自重深蹲"])
        #expect(WodMovementPool.movements(in: .conditioning).map(\.name) == ["战绳", "登山跑", "平板支撑"])
    }

    @Test("TABATA 默认动作是战绳，成绩 id 是固定值")
    func tabataDefaults() {
        #expect(WodMovementPool.defaultTabataMovement == "战绳")
        #expect(WodMovementPool.tabataWodID.uuidString == "AAAAAAAA-0000-0000-0000-000000000001")
    }
}
