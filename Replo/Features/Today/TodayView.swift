import SwiftData
import SwiftUI

/// 今日页：按周节律显示今天该练什么，力量课从卡片进入训练流程。
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var movements: [Movement]
    @Query private var templates: [PlanTemplate]
    @Query private var activePlans: [ActivePlan]
    @Query private var logs: [SessionLog]
    @Query private var decisions: [WeightDecision]

    @State private var failure: String?
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            List {
                Section("今天") { planHeader }
                if plan.isStrength {
                    movementsSection
                }
                weekSection
            }
            .navigationTitle("今日")
            .task { importSeeds() }
            .alert("种子导入失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    // MARK: - 区块

    @ViewBuilder
    private var planHeader: some View {
        LabeledContent("课型", value: plan.title)
        Text(plan.note)
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var movementsSection: some View {
        Section("今日课程") {
            ForEach(plan.movements) { movement in
                LabeledContent(movement.name, value: "\(movement.weightText)kg \(movement.sets)×\(movement.reps)")
            }
            NavigationLink {
                SessionView(plan: plan, histories: histories)
            } label: {
                Label("开始训练", systemImage: "figure.strengthtraining.traditional")
            }
        }
    }

    @ViewBuilder
    private var weekSection: some View {
        Section("计划进度") {
            LabeledContent("当前", value: "第 \(plan.weekIndex + 1) 周")
            if planContext.hasNextWeek {
                Button("这周练完了，进入下一周") { advanceWeek() }
            }
        }
    }

    // MARK: - 数据

    private var planContext: PlanContext {
        PlanContext(
            activePlan: activePlans.first { $0.active } ?? activePlans.first,
            templates: templates,
            movements: movements
        )
    }

    private var plan: TodayPlan { planContext.plan(on: now) }

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
