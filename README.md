# Replo

回线计划训练体系代码化的自用 iOS App。SwiftUI + SwiftData + CloudKit 私有库同步，
Kimi（Moonshot）对话教练经 [Swiftus](https://github.com/Fi2zz/swiftus) 的 OpenAI 兼容 wire 层调用。

当前状态：**骨架已就绪**。工程能生成、能编译、能在模拟器跑起来，五个 Tab 都是占位页；
模块 1-7 按 [docs/Replo_v1_实现委托提示词_v2.txt](docs/Replo_v1_实现委托提示词_v2.txt) 的顺序逐个填。

## 快速开始

```bash
xcodegen generate          # project.yml → Replo.xcodeproj
open Replo.xcodeproj       # 选 iPhone 模拟器直接跑
```

`.xcodeproj` 是生成物，不入库；改工程配置只改 `project.yml` 后重跑 `xcodegen generate`。

## 填 API Key（你来填）

```bash
cp secrets/moonshot-key.example.json secrets/moonshot-key.json
# 编辑 secrets/moonshot-key.json，填 {"KIMI_API_KEY": "sk-…"}
scripts/install-credentials.sh      # 装进模拟器里 App 的 Application Support
```

App 读的是沙盒里的 `Application Support/moonshot-key.json`（`Replo/Core/Runtime/ReploRuntime.swift`）。
填好后重启 App，「教练」页的运行时状态会从「装配失败：缺少凭据」变成「已就绪」。
`secrets/*.json` 已在 `.gitignore` 里，key 不会进仓库。真机的 Keychain 入口属于模块 6。

## 目录结构

```
Replo/
├── App/            应用入口与 TabView
├── Core/
│   ├── Runtime/    Swiftus 上下文树：ReploRuntime(@ContextTreeActor) / KimiConfig / RuntimeStore
│   └── Support/    通用小工具
├── Features/       Today / Calendar / Wod / Weight / Chat，一个 Tab 一个目录
└── Resources/      Assets.xcassets、Info.plist（由 xcodegen 生成）
ReploTests/         XCTest / swift-testing 用例
docs/               规格与接入文档
```

模块与落点：1 数据模型 + 种子 → `Core/Models` `Core/Data`；2 规则引擎 → `Core/Engine`；
3 训练课流程 → `Features/SessionFlow`；4 WOD 计时器 → `Features/Wod`；5 体重 + 日历 → `Features/Weight` `Features/Calendar`；
6 Kimi 教练 → `Features/Chat`；7 CloudKit 配置 → `ReploApp.swift` 的 `ModelContainer`。

## 骨架里已经定下来的决策

| 项 | 取值 | 原因 |
|---|---|---|
| 部署目标 | iOS 17.0 | SwiftData / Swift Charts 的地板是 17，比 Swiftus 自己声明的 16 高 |
| Swift 语言模式 | 5（`SWIFT_STRICT_CONCURRENCY: minimal`） | 规格与委托提示词写的是 Swift 5.9+；SwiftData + `@ContextTreeActor` 在 6 模式下会淹没在并发检查里 |
| Swiftus 引用方式 | 按需产品 `SwiftusCore` `SwiftusFoundation` `SwiftusCredentials` `SwiftusLLM` | 伞产品会连带 Yams/CYaml 第三方依赖，并把 `SwiftusTasks.Task` re-export 出来遮蔽 `_Concurrency.Task` |
| 凭据来源 | 文件（Application Support） | Swiftus 没有 Keychain 来源；模块 6 换成自实现 `Credentials` 协议的 Keychain 版，注入点只有一处 |
| 运行时隔离 | `ReploRuntime`（`@ContextTreeActor`）持有上下文树，`RuntimeStore`（MainActor）只回写状态 | `Context` 及其成员都在框架的 global actor 上，视图层不能直接碰（见 docs/ios-接入指南.md 坑 ②） |
| 包管理 | XcodeGen + SPM over SSH | 见下 |

## 网络备注

本机 `https://github.com` 不通、SSH 通，所以 `project.yml` 里 Swiftus 走
`ssh://git@github.com/Fi2zz/swiftus.git`（tag `v0.1.0`，含间接依赖 Yams）。
已在本机 git 全局配了一条重写，让 SPM 克隆 https 源时也走 SSH：

```bash
git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
```

换到能直连 https 的网络时，删掉这条配置、把 `project.yml` 的 URL 改回 `https://` 即可。
