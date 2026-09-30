import SwiftUI

/// API Key、模型与运行时状态。保存后立刻重新装配，状态行会跟着变。
struct KimiSettingsSheet: View {
    let hasKey: Bool
    let fingerprint: String?
    let state: String
    let onSave: (String) -> Void
    let onClear: () -> Void
    let onModelChange: (KimiModel) -> Void
    let onReboot: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var model: KimiModel

    init(
        hasKey: Bool,
        fingerprint: String?,
        state: String,
        onSave: @escaping (String) -> Void,
        onClear: @escaping () -> Void,
        onModelChange: @escaping (KimiModel) -> Void,
        onReboot: @escaping () -> Void
    ) {
        self.hasKey = hasKey
        self.fingerprint = fingerprint
        self.state = state
        self.onSave = onSave
        self.onClear = onClear
        self.onModelChange = onModelChange
        self.onReboot = onReboot
        _model = State(initialValue: KimiModelStore.selected())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    keyField
                    Button("保存 Key", action: save)
                        .disabled(trimmed.isEmpty)
                    if hasKey {
                        Button("清除已保存的 Key", role: .destructive, action: clear)
                    }
                } header: {
                    Text("Kimi API Key")
                } footer: {
                    Text(footerText)
                }

                modelSection
                runtimeSection

                Section("会发给模型的上下文") {
                    Text("system 里是三份计划文档全文（训练计划 / WOD 手册 / 动作说明）；每次提问前在 user 消息前缀里附上最近 7 天的训练记录和当前周次。对话只读，模型没有写数据的工具。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("教练设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("好") { dismiss() }
                }
            }
        }
    }

    // MARK: - 模型

    @ViewBuilder
    private var modelSection: some View {
        Section {
            if KimiConfig.isModelOverridden {
                LabeledContent("模型", value: KimiConfig.model)
                Label("被环境变量 KIMI_MODEL 顶掉了，这里的点选不生效。", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Picker("模型", selection: modelBinding) {
                    ForEach(KimiModel.allCases) { candidate in
                        Text(candidate.title).tag(candidate)
                    }
                }
                .pickerStyle(.inline)
                Text(model.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("模型")
        } footer: {
            Text("换模型会立刻重新装配，不用重启 App。")
        }
    }

    private var modelBinding: Binding<KimiModel> {
        Binding(
            get: { model },
            set: { picked in
                model = picked
                onModelChange(picked)
            }
        )
    }

    // MARK: - 运行时

    private var runtimeSection: some View {
        Section("Swiftus 运行时") {
            LabeledContent("状态", value: state)
            LabeledContent("端点", value: KimiConfig.baseUrl)
            if KimiConfig.isBaseUrlOverridden {
                Label("已被环境变量指到本机服务，不是真 Moonshot。", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button("重新装配", action: reboot)
        }
    }

    /// 刻意用普通 `TextField` 而不是 `SecureField`。
    ///
    /// iOS 的安全输入框（`isSecureTextEntry`）是系统行为，不是 SwiftUI 的选择：
    /// 它不弹第三方输入法，也拦掉长按粘贴。Key 有五十来字符，记不住也打不动，
    /// 两条路都堵死就只能靠手抄。用普通输入框换回输入法和粘贴，
    /// 靠 `.privacySensitive()` 挡住切后台和截图时的明文——key 本身仍然只存钥匙串。
    private var keyField: some View {
        TextField("sk-…", text: $key)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .privacySensitive()
    }

    private var footerText: String {
        let stored = hasKey ? "钥匙串里已保存一把 Key（尾部 \(fingerprint ?? "…")）。" : ""
        return stored + "支持第三方输入法与粘贴；输入时不遮挡，但切后台和截图会被遮住。保存后输入框清空。"
    }

    private var trimmed: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        onSave(trimmed)
        dismiss()
    }

    private func clear() {
        onClear()
        dismiss()
    }

    private func reboot() {
        onReboot()
        dismiss()
    }
}
