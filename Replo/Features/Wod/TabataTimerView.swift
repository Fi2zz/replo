import SwiftData
import SwiftUI

/// TABATA 计时页：开场调参数（动作 / 工作 / 休息 / 轮数），计时中显示段与轮次，
/// 结束记成绩。手册：TABATA 与 WOD 二选一，默认战绳 20 秒 / 10 秒 × 8 轮。
struct TabataTimerView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var movement = WodMovementPool.defaultTabataMovement
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
            Picker("动作", selection: $movement) {
                ForEach(WodMovementPool.movements) { item in
                    Text(item.name).tag(item.name)
                }
            }
            Stepper("工作 \(workSeconds) 秒", value: $workSeconds, in: 5...60)
            Stepper("休息 \(restSeconds) 秒", value: $restSeconds, in: 5...60)
            Stepper("\(rounds) 轮", value: $rounds, in: 1...20)
            Text("手册默认战绳 20 秒 / 10 秒 × 8 轮；壶铃摆动和跑步机不做 TABATA（伤腰 / 易摔）。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("开始", action: start)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 计时

    private func runningPanel(_ ticker: TabataTicker) -> some View {
        VStack(spacing: 16) {
            Text(ticker.timer.segment.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(ticker.timer.segment == .work ? Color.green : Color.orange)
            Text(segmentClock(ticker.timer))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("第 \(ticker.timer.currentRound) / \(ticker.timer.totalRounds) 轮 · \(movement)")
                .font(.callout)
                .foregroundStyle(.secondary)
            transport(ticker)
        }
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

    /// 成绩带上动作名，历史里看得出练的是什么（如「战绳 · 完成 8/8 轮」）。
    private func save(_ draft: WodResultDraft) throws {
        let result = WodResult(
            wodId: WodMovementPool.tabataWodID,
            date: Date(),
            score: "\(movement) · \(draft.score)",
            rpe: draft.rpe,
            nextDaySoreness: draft.soreness.isEmpty ? nil : draft.soreness
        )
        modelContext.insert(result)
        try modelContext.save()
    }

    private func segmentClock(_ timer: TabataTimerModel) -> String {
        String(format: "%d:%02d", timer.segmentRemaining / 60, timer.segmentRemaining % 60)
    }
}
