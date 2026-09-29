import Foundation
import SwiftData

/// WOD 格式（规格 4.6、6）。
enum WodFormat: String, Codable, CaseIterable, Sendable {
    case amrap
    case emom
    case forTime
    case chipper

    var title: String {
        switch self {
        case .amrap: "AMRAP"
        case .emom: "EMOM"
        case .forTime: "For Time"
        case .chipper: "Chipper"
        }
    }
}

/// EMOM 里动作落在奇数分钟还是偶数分钟。其余格式为 nil。
enum MinuteParity: String, Codable, CaseIterable, Sendable {
    case odd
    case even

    var title: String {
        self == .odd ? "奇数分钟" : "偶数分钟"
    }
}

/// WOD 里的一个站点。次数型填 `reps`，秒数型填 `durationSeconds`（规格 4.6）。
struct Station: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var reps: Int?
    var durationSeconds: Int?
    var parity: MinuteParity?

    /// 清单与计时器上的展示文案，如「壶铃摆动 × 8」「战绳 30 秒」。
    var summary: String {
        guard let reps else {
            guard let durationSeconds else { return title }
            return "\(title) \(durationSeconds) 秒"
        }
        return "\(title) × \(reps)"
    }
}

/// WOD 定义。种子数据，只读（规格 4.6）。
@Model
final class Wod {
    var id: UUID = UUID()
    var name: String = ""
    var format: WodFormat = WodFormat.amrap
    var timeCapSeconds: Int = 0
    /// For Time 的规定轮数；AMRAP 自由轮数、Chipper 清单轮次为 nil。
    var rounds: Int? = nil
    var stations: [Station] = []

    init(
        id: UUID = UUID(),
        name: String,
        format: WodFormat,
        timeCapSeconds: Int,
        rounds: Int? = nil,
        stations: [Station] = []
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.timeCapSeconds = timeCapSeconds
        self.rounds = rounds
        self.stations = stations
    }
}
