# WOD 动作选择 + 独立 TABATA 计时器 + 教练对话带动作 · 设计

日期：2026-10-10
状态：已获用户批准（头脑风暴阶段）

## 背景与目标

周三高强度有氧是「TABATA 或 WOD 二选一」（手册）。现状：WOD 有库、编辑器、计时器、成绩记录；TABATA 只在文档里，App 里没有对应功能；WOD 站点动作是自由输入，容易写错名字；教练对话页问 WOD 相关问题时无法方便地指明动作。

目标（用户已逐条确认）：

1. WOD 编辑器里站点动作可从手册动作池点选，仍允许自定义输入。
2. 新增独立的 TABATA 计时器（不作为第五种 WodFormat），参数可配，结束记成绩。
3. 教练对话页输入框旁可选动作，随该条消息发出，发完即清空。

## 非目标（YAGNI）

- TABATA 不进 WOD 库、不做每轮记次数（经典 Tabata score），成绩只记完成轮数。
- 对话页选动作不持久化、不进上下文开关设置。
- 不动 `Station` / `Wod` / `WodResult` 现有字段，无数据迁移。

## 1. 动作池（共用数据）

新文件 `Replo/Core/Wod/WodMovementPool.swift`：

- 手册动作池 8 个动作，带类别：`hinge`（壶铃摆动）、`推`（俯卧撑、单臂壶铃推举）、`蹲`（高脚杯深蹲、自重深蹲）、`心肺·核心`（战绳、登山跑、平板支撑）。
- 源码常量（与 `CoachDocuments` 同思路：内容即训练体系本身，编译期可见，不走 bundle）。
- 同时定义 TABATA 成绩用的固定虚拟 `wodId`（内置 UUID 常量），表示「TABATA 计时」这条非 WOD 库记录。
- WOD 编辑器与教练对话页共用这一份。

## 2. WOD 编辑器选动作

- `StationRowEditor` 的名称 `TextField` 改为「动作选择 Menu」：列出动作池（按类别分组）+ 末尾「自定义…」。
- 选池内动作：直接填入名称，不显示输入框；选「自定义…」：出现原输入框自由输入。
- `Station` / `StationDraft` / `WodDraft` 模型与校验不变（名称仍是字符串），已有 WOD 数据完全兼容。

## 3. 独立 TABATA 计时器

### 状态机：`Replo/Core/Wod/TabataTimerModel.swift`

纯状态机，外部 ticker 按秒喂真实经过时间，自身不读系统时钟（风格同 `WorkoutTimerModel`）。

- 参数：`workSeconds`、`restSeconds`、`rounds`（默认 20 / 10 / 8）。
- 状态：`ready / running / paused / finished`。
- 派生：`currentRound`（从 1 数）、当前段（`work` / `rest`）、段内剩余秒、总时长 = `(work + rest) × rounds`。
- 提示点 `Cue`：段切换（工作→休息、休息→下一轮工作）、每段最后 3 秒、结束。界面据此发声/震动（复用现有 cue 消费方式）。
- 成绩文案：`scoreText` = 「完成 x/y 轮」，x = 已完成的完整工作段数；跑完全程即 x = y。

### 界面：`Replo/Features/Wod/TabataTimerView.swift`

- `ready` 态：参数区——动作从动作池单选（默认战绳；手册注明只有战绳做 TABATA，池内其他动作可选但不推荐，文案提示）；工作秒 / 休息秒 / 轮数三个 stepper（范围 5-60s / 5-60s / 1-20 轮）。
- 计时中：大字 `WORK` / `REST` + 段倒计时 + 「第 n/y 轮」；开始/暂停/重置。
- 结束：出成绩 sheet（复用 `WodResultSheet` 的 RPE + 次日感觉结构，score 预填 `scoreText`）。

### 成绩记录

- 复用 `WodResult`：`wodId` = 动作池文件里的固定 TABATA UUID，`score` = 「完成 x/y 轮」，`rpe`、`nextDaySoreness` 照旧。
- `ReploSchema` 不变；日历 `isRecorded` 按 `WodResult.date` 标记，自动联动。
- 入口：`WodListView` 列表顶部固定一行「TABATA 计时」（非库内容，不可滑删/编辑），点击进入 `TabataTimerView`。

## 4. 教练对话页选动作

- `ChatView` 输入区上方加「选动作」入口 → sheet 从动作池多选（`WodMovementPool`）→ 选中项以 chip 展示在输入框上方，可逐个移除。
- 发送：`CoachPrompt.userMessage` 增加 `movements: [String] = []` 参数，非空时在上下文前缀之后、问句之前拼一段 `【选中动作】壶铃摆动、战绳`。
- 发完清空选中；不持久化、不受历史档位 / 计划开关影响；落库的消息文本即拼接后的全文（与现状一致）。

## 错误处理

- TABATA 参数全部走 stepper 范围约束，无非法输入路径；成绩保存失败沿用现有 alert 模式（`failure` 文案弹出）。
- 对话页选动作为空数组时 `userMessage` 输出与现状完全一致（不引入空段）。

## 测试

- `TabataTimerModel`：段切换边界（20s 整、跨段那一秒）、轮次推进、最后一段结束即 finished、暂停/重置、cue 优先级、`scoreText`。
- `WodMovementPool`：8 个动作、四个类别齐全、TABATA 固定 UUID 稳定（常量不随机生成）。
- `CoachPrompt.userMessage`：带 `movements` 时拼出【选中动作】段且位置正确；空数组时输出不变。
- `WodDraft` 层：选池内动作 / 自定义输入两条路径的校验与 `makeStation` 行为不变（回归）。
- UI 层不写 UI 测试（项目现状无此惯例）。
- 验证命令：`make test`；改动涉及联调断言时补 `make test-llm`。

## 影响面

- 新增：`WodMovementPool.swift`、`TabataTimerModel.swift`、`TabataTimerView.swift`，各自测试。
- 修改：`StationRowEditor.swift`、`WodListView.swift`、`ChatView.swift`、`CoachPrompt.swift`，及对应测试。
- 不变：全部 SwiftData schema、种子数据、教练文档内容。
