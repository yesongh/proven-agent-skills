---
name: coze-to-cloudflare
description: Use when porting, migrating, converting, or rewriting a Coze/扣子 workflow YAML to Cloudflare Workers, Queues, D1, Workflows, or R2; triggers include port Coze workflow, migrate Coze YAML, convert Coze to Cloudflare, coze2cf, coze 转 cloudflare, coze workflow 移植/重写/迁移, cloudflare workflow 实现, Coze node-to-step mapping, Coze model index mapping, and Coze subflows in Cloudflare Workflows.
---

# Coze Workflow YAML → Cloudflare Workflow 移植指南

## 角色定位

这个 skill 是 `superpowers:brainstorming` + `superpowers:writing-plans` 的**领域 companion**。它提供 Coze→Cloudflare 的节点映射知识、brainstorming 清单和移植经验，**不替代**那两个 skill。

适用前提：你的项目用 **Cloudflare Worker + Queue + D1 + Workflow + R2** 跑异步任务。

触发后，仍然先调用 `superpowers:brainstorming` 与用户对齐设计；本 skill 给你回答"该问哪些问题、Coze 节点该映射成什么、技术栈硬约束是什么"。

## 前置条件

- `<DB_BINDING>`：持久化任务状态和结果。
- `<BUCKET_BINDING>`：存放图片、长文本或中间大对象。
- `<QUEUE_BINDING>`：把 HTTP 请求转成轻量异步消息。
- `<FEATURE>_WORKFLOW`：执行业务步骤的 Workflow binding。
- 模型 registry：集中维护 Coze `model: <i>` 到实际模型 ID 的映射。

如果项目缺少 Queue / Workflow / D1 / R2 中的关键 binding，先在 brainstorming 阶段决定替代架构；不要套用本文的完整异步栈。

## 目标架构（通用骨架）

```
POST /your-endpoint
  → 校验入参（400 on fail，不入队）
  → 写 D1 任务记录（status="pending"）
  → <QUEUE_BINDING>.send({ type: "<feature>", taskId, params })
                    ↓
            Queue Consumer
  → <FEATURE>_WORKFLOW.create({ id: taskId, params })
                    ↓
            Workflow.run()
  ├─ step: idempotency-check（读 D1，done 直接返回缓存 result）
  ├─ step: [业务步骤，每个有副作用的操作单独一步]
  ├─ step: save-result（写 D1 result，status="done"）
  └─ error path: replay-safe write-error 或 Queue Consumer 兜底写 D1 error

GET /tasks/:id → 只读 D1，返回 { status, result, ... }
```

Bindings（`<DB_BINDING>`、`<BUCKET_BINDING>`、`<QUEUE_BINDING>`、`<FEATURE>_WORKFLOW`）按你项目的命名约定填充。

```ts
export class FeatureWorkflow extends WorkflowEntrypoint<Bindings, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    // step.do(...) steps here
  }
}

// Queue Consumer 伪代码
// Replace FEATURE_WORKFLOW with your actual <FEATURE>_WORKFLOW binding name.
await env.FEATURE_WORKFLOW.create({ id: taskId, params });
```

## 触发后的工作流程

```
1. 读 Coze YAML，逐节点分类
   （start / end / condition / code / text / llm / subflow / variable_merge / from_json / loop / parallel）
2. 读你项目的当前状态：Worker 入口、AI gateway helper、bindings 配置、现有 Workflow 文件
3. 调用 superpowers:brainstorming，用本文"Brainstorming 清单"逐条澄清
4. 写 spec（推荐结构见"Spec / Plan 结构建议"一节）
5. 用户审 spec → 调用 superpowers:writing-plans
6. 实现交给 superpowers:subagent-driven-development 或 superpowers:executing-plans
```

## Coze 节点 → 异步 step 映射（简表）

完整版含代码示例见 `references/coze-node-mapping.md`。

| Coze 节点 | Cloudflare 落点 |
|---|---|
| `start` / `end` | Workflow `Params` 入参类型 / `step.do "save-result"` 写 D1 result |
| `condition` | TS `if/else` 或 `switch` |
| `code`（纯函数，无副作用） | 普通模块函数，**不**放进 `step.do` |
| `code`（有副作用 / 随机性） | `step.do` 包裹；幂等以便 replay |
| `text`（字符串模版） | TS template literal 或 `buildXxxPrompt(...)` 函数 |
| `llm` | AI helper 调用，包在 `step.do` 内（见 coze-node-mapping.md 完整示例） |
| `subflow` | 不保留子流程抽象；按本质分类：deterministic→共享纯函数模块 / LLM 包装→展开调用 / 占位→placeholder step |
| `variable_merge` | TS 对象解构 / 合并 |
| `from_json` / 结构化输出 | LLM 直接返回结构化对象；必须 JSON.parse 时用 try/catch |
| `loop` | `for...of`（串行）或 `Promise.all`（并行），每次 LLM 调用各自一个 step |
| `parallel` | `Promise.all`，每个分支各自 `step.do` |

## 模型索引映射

Coze YAML 里 `model: <i>` 用数字 index 引用模型（Coze 平台事实）：

```js
// 示例 Coze ModelList（各账号可能不同，以用户实际配置为准）
[
  'gemini-2.5-flash-lite',           // 0
  'gemini-2.5-flash',                // 1
  'gemini-2.5-pro',                  // 2
  'gemini-3-flash-preview',          // 3
  'gemini-3.1-pro-preview',          // 4
  'gemini-2.5-flash-image',          // 5
  'gemini-3-pro-image-preview',      // 6
  'gemini-3.1-flash-image-preview',  // 7
]
```

你的项目应该有一个集中的模型 registry（如 `MODELS` dict / `models.ts`）。YAML 里每个 `model: <i>` 都要在 brainstorming 时确认它映射到 registry 里的哪个键。如果 index 没有对应，**主动问用户是否新增 registry 条目**，不要默默添加或猜测。

## 技术栈本身的硬约束

以下约束来自 Worker + Queue + D1 + Workflow + R2 这套技术栈，任何使用该技术栈的项目都适用：

1. **D1 是任务事实来源**：通过 ID 查任务状态的 GET endpoint 只读 D1，不要让 Workflow 实例直接返回结果给轮询方。
2. **Queue / Workflow payload 必须轻量 JSON**：Cloudflare Queue 消息有大小上限，图片、长文本等大对象先写 R2，payload 里只传 key。
3. **`step.do` 边界 = 副作用**：D1 / R2 / LLM / 外部 API / 随机数消耗 → 放进 `step.do`；纯计算 → 普通函数，不分 step。
4. **step 名字不要在 retry 间漂移**：Workflow replay 按 step 名读缓存，名字变了就会重跑该步骤——占位 step 也要保持固定的名字，为未来接入留出干净的升级路径。
5. **Idempotency check 放在 run() 第一步**：读 D1，`status === "done"` 且 result 非空时直接返回缓存结果，避免重复执行。
6. **LLM 调用包进 `step.do`**：让 step 的 retry 机制接管重试（如 `{ retries: { limit: 3, delay: "5 seconds", backoff: "exponential" } }`），不依赖 SDK 级别的重试。
7. **step 返回值保持小**：非 stream `step.do` 返回值必须小于 1 MiB；大对象写 R2/D1 外部存储，step 只返回 key 或摘要。

Retry / timeout 配置格式以 Cloudflare Workflows 当前文档为准，版本间可能变化。

## Brainstorming 必问清单

在 `superpowers:brainstorming` 阶段，用这 14 条问题逐一对齐：

1. **还原度**：完整还原 Coze 的全部分支逻辑，还是简化为核心路径？
2. **同步 vs 异步**：走 Queue + Workflow 异步，还是 Worker 同步返回？（项目里其它任务都走异步时，保持一致通常更合适）
3. **模型 index 映射**：YAML 里每个 `model: <i>` 在你 registry 里有对应吗？需要新增条目吗？
4. **跨 workflow 共享重构**：是否需要把公共 helper（AI 调用、数据转换）提取成共享模块？
5. **入参校验边界**：哪些字段校验失败走 HTTP 400 不入队，哪些进入 workflow 后再 throw？
6. **随机 / 非确定性**：workflow 跑几次？如何保证 replay 时幂等（`step.do` 缓存随机结果）？
7. **Idempotency**：workflow 启动时是否先读任务存储，跳过已完成任务？
8. **错误策略**：哪些用 `step.do` retry，哪些走外层 catch，哪些写 error 字段落库？
9. **兼容字段**：旧请求里的字段是接收即忽略，还是必填校验？
10. **测试范围**：哪些是核心 e2e 必跑，哪些只保静态类型通过？
11. **不在范围内**：明确写出本次 PR **不**做什么。
12. **Sentinel 值**：扫 code 节点 JS 里所有 `=== "<lit>"` / `== ""` 比较，把字符串字面量列出来——多义值（如 `""` 和 `"0"` 表示同一业务语义）一个都不能漏，每个都要在 spec 里登记。
13. **Deterministic 子工作流**：能抽成纯函数模块复用（适合按 key 查表的逻辑），还是内联展开？
14. **数值 / 范围输出**：LLM 返回有范围约束的数值时，prompt 里写约束**且**代码里再 clamp 一次。

## Coze JS → TS 移植的 4 条经验

从多次 Coze→Cloudflare 移植中提炼，每次都容易漏：

1. **Sentinel 值容易漏处理**：Coze code 节点 JS 里经常用多个等价字面量表示同一种状态（如空字符串 `""` 和 `"0"` 都表示"默认值"）。逐行读 code 节点，把所有字符串字面量比较列成"sentinel 表"，TS 端每个都要显式处理，code review 一抓一个准。

2. **Deterministic 子工作流应抽成共享模块**：如果一个 Coze 子工作流本质上是纯查表（按参数组合返回固定文本），不要把数据内联展开；应抽成 `data.ts`（数据常量）+ `module.ts`（纯函数查表），未来其它 workflow 能复用同一份数据。

3. **LLM 数值输出必须 clamp**：prompt 里写"必须在 1-100 以内"不够，模型偶尔会越界。在处理 LLM 返回值的代码里再加一次 `Math.min(max, Math.max(min, Math.round(v)))` 兜底。

4. **HTTP 校验深度不要只看最显眼的字段**：YAML `start.outputs` 里所有 downstream 实际用到的字段都要在 POST 路由层校验，包括嵌套对象、数组、optional 但 downstream 假定存在的字段。遗漏的字段通常在 workflow 跑到 LLM 时才暴露。

## Spec / Plan 结构建议

**Spec 推荐章节**（写完对照自检）：
- 决策摘要表（每个讨论过的决策 1 行结论）
- 架构 ASCII 流程图（POST → Queue → Workflow → D1 → GET）
- HTTP 层（请求校验 / 响应格式 / 旧实现移除）
- Queue & Workflow 层（消息类型分支 / Workflow class / step 列表）
- 静态数据与纯函数（从 YAML 抽出的硬编码常量 + 纯函数签名）
- 错误处理表（触发点 → 行为）
- 测试范围
- 不在范围内

**Plan 推荐结构**：
- 每个 task 给出 `Files: Create / Modify / Test`，不写 TBD
- TDD ceremony：写失败测试 → 看到 fail → 写最小实现 → 看到 pass → commit
- 新依赖、新 binding、新 migration 各自成一个独立 task，不塞进业务 task
- plan 末尾固定一个 "code review + fix" task（见下一节）

具体的 plan/spec 格式规范以 `superpowers:writing-plans` 的当前版本为准，本 skill 不维护独立模板。

## 完成后的 review 闭环

测试全绿不等于完成。plan 末尾固定一个 "code review + fix" task，主动核查以下问题：

1. **Sentinel 值漏处理**：TS 只判了一个等价字面量，漏了其它（如只判 `""` 没判 `"0"`）。
2. **HTTP 校验过浅**：只校验最显眼的字段，下游用到的数组 / 嵌套字段没校验，等 workflow 跑到 LLM 才崩。
3. **LLM 数值未 clamp**：prompt 写了约束，代码没兜底，偶尔越界值直接写进结果。
4. **ID 字段 truthy 校验过宽**：`!body.id` 会把 `0` 也排除（可能是合法 ID）；改用 `typeof === "number" && > 0` 或具体类型检查更安全。

## 注意

- 不要修改 Coze YAML 源文件，它们是只读的迁移参考。
- skill 里的知识可能滞后于你的项目实现；如有冲突，以仓库当前代码为准。
- 本 skill 描述 **Worker + Queue + D1 + Workflow + R2** 异步技术栈的通用实践；如果你的项目架构不同，某些约束可能不适用，自行判断。
