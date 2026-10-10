import SwiftData
import SwiftUI

/// 日历：横向滑动的月历（HorizonCalendar 分页），下方跟选中日的安排，默认选中今天（规格 7）。
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var logs: [SessionLog]
    @Query private var wodResults: [WodResult]

    @State private var selectedDate = Date()
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    MonthCalendarView(
                        selectedDate: $selectedDate,
                        isRecorded: isRecorded,
                        refreshToken: refreshToken
                    )
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

    /// 选中日或记录条数变了才重渲染月历（HorizonCalendar 靠 dataDependency 驱动）。
    private var refreshToken: String {
        "\(selectedDate.timeIntervalSince1970)|\(logs.count)|\(wodResults.count)"
    }

    /// 当天有训练记录或 WOD 成绩就算练过。
    private func isRecorded(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return logs.contains { calendar.isDate($0.date, inSameDayAs: date) }
            || wodResults.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - 动作

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
