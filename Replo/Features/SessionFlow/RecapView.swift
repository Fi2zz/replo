import SwiftUI

/// 复盘页：每个动作记余力、不适、主观强度、末组次数和备注（规格 7）。
struct RecapView: View {
    let drafts: [MovementDraft]
    let onRecap: (UUID, RecapChange) -> Void

    var body: some View {
        List {
            ForEach(drafts) { draft in
                Section {
                    rirPicker(draft)
                    discomfortToggle(draft)
                    rpeSlider(draft)
                    lastSetStepper(draft)
                    noteField(draft)
                } header: {
                    RecapHeader(draft: draft)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func rirPicker(_ draft: MovementDraft) -> some View {
        Stepper(value: Binding(
            get: { draft.rir },
            set: { onRecap(draft.id, RecapChange(rir: $0)) }
        ), in: 0...5) {
            LabeledContent("余力 RIR", value: "\(draft.rir) 次")
        }
    }

    private func discomfortToggle(_ draft: MovementDraft) -> some View {
        Toggle(isOn: Binding(
            get: { draft.discomfort },
            set: { onRecap(draft.id, RecapChange(discomfort: $0)) }
        )) {
            Text("出现腰膝 / 关节不适")
        }
    }

    private func rpeSlider(_ draft: MovementDraft) -> some View {
        VStack(alignment: .leading) {
            LabeledContent("主观强度 RPE", value: "\(draft.rpe)")
            Slider(
                value: Binding(
                    get: { Double(draft.rpe) },
                    set: { onRecap(draft.id, RecapChange(rpe: Int($0.rounded()))) }
                ),
                in: 1...10,
                step: 1
            )
        }
    }

    private func lastSetStepper(_ draft: MovementDraft) -> some View {
        Stepper(value: Binding(
            get: { draft.lastSetRepsOrPlanned },
            set: { onRecap(draft.id, RecapChange(lastSetReps: $0)) }
        ), in: 0...draft.movement.reps) {
            LabeledContent("末组次数", value: "\(draft.lastSetRepsOrPlanned) / \(draft.movement.reps)")
        }
    }

    private func noteField(_ draft: MovementDraft) -> some View {
        TextField(
            "备注：动作感受、换重原因",
            text: Binding(
                get: { draft.note },
                set: { onRecap(draft.id, RecapChange(note: $0)) }
            ),
            axis: .vertical
        )
        .lineLimit(1...3)
    }
}

/// 复盘改动按字段打包，避免 `onRecap` 挂七个可选参数。
struct RecapChange {
    var rir: Int?
    var discomfort: Bool?
    var rpe: Int?
    var lastSetReps: Int?
    var note: String?

    init(
        rir: Int? = nil,
        discomfort: Bool? = nil,
        rpe: Int? = nil,
        lastSetReps: Int? = nil,
        note: String? = nil
    ) {
        self.rir = rir
        self.discomfort = discomfort
        self.rpe = rpe
        self.lastSetReps = lastSetReps
        self.note = note
    }
}

private struct RecapHeader: View {
    let draft: MovementDraft

    var body: some View {
        HStack {
            Text(draft.movement.name)
            Spacer()
            Text("\(draft.completedSets)/\(draft.movement.sets) 组 · \(WeightFormat.text(draft.trainedWeight))kg")
                .font(.caption.monospacedDigit())
                .foregroundStyle(draft.finished ? .green : .secondary)
        }
    }
}
