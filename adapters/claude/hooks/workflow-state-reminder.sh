#!/usr/bin/env bash
# workflow-state-reminder.sh — Claude UserPromptSubmit hook
# 1.7:每 turn 读 .qey/.workflow-state → 注入对应 workflow breadcrumb
# 让 AI 永远知道自己在哪个阶段,防跳步
#
# 读 stdin(Claude 传 JSON {prompt:"..."}),输出提醒注入上下文
# 无 .workflow-state = no_change(无 active change)
set -u
STATE_FILE=".qey/.workflow-state"

# 读状态(无文件 = no_change)
STAGE="no_change"
CHANGE_ID=""
if [ -f "$STATE_FILE" ]; then
  CHANGE_ID=$(grep -m1 "^change_id=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
  STAGE=$(grep -m1 "^stage=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
  [ -z "$STAGE" ] && STAGE="no_change"
fi

# 各阶段 breadcrumb(对应 workflow.md 的 [workflow-state:X] 块)
case "$STAGE" in
  planning)
    MSG="📍 Workflow: planning (Stage 0-1)${CHANGE_ID:+ (change: $CHANGE_ID)}
在 Stage 0-1(规划设计)。过需求澄清 → 填 proposal(为什么+AC)+ design + tasks(AC→Scenario→Seam)+ specs delta。
⚠️ 3 硬闸:① 无批准 Scenario → 不实现;② 无 evidence → 不归档;③ Intent 变 → 新建 change。
填完 review gate → bash .qey/change.sh start $CHANGE_ID 切 in_progress。"
    ;;
  in_progress)
    MSG="📍 Workflow: in_progress (Stage 2-4)${CHANGE_ID:+ (change: $CHANGE_ID)}
在 Stage 2-4(实现+验证+提交)。按 Scenario TDD:一个 Scenario 一个 slice(red→green→填 evidence)。
每 Scenario 必填 evidence:RED(因正确原因失败)+ GREEN + 回归 + verified@commit。
全 AC evidence 齐 → /qey-commit(sh 引擎 + AI 起草 message)。"
    ;;
  finishing)
    MSG="📍 Workflow: finishing (Stage 4-5)${CHANGE_ID:+ (change: $CHANGE_ID)}
在 Stage 4-5(归档)。commit 后自动衔接 archive.sh run $CHANGE_ID:验 evidence + merge delta + 移 archive + 填归档.md。归档后回 no_change。"
    ;;
  *)  # no_change 或未知
    MSG="📍 Workflow: no_change
无 active change。先分类:新需求(过需求澄清 → Stage 1 建 change)/ 复杂 bug(Stage 0 复现+根因 → 建 change)/ 简单 bug·tweak(不建 change,直接改,踩坑当场写 memory)。"
    ;;
esac

printf '%s\n' "$MSG"
exit 0
