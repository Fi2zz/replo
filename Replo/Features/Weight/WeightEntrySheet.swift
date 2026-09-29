import SwiftUI

/// 称重录入。默认今天、默认上一次的重量，改个数字就能存。
struct WeightEntrySheet: View {
    let existing: [WeightEntry]
    let onSave: (WeightEntry) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kgText: String
    @State private var failure: String?

    init(existing: [WeightEntry], onSave: @escaping (WeightEntry) throws -> Void) {
        self.existing = existing
        self.onSave = onSave
        let last = existing.sorted { $0.date > $1.date }.first?.kg
        _kgText = State(initialValue: last.map { WeightFormat.text($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("晨起空腹") {
                    TextField("体重 kg", text: $kgText)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                }
                Section("目标") {
                    LabeledContent("区间", value: "\(WeightFormat.text(WeightStats.targetRange.lowerBound))-\(WeightFormat.text(WeightStats.targetRange.upperBound))kg")
                    LabeledContent("每周", value: "\(WeightFormat.text(WeightStats.weeklyLossRange.lowerBound))-\(WeightFormat.text(WeightStats.weeklyLossRange.upperBound))kg")
                }
            }
            .navigationTitle("记一次体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: save)
                        .disabled(kg == nil)
                }
            }
            .alert("保存失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private var kg: Double? {
        Double(kgText.trimmingCharacters(in: .whitespaces))
    }

    private func save() {
        guard let kg else { return }
        do {
            try onSave(WeightEntry(date: Date(), kg: kg))
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }
}
