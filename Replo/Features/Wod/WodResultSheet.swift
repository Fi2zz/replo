import SwiftUI

/// 成绩回填：轮数/时间由状态机给出，RPE 与次日感觉由人填（规格 4.7）。
struct WodResultSheet: View {
    let wod: Wod
    let timer: WodTicker
    let onSave: (WodResultDraft) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WodResultDraft
    @State private var failure: String?

    init(wod: Wod, timer: WodTicker, onSave: @escaping (WodResultDraft) throws -> Void) {
        self.wod = wod
        self.timer = timer
        self.onSave = onSave
        _draft = State(initialValue: WodResultDraft(score: timer.timer.scoreText))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("成绩") {
                    LabeledContent(wod.format.title, value: timer.timer.scoreText)
                    TextField("轮数或时间", text: $draft.score)
                }
                Section("体感") {
                    VStack(alignment: .leading) {
                        LabeledContent("RPE", value: "\(draft.rpe)")
                        Slider(
                            value: Binding(
                                get: { Double(draft.rpe) },
                                set: { draft.rpe = Int($0.rounded()) }
                            ),
                            in: Double(WodResultDraft.rpeRange.lowerBound)...Double(WodResultDraft.rpeRange.upperBound),
                            step: 1
                        )
                    }
                    TextField("次日腰膝感觉", text: $draft.soreness, axis: .vertical)
                }
            }
            .navigationTitle("记录成绩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: save)
                }
            }
            .alert("保存失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private func save() {
        do {
            try onSave(draft)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }
}
