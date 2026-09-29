import Foundation

/// 引擎看到的动作：名字 + 类别（+ 归属日，供调用方排课）。
///
/// 刻意不是 `@Model Movement`：引擎是纯函数模块，不该被 SwiftData 拖进来，
/// 也不该让调用方为了算一次重量去 fetch 一个托管对象（规格 5.1）。
struct MovementSpec: Equatable, Sendable {
    var name: String
    var category: MovementCategory
    var pattern: DayPattern

    init(name: String, category: MovementCategory, pattern: DayPattern) {
        self.name = name
        self.category = category
        self.pattern = pattern
    }

    /// 警示区下限（规格 5.3）：深蹲 90、硬拉 105，其余动作没有历史失败线。
    var warningFloor: Double? { Self.warningFloors[name] }

    /// 重量是否已经踩到历史失败线。引擎行为不变，只多打一个标记。
    func inWarningZone(atWeight weight: Double) -> Bool {
        guard let warningFloor else { return false }
        return weight >= warningFloor
    }

    /// 键是 `SeedData.movements` 里的动作名，改名要连这里一起改。
    static let warningFloors: [String: Double] = ["深蹲": 90, "硬拉": 105]

    /// 按种子动作名取规格。名字对不上返回 nil，不猜类别。
    static func named(_ name: String) -> MovementSpec? {
        guard let seed = SeedData.movements.first(where: { $0.name == name }) else { return nil }
        return MovementSpec(name: seed.name, category: seed.category, pattern: seed.pattern)
    }
}
