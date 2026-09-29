import Foundation
import SwiftUI
import SwiftusCredentials

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
    /// 持有上下文树本身：装配完不能丢，释放即凭据 close、LLM 退订。
    private var runtime: ReploRuntime?

    func start() {
        guard case .idle = state else { return }
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
