import SwiftUI

/// 当前提供商的模型区：点选模型、看那句人话说明、推理档位只对认它的模型显示。
/// 换模型立刻重新装配。宿主在切换提供商时按 `.id(provider)` 重建本区。
struct ProviderModelSection: View {
    let provider: CoachProvider
    let onModelChange: (CoachModel) -> Void

    @State private var model: CoachModel

    init(provider: CoachProvider, onModelChange: @escaping (CoachModel) -> Void) {
        self.provider = provider
        self.onModelChange = onModelChange
        _model = State(initialValue: CoachModelStore.selected(provider: provider))
    }

    var body: some View {
        Section {
            if CoachLlmConfig.isModelOverridden {
                LabeledContent("模型", value: CoachLlmConfig.model)
                Label("被环境变量 KIMI_MODEL 顶掉了，这里的点选不生效。", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Picker("模型", selection: modelBinding) {
                    ForEach(provider.models) { candidate in
                        Text(candidate.title).tag(candidate)
                    }
                }
                .pickerStyle(.inline)
                Text(model.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("推理档位", value: effortText)
            }
        } header: {
            Text("模型")
        } footer: {
            Text("换模型会立刻重新装配，不用重启 App。")
        }
    }

    /// 档位只对认 `reasoning_effort` 的模型有意义，其余一个多余字段都不发。
    /// Kimi 联调可用 KIMI_REASONING_EFFORT 顶掉。
    private var effortText: String {
        guard model.acceptsReasoningEffort else { return "不适用（该模型不认这个参数）" }
        return CoachLlmConfig.reasoningEffort.rawValue
    }

    private var modelBinding: Binding<CoachModel> {
        Binding(
            get: { model },
            set: { picked in
                model = picked
                onModelChange(picked)
            }
        )
    }
}
