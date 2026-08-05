---
description: 初始化项目 harness — 调 project-scanner 扫描,按内容类型映射写入 .qey,生成 CLAUDE.md + settings
argument-hint: "[deep|drill <模块>]"
---
# qey:scan(omp/pi adapter → canonical)

> omp(oh-my-pi)专属薄包装,native provider 发现(`.omp/commands/qey:scan.md`)。
> canonical 命令逻辑在 `.qey/commands/qey:scan.md`(平台无关)。
> 读它的 body 并执行(忽略本文件 body,以 canonical 为准)。
> omp 无 `allowed-tools` 概念,工具策略由 `.omp/config.yml` 的 `tools.approval` + `bash.patterns` 控制。

$ARGUMENTS
