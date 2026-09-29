import Foundation
import SwiftData

/// 托管对象到引擎输入的转换。放在引擎外面，`WeightEngine` 本身不 import SwiftData。
extension Movement {
    var spec: MovementSpec {
        MovementSpec(name: name, category: category, pattern: pattern)
    }
}
