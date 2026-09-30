import Foundation
import SwiftUI
import SwiftusCredentials
import SwiftusLLM

/// 视图侧唯一能碰运行时的入口：装配在 `ContextTreeActor` 上做，
/// 状态回写留在 MainActor。`Task` 写全名是防将来引入伞产品时被 `SwiftusTasks.Task` 遮蔽。
@MainActor
@Observable
final class RuntimeStore {
    enum State: Equatable {
        case idle
        case ready
        case failed(String)

        var label: String {
            switch self {
            case .idle: "未装配"
            case .ready: "已就绪"
            case .failed(let reason): "装配失败：\(reason)"
            }
        }
    }

    private(set) var state: State = .idle
    /// 钥匙串里有没有 Key。界面据此显示「已保存」还是「未配置」。
    private(set) var hasKey = false
    /// 已保存 Key 的尾部几位，方便确认换没换成功。
    private(set) var keyFingerprint: String?
    /// 持有上下文树本身：装配完不能丢，释放即凭据 close、LLM 退订。
    private var runtime: ReploRuntime?

    func start() {
        refreshKeyState()
        guard case .idle = state else { return }
        boot()
    }

    /// 改完 Key 后重来一遍装配，不用重启 App。
    func restart() {
        runtime = nil
        state = .idle
        refreshKeyState()
        boot()
    }

    func refreshKeyState() {
        hasKey = KimiKeyStore.isSaved()
        keyFingerprint = KimiKeyStore.fingerprint()
    }

    /// 问教练一句。运行时装配失败、Key 缺失都原样抛给界面，不静默吞掉。
    func askCoach(context: CoachContext, question: String, conversation: [LlmMessage]) async throws -> String {
        guard let runtime else {
            throw RuntimeError.notBootstrapped
        }
        return try await runtime.ask(
            system: CoachPrompt.system,
            conversation: conversation,
            question: CoachPrompt.userMessage(context: context, question: question)
        )
    }

    enum RuntimeError: LocalizedError {
        case notBootstrapped

        var errorDescription: String? {
            "运行时还没装好。先在下面填 API Key，再点「重新装配」。"
        }
    }

    private func boot() {
        // 本闭包已继承 MainActor，写 state 无需再 hop。
        _Concurrency.Task { [weak self] in
            let booted: ReploRuntime
            do {
                booted = try await ReploRuntime.bootstrap()
            } catch {
                self?.attachFailure(error)
                return
            }
            self?.attach(booted)
        }
    }

    private func attach(_ runtime: ReploRuntime) {
        self.runtime = runtime
        state = .ready
    }

    private func attachFailure(_ error: any Error) {
        runtime = nil
        state = .failed(Self.reason(error))
    }

    /// Swiftus 的异常自带中文原因，`localizedDescription` 只会给出「error 1」这类无信息文本。
    private static func reason(_ error: any Error) -> String {
        (error as? CredentialsException)?.message ?? String(describing: error)
    }
}
