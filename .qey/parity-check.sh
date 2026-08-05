#!/usr/bin/env bash
# parity-check.sh — 检测 harness 多 adapter drift(Layer B parity test)
# 1.3:扩展三平台(claude/codex/pi)+ canonical 一致性检查
#
# 查:
#   ① canonical 存在(.qey/commands/*.md,4 个)
#   ② 三 adapter 薄包装指向 canonical(claude/agents/pi)
#   ③ 三 adapter 薄包装 description 与 canonical 一致(防 drift)
#   ④ AGENTS→CLAUDE 软链(模板)/AGENTS→.claude/CLAUDE.md(项目)
#   ⑤ .codex/hooks.json 无绝对路径
#   ⑥ 无 .Codex 大写(macOS 能跑 Linux 断)
#   ⑦ manifest overwrite 关键文件存在
#   ⑧ (pi adapter 在时)TS hook 文件就位
#
# 用法:bash .qey/parity-check.sh   (在模板根或项目根跑)
# 退出码:0 = OK,1 = 有 drift(见上 ✗)
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fail=0
ok(){ printf "  ✓ %s\n" "$1"; }
bad(){ printf "  ✗ %s\n" "$1"; fail=1; }
warn(){ printf "  ⚠ %s\n" "$1"; }

# 判断当前位置:模板根(有 bin/qey-harness + HOW_TO_USE.md)还是项目根
# 不用 adapters/(upgrade 不该把 adapters/ 进项目,但历史可能误留;bin/qey-harness 是模板独有)
IS_TEMPLATE=0
{ [ -f bin/qey-harness ] || [ -f HOW_TO_USE.md ]; } && IS_TEMPLATE=1

echo "▶ adapter parity check ($([ "$IS_TEMPLATE" = 1 ] && echo '模板根' || echo '项目根'))"

# ── ① canonical 存在(只在模板根查;项目根的 canonical 由 hash-check 守)──
if [ "$IS_TEMPLATE" = 1 ]; then
  miss=0
  for cmd in scan qey-commit qey-log qey-distill; do
    [ -f ".qey/commands/$cmd.md" ] || { bad "canonical 缺: .qey/commands/$cmd.md"; miss=1; }
  done
  [ "$miss" = 0 ] && ok "canonical 5 命令齐(.qey/commands/)"
fi

# ── ② 三 adapter 薄包装指向 canonical ──
# claude 薄包装
check_wrapper_points() {
  local adapter="$1" dir="$2" marker="$3"
  [ -d "$dir" ] || return 0  # adapter 不在时跳过(项目模式只接了部分 adapter)
  local found=0 miss=0
  for cmd in scan qey-commit qey-log qey-distill; do
    local f="$dir/$cmd.md"
    [ -f "$f" ] || { continue; }
    found=$((found+1))
    if ! grep -q "$marker" "$f" 2>/dev/null; then
      bad "$adapter 薄包装 $cmd 未指向 canonical(应含 $marker)"
      miss=1
    fi
  done
  [ "$miss" = 0 ] && [ "$found" -gt 0 ] && ok "$adapter 薄包装($found 个)指向 canonical"
}

if [ "$IS_TEMPLATE" = 1 ]; then
  check_wrapper_points "claude" "adapters/claude/commands" ".qey/commands/"
  check_wrapper_points "pi" "adapters/pi/commands" ".qey/commands/"
fi

# agents 薄包装(SKILL.md 形式)
check_agents_skill() {
  local base="$1"
  [ -d "$base" ] || return 0
  local found=0 miss=0
  for d in "$base"/source-command-*/SKILL.md; do
    [ -f "$d" ] || continue
    found=$((found+1))
    local cmd=$(basename "$(dirname "$d")" | sed 's/source-command-//')
    # 指向新 canonical(.qey/commands/),非旧 .claude/commands/
    if grep -q ".qey/commands/$cmd.md" "$d"; then : # ok
    else bad "agents 薄包装 source-command-$cmd 应指向 .qey/commands/$cmd.md(新 canonical)"; miss=1; fi
    # 不嵌命令体(防从 canonical 复制内容导致 drift)
    if grep -qE "^## (Step|阶段|步骤|执行流程)" "$d"; then bad "source-command-$cmd 嵌了命令体(应薄包装)"; miss=1; fi
  done
  [ "$miss" = 0 ] && [ "$found" -gt 0 ] && ok "agents 薄包装($found 个)指向新 canonical"
}

if [ "$IS_TEMPLATE" = 1 ]; then
  check_agents_skill "adapters/agents/skills"
else
  check_agents_skill ".agents/skills"
fi

# ── ③ description 跨 adapter 一致性(只在模板根查)──
if [ "$IS_TEMPLATE" = 1 ]; then
  for cmd in scan qey-commit qey-log qey-distill; do
    canon_desc=$(grep -m1 "^description:" ".qey/commands/$cmd.md" 2>/dev/null | sed 's/^description:[[:space:]]*//')
    [ -z "$canon_desc" ] && continue
    for adapter_dir in adapters/claude/commands adapters/pi/commands; do
      f="$adapter_dir/$cmd.md"
      [ -f "$f" ] || continue
      adapter_desc=$(grep -m1 "^description:" "$f" 2>/dev/null | sed 's/^description:[[:space:]]*//')
      if [ "$canon_desc" != "$adapter_desc" ]; then
        bad "$cmd description drift: canonical ≠ $(dirname $adapter_dir | sed 's|adapters/||')"
      fi
    done
  done
  ok "description 跨 adapter 一致性已检查"
fi

# ── ④ AGENTS.md → CLAUDE.md 软链 ──
if [ -L AGENTS.md ] && [ -e AGENTS.md ]; then
  tgt=$(readlink AGENTS.md)
  case "$(basename "$tgt")" in
    CLAUDE.md) ok "AGENTS.md -> $tgt(→ CLAUDE,同源)";;
    *) bad "AGENTS.md 软链目标非 CLAUDE.md(现:$tgt)";;
  esac
else
  warn "AGENTS.md 非软链(模板应软链 CLAUDE.md;项目 attach 时建)"
fi

# ── ⑤ .codex/hooks.json 无绝对路径 ──
if [ -f .codex/hooks.json ]; then
  if grep -qE "/Users/|/home/|/root/" .codex/hooks.json; then
    bad ".codex/hooks.json 含绝对路径(应相对)"
  else ok ".codex/hooks.json 相对路径"; fi
fi

# ── ⑥ 无 .Codex 大写 ──
if find . -maxdepth 3 -name ".Codex" -not -path "./.git/*" 2>/dev/null | grep -q .; then
  bad "存在 .Codex 大写(应 .codex)"
else ok "无 .Codex 大写"; fi

# ── ⑦ manifest overwrite 关键文件存在 ──
miss=0
for f in .qey/changes/_template.md .qey/changes/README.md .qey/specs/README.md .qey/manifest.json; do
  [ -f "$f" ] || { bad "manifest overwrite 文件缺: $f"; miss=1; }
done
# canonical 或 claude 命令至少有一套(模板 canonical + claude;项目只 claude)
[ -f ".qey/commands/qey-log.md" ] || [ -f ".claude/commands/qey-log.md" ] || { bad "命令 qey-log.md 缺(canonical + claude 都没有)"; miss=1; }
[ -f ".qey/commands/qey-distill.md" ] || [ -f ".claude/commands/qey-distill.md" ] || { bad "命令 qey-distill.md 缺(canonical + claude 都没有)"; miss=1; }
[ "$miss" = 0 ] && ok "manifest overwrite 关键文件齐"

# ── ⑧ (pi adapter 在时)TS hook 文件就位 ──
pi_check_dir="$([ "$IS_TEMPLATE" = 1 ] && echo 'adapters/pi/extensions' || echo '.omp/extensions')"
if [ -d "$pi_check_dir" ]; then
  miss=0
  for h in qey-find-code.ts qey-recap-stop.ts qey-safety-block.ts; do
    [ -f "$pi_check_dir/$h" ] || { bad "pi extension 缺: $h"; miss=1; }
  done
  [ "$miss" = 0 ] && ok "pi TS hooks 3 个齐"
fi

# ── ⑨ pi adapter 在时,RULES.md + config.yml 就位 ──
pi_base="$([ "$IS_TEMPLATE" = 1 ] && echo 'adapters/pi' || echo '.omp')"
if [ -d "$pi_base" ] || [ "$pi_base" = ".omp" ]; then
  miss=0
  [ -f "$pi_base/RULES.md" ] || { [ "$IS_TEMPLATE" = 1 ] && bad "adapters/pi/RULES.md 缺" || warn ".omp/RULES.md 缺(attach --adapter pi 时应产出)"; }
  [ -f "$pi_base/config.yml" ] || { [ "$IS_TEMPLATE" = 1 ] && bad "adapters/pi/config.yml 缺" || warn ".omp/config.yml 缺"; }
fi

echo ""
if [ "$fail" = 0 ]; then echo "✓ parity OK"; exit 0
else echo "✗ parity FAIL(见上 ✗)——adapter drift,修了再提交"; exit 1; fi
