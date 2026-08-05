---
name: "source-command-qey-commit"
description: "引导式提交 — sh 引擎拉 diff/执行 git,LLM 只起草 message+判断规范+填归档语义;可选归档+MR(自动衔接 archive.sh)"
---

# source-command-qey-commit(agents adapter → canonical)

Codex / 通用 agent 读 `.agents/skills/`,Claude 读 `.claude/commands/`,omp 读 `.omp/commands/`。
**canonical 命令逻辑在 `.qey/commands/qey-commit.md`**(平台无关)—— 读它并执行其 body。

> **单源**:命令逻辑只维护 canonical 一份;本文件是 agents 适配薄包装,**不复制内容**(防 drift)。
