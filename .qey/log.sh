#!/usr/bin/env bash
# log.sh — 机械日志引擎(1.6:会话结束抓 git 信息 → append journal)
#
# 和 distill(提炼)的区别:log 只记录"发生了什么",不判断、不提炼、不删旧。
# 轻量(几秒),每次会话结束跑。
#
# 用法:
#   bash .qey/log.sh                     # 抓本次会话(HEAD vs 上次 journal 的 commit)
#   bash .qey/log.sh --title "标题"       # 指定标题
#   bash .qey/log.sh --stdin             # 从 stdin 读 summary
#   bash .qey/log.sh --since <commit>    # 指定起始 commit(默认:上次 journal 记的)
set -uo pipefail
G(){ printf "\033[32m%s\033[0m\n" "$1"; }
Y(){ printf "\033[33m%s\033[0m\n" "$1"; }
R(){ printf "\033[31m%s\033[0m\n" "$1"; }
B(){ printf "\033[1m%s\033[0m\n" "$1"; }

JOURNAL_DIR=".qey/journal"
mkdir -p "$JOURNAL_DIR"

# 参数解析
TITLE=""
SUMMARY=""
SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --stdin) SUMMARY=$(cat); shift ;;
    *) TITLE="${TITLE:-$1}"; shift ;;
  esac
done

# 非 git 项目 → 提示(日志依赖 git)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  Y "⚠ 非 git 仓库,journal 依赖 git(无 commit 记录可抓)。跳过。"
  exit 0
fi

# 确定 journal 文件(当月;超 2000 行轮转)
YEAR_MONTH=$(date +%Y-%m)
JOURNAL_FILE="$JOURNAL_DIR/journal-${YEAR_MONTH}.md"

# 检查行数,超 2000 轮转
if [ -f "$JOURNAL_FILE" ]; then
  LINES=$(wc -l < "$JOURNAL_FILE" | tr -d ' ')
  if [ "$LINES" -gt 2000 ]; then
    # 找下一个可用编号
    N=2
    while [ -f "$JOURNAL_DIR/journal-${YEAR_MONTH}-${N}.md" ]; do N=$((N+1)); done
    JOURNAL_FILE="$JOURNAL_DIR/journal-${YEAR_MONTH}-${N}.md"
  fi
fi

# 确定起始 commit(默认:journal 里记的最后一个 commit;首次用仓库第一个 commit 的父... 没父就用空)
LAST_COMMIT=""
if [ -z "$SINCE" ]; then
  # 从所有 journal 文件找最后一个 commit hash
  for jf in "$JOURNAL_DIR"/journal-*.md; do
    [ -f "$jf" ] || continue
    local_last=$(grep -oE '`[0-9a-f]{7,40}`' "$jf" 2>/dev/null | tail -1 | tr -d '`')
    [ -n "$local_last" ] && LAST_COMMIT="$local_last"
  done
  if [ -n "$LAST_COMMIT" ]; then
    SINCE="$LAST_COMMIT"
  else
    # 首次:用仓库第一个 commit(这样 root..HEAD = 全部)
    ROOT=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
    SINCE="${ROOT:-HEAD~1}"
    # 注意:root..HEAD 不含 root 本身,所以首次会从第二个 commit 开始记
    # 若想含 root,用 root^..HEAD(但 root 无父)。这里接受从第二个 commit 开始。
  fi
fi

# 抓 git 信息
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
TODAY=$(date +%Y-%m-%d)

# commit 列表(since..HEAD)
COMMITS=$(git log --format='| `%h` | %s |' "${SINCE}..HEAD" 2>/dev/null)
if [ -z "$COMMITS" ]; then
  Y "⚠ ${SINCE}..HEAD 无新 commit(可能已记录过或没改动)。跳过。"
  exit 0
fi

# 改动文件清单
CHANGES=$(git diff --name-only "${SINCE}..HEAD" 2>/dev/null | head -30 | while read f; do echo "- \`$f\`"; done)

# 检测在 change 里吗
IN_CHANGE=""
for d in .qey/changes/*/; do
  [ -d "$d" ] || continue
  case "$d" in */archive/*) continue;; esac
  IN_CHANGE=$(basename "$d")
  break
done

# 默认标题(从最近 commit message 提炼)
if [ -z "$TITLE" ]; then
  TITLE=$(git log --format='%s' -1 HEAD 2>/dev/null || echo "会话 $(date +%m-%d)")
fi

# 写入 journal(append)
{
  echo ""
  echo "## Session: $TITLE"
  echo ""
  echo "**Date**: $TODAY"
  echo "**Branch**: \`${BRANCH:-unknown}\`"
  [ -n "$IN_CHANGE" ] && echo "**Change**: \`$IN_CHANGE\`"
  echo ""
  echo "### Summary"
  echo "${SUMMARY:-<一句话(从 commit message 推断)>}"
  echo ""
  echo "### Changes"
  ${CHANGES:+"$CHANGES"} 2>/dev/null || echo "- <无文件改动或仅 .qey 内部>"
  echo ""
  echo "### Commits"
  echo "| Hash | Message |"
  echo "|------|---------|"
  echo "$COMMITS"
  echo ""
  echo "### Next Session(交接)"
  # 从当前 change 的 tasks.md 提取未完成 task(若在 change 里)
  if [ -n "$IN_CHANGE" ] && [ -f ".qey/changes/$IN_CHANGE/tasks.md" ]; then
    echo "**Active change**: \`$IN_CHANGE\`"
    UNFINISHED=$(grep -c '^\- \[ \]' ".qey/changes/$IN_CHANGE/tasks.md" 2>/dev/null || echo "0")
    echo "**Unfinished tasks**: $UNFINISHED 项(见 changes/$IN_CHANGE/tasks.md)"
    echo "**下一步**:续完 tasks.md 未勾选项 → 逐 Scenario evidence → archive"
  else
    echo "- <下一步 或 无>"
  fi
  # 读 .workflow-state(若存在)
  if [ -f ".qey/.workflow-state" ]; then
    STAGE=$(grep "^stage=" ".qey/.workflow-state" 2>/dev/null | cut -d= -f2)
    [ -n "$STAGE" ] && echo "**Workflow stage**: $STAGE"
  fi
  echo "---"
} >> "$JOURNAL_FILE"

G "✓ journal 已追加 → $JOURNAL_FILE"
Y "  (这是机械日志,不提炼。需要沉淀知识跑 /qey-distill)"

# 输出本次 journal 记录的 commit hash(下次 log 的 since)
HEAD_HASH=$(git rev-parse --short HEAD 2>/dev/null)
echo "  本次记到: $HEAD_HASH(下次 log 从这里续)"
