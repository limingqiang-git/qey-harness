---
name: "source-command-scan"
description: "扫描填充项目 — 调 project-scanner 扫描,按内容类型映射写入 .qey,生成 CLAUDE.md + settings"
---

# source-command-scan(agents adapter → canonical)

Codex / 通用 agent 读 `.agents/skills/`,Claude 读 `.claude/commands/`,omp 读 `.omp/commands/`。
**canonical 命令逻辑在 `.qey/commands/scan.md`**(平台无关)—— 读它并执行其 body。

> **单源**:命令逻辑只维护 canonical 一份;本文件是 agents 适配薄包装,**不复制内容**(防 drift)。
