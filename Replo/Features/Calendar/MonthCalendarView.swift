import HorizonCalendar
import SwiftUI

/// 月历区：HorizonCalendar 横向布局，默认就是按月分页，跟手滑动、惯性、回弹都是原生的。
/// 月标题与星期头在这里自定义成中文；选中、今天、课型色点、已练对勾沿用 DayCell。
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    /// 当天有训练记录或 WOD 成绩（画对勾）。
    let isRecorded: (Date) -> Bool
    /// 状态指纹：选中日或记录条数变化时让日历重渲染。
    let refreshToken: String

    @State private var proxy = CalendarViewProxy()
    @State private var width: CGFloat = 0

    private let visibleRange = Self.makeRange()

    var body: some View {
        CalendarViewRepresentable(
            calendar: Self.calendar,
            visibleDateRange: visibleRange,
            monthsLayout: .horizontal(options: HorizontalMonthsLayoutOptions()),
            dataDependency: refreshToken,
            proxy: proxy
        )
        .monthHeaders { month in
            Text(DateFormat.monthTitleText(Self.calendar.date(from: month.components) ?? Date()))
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .dayOfWeekHeaders { _, weekdayIndex in
            Text(Self.weekdayTitles[weekdayIndex])
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .days { [selectedDate, isRecorded] day in
            dayCell(day, selectedDate: selectedDate, isRecorded: isRecorded)
        }
        .dayOfWeekAspectRatio(0.5)
        .interMonthSpacing(24)
        .onDaySelection { day in
            guard let date = Self.calendar.date(from: day.components) else { return }
            selectedDate = date
        }
        .frame(height: Self.height(width: width))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear {
            proxy.scrollToMonth(
                containing: Date(),
                scrollPosition: .firstFullyVisiblePosition(padding: 0),
                animated: false
            )
        }
    }

    // MARK: - 数据

    /// 课表周节律从周一起（见 `MonthGrid.mondayFirst`），月历跟着周一起头，不跟设备 locale。
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = MonthGrid.mondayFirst
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()

    static let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]

    private func dayCell(
        _ day: DayComponents,
        selectedDate: Date,
        isRecorded: (Date) -> Bool
    ) -> some View {
        let date = Self.calendar.date(from: day.components) ?? .distantPast
        let monthDay = MonthDay(
            date: date,
            dayType: WeekRhythm.dayType(weekday: Self.calendar.component(.weekday, from: date)),
            isToday: Self.calendar.isDateInToday(date),
            isRecorded: isRecorded(date),
            isInMonth: true
        )
        return DayCell(day: monthDay, selected: Self.calendar.isDate(date, inSameDayAs: selectedDate))
    }

    /// 高度必须容下行数最多的月份：月头 28 + 星期头半格 + 6 行方格，否则会被裁。
    private static func height(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 1 }
        let day = width / 7
        return 28 + day * 0.5 + day * 6 + 4
    }

    /// 前后三年半够翻了：记录翻得到，计划也排得到。
    private static func makeRange() -> ClosedRange<Date> {
        let now = Date()
        let start = calendar.date(byAdding: .year, value: -3, to: now) ?? now
        let end = calendar.date(byAdding: .year, value: 1, to: now) ?? now
        return start...end
    }
}

private struct DayCell: View {
    let day: MonthDay
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day.dayNumber)")
                .font(.callout)
                .foregroundStyle(day.isInMonth ? .primary : .tertiary)
            marker
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(day.isToday ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
    }

    @ViewBuilder
    private var marker: some View {
        Circle()
            .fill(day.dayType.tint)
            .frame(width: 10, height: 10)
            .overlay {
                if day.isRecorded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}
