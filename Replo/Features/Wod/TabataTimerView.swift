import SwiftData
import SwiftUI

/// TABATA 计时页：开场调参数（动作 / 工作 / 休息 / 轮数），计时中显示段与轮次，
/// 结束记成绩。手册：TABATA 与 WOD 二选一，默认战绳 20 秒 / 10 秒 × 8 轮。
/// 动作由用户自由填写，数量不限；填了多个时按轮轮换。
struct TabataTimerView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var movements = [WodMovementPool.defaultTabataMovement]
    @State private var workSeconds = 20
    @State private var restSeconds = 10
    @State private var rounds = 8
    @State private var ticker: TabataTicker?
    @State private var isRecording = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let ticker {
                    runningPanel(ticker)
                } else {
                    setupPanel
                }
            }
            .padding()
        }
        .navigationTitle("TABATA")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isRecording, content: resultSheet)
    }

    // MARK: - 参数

    private var setupPanel: some View {
        VStack(spacing: 16) {
            movementEditor
            Stepper("工作 \(workSeconds) 秒", value: $workSeconds, in: 5...60)
            Stepper("休息 \(restSeconds) 秒", value: $restSeconds, in: 5...60)
            Stepper("\(rounds) 轮", value: $rounds, in: 1...20)
            Text("动作自己填，可添加多个，计时按轮轮换。手册默认战绳 20 秒 / 10 秒 × 8 轮；壶铃摆动和跑步机不做 TABATA（伤腰 / 易摔）。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("开始", action: start)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 动作填写

    /// 自由文本动作列表：想填几个填几个，只剩一行时不给删除，免得把列表清空后无从下手。
    /// 行做成大圆角卡片（接近 iOS 分组表单的行高），保证输入区一眼可见、随手能点中。
    private var movementEditor: some View {
        VStack(spacing: 10) {
            ForEach(movements.indices, id: \.self) { index in
                movementRow(index)
            }
            Button("添加动作", systemImage: "plus") { movements.append("") }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    private func movementRow(_ index: Int) -> some View {
        HStack(spacing: 8) {
            TextField("动作 \(index + 1)", text: $movements[index])
                .font(.body)
            if movements.count > 1 {
                Button("删除", systemImage: "minus.circle.fill") { movements.remove(at: index) }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
    }

    /// 留空行不参与计时和存档。
    private var filledMovements: [String] {
        movements
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - 计时

    private func runningPanel(_ ticker: TabataTicker) -> some View {
        VStack(spacing: 16) {
            Text(segmentTitle(ticker.timer))
                .font(.title2.weight(.bold))
                .foregroundStyle(segmentColor(ticker.timer))
            Text(segmentClock(ticker.timer))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("第 \(ticker.timer.currentRound) / \(ticker.timer.totalRounds) 轮 · \(currentMovement(for: ticker.timer.currentRound))")
                .font(.callout)
                .foregroundStyle(.secondary)
            transport(ticker)
        }
    }

    /// 多个动作按轮轮换（第 1 轮第一个、第 2 轮第二个……绕圈）；全留空时退回显示「TABATA」。
    private func currentMovement(for round: Int) -> String {
        guard !filledMovements.isEmpty else { return "TABATA" }
        return filledMovements[(round - 1) % filledMovements.count]
    }

    /// 大字区：跑完显示「完成」，否则当前段名；跑完后 segment 回绕到 work，不能直接用它。
    private func segmentTitle(_ timer: TabataTimerModel) -> String {
        guard timer.phase != .finished else { return "完成" }
        return timer.segment.title
    }

    private func segmentColor(_ timer: TabataTimerModel) -> Color {
        guard timer.phase != .finished else { return .primary }
        return timer.segment == .work ? Color.green : Color.orange
    }

    private func transport(_ ticker: TabataTicker) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(ticker.isRunning ? "暂停" : "继续") {
                    ticker.isRunning ? ticker.pause() : ticker.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ticker.timer.phase == .finished)

                Button("重置") { self.ticker = nil }
                    .buttonStyle(.bordered)
            }
            if ticker.timer.phase == .finished {
                Button("记录成绩") { isRecording = true }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func resultSheet() -> some View {
        WodResultSheet(formatTitle: "TABATA", scoreText: ticker?.timer.scoreText ?? "") { draft in
            try save(draft)
        }
    }

    private func start() {
        let model = TabataTimerModel(
            workSeconds: workSeconds, restSeconds: restSeconds, totalRounds: rounds
        )
        let created = TabataTicker(model: model)
        ticker = created
        created.start()
    }

    /// 成绩带上动作名，历史里看得出练的是什么（如「战绳 · 完成 8/8 轮」）；多个动作全部列出。
    private func save(_ draft: WodResultDraft) throws {
        let result = WodResult(
            wodId: WodMovementPool.tabataWodID,
            date: Date(),
            score: scoreText(for: draft),
            rpe: draft.rpe,
            nextDaySoreness: draft.soreness.isEmpty ? nil : draft.soreness
        )
        modelContext.insert(result)
        try modelContext.save()
    }

    private func scoreText(for draft: WodResultDraft) -> String {
        guard !filledMovements.isEmpty else { return draft.score }
        return "\(filledMovements.joined(separator: "、")) · \(draft.score)"
    }

    private func segmentClock(_ timer: TabataTimerModel) -> String {
        guard timer.phase != .finished else { return "0:00" }
        return String(format: "%d:%02d", timer.segmentRemaining / 60, timer.segmentRemaining % 60)
    }
}
