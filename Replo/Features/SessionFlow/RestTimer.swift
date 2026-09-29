import Foundation
import Observation

/// 组间休息倒计时。时钟由 `Task.sleep` 推进，不读系统时间，
/// 所以后台切回来不会自己少掉时间；离开页面时 `stop()` 收掉循环。
@MainActor
@Observable
final class RestTimer {
    private(set) var remaining: Int
    private(set) var running = false
    /// 每轮结束提示一次，界面据此震动或出声。
    private(set) var didFinish = false
    private var task: Task<Void, Never>?

    init(seconds: Int = SessionStore.defaultRestSeconds) {
        self.remaining = seconds
    }

    func start() {
        guard !running, remaining > 0 else { return }
        running = true
        didFinish = false
        task = Task { [weak self] in
            while let self, !Task.isCancelled, self.remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.remaining -= 1
            }
            guard let self, !Task.isCancelled else { return }
            self.finish()
        }
    }

    func pause() {
        task?.cancel()
        task = nil
        running = false
    }

    /// 换休息时长。倒计时中改就从新时长重新开始，避免半截数字跳动。
    func reset(to seconds: Int) {
        pause()
        remaining = max(0, seconds)
        didFinish = false
    }

    func stop() {
        task?.cancel()
        task = nil
        running = false
    }

    private func finish() {
        running = false
        task = nil
        didFinish = true
    }
}
