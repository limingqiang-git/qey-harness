# [项目名] Harness — AI 协作工程资产

> 这是给 AI agent(和新人)的**行为约束 + 项目记忆**。
> 改代码前按"场景索引"读对应文件。**按需读,不全塞上下文**。

## 使用方法

1. **首次**:复制本模板到项目根 → `/qey-init` 让 AI 扫描项目填充 domain/rules
2. **日常**:Claude Code 自动读 `.claude/CLAUDE.md`(红线+场景索引)→ 命中场景读 `.qey/`
3. **提交**:`/commit`(起草→勾选→归档→MR)
4. **周期审计**:`/recap`(查旧知识过期;踩坑/决策已在 loop 当场写)

## 结构

| 目录 | 类型 | 放什么 |
|------|------|--------|
| `rules/` | 规则 | 编码规范、各层规范、git提交规范(**从 qey-init 填充**) |
| `domain/` | 知识 | domain-map、状态流程、业务术语(**从 qey-init 填充**) |
| `memory/` | 记忆 | 踩坑记录、业务演进(随项目长大) |
| `guardrails/` | 约束 | permissions(settings allow/ask/deny) |
| `workflow/` | 流程 | 6 阶段开发 loop、需求澄清 checklist、bug 排查 loop |
| `changes/` | 变更 | 进行中 change + archive;change 模板、生命周期 |
| `specs/` | 真相 | 当前行为规格(由 change 归档 merge delta 而来) |

## 目录决策树(写 X → 放 Y;堵住 domain↔specs 等易混边界)

| 你要记/写的 | 放哪 | 易混 / 别放 |
|------------|------|------------|
| 代码结构 / 调用链 / 流程图 / 状态机(**怎么实现**) | `domain/`(业务流程·状态流程·业务领域) | ≠ specs(spec 是行为真相,不是结构图) |
| 当前行为真相 / 不变量 / 契约(**做什么**,代码应一致) | `specs/<域>/spec.md` | ≠ domain(domain 是地图 hint,这是契约 truth) |
| **为什么**这么设计(ADR:难逆+反直觉+真实取舍) | `knowledge/业务演进/` | ≠ specs(spec 不记 why) |
| 踩过的坑 / 陷阱 / 排查 | `knowledge/踩坑记录/` | ≠ domain(domain 不记坑) |
| 项目级事实(技术栈/目录/DB/队列,高层) | `knowledge/项目级记忆.md` | ≠ domain-map(那是代码结构图,这是高层事实) |
| 业务术语(中文功能 ↔ 英文符号) | `domain/业务术语.md` | — |
| 编码规范(**怎么写**:命名/注释/安全/日志) | `rules/` | ≠ specs(spec 是行为,rule 是写法) |
| 一次变更(proposal+design+tasks+delta) | `changes/<id>/` | — |

> 一句话:**domain=怎么实现(hint)、specs=做什么(truth)、memory=为什么/坑、rules=怎么写、changes=正在变什么**。每个目录只答一个问题,别混。

## 维护(事件驱动,不靠 /recap 仪式)

- 踩坑 → bug-loop **第6步当场写** `knowledge/踩坑记录/`
- 业务流程/决策变 → dev-loop **Stage1 决策落定当场写** `knowledge/业务演进/`
- 项目级事实(技术栈/目录/架构)→ 重跑 `/qey-init` 刷新
- `/recap` = **周期审计**(查旧知识过期),不是每任务必经
- **更新优先于追加**;过时知识比没知识更危险(误导)
