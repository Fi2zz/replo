import SwiftData
import SwiftUI

/// TABATA 计时页：开场调参数（动作 / 工作 / 休息 / 轮数），计时中显示段与轮次，
/// 结束记成绩。手册：TABATA 与 WOD 二选一，默认战绳 20 秒 / 10 秒 × 8 轮。
/// 动作不内置，用户点「添加动作」自行输入，数量不限；填了多个时按轮轮换。
struct TabataTimerView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var movements: [String] = []
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
            countdownRing(ticker.timer)
            Text("第 \(ticker.timer.currentRound) / \(ticker.timer.totalRounds) 轮 · \(currentMovement(for: ticker.timer.currentRound))")
                .font(.callout)
                .foregroundStyle(.secondary)
            transport(ticker)
        }
    }

    /// 大圆环倒计时：外圈按当前段剩余比例收拢，圆心放剩余秒数；每秒线性扫一格。
    private func countdownRing(_ timer: TabataTimerModel) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 14)
            Circle()
                .trim(from: 0, to: ringProgress(timer))
                .stroke(segmentColor(timer), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(segmentClock(timer))
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 220, height: 220)
        .animation(.linear(duration: 1), value: timer.segmentRemaining)
    }

    /// 当前段剩余比例：跑完归零，否则剩余秒 / 段时长（工作段或休息段各自的时长）。
    private func ringProgress(_ timer: TabataTimerModel) -> Double {
        guard timer.phase != .finished else { return 0 }
        let total = timer.segment == .work ? timer.workSeconds : timer.restSeconds
        return Double(timer.segmentRemaining) / Double(total)
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

    /// 控制按钮一行一个、撑满宽度，计时中手指好够。
    private func transport(_ ticker: TabataTicker) -> some View {
        VStack(spacing: 10) {
            Button {
                ticker.isRunning ? ticker.pause() : ticker.start()
            } label: {
                Text(ticker.isRunning ? "暂停" : "继续")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(ticker.timer.phase == .finished)

            Button { self.ticker = nil } label: {
                Text("重置")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if ticker.timer.phase == .finished {
                Button { isRecording = true } label: {
                    Text("记录成绩")
                        .frame(maxWidth: .infinity)
                }
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
