# qey-harness 硬红线(always-apply)

> omp 独有:本文件是 always-apply rule,长对话把 CLAUDE.md/AGENTS.md 推远后**仍生效**(re-attach 到当前 turn)。
> 完整红线 + 场景索引见 `.claude/CLAUDE.md`(omp claude provider 也会读,作为 context);本文件只放"长对话也不能忘"的最硬几条。
> 详细规范在 `.qey/rules/`。

## 6 条硬红线

- **找代码分两类**:查询型(入口在哪/流程怎么走/X 是什么)→ 直接 `codegraph_callers`/`callees`/`search` + 路由 grep,**第一轮并行**;改代码型(我要改 X)→ **必须先**读 `.qey/domain/` + 陷阱文档,再 codegraph/grep 验证。**禁**:codegraph 搜中文(只索引英文,必 0 结果)。domain=hint、代码=truth,不一致回写。

- **无 evidence 不归档**:change 归档前每个 Scenario 须有 RED(因正确原因失败)+ GREEN + 回归 evidence + `verified@commit` hash。`change.sh archive` 用 `git rev-parse` 验 hash 真实存在,编造/未提交过不了闸。

- **不加 AI 署名**:commit message **绝不**加 `Co-Authored-By` / 邮箱 / 任何 AI 标记。

- **危险操作禁止**:`rm -rf` / `git push --force` / `git reset --hard` / `git clean` 永远 deny(见 `.omp/config.yml` 的 `bash.patterns`)。`git push` / `merge` / `checkout` / `branch` 触发 prompt 确认。

- **落盘判定**:成功以**落盘产物**为准,不信 stdout/退出码/AI 自报。stdout 会截断、长命令被 terminal 置后台、管道变异步。测试"通过"留可核对 evidence(不只 exit 0);提交成功以 `git log -1` 确认;evidence 的 `verified@commit` hash 必须**真实**。

- **改 `.qey` 引用的文件后必须查旧**:过期知识比没知识更危险。`git diff --name-only` 涉及的文件,`grep -rl "<文件>" .qey/` 命中 → 核实其 **freshness**(last_verified 是否还准);触及高风险区(支付/状态机)优先核实。
