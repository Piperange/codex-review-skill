#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  Codex Review Skill — 一键安装脚本 (macOS / Linux / WSL)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }
log_step()  { printf "\n${CYAN}==== %s ====${NC}\n" "$*"; }

# ---- 检查 Node.js ----
log_step "检查 Node.js"
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$MAJOR_VERSION" -ge 18 ]; then
        log_info "Node.js $NODE_VERSION ✓"
    else
        log_error "Node.js >= 18.18 需要，当前版本: $NODE_VERSION"
        log_info "请安装 Node.js: https://nodejs.org/"
        exit 1
    fi
else
    log_error "Node.js 未安装"
    log_info "请安装 Node.js >= 18.18: https://nodejs.org/"
    exit 1
fi

# ---- 安装 Codex CLI ----
log_step "安装 OpenAI Codex CLI"
if command -v codex &>/dev/null; then
    CODEX_VERSION=$(codex --version 2>/dev/null || echo "unknown")
    log_info "Codex CLI 已安装: $CODEX_VERSION ✓"
else
    log_info "正在安装 @openai/codex..."
    npm install -g @openai/codex
    if command -v codex &>/dev/null; then
        log_info "Codex CLI 安装成功 ✓"
    else
        log_error "Codex CLI 安装失败，请手动执行: npm install -g @openai/codex"
        exit 1
    fi
fi

# ---- 检查 Codex 登录状态 ----
log_step "检查 Codex 登录状态"
if codex whoami &>/dev/null; then
    CODEX_USER=$(codex whoami 2>/dev/null || echo "已登录")
    log_info "Codex 已登录: $CODEX_USER ✓"
else
    log_warn "Codex 尚未登录，请执行登录流程..."
    codex login
    if ! codex whoami &>/dev/null; then
        log_error "Codex 登录失败，请手动执行: codex login"
        exit 1
    fi
    log_info "Codex 登录成功 ✓"
fi

# ---- 安装 Skill 文件 ----
log_step "安装 Codex Review Skill"

SKILL_DIR="${HOME}/.claude/skills/codex-review"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILL_DIR"

# 复制 SKILL.md
if [ -f "${SCRIPT_DIR}/SKILL.md" ]; then
    cp "${SCRIPT_DIR}/SKILL.md" "${SKILL_DIR}/SKILL.md"
    log_info "SKILL.md → ${SKILL_DIR}/SKILL.md ✓"
else
    log_error "未找到 SKILL.md 文件，请确保从正确的目录运行安装脚本"
    exit 1
fi

# ---- 创建记忆目录 ----
log_step "初始化记忆系统"

GLOBAL_MEMORY_DIR="${HOME}/.claude/codex-review"
mkdir -p "$GLOBAL_MEMORY_DIR"

if [ ! -f "${GLOBAL_MEMORY_DIR}/memory.json" ]; then
    if [ -f "${SCRIPT_DIR}/memory-template.json" ]; then
        cp "${SCRIPT_DIR}/memory-template.json" "${GLOBAL_MEMORY_DIR}/memory.json"
        log_info "全局记忆文件已创建: ${GLOBAL_MEMORY_DIR}/memory.json ✓"
    else
        cat > "${GLOBAL_MEMORY_DIR}/memory.json" << 'MEMEOF'
{
  "version": "1.0",
  "createdAt": null,
  "updatedAt": null,
  "stats": { "totalReviews": 0, "totalMistakes": 0, "lastReview": null },
  "mistakes": []
}
MEMEOF
        log_info "全局记忆文件已创建（使用默认模板）✓"
    fi
else
    log_info "全局记忆文件已存在，跳过创建 ✓"
fi

# ---- 提示后续步骤 ----
log_step "安装完成"

echo ""
echo "  后续步骤："
echo "  ─────────────────────────────────────────────"
echo ""
echo "  1. 在 Claude Code 中安装官方 Codex 插件："
echo "     /plugin marketplace add openai/codex-plugin-cc"
echo "     /plugin install codex@openai-codex"
echo "     /reload-plugins"
echo ""
echo "  2. 使用 Codex Review："
echo "     在 Claude Code 中输入「我想要codex再检查一遍」"
echo "     或使用命令 /codex-review"
echo ""
echo "  ─────────────────────────────────────────────"
echo ""

log_info "安装成功！🎉"
