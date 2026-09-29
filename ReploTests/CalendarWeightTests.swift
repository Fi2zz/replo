import Foundation
import Testing

@testable import Replo

@Suite("月视图网格")
struct MonthGridTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func days(
        _ month: String,
        today: String = "2026-09-17",
        recorded: [String] = []
    ) -> [MonthDay] {
        let monthDate = try! #require(date(month))
        let todayDate = try! #require(date(today))
        let marks = recorded.compactMap(date)
        return MonthGrid.days(in: monthDate, today: todayDate, calendar: calendar) { day in
            marks.contains { calendar.isDate($0, inSameDayAs: day) }
        }
    }

    @Test("格子数是 7 的倍数，整月对齐到周一起")
    func gridIsWeekAligned() {
        let grid = days("2026-09-01")

        #expect(grid.count % 7 == 0)
        #expect(grid.first?.date.weekday == 2, "第一格是周一（周一起头）")
        #expect(grid.filter(\.isInMonth).count == 30, "2026 年 9 月 30 天")
    }

    @Test("前后月补位格标成不在本月")
    func paddingIsMarked() {
        let grid = days("2026-09-01")

        #expect(grid.first?.isInMonth == false)
        #expect(grid.last?.isInMonth == false)
        #expect(grid.filter(\.isInMonth).allSatisfy { $0.isInMonth })
    }

    @Test("课型按周节律落：周一 B、周三高强度、周日全休")
    func dayTypesFollowRhythm() {
        let grid = days("2026-09-01")
        // 只取本月内的格子：前后月的补位格日期会重复，不能按「几号」建字典。
        let byNumber = Dictionary(uniqueKeysWithValues: grid.filter(\.isInMonth).map { ($0.dayNumber, $0) })

        #expect(byNumber[7]?.dayType == .dayB, "9/7 是周一")
        #expect(byNumber[9]?.dayType == .wod, "9/9 是周三")
        #expect(byNumber[10]?.dayType == .rest, "9/10 周四是全休")
        #expect(byNumber[11]?.dayType == .dayA, "9/11 周五是力量 A")
        #expect(byNumber[13]?.dayType == .rest, "9/13 周日全休")
    }

    @Test("今天与已记录的标记")
    func todayAndRecordedFlags() {
        let grid = days("2026-09-01", today: "2026-09-11", recorded: ["2026-09-09", "2026-09-10"])

        #expect(grid.filter(\.isToday).count == 1)
        #expect(grid.first { $0.isToday }?.dayNumber == 11)
        #expect(grid.filter(\.isRecorded).count == 2)
    }

    @Test("2 月闰年与平年都对得上")
    func februaryLength() {
        #expect(days("2028-02-01").filter(\.isInMonth).count == 29)
        #expect(days("2026-02-01").filter(\.isInMonth).count == 28)
    }

    private func date(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

@Suite("体重周平均")
struct WeightStatsTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("同一周的几次称重合成一个平均")
    func averagesPerCalendarWeek() throws {
        let entries = [
            entry("2026-09-13", 73.6),  // 周日：属于 9/7 那一周
            entry("2026-09-14", 73.4),  // 周一：已经是新的一周
            entry("2026-09-19", 73.2),  // 周六：和 9/14 同一周
        ]

        let weeks = WeightStats.weekly(entries, calendar: calendar)

        #expect(weeks.count == 2)
        #expect(abs(weeks[0].kg - 73.6) < 0.001)
        #expect(abs(weeks[1].kg - 73.3) < 0.001)
    }

    @Test("周平均之间给出相对上一周的变化")
    func deltaBetweenWeeks() throws {
        let weeks = WeightStats.weekly([entry("2026-09-14", 73.5), entry("2026-09-21", 73.1)], calendar: calendar)

        #expect(weeks[0].delta == nil)
        #expect(abs(try #require(weeks[1].delta) + 0.4) < 0.001)
        #expect(weeks[1].deltaText == "-0.40kg")
    }

    @Test("空输入返回空数组")
    func emptyInput() {
        #expect(WeightStats.weekly([], calendar: calendar).isEmpty)
    }

    @Test("目标区间判定与差额")
    func targetRange() {
        #expect(WeightStats.isInTargetRange(69.5))
        #expect(WeightStats.isInTargetRange(68) == true)
        #expect(WeightStats.isInTargetRange(71) == true)
        #expect(WeightStats.isInTargetRange(71.5) == false)

        #expect(WeightStats.gapToTarget(70) == 0)
        #expect(abs(WeightStats.gapToTarget(73.8) - 2.8) < 0.001, "高于上限：差 2.8kg")
        #expect(abs(WeightStats.gapToTarget(66) - 2) < 0.001, "低于下限：差 2kg 到下限")
    }

    @Test("计划给的每周掉秤速度范围")
    func weeklyLossRange() {
        #expect(WeightStats.weeklyLossRange.contains(0.25))
        #expect(WeightStats.weeklyLossRange.contains(0.4))
    }

    private func entry(_ text: String, _ kg: Double) -> WeightEntry {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
        return WeightEntry(date: date, kg: kg)
    }
}

private extension Date {
    /// Calendar 的 weekday：1=周日。测试里用来看首格是不是周一。
    var weekday: Int { Calendar(identifier: .gregorian).component(.weekday, from: self) }
}

@Suite("文案格式化")
struct FormatTests {
    @Test("重量四舍五入到两位，不留浮点毛刺")
    func weightTextRounds() {
        #expect(WeightFormat.text(73.69999999999999) == "73.7")
        #expect(WeightFormat.text(72.6) == "72.6")
        #expect(WeightFormat.text(80) == "80")
        #expect(WeightFormat.text(42.5) == "42.5")
        #expect(WeightFormat.text(.nan) == "—")
    }

    @Test("日期走中文，不受设备英文区域影响")
    func datesAreChinese() throws {
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 29)))

        #expect(DateFormat.monthDayText(date) == "9月29日")
        #expect(DateFormat.monthTitleText(date) == "2026年9月")
        #expect(DateFormat.shortText(date) == "9/29")
        #expect(DateFormat.fullText(date).contains("年"))
    }
}
