# ============================================================
#  Codex Review Skill — 一键安装脚本 (Windows PowerShell)
# ============================================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Info  { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-ErrorMsg { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step  { Write-Host "`n==== $args ====" -ForegroundColor Cyan }

# ---- 检查 Node.js ----
Write-Step "检查 Node.js"

try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        $versionStr = $nodeVersion -replace '^v', ''
        $majorVersion = [int]($versionStr.Split('.')[0])
        if ($majorVersion -ge 18) {
            Write-Info "Node.js $nodeVersion ✓"
        } else {
            Write-ErrorMsg "Node.js >= 18.18 需要，当前版本: $nodeVersion"
            Write-Info "请安装 Node.js: https://nodejs.org/"
            exit 1
        }
    }
} catch {
    Write-ErrorMsg "Node.js 未安装"
    Write-Info "请安装 Node.js >= 18.18: https://nodejs.org/"
    exit 1
}

# ---- 安装 Codex CLI ----
Write-Step "安装 OpenAI Codex CLI"

$codexPath = Get-Command codex -ErrorAction SilentlyContinue
if ($codexPath) {
    Write-Info "Codex CLI 已安装: $($codexPath.Source) ✓"
} else {
    Write-Info "正在安装 @openai/codex..."
    npm install -g @openai/codex
    $codexPath = Get-Command codex -ErrorAction SilentlyContinue
    if ($codexPath) {
        Write-Info "Codex CLI 安装成功 ✓"
    } else {
        Write-ErrorMsg "Codex CLI 安装失败，请手动执行: npm install -g @openai/codex"
        exit 1
    }
}

# ---- 检查 Codex 登录状态 ----
Write-Step "检查 Codex 登录状态"

try {
    $codexUser = codex whoami 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Codex 已登录: $codexUser ✓"
    } else {
        throw "未登录"
    }
} catch {
    Write-Warn "Codex 尚未登录，请执行登录流程..."
    codex login
    try {
        codex whoami 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Codex 登录成功 ✓"
        } else {
            Write-ErrorMsg "Codex 登录失败，请手动执行: codex login"
            exit 1
        }
    } catch {
        Write-ErrorMsg "Codex 登录失败，请手动执行: codex login"
        exit 1
    }
}

# ---- 安装 Skill 文件 ----
Write-Step "安装 Codex Review Skill"

$skillDir = "$env:USERPROFILE\.claude\skills\codex-review"
New-Item -ItemType Directory -Force -Path $skillDir | Out-Null

$skillSource = Join-Path $scriptDir "SKILL.md"
if (Test-Path $skillSource) {
    Copy-Item -Path $skillSource -Destination $skillDir -Force
    Write-Info "SKILL.md → $skillDir\SKILL.md ✓"
} else {
    Write-ErrorMsg "未找到 SKILL.md 文件，请确保从正确的目录运行安装脚本"
    exit 1
}

# ---- 创建记忆目录 ----
Write-Step "初始化记忆系统"

$globalMemoryDir = "$env:USERPROFILE\.claude\codex-review"
New-Item -ItemType Directory -Force -Path $globalMemoryDir | Out-Null

$globalMemoryFile = Join-Path $globalMemoryDir "memory.json"
if (-not (Test-Path $globalMemoryFile)) {
    $templateSource = Join-Path $scriptDir "memory-template.json"
    if (Test-Path $templateSource) {
        Copy-Item -Path $templateSource -Destination $globalMemoryFile
        Write-Info "全局记忆文件已创建: $globalMemoryFile ✓"
    } else {
        $defaultMemory = @'
{
  "version": "1.0",
  "createdAt": null,
  "updatedAt": null,
  "stats": { "totalReviews": 0, "totalMistakes": 0, "lastReview": null },
  "mistakes": []
}
'@
        Set-Content -Path $globalMemoryFile -Value $defaultMemory -Encoding UTF8
        Write-Info "全局记忆文件已创建（使用默认模板）✓"
    }
} else {
    Write-Info "全局记忆文件已存在，跳过创建 ✓"
}

# ---- 提示后续步骤 ----
Write-Step "安装完成"

Write-Host ""
Write-Host "  后续步骤："
Write-Host "  ─────────────────────────────────────────────"
Write-Host ""
Write-Host "  1. 在 Claude Code 中安装官方 Codex 插件："
Write-Host "     /plugin marketplace add openai/codex-plugin-cc"
Write-Host "     /plugin install codex@openai-codex"
Write-Host "     /reload-plugins"
Write-Host ""
Write-Host "  2. 使用 Codex Review："
Write-Host "     在 Claude Code 中输入「我想要codex再检查一遍」"
Write-Host "     或使用命令 /codex-review"
Write-Host ""
Write-Host "  ─────────────────────────────────────────────"
Write-Host ""

Write-Info "安装成功！" -ForegroundColor Green
