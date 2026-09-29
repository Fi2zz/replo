import SwiftUI

/// 组间休息倒计时。计时器由外层持有：打满一组就由训练页统一启动，
/// 免得每个动作各挂一个、各走各的。
struct RestTimerView: View {
    let timer: RestTimer
    let defaultSeconds: Int
    let onSecondsChange: (Int) -> Void

    @State private var seconds: Int
    @State private var feedback = UIImpactFeedbackGenerator(style: .medium)

    init(timer: RestTimer, defaultSeconds: Int, onSecondsChange: @escaping (Int) -> Void) {
        self.timer = timer
        self.defaultSeconds = defaultSeconds
        self.onSecondsChange = onSecondsChange
        _seconds = State(initialValue: defaultSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("组间休息", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text(clock)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(timer.running ? .primary : .secondary)
            }
            controls
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
        .onChange(of: timer.didFinish) { _, finished in
            guard finished else { return }
            feedback.impactOccurred()
        }
    }

    @ViewBuilder
    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(timer.running ? "暂停" : "开始") {
                    timer.running ? timer.pause() : timer.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(timer.remaining == 0)

                Button("重置") {
                    timer.reset(to: seconds)
                }
                .buttonStyle(.bordered)
                .disabled(timer.running)
                Spacer()
            }
            Stepper(
                value: $seconds,
                in: 30...600,
                step: 30,
                onEditingChanged: { editing in
                    guard !editing else { return }
                    onSecondsChange(seconds)
                    timer.reset(to: seconds)
                }
            ) {
                Text("每组之间休息 \(seconds) 秒")
                    .font(.callout.monospacedDigit())
            }
        }
    }

    private var clock: String {
        let minutes = timer.remaining / 60
        let rest = timer.remaining % 60
        return String(format: "%d:%02d", minutes, rest)
    }
}
