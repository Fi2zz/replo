# WOD 动作选择 + 独立 TABATA 计时器 + 教练对话带动作 · 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WOD 编辑器站点动作改为从手册动作池点选（可自定义）；新增独立 TABATA 计时器（参数可配、记成绩）；教练对话页可选动作随消息发出。

**Architecture:** 动作池是源码常量（同 `CoachDocuments` 思路），三处共用。TABATA 不进 `WodFormat`：独立 `TabataTimerModel` 纯状态机 + `TabataTicker` 外壳（复刻 `WodTicker` 模式），成绩复用 `WodResult`（固定虚拟 wodId）。对话页动作用于 `CoachPrompt.userMessage` 新增的 `movements` 参数。无 SwiftData schema 变更，无迁移。

**Tech Stack:** SwiftUI / SwiftData / Swift Testing，iOS 17，xcodegen（`make test` 自动重生成工程，新文件按目录收录无需改 project.yml）。

**规格文档:** `docs/superpowers/specs/2026-10-10-wod-movement-picker-tabata-design.md`

---

### Task 1: 动作池 `WodMovementPool`

**Files:**
- Create: `Replo/Core/Wod/WodMovementPool.swift`
- Test: `ReploTests/WodMovementPoolTests.swift`

- [ ] **Step 1: 写失败的测试**

新建 `ReploTests/WodMovementPoolTests.swift`：

```swift
import Testing

@testable import Replo

@Suite("WOD 动作池")
struct WodMovementPoolTests {
    @Test("手册动作池：四类 8 个动作")
    func poolMatchesManual() {
        #expect(WodMovementPool.movements.count == 8)
        #expect(WodMovementPool.movements(in: .hinge).map(\.name) == ["壶铃摆动"])
        #expect(WodMovementPool.movements(in: .push).map(\.name) == ["俯卧撑", "单臂壶铃推举"])
        #expect(WodMovementPool.movements(in: .squat).map(\.name) == ["高脚杯深蹲", "自重深蹲"])
        #expect(WodMovementPool.movements(in: .conditioning).map(\.name) == ["战绳", "登山跑", "平板支撑"])
    }

    @Test("TABATA 默认动作是战绳，成绩 id 是固定值")
    func tabataDefaults() {
        #expect(WodMovementPool.defaultTabataMovement == "战绳")
        #expect(WodMovementPool.tabataWodID.uuidString == "AAAAAAAA-0000-0000-0000-000000000001")
    }
}
```

- [ ] **Step 2: 跑测试确认编译失败**

Run: `make test`
Expected: 编译错误 `cannot find 'WodMovementPool' in scope`

- [ ] **Step 3: 实现动作池**

新建 `Replo/Core/Wod/WodMovementPool.swift`：

```swift
import Foundation

/// 手册动作池的类别（《WOD 训练手册》第三节：一次 WOD 从四类里各取 1 个）。
enum WodMovementCategory: String, CaseIterable, Sendable {
    case hinge
    case push
    case squat
    case conditioning

    var title: String {
        switch self {
        case .hinge: "hinge（髋铰链）"
        case .push: "推"
        case .squat: "蹲"
        case .conditioning: "心肺·核心"
        }
    }
}

/// 动作池里的一个动作。
struct WodPoolMovement: Equatable, Identifiable, Sendable {
    var name: String
    var category: WodMovementCategory

    var id: String { name }
}

/// 《WOD 训练手册》动作池：就这些，全在小空间内原地完成。
/// 源码常量（与 CoachDocuments 同思路）：内容是训练体系本身，编译期可见。
/// WOD 编辑器、TABATA 计时器、教练对话页的「选动作」共用这一份。
enum WodMovementPool {
    static let movements: [WodPoolMovement] = [
        WodPoolMovement(name: "壶铃摆动", category: .hinge),
        WodPoolMovement(name: "俯卧撑", category: .push),
        WodPoolMovement(name: "单臂壶铃推举", category: .push),
        WodPoolMovement(name: "高脚杯深蹲", category: .squat),
        WodPoolMovement(name: "自重深蹲", category: .squat),
        WodPoolMovement(name: "战绳", category: .conditioning),
        WodPoolMovement(name: "登山跑", category: .conditioning),
        WodPoolMovement(name: "平板支撑", category: .conditioning),
    ]

    static func movements(in category: WodMovementCategory) -> [WodPoolMovement] {
        movements.filter { $0.category == category }
    }

    /// 手册默认：TABATA 只用战绳（摆动疲劳易伤腰，跑步机间歇易摔）。
    static let defaultTabataMovement = "战绳"

    /// TABATA 成绩的固定 wodId。TABATA 不进 WOD 库，成绩仍复用 WodResult，
    /// 用这个固定 id 与库内 WOD 区分；日历按日期标记，不受影响。
    static let tabataWodID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001") ?? UUID()
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `make test`
Expected: `Test run with 169 tests ... passed`（原 167 + 新 2）

- [ ] **Step 5: 提交**

```bash
git add Replo/Core/Wod/WodMovementPool.swift ReploTests/WodMovementPoolTests.swift
git commit -m "feat(wod): 手册动作池常量，编辑器/TABATA/教练页共用"
```

---

### Task 2: TABATA 状态机 `TabataTimerModel`

**Files:**
- Create: `Replo/Core/Wod/TabataTimerModel.swift`
- Test: `ReploTests/TabataTimerTests.swift`

- [ ] **Step 1: 写失败的测试**

新建 `ReploTests/TabataTimerTests.swift`：

```swift
import Testing

@testable import Replo

@Suite("TABATA 计时状态机")
struct TabataTimerModelTests {
    private func model(work: Int = 20, rest: Int = 10, rounds: Int = 8) -> TabataTimerModel {
        TabataTimerModel(workSeconds: work, restSeconds: rest, totalRounds: rounds)
    }

    @Test("总时长 = (工作 + 休息) × 轮数")
    func totalSecondsAddsUp() {
        #expect(model().totalSeconds == 240)
    }

    @Test("工作段→休息段→下一轮，段边界给提示")
    func segmentTransitions() {
        var timer = model()
        timer.start()

        #expect(timer.segment == .work)
        #expect(timer.currentRound == 1)
        #expect(timer.advance(to: 19) == .none)
        #expect(timer.segmentRemaining == 1)

        #expect(timer.advance(to: 20) == .segment)
        #expect(timer.segment == .rest)
        #expect(timer.segmentRemaining == 10)

        #expect(timer.advance(to: 30) == .segment)
        #expect(timer.segment == .work)
        #expect(timer.currentRound == 2)
    }

    @Test("进入段末 3 秒给提示")
    func finalThreeCue() {
        var timer = model()
        timer.start()

        #expect(timer.advance(to: 16) == .none)
        #expect(timer.advance(to: 17) == .finalThree)
        #expect(timer.advance(to: 18) == .none)
    }

    @Test("跑满 8 轮自动结束，成绩记完整工作段数")
    func finishAtEnd() {
        var timer = model()
        timer.start()

        #expect(timer.advance(to: 240) == .end)
        #expect(timer.phase == .finished)
        #expect(timer.scoreText == "完成 8/8 轮")
    }

    @Test("中途停下：成绩只记已完成的工作段")
    func partialScore() {
        var timer = model()
        timer.start()
        timer.advance(to: 65)  // 第 3 轮工作段中（60-80）

        #expect(timer.completedRounds == 2)
        #expect(timer.scoreText == "完成 2/8 轮")
    }

    @Test("暂停后喂时间不推进，恢复后继续")
    func pauseFreezes() {
        var timer = model()
        timer.start()
        timer.advance(to: 5)
        timer.pause()

        #expect(timer.advance(to: 10) == .none)
        #expect(timer.elapsed == 5)

        timer.start()
        #expect(timer.advance(to: 10) == .none)
        #expect(timer.elapsed == 10)
    }

    @Test("重置回 ready，归零")
    func resetClears() {
        var timer = model()
        timer.start()
        timer.advance(to: 30)
        timer.reset()

        #expect(timer.phase == .ready)
        #expect(timer.elapsed == 0)
        #expect(timer.scoreText == "完成 0/8 轮")
    }

    @Test("结束后不再推进")
    func finishedLocks() {
        var timer = model()
        timer.start()
        timer.advance(to: 240)

        #expect(timer.advance(to: 300) == .none)
        #expect(timer.elapsed == 240)
    }

    @Test("一大跳跨多段只报一个换段提示")
    func bigJumpReportsOneCue() {
        var timer = model()
        timer.start()

        #expect(timer.advance(to: 95) == .segment)
        #expect(timer.currentRound == 4)
        #expect(timer.segment == .work)
    }
}
```

- [ ] **Step 2: 跑测试确认编译失败**

Run: `make test`
Expected: 编译错误 `cannot find 'TabataTimerModel' in scope`

- [ ] **Step 3: 实现状态机**

新建 `Replo/Core/Wod/TabataTimerModel.swift`：

```swift
import Foundation

/// TABATA 间歇计时状态机：工作段 / 休息段交替，跑满轮数自动结束。
/// 与 WorkoutTimerModel 同风格：外部 ticker 按秒喂真实经过时间，自身不读系统时钟。
struct TabataTimerModel: Equatable {
    /// 当前处在工作段还是休息段。
    enum Segment: Equatable {
        case work, rest

        var title: String { self == .work ? "WORK" : "REST" }
    }

    /// 一次推进跨过的提示点，界面据此发声、震动。
    enum Cue: Equatable {
        case none
        /// 跨过段边界（工作→休息，或休息→下一轮工作）。
        case segment
        /// 进入当前段最后 3 秒。
        case finalThree
        /// 全部轮数跑完。
        case end
    }

    enum Phase: Equatable {
        case ready, running, paused, finished
    }

    let workSeconds: Int
    let restSeconds: Int
    let totalRounds: Int

    private(set) var phase: Phase = .ready
    private(set) var elapsed: Int = 0

    init(workSeconds: Int = 20, restSeconds: Int = 10, totalRounds: Int = 8) {
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.totalRounds = totalRounds
    }

    // MARK: - 派生

    var totalSeconds: Int { cycleSeconds * totalRounds }
    /// 当前第几轮，从 1 数。
    var currentRound: Int { min(elapsed / cycleSeconds + 1, totalRounds) }
    var segment: Segment { segmentOrdinal(at: elapsed) % 2 == 0 ? .work : .rest }
    /// 当前段还剩几秒。
    var segmentRemaining: Int { segmentRemaining(at: elapsed) }
    /// 已完成的完整工作段数；成绩按它记。
    var completedRounds: Int {
        guard elapsed >= workSeconds else { return 0 }
        return min((elapsed - workSeconds) / cycleSeconds + 1, totalRounds)
    }
    /// 成绩文案，写进 WodResult.score。
    var scoreText: String { "完成 \(completedRounds)/\(totalRounds) 轮" }

    // MARK: - 走时

    mutating func start() {
        guard phase == .ready || phase == .paused else { return }
        phase = .running
    }

    mutating func pause() {
        guard phase == .running else { return }
        phase = .paused
    }

    mutating func reset() {
        phase = .ready
        elapsed = 0
    }

    /// 喂真实经过的秒数（单调不减）。跑满总时长自动结束，返回这一跳跨过的提示点。
    @discardableResult
    mutating func advance(to seconds: Int) -> Cue {
        guard phase == .running, seconds > elapsed else { return .none }
        let target = min(seconds, totalSeconds)
        let cue = cue(from: elapsed, to: target)
        elapsed = target
        if elapsed >= totalSeconds { phase = .finished }
        return cue
    }

    private var cycleSeconds: Int { workSeconds + restSeconds }

    /// 段序号：第 n 轮的工作段是 2(n-1)，休息段是 2(n-1)+1。
    private func segmentOrdinal(at seconds: Int) -> Int {
        seconds / cycleSeconds * 2 + (seconds % cycleSeconds < workSeconds ? 0 : 1)
    }

    private func segmentRemaining(at seconds: Int) -> Int {
        let within = seconds % cycleSeconds
        return within < workSeconds ? workSeconds - within : cycleSeconds - within
    }

    /// 提示点优先级：结束 > 跨段 > 进入段末 3 秒。
    private func cue(from: Int, to: Int) -> Cue {
        if to >= totalSeconds { return .end }
        if segmentOrdinal(at: to) > segmentOrdinal(at: from) { return .segment }
        if segmentRemaining(at: from) > 3, segmentRemaining(at: to) <= 3 { return .finalThree }
        return .none
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `make test`
Expected: `Test run with 178 tests ... passed`（169 + 新 9）

- [ ] **Step 5: 提交**

```bash
git add Replo/Core/Wod/TabataTimerModel.swift ReploTests/TabataTimerTests.swift
git commit -m "feat(wod): TABATA 间歇计时状态机"
```

---

### Task 3: 成绩 sheet 泛化 `WodResultSheet`

`WodResultSheet` 目前绑死 `Wod` + `WodTicker`，泛化成只收标题与成绩文案，TABATA 才能复用。

**Files:**
- Modify: `Replo/Features/Wod/WodResultSheet.swift`
- Modify: `Replo/Features/Wod/WodTimerView.swift:28-32`

- [ ] **Step 1: 改 `WodResultSheet`**

`Replo/Features/Wod/WodResultSheet.swift` 的存储属性与 init 改为：

```swift
/// 成绩回填：轮数/时间由状态机给出，RPE 与次日感觉由人填（规格 4.7）。
struct WodResultSheet: View {
    let formatTitle: String
    let scoreText: String
    let onSave: (WodResultDraft) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WodResultDraft
    @State private var failure: String?

    init(formatTitle: String, scoreText: String, onSave: @escaping (WodResultDraft) throws -> Void) {
        self.formatTitle = formatTitle
        self.scoreText = scoreText
        self.onSave = onSave
        _draft = State(initialValue: WodResultDraft(score: scoreText))
    }
```

body 里「成绩」Section 那行改为：

```swift
LabeledContent(formatTitle, value: scoreText)
```

其余（体感 Section、toolbar、save、failureBinding）不动。

- [ ] **Step 2: 改 `WodTimerView` 调用点**

`Replo/Features/Wod/WodTimerView.swift` 的 sheet 改为：

```swift
.sheet(isPresented: $isRecording) {
    WodResultSheet(formatTitle: wod.format.title, scoreText: ticker.timer.scoreText) { result in
        try save(result)
    }
}
```

- [ ] **Step 3: 跑测试确认全绿（纯重构，行为不变）**

Run: `make test`
Expected: `Test run with 178 tests ... passed`

- [ ] **Step 4: 提交**

```bash
git add Replo/Features/Wod/WodResultSheet.swift Replo/Features/Wod/WodTimerView.swift
git commit -m "refactor(wod): 成绩 sheet 与 Wod/WodTicker 解耦，供 TABATA 复用"
```

---

### Task 4: TABATA 外壳 `TabataTicker` + 计时页 + WOD 库入口

**Files:**
- Create: `Replo/Features/Wod/TabataTicker.swift`
- Create: `Replo/Features/Wod/TabataTimerView.swift`
- Modify: `Replo/Features/Wod/WodListView.swift:14-17`

外壳与页面是 UI 层，项目无 UI 测试惯例，验证靠编译 + 模拟器手测（Step 4）。

- [ ] **Step 1: 新建 `Replo/Features/Wod/TabataTicker.swift`**

```swift
import AudioToolbox
import Foundation
import Observation
import UIKit

/// TABATA 计时器外壳：拿真实经过的时间喂状态机，负责发声与震动。
/// 与 WodTicker 同一套接缝：暂停冻结、恢复按起点对齐，不做 += 1 累加。
@MainActor
@Observable
final class TabataTicker {
    private(set) var timer: TabataTimerModel
    private(set) var lastCue: TabataTimerModel.Cue = .none
    private(set) var isRunning = false

    private var task: _Concurrency.Task<Void, Never>?
    private var startedAt: Date?
    private var frozenElapsed = 0

    init(model: TabataTimerModel) {
        self.timer = model
    }

    func start() {
        guard !isRunning, timer.phase != .finished else { return }
        timer.start()
        isRunning = true
        startedAt = Date()
        scheduleTick()
    }

    func pause() {
        guard isRunning else { return }
        frozenElapsed = timer.elapsed
        stopTask()
        timer.pause()
        isRunning = false
    }

    /// 现在过了多少秒：暂停时用冻结值，运行时按起点对齐。
    private var trueElapsed: Int {
        guard let startedAt else { return frozenElapsed }
        return frozenElapsed + Int(Date().timeIntervalSince(startedAt))
    }

    private func scheduleTick() {
        task?.cancel()
        task = _Concurrency.Task { [weak self] in
            while let self, !_Concurrency.Task.isCancelled {
                try? await _Concurrency.Task.sleep(for: .milliseconds(200))
                guard !_Concurrency.Task.isCancelled else { return }
                self.tick()
                if self.timer.phase == .finished { self.isRunning = false }
            }
        }
    }

    private func tick() {
        let cue = timer.advance(to: trueElapsed)
        guard cue != .none else { return }
        lastCue = cue
        play(cue)
    }

    /// 换段：提示音 + 轻震动；段末 3 秒只提示音；全部跑完两样都来。
    private func play(_ cue: TabataTimerModel.Cue) {
        switch cue {
        case .none:
            break
        case .segment:
            AudioServicesPlaySystemSound(WodTicker.cueSoundID)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .finalThree:
            AudioServicesPlaySystemSound(WodTicker.cueSoundID)
        case .end:
            AudioServicesPlaySystemSound(WodTicker.cueSoundID)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func stopTask() {
        task?.cancel()
        task = nil
        startedAt = nil
    }
}
```

- [ ] **Step 2: 新建 `Replo/Features/Wod/TabataTimerView.swift`**

```swift
import SwiftData
import SwiftUI

/// TABATA 计时页：开场调参数（动作 / 工作 / 休息 / 轮数），计时中显示段与轮次，
/// 结束记成绩。手册：TABATA 与 WOD 二选一，默认战绳 20 秒 / 10 秒 × 8 轮。
struct TabataTimerView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var movement = WodMovementPool.defaultTabataMovement
    @State private var workSeconds = 20
    @State private var restSeconds = 10
    @State private var rounds = 8
    @State private var ticker: TabataTicker?
    @State private var isRecording = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let ticker {
                    runningPanel(ticker)
                } else {
                    setupPanel
                }
            }
            .padding()
        }
        .navigationTitle("TABATA")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isRecording, content: resultSheet)
    }

    // MARK: - 参数

    private var setupPanel: some View {
        VStack(spacing: 16) {
            Picker("动作", selection: $movement) {
                ForEach(WodMovementPool.movements) { item in
                    Text(item.name).tag(item.name)
                }
            }
            Stepper("工作 \(workSeconds) 秒", value: $workSeconds, in: 5...60)
            Stepper("休息 \(restSeconds) 秒", value: $restSeconds, in: 5...60)
            Stepper("\(rounds) 轮", value: $rounds, in: 1...20)
            Text("手册默认战绳 20 秒 / 10 秒 × 8 轮；壶铃摆动和跑步机不做 TABATA（伤腰 / 易摔）。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("开始", action: start)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 计时

    private func runningPanel(_ ticker: TabataTicker) -> some View {
        VStack(spacing: 16) {
            Text(ticker.timer.segment.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(ticker.timer.segment == .work ? Color.green : Color.orange)
            Text(segmentClock(ticker.timer))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("第 \(ticker.timer.currentRound) / \(ticker.timer.totalRounds) 轮 · \(movement)")
                .font(.callout)
                .foregroundStyle(.secondary)
            transport(ticker)
        }
    }

    private func transport(_ ticker: TabataTicker) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(ticker.isRunning ? "暂停" : "继续") {
                    ticker.isRunning ? ticker.pause() : ticker.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ticker.timer.phase == .finished)

                Button("重置") { self.ticker = nil }
                    .buttonStyle(.bordered)
            }
            if ticker.timer.phase == .finished {
                Button("记录成绩") { isRecording = true }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func resultSheet() -> some View {
        WodResultSheet(formatTitle: "TABATA", scoreText: ticker?.timer.scoreText ?? "") { draft in
            try save(draft)
        }
    }

    private func start() {
        let model = TabataTimerModel(
            workSeconds: workSeconds, restSeconds: restSeconds, totalRounds: rounds
        )
        let created = TabataTicker(model: model)
        ticker = created
        created.start()
    }

    /// 成绩带上动作名，历史里看得出练的是什么（如「战绳 · 完成 8/8 轮」）。
    private func save(_ draft: WodResultDraft) throws {
        let result = WodResult(
            wodId: WodMovementPool.tabataWodID,
            date: Date(),
            score: "\(movement) · \(draft.score)",
            rpe: draft.rpe,
            nextDaySoreness: draft.soreness.isEmpty ? nil : draft.soreness
        )
        modelContext.insert(result)
        try modelContext.save()
    }

    private func segmentClock(_ timer: TabataTimerModel) -> String {
        String(format: "%d:%02d", timer.segmentRemaining / 60, timer.segmentRemaining % 60)
    }
}
```

注：成绩保存失败的提示由 `WodResultSheet` 自己的 alert 负责，本页不再重复。

- [ ] **Step 3: `WodListView` 加固定入口**

`Replo/Features/Wod/WodListView.swift` 的 `List` 改为：

```swift
List {
    Section("间歇") {
        NavigationLink {
            TabataTimerView()
        } label: {
            Label("TABATA 计时", systemImage: "timer")
        }
    }
    Section("WOD 库") {
        ForEach(wods) { wod in
            row(for: wod)
        }
    }
}
```

- [ ] **Step 4: 编译 + 模拟器手测**

Run: `make test`
Expected: `Test run with 178 tests ... passed`

手测（`make build` + `xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/Replo.app` + launch，或 `make run-mock`）：
- WOD 页顶部出现「TABATA 计时」，进入后可调参数，点开始计时，20s 换 REST 有提示音，到 240s 自动结束
- 结束后「记录成绩」保存成功；日历当天出现已训练标记

- [ ] **Step 5: 提交**

```bash
git add Replo/Features/Wod/TabataTicker.swift Replo/Features/Wod/TabataTimerView.swift Replo/Features/Wod/WodListView.swift
git commit -m "feat(wod): 独立 TABATA 计时器，WOD 页顶部入口，成绩入 WodResult"
```

---

### Task 5: 编辑器站点选动作 `StationRowEditor`

**Files:**
- Modify: `Replo/Features/Wod/StationRowEditor.swift`

回归保证：`ReploTests/WodDraftTests.swift` 现有用例全绿（`StationDraft`/`WodDraft` 不动）。

- [ ] **Step 1: 名称输入框换成动作池 Menu**

`Replo/Features/Wod/StationRowEditor.swift` 完整替换为：

```swift
import SwiftUI

/// 单个站点的编辑行：动作从手册动作池里选（可自定义）、次数/秒数二选一，
/// EMOM 时选奇偶分钟。只编辑草稿，不含校验规则。
struct StationRowEditor: View {
    @Binding var draft: StationDraft
    let emom: Bool

    /// 名称不在动作池里（含还没填）时按自定义处理，显示自由输入框。
    @State private var customTitle: Bool

    init(draft: Binding<StationDraft>, emom: Bool) {
        _draft = draft
        self.emom = emom
        let title = draft.wrappedValue.title
        _customTitle = State(initialValue: WodMovementPool.movements.allSatisfy { $0.name != title })
    }

    var body: some View {
        VStack(spacing: 8) {
            movementRow
            if customTitle {
                TextField("动作名称", text: $draft.title)
            }
            valueRow
            if emom {
                parityRow
            }
        }
        .padding(.vertical, 2)
    }

    /// 动作池按手册四类分组；「自定义…」切回自由输入（老 WOD 的自定义动作走这条）。
    private var movementRow: some View {
        Menu {
            ForEach(WodMovementCategory.allCases, id: \.self) { category in
                Section(category.title) {
                    ForEach(WodMovementPool.movements(in: category)) { item in
                        Button(item.name) { pick(item.name) }
                    }
                }
            }
            Divider()
            Button("自定义…") { customTitle = true }
        } label: {
            HStack {
                Text(draft.title.isEmpty ? "选择动作" : draft.title)
                    .foregroundStyle(draft.title.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ name: String) {
        draft.title = name
        customTitle = false
    }

    private var valueRow: some View {
        HStack {
            Picker("计量", selection: $draft.kind) {
                ForEach(StationDraft.Kind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            TextField(draft.kind == .reps ? "次数" : "秒数", text: valueText)
                .keyboardType(.numberPad)
        }
    }

    private var parityRow: some View {
        Picker("分钟", selection: $draft.parity) {
            ForEach(MinuteParity.allCases, id: \.self) { parity in
                Text(parity.title).tag(parity)
            }
        }
        .pickerStyle(.segmented)
    }

    private var valueText: Binding<String> {
        draft.kind == .reps ? $draft.repsText : $draft.secondsText
    }
}
```

- [ ] **Step 2: 跑测试确认全绿（回归）**

Run: `make test`
Expected: `Test run with 178 tests ... passed`

- [ ] **Step 3: 模拟器手测**

- 新建 WOD：站点默认显示「选择动作」Menu + 自由输入框（空名称按自定义处理）
- Menu 里分四组列出 8 个动作，点「壶铃摆动」后输入框消失、名称填入
- 编辑内置种子以外的自定义老 WOD：非池动作名正常显示且可编辑

- [ ] **Step 4: 提交**

```bash
git add Replo/Features/Wod/StationRowEditor.swift
git commit -m "feat(wod): 站点动作从手册动作池点选，保留自定义输入"
```

---

### Task 6: `userMessage` 带选中动作 + 调用链透传

**Files:**
- Modify: `Replo/Core/Coach/CoachPrompt.swift`
- Modify: `Replo/Core/Runtime/RuntimeStore.swift:53-77`
- Modify: `Replo/Features/Chat/ChatStore.swift:107-145`
- Test: `ReploTests/CoachTests.swift`

- [ ] **Step 1: 写失败的测试**

`ReploTests/CoachTests.swift` 的 `CoachContextBuilderTests` 里（`userMessageCarriesPrefixAndQuestion` 之后）加：

```swift
    @Test("选中动作拼在前缀之后、问句之前")
    func userMessageCarriesMovements() throws {
        let message = CoachPrompt.userMessage(
            context: .sample, question: "帮我编个 WOD", movements: ["壶铃摆动", "战绳"]
        )

        #expect(message.contains("【选中动作】壶铃摆动、战绳"))
        let plan = try #require(message.range(of: "【当前计划】"))
        let movement = try #require(message.range(of: "【选中动作】"))
        let question = try #require(message.range(of: "帮我编个 WOD"))
        #expect(plan.lowerBound < movement.lowerBound)
        #expect(movement.lowerBound < question.lowerBound)
    }

    @Test("不带动作：不出现选中动作段")
    func userMessageWithoutMovements() {
        let message = CoachPrompt.userMessage(context: .sample, question: "随便聊聊")

        #expect(message.contains("【选中动作】") == false)
        #expect(message.hasSuffix("随便聊聊"))
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `make test`
Expected: 编译错误 `extra argument 'movements' in call`

- [ ] **Step 3: 改 `CoachPrompt.userMessage`**

`Replo/Core/Coach/CoachPrompt.swift` 里 `userMessage` 改为：

```swift
    /// 用户消息：上下文前缀在前，本人问句在后（规格 8 要求拼在前缀里）。
    /// 选中动作（如有）在前缀之后、问句之前。空段不进，全空时只剩问句。
    static func userMessage(context: CoachContext, question: String, movements: [String] = []) -> String {
        var parts = [context.prefix]
        if !movements.isEmpty {
            parts.append("【选中动作】\(movements.joined(separator: "、"))")
        }
        parts.append(question)
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
```

- [ ] **Step 4: `RuntimeStore` 透传**

`Replo/Core/Runtime/RuntimeStore.swift` 的两个方法加参数：

```swift
    func askCoach(context: CoachContext, question: String, conversation: [LlmMessage], movements: [String] = []) async throws -> String {
        let stream = try await askCoachStream(context: context, question: question, conversation: conversation, movements: movements)
```

```swift
    func askCoachStream(
        context: CoachContext,
        question: String,
        conversation: [LlmMessage],
        movements: [String] = []
    ) async throws -> AsyncThrowingStream<LlmStreamEvent, Error> {
        guard let runtime else {
            throw RuntimeError.notBootstrapped
        }
        return await runtime.askStream(
            system: CoachPrompt.system(today: Date(), includePlan: context.planIncluded),
            conversation: conversation,
            question: CoachPrompt.userMessage(context: context, question: question, movements: movements)
        )
    }
```

- [ ] **Step 5: `ChatStore` 透传**

`Replo/Features/Chat/ChatStore.swift`：

`send` 改为：

```swift
    /// 发一句。`movements` 是这条消息选中的动作，拼进前缀，发完即弃。流式接收：先建一条空的助手消息占位，增量往里填，收完落库。
    func send(_ question: String, movements: [String] = []) async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        // 先取历史再记录：这一句要拼进前缀，不能同时又当历史发一遍。
        let history = recentTurns()
        record(role: .user, content: text)
        isSending = true
        failure = nil
        streamingText = ""
        streamingReasoning = ""

        let task = _Concurrency.Task { await receive(history: history, question: text, movements: movements) }
        inFlight = task
        await task.value
        inFlight = nil
    }
```

`receive` 改为：

```swift
    /// 收流：正文增量拼成答案，思考增量单独走，收完写一条助手消息。
    private func receive(history: [LlmMessage], question: String, movements: [String]) async {
        defer { clearStreamingState() }
        do {
            let stream = try await runtime.askCoachStream(
                context: context,
                question: question,
                conversation: history,
                movements: movements
            )
            try await consume(stream)
            commitAnswer()
        } catch is CancellationError {
            finishPartial()
        } catch {
            failure = ErrorText.reason(error)
        }
    }
```

注：落库的用户消息仍是纯问句文本（`record(role: .user, content: text)`），选中动作只进发给模型的报文，不进聊天记录——与上下文前缀的处理方式一致。

- [ ] **Step 6: 跑测试确认通过**

Run: `make test`
Expected: `Test run with 180 tests ... passed`（178 + 新 2）

- [ ] **Step 7: 提交**

```bash
git add Replo/Core/Coach/CoachPrompt.swift Replo/Core/Runtime/RuntimeStore.swift Replo/Features/Chat/ChatStore.swift ReploTests/CoachTests.swift
git commit -m "feat(coach): userMessage 支持选中动作段，调用链透传"
```

---

### Task 7: 教练页选动作 UI

**Files:**
- Create: `Replo/Features/Chat/MovementPickBar.swift`
- Create: `Replo/Features/Chat/MovementPickerSheet.swift`
- Modify: `Replo/Features/Chat/ChatView.swift`

- [ ] **Step 1: 新建 `Replo/Features/Chat/MovementPickBar.swift`**

```swift
import SwiftUI

/// 输入框上方的「选动作」条：入口按钮 + 已选动作 chip（点了移除）。
/// 选中动作随下一条消息发出，发完由 ChatView 清空；不持久化、不进上下文开关。
struct MovementPickBar: View {
    @Binding var selected: [String]
    @Binding var isPicking: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    isPicking = true
                } label: {
                    Label("选动作", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                ForEach(selected, id: \.self) { name in
                    chip(name)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    private func chip(_ name: String) -> some View {
        Button {
            selected.removeAll { $0 == name }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                Image(systemName: "xmark")
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: 新建 `Replo/Features/Chat/MovementPickerSheet.swift`**

```swift
import SwiftUI

/// 动作池多选：按手册四类分组，已选的打勾，再点取消。
struct MovementPickerSheet: View {
    @Binding var selected: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(WodMovementCategory.allCases, id: \.self) { category in
                    Section(category.title) {
                        ForEach(WodMovementPool.movements(in: category)) { item in
                            row(item.name)
                        }
                    }
                }
            }
            .navigationTitle("选动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ name: String) -> some View {
        Button {
            toggle(name)
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if selected.contains(name) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.removeAll { $0 == name }
        } else {
            selected.append(name)
        }
    }
}
```

- [ ] **Step 3: `ChatView` 接线**

`Replo/Features/Chat/ChatView.swift`：

`@State` 区加两个：

```swift
    @State private var selectedMovements: [String] = []
    @State private var isPickingMovements = false
```

body 里 `HistoryModeChip(...)` 与 `ChatComposer(...)` 之间插入：

```swift
                MovementPickBar(selected: $selectedMovements, isPicking: $isPickingMovements)
```

sheet 区加：

```swift
            .sheet(isPresented: $isPickingMovements) {
                MovementPickerSheet(selected: $selectedMovements)
            }
```

`send()` 改为：

```swift
    private func send() {
        let text = draft
        let movements = selectedMovements
        draft = ""
        selectedMovements = []
        _Concurrency.Task { await store?.send(text, movements: movements) }
    }
```

- [ ] **Step 4: 编译 + 联调手测**

Run: `make test`
Expected: `Test run with 180 tests ... passed`

联调验证（`make test-llm`，或 `make mock` + `make run-mock` 在模拟器里手动发一条带动作的消息）：mock 日志里 user 全文中可见 `【选中动作】壶铃摆动、战绳` 段，位置在上下文前缀之后、问句之前；发送后 chip 清空。

- [ ] **Step 5: 提交**

```bash
git add Replo/Features/Chat/MovementPickBar.swift Replo/Features/Chat/MovementPickerSheet.swift Replo/Features/Chat/ChatView.swift
git commit -m "feat(coach): 对话页选动作 chip，随下一条消息发出"
```

---

### Task 8: 全量验证与收尾

- [ ] **Step 1: 全量测试**

Run: `make test`
Expected: `Test run with 180 tests ... passed`，0 失败

- [ ] **Step 2: 联调用例**

Run: `make test-llm`
Expected: 全绿；mock 日志确认 system 含当天日期行、user 前缀结构不变

- [ ] **Step 3: 真机/模拟器走查清单**

- WOD 页：顶部「TABATA 计时」入口；新建 WOD 站点动作从池里选、可自定义
- TABATA：默认战绳 20/10×8；换段提示音；结束记成绩「战绳 · 完成 8/8 轮」；日历当天有标记
- 教练页：选动作 chip 出现、可移除；发送后 chip 清空；聊天记录里该条仍是纯问句

## Self-Review 结论

- 规格四条（编辑器选动作 / 独立 TABATA 可配参数记完成轮数 / 对话页选动作随消息发出 / 动作池含自定义）分别由 Task 5、Task 2-4、Task 6-7、Task 1+5 覆盖，无缺口。
- 类型名全计划一致：`WodMovementPool` / `WodPoolMovement` / `WodMovementCategory` / `TabataTimerModel` / `TabataTicker` / `TabataTimerView` / `MovementPickBar` / `MovementPickerSheet`；`userMessage(context:question:movements:)`、`send(_:movements:)`、`askCoachStream(context:question:conversation:movements:)` 签名一致。
- 无占位符；每个代码步骤给出完整代码。
