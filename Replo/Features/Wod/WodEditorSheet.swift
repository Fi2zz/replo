import SwiftUI

/// 新建/编辑 WOD 共用的表单。只编辑 `WodDraft` 拷贝，落盘方式由调用方的 `onSave` 决定。
struct WodEditorSheet: View {
    let sheetTitle: String
    let onSave: (WodDraft) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WodDraft
    @State private var failure: String?

    init(draft: WodDraft, title: String, onSave: @escaping (WodDraft) throws -> Void) {
        self.sheetTitle = title
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("名称", text: $draft.name)
                }
                Section("格式") {
                    formatPicker
                    Stepper("时间封顶 \(draft.capMinutes) 分钟", value: $draft.capMinutes, in: 5...30)
                    if draft.format == .forTime {
                        Stepper("轮数 \(draft.rounds)", value: $draft.rounds, in: 1...20)
                    }
                }
                stationSection
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: save)
                        .disabled(!draft.failureReasons.isEmpty)
                }
            }
            .alert("保存失败", isPresented: failureBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private var formatPicker: some View {
        Picker("格式", selection: $draft.format) {
            ForEach(WodFormat.allCases, id: \.self) { format in
                Text(format.title).tag(format)
            }
        }
        .pickerStyle(.segmented)
    }

    private var stationSection: some View {
        Section {
            ForEach($draft.stations) { $station in
                StationRowEditor(draft: $station, emom: draft.format == .emom)
            }
            .onDelete { draft.stations.remove(atOffsets: $0) }
            Button("添加站点") { draft.appendStation() }
        } header: {
            Text("站点")
        } footer: {
            if let reason = draft.failureReasons.first {
                Text(reason).foregroundStyle(.red)
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
