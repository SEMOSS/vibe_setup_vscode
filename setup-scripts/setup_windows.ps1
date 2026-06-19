########################################################
# SEMOSS Vibe Coding - One-Time Setup Script (Windows)
#
# INSTRUCTIONS:
#   1. Search for "PowerShell" in the Start Menu
#   2. RIGHT-CLICK → "Run as Administrator"
#   3. Copy-paste these TWO lines and press Enter:
#
#      Set-ExecutionPolicy Bypass -Scope Process -Force
#      .\setup-scripts\setup_windows.ps1
#
#   Or if you downloaded this file separately:
#      Set-ExecutionPolicy Bypass -Scope Process -Force
#      .\setup_windows.ps1
#
########################################################

# Don't stop on errors — we handle them ourselves
$ErrorActionPreference = "Continue"
$errorCount = 0
$results = @()
$fixes = @()

function Add-Result($msg) { $script:results += $msg }
function Add-Fix($msg) { $script:fixes += $msg }

Clear-Host
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║   SEMOSS Vibe Coding — Windows Environment Setup      ║" -ForegroundColor White
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""
Write-Host "  This script will install everything you need." -ForegroundColor DarkGray
Write-Host "  It's safe to run multiple times." -ForegroundColor DarkGray
Write-Host "  You may see UAC popups (click Yes — that's normal)." -ForegroundColor DarkGray
Write-Host ""
Start-Sleep -Seconds 1

# =============================================================
# Step 1: Check if running as Admin
# =============================================================
Write-Host "━━━ [PRE-CHECK] Admin Privileges ━━━" -ForegroundColor Yellow

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "  ✅ Running as Administrator" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  NOT running as Administrator — some installs may fail" -ForegroundColor Yellow
    Write-Host "  TIP: Close PowerShell, right-click it, and select 'Run as Administrator'" -ForegroundColor Cyan
}
Write-Host ""

# =============================================================
# Step 2: Python 3.13
# =============================================================
Write-Host "━━━ [1/5] Python 3.13 ━━━" -ForegroundColor Yellow

$pyCmd = $null
$pyExe = $null

# Check py launcher (most common on Windows)
try {
    $pyVer = & py -3.13 --version 2>&1
    if ($pyVer -match "3\.13") {
        $pyCmd = "py"
        $pyExe = "py -3.13"
        Write-Host "  ✅ Already installed — $pyVer" -ForegroundColor Green
        Add-Result "✅ Python 3.13"
    }
} catch {}

# Fallback: check python3 or python
if (-not $pyCmd) {
    try {
        $pyVer = & python --version 2>&1
        if ($pyVer -match "3\.13") {
            $pyCmd = "python"
            $pyExe = "python"
            Write-Host "  ✅ Already installed — $pyVer" -ForegroundColor Green
            Add-Result "✅ Python 3.13"
        }
    } catch {}
}

if (-not $pyCmd) {
    # Try to install via winget
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        Write-Host "  Installing Python 3.13 via winget..." -ForegroundColor Cyan
        winget install Python.Python.3.13 --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        try {
            $pyVer = & py -3.13 --version 2>&1
            if ($pyVer -match "3\.13") {
                $pyCmd = "py"
                $pyExe = "py -3.13"
                Write-Host "  ✅ Installed — $pyVer" -ForegroundColor Green
                Add-Result "✅ Python 3.13"
            }
        } catch {}
    }

    if (-not $pyCmd) {
        Write-Host "  ❌ FAILED" -ForegroundColor Red
        Add-Result "❌ Python 3.13"
        Add-Fix @"
┃  Python 3.13 is not installed.
┃
┃  HOW TO FIX:
┃  1. Open your browser and go to: https://www.python.org/downloads/
┃  2. Download "Python 3.13.x" (the big yellow button)
┃  3. Run the installer
┃  4. ⚠️  IMPORTANT: Check the box that says "Add Python to PATH"
┃  5. Click "Install Now"
┃  6. After it finishes, close PowerShell, reopen it, and run this script again.
"@
        $errorCount++
    }
}
Write-Host ""

# =============================================================
# Step 3: Python venv + SEMOSS SDK
# =============================================================
Write-Host "━━━ [2/5] SEMOSS Python SDK ━━━" -ForegroundColor Yellow

$venvDir = "$env:USERPROFILE\.semoss-venv"

if (-not $pyCmd) {
    Write-Host "  ❌ Skipped — Python 3.13 is not installed (fix that first)" -ForegroundColor Red
    Add-Result "❌ SEMOSS SDK"
    Add-Fix @"
┃  SEMOSS SDK could not be installed because Python 3.13 is missing.
┃
┃  HOW TO FIX: Install Python 3.13 first (see above), then re-run this script.
"@
    $errorCount++
} else {
    # Create venv
    if (-not (Test-Path "$venvDir\Scripts\python.exe")) {
        Write-Host "  Creating isolated Python environment..." -ForegroundColor Cyan
        & cmd /c "$pyExe -m venv `"$venvDir`"" 2>&1 | Out-Null
    }

    if (Test-Path "$venvDir\Scripts\python.exe") {
        Write-Host "  Installing SEMOSS SDK (ai-server-sdk)..." -ForegroundColor Cyan
        & "$venvDir\Scripts\python.exe" -m pip install --upgrade pip --quiet 2>&1 | Out-Null
        & "$venvDir\Scripts\python.exe" -m pip install --upgrade ai-server-sdk --quiet 2>&1 | Out-Null

        # Verify
        $sdkCheck = & "$venvDir\Scripts\python.exe" -c "from ai_server import ServerClient; print('OK')" 2>&1
        if ("$sdkCheck" -match "OK") {
            Write-Host "  ✅ SDK installed and working" -ForegroundColor Green
            Write-Host "     Location: $venvDir" -ForegroundColor DarkGray
            Add-Result "✅ SEMOSS SDK (in ~\.semoss-venv)"
        } else {
            Write-Host "  ❌ SDK installed but import failed" -ForegroundColor Red
            Add-Result "❌ SEMOSS SDK"
            Add-Fix @"
┃  The SEMOSS SDK installed but couldn't load.
┃
┃  HOW TO FIX:
┃  1. Delete the Python environment:
┃     Remove-Item -Recurse -Force "$venvDir"
┃  2. Run this setup script again.
┃  If it still fails, ask your team lead for help.
"@
            $errorCount++
        }
    } else {
        Write-Host "  ❌ Failed to create Python environment" -ForegroundColor Red
        Add-Result "❌ SEMOSS SDK"
        Add-Fix @"
┃  Could not create the Python virtual environment.
┃
┃  HOW TO FIX:
┃  1. Delete any leftover files:
┃     Remove-Item -Recurse -Force "$venvDir"
┃  2. Make sure Python 3.13 is installed correctly.
┃  3. Run this script again.
"@
        $errorCount++
    }
}
Write-Host ""

# =============================================================
# Step 4: Node.js + npx
# =============================================================
Write-Host "━━━ [3/5] Node.js + npx ━━━" -ForegroundColor Yellow

$hasNode = Get-Command node -ErrorAction SilentlyContinue
if ($hasNode) {
    $nodeVer = & node --version
    Write-Host "  ✅ Node.js already installed — $nodeVer" -ForegroundColor Green
    Add-Result "✅ Node.js $nodeVer"
} else {
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        Write-Host "  Installing Node.js via winget..." -ForegroundColor Cyan
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        $hasNode = Get-Command node -ErrorAction SilentlyContinue
        if ($hasNode) {
            Write-Host "  ✅ Installed — Node.js $(node --version)" -ForegroundColor Green
            Add-Result "✅ Node.js $(node --version)"
        } else {
            Write-Host "  ❌ FAILED (may need to restart PowerShell)" -ForegroundColor Red
            Add-Result "❌ Node.js"
            Add-Fix @"
┃  Node.js install might have succeeded but isn't visible yet.
┃
┃  HOW TO FIX:
┃  1. Close PowerShell completely
┃  2. Reopen PowerShell as Administrator
┃  3. Run this script again
┃
┃  If it still fails:
┃  1. Go to https://nodejs.org in your browser
┃  2. Download the LTS version (the green button)
┃  3. Run the installer (click Next through everything)
┃  4. Restart PowerShell and run this script again
"@
            $errorCount++
        }
    } else {
        Write-Host "  ❌ NOT FOUND and winget not available" -ForegroundColor Red
        Add-Result "❌ Node.js"
        Add-Fix @"
┃  Node.js is not installed.
┃
┃  HOW TO FIX:
┃  1. Go to https://nodejs.org in your browser
┃  2. Download the LTS version (the big green button)
┃  3. Run the installer (click Next through everything)
┃  4. Restart PowerShell and run this script again
"@
        $errorCount++
    }
}

# Check npx
$hasNpx = Get-Command npx -ErrorAction SilentlyContinue
if ($hasNpx) {
    Write-Host "  ✅ npx available — $(npx --version)" -ForegroundColor Green
    Add-Result "✅ npx"
} elseif ($hasNode) {
    Write-Host "  ⚠️  npx not found yet — restart PowerShell and it should appear" -ForegroundColor Yellow
    Add-Result "⚠️  npx (restart PowerShell)"
    Add-Fix @"
┃  npx wasn't found, but Node.js is installed.
┃
┃  HOW TO FIX: Close PowerShell, reopen it, and run this script again.
┃  npx comes with Node.js and should work after restart.
"@
    $errorCount++
}
Write-Host ""

# =============================================================
# Step 5: VS Code check
# =============================================================
Write-Host "━━━ [4/5] VS Code ━━━" -ForegroundColor Yellow

$hasCode = Get-Command code -ErrorAction SilentlyContinue
if ($hasCode) {
    Write-Host "  ✅ VS Code is installed" -ForegroundColor Green
    Add-Result "✅ VS Code"
} else {
    Write-Host "  ⚠️  VS Code not found on PATH" -ForegroundColor Yellow
    Write-Host "     (It may be installed but not added to PATH)" -ForegroundColor DarkGray
    Add-Result "⚠️  VS Code (not on PATH)"
    Add-Fix @"
┃  VS Code wasn't found on PATH.
┃
┃  HOW TO FIX (if not installed):
┃  1. Go to https://code.visualstudio.com
┃  2. Download and install VS Code
┃  3. During install, check "Add to PATH"
┃
┃  If already installed: Open VS Code, press Ctrl+Shift+P,
┃  type "Shell Command", and click "Install 'code' command in PATH"
"@
    $errorCount++
}
Write-Host ""

# =============================================================
# Step 6: Configure SEMOSS credentials (interactive)
# =============================================================
Write-Host "━━━ [5/5] SEMOSS Project Configuration ━━━" -ForegroundColor Yellow

$configDir = "semoss_config"
$configFile = "$configDir\config.json"

if ((Test-Path "scripts") -or (Test-Path $configDir)) {
    Write-Host ""
    Write-Host "  Let's set up your SEMOSS connection." -ForegroundColor Cyan
    Write-Host "  You'll need your Access Key and Secret Key from SEMOSS." -ForegroundColor Cyan
    Write-Host "  (Find them at: Settings → My Profile on your SEMOSS instance)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press Enter to skip any field — you can configure later." -ForegroundColor DarkGray
    Write-Host ""

    $baseUrl = Read-Host "  Base URL (e.g. https://your-instance.semoss.org)"
    $accessKey = Read-Host "  Access Key"
    $secretKey = Read-Host "  Secret Key"
    $projectId = Read-Host "  Project ID"
    $apiModuleUrl = Read-Host "  API Module URL (press Enter for /api)"
    $webModuleUrl = Read-Host "  Web Module URL (press Enter for /web)"

    if (-not $apiModuleUrl) { $apiModuleUrl = "/api" }
    if (-not $webModuleUrl) { $webModuleUrl = "/web" }

    if ($baseUrl -and $accessKey -and $secretKey -and $projectId) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null

        @"
{
    "project_id": "$projectId",
    "base_url": "$baseUrl",
    "api_module_url": "$apiModuleUrl",
    "web_module_url": "$webModuleUrl"
}
"@ | Set-Content -Path $configFile -Encoding UTF8

        New-Item -ItemType Directory -Path ".vscode" -Force | Out-Null

        @"
{
    "servers": {
        "semoss": {
            "command": "npx",
            "args": ["-y", "@anthropic-ai/mcp-proxy@latest", "--transport", "streamable-http", "$baseUrl$apiModuleUrl/mcp/sse"],
            "env": {
                "MCP_HEADERS": "Authorization: Bearer $accessKey $secretKey\nProject: $projectId"
            }
        }
    }
}
"@ | Set-Content -Path ".vscode\mcp.json" -Encoding UTF8

        Write-Host ""
        Write-Host "  ✅ Configuration saved!" -ForegroundColor Green
        Add-Result "✅ SEMOSS configured"
    } else {
        Write-Host ""
        Write-Host "  ⏭️  Skipped for now — no worries, you can do this later." -ForegroundColor Yellow
        Add-Result "⏭️  SEMOSS config (skipped)"
    }
} else {
    Write-Host "  ⏭️  You're not inside a project folder right now." -ForegroundColor Yellow
    Write-Host "     Clone your project first:" -ForegroundColor DarkGray
    Write-Host "     git clone https://github.com/SEMOSS/vibe_setup_vscode.git my-app" -ForegroundColor Cyan
    Write-Host "     cd my-app" -ForegroundColor Cyan
    Write-Host "     Then re-run this script from inside that folder." -ForegroundColor Cyan
    Add-Result "⏭️  SEMOSS config (not in project folder)"
}

# =============================================================
# FINAL SUMMARY
# =============================================================
Write-Host ""
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║                    SETUP SUMMARY                       ║" -ForegroundColor White
Write-Host "╠════════════════════════════════════════════════════════╣" -ForegroundColor White

foreach ($result in $results) {
    Write-Host "║  $result"
}

Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor White

if ($errorCount -eq 0) {
    Write-Host ""
    Write-Host "  🎉 ALL DONE! Your environment is ready for vibe coding." -ForegroundColor Green
    Write-Host ""
    Write-Host "  WHAT TO DO NEXT:" -ForegroundColor White
    Write-Host "  ─────────────────"
    Write-Host "  1. Close this PowerShell window and open a new one" -ForegroundColor Cyan
    Write-Host "  2. Open VS Code" -ForegroundColor Cyan
    Write-Host "  3. Open your project folder in VS Code" -ForegroundColor Cyan
    Write-Host "  4. Start coding! The MCP tools should connect automatically." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  USEFUL COMMANDS:" -ForegroundColor White
    Write-Host "  ─────────────────"
    Write-Host "  $venvDir\Scripts\activate" -ForegroundColor Cyan -NoNewline
    Write-Host "  — Activate the Python environment"
    Write-Host "  python scripts\semoss_asset_sync.py upload <file>" -ForegroundColor Cyan -NoNewline
    Write-Host "  — Upload a file"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  ⚠️  $errorCount ISSUE(S) NEED FIXING" -ForegroundColor Red
    Write-Host ""
    Write-Host "  HOW TO FIX:" -ForegroundColor White
    Write-Host "  ────────────"
    Write-Host ""
    foreach ($fix in $fixes) {
        Write-Host $fix -ForegroundColor Red
        Write-Host ""
    }
    Write-Host "  After fixing, run this script again:" -ForegroundColor White
    Write-Host "  .\setup-scripts\setup_windows.ps1" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "  Need help? Ask your team lead or post in the team Slack/Teams channel." -ForegroundColor DarkGray
Write-Host ""
