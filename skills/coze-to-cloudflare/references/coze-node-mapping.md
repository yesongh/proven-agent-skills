# Coze 节点 → Cloudflare Workflow 模式映射

Coze workflow YAML 用一组节点（`nodes:`）描述数据流，每个节点由 `data.type` 区分类别。本文覆盖所有已观察到的节点类型，以及在 **Worker + Queue + D1 + Workflow + R2** 异步技术栈里的对应模式。

## 目录

- 通用节点结构
- 节点类型表：`start` / `end`、`condition`、`code`、`text`、`llm`、`subflow`、`variable_merge`、`from_json`、`loop`、`parallel`、其它节点
- 共性原则

## 通用节点结构

```yaml
- id: "100001"
  type: "1"
  data:
    nodeMeta:
      title: "开始"
      description: "..."
    inputs:
      inputParameters:
        - name: keywords
          input: { type: list, value: { ... } }
    outputs:
      - name: keywords
        type: list
```

每个节点都有 `inputs` 和 `outputs`，节点之间靠 `edges:` 里的 `sourceNodeID → targetNodeID` 连接。读 YAML 时第一件事：**把节点拓扑画成有向图**，再按下面表格分类。

解析 YAML 时保留原始 node ID，构建 `sourceNodeID → targetNodeID` 边图，并检查不可达节点、重复边和多入口汇合点；不要只按 YAML 数组顺序推断执行顺序。

## 节点类型表

### `start` / `end`（边界）

YAML 字段：`type: "1"`（start）/ `type: "2"`（end）。

- `start` 节点的 `outputs` 是 workflow 的入参 → 映射到 `WorkflowEntrypoint<Bindings, Params>` 的 `Params` 类型（在你项目的类型模块里定义，如 `types/api.ts`）。
- `end` 节点的 `inputs` 是 workflow 的出参 → 映射到 D1 `result` 字段（`JSON.stringify` 一份结果对象）。

注意：Coze 的 `start.inputs` 在 YAML 里声明可选 / 默认值，真正的入参是 `start.outputs`。

### `condition`（分支）

YAML 字段：`type: "8"`，`data.inputs.branches[]` 列分支条件。

- 映射为 TS `if/else` 或 `switch`。
- 如果某个分支的判断变量是动态计算结果，先用普通函数算出值，再分支。
- 如果分支两边都有 LLM 调用，每个分支的 LLM 各自包一个 `step.do`。

### `code`（代码节点）

YAML 字段：`type: "5"`，`data.inputs.code` 是 JS 代码（字符串），`data.outputs` 声明返回值结构。

这是最常见的节点，可以是纯函数（查表、字符串拼接、聚合），也可以消耗随机性或有副作用。

**纯函数（无副作用、无随机）**：直接抽成 TS 模块函数。**不**用 `step.do`。

**有随机性的 code 节点**：把整段抽成 `computeX(input, rng: () => number)` 函数，workflow 里包进 `step.do`：

```ts
const x = await step.do("compute-x", () => computeX(input, Math.random));
```

原因：`step.do` 会缓存返回值，replay 时直接读缓存，避免每次 retry 都重新随机。测试时传入确定性 rng mock。

**有副作用的 code 节点**（写 D1 / R2）：包 `step.do`，单独一步。

JS → TS 改写要点：
- `Math.random()` 从函数内部走，由 workflow 注入作为 rng 参数。
- Coze JS 的 `console.log` 直接删掉。
- Coze JS 的 `args.params.xxx` 改成 TS 函数参数。
- **Sentinel 值 / 多义字面量**：扫 code 节点里所有 `===` / `==` 比较，把字符串字面量列入 spec 的"sentinel 表"。常见：`""`/`"0"`/`"none"`/`null` 多个等价值表示同一业务语义。漏掉任何一个都是 bug。

### `text`（字符串模版）

YAML 字段：`type: "12"`，输出一段拼接好的文本。

- 映射为 TS tagged template literal，或 `buildXxxPrompt(...)` 函数。
- 长 prompt（> 10 行）建议抽成函数，便于测试和单点修改。
- 变量替换（Coze 的 `{{var_name}}`）改成 JS 的 `${varName}`，命名统一为 lowerCamelCase。

### `llm`（LLM 调用）

YAML 字段：`type: "3"`，`data.inputs.llmParam` 里有 `model`（数字 index）、`temperature`、`prompt`、`systemPrompt`、`outputFormat`、`output_schema` 等。

映射到你项目的 AI gateway helper，包在 `step.do` 内：

```ts
// 伪代码，按你项目的 AI helper API 调整
const { output, usage } = await step.do("step-name", { retries: { limit: 3, delay: "5 seconds", backoff: "exponential" } }, async () => {
  return yourAiHelper.generateText({
    model: yourModelRegistry["<mapped-key>"],
    fallbackModel: yourModelRegistry["<fallback-key>"], // 可选
    output: structuredOutputSchema<TOut>(...),          // 如果 outputFormat 是 object/json
    system: systemPrompt,
    prompt: userPrompt,
    // temperature: 0.7,  // YAML 显式给出时才传
    maxRetries: 0,         // 让 step.do 的 retry 接管
  });
});
```

要点：
- 模型 index → 你的 model registry 键：在 brainstorming 时确认映射，不要猜。
- `outputFormat: "object"` 或 `"json"` 配合 `output_schema` → 用你的结构化输出 API（如 `Output.object` / Zod schema）；类型在你项目的类型模块集中声明。
- `temperature` 如果 YAML 显式给了，就传进去；没给就省略（用 AI helper 默认值）。
- 整个调用包在 `step.do` 里，retry 配置参考你项目里其它 workflow 的写法。
- 每次 LLM 调用都要把 `usage`（token 消耗）收集起来，按你项目的 response contract 格式追加到结果里。

### `subflow`（子工作流）

YAML 字段：`type: "9"` 或 `type: "23"`（依 Coze 版本而异），`data.inputs.spaceID` + `workflowID` 指向另一个 Coze workflow。

项目里**不保留子流程抽象**，但落点取决于子工作流的本质：

#### (a) Deterministic 子工作流（纯查表 / 纯计算）

如果子工作流本质上是"按参数组合返回固定文本 / 数据"（没有 LLM、没有随机），应抽成**共享模块**：

- `<shared>.data.ts`：YAML 中的字面量逐字搬过来，结构化为按维度索引的常量字典。
- `<shared>.ts`：纯函数 `build<Shared>(input): string`，做参数校验 + 查表。

优势：未来任何 workflow 都能复用同一份数据，避免数据散落在多个地方。

#### (b) LLM 包装子工作流

如果子工作流只是把入参整理后调一次 LLM，直接展开为一个 `step.do` + AI helper 调用，不保留子流程抽象。

#### (c) 占位类子工作流（如外部记忆服务尚未接入）

如果子工作流依赖你项目尚未实现的外部服务（如长期记忆 / KV / 向量检索），用 placeholder step 占位：

```ts
await step.do("ltm-read-placeholder", async () => ({ memory: [] }));
// ... 业务步骤 ...
await step.do("ltm-write-placeholder", async () => ({ written: false }));
```

**保留 step 名字**：未来真实接入时不破坏 replay 缓存的 step 列表（按名字索引）。prompt 模板里仍保留该功能的占位段落，并用 TODO 注释标明未来接入路径。

#### (d) 复杂多步骤子工作流

brainstorm 时决定：合并进外层 Workflow，还是单独起一个 Workflow？默认合并，除非子工作流需要被多个父工作流独立复用。

### `variable_merge`（变量合并）

YAML 字段：`type: "32"`，把多个分支的输出合并成一个变量。

```ts
const merged = { ...branchA, ...branchB, extra };
```

如果合并发生在 `condition` 分支汇合处，把分支结果命名后用 `??` 合并。

### `from_json` / 结构化输出解析

YAML 字段：可能是 `type: "13"`（JSON parser 节点）或 LLM 节点直接 `outputFormat: "object"`。

- 尽量让 LLM 直接返回结构化对象（via 你项目的 structured output API），避免拿到字符串再 `JSON.parse`。
- 如果必须解析，用 `JSON.parse(...)` 包在 try/catch 内；不可恢复的格式错误抛 `NonRetryableError`，避免 `step.do` 对终态错误做无效重试。

### `loop`（循环）

YAML 字段：`type: "21"` 或 `type: "loop"`，常见是按数组迭代。

```ts
// 串行
for (const [i, item] of arr.entries()) {
  const r = await step.do(`step-name-${i}`, async () => { ... });
}

// 并行
const results = await Promise.all(
  arr.map((item, i) => step.do(`step-name-${i}`, async () => { ... }))
);
```

每次迭代里的 LLM 调用**各自一个 `step.do`**，名字带 index；否则 step 缓存会冲突，replay 时只有第一个 step 名有缓存。

Index-based step 名只在迭代数组长度和顺序确定时安全；如果数组来自非确定性输出，先把该输出固定在上游 `step.do` 里。

### `parallel`（并行分支）

YAML 字段：`type: "parallel"` 或多条边同时从一个节点出发。

```ts
const [resultA, resultB] = await Promise.all([
  step.do("branch-a", async () => { ... }),
  step.do("branch-b", async () => { ... }),
]);
```

每个并行分支里如有 LLM 调用，都各自 `step.do`。

### 其它节点

Coze tool / plugin 节点通常等价于外部 API 或工具调用：作为有副作用步骤放进 `step.do`，并在 brainstorming 时确认鉴权、超时、retry、幂等键和失败语义。

如果遇到不在上面列表的 `data.type`，**brainstorming 时停下来对齐**：

1. 它对应业务逻辑里的什么概念？
2. 在你项目里有没有现成的对应模式？
3. 是要新建公共抽象，还是这次内联展开？

不要默默猜测。

## 共性原则

- **`step.do` 的边界**：副作用（D1 / R2 / LLM / 外部 API / 随机数） = 一个 step；纯计算 = 普通函数，不分 step。
- **每个 step 的 retry 策略**：LLM step 通常 `{ retries: { limit: 3, delay: "5 seconds", backoff: "exponential" } }`；D1 写入 step 通常不 retry。配置格式以 Cloudflare Workflows 当前 API 为准。
- **终态错误**：入参校验失败、鉴权失败、不可恢复的格式错误等应抛 `NonRetryableError`（从 `cloudflare:workflows` 导入），阻止 `step.do` 做无效重试。
- **错误处理**：错误状态写入必须 replay-safe。可以在受控 `try/catch` 中用命名稳定的 `step.do("write-error", ...)` 做清理/落库后再决定是否 rethrow；也可以让 Workflow 失败，由 Queue Consumer 或启动方兜底写 D1 error。不要在 catch 里裸调用 D1 / R2 / 外部 API。
- **Idempotency**：每个 Workflow 的第一个 step 是 idempotency check：读 D1，`status === "done"` 且 result 非空 → 直接返回缓存 result，不重跑。
- **Usage / token 追踪**：每次 LLM 调用都收集 token 消耗，按你项目的 response 格式追加（如 `usages` 数组、按 node_id 标记），确保所有 LLM step 都有记录。
