#!/usr/bin/env bash
# evidence.sh — 跑测试 + 抓 exit code + 输出摘要(归档 evidence 闸的机械引擎)
# 1.5 新增:把"跑测试验证 evidence"从 LLM 抽出来,sh 确定性执行。
#
# 用法:
#   bash .qey/evidence.sh run [test_cmd]   # 跑测试,输出 evidence.log + exit code 摘要
#   bash .qey/evidence.sh verify <hash>     # 验 git commit hash 真实(落盘判定)
#   bash .qey/evidence.sh check <change-id> # 验 change 的 tasks.md evidence 齐(数量 + hash 真实)
#
# 技术栈自动检测(无 test_cmd 参数时):
#   composer.json → php artisan test
#   package.json (含 phpunit) → phpunit
#   package.json (含 jest/vitest) → npm test
#   go.mod → go test ./...
#   Cargo.toml → cargo test
#   pom.xml → mvn test
#   否则 → 提示用户指定 test_cmd
#
# 输出(run):.qey/.evidence.log(测试输出摘要)+ stdout JSON 摘要
#   { "exit": 0/1, "passed": N, "failed": N, "tail": "最后 20 行", "timestamp": "..." }
set -uo pipefail
G(){ printf "\033[32m%s\033[0m\n" "$1"; }
Y(){ printf "\033[33m%s\033[0m\n" "$1"; }
R(){ printf "\033[31m%s\033[0m\n" "$1"; }
B(){ printf "\033[1m%s\033[0m\n" "$1"; }

C=".qey/changes"
EVIDENCE_LOG=".qey/.evidence.log"

# 自动检测测试命令
detect_test_cmd(){
  [ -f composer.json ] && { echo "php artisan test"; return; }
  [ -f phpunit.xml ] && { echo "./vendor/bin/phpunit"; return; }
  if [ -f package.json ]; then
    grep -q '"jest"\|"vitest"' package.json 2>/dev/null && { echo "npm test"; return; }
    grep -q '"mocha"' package.json 2>/dev/null && { echo "npm test"; return; }
  fi
  [ -f go.mod ] && { echo "go test ./..."; return; }
  [ -f Cargo.toml ] && { echo "cargo test"; return; }
  [ -f pom.xml ] && { echo "mvn test"; return; }
  [ -f pytest.ini ] && { echo "pytest"; return; }
  [ -f tox.ini ] && { echo "tox"; return; }
  echo ""  # 没检测到
}

# run 子命令:跑测试 + 抓 exit/output
run_tests(){
  local test_cmd="${1:-}"
  if [ -z "$test_cmd" ]; then
    test_cmd=$(detect_test_cmd)
    if [ -z "$test_cmd" ]; then
      R "✗ 未检测到测试命令(无 composer.json/package.json/go.mod 等)"
      Y "  手动指定:bash .qey/evidence.sh run \"<测试命令>\""
      Y "  或建 .qey/evidence.config 指定(格式:cmd=xxx timeout=300)"
      exit 2
    fi
    B "▶ 自动检测测试命令:$test_cmd"
  fi

  # 超时(从 evidence.config 读,默认 600s)
  local timeout=600
  [ -f .qey/evidence.config ] && timeout=$(grep -E '^timeout=' .qey/evidence.config | cut -d= -f2 || echo 600)
  [ -z "$timeout" ] && timeout=600

  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  B "▶ 跑测试(超时 ${timeout}s):$test_cmd"

  # 跑测试,抓输出 + exit code(不 set -e,要抓失败)
  local tmp_out=$(mktemp)
  local exit_code=0
  ( eval "$test_cmd" ) > "$tmp_out" 2>&1 || exit_code=$?

  # 存完整日志
  cp "$tmp_out" "$EVIDENCE_LOG"
  echo "timestamp: $ts" >> "$EVIDENCE_LOG"
  echo "cmd: $test_cmd" >> "$EVIDENCE_LOG"
  echo "exit: $exit_code" >> "$EVIDENCE_LOG"

  # 解析 pass/fail(从输出尾部抓常见模式)
  local passed=0 failed=0
  # PHPUnit: "OK, but... 123 tests" / "Tests: 123, Assertions: 456"
  # Jest: "Tests: 12 passed, 3 failed"
  # Go: "ok pkg 0.123s" / "FAIL pkg"
  local line
  line=$(grep -oE '[0-9]+ (passed|tests?)' "$tmp_out" | tail -1 | grep -oE '^[0-9]+')
  [ -n "$line" ] && passed=$line
  line=$(grep -oE '[0-9]+ failed' "$tmp_out" | tail -1 | grep -oE '^[0-9]+')
  [ -n "$line" ] && failed=$line

  # 输出 JSON 摘要(给 LLM/archive.sh 读)
  local tail_out=$(tail -20 "$tmp_out" | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//')
  printf '{"exit": %s, "passed": %s, "failed": %s, "timestamp": "%s", "cmd": "%s", "tail": "%s", "log": "%s"}\n' \
    "$exit_code" "$passed" "$failed" "$ts" "$test_cmd" "$tail_out" "$EVIDENCE_LOG"

  if [ "$exit_code" = 0 ]; then
    G "✓ 测试通过(exit 0${passed:+, $passed passed})"
  else
    R "✗ 测试失败(exit $exit_code${failed:+, $failed failed})—— evidence 闸不过"
    Y "  日志:$EVIDENCE_LOG"
  fi
  rm -f "$tmp_out"
  exit $exit_code
}

# verify 子命令:验 git commit hash 真实存在
verify_hash(){
  local hash="${1:-}"
  [ -n "$hash" ] || { R "用法:evidence.sh verify <hash>"; exit 1; }
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    Y "  非 git 仓库,跳过 hash 校验"
    printf '{"verified": false, "reason": "not git repo"}\n'
    exit 0
  fi
  if git rev-parse --verify --quiet "${hash}^{commit}" >/dev/null 2>&1; then
    G "✓ hash 真实存在:$hash"
    printf '{"verified": true, "hash": "%s"}\n' "$hash"
  else
    R "✗ hash 不存在/未提交:$hash"
    printf '{"verified": false, "hash": "%s", "reason": "not found"}\n' "$hash"
    exit 1
  fi
}

# check 子命令:验 change 的 tasks.md evidence 齐
check_change(){
  local id="${1:-}"
  [ -n "$id" ] || { R "用法:evidence.sh check <change-id>"; exit 1; }
  local d="$C/$id"
  [ -d "$d" ] || d="$C/archive/$id"
  [ -d "$d" ] || { R "✗ change 不存在:$id"; exit 1; }

  B "▶ evidence check:$id"
  local acs ev fake checked
  acs=$(grep -cE '^### AC[0-9]' "$d/tasks.md" 2>/dev/null); [ -n "$acs" ] || acs=0
  ev=$(grep -c 'verified@commit' "$d/tasks.md" 2>/dev/null); [ -n "$ev" ] || ev=0
  printf "  Scenario(### AC):%s | evidence(verified@commit):%s\n" "$acs" "$ev"

  if [ "$ev" -lt "$acs" ] 2>/dev/null; then
    Y "  ⚠ evidence 不足($ev/$acs)"
    printf '{"evidence_ok": false, "acs": %s, "evidence": %s, "reason": "insufficient"}\n' "$acs" "$ev"
    exit 1
  fi

  # 落盘判定:hash 真实
  fake=0; checked=0
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for h in $(grep -oE 'verified@commit:[[:space:]]*[0-9a-fA-F]+' "$d/tasks.md" 2>/dev/null | sed -E 's/.*:[[:space:]]*([0-9a-fA-F]+)/\1/'); do
      [ -n "$h" ] || continue
      checked=$((checked+1))
      git rev-parse --verify --quiet "${h}^{commit}" >/dev/null 2>&1 || { Y "  ✗ hash 不真实:$h"; fake=$((fake+1)); }
    done
  fi
  if [ "$fake" -gt 0 ]; then
    R "  ✗ $fake 个 hash 编造/未提交"
    printf '{"evidence_ok": false, "checked": %s, "fake": %s, "reason": "fake hash"}\n' "$checked" "$fake"
    exit 1
  fi

  G "  ✓ evidence 齐($ev/$acs)${checked:+, hash 全真实($checked)}"
  printf '{"evidence_ok": true, "acs": %s, "evidence": %s, "checked": %s}\n' "$acs" "$ev" "$checked"
}

CMD="${1:-}"; shift || true
case "$CMD" in
  run) run_tests "$@" ;;
  verify) verify_hash "$@" ;;
  check) check_change "$@" ;;
  *) R "用法:evidence.sh run [test_cmd] | verify <hash> | check <change-id>"; exit 1 ;;
esac
