import Foundation
import Testing

@testable import Replo

@Suite("提供商与模型选择", .serialized)
struct CoachProviderTests {
    @Test("提供商就三家：Kimi、豆包、DeepSeek")
    func offersThreeProviders() {
        #expect(CoachProvider.allCases == [.kimi, .doubao, .deepseek])
    }

    @Test("没选过的时候用 Kimi")
    func defaultsToKimi() throws {
        #expect(CoachProviderStore.selected(in: try isolated()) == .kimi)
    }

    @Test("选过提供商记得住，不认识的值退回 Kimi")
    func remembersProvider() throws {
        let defaults = try isolated()
        CoachProviderStore.save(.deepseek, to: defaults)

        #expect(CoachProviderStore.selected(in: defaults) == .deepseek)
        #expect(CoachProviderStore.selected(in: try isolated()) == .kimi, "另一个域不受影响")

        defaults.set("openai", forKey: CoachProviderStore.defaultsKey)
        #expect(CoachProviderStore.selected(in: defaults) == .kimi)
    }

    @Test("三家预设模型清单：防手滑改错 ID")
    func modelCatalog() {
        #expect(CoachProvider.kimi.models.map(\.id) == ["kimi-k3", "kimi-k2.6"])
        #expect(CoachProvider.doubao.models.map(\.id) == ["doubao-seed-1-6-250615", "doubao-seed-1-6-flash-250828"])
        #expect(CoachProvider.deepseek.models.map(\.id) == ["deepseek-chat", "deepseek-reasoner"])
    }

    @Test("每个提供商各自记模型，互不干扰")
    func modelSelectionPerProvider() throws {
        let defaults = try isolated()
        #expect(CoachModelStore.selected(provider: .kimi, in: defaults).id == "kimi-k3")
        #expect(CoachModelStore.selected(provider: .doubao, in: defaults).id == "doubao-seed-1-6-250615")
        #expect(CoachModelStore.selected(provider: .deepseek, in: defaults).id == "deepseek-chat")

        CoachModelStore.save(CoachProvider.kimi.models[1], provider: .kimi, to: defaults)

        #expect(CoachModelStore.selected(provider: .kimi, in: defaults).id == "kimi-k2.6")
        #expect(CoachModelStore.selected(provider: .doubao, in: defaults).id == "doubao-seed-1-6-250615", "别家的选择不受影响")
    }

    @Test("kimi 沿用旧键名，升级前存的 kimi-k2.6 还能读出来")
    func legacyKimiModelKeyStillReads() throws {
        let defaults = try isolated()
        defaults.set("kimi-k2.6", forKey: "replo.kimi.model")

        #expect(CoachModelStore.selected(provider: .kimi, in: defaults).id == "kimi-k2.6")
    }

    @Test("存了个不认识的模型名就退回这家默认，不崩")
    func fallsBackOnUnknownModel() throws {
        let defaults = try isolated()
        defaults.set("moonshot-v1-8k", forKey: CoachProvider.kimi.modelDefaultsKey)

        #expect(CoachModelStore.selected(provider: .kimi, in: defaults).id == "kimi-k3")
    }

    @Test("环境变量优先于点选（仅 kimi），联调时能临时顶掉")
    func environmentWinsOverPick() throws {
        let restore = pinProvider(.kimi)
        defer { restore() }
        setenv("KIMI_MODEL", "kimi-k2.6", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(CoachLlmConfig.model == "kimi-k2.6")
        #expect(CoachLlmConfig.isModelOverridden)
    }

    @Test("选了别家之后 KIMI_MODEL 不生效，免得 mock 通道串到真服务")
    func environmentIgnoredForOtherProviders() throws {
        let restore = pinProvider(.doubao)
        defer { restore() }
        setenv("KIMI_MODEL", "kimi-k2.6", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(CoachLlmConfig.model == "doubao-seed-1-6-250615")
        #expect(CoachLlmConfig.isModelOverridden == false)
    }

    @Test("空串不算设过，别把默认模型顶掉")
    func emptyOverrideIgnored() throws {
        let restore = pinProvider(.kimi)
        defer { restore() }
        setenv("KIMI_MODEL", "", 1)
        defer { unsetenv("KIMI_MODEL") }

        #expect(CoachLlmConfig.model == CoachModelStore.selected(provider: .kimi).id)
        #expect(CoachLlmConfig.isModelOverridden == false)
    }

    @Test("K3 带 reasoning_effort=high；K2.6 与豆包、DeepSeek 一个多余字段都不发")
    func requestOptionsOnlyForK3() throws {
        let restore = pinProvider(.kimi)
        defer { restore() }
        setenv("KIMI_MODEL", "kimi-k3", 1)
        #expect(CoachLlmConfig.requestOptions?["reasoning_effort"]?.stringValue == "high")

        setenv("KIMI_MODEL", "kimi-k2.6", 1)
        #expect(CoachLlmConfig.requestOptions == nil)
        unsetenv("KIMI_MODEL")

        CoachProviderStore.save(.doubao)
        #expect(CoachLlmConfig.requestOptions == nil, "豆包的模型不认 reasoning_effort")
        CoachProviderStore.save(.deepseek)
        #expect(CoachLlmConfig.requestOptions == nil, "DeepSeek 的模型不认 reasoning_effort")
    }

    @Test("档位可以临时顶掉，认不出的值退回默认")
    func effortOverride() throws {
        let restore = pinProvider(.kimi)
        defer { restore() }
        setenv("KIMI_MODEL", "kimi-k3", 1)
        setenv("KIMI_REASONING_EFFORT", "low", 1)
        defer {
            unsetenv("KIMI_MODEL")
            unsetenv("KIMI_REASONING_EFFORT")
        }
        #expect(CoachLlmConfig.requestOptions?["reasoning_effort"]?.stringValue == "low")

        setenv("KIMI_REASONING_EFFORT", "medium", 1)
        #expect(CoachLlmConfig.reasoningEffort == .high, "认不出就退回默认 high")
    }

    @Test("默认档位是 high")
    func defaultEffortIsHigh() {
        unsetenv("KIMI_REASONING_EFFORT")
        #expect(CoachLlmConfig.reasoningEffort == .high)
        #expect(ReasoningEffort.fallback == .high)
    }

    private func isolated() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "coach-provider-tests-\(UUID().uuidString)"))
    }

    /// `CoachLlmConfig` 读的是 `.standard` 里的提供商选择：用例先把提供商钉住，
    /// 跑完还原，免得模拟器里点过的选择串进断言。
    private func pinProvider(_ provider: CoachProvider) -> () -> Void {
        let previous = UserDefaults.standard.string(forKey: CoachProviderStore.defaultsKey)
        CoachProviderStore.save(provider)
        return {
            if let previous {
                UserDefaults.standard.set(previous, forKey: CoachProviderStore.defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: CoachProviderStore.defaultsKey)
            }
        }
    }
}
