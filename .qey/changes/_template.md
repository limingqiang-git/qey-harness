# Change 模板(`<change-id>`)

> 复制本目录结构到 `changes/<change-id>/`,填。一个 change = proposal(为什么)+ design(怎么做)+ tasks(执行)+ specs/(delta 变化)。
> (无造假范例:change 由真实需求产生,照下面结构填;生命周期见 `changes/README.md`)
> **delta 用 ADDED/MODIFIED/REMOVED**(相对 `specs/` 当前真相的变化);归档时 merge 进 `specs/`。
> 📖 **填写参考**:看 `归档_example.md`(支付重构完整范例)——参考 12 段的写法。

## 目录结构(一个 change 一个目录)

```
changes/<id>/
├── change.json      # 结构化元数据(id/status/priority/domain/branch/commit;可 list/查询)
├── proposal.md      # 为什么 + 范围 + AC + 风险 + 待定问题 + 依赖
├── design.md        # 怎么实现(设计决策/架构/步骤)
├── tasks.md         # 纵向切片任务(每 task 对应 AC)
├── specs/<域>.md    # delta:ADDED/MODIFIED/REMOVED(行为变化)
├── implement.jsonl  # 实现 agent 该读的(domain/specs 改前/design/rules;规划期填)
└── check.jsonl      # 检查 agent 该读的(AC/specs 一致性/域约束/rules;≠ implement)
```

> 小改动:proposal + tasks 够(design/specs 按需)。归档时加 `归档.md`(frontmatter + 实际改动/坑/上线)。

---

## proposal.md(为什么 + 范围 + AC + 风险)

### 背景(为什么)
<现状 + 痛点 + 目标。改造类:简述老逻辑 + 本次目标>

### 边界
- ✅ 包含:
- ❌ 不包含:

### 验收标准(AC)⭐ 可逐条核对
- [ ] AC1:<可验证行为>
> AC 是 Stage 3 验证 + 完成度判定依据。

### 风险 & 缓解(含需求侧异常)
| 风险 | 缓解 |
|------|------|
| <例:回调丢失> | <定时兜底扫描 + 查询接口> |

### 待定问题(Open Q,实现前清空)
- [ ] <例:灰度比例从多少起步?>

### 依赖
- <例:xxx change / 基础设施先就绪>

## design.md(怎么实现)

### 设计决策
<关键取舍(选 X 不选 Y,为什么)。满足 ADR 三门槛(难逆/反直觉/真实取舍)→ 同步落 `knowledge/业务演进/`>

### 架构 / 组件
<新增/改动哪些类/模块 + 职责划分>

### 主流程(mermaid)
### 影响入口 / 改动点
| 系统 | 层级 | 位置 | 改动 |
### 容灾 / 灰度 / 回滚(高风险改造必填)

## tasks.md(Scenario 驱动,checkbox)

### AC → Scenario → Seam(测试契约,设计期定)
| AC | Scenario(Given/When/Then) | Seam | 测试名 |
|----|---------------------------|------|--------|
| AC1 | Given …;When …;Then … | <类::方法 / API> | `test<Scenario名>` |
> Scenario = AC 与 TDD 间的稳定中间层(Given/When/Then);Seam = 测哪个公开接口(Stage 1 先确认)。
> **不在设计期写死断言**(防 horizontal slicing)——实现期按 Scenario 逐个 vertical slice(red→green)。
> ⭐ **Scenario 名 ⇌ 测试名 1:1**(唯一机器可断言的硬交点):每个 Scenario 必须有对应测试;`qey verify` 检测 diff=0(有 Scenario 无测试 → 报警)。

### 证据(⑥ 实现期填,每 Scenario 一个 red→green 记录;归档前必填齐)
```
### AC1 / Seam: <类::方法>
- RED  : <测试命令> → <exit 1 + 关键输出(因正确原因失败)>
- GREEN: <测试命令> → <exit 0, N passed>
- 回归 : <全量测试命令> → <exit 0, M passed>
- verified@commit: <hash> (YYYY-MM-DD)
```
> **完成判定**:每 Scenario 有 RED(因正确原因失败)+ GREEN + 回归 才算 AC 绿,不是勾选。
> **hash 真实(落盘判定)**:`verified@commit: <hash>` 必须是 git 里**真实存在**的 commit——归档时 `change.sh archive` 用 `git rev-parse` 逐个验,编造/未提交的 hash 过不了闸。

### 任务(每 task = 一个 Scenario 的 red→green slice)
- [ ] task1:<对应 AC1,先写其 Scenario 的 failing test,再最小实现>
- [ ] task2:<对应 AC2>

## specs/<域>.md(delta,ADDED/MODIFIED/REMOVED)

### ADDED
- <新增行为>

### MODIFIED
- <改变的行为:老 → 新>

### REMOVED
- <移除的行为>

> 归档时 apply 进 `specs/<域>/spec.md`:ADDED 追加 / MODIFIED 覆盖 / REMOVED 删除。

## 归档.md(change 建好就带,开发过程中持续填;归档时自动填 frontmatter)

> 独立模板见 **`归档_template.md`**(5 段结构化:实际改动/坑/决策/上线/后续待办)。
> `change.sh create` 自动 cp 一份到 `changes/<id>/归档.md`。开发过程中人/AI 随时填(事件驱动,不拖归档时)。
> 归档时 `archive.sh` 自动填 frontmatter 的 commit/date/branch/change_id/status,正文已填的保留。
> 对 AI 友好(固定 5 段,/qey-distill 可靠解析);对人友好(每段有问法,AI 起草人校对)。
