#!/usr/bin/env bash
# commit.sh — git 提交流水线引擎(1.5:把 I/O 从 LLM 抽出来,确定性执行)
#
# 三个 stage,LLM canonical(qey-commit.md)编排:
#   stage1-context  拉取 diff/log/status/dirty → JSON,LLM 读它起草 message
#   stage3-execute  执行 add/commit/push(按用户勾选)→ 抓 hash
#   stage6-mr       用 glab/gh 提 MR(按勾选)
#
# 设计原则:sh 包机械 I/O(快、确定),LLM 只做语义(起草 message、判断规范、填归档语义字段)。
# 用法见各 stage。
set -uo pipefail
G(){ printf "\033[32m%s\033[0m\n" "$1"; }
Y(){ printf "\033[33m%s\033[0m\n" "$1"; }
R(){ printf "\033[31m%s\033[0m\n" "$1"; }
B(){ printf "\033[1m%s\033[0m\n" "$1"; }

# ── stage1-context:拉取 git 上下文 → JSON(LLM 读它起草 message)──
stage1_context(){
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { R "✗ 非 git 仓库"; exit 1; }

  local status diff_stat log recent
  status=$(git status --porcelain 2>/dev/null)
  diff_stat=$(git diff --stat 2>/dev/null; git diff --cached --stat 2>/dev/null)
  # 近 10 条 commit(看历史风格,LLM 起草时对齐)
  log=$(git log --format='%h %s' -10 2>/dev/null)
  # 当前分支
  local branch=$(git branch --show-current 2>/dev/null || echo "")
  # 改动的文件清单(给 LLM 看 + freshness grep 用)
  local dirty=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null | sort -u)

  # freshness 命中:改动的文件是否被 .qey 引用
  local fresh_hits=""
  if [ -n "$dirty" ]; then
    for f in $dirty; do
      local hits=$(grep -rl "$f" .qey/ 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//')
      [ -n "$hits" ] && fresh_hits="${fresh_hits}${f}|${hits}
"
    done
  fi

  # 检测在 change 里吗
  local in_change=""
  for d in .qey/changes/*/; do
    [ -d "$d" ] || continue
    case "$d" in */archive/*) continue;; esac
    in_change=$(basename "$d")
    break
  done

  # 探测 MR 工具
  local mr_tool=""
  command -v glab >/dev/null 2>&1 && mr_tool="glab"
  [ -z "$mr_tool" ] && command -v gh >/dev/null 2>&1 && mr_tool="gh"

  # 探测 git 平台 host
  local git_host=""
  local remote=$(git remote get-url origin 2>/dev/null || echo "")
  case "$remote" in
    *gitlab*) git_host="gitlab" ;;
    *github*) git_host="github" ;;
    *gitea*) git_host="gitea" ;;
  esac

  # 输出 JSON(LLM 读这个起草 message,不用再调 git)
  # dirty/fresh_hits 用换行分隔,JSON 里转义
  local dirty_esc=$(printf '%s' "$dirty" | sed 's/"/\\"/g' | tr '\n' '|')
  local fresh_esc=$(printf '%s' "$fresh_hits" | sed 's/"/\\"/g' | tr '\n' '|')
  printf '{"branch": "%s", "in_change": "%s", "mr_tool": "%s", "git_host": "%s", "status": "%s", "diff_stat": "%s", "recent_commits": "%s", "dirty_files": "%s", "freshness_hits": "%s"}\n' \
    "$branch" "$in_change" "$mr_tool" "$git_host" \
    "$(printf '%s' "$status" | tr '\n' '|')" \
    "$(printf '%s' "$diff_stat" | tr '\n' '|')" \
    "$(printf '%s' "$log" | tr '\n' '|')" \
    "$dirty_esc" "$fresh_esc"

  B "▶ context 已拉取(分支:$branch${in_change:+, 在 change:$in_change}${mr_tool:+, MR:$mr_tool})"
  [ -n "$fresh_hits" ] && Y "  ⚠ freshness 命中:本次改动文件被 .qey 引用,核实 last_verified"
}

# ── stage3-execute:执行 add/commit/push(按用户勾选;LLM 起草的 message 通过参数传)──
stage3_execute(){
  # 参数:$1=message(多行用 \n),$2=scope(add/commit/push,逗号分隔),$3=change_id(可选,在 change 里时)
  local msg="${1:-}" scope="${2:-add}" change_id="${3:-}"
  [ -n "$msg" ] || { R "✗ 缺 message"; exit 1; }

  # message 从 \n 转回真换行
  msg=$(printf '%b' "$msg")

  # add
  case "$scope" in *add*|*commit*|*push*)
    git add -A 2>/dev/null
    G "✓ git add"
  ;; esac

  # commit
  local commit_hash=""
  case "$scope" in *commit*|*push*)
    git commit -m "$msg" >/dev/null 2>&1 || { R "✗ git commit 失败"; exit 1; }
    commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
    G "✓ git commit $commit_hash"
  ;; esac

  # push
  case "$scope" in *push*)
    git push 2>&1 | tail -3
    G "✓ git push"
  ;; esac

  # 输出 JSON(给 stage6/归档用)
  printf '{"commit_hash": "%s", "branch": "%s", "scope": "%s", "change_id": "%s"}\n' \
    "$commit_hash" "$(git branch --show-current 2>/dev/null)" "$scope" "$change_id"
}

# ── stage6-mr:提 MR(用 glab/gh)──
stage6_mr(){
  # 参数:$1=target 分支,$2=MR 标题,$3=body(可选),$4=mr_tool(glab/gh)
  local target="${1:-}" title="${2:-}" body="${3:-}" tool="${4:-glab}"
  [ -n "$target" ] || { R "✗ 缺 target 分支"; exit 1; }
  [ -n "$title" ] || { R "✗ 缺 MR 标题"; exit 1; }

  local src=$(git branch --show-current 2>/dev/null)
  local mr_url=""

  case "$tool" in
    glab)
      mr_url=$(glab mr create --yes --source-branch "$src" --target-branch "$target" \
        --title "$title" --description "${body:-(无描述)}" 2>&1 | grep -oE 'https?://[^ ]+' | head -1)
      ;;
    gh)
      mr_url=$(gh pr create --base "$target" --head "$src" \
        --title "$title" --body "${body:-(无描述)}" 2>&1 | grep -oE 'https?://[^ ]+' | head -1)
      ;;
    *) R "✗ 无 MR 工具(glab/gh)或未装"; exit 1 ;;
  esac

  if [ -n "$mr_url" ]; then
    G "✓ MR 已提:$mr_url"
    printf '{"mr_url": "%s", "target": "%s", "source": "%s"}\n' "$mr_url" "$target" "$src"
  else
    R "✗ MR 提交失败(见上)"
    exit 1
  fi
}

CMD="${1:-}"; shift || true
case "$CMD" in
  stage1-context) stage1_context "$@" ;;
  stage3-execute) stage3_execute "$@" ;;
  stage6-mr) stage6_mr "$@" ;;
  *) R "用法:commit.sh stage1-context | stage3-execute | stage6-mr"; exit 1 ;;
esac
