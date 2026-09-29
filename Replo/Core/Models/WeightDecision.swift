import Foundation
import SwiftData

/// 引擎给出的下次动作方向（规格 4.5、5.2）。`repeat` 是关键字，声明处要反引号。
enum ProgressAction: String, Codable, CaseIterable, Sendable {
    case add
    case `repeat`
    case deload

    var title: String {
        switch self {
        case .add: "加重"
        case .repeat: "原地重复"
        case .deload: "减 10% 重建"
        }
    }
}

/// 决策留痕：引擎输出的每条结论都落一条，UI 与复盘都读它（规格 4.5）。
@Model
final class WeightDecision {
    var id: UUID = UUID()
    var sessionLogId: UUID = UUID()
    /// 决策产生的时间。规格 4.5 未列，但数「连续失败」要按时间倒序翻决策，
    /// 光有 sessionLogId 得回表 join 才排得出来。
    var date: Date = Date()
    var movementId: UUID = UUID()
    var currentWeight: Double = 0
    var nextWeight: Double = 0
    var action: ProgressAction = ProgressAction.repeat
    var reasons: [String] = []
    /// 决策时是否落在警示区。规格 4.5 未列，但决策页徽章要在事后复现，加它落库更省事。
    var warning: Bool = false

    init(
        id: UUID = UUID(),
        sessionLogId: UUID,
        date: Date,
        movementId: UUID,
        currentWeight: Double,
        nextWeight: Double,
        action: ProgressAction,
        reasons: [String] = [],
        warning: Bool = false
    ) {
        self.id = id
        self.sessionLogId = sessionLogId
        self.date = date
        self.movementId = movementId
        self.currentWeight = currentWeight
        self.nextWeight = nextWeight
        self.action = action
        self.reasons = reasons
        self.warning = warning
    }
}
