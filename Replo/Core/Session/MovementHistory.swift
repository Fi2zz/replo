import Foundation
import SwiftData

/// 引擎要的历史上下文：上次练这个动作的日期、连续未通过次数。
/// 两者都从库里查出来传给引擎，引擎自己不碰 SwiftData。
struct MovementHistory: Equatable {
    var lastSessionDate: Date?
    var failStreak: Int

    static let none = MovementHistory(lastSessionDate: nil, failStreak: 0)
}

/// 从历史记录里数「连续失败」：从最近一次决策往回数，碰到加重或降级就停
/// （降级已经把 failStreak 清零了），中间连续的原地重复就是次数。
enum FailStreak {
    /// `decisions` 必须按时间从新到旧排好，调用方用决策日期排。
    /// 最新一条是加重或降级就说明已经清零，只有开头连续的原地重复才计数。
    static func count(for movementId: UUID, in decisions: [WeightDecision]) -> Int {
        let trail = decisions.filter { $0.movementId == movementId }
        guard trail.first?.action == .repeat else { return 0 }
        return trail.prefix { $0.action == .repeat }.count
    }

    /// 同样地取最近一次训练日期，早于 `date` 的才算。
    static func lastSessionDate(for movementId: UUID, in logs: [SessionLog], before date: Date) -> Date? {
        logs
            .filter { $0.date < date }
            .filter { log in log.entries.contains { $0.movementId == movementId } }
            .map(\.date)
            .max()
    }

    /// 每个动作一份历史，喂给 `SessionStore`。
    static func histories(
        movementIds: [UUID],
        logs: [SessionLog],
        decisions: [WeightDecision],
        before date: Date
    ) -> [UUID: MovementHistory] {
        let sorted = decisions
            .filter { $0.date < date }
            .sorted { $0.date > $1.date }
        return Dictionary(uniqueKeysWithValues: movementIds.map { id in
            let streak = count(for: id, in: sorted)
            let last = lastSessionDate(for: id, in: logs, before: date)
            return (id, MovementHistory(lastSessionDate: last, failStreak: streak))
        })
    }
}
