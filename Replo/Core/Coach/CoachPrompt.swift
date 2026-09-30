import Foundation

/// 教练的 system prompt：角色设定 + 三份文档全文（规格 8）。
enum CoachPrompt {
    /// 角色设定。规格原话：熟悉回线计划全部规则，回答不超过 150 字，先给结论。
    static let role = """
    你是 Replo 的教练，熟悉回线计划全部规则，回答不超过 150 字，先给结论。
    加重规则、警示区、每周节律、动作要领以下面三份文档为准；\
    用户问计划里没写的事，直接说文档里没定，不要编。
    """

    /// 发给 Moonshot 的完整 system prompt。
    static var system: String {
        [role, CoachDocuments.all].joined(separator: "\n\n")
    }

    /// 用户消息：上下文前缀在前，本人问句在后（规格 8 要求拼在前缀里）。
    /// 抽成函数是为了让联调用例能断言「发出去的确实是拼好的这份」。
    static func userMessage(context: CoachContext, question: String) -> String {
        [context.prefix, question].joined(separator: "\n\n")
    }
}
