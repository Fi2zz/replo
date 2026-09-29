import SwiftusLLM

/// Moonshot 端点与模型（规格第 8 节）。`credentialKey` 对应凭据源里的键名。
enum KimiConfig {
    static let credentialKey = "KIMI_API_KEY"
    static let baseUrl = "https://api.moonshot.cn/v1"
    static let model = "moonshot-v1-8k"

    static func openAi() -> OpenAiConfig {
        var config = OpenAiConfig(name: "kimi", baseUrl: baseUrl, model: model)
        config.credentialKey = credentialKey
        return config
    }
}
