import Foundation
import SwiftusLLM

/// Moonshot 端点与模型（规格第 8 节）。`credentialKey` 对应凭据源里的键名。
enum KimiConfig {
    static let credentialKey = "KIMI_API_KEY"
    /// 钥匙串里这一项的 service，删 Key 也按它删。
    static let keychainService = "com.fi2zz.replo.moonshot"

    /// 默认端点。联调时用环境变量指向本机假服务（`make run-mock`），不改这份默认值。
    static let defaultBaseUrl = "https://api.moonshot.cn/v1"
    static let defaultModel = "moonshot-v1-8k"

    static var baseUrl: String {
        overridden("KIMI_BASE_URL") ?? defaultBaseUrl
    }

    static var model: String {
        overridden("KIMI_MODEL") ?? defaultModel
    }

    /// 端点被环境变量改过：界面上要能看出来，免得以为在跟真 Moonshot 说话。
    static var isOverridden: Bool {
        overridden("KIMI_BASE_URL") != nil || overridden("KIMI_MODEL") != nil
    }

    static func openAi() -> OpenAiConfig {
        var config = OpenAiConfig(name: "kimi", baseUrl: baseUrl, model: model)
        config.credentialKey = credentialKey
        return config
    }

    /// 空串当作没设，免得 `KIMI_BASE_URL=` 反而把默认端点顶掉。
    private static func overridden(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else { return nil }
        return value
    }
}
