import Foundation

/// 发给教练的上下文里带多少历史训练记录（规格 8）。用户可选，默认最近 7 天。
enum CoachHistoryMode: String, CaseIterable, Identifiable, Sendable {
    /// 最近 7 天的全部训练课（现状）。
    case lastWeek
    /// 只带最近一次训练课，不管隔了多久。
    case lastSession
    /// 完全不带训练记录。
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastWeek: "最近 7 天"
        case .lastSession: "仅上次训练"
        case .none: "不带历史"
        }
    }

    /// 选档位时那句人话，说明这一档教练能看到什么。
    var note: String {
        switch self {
        case .lastWeek: "教练能看到这 7 天的每一节课，适合正常跟练"
        case .lastSession: "只给最近一次课，轻装提问，也省 token"
        case .none: "只看计划和今天安排，回答不参考你的实际完成"
        }
    }

    /// 前缀里训练记录段的标题（`.none` 不出这段，用不到）。
    var sectionTitle: String {
        switch self {
        case .lastWeek: "最近 7 天训练记录"
        case .lastSession: "上次训练"
        case .none: ""
        }
    }

    /// 该档窗口内一节课都没有时的空态文案（`.none` 用不到）。
    var emptyText: String {
        switch self {
        case .lastWeek: "（这 7 天没有训练记录）"
        case .lastSession: "（还没有训练记录）"
        case .none: ""
        }
    }

    static let fallback: CoachHistoryMode = .lastWeek
}

/// 历史参考档位的持久化。不是秘密，放 UserDefaults；设置面板和对话页 chip 共享这份。
enum CoachHistoryModeStore {
    static let defaultsKey = "replo.coach.historyMode"

    static func selected(in defaults: UserDefaults = .standard) -> CoachHistoryMode {
        guard let raw = defaults.string(forKey: defaultsKey),
              let mode = CoachHistoryMode(rawValue: raw) else {
            return CoachHistoryMode.fallback
        }
        return mode
    }

    static func save(_ mode: CoachHistoryMode, to defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: defaultsKey)
    }
}

/// 「当前计划与今天安排」是否进上下文的持久化，默认带。与历史档位同属参考范围设置。
enum CoachPlanReferenceStore {
    static let defaultsKey = "replo.coach.includePlan"

    /// 没设过就当带：`object(forKey:)` 未设值时返回 nil，不能用 `bool(forKey:)`（缺省会读出 false）。
    static func planIncluded(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func savePlanIncluded(_ included: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(included, forKey: defaultsKey)
    }
}
