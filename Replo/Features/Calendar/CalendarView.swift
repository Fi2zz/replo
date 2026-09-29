import SwiftData
import SwiftUI

/// 日历：月视图四色标记，点某天看当天该练什么（规格 7）。
struct CalendarView: View {
    @Query private var logs: [SessionLog]
    @Query private var wodResults: [WodResult]

    @State private var month = Date()
    @State private var selected: MonthDay?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                monthHeader
                weekdayHeader
                grid
                legend
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("日历")
            .sheet(item: $selected) { day in
                DayPlanSheet(day: day, month: month)
            }
        }
    }

    // MARK: - 区块

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdayTitles, id: \.self) { title in
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days) { day in
                Button {
                    selected = day
                } label: {
                    DayCell(day: day)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(DayType.legend, id: \.dayType) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.dayType.tint)
                        .frame(width: 8, height: 8)
                    Text(item.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 数据

    private var days: [MonthDay] {
        MonthGrid.days(in: month, today: Date(), isRecorded: isRecorded)
    }

    /// 当天有训练记录或 WOD 成绩就算练过。
    private func isRecorded(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return logs.contains { calendar.isDate($0.date, inSameDayAs: date) }
            || wodResults.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var monthTitle: String { DateFormat.monthTitleText(month) }

    private var weekdayTitles: [String] {
        ["一", "二", "三", "四", "五", "六", "日"]
    }

    private func shiftMonth(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: month) else { return }
        month = next
    }
}

private struct DayCell: View {
    let day: MonthDay

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day.dayNumber)")
                .font(.callout)
                .foregroundStyle(day.isInMonth ? .primary : .tertiary)
            marker
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(day.isToday ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
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
