---
description: 引导式提交 — sh 引擎拉 diff/执行 git,LLM 只起草 message+判断规范+填归档语义;可选归档+MR(自动衔接 archive.sh)
argument-hint: "[可选: type(scope) 提示, 如 fix(wms)]"
---
# qey-commit(omp/pi adapter → canonical)

> omp(oh-my-pi)专属薄包装,native provider 发现(`.omp/commands/qey:commit.md`)。
> canonical 命令逻辑在 `.qey/commands/qey:commit.md`(平台无关)。
> 读它的 body 并执行(忽略本文件 body,以 canonical 为准)。
> omp 无 `allowed-tools` 概念,工具策略由 `.omp/config.yml` 的 `tools.approval` + `bash.patterns` 控制。

$ARGUMENTS
