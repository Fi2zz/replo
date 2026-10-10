import Foundation

/// 手册动作池的类别（《WOD 训练手册》第三节：一次 WOD 从四类里各取 1 个）。
enum WodMovementCategory: String, CaseIterable, Sendable {
    case hinge
    case push
    case squat
    case conditioning

    var title: String {
        switch self {
        case .hinge: "hinge（髋铰链）"
        case .push: "推"
        case .squat: "蹲"
        case .conditioning: "心肺·核心"
        }
    }
}

/// 动作池里的一个动作。
struct WodPoolMovement: Equatable, Identifiable, Sendable {
    var name: String
    var category: WodMovementCategory

    var id: String { name }
}

/// 《WOD 训练手册》动作池：就这些，全在小空间内原地完成。
/// 源码常量（与 CoachDocuments 同思路）：内容是训练体系本身，编译期可见。
/// WOD 编辑器、TABATA 计时器、教练对话页的「选动作」共用这一份。
enum WodMovementPool {
    static let movements: [WodPoolMovement] = [
        WodPoolMovement(name: "壶铃摆动", category: .hinge),
        WodPoolMovement(name: "俯卧撑", category: .push),
        WodPoolMovement(name: "单臂壶铃推举", category: .push),
        WodPoolMovement(name: "高脚杯深蹲", category: .squat),
        WodPoolMovement(name: "自重深蹲", category: .squat),
        WodPoolMovement(name: "战绳", category: .conditioning),
        WodPoolMovement(name: "登山跑", category: .conditioning),
        WodPoolMovement(name: "平板支撑", category: .conditioning),
    ]

    static func movements(in category: WodMovementCategory) -> [WodPoolMovement] {
        movements.filter { $0.category == category }
    }

    /// 手册默认：TABATA 只用战绳（摆动疲劳易伤腰，跑步机间歇易摔）。
    static let defaultTabataMovement = "战绳"

    /// TABATA 成绩的固定 wodId。TABATA 不进 WOD 库，成绩仍复用 WodResult，
    /// 用这个固定 id 与库内 WOD 区分；日历按日期标记，不受影响。
    static let tabataWodID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001") ?? UUID()
}
