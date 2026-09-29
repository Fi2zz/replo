import Foundation

/// 一个动作在本次训练课上的草稿。字段与 `SetEntry` 一一对应，提交时直接翻译。
struct MovementDraft: Identifiable, Equatable {
    var movement: PlannedMovement
    var completedSets: Int = 0
    /// 末组实际次数；正式组打满时等于计划次数。
    var lastSetReps: Int = 0
    var rir: Int = 2
    var discomfort: Bool = false
    var rpe: Int = 7
    var note: String = ""
    /// 配重配不出时人工改的重量，改动要连原因一起记进 note。
    var manualWeight: Double?

    var id: UUID { movement.movementId }
    /// 草稿的对外身份就是动作 id，界面上到处按 id 回写。
    var movementId: UUID { movement.movementId }

    /// 本次实际练的重量：人工改过就用改的。
    var trainedWeight: Double { manualWeight ?? movement.weight }
    var plannedSets: Int { movement.sets }
    /// 组打满了才算练完这一项。
    var finished: Bool { completedSets >= movement.sets }
    /// 末组次数默认跟着计划次数走。
    var lastSetRepsOrPlanned: Int { lastSetReps == 0 ? movement.reps : lastSetReps }

    /// 本周步长：下肢 +5、上肢 +2.5。人工加重的上限，不许越过（规格 5.3）。
    var step: Double { movement.category.increment }
    /// 人工改重后能到的天花板。
    var overrideCeiling: Double { trainedWeight + step }

    var entry: SetEntry {
        SetEntry(
            movementId: movement.movementId,
            plannedSets: movement.sets,
            plannedReps: movement.reps,
            completedSets: completedSets,
            lastSetReps: lastSetRepsOrPlanned,
            rir: rir,
            discomfort: discomfort,
            rpe: rpe,
            note: note.isEmpty ? nil : note
        )
    }
}
