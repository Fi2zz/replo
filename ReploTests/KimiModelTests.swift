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

    @Test("K3 带 reasoning_effort=high")
    func k3SendsHighEffort() {
        setenv("KIMI_MODEL", "kimi-k3", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(KimiConfig.requestOptions?["reasoning_effort"]?.stringValue == "high")
    }

    @Test("K2.6 一个多余字段都不发，免得服务端不认")
    func k26SendsNoOptions() {
        setenv("KIMI_MODEL", "kimi-k2.6", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(KimiConfig.requestOptions == nil)
    }

    @Test("档位可以临时顶掉，认不出的值退回默认")
    func effortOverride() {
        setenv("KIMI_MODEL", "kimi-k3", 1)
        setenv("KIMI_REASONING_EFFORT", "low", 1)
        defer {
            unsetenv("KIMI_MODEL")
            unsetenv("KIMI_REASONING_EFFORT")
        }
        #expect(KimiConfig.requestOptions?["reasoning_effort"]?.stringValue == "low")

        setenv("KIMI_REASONING_EFFORT", "medium", 1)
        #expect(KimiConfig.reasoningEffort == .high, "认不出就退回默认 high")
    }

    @Test("默认档位是 high")
    func defaultEffortIsHigh() {
        unsetenv("KIMI_REASONING_EFFORT")
        #expect(KimiConfig.reasoningEffort == .high)
        #expect(ReasoningEffort.fallback == .high)
    }

    private func isolated() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "kimi-model-tests-\(UUID().uuidString)"))
    }
}
