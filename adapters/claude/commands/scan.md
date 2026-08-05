---
description: 初始化项目 harness — 调 project-scanner 扫描,按内容类型映射写入 .qey,生成 CLAUDE.md + settings
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
argument-hint: "[deep|drill <模块>]"
---
# qey:scan(Claude adapter → canonical)

> Claude 专属薄包装。canonical 命令逻辑在 `.qey/commands/qey:scan.md`(平台无关)。
> 读它的 body 并执行(忽略本文件 body,以 canonical 为准)。本文件只放 Claude 专属 frontmatter(`allowed-tools`)。

$ARGUMENTS
