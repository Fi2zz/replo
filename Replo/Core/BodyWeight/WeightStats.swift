import Foundation

/// 一次称重。`date` 归一到当天零点，周平均按自然周（周一起）分组。
struct WeightEntry: Identifiable, Equatable {
    var date: Date
    var kg: Double

    var id: Date { date }
}

/// 一个自然周的体重平均。
struct WeekAverage: Identifiable, Equatable {
    var weekStart: Date
    var kg: Double
    /// 相对上一周的变化，负数是掉了。
    var delta: Double?

    var id: Date { weekStart }
    var deltaText: String {
        guard let delta else { return "—" }
        return String(format: "%@%.2fkg", delta <= 0 ? "" : "+", delta)
    }
}

/// 体重统计：周平均与目标区间（规格 E）。
///
/// 计划里的监控规则是「每周日晨起空腹称重，看周平均」，所以主指标是周平均，
/// 单次称重只作原始点。目标区间 68-71kg 来自计划文档第一节。
enum WeightStats {
    static let targetRange = 68.0...71.0
    /// 计划给的减重速度：每周 0.25-0.4kg。
    static let weeklyLossRange = 0.25...0.4
    /// 周一起算，和 `MonthGrid` 一致（计划里的周节律就是周一起）。
    static let mondayFirst = 2

    /// 按自然周分组求平均，日期升序返回。
    static func weekly(_ entries: [WeightEntry], calendar: Calendar = .current) -> [WeekAverage] {
        let grouped = Dictionary(grouping: entries) { weekStart(of: $0.date, calendar: calendar) }
        let ordered = grouped.keys.sorted()
        var result: [WeekAverage] = []
        for (index, start) in ordered.enumerated() {
            guard let values = grouped[start] else { continue }
            let average = values.map(\.kg).reduce(0, +) / Double(values.count)
            let previous = index > 0 ? result[index - 1].kg : nil
            result.append(WeekAverage(weekStart: start, kg: average, delta: previous.map { average - $0 }))
        }
        return result
    }

    /// 区间内的点单独挑出来，图表用来画目标色带。
    static func isInTargetRange(_ kg: Double) -> Bool {
        targetRange.contains(kg)
    }

    /// 离目标区间还差多少：区间内是 0，区间外是到最近边界的距离（恒为正）。
    static func gapToTarget(_ average: Double) -> Double {
        switch average {
        case ..<targetRange.lowerBound: targetRange.lowerBound - average
        case targetRange.upperBound...: average - targetRange.upperBound
        default: 0
        }
    }

    /// 一周的起点，显式从周一起算。
    ///
    /// 不用 `dateInterval(of: .weekOfYear)`：那个跟着设备的 `firstWeekday` 走，
    /// 周日起的设备会把周日归到下一周，周平均曲线会整周错位。计划里的节律是周一起，
    /// 这里就固定周一起，跟设备区域设置无关。
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - mondayFirst + 7) % 7
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }
}
