# Replo v1 规格文档

版本：v1.0（2026-09-28）
状态：自用，iOS 独占，暂不考虑上架
技术栈：SwiftUI + SwiftData + CloudKit（私有库同步）+ Moonshot Kimi API

---

## 1. 产品定位

Replo 是把「回线计划」训练体系代码化的自用工具。核心不是记录，而是**决策**：
每次练完输入完成度和体感，App 按加重规则自动算出下次重量（加/原地重复/减 10%），
用户不需要自己记规则、算进度。

与「练啥」的边界：练啥是通用健身记录工具；Replo 是单用户、单计划、规则驱动的
私人教练。两者独立，不共享数据。

## 2. 范围

**做：**
- 四周重建计划（A/B 日模板、周重量表，已内置为初始数据）
- AB 日长期模板（计划收官后切换）
- 训练课流程：今日课程 → 组间计时 → 练完复盘（完成组数/余力/不适/RPE）→ 下次重量决策
- 加重规则引擎（本文档第 5 节，产品的核心）
- WOD 库（8 个内置）+ 三种格式计时器（EMOM/AMRAP/For Time，时间封顶）
- 日历（一力一有节律：力量/低强度有氧/高强度有氧/全休）
- 体重记录（周平均 + 目标区间 68-71kg 可视化）
- Kimi 对话教练（v1 内置）

**不做（v1）：**
- 上架、账号系统、社交、多用户
- 多计划并行、自定义计划编辑器（模板数据写死为初始种子）
- 饮食记录、动作演示视频、Apple Watch 端（待定，见第 10 节）
- 数据导出为 xlsx（训练日志仍以对话方式人工维护）

## 3. 名词表

| 名词 | 含义 |
|---|---|
| A 日 | 上肢容量 + 前蹲：卧推 5×5 / 划船 5×5 / 前蹲 3×5 |
| B 日 | 下肢强度 + 推举：深蹲 3×3 / 推举 5×5 / 硬拉 1×3 |
| RIR | Reps in Reserve，练完每组还剩几次余力 |
| RPE | 主观用力程度 1-10 |
| 警示区 | 深蹲 ≥90kg 或 硬拉 ≥105kg，历史失败重量附近 |
| 低强度有氧 | 坡度走/轻松骑，RPE 4-5 |
| 高强度有氧 | TABATA 或 WOD，RPE 8.5-9，每周最多一次 |

## 4. 数据模型（SwiftData）

### 4.1 Movement（动作定义，种子数据，只读）
- id: UUID
- name: String（深蹲/卧推/杠铃划船/前蹲/推举/硬拉）
- category: enum { lower, upper }（加重步长与警示区判断的依据）
- pattern: enum { dayA, dayB }

### 4.2 PlanTemplate（计划模板，种子数据，只读）
- id: UUID
- name: String（"4周重建 v2" / "AB 常模"）
- weeks: [PlanWeek]（有序）
  - PlanWeek: weekIndex: Int, movements: [MovementAssignment]
    - MovementAssignment: movementId, weight: Double, sets: Int, reps: Int

种子数据 = 计划文档 v2 的完整重量表（见附录 A）。

### 4.3 ActivePlan（当前激活计划，单例）
- templateId, currentWeekIndex: Int, active: Bool

### 4.4 SessionLog（训练记录）
- id: UUID
- date: Date
- dayType: enum { dayA, dayB, wod, cardio, rest }（rest 仅占位）
- entries: [SetEntry]
  - SetEntry: movementId, plannedSets: Int, plannedReps: Int,
    completedSets: Int, lastSetReps: Int（完整则为 plannedReps）,
    rir: Int, discomfort: Bool, rpe: Int, note: String?
- wodId: UUID?（WOD 课填写）
- wodScore: String?（"4轮+8摆+6俯卧撑" 或总时间）

### 4.5 WeightDecision（决策记录，引擎输出留痕）
- sessionLogId, movementId, currentWeight, nextWeight,
  action: enum { add, repeat, deload }, reasons: [String]

### 4.6 Wod（WOD 定义，种子数据，只读）
- id, name, format: enum { amrap, emom, forTime, chipper },
  timeCapSeconds: Int, stations: [Station]
  - Station: description, reps: Int?（seconds 型 Station 用 durationSeconds）

### 4.7 WodResult
- wodId, date, score: String, rpe: Int, nextDaySoreness: String?

### 4.8 BodyWeight
- date: Date, kg: Double

### 4.9 KimiChatMessage
- id, role: enum { user, assistant }, content, createdAt

## 5. 规则引擎（核心）

纯函数模块，不依赖系统时钟（所有上下文由调用方传入），可完整单元测试。

### 5.1 决策输入
```swift
struct DecisionInput {
    let movement: Movement        // category + name
    let currentWeight: Double
    let plannedSets: Int
    let plannedReps: Int
    let completedSets: Int
    let lastSetReps: Int          // 完整完成 = plannedReps
    let rir: Int                  // 0-5
    let discomfort: Bool          // 腰膝/关节不适
    let failStreak: Int           // 该动作连续未通过次数（不含本次）
    let inWarningZone: Bool       // 由 currentWeight 推出，见 5.3
}
```

### 5.2 决策规则（按优先级自上而下，命中即返回）

1. **不适即停**：discomfort == true → repeat，reason「出现不适，原地重复」
2. **失败降级**：failStreak ≥ 2（本次再次未通过）→ deload，
   nextWeight = roundTo1p25(currentWeight × 0.90)，reason「连续失败，减 10% 重建」
3. **未全完成**：completedSets < plannedSets → repeat，reason「未完成计划组数」
4. **余力不足**：rir < 2 → repeat，reason「余力不足 2 次」（真实案例：硬拉 100×3 余力 1 → 原地重复）
5. **通过加重**：以上皆否 → add，
   nextWeight = currentWeight + (lower ? 5 : 2.5)，reason「通过，+5/+2.5」

「本次未通过」定义为规则 3 或 4 命中（规则 1 单独计数，不影响 failStreak
的语义；v1 简化为：规则 3/4 命中则 failStreak +1，否则清零）。

### 5.3 警示区
- 进入条件：movement 为深蹲且 currentWeight ≥ 90，或硬拉且 ≥ 105
- 引擎行为不变（规则 5.2 已是最严标准），但输出带 warning 标记；
  UI 在训练页和决策页显示「警示区」徽章，
  并禁止任何超过规则 5.2 步长的人工加重（手动改重须二次确认）。

### 5.4 配重可行性（独立工具，不参与决策）
`LoadPlanner.canLoad(_ weight: Double, plates: [Double], barWeight: 20) -> Bool`
判断目标重量是否可用现有杠铃片配出。配不出时 UI 提示
「该重量无法配片，可选择最近可配重量并记录原因」（真实案例：95 配不出 → 改 100，
属手动覆盖，记录在 SessionLog.note）。

### 5.5 周封顶
步长本身即封顶（下肢 +5/周、上肢 +2.5/周）。相邻两次同动作训练间隔不足 5 天时，
引擎拒绝输出 add（UI 层提示，引擎接收 lastSessionDate 与 today 两个参数判断）。

## 6. WOD 计时器

四种格式的状态机，通用组件 `WorkoutTimer`：

- **AMRAP**：倒计时 timeCap，用户手动记轮数（+/- 按钮），到时锁定成绩
- **EMOM**：循环当前分钟序号，每分钟起点提示音，分钟内完成与否手动确认；到时结束
- **For Time**：正计时 + timeCap 上限，到 cap 停止计成绩
- **Chipper**：清单逐条勾选，正计时 + cap

共同功能：每组/每分钟结束轻震动；最后 10 秒提示音；后台进入时本地通知兜底（v1 可只做前台，待定）。

## 7. 页面结构

```
TabView
├── 今日（TodayView）
│   └── 根据日历节律显示：今天该练什么 / 今日课程卡片（动作+重量+组次）
├── 日历（CalendarView）
│   └── 月视图：力量/有氧/体能/全休 四色标记；点击跳转当日课程
├── WOD（WodListView → WodTimerView）
├── 体重（WeightView：折线 + 周平均 + 目标区间带）
└── 教练（ChatView：Kimi 对话）
```

训练课流程（今日 Tab 进入）：
`SessionView`：动作列表 → 每个动作 `MovementLoggingView`
（热身组提示 / 正式组打勾 / 组间休息计时默认 3 分钟可改）
→ 全部完成进入 `RecapView`（RIR stepper / 不适 toggle / RPE slider / 备注）
→ 引擎计算 → `DecisionView`（下次重量 + 理由文案 + 警示区徽章）→ 写入 SessionLog + WeightDecision。

## 8. Kimi 接入（v1）

- 设置页填入 Moonshot API Key，存 Keychain
- 模型端点：https://api.moonshot.cn/v1/chat/completions（以官方文档为准）
- system prompt：内嵌三份文档全文（训练计划 / WOD 手册 / 动作说明）+ 角色设定
  「你是 Repl​​o 的教练，熟悉回线计划全部规则，回答不超过 150 字，先给结论」
- 上下文注入：发送前把最近 7 天 SessionLog（日期/动作/重量/组次/RIR/决策）
  和当前计划周次拼进 user message 前缀
- v1 对话只读，不允许 Kimi 写数据（无工具调用）

## 9. 实现顺序

1. SwiftData 模型 + 种子数据导入（附录 A 重量表）
2. 规则引擎 + 单元测试（验收用例见委托提示词）
3. SessionView 训练课流程 + 组间计时
4. WOD 库 + 四种计时器
5. 日历 + 体重
6. Kimi 教练
7. CloudKit 同步（私有库，最后接，用 `ModelConfiguration` + `cloudKitDatabase: .private`)

## 10. 待定决策点（未拍板，v1 默认不做）

- Apple Watch 端（练啥有 Watch 经验，Replo 要不要跟）
- 训练动作演示（图文 or 视频）
- 后台/锁屏时的计时通知
- 多计划支持（v2 候选）

## 附录 A：种子重量表（4 周重建 v2）

A 日（卧推/划船/前蹲，kg）：
W1 40/40/40（3×5）｜W2 42.5/45/45（4×5）｜W3 45/50/50（5×5）｜W4 47.5/55/55（5×5）
B 日（深蹲/推举/硬拉，kg）：
W1 80/30/90（3×3/3×5/1×3）｜W2 85/30/100｜W3 90/32.5/100（硬拉原地重复）
｜W4 95/35/105

AB 常模（长期模板，10/19 后切换）：
A：卧推 5×5 / 划船 5×5 / 前蹲 3×5；B：深蹲 3×3 / 推举 5×5 / 硬拉 1×3（起始重量取收官时决策值）

## 附录 B：真实案例卡（用于引擎验收）

- 2026-09-28 硬拉 100×3，completed=1/1 组，lastSetReps=3，rir=1，discomfort=false
  → 期望：repeat 100，reason「余力不足 2 次」
- 2026-09-21 硬拉 90×3，rir=3 → 期望：add 95（随后被配重问题人工改 100，note 记录）
