#!/usr/bin/env bash
# change.sh — change 生命周期脚本,让 specs↔changes↔archive 真落地(不只靠 AI 自觉)
# 用法:
#   bash .qey/change.sh create <id> [域]   # 建 changes/<id>/ 骨架(change.json+proposal+design+tasks+specs+context.jsonl)
#   bash .qey/change.sh list               # 列所有 change(进行中 + archive)+ 状态
#   bash .qey/change.sh archive <id>       # 验 evidence + 助 delta merge + 移 archive + 更新 change.json + parity
set -uo pipefail
G(){ printf "\033[32m%s\033[0m\n" "$1"; }
Y(){ printf "\033[33m%s\033[0m\n" "$1"; }
R(){ printf "\033[31m%s\033[0m\n" "$1"; }
ask(){ printf "\033[36m? %s [y/N]\033[0m " "$1"; read r; [ "$r" = "y" ] || [ "$r" = "Y" ]; }
B(){ printf "\033[1m%s\033[0m\n" "$1"; }
C=".qey/changes"

CMD="${1:-}"
[ -n "$CMD" ] || { R "用法:change.sh create|list|archive ..."; exit 1; }

case "$CMD" in
create)
  ID="${2:-}"; DOMAIN="${3:-}"
  [ -n "$ID" ] || { R "用法:change.sh create <id> [域]"; exit 1; }
  [ -d "$C/$ID" ] && { R "✗ $C/$ID 已存在"; exit 1; }
  mkdir -p "$C/$ID/specs"
  TODAY=$(date +%Y-%m-%d)
  # change.json(结构化元数据;可 list/查询/状态机读)
  cat > "$C/$ID/change.json" <<EOF
{
  "id": "$ID",
  "title": "",
  "status": "planning",
  "priority": "P2",
  "domain": "$DOMAIN",
  "assignee": "",
  "branch": "",
  "base_branch": "master",
  "created": "$TODAY",
  "archived": null,
  "commit": "",
  "relatedFiles": [],
  "subtasks": [],
  "parent": null
}
EOF
  cat > "$C/$ID/proposal.md" <<EOF
# Proposal:$ID
> 为什么 + 范围 + AC + 风险(做什么);怎么做见 design.md,delta 见 specs/。结构参考 _template.md。

## 背景(为什么)
## 边界
- ✅ 包含:
- ❌ 不包含:
## 验收标准(AC)⭐ 可逐条核对
- [ ] AC1:
## 风险 & 缓解(含需求侧异常)
| 风险 | 缓解 |
|------|------|
## 待定问题(Open Q,实现前清空)
-
## 依赖
-
EOF
  cat > "$C/$ID/design.md" <<EOF
# Design:$ID
> 怎么实现(设计决策/架构/步骤)。满足 ADR 三门槛(难逆/反直觉/真实取舍)→ 落 knowledge/业务演进/。

## 设计决策
## 架构 / 组件
## 实现步骤(→ tasks 拆解)
EOF
  cat > "$C/$ID/tasks.md" <<EOF
# Tasks:$ID
> Scenario 驱动:每 task = 一个 Scenario 的 red→green;实现期填 evidence。

## AC → Scenario → Seam(测试契约,设计期定)
| AC | Scenario(Given/When/Then) | Seam |
|----|---------------------------|------|
| AC1 | Given …;When …;Then … | <类::方法 / API> |
> 不在设计期写死测试名/断言(防 horizontal slicing)。

## 证据(⑥ 每 Scenario,实现期填;归档前必齐)
### AC1 / Seam:<类::方法>
- RED  : <测试命令> → <exit 1 + 关键输出>
- GREEN: <测试命令> → <exit 0, N passed>
- 回归 : <全量测试命令> → <exit 0, M passed>
- verified@commit: <hash> ($TODAY)
> hash 必须 git 真实存在;归档时 change.sh 用 git rev-parse 验(落盘判定,不信自报)

## 任务(每 task 实现 ≥1 Scenario)
- [ ] task1 → AC1
EOF
  cat > "$C/$ID/implement.jsonl" <<EOF
# implement.jsonl — 实现 agent 该读的(domain/specs 改前真相/design/rules;规划期填)
# 格式:每行 <文件路径>|<为什么读>,例:
# .qey/domain/业务流程.md|链路入口
# .qey/specs/订单/spec.md|当前行为真相(改前,对照 delta)
# .qey/rules/各层规范.md|分层写法
EOF
  cat > "$C/$ID/check.jsonl" <<EOF
# check.jsonl — 检查 agent 该读的(AC/specs 一致性/域约束/rules;验证用,可能 ≠ implement)
# 格式:每行 <文件路径>|<为什么读>,例:
# .qey/specs/订单/spec.md|验证实现后行为真相一致
# .qey/changes/$ID/tasks.md|AC + evidence 核对
# .qey/rules/安全规范.md|安全底线核对
EOF
  # 归档.md(1.5:建骨架时就带,开发过程中持续填;归档时自动填 frontmatter)
  if [ -f "$C/归档_template.md" ]; then
    sed "s/<change-id 或 title>/$ID/" "$C/归档_template.md" > "$C/$ID/归档.md"
  fi
  G "✓ 建 $C/$ID/ (change.json + proposal + design + tasks + specs/ + implement.jsonl + check.jsonl + 归档.md)"
  echo "  下一步:填 change.json(title)→ proposal(为什么+AC+风险)→ design → tasks(Scenario+Seam)→ specs/<域>.md(delta)"
  echo "  归档.md 骨架已建,开发过程中随时填'踩的坑/决策/后续待办'(事件驱动,不拖归档时)"
  # 1.7:写 .workflow-state(hook 每 turn 读,注入 planning breadcrumb)
  printf "change_id=%s\nstage=planning\n" "$ID" > .qey/.workflow-state
  G "  ✓ .workflow-state → planning(hook 每 turn 注入 workflow 提醒)"
  ;;

list)
  getk(){ k=$(grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$d" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/'); echo "$k"; }
  printf "\033[1m▶ changes(id · status · priority · domain · created)\033[0m  📦=已归档\n"
  printf "  %-26s %-12s %-4s %-12s %-12s\n" "ID" "STATUS" "PRI" "DOMAIN" "CREATED"
  for d in "$C"/*/change.json "$C"/archive/*/change.json; do
    [ -f "$d" ] || continue
    id=$(getk id); st=$(getk status); pri=$(getk priority); dom=$(getk domain); cr=$(getk created)
    arc=""; case "$d" in *"/archive/"*) arc="📦";; esac
    [ -z "$st" ] && st="?"
    printf "  %-26s %-12s %-4s %-12s %-12s %s\n" "$id" "$st" "$pri" "$dom" "$cr" "$arc"
  done
  ;;
start)
  # 1.7:显式 planning→in_progress(经 review gate)
  ID="${2:-}"
  [ -n "$ID" ] || { R "用法:change.sh start <id>"; exit 1; }
  D="$C/$ID"
  [ -d "$D" ] || { R "✗ $D 不存在"; exit 1; }
  B "▶ start $ID(planning → in_progress)"
  # review gate:proposal AC + tasks Scenario→Seam 必须有实质内容(非模板占位)
  miss=0
  # proposal.md:AC 行要有实质描述(冒号后有内容,排除空占位)
  ac_filled=$(grep -E 'AC[0-9]+:' "$D/proposal.md" 2>/dev/null | grep -vE 'AC[0-9]+:[[:space:]]*$|AC[0-9]+:[[:space:]]*<|AC[0-9]+:[[:space:]]*可验证' | head -1)
  [ -n "$ac_filled" ] || { Y "  ⚠ proposal.md 缺实质 AC(验收标准要有具体描述,非空占位)"; miss=1; }
  # tasks.md:Scenario→Seam 表要有数据行(AC| 开头,排除表头)
  seam_row=$(grep -E '^\| *AC[0-9]' "$D/tasks.md" 2>/dev/null | grep -vE 'Scenario.*Given' | head -1)
  [ -n "$seam_row" ] || { Y "  ⚠ tasks.md 缺 Scenario→Seam 数据行(表里要有 AC 对应的 Scenario + Seam)"; miss=1; }
  if [ "$miss" = 1 ]; then
    R "  ✗ review gate 不过:proposal/tasks 未填齐。先填再 start"
    Y "  (proposal 的 AC + tasks 的 Scenario→Seam 是 Stage 1→2 硬闸:无批准 Scenario → 不实现)"
    exit 1
  fi
  G "  ✓ review gate 通过(AC 有实质 + Scenario→Seam 有数据)"
  # 改 change.json.status
  if [ -f "$D/change.json" ]; then
    sed -i '' 's/"status"[[:space:]]*:[[:space:]]*"[^"]*"/"status": "in_progress"/' "$D/change.json" 2>/dev/null \
      || sed -i 's/"status"[[:space:]]*:[[:space:]]*"[^"]*"/"status": "in_progress"/' "$D/change.json"
    G "  ✓ change.json → status=in_progress"
  fi
  # 写 .workflow-state(hook 读)
  printf "change_id=%s\nstage=in_progress\n" "$ID" > .qey/.workflow-state
  G "  ✓ .workflow-state → in_progress(hook 每 turn 注入:按 Scenario TDD + 填 evidence)"
  ;;

archive)
  ID="${2:-}"
  [ -n "$ID" ] || { R "用法:change.sh archive <id>"; exit 1; }
  D="$C/$ID"
  [ -d "$D" ] || { R "✗ $D 不存在"; exit 1; }
  [ -d "$C/archive" ] || mkdir -p "$C/archive"
  [ -d "$C/archive/$ID" ] && { R "✗ $C/archive/$ID 已在(归档过?)"; exit 1; }

  printf "\033[1m▶ archive $ID\n\033[0m"
  # ① 验 evidence
  printf "\033[1m① 验 evidence\033[0m\n"
  acs=$(grep -cE '^### AC[0-9]' "$D/tasks.md" 2>/dev/null); [ -n "$acs" ] || acs=0
  ev=$(grep -c 'verified@commit' "$D/tasks.md" 2>/dev/null); [ -n "$ev" ] || ev=0
  printf "  Scenario(### AC):%s | evidence(verified@commit):%s\n" "$acs" "$ev"
  if [ "$ev" -lt "$acs" ] 2>/dev/null; then
    Y "  ⚠ evidence 不足($ev/$acs)"
    ask "  归档前应补齐,仍继续?" || { echo "  中止(先补 evidence)"; exit 1; }
  else G "  ✓ evidence 齐"; fi
  # 落盘判定:verified@commit 的 hash 必须 git 真实存在(成功以落盘为准,不信自报;防编造 hash 过闸)
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fake=0; checked=0
    hashes=$(grep -oE 'verified@commit:[[:space:]]*[0-9a-fA-F]+' "$D/tasks.md" 2>/dev/null | sed -E 's/.*:[[:space:]]*([0-9a-fA-F]+)/\1/')
    for h in $hashes; do
      [ -n "$h" ] || continue
      checked=$((checked+1))
      git rev-parse --verify --quiet "${h}^{commit}" >/dev/null 2>&1 || { Y "  ✗ hash 不存在/未提交:$h"; fake=$((fake+1)); }
    done
    if [ "$checked" -gt 0 ]; then
      printf "  hash 落盘校验:查 %s 个,%s 个不真实\n" "$checked" "$fake"
      if [ "$fake" -gt 0 ]; then
        Y "  ⚠ verified@commit 的 hash 有编造/未提交($fake 个)— 落盘判定不过"
        ask "  仍继续归档?" || { echo "  中止(hash 不真实)"; exit 1; }
      else G "  ✓ hash 全部真实存在(git 落盘)"; fi
    fi
  else Y "  (非 git 仓库,跳过 hash 落盘校验——仅数数量)"; fi

  # ② delta → specs merge(脚本做不了语义 merge,助查 + 提示手动)
  printf "\033[1m② delta(specs/<域>.md)→ merge 进 specs/<域>/spec.md\033[0m\n"
  found=0
  for delta in "$D"/specs/*.md; do [ -f "$delta" ] || continue; found=1
    域=$(basename "$delta" .md)
    printf "  delta:%s\n" "$delta"
    if [ -f ".qey/specs/$域/spec.md" ]; then
      printf "    → 手动 apply 到 .qey/specs/%s/spec.md(ADDED 追加 / MODIFIED 覆盖 / REMOVED 删除)\n" "$域"
    else
      printf "    → .qey/specs/%s/spec.md 不存在 → 新建(用 specs/_template.md)\n" "$域"
    fi
  done
  [ "$found" = 0 ] && Y "  ⚠ 无 delta(specs/*.md)— change 没行为变化?或忘了写"
  ask "  delta 已 merge 进 specs/?(y 继续)" || { echo "  先 merge 再归档"; exit 1; }

  # ③ 移目录
  mv "$D" "$C/archive/$ID"
  G "  ✓ $ID → $C/archive/$ID/"

  # ④ 更新 change.json(status→archived)
  if [ -f "$C/archive/$ID/change.json" ]; then
    TODAY=$(date +%Y-%m-%d); COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
    J="$C/archive/$ID/change.json"
    sed -i '' "s/\"status\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"status\": \"archived\"/" "$J" 2>/dev/null \
      || sed -i "s/\"status\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"status\": \"archived\"/" "$J"
    sed -i '' "s/\"archived\"[[:space:]]*:[[:space:]]*null/\"archived\": \"$TODAY\"/" "$J" 2>/dev/null \
      || sed -i "s/\"archived\"[[:space:]]*:[[:space:]]*null/\"archived\": \"$TODAY\"/" "$J"
    [ -n "$COMMIT" ] && { sed -i '' "s/\"commit\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"commit\": \"$COMMIT\"/" "$J" 2>/dev/null \
      || sed -i "s/\"commit\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"commit\": \"$COMMIT\"/" "$J"; }
    G "  ✓ change.json → status=archived, archived=$TODAY${COMMIT:+, commit=$COMMIT}"
  fi
  [ -f "$C/archive/$ID/归档.md" ] || Y "  ⚠ 缺 归档.md(加 frontmatter + 实际改动/坑/上线)— 可后补"

  # ⑤ parity
  printf "\033[1m③ parity\033[0m\n"
  [ -f .qey/parity-check.sh ] && { bash .qey/parity-check.sh 2>&1 | tail -1; } || echo "  (无 parity-check.sh)"
  G "✓ 归档完成。踩坑/决策应在 loop 当场写 memory/;/recap 周期审计"
  ;;

*) R "未知命令:$CMD(用 create|list|archive)"; exit 1 ;;
esac
