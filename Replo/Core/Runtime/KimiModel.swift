import Foundation

/// 可选的 Kimi 模型。只放实际在用的两个，不做成任意字符串。
///
/// 规格原稿写的 `moonshot-v1-8k` 已经不在开放平台的可选列表里（平台现在给的是
/// kimi-k3 / kimi-k2.7-code / kimi-k2.6 这一系），按规格「若失效按返回报错提示」
/// 的约定换成这两个：K3 是旗舰（1M 上下文），K2.6 是通用备选（256K）。
enum KimiModel: String, CaseIterable, Identifiable, Sendable {
    case k3 = "kimi-k3"
    case k26 = "kimi-k2.6"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .k3: "Kimi K3"
        case .k26: "Kimi K2.6"
        }
    }

    /// 选模型时那句人话，标明上下文量级——教练要带三份文档全文，这个数有意义。
    var note: String {
        switch self {
        case .k3: "旗舰，1M 上下文，长文档规则跟随更稳"
        case .k26: "通用，256K 上下文，够用且更省"
        }
    }

    static let fallback: KimiModel = .k3
}

/// 模型选择的持久化。不是秘密，放 UserDefaults 就够；API Key 仍然只在钥匙串。
enum KimiModelStore {
    static let defaultsKey = "replo.kimi.model"

    static func selected(in defaults: UserDefaults = .standard) -> KimiModel {
        guard let raw = defaults.string(forKey: defaultsKey),
              let model = KimiModel(rawValue: raw) else {
            return KimiModel.fallback
        }
        return model
    }

    static func save(_ model: KimiModel, to defaults: UserDefaults = .standard) {
        defaults.set(model.rawValue, forKey: defaultsKey)
    }
}
