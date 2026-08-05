#!/usr/bin/env bash
# find-code-reminder.sh — UserPromptSubmit hook: 用户"找代码"时注入 domain-first 串行提醒
# 读 stdin(Claude Code 传 JSON {prompt:"..."}),匹配关键词 → 输出提醒(注入上下文);不匹配 → 静默
# 目的:治"AI 不串行跟 domain-first"(铁律压不住时,在 prompt 提交时硬提醒)
set -u
INPUT="$(cat 2>/dev/null || echo '')"
[ -z "$INPUT" ] && exit 0
# 提取 prompt(粗提取,不依赖 jq)
PROMPT="$(printf '%s' "$INPUT" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"//;s/"$//')"
[ -z "$PROMPT" ] && exit 0
# 匹配找代码关键词(精确到代码定位,不是找 bug/找问题)
printf '%s' "$PROMPT" | grep -qE '在哪|定位|代码在哪|找.*代码|找.*功能|调用链|链路|代码段|入口在哪|看.*代码|查.*代码|.*在哪.*代码' || exit 0
# 注入提醒
printf '💡 找代码?先 grep -rl "<关键词>" .qey/domain/ 拿英文符号(domain 是中文↔英文桥;答案常已在 domain/业务术语.md),再用英文符号查 codegraph——别直接 codegraph 搜中文(只索引英文,必 0 结果)。串行:domain 拿符号→codegraph 验证。\n'
exit 0
