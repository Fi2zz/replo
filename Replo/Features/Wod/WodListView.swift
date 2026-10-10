import SwiftData
import SwiftUI

/// WOD 库：内置 8 个种子 + 用户自建，点进去开计时器。自建的带徽章，可滑动编辑/删除（规格 6）。
struct WodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wod.name) private var wods: [Wod]
    @State private var failure: String?
    @State private var creating = false
    @State private var editing: EditTarget?

    var body: some View {
        NavigationStack {
            List {
                Section("WOD 库") {
                    ForEach(wods) { wod in
                        row(for: wod)
                    }
                }
            }
            .navigationTitle("WOD")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建 WOD", systemImage: "plus") { creating = true }
                }
            }
            .sheet(isPresented: $creating, content: createSheet)
            .sheet(item: $editing, content: editSheet)
            .task { importSeeds() }
            .alert("操作失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private func row(for wod: Wod) -> some View {
        NavigationLink {
            WodTimerView(wod: wod)
        } label: {
            WodRow(wod: wod)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if wod.isCustom {
                Button("删除", role: .destructive) { delete(wod) }
                Button("编辑") { editing = EditTarget(wod: wod) }
                    .tint(.orange)
            }
        }
    }

    private func createSheet() -> some View {
        WodEditorSheet(draft: createDraft, title: "新建 WOD") { draft in
            modelContext.insert(draft.makeWod())
            try modelContext.save()
        }
    }

    private func editSheet(_ target: EditTarget) -> some View {
        WodEditorSheet(draft: WodDraft(wod: target.wod), title: "编辑 WOD") { draft in
            draft.applyTo(target.wod)
            try modelContext.save()
        }
    }

    /// 手册的命名习惯：按序号起「WOD 9、WOD 10……」，用户可改。
    private var createDraft: WodDraft {
        var draft = WodDraft()
        draft.name = "WOD \(wods.count + 1)"
        return draft
    }

    private func delete(_ wod: Wod) {
        modelContext.delete(wod)
        do {
            try modelContext.save()
        } catch {
            failure = String(describing: error)
        }
    }

    private func importSeeds() {
        guard failure == nil else { return }
        do {
            try SeedImporter.applyOnce(to: modelContext)
        } catch {
            failure = String(describing: error)
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }
}

/// `.sheet(item:)` 的包装：编辑目标是一次性的，免得用布尔状态记两份。
private struct EditTarget: Identifiable {
    let wod: Wod
    var id: UUID { wod.id }
}

private struct WodRow: View {
    let wod: Wod

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(wod.name)
                    .font(.headline)
                Spacer()
                if wod.isCustom {
                    badge("自定义")
                }
                badge(wod.format.title)
            }
            Text("\(wod.timeCapSeconds / 60) 分钟封顶\(roundsText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(wod.stations.map(\.summary).joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.5), in: .capsule)
    }

    private var roundsText: String {
        guard let rounds = wod.rounds else { return "" }
        return " · \(rounds) 轮"
    }
}
