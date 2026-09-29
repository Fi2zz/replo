import SwiftUI

/// 日历四色：力量红 / 高强度有氧橙 / 低强度有氧绿 / 全休灰（规格 7）。
/// 权重课两种（A/B 日）共用红色。
extension DayType {
    var tint: Color {
        switch self {
        case .dayA, .dayB: .red
        case .wod: .orange
        case .cardio: .green
        case .rest: .gray
        }
    }

    /// 图例文案，和 `tint` 一一对应。
    var legendTitle: String {
        switch self {
        case .dayA: "力量 A"
        case .dayB: "力量 B"
        case .wod: "高强度有氧"
        case .cardio: "低强度有氧"
        case .rest: "全休"
        }
    }

    /// 日历图例只要四色，力量 A/B 合并成一个色块。
    static var legend: [(dayType: DayType, title: String)] {
        [
            (.dayA, "力量"),
            (.wod, "高强度有氧"),
            (.cardio, "低强度有氧"),
            (.rest, "全休"),
        ]
    }
}
