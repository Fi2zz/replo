import SwiftData
import SwiftUI

/// 日历下方选中日的安排：课型与课程清单任何日期都看；
/// 「开始训练」和周进度只给今天，免得把训练记到别的日子上。
struct DayPlanDetail: View {
    let date: Date

    @Query private var movements: [Movement]
    @Query private var templates: [PlanTemplate]
    @Query private var activePlans: [ActivePlan]
    @Query private var logs: [SessionLog]
    @Query private var decisions: [WeightDecision]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            if plan.isStrength {
                movementsSection
            }
            if Calendar.current.isDateInToday(date) {
                todaySection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 区块

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateFormat.fullText(date))
                .font(.headline)
            LabeledContent("课型", value: plan.title)
            Text(plan.note)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var movementsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("当天课程 · 第 \(plan.weekIndex + 1) 周")
            ForEach(plan.movements) { movement in
                LabeledContent(
                    movement.name,
                    value: "\(movement.weightText)kg \(movement.sets)×\(movement.reps)"
                )
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        if plan.isStrength {
            NavigationLink {
                SessionView(plan: plan, histories: histories)
            } label: {
                Label("开始训练", systemImage: "figure.strengthtraining.traditional")
            }
        }
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("计划进度")
            LabeledContent("当前", value: "第 \(plan.weekIndex + 1) 周")
            if planContext.hasNextWeek {
                Button("这周练完了，进入下一周") { advanceWeek() }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - 数据

    private var planContext: PlanContext {
        PlanContext(
            activePlan: activePlans.first { $0.active } ?? activePlans.first,
            templates: templates,
            movements: movements
        )
    }

    private var plan: TodayPlan { planContext.plan(on: date) }

    private var histories: [UUID: MovementHistory] {
        FailStreak.histories(
            movementIds: plan.movements.map(\.movementId),
            logs: logs,
            decisions: decisions,
            before: plan.date
        )
    }

    // MARK: - 动作

    private func advanceWeek() {
        guard let plan = activePlans.first else { return }
        plan.currentWeekIndex += 1
    }
}
