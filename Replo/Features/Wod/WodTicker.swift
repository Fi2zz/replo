import AudioToolbox
import Foundation
import Observation
import UIKit

/// 计时器外壳：拿真实经过的时间喂给状态机，负责发声与震动。
///
/// 状态机是纯的，这里是它跟现实之间唯一的接缝：后台切回来、`Task` 被系统拖慢都不影响
/// 走表——每跳都按「从开始到现在过了多少秒」重新对齐，不做 `+= 1` 的累加。
@MainActor
@Observable
final class WodTicker {
    /// 委托提示词指定的系统提示音 ID。
    static let cueSoundID: SystemSoundID = 1005

    private(set) var timer: WorkoutTimerModel
    private(set) var lastCue: WorkoutTimerModel.Cue = .none
    private(set) var isRunning = false

    private var task: _Concurrency.Task<Void, Never>?
    private var startedAt: Date?
    private var frozenElapsed = 0
    private let sound = SystemSoundCue()
    private let haptic = HapticCue()

    init(wod: Wod) {
        self.timer = WorkoutTimerModel(wod: wod)
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

    func reset() {
        stopTask()
        timer.reset()
        startedAt = nil
        frozenElapsed = 0
        isRunning = false
        lastCue = .none
    }

    func addRound() { timer.addRound() }
    func removeRound() { timer.removeRound() }
    func toggleStation(_ id: UUID) { timer.toggleStation(id) }

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

    /// 每分钟起点提示音 + 震动，最后 10 秒只提示音，到点两样都来（规格 6）。
    private func play(_ cue: WorkoutTimerModel.Cue) {
        switch cue {
        case .none:
            break
        case .minute:
            sound.play()
            haptic.impact()
        case .finalTenSeconds:
            sound.play()
        case .end:
            sound.play()
            haptic.success()
        }
    }

    private func stopTask() {
        task?.cancel()
        task = nil
        startedAt = nil
    }
}

/// 系统提示音。委托提示词指定 1005。
private struct SystemSoundCue {
    func play() {
        AudioServicesPlaySystemSound(WodTicker.cueSoundID)
    }
}

/// 轻震动：每分钟/每组一次；结束时给一次成功反馈。
private struct HapticCue {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    func impact() {
        light.impactOccurred()
    }

    func success() {
        notification.notificationOccurred(.success)
    }
}
