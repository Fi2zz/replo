import Foundation

/// 教练的 system prompt：角色设定 + 当天日期 + 文档全文（规格 8）。
enum CoachPrompt {
    /// 角色设定。规格原话：熟悉回线计划全部规则，回答不超过 150 字，先给结论。
    static let role = """
    你是 Replo 的教练，熟悉回线计划全部规则，回答不超过 150 字，先给结论。
    加重规则、警示区、每周节律、动作要领以下面文档为准；\
    用户问文档里没写的事，直接说文档里没定，不要编。
    """

    /// 发给 Moonshot 的完整 system prompt。
    /// 当天日期常驻（不受上下文开关影响）：模型唯一的真实日期锚点，
    /// 文档里的日历只是历史计划，不再标「今天」。
    /// `includePlan == false`（用户关掉「当前计划与今天安排」）时计划文档不进 prompt，
    /// 教练此时答不了计划规则类问题，按 role 设定回「文档里没定」。
    /// 规格 8 原为三份文档常驻，此处按开关语义裁剪。
    static func system(today: Date = Date(), includePlan: Bool = true) -> String {
        let dateLine = "今天是 \(DateFormat.fullText(today))。"
        let documents = includePlan ? CoachDocuments.all : CoachDocuments.withoutPlan
        return [role, dateLine, documents].joined(separator: "\n\n")
    }

    /// 用户消息：上下文前缀在前，本人问句在后（规格 8 要求拼在前缀里）。
    /// 选中动作（如有）在前缀之后、问句之前。空段不进，全空时只剩问句。
    /// 抽成函数是为了让联调用例能断言「发出去的确实是拼好的这份」。
    /// 前缀被用户全关时是空串，消息就只剩问句，不留前导空行。
    static func userMessage(context: CoachContext, question: String, movements: [String] = []) -> String {
        var parts = [context.prefix]
        if !movements.isEmpty {
            parts.append("【选中动作】\(movements.joined(separator: "、"))")
        }
        parts.append(question)
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
