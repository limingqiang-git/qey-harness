#!/usr/bin/env bash
# hash-check.sh — 比对项目 overwrite 文件 vs 模板的 SHA256,列出漂移的(精确到文件,不依赖版本号)
# 解决:版本相同但内容漂(/qey-update 按版本 skip 的 bug)→ 哈希精确抓
# 用法:bash .qey/hash-check.sh [template-path]
#   template: $1 或 $QEY_TEMPLATE 或 ~/qey-harness
# 退出:0=无漂移,1=有漂移/缺文件
set -u
TEMPLATE="${1:-${QEY_TEMPLATE:-$HOME/qey-harness}}"
[ -d "$TEMPLATE/.qey" ] || { printf "\033[31m✗ 模板不存在:%s/.qey(设 QEY_TEMPLATE)\033[0m\n" "$TEMPLATE"; exit 2; }

# overwrite 文件清单(纯通用模板;与 manifest.json / upgrade 脚本保持一致)
# 1.3:加 .qey/commands/(canonical)+ adapters/(三平台薄包装)
# 注意:diff_only(domain 实例/memory 实例/specs/<域>/changes/<id>/CLAUDE/settings.local/.omp/config.yml)不在此——它们本就该和模板不同
OVERWRITE=( ".qey/commands" ".qey/workflow" ".qey/rules/index.md" ".qey/rules/git提交规范.md" ".qey/rules/代码注释规范.md" \
  ".qey/rules/安全规范.md" ".qey/rules/错误处理规范.md" ".qey/rules/日志规范.md" \
  ".qey/rules/外部调用规范.md" ".qey/rules/backend" ".qey/rules/database" ".qey/rules/thinking-guides" ".qey/agents" ".qey/guardrails/permissions.md" \
  ".qey/changes/_template.md" ".qey/changes/README.md" \
  ".qey/specs/_template.md" ".qey/specs/README.md" \
  ".qey/memory/README.md .qey/knowledge/README.md" ".qey/journal" \
  ".qey/knowledge/踩坑记录/_template.md" ".qey/knowledge/业务演进/_template.md" \
  ".qey/domain/业务领域/_template.md" ".qey/domain/README.md" ".qey/README.md" \
  ".qey/parity-check.sh" ".qey/hash-check.sh" ".qey/change.sh" ".qey/log.sh" \
  "adapters" \
  ".claude/commands" ".claude/hooks" ".claude/settings.json" \
  ".codex/hooks.json" "HOW_TO_USE.md" )

# 可移植 sha256(macOS: shasum -a 256;Linux: sha256sum)
shasum_cmd(){ sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

G(){ printf "\033[32m%s\033[0m\n" "$1"; }
Y(){ printf "\033[33m%s\033[0m\n" "$1"; }

printf "\033[1m▶ hash-check(项目 vs 模板,SHA256,不查版本号)\033[0m\n  模板:%s\n" "$TEMPLATE"
drifted=0; clean=0; missing=0
drift_list=""
for f in "${OVERWRITE[@]}"; do
  src="$TEMPLATE/$f"; [ -e "$src" ] || continue
  if [ -d "$src" ]; then
    for sub in "$src"/*; do [ -e "$sub" ] || continue; s=$(basename "$sub"); d="$f/$s"
      if [ ! -e "$d" ]; then drift_list="$drift_list\n    + 缺 $d"; missing=$((missing+1)); continue; fi
      h1=$(shasum_cmd "$sub"); h2=$(shasum_cmd "$d")
      [ "$h1" = "$h2" ] && clean=$((clean+1)) || { drift_list="$drift_list\n    ≠ 漂移 $d"; drifted=$((drifted+1)); }
    done
  else
    if [ ! -e "$f" ]; then drift_list="$drift_list\n    + 缺 $f"; missing=$((missing+1)); continue; fi
    h1=$(shasum_cmd "$src"); h2=$(shasum_cmd "$f")
    [ "$h1" = "$h2" ] && clean=$((clean+1)) || { drift_list="$drift_list\n    ≠ 漂移 $f"; drifted=$((drifted+1)); }
  fi
done

printf "  干净:\033[32m%s\033[0m  漂移:\033[33m%s\033[0m  缺失:\033[33m%s\033[0m\n" "$clean" "$drifted" "$missing"
total=$((drifted+missing))
if [ "$total" = 0 ]; then G "✓ 无漂移(所有 overwrite 文件 = 模板)"; exit 0
else
  Y "✗ 有漂移(下面 ≠/+)——跑 /qey-update 或 upgrade 脚本同步:"
  printf "%b\n" "$drift_list"; exit 1
fi
