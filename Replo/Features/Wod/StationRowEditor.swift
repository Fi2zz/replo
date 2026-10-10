import SwiftUI

/// 单个站点的编辑行：名称、次数/秒数二选一，EMOM 时选奇偶分钟。只编辑草稿，不含校验规则。
struct StationRowEditor: View {
    @Binding var draft: StationDraft
    let emom: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField("动作名称", text: $draft.title)
            valueRow
            if emom {
                parityRow
            }
        }
        .padding(.vertical, 2)
    }

    private var valueRow: some View {
        HStack {
            Picker("计量", selection: $draft.kind) {
                ForEach(StationDraft.Kind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            TextField(kind == .reps ? "次数" : "秒数", text: valueText)
                .keyboardType(.numberPad)
        }
    }

    private var parityRow: some View {
        Picker("分钟", selection: $draft.parity) {
            ForEach(MinuteParity.allCases, id: \.self) { parity in
                Text(parity.title).tag(parity)
            }
        }
        .pickerStyle(.segmented)
    }

    private var kind: StationDraft.Kind {
        draft.kind
    }

    private var valueText: Binding<String> {
        draft.kind == .reps ? $draft.repsText : $draft.secondsText
    }
}
