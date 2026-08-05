# [项目名] — 项目技术指南(精简版)

> 一句话项目定位。

> ⚠️ **动手前必读**:本文件只放**红线 + 场景索引**,详细规范在 `.qey/`。
> 首次使用:跑 `/qey-init` 让 AI 扫描项目、填充 domain-map + rules。
> 🔍 **自检**:若本文件仍有 `[qey-init 填充]` 占位 → 尚未初始化,先跑 `/qey-init`。

---

## 执行铁律(红线;详细见 `.qey/rules/`)

- [qey-init 填充:项目分层红线]
- **异常处理**:[qey-init 填充:项目异常约定]
- **代码注释克制无 AI 味**:只注 why 不注 what,不堆方案/废话;详见 `.qey/rules/代码注释规范.md`。
- **防御性编码底线**:不拼 SQL/不硬编码密钥/敏感信息脱敏;不空 catch/对外不泄露堆栈;日志带 traceId+脱敏/级别准;外部调用必超时+重试+幂等。详见 `.qey/rules/`(安全/错误/日志/外部调用 规范)。
- **git:add/commit 自动,push/merge/checkout 触发 ask**(settings;详见 `.qey/guardrails/permissions.md`);AI 只起草 message;**不加 Co-Authored-By**。
- **落盘判定**:成功以**落盘产物**为准,不信 stdout/退出码/AI 自报——stdout 会截断、长命令被 terminal 置后台、管道变异步。具体:测试"通过"留可核对 evidence(不只 exit 0);提交成功以 `git log -1` 确认,不信"提交成功"提示;evidence 的 `verified@commit` hash 必须**真实**——归档时 `change.sh archive` 用 `git rev-parse` 验存在,编造/未提交过不了闸。
- **记忆事件驱动 + 周期审计**:踩坑/决策在 loop 当场写(bug-loop 第6步 / dev-loop Stage1);`/recap` = 定期查过期。更新优先于追加。
- **改 .qey 引用的文件后必须查旧**:过期知识比没知识更危险。
- **找代码分两类,别一刀切**:
  - **查询型**(入口在哪/流程怎么走/X 是什么):直接 `codegraph_callers`/`callees`/`search`(符号级)+ `grep path:"**/Routes/"`(HTTP 入口),**第一轮并行发出**。domain 是可选补充,不必先读。
  - **改代码型**(我要改 X):**必须先**读 `domain/` + 陷阱文档(防命名踩坑)→ 再 codegraph/grep 验证。
  - 通用:见 `.qey/rules/代码定位决策树.md`(LSP/codegraph/grep 任务匹配决策表)。**禁**:codegraph 搜中文(只索引英文,必 0 结果)。domain=hint、代码=truth,不一致回写。
- [qey-init 填充:其他项目特定红线]
- **工具选型按任务匹配,不是一刀切优先级**:LSP 查符号引用(trait/接口/重命名)、codegraph 查调用图/影响面、grep 查文本/路由表。详见 `.qey/rules/代码定位决策树.md`。**装了 LSP**(对应语言的 server,如 PHP 装 intelephense)后,查符号关系优先 LSP,穿透 trait 零噪声。

---

## 场景索引(改之前先读 `.qey/` 哪个)

| 你要干的事 | 先读 |
|-----------|------|
| 理解项目/熟悉代码 | `.qey/domain/domain-map.md` + `knowledge/项目级记忆.md` |
| 看分层/各层怎么写 | `.qey/rules/backend/index.md`(后端)+ `rules/各层规范.md`(分层骨架) |
| 找代码/定位功能/看链路 | 查询型→`codegraph_callers`+路由 grep(并行);改代码型→先 `domain/`+陷阱文档;工具选型见 `rules/代码定位决策树.md` |
| 看链路/调用链/状态机 | `.qey/domain/业务流程.md` + `状态流程.md` |
| 看当前行为真相 | `.qey/specs/<域>/spec.md`(代码应一致,不一致以此为准) |
| 查规范(git/命名/注释/安全/错误/日志/外部) | `.qey/rules/index.md`(路由表,按场景精准加载) |
| **改代码前(思维触发)** | `.qey/rules/thinking-guides/index.md`(跨层/复用/状态机/边界;30 秒防"没想到"的 bug) |
| **派 subagent 做(复杂任务)** | `.qey/agents/`(researcher 调研 / implementer 实现 / reviewer 审计;各有 persona + 边界) |
| 接新需求开发 | `.qey/workflow/新需求开发-loop.md` |
| 排查/修 bug | `.qey/workflow/bug排查-loop.md` + `knowledge/踩坑记录/` |
| 提交代码 | `/qey-commit`(sh 引擎 + AI 起草 message,人工确认;commit 后自动衔接归档) |
| 会话日志(机械记录) | `/qey-log`(会话结束跑,抓 git log/diff → journal/;不提炼) |
| 知识提炼(刻意沉淀) | `/qey-distill`(周期跑;7 类触发 → staging → 候选落点 → Ask 确认;默认无可提炼) |
| 需求归档 | `.qey/changes/README.md` + `归档_template.md`(12 段结构化) |

---

## 核心命令

```bash
# [qey-init 填充:项目 build/test/lint 命令]
```

## Git

分支:`feat/` `bugfix/` `opt/`;Commit:`fix:`/`feat:`,允许中文。
