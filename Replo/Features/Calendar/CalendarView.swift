import SwiftData
import SwiftUI

/// 日历：月视图四色标记，左右滑或点箭头切月；下方跟选中日的安排，默认选中今天（规格 7）。
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var logs: [SessionLog]
    @Query private var wodResults: [WodResult]

    @State private var month = Date()
    @State private var selectedDate = Date()
    @State private var failure: String?
    @State private var dragOffset: CGFloat = 0
    @State private var gridWidth: CGFloat = 0
    @State private var sliding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 12) {
                        monthHeader
                        weekdayHeader
                        grid
                    }
                    .simultaneousGesture(monthSwipe)
                    legend
                    Divider()
                    DayPlanDetail(date: selectedDate)
                }
                .padding()
            }
            .navigationTitle("日历")
            .task { importSeeds() }
            .alert("种子导入失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    // MARK: - 区块

    private var monthHeader: some View {
        HStack {
            Button {
                slideMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                slideMonth(by: 1)
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
                    selectedDate = day.date
                } label: {
                    DayCell(day: day, selected: selected(day))
                }
                .buttonStyle(.plain)
            }
        }
        .offset(x: dragOffset)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
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

    private func selected(_ day: MonthDay) -> Bool {
        Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
    }

    private var monthTitle: String { DateFormat.monthTitleText(month) }

    private var weekdayTitles: [String] {
        ["一", "二", "三", "四", "五", "六", "日"]
    }

    // MARK: - 动作

    /// 跟手滑切月：横向为主的拖动才让格子跟手，竖向滚动留给 ScrollView；
    /// simultaneousGesture 保证点格子选日和整页滚动都不受影响。
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard !sliding, horizontal(value.translation) else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !sliding else { return }
                guard horizontal(value.translation),
                      abs(value.predictedEndTranslation.width) > gridWidth / 4 else {
                    withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
                    return
                }
                slideMonth(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    /// 跟手滑出 → 无动画换月 → 新月份从另一侧滑入。箭头按钮也走这条路，两种切法同一种动效。
    private func slideMonth(by step: Int) {
        guard !sliding else { return }
        guard gridWidth > 0 else {
            shiftMonth(by: step)
            return
        }
        sliding = true
        let exit = CGFloat(-step) * gridWidth
        withAnimation(.easeOut(duration: 0.18)) {
            dragOffset = exit
        } completion: {
            swapMonth(by: step, from: exit)
        }
    }

    /// 滑出到位后瞬间换月并从另一侧进场；走完才放下一次滑动的闸，避免连滑记两次。
    private func swapMonth(by step: Int, from exit: CGFloat) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shiftMonth(by: step)
            dragOffset = -exit
        }
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = 0
        } completion: {
            sliding = false
        }
    }

    private func horizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    private func shiftMonth(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: month) else { return }
        month = next
    }

    private func importSeeds() {
        guard failure == nil else { return }
        do {
            try SeedImporter.applyOnce(to: context)
        } catch {
            failure = String(describing: error)
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
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
