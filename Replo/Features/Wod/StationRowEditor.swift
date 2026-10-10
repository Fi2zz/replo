import SwiftUI

/// 单个站点的编辑行：动作从手册动作池里选（可自定义）、次数/秒数二选一，
/// EMOM 时选奇偶分钟。只编辑草稿，不含校验规则。
struct StationRowEditor: View {
    @Binding var draft: StationDraft
    let emom: Bool

    /// 名称不在动作池里（含还没填）时按自定义处理，显示自由输入框。
    @State private var customTitle: Bool

    init(draft: Binding<StationDraft>, emom: Bool) {
        _draft = draft
        self.emom = emom
        let title = draft.wrappedValue.title
        _customTitle = State(initialValue: WodMovementPool.movements.allSatisfy { $0.name != title })
    }

    var body: some View {
        VStack(spacing: 8) {
            movementRow
            if customTitle {
                TextField("动作名称", text: $draft.title)
            }
            valueRow
            if emom {
                parityRow
            }
        }
        .padding(.vertical, 2)
    }

    /// 动作池按手册四类分组；「自定义…」切回自由输入（老 WOD 的自定义动作走这条）。
    private var movementRow: some View {
        Menu {
            ForEach(WodMovementCategory.allCases, id: \.self) { category in
                Section(category.title) {
                    ForEach(WodMovementPool.movements(in: category)) { item in
                        Button(item.name) { pick(item.name) }
                    }
                }
            }
            Divider()
            Button("自定义…") { customTitle = true }
        } label: {
            HStack {
                Text(draft.title.isEmpty ? "选择动作" : draft.title)
                    .foregroundStyle(draft.title.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ name: String) {
        draft.title = name
        customTitle = false
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
            TextField(draft.kind == .reps ? "次数" : "秒数", text: valueText)
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

    private var valueText: Binding<String> {
        draft.kind == .reps ? $draft.repsText : $draft.secondsText
    }
}
