#!/usr/bin/env bash
# attach.sh — 把 qey-harness 接入当前项目(1.3:支持 --adapter 选平台)
# 位置:模板 .qey/ 下(和 rules/ 同级)。模板根 = 本脚本目录的父(SCRIPT_DIR/..)。
# 用法:
#   cd /path/to/project && bash /path/to/qey-harness/.qey/attach.sh [--adapter claude|codex|pi|all]
#   默认 --adapter all(接 claude + codex + pi 全套)
# 本脚本不进项目(复制 .qey 时排除自己,防 project 自引用);从模板跑。

set -uo pipefail

green(){ printf "\033[32m%s\033[0m\n" "$1"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }

# ── 解析 --adapter ──
ADAPTER="all"
for arg in "$@"; do
  case "$arg" in
    --adapter) shift_next=1 ;;
    --adapter=*) ADAPTER="${arg#--adapter=}" ;;
    claude|codex|pi|all) [ "${shift_next:-0}" = 1 ] && { ADAPTER="$arg"; shift_next=0; } ;;
    *) [ "${shift_next:-0}" = 1 ] && { ADAPTER="$arg"; shift_next=0; } ;;
  esac
done
case "$ADAPTER" in
  claude|codex|pi|all) : ;;
  *) red "✗ 未知 adapter:$ADAPTER(支持:claude / codex / pi / all)"; exit 1 ;;
esac

# 模板根 = 脚本所在目录的父(本脚本在 .qey/ 下)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="${QEY_TEMPLATE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# 1. 模板源检查
if [ ! -d "$TEMPLATE/.qey" ] || [ ! -f "$TEMPLATE/.qey/attach.sh" ]; then
  red "✗ 模板源异常:$TEMPLATE/.qey 缺 attach.sh"
  yellow "  设 QEY_TEMPLATE=/path/to/qey-harness 或调整脚本位置"
  exit 2
fi

# 1.3 结构检查:canonical + adapters 必须在
if [ ! -d "$TEMPLATE/.qey/commands" ] || [ ! -d "$TEMPLATE/adapters" ]; then
  red "✗ 模板不是 1.3 结构(缺 .qey/commands/ canonical 或 adapters/)"
  yellow "  当前模板:$TEMPLATE"
  yellow "  需 1.3+ 模板(canonical 抽取 + adapter 注册表)。老模板跑 qey-harness upgrade 升级。"
  exit 2
fi

# 2. 不允许在 HOME 跑
if [ "$(pwd -P)" = "$HOME" ]; then
  red "✗ 不允许在 HOME 目录接入(会污染家目录)。cd 到项目根再跑"
  exit 1
fi

green "▶ 接入 harness 到: $(pwd)  [adapter: $ADAPTER]"
echo "  模板源: $TEMPLATE"
echo ""

# ── 3. .qey/(总是复制;所有 adapter 都需要 canonical + 惯性层)──
if [ -d ".qey" ]; then
  yellow "  ⚠ .qey/ 已存在,只补缺(不覆盖项目填充)"
  # 补 canonical commands(1.3 新)
  mkdir -p .qey/commands
  for cmd in scan qey-commit qey-log qey-distill; do
    [ -f ".qey/commands/$cmd.md" ] || cp "$TEMPLATE/.qey/commands/$cmd.md" ".qey/commands/$cmd.md"
  done
else
  green "  ✓ 复制 .qey/(含 canonical commands + rules/domain/memory/specs/changes/workflow/guardrails)"
  # 复制时排除 attach.sh 本身(脚本只属模板,防 project 自引用)
  (cd "$TEMPLATE" && find .qey -type f ! -name "attach.sh" | while read f; do
    mkdir -p "$(dirname "$f")" && cp "$TEMPLATE/$f" "$f" 2>/dev/null
  done) || {
    # fallback:简单 cp -r 再删 attach.sh
    cp -r "$TEMPLATE/.qey" ./.qey
    rm -f .qey/attach.sh
  }
fi

# ── 辅助:adapter 是否在当前接入选择里 ──
want_adapter(){ case "$ADAPTER" in all) return 0;; *) [ "$ADAPTER" = "$1" ];; esac; }

# ── 4. Claude adapter(从 adapters/claude/ 复制;canonical 单源,薄包装指向它)──
if want_adapter claude; then
  green "▶ Claude adapter"
  mkdir -p .claude/commands .claude/hooks
  for cmd in scan qey-commit qey-log qey-distill; do
    [ -f ".claude/commands/$cmd.md" ] || cp "$TEMPLATE/adapters/claude/commands/$cmd.md" ".claude/commands/$cmd.md"
    green "  ✓ .claude/commands/$cmd.md(薄包装 → canonical)"
  done
  for h in find-code-reminder.sh recap-stop-hook.sh workflow-state-reminder.sh; do
    [ -f ".claude/hooks/$h" ] || cp "$TEMPLATE/adapters/claude/hooks/$h" ".claude/hooks/$h"
  done
  [ -f ".claude/settings.json" ] || cp "$TEMPLATE/adapters/claude/settings.json" ".claude/settings.json"
  green "  ✓ Claude hooks + settings.json(Stop + UserPromptSubmit hook)"

  # CLAUDE.md(已存在不覆盖)
  if [ -f ".claude/CLAUDE.md" ]; then
    yellow "  ⚠ .claude/CLAUDE.md 已存在,保留(qey-init 追加不覆盖)"
  else
    cp "$TEMPLATE/CLAUDE.md" ".claude/CLAUDE.md"
    green "  ✓ .claude/CLAUDE.md(skeleton,含 [qey-init 填充] 占位)"
  fi

  # AGENTS.md 软链 → .claude/CLAUDE.md(同源防 drift;Codex/omp 读根 AGENTS.md)
  if [ ! -e "AGENTS.md" ] && [ -f ".claude/CLAUDE.md" ]; then
    ln -s .claude/CLAUDE.md AGENTS.md
    green "  ✓ AGENTS.md -> .claude/CLAUDE.md(软链)"
  fi
fi

# ── 5. Codex adapter(agents 薄包装 + codex hooks;复用 agents adapter)──
if want_adapter codex; then
  green "▶ Codex adapter(via agents + codex hooks)"
  # agents 薄包装(Codex / 通用 agent 读 .agents/skills/)
  mkdir -p .agents/skills
  for skill_dir in "$TEMPLATE"/adapters/agents/skills/source-command-*; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    if [ ! -d ".agents/skills/$name" ]; then
      mkdir -p ".agents/skills/$name"
      cp "$skill_dir/SKILL.md" ".agents/skills/$name/SKILL.md"
    fi
  done
  green "  ✓ .agents/skills/source-command-*(薄包装 → canonical)"

  # codex hooks
  if [ ! -d ".codex" ]; then
    mkdir -p .codex/hooks
    cp "$TEMPLATE/adapters/codex/hooks.json" .codex/hooks.json
    # Stop hook 软链 → .claude/hooks/(单源)
    if [ -f ".claude/hooks/recap-stop-hook.sh" ]; then
      ln -sf ../../.claude/hooks/recap-stop-hook.sh .codex/hooks/recap-stop-hook.sh
    fi
    green "  ✓ .codex/hooks.json + hook 软链"
  fi
fi

# ── 6. pi adapter(omp 独有增强层:RULES sticky + config 权限 + TS hooks)──
if want_adapter pi; then
  green "▶ pi(omp)adapter"
  mkdir -p .omp/commands .omp/extensions

  # commands 薄包装(omp native provider,priority 100;独立于 claude)
  for cmd in scan qey-commit qey-log qey-distill; do
    [ -f ".omp/commands/$cmd.md" ] || cp "$TEMPLATE/adapters/pi/commands/$cmd.md" ".omp/commands/$cmd.md"
  done
  green "  ✓ .omp/commands/*.md(薄包装 → canonical;native provider,disabledProviders:[claude] 也工作)"

  # RULES.md(sticky 红线,always-apply)
  [ -f ".omp/RULES.md" ] || cp "$TEMPLATE/adapters/pi/RULES.md" .omp/RULES.md
  green "  ✓ .omp/RULES.md(6 条硬红线 sticky,长对话不失效)"

  # config.yml(权限映射;若已存在项目配置,只补 bash.patterns 的缺项)
  if [ ! -f ".omp/config.yml" ]; then
    cp "$TEMPLATE/adapters/pi/config.yml" .omp/config.yml
    green "  ✓ .omp/config.yml(权限:bash.patterns 精细 allow/prompt/deny)"
  else
    yellow "  ⚠ .omp/config.yml 已存在,保留(手动 merge bash.patterns 或删了重 attach)"
  fi

  # TS extensions(4 个 hook:find-code / recap-stop / safety-block / workflow-state)
  for h in qey-find-code.ts qey-recap-stop.ts qey-safety-block.ts qey-workflow-state.ts; do
    [ -f ".omp/extensions/$h" ] || cp "$TEMPLATE/adapters/pi/extensions/$h" ".omp/extensions/$h"
  done
  green "  ✓ .omp/extensions/{find-code,recap-stop,safety-block}.ts"
  echo "    find-code:找代码提醒(before_agent_start,替代 Claude UserPromptSubmit hook)"
  echo "    recap-stop:沉淀提醒(turn_end + session_shutdown;⚠ omp 无法强制拦截,见设计 doc 能力差距)"
  echo "    safety-block:Write/Edit 受保护文件拦截(tool_call,omp 独有,补 Claude 做不到的)"
fi

# ── 7. 验证 ──
echo ""
green "▶ 验证"
ok=1
# canonical 必有
for f in .qey/commands/scan.md .qey/commands/qey-commit.md .qey/manifest.json .qey/guards/parity-check.sh .qey/rules/git提交规范.md .qey/guardrails/permissions.md; do
  if [ -f "$f" ]; then green "  ✓ $f"; else red "  ✗ 缺 $f"; ok=0; fi
done
# adapter 特定
if want_adapter claude; then
  for f in .claude/commands/scan.md .claude/hooks/find-code-reminder.sh .claude/settings.json .claude/CLAUDE.md AGENTS.md; do
    [ -e "$f" ] && green "  ✓ $f" || { red "  ✗ 缺 $f"; ok=0; }
  done
fi
if want_adapter codex; then
  for f in .agents/skills/source-commit/SKILL.md .codex/hooks.json; do
    [ -e "$f" ] && green "  ✓ $f" || { red "  ✗ 缺 $f"; ok=0; }
  done
fi
if want_adapter pi; then
  for f in .omp/commands/qey-commit.md .omp/RULES.md .omp/config.yml .omp/extensions/qey-safety-block.ts; do
    [ -e "$f" ] && green "  ✓ $f" || { red "  ✗ 缺 $f"; ok=0; }
  done
fi
[ -f ".qey/attach.sh" ] && red "  ✗ .qey/attach.sh 不该在项目(脚本只属模板)" || green "  ✓ 项目无引导脚本(干净)"

# ── 8. 下一步 ──
echo ""
if [ "$ok" = 1 ]; then
  green "✓ harness 接入完成(adapter: $ADAPTER)"
else
  red "✗ 接入异常(见上 ✗),修了再继续"
fi
cat <<EOF

  下一步:
  1. 在本项目启动 Claude Code / omp
  2. 跑扫描填充(AI 命令):
     /qey:scan              # 默认 quick 全景(技术栈/目录/架构/术语)
     /qey:scan deep         # 全景 + 数据 + 流程
     /qey:scan drill <模块> # 深挖特定模块
  3. (omp)启动后验证:
     - /qey:commit /qey:scan 能跑(读 canonical)
     - RULES.md 生效(改 .env 会被 qey-safety-block 拦截)
     - bash.patterns 生效(git push --force 被 deny)

  日常命令:
     /qey:commit            引导式提交(+归档 +MR)
     /qey:log               机械日志(会话结束跑)
     /qey:distill           知识提炼(周期跑)

  CLI:
     qey change new|list|archive ...
     qey doctor             体检(版本/漂移/adapter)
     qey update             同步最新模板
EOF
