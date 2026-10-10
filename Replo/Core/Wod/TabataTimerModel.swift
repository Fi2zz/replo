import Foundation

/// TABATA 间歇计时状态机：工作段 / 休息段交替，跑满轮数自动结束。
/// 与 WorkoutTimerModel 同风格：外部 ticker 按秒喂真实经过时间，自身不读系统时钟。
struct TabataTimerModel: Equatable {
    /// 当前处在工作段还是休息段。
    enum Segment: Equatable {
        case work, rest

        var title: String { self == .work ? "WORK" : "REST" }
    }

    /// 一次推进跨过的提示点，界面据此发声、震动。
    enum Cue: Equatable {
        case none
        /// 跨过段边界（工作→休息，或休息→下一轮工作）。
        case segment
        /// 进入当前段最后 3 秒。
        case finalThree
        /// 全部轮数跑完。
        case end
    }

    enum Phase: Equatable {
        case ready, running, paused, finished
    }

    let workSeconds: Int
    let restSeconds: Int
    let totalRounds: Int

    private(set) var phase: Phase = .ready
    private(set) var elapsed: Int = 0

    init(workSeconds: Int = 20, restSeconds: Int = 10, totalRounds: Int = 8) {
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.totalRounds = totalRounds
    }

    // MARK: - 派生

    var totalSeconds: Int { cycleSeconds * totalRounds }
    /// 当前第几轮，从 1 数。
    var currentRound: Int { min(elapsed / cycleSeconds + 1, totalRounds) }
    var segment: Segment { segmentOrdinal(at: elapsed) % 2 == 0 ? .work : .rest }
    /// 当前段还剩几秒。
    var segmentRemaining: Int { segmentRemaining(at: elapsed) }
    /// 已完成的完整工作段数；成绩按它记。
    var completedRounds: Int {
        guard elapsed >= workSeconds else { return 0 }
        return min((elapsed - workSeconds) / cycleSeconds + 1, totalRounds)
    }
    /// 成绩文案，写进 WodResult.score。
    var scoreText: String { "完成 \(completedRounds)/\(totalRounds) 轮" }

    // MARK: - 走时

    mutating func start() {
        guard phase == .ready || phase == .paused else { return }
        phase = .running
    }

    mutating func pause() {
        guard phase == .running else { return }
        phase = .paused
    }

    mutating func reset() {
        phase = .ready
        elapsed = 0
    }

    /// 喂真实经过的秒数（单调不减）。跑满总时长自动结束，返回这一跳跨过的提示点。
    @discardableResult
    mutating func advance(to seconds: Int) -> Cue {
        guard phase == .running, seconds > elapsed else { return .none }
        let target = min(seconds, totalSeconds)
        let cue = cue(from: elapsed, to: target)
        elapsed = target
        if elapsed >= totalSeconds { phase = .finished }
        return cue
    }

    private var cycleSeconds: Int { workSeconds + restSeconds }

    /// 段序号：第 n 轮的工作段是 2(n-1)，休息段是 2(n-1)+1。
    private func segmentOrdinal(at seconds: Int) -> Int {
        seconds / cycleSeconds * 2 + (seconds % cycleSeconds < workSeconds ? 0 : 1)
    }

    private func segmentRemaining(at seconds: Int) -> Int {
        let within = seconds % cycleSeconds
        return within < workSeconds ? workSeconds - within : cycleSeconds - within
    }

    /// 提示点优先级：结束 > 跨段 > 进入段末 3 秒。
    /// 末 3 秒提示只在正好落到剩余 3 秒时发一次；一次大跳直接越过不报。
    private func cue(from: Int, to: Int) -> Cue {
        if to >= totalSeconds { return .end }
        if segmentOrdinal(at: to) > segmentOrdinal(at: from) { return .segment }
        if segmentRemaining(at: from) > 3, segmentRemaining(at: to) == 3 { return .finalThree }
        return .none
    }
}
