import Foundation
import SwiftData

/// 全部模型与容器工厂。模块 7 接 CloudKit 私有库时只改 `makeContainer` 里的 configuration。
enum ReploSchema {
    static let models: [any PersistentModel.Type] = [
        Movement.self,
        PlanTemplate.self,
        ActivePlan.self,
        SessionLog.self,
        WeightDecision.self,
        Wod.self,
        WodResult.self,
        BodyWeight.self,
        KimiChatMessage.self,
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
