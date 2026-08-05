#!/usr/bin/env bash
# archive.sh — change 归档引擎(1.5:从 change.sh 独立;集成 evidence.sh;支持 --experimental)
#
# 用法:
#   bash .qey/archive.sh run <id>                # 正常归档:验 evidence + merge delta + 移目录 + 填归档.md
#   bash .qey/archive.sh run --experimental <id> # 实验性归档:不 merge specs(无 commit 锚点),只移目录
#   bash .qey/archive.sh check <id>              # 只验 evidence,不归档(预检)
#
# 流程(run):
#   ① evidence.sh check(测试 evidence + hash 真实)
#   ② commit 后 diff 校验(<hash>..HEAD 干净)
#   ③ 提示 LLM merge delta(语义,LLM 做)
#   ④ 移目录 changes/<id>/ → changes/archive/<id>/
#   ⑤ 填 归档.md frontmatter(commit/date/branch/change_id/status 自动)
#   ⑥ 更新 change.json(status)
#   ⑦ parity
set -uo pipefail
G(){ printf "\033[32m%s\033[0m\n" "$1"; }
Y(){ printf "\033[33m%s\033[0m\n" "$1"; }
R(){ printf "\033[31m%s\033[0m\n" "$1"; }
B(){ printf "\033[1m%s\033[0m\n" "$1"; }
ask(){ printf "\033[36m? %s [y/N]\033[0m " "$1"; read r; [ "$r" = "y" ] || [ "$r" = "Y" ]; }

C=".qey/changes"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── check:预检 evidence(不归档)──
do_check(){
  local id="${1:-}"
  [ -n "$id" ] || { R "用法:archive.sh check <id>"; exit 1; }
  bash "$SCRIPT_DIR/evidence.sh" check "$id"
}

# ── run:归档 ──
do_run(){
  local experimental=0 id=""

  # 解析参数(支持 run --experimental <id> 或 run <id>)
  while [ $# -gt 0 ]; do
    case "$1" in
      --experimental) experimental=1 ;;
      *) id="$1" ;;
    esac
    shift
  done

  [ -n "$id" ] || { R "用法:archive.sh run [--experimental] <id>"; exit 1; }
  local d="$C/$id"
  [ -d "$d" ] || { R "✗ $d 不存在"; exit 1; }
  [ -d "$C/archive" ] || mkdir -p "$C/archive"
  [ -d "$C/archive/$id" ] && { R "✗ $C/archive/$id 已在(归档过?)"; exit 1; }

  B "▶ archive $id${experimental:+ (experimental)}"

  # ① evidence 检查(experimental 模式放宽:跳过 hash 校验,但仍数 evidence 数量)
  B "① evidence 检查"
  if [ "$experimental" = 1 ]; then
    Y "  experimental 模式:跳过 hash 真实性校验(无 commit 锚点)"
    local acs ev
    acs=$(grep -cE '^### AC[0-9]' "$d/tasks.md" 2>/dev/null); [ -n "$acs" ] || acs=0
    ev=$(grep -c 'verified@commit' "$d/tasks.md" 2>/dev/null); [ -n "$ev" ] || ev=0
    printf "  Scenario:%s | evidence:%s(experimental,不校验 hash)\n" "$acs" "$ev"
  else
    if ! bash "$SCRIPT_DIR/evidence.sh" check "$id" 2>&1; then
      Y "  ⚠ evidence 不足"
      ask "  归档前应补齐,仍继续?" || { echo "  中止"; exit 1; }
    fi
  fi

  # ② commit 后 diff 校验(非 experimental;experimental 跳过,无锚点)
  if [ "$experimental" = 0 ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    B "② commit 后 diff 校验"
    local latest_hash=$(grep -oE 'verified@commit:[[:space:]]*[0-9a-fA-F]+' "$d/tasks.md" 2>/dev/null | tail -1 | sed -E 's/.*:[[:space:]]*([0-9a-fA-F]+)/\1/')
    if [ -n "$latest_hash" ]; then
      local diff_stat=$(git diff --stat "${latest_hash}..HEAD" 2>/dev/null)
      if [ -n "$diff_stat" ]; then
        Y "  ⚠ commit $latest_hash 后又有改动:"
        echo "$diff_stat" | head -5
        ask "  归档可能不准(代码已变),仍继续?" || { echo "  中止"; exit 1; }
      else
        G "  ✓ commit 后无额外改动"
      fi
    fi
  fi

  # ③ merge delta(非 experimental;experimental 不 merge specs,避免污染)
  B "③ delta merge"
  local found=0
  for delta in "$d"/specs/*.md; do [ -f "$delta" ] || continue; found=1
    local domain=$(basename "$delta" .md)
    printf "  delta:%s\n" "$delta"
    if [ "$experimental" = 1 ]; then
      Y "    experimental 模式:不 merge 进 specs/(无锚点,不污染当前真相)"
    elif [ -f ".qey/specs/$domain/spec.md" ]; then
      printf "    → LLM 手动 apply 到 .qey/specs/%s/spec.md(ADDED 追加 / MODIFIED 覆盖 / REMOVED 删除)\n" "$domain"
    else
      printf "    → .qey/specs/%s/spec.md 不存在 → 新建(用 specs/_template.md)\n" "$domain"
    fi
  done
  [ "$found" = 0 ] && Y "  ⚠ 无 delta(specs/*.md)— change 没行为变化?或忘了写"
  if [ "$experimental" = 0 ]; then
    ask "  delta 已 merge 进 specs/?(y 继续)" || { echo "  先 merge 再归档"; exit 1; }
  fi

  # ④ 移目录
  B "④ 移目录"
  mv "$d" "$C/archive/$id"
  G "  ✓ $id → $C/archive/$id/"

  # ⑤ 填 归档.md frontmatter(自动字段)
  B "⑤ 填归档.md frontmatter(自动)"
  local archive_md="$C/archive/$id/归档.md"
  local today=$(date +%Y-%m-%d)
  local branch=$(git branch --show-current 2>/dev/null || echo "")
  local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "")
  local status=$([ "$experimental" = 1 ] && echo "experimental" || echo "done")

  if [ -f "$archive_md" ]; then
    # 用 sed 改 frontmatter(若字段空才填,不覆盖人填的)
    sed -i '' "s/^date: \"\"/date: \"$today\"/" "$archive_md" 2>/dev/null || sed -i "s/^date: \"\"/date: \"$today\"/" "$archive_md"
    sed -i '' "s/^branch: feat\\/xxx/branch: $branch/" "$archive_md" 2>/dev/null || sed -i "s/^branch: feat\\/xxx/branch: $branch/" "$archive_md"
    [ -n "$commit" ] && { sed -i '' "s/^commit: \"\"/commit: \"$commit\"/" "$archive_md" 2>/dev/null || sed -i "s/^commit: \"\"/commit: \"$commit\"/" "$archive_md"; }
    sed -i '' "s/^status: in-progress/status: $status/" "$archive_md" 2>/dev/null || sed -i "s/^status: in-progress/status: $status/" "$archive_md"
    sed -i '' "s/^change_id: \"\"/change_id: \"$id\"/" "$archive_md" 2>/dev/null || sed -i "s/^change_id: \"\"/change_id: \"$id\"/" "$archive_md"
    G "  ✓ 归档.md frontmatter 已填(commit=$commit, date=$today, status=$status)"
  fi

  # ⑥ 更新 change.json
  if [ -f "$C/archive/$id/change.json" ]; then
    local J="$C/archive/$id/change.json"
    sed -i '' "s/\"status\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"status\": \"archived\"/" "$J" 2>/dev/null \
      || sed -i "s/\"status\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"status\": \"archived\"/" "$J"
    sed -i '' "s/\"archived\"[[:space:]]*:[[:space:]]*null/\"archived\": \"$today\"/" "$J" 2>/dev/null \
      || sed -i "s/\"archived\"[[:space:]]*:[[:space:]]*null/\"archived\": \"$today\"/" "$J"
    [ -n "$commit" ] && { sed -i '' "s/\"commit\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"commit\": \"$commit\"/" "$J" 2>/dev/null \
      || sed -i "s/\"commit\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"commit\": \"$commit\"/" "$J"; }
    G "  ✓ change.json → status=archived, archived=$today${commit:+, commit=$commit}"
  fi

  # ⑦ parity
  B "⑥ parity"
  [ -f .qey/parity-check.sh ] && { bash .qey/parity-check.sh 2>&1 | tail -1; } || echo "  (无 parity-check.sh)"

  G "✓ 归档完成。踩坑/决策应在 loop 当场写 memory/;/qey-distill 周期审计"
  # 1.7:清 .workflow-state(归档后回 no_change)
  rm -f .qey/.workflow-state
  G "  ✓ .workflow-state 已清(hook 回 no_change breadcrumb)"
  [ "$experimental" = 1 ] && Y "  (experimental:delta 未 merge specs,后续若真上线需重跑归档或手动 merge)"
}

CMD="${1:-}"; shift || true
case "$CMD" in
  run) do_run "$@" ;;
  check) do_check "$@" ;;
  *) R "用法:archive.sh run [--experimental] <id> | check <id>"; exit 1 ;;
esac
