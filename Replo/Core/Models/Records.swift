import Foundation
import SwiftData

/// WOD 成绩（规格 4.7）。
@Model
final class WodResult {
    var id: UUID = UUID()
    var wodId: UUID = UUID()
    var date: Date = Date()
    /// 轮数或总时间，如「4 轮 + 8 摆」。
    var score: String = ""
    var rpe: Int = 0
    var nextDaySoreness: String? = nil

    init(
        id: UUID = UUID(),
        wodId: UUID,
        date: Date,
        score: String,
        rpe: Int,
        nextDaySoreness: String? = nil
    ) {
        self.id = id
        self.wodId = wodId
        self.date = date
        self.score = score
        self.rpe = rpe
        self.nextDaySoreness = nextDaySoreness
    }
}

/// 晨起空腹体重（规格 4.8）。
@Model
final class BodyWeight {
    var id: UUID = UUID()
    var date: Date = Date()
    var kg: Double = 0

    init(id: UUID = UUID(), date: Date, kg: Double) {
        self.id = id
        self.date = date
        self.kg = kg
    }
}

/// 教练对话消息。v1 只读，模型不写库（规格 4.9、8）。
enum ChatRole: String, Codable, CaseIterable, Sendable {
    case user
    case assistant
}

@Model
final class KimiChatMessage {
    var id: UUID = UUID()
    var role: ChatRole = ChatRole.user
    var content: String = ""
    var createdAt: Date = Date()
    /// 属于哪一次会话。开新会话就是换一个 id：旧消息照样看得见，但不进模型上下文。
    var conversationID: UUID = KimiChatMessage.legacyConversation

    /// 这个字段是后加的，早先的消息没有它。给一个固定值，让它们归到同一次会话里，
    /// 而不是每条各自成为一次新会话。
    static let legacyConversation = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        createdAt: Date = Date(),
        conversationID: UUID = KimiChatMessage.legacyConversation
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.conversationID = conversationID
    }
}
