import Foundation
import SwiftData

/// 一次训练课的课型。`rest` 仅占位，日历上用（规格 4.4）。
enum DayType: String, Codable, CaseIterable, Sendable {
    case dayA
    case dayB
    case wod
    case cardio
    case rest

    var title: String {
        switch self {
        case .dayA: "A 日"
        case .dayB: "B 日"
        case .wod: "WOD"
        case .cardio: "有氧"
        case .rest: "全休"
        }
    }
}

/// 一次训练课里单个动作的记录（规格 4.4）。
struct SetEntry: Codable, Equatable {
    var movementId: UUID = UUID()
    var plannedSets: Int = 0
    var plannedReps: Int = 0
    var completedSets: Int = 0
    /// 末组实际次数，完整完成时等于 `plannedReps`。
    var lastSetReps: Int = 0
    var rir: Int = 0
    var discomfort: Bool = false
    var rpe: Int = 0
    var note: String?
}

/// 训练记录（规格 4.4）。
@Model
final class SessionLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var dayType: DayType = DayType.dayA
    var entries: [SetEntry] = []
    /// WOD 课填写，力量课为空。
    var wodId: UUID? = nil
    var wodScore: String? = nil

    init(
        id: UUID = UUID(),
        date: Date,
        dayType: DayType,
        entries: [SetEntry] = [],
        wodId: UUID? = nil,
        wodScore: String? = nil
    ) {
        self.id = id
        self.date = date
        self.dayType = dayType
        self.entries = entries
        self.wodId = wodId
        self.wodScore = wodScore
    }
}
