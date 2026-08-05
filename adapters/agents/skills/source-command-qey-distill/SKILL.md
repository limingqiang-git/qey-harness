---
name: "source-command-qey-distill"
description: "知识提炼(刻意) — 7类触发判定 → staging → 落点候选(带范围检查)→ Ask 确认 → 落盘;默认无可提炼"
---

# source-command-qey-distill(agents adapter → canonical)

Codex / 通用 agent 读 `.agents/skills/`,Claude 读 `.claude/commands/`,omp 读 `.omp/commands/`。
**canonical 命令逻辑在 `.qey/commands/qey-distill.md`**(平台无关)—— 读它并执行其 body。

> **单源**:命令逻辑只维护 canonical 一份;本文件是 agents 适配薄包装,**不复制内容**(防 drift)。
