import Foundation
import Testing

@testable import Replo

@Suite("模型选择", .serialized)
struct KimiModelTests {
    @Test("可选模型只有 K3 与 K2.6")
    func offersTwoModels() {
        #expect(KimiModel.allCases.map(\.rawValue) == ["kimi-k3", "kimi-k2.6"])
    }

    @Test("没选过的时候用 K3")
    func defaultsToK3() throws {
        #expect(KimiModelStore.selected(in: try isolated()) == .k3)
    }

    @Test("选过之后记得住")
    func remembersSelection() throws {
        let defaults = try isolated()
        KimiModelStore.save(.k26, to: defaults)

        #expect(KimiModelStore.selected(in: defaults) == .k26)
        #expect(KimiModelStore.selected(in: try isolated()) == .k3, "另一个域不受影响")
    }

    @Test("存了个不认识的模型名就退回默认，不崩")
    func fallsBackOnUnknownValue() throws {
        let defaults = try isolated()
        defaults.set("moonshot-v1-8k", forKey: KimiModelStore.defaultsKey)

        #expect(KimiModelStore.selected(in: defaults) == .k3)
    }

    @Test("环境变量优先于点选，联调时能临时顶掉")
    func environmentWinsOverPick() throws {
        let defaults = try isolated()
        KimiModelStore.save(.k3, to: defaults)
        setenv("KIMI_MODEL", "kimi-k2.6", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(KimiConfig.model == "kimi-k2.6")
        #expect(KimiConfig.isModelOverridden)
    }

    @Test("空串不算设过，别把默认模型顶掉")
    func emptyOverrideIgnored() {
        setenv("KIMI_MODEL", "", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(KimiConfig.model == KimiModelStore.selected().rawValue)
        #expect(KimiConfig.isModelOverridden == false)
    }

    private func isolated() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "kimi-model-tests-\(UUID().uuidString)"))
    }
}
