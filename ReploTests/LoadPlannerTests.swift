import Foundation
import Testing

@testable import Replo

/// 配重可行性。验收表第 12 条按真实器材清单核对，见 `smallPlates` 用例的注释。
@Suite("LoadPlanner")
struct LoadPlannerTests {
    /// 9/28 当时的器材：还没有 1.25/2.5kg 小片，95 真的配不出来，所以当周手动改成 100。
    private let platesWithoutChange = [25.0, 15.0, 10.0, 5.0]
    private let platesWithChange = [25.0, 15.0, 10.0, 5.0, 2.5]

    @Test("真实案例：没有小片时 95 配不出、100 配得出")
    func realWorldCase() {
        #expect(LoadPlanner.canLoad(95, plates: platesWithoutChange, barWeight: 20) == false)
        #expect(LoadPlanner.canLoad(100, plates: platesWithoutChange, barWeight: 20) == true)
    }

    @Test("验收表第 12 条按原样核对：给到 2.5kg 片时 95 其实配得出来")
    func acceptanceCaseAsWritten() {
        // 委托提示词写的是 canLoad(95, plates=[25,15,10,5,2.5], bar=20) → false，
        // 但 25+10+2.5 = 37.5 每侧，95 = 20 + 2×37.5 配得出来。真实卡住 95 的是器材清单，
        // 不是算法，所以这里按真实清单断言，结论与验收表一致。
        #expect(LoadPlanner.canLoad(95, plates: platesWithChange, barWeight: 20) == true)
        #expect(LoadPlanner.canLoad(100, plates: platesWithChange, barWeight: 20) == true)
    }

    @Test("计划里的目标重量都配得出来")
    func planTargetsAreLoadable() {
        let targets: [Double] = [40, 42.5, 45, 47.5, 50, 55, 80, 85, 90, 95, 100, 105]

        for target in targets {
            #expect(LoadPlanner.canLoad(target), "\(target)kg 应当配得出来")
        }
    }

    @Test("比杠铃还轻配不出来")
    func belowBarIsNotLoadable() {
        #expect(LoadPlanner.canLoad(15) == false)
        #expect(LoadPlanner.canLoad(20) == true)
    }

    @Test("只有 20kg 一片时只能配 20 与 60")
    func singlePlateSize() {
        #expect(LoadPlanner.canLoad(20, plates: [20], barWeight: 20) == true)
        #expect(LoadPlanner.canLoad(60, plates: [20], barWeight: 20) == true)
        #expect(LoadPlanner.canLoad(50, plates: [20], barWeight: 20) == false)
    }

    @Test("最近可配重量只往上看：95 找 100，不退回 90")
    func nearestSearchesUpwardOnly() {
        #expect(LoadPlanner.nearestLoadable(95, plates: platesWithoutChange, barWeight: 20) == 100)
        #expect(LoadPlanner.nearestLoadable(93, plates: platesWithoutChange, barWeight: 20) == 100)
        // 返回的是「换上去」的下一个重量，不含原重量本身：
        // 有 1.25kg 小片，100 之后最近的是 102.5 = 20 + 2×(25+15+1.25)。
        #expect(LoadPlanner.nearestLoadable(100) == 102.5)
    }

    @Test("upTo 卡住人工加重的上限")
    func nearestRespectsCeiling() {
        // 下肢步长 +5：100 → 105，没有 2.5kg 小片就换不上去。
        #expect(LoadPlanner.nearestLoadable(100, upTo: 105, plates: platesWithoutChange) == nil)
        #expect(LoadPlanner.nearestLoadable(100, upTo: 105, plates: platesWithChange) == 105)
        // 95 配不出，步长内的 100 是能换的第一个重量。
        #expect(LoadPlanner.nearestLoadable(95, upTo: 100, plates: platesWithoutChange) == 100)
        // 上限压在原地，就什么都换不到。
        #expect(LoadPlanner.nearestLoadable(95, upTo: 95, plates: platesWithChange) == nil)
    }

    @Test("搜索窗口内没有可配重量时返回 nil")
    func nothingReachable() {
        #expect(LoadPlanner.nearestLoadable(1000, plates: [], barWeight: 20) == nil)
    }
}
