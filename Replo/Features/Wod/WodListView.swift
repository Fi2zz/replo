import SwiftData
import SwiftUI

/// WOD 库：8 个内置 WOD，点进去开计时器（规格 6）。
struct WodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wod.name) private var wods: [Wod]
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(wods) { wod in
                    NavigationLink {
                        WodTimerView(wod: wod)
                    } label: {
                        WodRow(wod: wod)
                    }
                }
            }
            .navigationTitle("WOD")
            .task { importSeeds() }
            .alert("种子导入失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
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

private struct WodRow: View {
    let wod: Wod

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(wod.name)
                    .font(.headline)
                Spacer()
                Text(wod.format.title)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.5), in: .capsule)
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

    private var roundsText: String {
        guard let rounds = wod.rounds else { return "" }
        return " · \(rounds) 轮"
    }
}
