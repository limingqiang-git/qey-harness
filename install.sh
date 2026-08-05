#!/usr/bin/env bash
# qey-harness 安装脚本
# 用法:curl -fsSL https://raw.githubusercontent.com/limingqiang-git/qey-harness/main/install.sh | bash
#
# 两种模式:
#   默认(管道模式):下载到 ~/.qey-harness + 软链 qey 到 ~/.local/bin
#   --local:在当前项目目录跑 qey init(接入新项目)
set -euo pipefail

BOLD() { printf "\033[1m%s\033[0m\n" "$1"; }
GREEN() { printf "\033[32m%s\033[0m\n" "$1"; }
YELLOW() { printf "\033[33m%s\033[0m\n" "$1"; }
RED() { printf "\033[31m%s\033[0m\n" "$1"; }

REPO="https://github.com/limingqiang-git/qey-harness"
INSTALL_DIR="${QEY_HOME:-$HOME/.qey-harness}"
BIN_DIR="$HOME/.local/bin"

# ── 检查 node ──
if ! command -v node >/dev/null 2>&1; then
  RED "✗ 需要 Node.js >= 18(没检测到 node)"
  echo "  安装:https://nodejs.org/ 或 brew install node"
  exit 1
fi
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
  RED "✗ Node.js 版本太低(当前 $(node -v),需要 >= 18)"
  exit 1
fi

# ── 参数解析 ──
MODE="install"
PROJECT_DIR=""
for arg in "$@"; do
  case "$arg" in
    --local) MODE="local" ;;
    --help|-h)
      echo "qey-harness 安装脚本"
      echo ""
      echo "用法:"
      echo "  curl -fsSL https://raw.githubusercontent.com/limingqiang-git/qey-harness/main/install.sh | bash          # 全局安装"
      echo "  curl -fsSL https://raw.githubusercontent.com/limingqiang-git/qey-harness/main/install.sh | bash -s -- --local   # 接入当前目录"
      echo ""
      echo "环境变量:"
      echo "  QEY_HOME  安装目录(默认 ~/.qey-harness)"
      exit 0
      ;;
  esac
done

# ── 模式 1:全局安装(下载 + 软链)──
if [ "$MODE" = "install" ]; then
  BOLD "▶ 安装 qey-harness"
  echo "  仓库:$REPO"
  echo "  安装到:$INSTALL_DIR"
  echo ""

  # 下载(优先 git clone,fallback 下载 tar)
  if [ -d "$INSTALL_DIR/.git" ]; then
    YELLOW "  ℹ 已存在,更新中..."
    cd "$INSTALL_DIR" && git pull -q --ff-only 2>/dev/null || true
  else
    GREEN "  ▶ 克隆仓库..."
    git clone -q --depth 1 "$REPO" "$INSTALL_DIR" 2>/dev/null || {
      RED "✗ git clone 失败,检查网络或仓库地址"
      exit 1
    }
  fi

  # 软链 qey → bin/qey.js
  mkdir -p "$BIN_DIR"
  ln -sf "$INSTALL_DIR/bin/qey.js" "$BIN_DIR/qey"
  GREEN "  ✓ 软链 $BIN_DIR/qey → $INSTALL_DIR/bin/qey.js"

  # PATH 检查
  case ":$PATH:" in
    *":$BIN_DIR:"*) GREEN "  ✓ $BIN_DIR 已在 PATH" ;;
    *)
      YELLOW "  ⚠ $BIN_DIR 不在 PATH。加到 ~/.zshrc / ~/.bashrc:"
      echo '      export PATH="'$BIN_DIR':$PATH"'
      echo "  然后 source 或重开终端"
      ;;
  esac

  echo ""
  GREEN "✓ 安装完成!"
  echo ""
  BOLD "  使用:"
  echo "    qey init              # 在项目目录跑,接入骨架"
  echo "    qey version           # 查版本"
  echo "    qey help              # 查命令"
  echo ""
  echo "  或直接 npx(发布到 npm 后):npx qey-harness init"

# ── 模式 2:接入当前目录 ──
else
  if [ ! -f "package.json" ] && [ ! -d ".git" ] && [ "$(pwd)" = "$HOME" ]; then
    RED "✗ 不建议在 HOME 目录跑(--local)。cd 到你的项目目录再跑。"
    exit 1
  fi
  BOLD "▶ 接入 qey-harness 到当前项目"
  echo "  目录:$(pwd)"
  echo ""

  # 如果没全局装,先临时下载
  if ! command -v qey >/dev/null 2>&1; then
    if [ ! -d "$INSTALL_DIR/.git" ]; then
      GREEN "  ▶ 先全局安装(到 $INSTALL_DIR)..."
      git clone -q --depth 1 "$REPO" "$INSTALL_DIR" 2>/dev/null || {
        RED "✗ 下载失败"
        exit 1
      }
    fi
    export QEY_TEMPLATE="$INSTALL_DIR"
    NODE_BIN="$INSTALL_DIR/bin/qey.js"
  else
    NODE_BIN="qey"
  fi

  node "$NODE_BIN" init "$@"
fi
