---
description: 引导式提交 — sh 引擎拉 diff/执行 git,LLM 只起草 message+判断规范+填归档语义;可选归档+MR(自动衔接 archive.sh)
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
argument-hint: "[可选: type(scope) 提示, 如 fix(wms)]"
---
# qey-commit(Claude adapter → canonical)

> Claude 专属薄包装。canonical 命令逻辑在 `.qey/commands/qey:commit.md`(平台无关)。
> 读它的 body 并执行(忽略本文件 body,以 canonical 为准)。本文件只放 Claude 专属 frontmatter(`allowed-tools`)。

$ARGUMENTS
