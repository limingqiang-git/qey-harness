# 业务演进模板(Business Evolution)

> 流程/架构**为什么**从 A → B → C → D。只记演进原因(决策依据),不记现状(现状在 `domain/`)。
> **写入时机**:dev-loop **Stage 1 决策落定当场写**(那时 why 最清晰),不拖到 /recap。
> 🔁 **freshness**:每条的 `影响 file:line + 标题日期` 即其 fresh 度;流程再变 → 追加新条目(A→B→C→D),不删旧的。
> **ADR 三门槛**(全中才记,否则跳过):① 难逆(改主意代价大)② 反直觉(未来读者会问"为什么这么做")③ 真实取舍(有备选并选了一个)。
> 📖 **填写参考**:看 `_example.md`(策略模式选型/状态机统一完整范例)——参考 ADR 三门槛的写法。

## 条目格式(每条演进一篇 md)

````markdown
### [YYYY-MM-DD] <流程名>: A→B → A→B→C
- **为什么变**:<触发原因,一句话>
- **之前(A→B)**:<步骤 list 或 mermaid>
  ```mermaid
  flowchart LR
  A-->B
  ```
- **现在(A→B→C)**:<步骤 list 或 mermaid>
  ```mermaid
  flowchart LR
  A-->B-->C
  ```
- **为什么更好**:<一句话>
- **影响**:`file:line` / `domain/`
````

> **排版**:之前/现在优先用**流程图或步骤**;为什么一句话;影响 file:line。

## 索引(新增条目补一行)

| 流程 | 文件 |
|----|------|
| [qey-init 填充:流程1] | |
