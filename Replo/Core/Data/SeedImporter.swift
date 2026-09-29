import Foundation
import SwiftData

/// 首次启动导入种子。以动作表为空作为「未导入」判据，重复调用不会产生第二份。
@MainActor
enum SeedImporter {
    static func applyOnce(to context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Movement>()) == 0 else { return }
        let bundle = SeedData.make()
        for model in bundle.models {
            context.insert(model)
        }
        try context.save()
    }
}
