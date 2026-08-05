---
name: "source-command-qey-log"
description: "会话日志(机械) — bash log.sh 抓 git 信息 append 到 journal;30 秒,不提炼不判断不删旧"
---

# source-command-qey-log(agents adapter → canonical)

Codex / 通用 agent 读 `.agents/skills/`,Claude 读 `.claude/commands/`,omp 读 `.omp/commands/`。
**canonical 命令逻辑在 `.qey/commands/qey-log.md`**(平台无关)—— 读它并执行其 body。

> **单源**:命令逻辑只维护 canonical 一份;本文件是 agents 适配薄包装,**不复制内容**(防 drift)。
