import SwiftUI

/// 动作池多选：按手册四类分组，已选的打勾，再点取消。
struct MovementPickerSheet: View {
    @Binding var selected: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(WodMovementCategory.allCases, id: \.self) { category in
                    Section(category.title) {
                        ForEach(WodMovementPool.movements(in: category)) { item in
                            row(item.name)
                        }
                    }
                }
            }
            .navigationTitle("选动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ name: String) -> some View {
        Button {
            toggle(name)
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if selected.contains(name) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.removeAll { $0 == name }
        } else {
            selected.append(name)
        }
    }
}
