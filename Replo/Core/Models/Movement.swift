import Foundation
import SwiftData

/// 动作类别：加重步长与警示区判断的依据（规格 3、5.2）。
enum MovementCategory: String, Codable, CaseIterable, Sendable {
    case lower
    case upper

    var title: String {
        switch self {
        case .lower: "下肢"
        case .upper: "上肢"
        }
    }

    /// 每周加重步长：下肢 +5kg、上肢 +2.5kg（规格 5.2 规则 5、5.5 周封顶）。
    var increment: Double {
        self == .lower ? 5 : 2.5
    }
}

/// 动作归属的训练日。
enum DayPattern: String, Codable, CaseIterable, Sendable {
    case dayA
    case dayB

    var title: String {
        switch self {
        case .dayA: "A 日"
        case .dayB: "B 日"
        }
    }
}

/// 动作定义。种子数据，只读（规格 4.1）。
@Model
final class Movement {
    var id: UUID = UUID()
    var name: String = ""
    var category: MovementCategory = MovementCategory.lower
    var pattern: DayPattern = DayPattern.dayA

    init(id: UUID = UUID(), name: String, category: MovementCategory, pattern: DayPattern) {
        self.id = id
        self.name = name
        self.category = category
        self.pattern = pattern
    }
}
