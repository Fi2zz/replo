import AudioToolbox
import Foundation
import Observation
import UIKit

/// TABATA 计时器外壳：拿真实经过的时间喂状态机，负责发声与震动。
/// 与 WodTicker 同一套接缝：暂停冻结、恢复按起点对齐，不做 += 1 累加。
@MainActor
@Observable
final class TabataTicker {
    private(set) var timer: TabataTimerModel
    private(set) var lastCue: TabataTimerModel.Cue = .none
    private(set) var isRunning = false

    private var task: _Concurrency.Task<Void, Never>?
    private var startedAt: Date?
    private var frozenElapsed = 0

    init(model: TabataTimerModel) {
        self.timer = model
    }

    func start() {
        guard !isRunning, timer.phase != .finished else { return }
        timer.start()
        isRunning = true
        startedAt = Date()
        scheduleTick()
    }

    func pause() {
        guard isRunning else { return }
        frozenElapsed = timer.elapsed
        stopTask()
        timer.pause()
        isRunning = false
    }

    /// 现在过了多少秒：暂停时用冻结值，运行时按起点对齐。
    private var trueElapsed: Int {
        guard let startedAt else { return frozenElapsed }
        return frozenElapsed + Int(Date().timeIntervalSince(startedAt))
    }

    private func scheduleTick() {
        task?.cancel()
        task = _Concurrency.Task { [weak self] in
            while let self, !_Concurrency.Task.isCancelled {
                try? await _Concurrency.Task.sleep(for: .milliseconds(200))
                guard !_Concurrency.Task.isCancelled else { return }
                self.tick()
                if self.timer.phase == .finished { self.isRunning = false }
            }
        }
    }

    private func tick() {
        let cue = timer.advance(to: trueElapsed)
        guard cue != .none else { return }
        lastCue = cue
        play(cue)
    }

    /// 换段：提示音 + 轻震动；段末 3 秒只提示音；全部跑完两样都来。
    private func play(_ cue: TabataTimerModel.Cue) {
        switch cue {
        case .none:
            break
        case .segment:
            AudioServicesPlaySystemSound(WodTicker.cueSoundID)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .finalThree:
            AudioServicesPlaySystemSound(WodTicker.cueSoundID)
        case .end:
            AudioServicesPlaySystemSound(WodTicker.cueSoundID)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func stopTask() {
        task?.cancel()
        task = nil
        startedAt = nil
    }
}
