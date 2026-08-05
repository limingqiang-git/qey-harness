#!/usr/bin/env bash
# Stop hook: 会话结束"沉淀提醒"——本次是否产出可沉淀的知识?
# 覆盖:熟悉业务/看代码(→domain)、改代码(→freshness)、查阅纠正(→memory/踩坑)、决策(→业务演进)、行为真相(→specs)
# 事件驱动:踩坑/决策已在 loop 当场写;本 hook 兜底,尤其抓"探索类只读会话"别白学。
# marker 放 .git/(不污染工作树):每个 git 状态最多提示一次,第二次 stop 放行。
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
MARKER="$GIT_DIR/harness-stop-nudged"
CURRENT="$(git rev-parse HEAD 2>/dev/null)|$(git status --porcelain 2>/dev/null | shasum | cut -d' ' -f1)"
# 该状态已提示过 → 放行(防 nag / 防循环)
[ -f "$MARKER" ] && [ "$(cat "$MARKER" 2>/dev/null)" = "$CURRENT" ] && exit 0
echo "$CURRENT" > "$MARKER"
CHANGED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
[ -z "$CHANGED" ] && CHANGED=0
if [ "$CHANGED" -gt 0 ]; then
  printf '{"decision":"block","reason":"💡 会话结束沉淀提醒(本次改了 %s 处):产出可沉淀知识吗?业务理解→domain/、纠正/坑→knowledge/踩坑记录/、决策→knowledge/业务演进/、行为真相→specs/;改了代码→核实 .qey 引用 freshness。已当场写或不涉及→再停止一次跳过(或 /recap 系统过一遍)。"}\n' "$CHANGED"
else
  printf '{"decision":"block","reason":"💡 会话结束沉淀提醒(只读/探索):摸清了业务/代码,或纠正了什么认知?有→写 domain/(理解)或 knowledge/踩坑记录/(坑);纯读无新知→再停止一次跳过。"}\n'
fi
exit 0
