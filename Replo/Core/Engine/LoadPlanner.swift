import Foundation

/// 配重可行性：目标重量能不能用现有杠铃片配出来。纯函数，不参与决策（规格 5.4）。
///
/// 判定是两侧对称的整数背包：每侧要配的重量 = (目标 − 杠铃) / 2，
/// 能不能用给定片重（每种可用任意片）凑出来。
enum LoadPlanner {
    /// 常见家用杠铃片，含 1.25kg 小片。配不出 95 的真实案例发生在还没有小片的时候。
    static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    static let standardBar: Double = 20
    /// 换算成 0.25kg 为单位的整数，避开浮点累加误差。
    private static let unitsPerKg = 4.0
    /// 找最近可配重量时的搜索步长与上限。
    private static let searchStep = 0.25
    private static let searchCeiling = 40.0

    static func canLoad(
        _ weight: Double,
        plates: [Double] = standardPlates,
        barWeight: Double = standardBar
    ) -> Bool {
        guard let perSide = plateWeight(of: weight, barWeight: barWeight) else { return false }
        guard let target = units(of: perSide) else { return false }
        return reachable(target, sizes: units(of: plates))
    }

    /// 返回严格大于 `weight` 的最近可配重量，最多找到 `upTo`，找不到返回 nil。
    ///
    /// 用法就是「这个重量配不出，换哪个」：从 `weight` 往上找，且只往上看——
    /// 往下退等于变相减重，减重要走引擎的 deload 规则，不能由配重可行性顺手决定。
    /// 9/28 硬拉 95 配不出、当场改 100 就是这条路径。
    /// `upTo` 用来卡住人工加重的上限（规格 5.3：人工加重不许超过规则步长）。
    static func nearestLoadable(
        _ weight: Double,
        upTo limit: Double? = nil,
        plates: [Double] = standardPlates,
        barWeight: Double = standardBar
    ) -> Double? {
        let ceiling = min(weight + searchCeiling, limit ?? .greatestFiniteMagnitude)
        var candidate = max(weight + searchStep, barWeight)
        while candidate <= ceiling {
            if canLoad(candidate, plates: plates, barWeight: barWeight) { return candidate }
            candidate += searchStep
        }
        return nil
    }

    /// 每侧要配的重量；比杠铃还轻配不出来。
    private static func plateWeight(of weight: Double, barWeight: Double) -> Double? {
        let onPlates = weight - barWeight
        guard onPlates >= 0 else { return nil }
        return onPlates / 2
    }

    /// 换算成 0.25kg 为单位的整数。换不出整数说明这个重量不在片重能凑出的刻度上
    /// （比如每侧要 39.875kg），直接判不可配，不四舍五入放行。
    private static func units(of kilograms: Double) -> Int? {
        let scaled = (kilograms * unitsPerKg).rounded()
        guard abs(kilograms * unitsPerKg - scaled) < 1e-9 else { return nil }
        return Int(scaled)
    }

    private static func units(of plates: [Double]) -> [Int] {
        plates.compactMap { units(of: $0) }.filter { $0 > 0 }
    }

    /// 从 0 起逐个单位判断能否凑出：能凑出 `total − size` 就说明 `total` 也能凑出。
    private static func reachable(_ target: Int, sizes: [Int]) -> Bool {
        guard target >= 0, !sizes.isEmpty else { return target == 0 }
        var sums: Set<Int> = [0]
        for total in 1...max(target, 1) where !sums.contains(total) {
            if sizes.contains(where: { size in size <= total && sums.contains(total - size) }) {
                sums.insert(total)
            }
        }
        return sums.contains(target)
    }
}
