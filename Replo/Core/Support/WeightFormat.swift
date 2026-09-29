import Foundation

/// 重量的统一文案。
///
/// SwiftUI 的 `Text` 插值 `Double` 会走 locale 数字格式，直接写 `\(weight)`kg
/// 会渲染成「80.000000kg」。这里统一先四舍五入到两位小数再转字符串：
/// 周平均是除出来的，浮点毛刺会显示成「73.699999999999999kg」。
enum WeightFormat {
    /// 两位小数。整数不带小数点，42.5 留一位。
    static func text(_ weight: Double) -> String {
        guard weight.isFinite else { return "—" }
        let rounded = (weight * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
