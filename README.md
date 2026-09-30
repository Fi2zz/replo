# Replo

回线计划训练体系代码化的自用 iOS App。SwiftUI + SwiftData + CloudKit 私有库同步，
Kimi（Moonshot）对话教练经 [Swiftus](https://github.com/Fi2zz/swiftus) 的 OpenAI 兼容 wire 层调用。

当前状态：**模块 1-6（数据模型与种子、规则引擎与配重、训练课流程、WOD 计时器、日历与体重、Kimi 教练）已交付**，共 89 条用例全绿；
模块 7（CloudKit 同步）按 [docs/Replo_v1_实现委托提示词_v2.txt](docs/Replo_v1_实现委托提示词_v2.txt) 的顺序逐个填。
今日页按周节律显示今天该练什么，力量课可进入「记录 → 复盘 → 决策」三步流程并写入 `SessionLog` + `WeightDecision`。
Tab 是 今日 / 日历 / WOD / 体重 / 教练 五个。

## 快速开始

```bash
make help          # 全部目标
make test          # 模拟器上跑全部用例
make run           # 编译 → 装到已连接的手机 → 启动
```

也可以手动来：`make generate`（等价于 `xcodegen generate`）后 `open Replo.xcodeproj`。
`.xcodeproj` 是生成物，不入库；改工程配置只改 `project.yml` 后重新生成。

## 装到手机上

`make run` 自动挑第一台在线的 iPhone、推断签名团队、编译安装并启动。

- **签名团队**默认取「最近一张描述文件所属的团队」，也就是 Xcode 当前登录账号真正能签的那个；
  取不到再退到钥匙串里的 `Apple Development` 证书。想写死或换账号：把 `local.mk.example` 复制成
  `local.mk` 改 `DEVELOPMENT_TEAM`，或 `make run DEVELOPMENT_TEAM=XXXXXXXXXX`。
  报 `No Account for Team` 就是这个团队没在 Xcode → Settings → Accounts 里登录。
- **设备**默认第一台在线 iPhone，也可 `make run DEVICE=<UDID>`；`make device-list` 看有哪些。
- 手机要解锁并信任这台 Mac。

其余目标：`make install`（只装不启动）、`make run-console`（顺带把 App 的 stdout 打到终端）、
`make build`（只编模拟器包）、`make clean`。

## 填 Moonshot API Key

打开 App 的「教练」页，点右上角的钥匙图标，在 **Kimi API Key** 区块里粘贴 `sk-…` 点保存。
Key 存进钥匙串（service `com.fi2zz.replo.moonshot`，account `KIMI_API_KEY`），不落文件、不进仓库；
保存后运行时立刻重新装配，状态行应该从「装配失败：缺少凭据」变成「已就绪」。同一页也能清除已保存的 Key。

问句会自动带上最近 7 天的训练记录与当前周次（三份计划文档全文在 system prompt 里，见
`Replo/Core/Coach/CoachDocuments.swift`）。对话只读：不传 tools，模型没有写数据的手段。
发不出去时输入框上方会红字说明原因，不静默失败。

## 联调 LLM（不打真 Moonshot）

`tools/mock-kimi/mock_kimi.py` 是 OpenAI 兼容的假服务，零依赖。**它必须回 SSE**：
Swiftus 的 `chat()` 连非流式调用也走流式端点（请求体 `stream` 恒为 true），回普通 JSON
会被当成 0 个增量、得到空回答。

```bash
make mock            # 前台起服务，每个请求的 system/user 全文打到终端
make mock-fail       # 固定返回 401，验 App 的错误提示
make test-llm        # 起服务 + 跑联调用例（联调套件只在服务起着时跑）
make run-mock        # 模拟器：装好并指到本机服务
make run-mock-device MOCK_URL=http://192.168.1.5:8099/v1   # 真机走局域网地址
```

App 侧靠环境变量改端点，默认值不动：`KIMI_BASE_URL` / `KIMI_MODEL`。教练设置页会显示
当前端点，被改过还会挂一条橙色提示，免得以为在跟真 Moonshot 说话。端点被指到本机时，
钥匙串里没有 Key 会补一把占位 Key（假服务不校验 Key），干净模拟器也能直接跑。

假服务的回话会把收到的东西回述一遍——三份文档在不在 system、周次和最近 7 天记录在不在
user 前缀、历史几条——所以它同时是一份「发出去的到底是什么」的现场证据。

## 目录结构

```
Replo/
├── App/            应用入口与 TabView
├── Core/
│   ├── Models/     SwiftData 模型与容器工厂
│   ├── Data/       种子数据：动作 / 重量表 / WOD / 导入器
│   ├── Engine/     WeightEngine 规则引擎、LoadPlanner 配重、MovementSpec
│   ├── Session/    今日计划（周节律）、训练草稿、连续失败统计、热身组
│   ├── Wod/        WorkoutTimerModel 计时状态机（纯函数）、成绩回填草稿
│   ├── Calendar/   MonthGrid 月视图格子
│   ├── BodyWeight/ WeightStats 周平均与目标区间
│   ├── Coach/      教练 system prompt（三份文档全文）与训练上下文拼接
│   ├── Runtime/    Swiftus 上下文树 + 钥匙串凭据：ReploRuntime / KeychainCredentials / RuntimeStore
│   └── Support/    通用小工具
├── Features/       Today / SessionFlow / Calendar / Wod / Chat，一个 Tab 一个目录
└── Resources/      Assets.xcassets、Info.plist（由 xcodegen 生成）
ReploTests/         XCTest / swift-testing 用例
tools/mock-kimi/    LLM 联调用的假服务（Python 标准库，无依赖）
docs/               规格与接入文档
```

模块与落点：1 数据模型 + 种子 → `Core/Models` `Core/Data`；2 规则引擎 → `Core/Engine`；
3 训练课流程 → `Features/SessionFlow`；4 WOD 计时器 → `Features/Wod`（状态机在 `Core/Wod`）；5 体重 + 日历 → `Features/Weight` `Features/Calendar`（网格与统计在 `Core/Calendar` `Core/BodyWeight`）；
6 Kimi 教练 → `Features/Chat`（prompt 与上下文在 `Core/Coach`）；7 CloudKit 配置 → `ReploApp.swift` 的 `ModelContainer`。

## 已经定下来的决策

| 项 | 取值 | 原因 |
|---|---|---|
| 部署目标 | iOS 17.0 | SwiftData / Swift Charts 的地板是 17，比 Swiftus 自己声明的 16 高 |
| Swift 语言模式 | 5（`SWIFT_STRICT_CONCURRENCY: minimal`） | 规格与委托提示词写的是 Swift 5.9+；SwiftData + `@ContextTreeActor` 在 6 模式下会淹没在并发检查里 |
| Swiftus 引用方式 | 按需产品 `SwiftusCore` `SwiftusFoundation` `SwiftusCredentials` `SwiftusLLM` | 伞产品会连带 Yams/CYaml 第三方依赖，并把 `SwiftusTasks.Task` re-export 出来遮蔽 `_Concurrency.Task` |
| 凭据来源 | 钥匙串（`KeychainCredentials` 实现 Swiftus 的 `Credentials`） | 早先是沙盒里的 JSON 文件，Key 明文躺在 Application Support；换钥匙串后注入点仍只有 `ReploRuntime.bootstrap` 一处 |
| 运行时隔离 | `ReploRuntime`（`@ContextTreeActor`）持有上下文树，`RuntimeStore`（MainActor）只回写状态 | `Context` 及其成员都在框架的 global actor 上，视图层不能直接碰（见 docs/ios-接入指南.md 坑 ②） |
| 包管理 | XcodeGen + SPM over SSH | 见下 |
| 计划模板的周结构 | 一周 = 一个 `PlanWeek`，A/B 日动作合在一起 | 课型由 `Movement.pattern` 唯一决定；早先按「A、B 各存一条同周次 `PlanWeek`」实现，查 B 日动作永远查不到 |
| 周次编号 | 从 0 数起，界面显示第 N+1 周 | 和 `ActivePlan.currentWeekIndex` 对齐；早先重量表按 1 起数，`week(_:)` 查不到当周，整周动作是空的 |
| 引擎的动作类型 | 值类型 `MovementSpec`，不是 `@Model Movement` | 引擎保持纯函数，不 import SwiftData，调用方也不必为了算重量去 fetch 托管对象 |
| 配重可行性 | 每侧对称的整数背包，只往上找替代重量 | 往下退等于变相减重，减重只走引擎的 deload 规则（见 `LoadPlanner.nearestLoadable`） |
| 计划推进 | 今日页「这周练完了」按钮手动推进 | 四周表按自然周走，什么时候算一周完不猜；不塞进训练提交里，免得练一次跳一周 |
| 重量文案 | 统一走 `WeightFormat.text` | `Text` 插值 `Double` 会按 locale 格式化，直接插值会显示成「80.000000kg」 |
| 人工改重 | 只能改到「当前重量 + 类别步长」以内，超出要二次确认并把原因写进备注 | 规格 5.3：警示区不许越过步长人工加重；`LoadPlanner.nearestLoadable(upTo:)` 卡住上限 |
| 周起点 | 显式周一起，不跟设备区域设置走 | 计划的节律是周一起；跟 `firstWeekday` 走会让月视图和体重周平均整体错位一天 |
| 日期文案 | 统一走 `DateFormat`（zh_CN） | 系统是英文区域，`Date.formatted` 会渲染出「Aug 31」「Monday」 |

## 测试注意

`ReploTests/TestStore.swift` 整个测试进程只建一个 `ModelContainer`，用例之间清数据而不重建容器。
原因是实测（Xcode 26.5 / iOS 26.5 模拟器）：同一进程内每新建一个容器就往里写数据，SwiftData 会以
`EXC_BREAKPOINT` 崩掉，XCTest 报成「Restarting after unexpected exit, crash, or test timeout」。
新写用例请复用 `TestStore`，不要自己 `ModelContainer(...)`。

## 网络备注

本机 `https://github.com` 不通、SSH 通，所以 `project.yml` 里 Swiftus 走
`ssh://git@github.com/Fi2zz/swiftus.git`（tag `v0.1.0`，含间接依赖 Yams）。
已在本机 git 全局配了一条重写，让 SPM 克隆 https 源时也走 SSH：

```bash
git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
```

换到能直连 https 的网络时，删掉这条配置、把 `project.yml` 的 URL 改回 `https://` 即可。
