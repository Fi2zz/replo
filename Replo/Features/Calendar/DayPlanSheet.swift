import SwiftData
import SwiftUI

/// 点某天看当天该做什么：课型、固定交代，力量日再列出动作与重量。
struct DayPlanSheet: View {
    let day: MonthDay
    let month: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var activePlans: [ActivePlan]
    @Query private var templates: [PlanTemplate]
    @Query private var movements: [Movement]

    var body: some View {
        NavigationStack {
            List {
                Section(DateFormat.fullText(day.date)) {
                    LabeledContent("课型", value: plan.dayType.title)
                    Text(plan.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if plan.isStrength {
                    Section("当天课程 · 第 \(plan.weekIndex + 1) 周") {
                        ForEach(plan.movements) { movement in
                            LabeledContent(
                                movement.name,
                                value: "\(movement.weightText)kg \(movement.sets)×\(movement.reps)"
                            )
                        }
                    }
                }
            }
            .navigationTitle("当天安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("好") { dismiss() }
                }
            }
        }
    }

    private var plan: TodayPlan {
        PlanContext(
            activePlan: activePlans.first { $0.active } ?? activePlans.first,
            templates: templates,
            movements: movements
        ).plan(on: day.date)
    }
}
