import SwiftUI

/// 训练页的单项：热身提示 → 正式组逐组打勾。
struct MovementLoggingView: View {
    let draft: MovementDraft
    let onCompleteSet: () -> Void
    let onUndoSet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            warmup
            setButtons
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(draft.movement.name)
                .font(.headline)
            Text("\(draft.movement.weightText)kg \(draft.movement.sets)×\(draft.movement.reps)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            if draft.finished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private var warmup: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("热身组")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(WarmupPlan.steps(for: draft.movement)) { step in
                    Text(step.caption)
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.5), in: .capsule)
                }
            }
        }
    }

    private var setButtons: some View {
        HStack(spacing: 8) {
            ForEach(1...max(draft.movement.sets, 1), id: \.self) { index in
                Button {
                    if index <= draft.completedSets {
                        onUndoSet()
                    } else if index == draft.completedSets + 1 {
                        onCompleteSet()
                    }
                } label: {
                    Text("\(index)")
                        .font(.body.monospacedDigit())
                        .frame(width: 44, height: 44)
                        .background(background(for: index), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(index > draft.completedSets + 1)
            }
            Spacer()
        }
    }

    private func background(for index: Int) -> Color {
        if index <= draft.completedSets { return .green.opacity(0.25) }
        if index == draft.completedSets + 1 { return .accentColor.opacity(0.2) }
        return .secondary.opacity(0.12)
    }
}
