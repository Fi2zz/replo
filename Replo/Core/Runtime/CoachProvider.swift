import Foundation

/// 教练对话可用的 LLM 提供商。三家都是 OpenAI 兼容协议，运行时统一走
/// `OpenAiCompatibleProvider`，差异全部收敛在 `profile` 这张表里。
enum CoachProvider: String, CaseIterable, Identifiable, Sendable {
    case kimi
    case doubao
    case deepseek

    var id: String { rawValue }

    // REASON: 静态映射表 —— 提供商元数据天然是一张表，一处说清三家差异，比散开的 switch 易读。
    var profile: CoachProviderProfile {
        switch self {
        case .kimi: .kimi
        case .doubao: .doubao
        case .deepseek: .deepseek
        }
    }

    var title: String { profile.title }
    var defaultBaseUrl: String { profile.defaultBaseUrl }
    var credentialKey: String { profile.credentialKey }
    var keychainService: String { profile.keychainService }
    var modelDefaultsKey: String { profile.modelDefaultsKey }
    var models: [CoachModel] { profile.models }
    var fallbackModel: CoachModel { profile.models[0] }

    /// 环境变量覆盖（联调 mock）只对 Kimi 开放，其余两家没有这条通道。
    var honorsEnvironmentOverride: Bool { self == .kimi }
}

/// 一家提供商的全部差异：界面标题、端点、凭据键名、钥匙串 service、模型清单。
struct CoachProviderProfile: Sendable {
    let title: String
    /// 设置页 Key 区的 footer：去哪个控制台拿 Key。
    let keyConsoleHint: String
    let defaultBaseUrl: String
    /// 凭据源（钥匙串快照）里的键名。
    let credentialKey: String
    /// 钥匙串 service。kimi 沿用旧的 Moonshot 名字，老用户的 Key 无感保留。
    let keychainService: String
    /// 各自记住各自选过的模型；kimi 沿用旧键名，升级前存的选择不丢。
    let modelDefaultsKey: String
    let models: [CoachModel]
}

extension CoachProviderProfile {
    static let kimi = CoachProviderProfile(
        title: "Kimi（月之暗面）",
        keyConsoleHint: "去 platform.moonshot.cn 的「API Key 管理」拿一把。",
        defaultBaseUrl: "https://api.moonshot.cn/v1",
        credentialKey: "KIMI_API_KEY",
        keychainService: "com.fi2zz.replo.moonshot",
        modelDefaultsKey: "replo.kimi.model",
        models: [
            CoachModel(id: "kimi-k3", title: "Kimi K3", note: "旗舰，1M 上下文，长文档规则跟随更稳", acceptsReasoningEffort: true),
            CoachModel(id: "kimi-k2.6", title: "Kimi K2.6", note: "通用，256K 上下文，够用且更省"),
        ]
    )

    /// 方舟模型 ID 参照官方模型列表（volcengine.com/docs/82379/1554679）；
    /// 失效就按服务端返回的报错提示，改这里即可。
    static let doubao = CoachProviderProfile(
        title: "豆包（火山方舟）",
        keyConsoleHint: "去火山方舟控制台的「API Key 管理」拿一把，并在「开通管理」里开通所选模型。",
        defaultBaseUrl: "https://ark.cn-beijing.volces.com/api/v3",
        credentialKey: "DOUBAO_API_KEY",
        keychainService: "com.fi2zz.replo.doubao",
        modelDefaultsKey: "replo.doubao.model",
        models: [
            CoachModel(id: "doubao-seed-1-6-250615", title: "Doubao Seed 1.6", note: "旗舰，256K 上下文，需在方舟控制台开通"),
            CoachModel(id: "doubao-seed-1-6-flash-250828", title: "Doubao Seed 1.6 Flash", note: "轻快省钱，日常问答够用"),
        ]
    )

    static let deepseek = CoachProviderProfile(
        title: "DeepSeek",
        keyConsoleHint: "去 platform.deepseek.com 的「API keys」拿一把。",
        defaultBaseUrl: "https://api.deepseek.com/v1",
        credentialKey: "DEEPSEEK_API_KEY",
        keychainService: "com.fi2zz.replo.deepseek",
        modelDefaultsKey: "replo.deepseek.model",
        models: [
            CoachModel(id: "deepseek-chat", title: "DeepSeek Chat", note: "V3.2 非思考模式，快且省"),
            CoachModel(id: "deepseek-reasoner", title: "DeepSeek Reasoner", note: "思考型，先推一遍再答，更慢更贵"),
        ]
    )
}

/// 一个可选模型。`id` 就是发给服务端的模型名。
struct CoachModel: Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    /// 选模型时那句人话，标明上下文量级或开通前提。
    let note: String
    /// 能不能收请求顶层的 `reasoning_effort`。官方文档明说各模型参数配置不同，
    /// 不认这个字段的模型一个多余字段都不发。
    var acceptsReasoningEffort = false
}

/// 提供商选择的持久化。不是秘密，放 UserDefaults 就够；API Key 仍然只在钥匙串。
enum CoachProviderStore {
    static let defaultsKey = "replo.coach.provider"

    static func selected(in defaults: UserDefaults = .standard) -> CoachProvider {
        guard let raw = defaults.string(forKey: defaultsKey),
              let provider = CoachProvider(rawValue: raw) else {
            return .kimi
        }
        return provider
    }

    static func save(_ provider: CoachProvider, to defaults: UserDefaults = .standard) {
        defaults.set(provider.rawValue, forKey: defaultsKey)
    }
}

/// 每个提供商各自记住选中的模型；存了个不认识的名字就退回这家默认，不崩。
enum CoachModelStore {
    static func selected(provider: CoachProvider, in defaults: UserDefaults = .standard) -> CoachModel {
        guard let raw = defaults.string(forKey: provider.modelDefaultsKey),
              let model = provider.models.first(where: { $0.id == raw }) else {
            return provider.fallbackModel
        }
        return model
    }

    static func save(_ model: CoachModel, provider: CoachProvider, to defaults: UserDefaults = .standard) {
        defaults.set(model.id, forKey: provider.modelDefaultsKey)
    }
}
