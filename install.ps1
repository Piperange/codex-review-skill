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
        $parts = $versionStr.Split('.')
        $majorVersion = [int]$parts[0]
        $minorVersion = [int]$parts[1]
        if ($majorVersion -gt 18 -or ($majorVersion -eq 18 -and $minorVersion -ge 18)) {
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

# ---- 安装/更新 Codex CLI ----
Write-Step "安装 OpenAI Codex CLI"

$npmPath = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npmPath) {
    Write-ErrorMsg "npm 未安装，请先安装 Node.js"
    exit 1
}

$codexPath = Get-Command codex -ErrorAction SilentlyContinue
if ($codexPath) {
    Write-Info "Codex CLI 已安装: $($codexPath.Source)，尝试更新到最新版本..."
    npm install -g @openai/codex@latest 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Codex CLI 更新失败，继续使用当前版本"
    } else {
        Write-Info "Codex CLI 更新完成 ✓"
    }
} else {
    Write-Info "正在安装 @openai/codex..."
    npm install -g @openai/codex
    $codexPath = Get-Command codex -ErrorAction SilentlyContinue
    if ($codexPath) {
        Write-Info "Codex CLI 安装成功 ✓"
    } else {
        Write-ErrorMsg "Codex CLI 安装失败，请手动执行: npm install -g @openai/codex"
        Write-Info "或尝试 npx @openai/codex 进行免安装运行"
        exit 1
    }
}

# ---- 检查 Codex 登录状态 ----
Write-Step "检查 Codex 登录状态"

$doctorOutput = codex doctor 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $doctorOutput -match "error|Error|not logged|auth|login") {
    Write-Warn "Codex 认证可能有问题，请执行登录流程..."
    codex login
    $doctorOutput = codex doctor 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $doctorOutput -notmatch "error|Error|not logged") {
        Write-Info "Codex 登录完成 ✓"
    } else {
        Write-ErrorMsg "Codex 登录失败，请手动执行: codex login"
        exit 1
    }
} else {
    Write-Info "Codex 认证状态正常 ✓"
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
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $tmpFile = Join-Path $globalMemoryDir ".memory.tmp.$PID"
    $templateSource = Join-Path $scriptDir "memory-template.json"
    if (Test-Path $templateSource) {
        $content = Get-Content $templateSource -Raw -Encoding UTF8
        $content = $content -replace '"createdAt": null', "`"createdAt`": `"$now`""
        $content = $content -replace '"updatedAt": null', "`"updatedAt`": `"$now`""
        Set-Content -Path $tmpFile -Value $content -Encoding UTF8
        Move-Item -Path $tmpFile -Destination $globalMemoryFile -Force
        Write-Info "全局记忆文件已创建: $globalMemoryFile ✓"
    } else {
        $defaultMemory = @"
{
  "version": "1.0",
  "createdAt": "$now",
  "updatedAt": "$now",
  "stats": { "totalReviews": 0, "totalMistakes": 0, "lastReview": null },
  "mistakes": []
}
"@
        Set-Content -Path $tmpFile -Value $defaultMemory -Encoding UTF8
        Move-Item -Path $tmpFile -Destination $globalMemoryFile -Force
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
