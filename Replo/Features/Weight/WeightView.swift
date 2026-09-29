import Charts
import SwiftData
import SwiftUI

/// 体重：折线 + 周平均 + 68-71kg 目标区间带（规格 E）。
struct WeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyWeight.date, order: .reverse) private var records: [BodyWeight]
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Section { emptyHint }
                } else {
                    chartSection
                    summarySection
                    entriesSection
                }
            }
            .navigationTitle("体重")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                WeightEntrySheet(existing: entries) { entry in
                    try save(entry)
                }
            }
        }
    }

    // MARK: - 区块

    private var emptyHint: some View {
        Text("还没有记录。晨起空腹称一次，之后按周平均看趋势。")
            .foregroundStyle(.secondary)
    }

    private var chartSection: some View {
        Section {
            Chart {
                ForEach(entries) { entry in
                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("体重", entry.kg),
                        series: .value("类型", "单次")
                    )
                    .foregroundStyle(.secondary)
                    .interpolationMethod(.linear)
                }
                ForEach(weeks) { week in
                    LineMark(
                        x: .value("日期", week.weekStart),
                        y: .value("体重", week.kg),
                        series: .value("类型", "周平均")
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.stepEnd)
                    PointMark(
                        x: .value("日期", week.weekStart),
                        y: .value("体重", week.kg)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                RectangleMark(
                    yStart: .value("下限", WeightStats.targetRange.lowerBound),
                    yEnd: .value("上限", WeightStats.targetRange.upperBound)
                )
                .foregroundStyle(.green.opacity(0.12))
            }
            .chartYScale(domain: chartDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 1)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(DateFormat.shortText(date))
                        }
                    }
                }
            }
            .frame(height: 200)
        } header: {
            Text("趋势与目标区间 \(WeightFormat.text(WeightStats.targetRange.lowerBound))-\(WeightFormat.text(WeightStats.targetRange.upperBound))kg")
        }
    }

    private var summarySection: some View {
        Section("周平均") {
            ForEach(weeks) { week in
                LabeledContent(
                    "\(DateFormat.monthDayText(week.weekStart)) 那周",
                    value: "\(WeightFormat.text(week.kg))kg \(week.deltaText)"
                )
            }
            if let latest = weeks.last {
                LabeledContent("离目标区间", value: gapText(latest.kg))
            }
        }
    }

    private var entriesSection: some View {
        Section("全部记录") {
            ForEach(entries) { entry in
                LabeledContent(
                    "\(DateFormat.monthDayText(entry.date)) \(DateFormat.weekdayText(entry.date))",
                    value: "\(WeightFormat.text(entry.kg))kg"
                )
            }
            .onDelete { offsets in delete(offsets) }
        }
    }

    // MARK: - 数据

    private var entries: [WeightEntry] {
        records.map { WeightEntry(date: $0.date, kg: $0.kg) }
    }

    private var weeks: [WeekAverage] {
        WeightStats.weekly(entries.reversed())
    }

    /// 纵轴留出目标区间，两头各留一点余量。
    private var chartDomain: ClosedRange<Double> {
        let values = entries.map(\.kg) + [WeightStats.targetRange.lowerBound, WeightStats.targetRange.upperBound]
        let low = (values.min() ?? 68) - 1
        let high = (values.max() ?? 72) + 1
        return low...high
    }

    private func gapText(_ average: Double) -> String {
        let gap = WeightStats.gapToTarget(average)
        guard gap > 0 else { return "已在区间内" }
        return "还差 \(WeightFormat.text(gap))kg"
    }

    // MARK: - 动作

    /// 同一天再记一次就是改那天的数，不新增一条。
    private func save(_ entry: WeightEntry) throws {
        if let existing = records.first(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
            existing.kg = entry.kg
        } else {
            modelContext.insert(BodyWeight(date: entry.date, kg: entry.kg))
        }
        try modelContext.save()
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}
