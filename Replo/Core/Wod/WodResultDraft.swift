import Foundation

/// 练完一次 WOD 的回填内容。《WOD 训练手册》第七节要记的四个数：
/// 格式（由 WOD 本身决定）、成绩、RPE、次日腰膝感觉。
struct WodResultDraft: Equatable {
    var score: String
    var rpe: Int = 8
    var soreness: String = ""

    init(score: String, rpe: Int = 8, soreness: String = "") {
        self.score = score
        self.rpe = rpe
        self.soreness = soreness
    }

    /// 手册里的 RPE 8.5 封顶：滑杆最高给到 10，但默认落在 8。
    static let rpeRange = 1...10
}
