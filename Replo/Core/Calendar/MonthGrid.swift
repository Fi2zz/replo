import Foundation

/// 月视图的一格：这一天是什么课、练没练。
struct MonthDay: Identifiable, Equatable {
    var date: Date
    var dayType: DayType
    var isToday: Bool
    /// 当天已经有训练记录或 WOD 成绩。
    var isRecorded: Bool
    /// 是不是本月内的日子（前后月的补位格子画淡一点）。
    var isInMonth: Bool

    var id: Date { date }

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
}

/// 把一个月铺成整周对齐的格子。课型来自周节律，不查库；练没练由调用方给判定。
enum MonthGrid {
    /// 计划里的周节律从周一起（周一力量 B … 周日全休），所以月视图也周一起头，
    /// 不跟设备 locale 走——周一起改成周日起，整张图会和课表错位一天。
    static let mondayFirst = 2

    /// 按 `firstWeekday` 对齐，首尾用相邻月的日期补满整周。
    static func days(
        in month: Date,
        today: Date,
        calendar: Calendar = .current,
        firstWeekday: Int = mondayFirst,
        isRecorded: (Date) -> Bool = { _ in false }
    ) -> [MonthDay] {
        let start = startOfMonth(of: month, calendar: calendar)
        let leading = leadingBlankDays(of: start, calendar: calendar, firstWeekday: firstWeekday)
        let inMonth = numberOfDays(in: month, calendar: calendar)
        let trailing = (7 - (leading + inMonth) % 7) % 7

        return (0..<(leading + inMonth + trailing)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - leading, to: start) else {
                return nil
            }
            return makeDay(date, month: month, today: today, calendar: calendar, isRecorded: isRecorded)
        }
    }

    private static func makeDay(
        _ date: Date,
        month: Date,
        today: Date,
        calendar: Calendar,
        isRecorded: (Date) -> Bool
    ) -> MonthDay {
        MonthDay(
            date: date,
            dayType: WeekRhythm.dayType(weekday: calendar.component(.weekday, from: date)),
            isToday: calendar.isDate(date, inSameDayAs: today),
            isRecorded: isRecorded(date),
            isInMonth: calendar.isDate(date, equalTo: month, toGranularity: .month)
        )
    }

    private static func startOfMonth(of date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func numberOfDays(in month: Date, calendar: Calendar) -> Int {
        let start = startOfMonth(of: month, calendar: calendar)
        guard let next = calendar.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return calendar.dateComponents([.day], from: start, to: next).day ?? 0
    }

    private static func leadingBlankDays(of firstOfMonth: Date, calendar: Calendar, firstWeekday: Int) -> Int {
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday - firstWeekday + 7) % 7
    }
}
