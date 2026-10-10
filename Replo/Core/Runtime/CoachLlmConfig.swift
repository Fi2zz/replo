import Foundation
import SwiftusCore
import SwiftusLLM

/// 教练 LLM 的端点与模型配置，全部按当前选中的提供商取值（规格第 8 节）。
/// 环境变量覆盖是 Kimi 专属的联调通道（`make run-mock`），其余两家没有。
enum CoachLlmConfig {
    static var provider: CoachProvider {
        CoachProviderStore.selected()
    }

    static var baseUrl: String {
        overridden("KIMI_BASE_URL") ?? provider.defaultBaseUrl
    }

    /// 模型：kimi 联调可用环境变量顶掉 > 设置页点选的 > 默认。
    static var model: String {
        overridden("KIMI_MODEL") ?? CoachModelStore.selected(provider: provider).id
    }

    /// 推理档位：联调用环境变量顶掉 > 默认 high。只对认这个参数的模型有意义。
    static var reasoningEffort: ReasoningEffort {
        guard let raw = overridden("KIMI_REASONING_EFFORT"),
              let effort = ReasoningEffort(rawValue: raw) else {
            return ReasoningEffort.fallback
        }
        return effort
    }

    /// 端点或模型被环境变量改过：界面上要能看出来，免得以为在跟真服务说话。
    static var isOverridden: Bool {
        isBaseUrlOverridden || isModelOverridden
    }

    static var isBaseUrlOverridden: Bool {
        overridden("KIMI_BASE_URL") != nil
    }

    static var isModelOverridden: Bool {
        overridden("KIMI_MODEL") != nil
    }

    /// 要并进请求体顶层的字段。当前模型不认就返回 nil，一个多余字段都不发。
    static var requestOptions: [String: JSONValue]? {
        guard let current = provider.models.first(where: { $0.id == model }),
              current.acceptsReasoningEffort else {
            return nil
        }
        return ["reasoning_effort": .string(reasoningEffort.rawValue)]
    }

    static func openAi() -> OpenAiConfig {
        var config = OpenAiConfig(name: provider.rawValue, baseUrl: baseUrl, model: model)
        config.credentialKey = provider.credentialKey
        return config
    }

    /// 空串当作没设，免得 `KIMI_BASE_URL=` 反而把默认端点顶掉。
    private static func overridden(_ key: String) -> String? {
        guard provider.honorsEnvironmentOverride,
              let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else { return nil }
        return value
    }
}

/// 推理档位。Kimi K3 支持 `low` / `high` / `max`，官方默认是 `max`。
///
/// 这里的默认取 `high`：教练的活是「先给结论、不超过 150 字」，满档推理对这种
/// 问法收益有限，却要等更久、花更多 token。其余模型不收这个参数，见
/// `CoachModel.acceptsReasoningEffort`。
enum ReasoningEffort: String, CaseIterable, Sendable {
    case low
    case high
    case max

    static let fallback: ReasoningEffort = .high
}
