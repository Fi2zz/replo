import SwiftData
import SwiftUI

/// 计时页：四种格式共用一套壳，差异部分按格式切换（规格 6）。
struct WodTimerView: View {
    let wod: Wod

    @Environment(\.modelContext) private var modelContext
    @State private var ticker: WodTicker
    @State private var isRecording = false

    init(wod: Wod) {
        self.wod = wod
        _ticker = State(initialValue: WodTicker(wod: wod))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                formatPanel
                transport
            }
            .padding()
        }
        .navigationTitle(wod.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isRecording) {
            WodResultSheet(wod: wod, timer: ticker) { result in
                try save(result)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(primaryClock)
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(caption)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    /// AMRAP 读倒计时，其余格式读正计时（规格 6）。
    private var primaryClock: String {
        let seconds = timer.format == .amrap ? timer.remaining : timer.elapsed
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var caption: String {
        if timer.format == .emom { return "第 \(timer.minute) / \(timer.capSeconds / 60) 分钟" }
        if timer.phase == .finished { return timer.cappedOut ? "到 cap，没做完" : "完成" }
        return "\(wod.format.title) · \(wod.timeCapSeconds / 60) 分钟封顶"
    }

    // MARK: - 格式面板

    @ViewBuilder
    private var formatPanel: some View {
        switch wod.format {
        case .amrap, .forTime: roundCounter
        case .chipper: checklist
        case .emom: minuteList
        }
    }

    private var roundCounter: some View {
        VStack(spacing: 8) {
            Text("轮数")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                Button {
                    ticker.removeRound()
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title)
                }
                .buttonStyle(.plain)
                .disabled(timer.rounds == 0 || timer.phase == .finished)

                Text("\(timer.rounds)")
                    .font(.title.monospacedDigit())
                    .frame(minWidth: 48)

                Button {
                    ticker.addRound()
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title)
                }
                .buttonStyle(.plain)
                .disabled(timer.phase == .finished)
            }
            if let planned = wod.rounds {
                Text("规定 \(planned) 轮")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("清单")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(wod.stations) { station in
                Button {
                    ticker.toggleStation(station.id)
                } label: {
                    HStack {
                        Image(systemName: timer.doneStations.contains(station.id) ? "checkmark.circle.fill" : "circle")
                        Text(station.summary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(timer.phase == .finished)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))
    }

    private var minuteList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("每分钟做什么")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(wod.stations) { station in
                HStack {
                    Text(station.parity?.title ?? "全程")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: .capsule)
                    Text(station.summary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))
    }

    // MARK: - 走表

    private var transport: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(ticker.isRunning ? "暂停" : "开始") {
                    ticker.isRunning ? ticker.pause() : ticker.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(timer.phase == .finished)

                Button("重置") { ticker.reset() }
                    .buttonStyle(.bordered)
            }
            if timer.phase == .finished {
                Button("记录成绩") { isRecording = true }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var timer: WorkoutTimerModel { ticker.timer }

    private func save(_ draft: WodResultDraft) throws {
        let result = WodResult(
            wodId: wod.id,
            date: Date(),
            score: draft.score,
            rpe: draft.rpe,
            nextDaySoreness: draft.soreness.isEmpty ? nil : draft.soreness
        )
        modelContext.insert(result)
        try modelContext.save()
    }
}
