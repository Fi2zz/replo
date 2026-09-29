import Foundation

/// WOD 计时状态机。外部 ticker 按秒把真实经过时间喂进来，状态与提示都在这里算，
/// 结构体自己不读系统时钟（规格 6、委托提示词的 `TimerEngine`）。
///
/// 四种格式共用一个状态：AMRAP 倒计时到 cap 并锁轮数，EMOM 递增分钟序号，
/// For Time / Chipper 正计时并在到 cap 时判定有没有做完。
struct WorkoutTimerModel: Equatable {
    /// 一次推进跨过的提示点，界面据此发声、震动。
    enum Cue: Equatable {
        case none
        /// EMOM：跨过整分，下一分钟开始。
        case minute
        /// 所有格式：进入最后 10 秒。
        case finalTenSeconds
        /// 到 cap。
        case end
    }

    enum Phase: Equatable {
        case ready, running, paused, finished
    }

    let wodID: UUID
    let format: WodFormat
    let capSeconds: Int
    /// Chipper 清单顺序；其余格式为空。
    let stationIDs: [UUID]
    /// For Time 的规定轮数；AMRAP 自由轮数、Chipper 为 nil。
    let plannedRounds: Int?

    private(set) var phase: Phase = .ready
    private(set) var elapsed: Int = 0
    private(set) var rounds: Int = 0
    private(set) var doneStations: Set<UUID> = []

    init(wod: Wod) {
        self.wodID = wod.id
        self.format = wod.format
        self.capSeconds = wod.timeCapSeconds
        self.stationIDs = wod.stations.map(\.id)
        self.plannedRounds = wod.rounds
    }

    // MARK: - 派生

    /// 距 cap 的剩余秒数，AMRAP 拿它当倒计时读。
    var remaining: Int { max(0, capSeconds - elapsed) }
    var isEMOM: Bool { format == .emom }
    /// EMOM 当前是第几分钟，从 1 数。
    var minute: Int { elapsed / 60 + 1 }
    var stationsComplete: Bool { !stationIDs.isEmpty && doneStations.count == stationIDs.count }

    /// 这堂课算不算做完：AMRAP 至少完成一轮、For Time 跑够规定轮数、
    /// Chipper 清单全勾；EMOM 到点即止，不判成败。
    var isComplete: Bool {
        switch format {
        case .amrap: rounds > 0
        case .forTime: plannedRounds.map { rounds >= $0 } ?? false
        case .chipper: stationsComplete
        case .emom: true
        }
    }

    /// 到 cap 时还没做完（For Time / Chipper 用）。AMRAP 自由轮数，不判。
    private(set) var cappedOut = false

    /// 成绩文案，写进 `WodResult.score`。
    var scoreText: String {
        switch format {
        case .amrap: "\(rounds) 轮"
        case .forTime, .emom: clock
        case .chipper: "\(doneStations.count)/\(stationIDs.count) 项"
        }
    }

    var clock: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

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
        rounds = 0
        doneStations = []
        cappedOut = false
    }

    /// 喂真实经过的秒数（单调不减）。到 cap 自动结束并锁成绩，返回这一跳跨过的提示点。
    @discardableResult
    mutating func advance(to seconds: Int) -> Cue {
        guard phase == .running, seconds > elapsed else { return .none }
        let target = min(seconds, capSeconds)
        let cue = Self.cue(from: elapsed, to: target, capSeconds: capSeconds, isEMOM: isEMOM)
        elapsed = target
        if elapsed >= capSeconds { finish() }
        return cue
    }

    /// AMRAP / For Time 的轮数加减。到 cap 后锁定，成绩不能再改（规格 6）。
    mutating func addRound() {
        guard phase != .finished else { return }
        rounds += 1
    }

    mutating func removeRound() {
        guard phase != .finished else { return }
        rounds = max(0, rounds - 1)
    }

    mutating func toggleStation(_ id: UUID) {
        guard phase != .finished, stationIDs.contains(id) else { return }
        if doneStations.contains(id) {
            doneStations.remove(id)
        } else {
            doneStations.insert(id)
        }
    }

    private mutating func finish() {
        phase = .finished
        cappedOut = !isComplete
    }

    /// 提示点优先级：到 cap > 跨整分 > 进入最后 10 秒。
    static func cue(from: Int, to: Int, capSeconds: Int, isEMOM: Bool) -> Cue {
        if to >= capSeconds { return .end }
        if isEMOM, to / 60 > from / 60 { return .minute }
        if to > capSeconds - 10, from <= capSeconds - 10 { return .finalTenSeconds }
        return .none
    }
}
