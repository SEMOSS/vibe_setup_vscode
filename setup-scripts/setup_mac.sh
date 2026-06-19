#!/bin/bash
########################################################
# SEMOSS Vibe Coding - One-Time Setup Script (macOS)
#
# INSTRUCTIONS:
#   1. Open the Terminal app (search "Terminal" in Spotlight)
#   2. Copy-paste this ENTIRE line and press Enter:
#
#      curl -fsSL https://raw.githubusercontent.com/SEMOSS/vibe_setup_vscode/main/setup-scripts/setup_mac.sh | bash
#
#   OR if you already cloned the repo:
#      chmod +x setup-scripts/setup_mac.sh && ./setup-scripts/setup_mac.sh
#
########################################################

# Don't exit on error — we handle errors ourselves
set +e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Track results
declare -a RESULTS=()
declare -a FIXES=()
error_count=0

add_result() {
    RESULTS+=("$1")
}

add_fix() {
    FIXES+=("$1")
}

# --- Helper: add to shell profile ---
add_to_profile() {
    local line="$1"
    local shell_profile=""

    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_profile="$HOME/.bash_profile"
    fi

    if [[ -n "$shell_profile" ]]; then
        # Create the file if it doesn't exist
        touch "$shell_profile"
        if ! grep -qF "$line" "$shell_profile" 2>/dev/null; then
            echo "$line" >> "$shell_profile"
        fi
    fi
}

clear
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════╗"
echo -e "║   SEMOSS Vibe Coding — Mac Environment Setup           ║"
echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${DIM}  This script will install everything you need.${NC}"
echo -e "${DIM}  It's safe to run multiple times.${NC}"
echo -e "${DIM}  You may be prompted for your Mac password (that's normal).${NC}"
echo ""
sleep 1

# =============================================================
# Step 1: Xcode Command Line Tools (required for everything)
# =============================================================
echo -e "${YELLOW}━━━ [1/6] Xcode Command Line Tools ━━━${NC}"

if xcode-select -p &> /dev/null; then
    echo -e "${GREEN}  ✅ Already installed${NC}"
    add_result "✅ Xcode CLI Tools"
else
    echo -e "${CYAN}  Installing... (a popup may appear — click 'Install')${NC}"
    xcode-select --install 2>/dev/null
    
    # Wait for installation
    echo -e "${CYAN}  Waiting for installation to complete...${NC}"
    echo -e "${CYAN}  (If a popup appeared, click 'Install' and wait)${NC}"
    until xcode-select -p &> /dev/null; do
        sleep 5
    done
    
    if xcode-select -p &> /dev/null; then
        echo -e "${GREEN}  ✅ Installed${NC}"
        add_result "✅ Xcode CLI Tools"
    else
        echo -e "${RED}  ❌ FAILED${NC}"
        add_result "❌ Xcode CLI Tools"
        add_fix "┃  Xcode CLI Tools failed to install.
┃  FIX: Open Terminal and run:
┃       xcode-select --install
┃  Then click 'Install' on the popup that appears.
┃  After it finishes, run this setup script again."
        ((error_count++))
    fi
fi
echo ""

# =============================================================
# Step 2: Homebrew
# =============================================================
echo -e "${YELLOW}━━━ [2/6] Homebrew (Mac Package Manager) ━━━${NC}"

# Try to find brew even if not on PATH
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v brew &> /dev/null; then
    echo -e "${GREEN}  ✅ Already installed — $(brew --version | head -1)${NC}"
    add_result "✅ Homebrew"
else
    echo -e "${CYAN}  Installing Homebrew (this may take 2-5 minutes)...${NC}"
    echo -e "${DIM}  You'll be asked for your Mac password — type it and press Enter${NC}"
    echo -e "${DIM}  (the password won't show as you type, that's normal)${NC}"
    echo ""
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Source it
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        add_to_profile 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew &> /dev/null; then
        echo -e "${GREEN}  ✅ Installed${NC}"
        add_result "✅ Homebrew"
    else
        echo -e "${RED}  ❌ FAILED${NC}"
        add_result "❌ Homebrew"
        add_fix "┃  Homebrew failed to install.
┃  FIX: Go to https://brew.sh in your browser.
┃  Copy the install command shown on that page.
┃  Paste it into Terminal and press Enter.
┃  Then run this setup script again."
        ((error_count++))
    fi
fi
echo ""

# =============================================================
# Step 3: Python 3.13
# =============================================================
echo -e "${YELLOW}━━━ [3/6] Python 3.13 ━━━${NC}"

py_cmd=""
if command -v python3.13 &> /dev/null; then
    py_cmd="python3.13"
elif command -v python3 &> /dev/null && python3 --version 2>&1 | grep -q "3.13"; then
    py_cmd="python3"
fi

if [[ -n "$py_cmd" ]]; then
    echo -e "${GREEN}  ✅ Already installed — $($py_cmd --version)${NC}"
    add_result "✅ Python 3.13"
else
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}  ❌ Cannot install — Homebrew is missing (fix that first)${NC}"
        add_result "❌ Python 3.13"
        add_fix "┃  Python 3.13 could not be installed because Homebrew is missing.
┃  FIX: Fix the Homebrew issue above first, then re-run this script."
        ((error_count++))
    else
        echo -e "${CYAN}  Installing Python 3.13 (this may take 2-3 minutes)...${NC}"
        brew install python@3.13 2>&1 | tail -5

        # Make sure it's on PATH
        BREW_PREFIX="$(brew --prefix)"
        export PATH="$BREW_PREFIX/opt/python@3.13/libexec/bin:$BREW_PREFIX/opt/python@3.13/bin:$BREW_PREFIX/bin:$PATH"

        if command -v python3.13 &> /dev/null; then
            py_cmd="python3.13"
            echo -e "${GREEN}  ✅ Installed — $(python3.13 --version)${NC}"
            add_result "✅ Python 3.13"
        elif command -v python3 &> /dev/null && python3 --version 2>&1 | grep -q "3.13"; then
            py_cmd="python3"
            echo -e "${GREEN}  ✅ Installed — $(python3 --version)${NC}"
            add_result "✅ Python 3.13"
        else
            echo -e "${RED}  ❌ FAILED${NC}"
            add_result "❌ Python 3.13"
            add_fix "┃  Python 3.13 install failed.
┃  FIX: Open Terminal and run these commands one at a time:
┃       brew update
┃       brew install python@3.13
┃  If that fails, try:
┃       brew doctor
┃  Fix any issues it reports, then run this setup script again."
            ((error_count++))
        fi
    fi
fi
echo ""

# =============================================================
# Step 4: Python venv + SEMOSS SDK
# =============================================================
echo -e "${YELLOW}━━━ [4/6] SEMOSS Python SDK ━━━${NC}"

VENV_DIR="$HOME/.semoss-venv"

if [[ -z "$py_cmd" ]]; then
    echo -e "${RED}  ❌ Skipped — Python 3.13 is not installed (fix that first)${NC}"
    add_result "❌ SEMOSS SDK"
    add_fix "┃  SEMOSS SDK could not be installed because Python 3.13 is missing.
┃  FIX: Fix the Python issue above first, then re-run this script."
    ((error_count++))
else
    # Create venv
    if [[ ! -d "$VENV_DIR" ]]; then
        echo -e "${CYAN}  Creating isolated Python environment...${NC}"
        $py_cmd -m venv "$VENV_DIR"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}  ❌ Failed to create Python environment${NC}"
            add_result "❌ SEMOSS SDK"
            add_fix "┃  Could not create Python virtual environment.
┃  FIX: Try deleting the old one and re-running:
┃       rm -rf ~/.semoss-venv
┃  Then run this setup script again."
            ((error_count++))
        fi
    fi

    if [[ -d "$VENV_DIR" ]]; then
        echo -e "${CYAN}  Installing SEMOSS SDK (ai-server-sdk)...${NC}"
        source "$VENV_DIR/bin/activate"
        pip install --upgrade pip --quiet 2>/dev/null
        pip install --upgrade ai-server-sdk 2>&1 | grep -v "already satisfied" | tail -3

        # Verify it actually works
        sdk_check=$(python -c "from ai_server import ServerClient; print('OK')" 2>&1)
        if echo "$sdk_check" | grep -q "OK"; then
            echo -e "${GREEN}  ✅ SDK installed and working${NC}"
            echo -e "${DIM}     Location: $VENV_DIR${NC}"
            add_result "✅ SEMOSS SDK (in ~/.semoss-venv)"
        else
            echo -e "${RED}  ❌ SDK installed but import failed${NC}"
            echo -e "${DIM}     Error: $sdk_check${NC}"
            add_result "❌ SEMOSS SDK"
            add_fix "┃  The SEMOSS SDK installed but couldn't load properly.
┃  FIX: Try a clean install:
┃       rm -rf ~/.semoss-venv
┃  Then run this setup script again.
┃  If it still fails, ask your team lead for help."
            ((error_count++))
        fi

        deactivate 2>/dev/null || true

        # Add alias to shell profile
        add_to_profile '# SEMOSS Python environment'
        add_to_profile "alias semoss-activate='source $VENV_DIR/bin/activate'"
    fi
fi
echo ""

# =============================================================
# Step 5: Node.js + npx
# =============================================================
echo -e "${YELLOW}━━━ [5/6] Node.js + npx ━━━${NC}"

if command -v node &> /dev/null; then
    node_ver=$(node --version)
    echo -e "${GREEN}  ✅ Node.js already installed — $node_ver${NC}"
    add_result "✅ Node.js $node_ver"
else
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}  ❌ Cannot install — Homebrew is missing (fix that first)${NC}"
        add_result "❌ Node.js"
        add_fix "┃  Node.js could not be installed because Homebrew is missing.
┃  FIX: Fix the Homebrew issue first, then re-run this script."
        ((error_count++))
    else
        echo -e "${CYAN}  Installing Node.js (this may take 1-2 minutes)...${NC}"
        brew install node 2>&1 | tail -3

        if command -v node &> /dev/null; then
            echo -e "${GREEN}  ✅ Installed — Node.js $(node --version)${NC}"
            add_result "✅ Node.js $(node --version)"
        else
            echo -e "${RED}  ❌ FAILED${NC}"
            add_result "❌ Node.js"
            add_fix "┃  Node.js install failed.
┃  FIX: Open Terminal and run:
┃       brew install node
┃  If that doesn't work, download from https://nodejs.org
┃  (pick the LTS version), install it, then re-run this script."
            ((error_count++))
        fi
    fi
fi

# Check npx (comes with Node)
if command -v npx &> /dev/null; then
    echo -e "${GREEN}  ✅ npx available — $(npx --version)${NC}"
    add_result "✅ npx"
elif command -v node &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  npx not found yet — close Terminal and reopen, it should appear${NC}"
    add_result "⚠️  npx (restart Terminal)"
    add_fix "┃  npx wasn't found, but Node.js is installed.
┃  FIX: Close this Terminal window completely, open a new one,
┃  and run this script again. npx should work after that."
    ((error_count++))
fi
echo ""

# =============================================================
# Step 6: Configure SEMOSS credentials (interactive)
# =============================================================
echo -e "${YELLOW}━━━ [6/6] SEMOSS Project Configuration ━━━${NC}"

CONFIG_DIR="semoss_config"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Only do config if in a project directory
if [[ -d "scripts" ]] || [[ -d "$CONFIG_DIR" ]]; then
    echo ""
    echo -e "${CYAN}  Let's set up your SEMOSS connection.${NC}"
    echo -e "${CYAN}  You'll need your Access Key and Secret Key from SEMOSS.${NC}"
    echo -e "${DIM}  (Find them at: Settings → My Profile on your SEMOSS instance)${NC}"
    echo ""
    echo -e "${DIM}  Press Enter to skip any field — you can configure later.${NC}"
    echo ""

    read -rp "  Base URL (e.g. https://your-instance.semoss.org): " base_url
    read -rp "  Access Key: " access_key
    read -rp "  Secret Key: " secret_key
    read -rp "  Project ID: " project_id
    read -rp "  API Module URL (press Enter for /api): " api_module_url
    read -rp "  Web Module URL (press Enter for /web): " web_module_url

    api_module_url="${api_module_url:-/api}"
    web_module_url="${web_module_url:-/web}"

    if [[ -n "$base_url" && -n "$access_key" && -n "$secret_key" && -n "$project_id" ]]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" <<EOF
{
    "project_id": "$project_id",
    "base_url": "$base_url",
    "api_module_url": "$api_module_url",
    "web_module_url": "$web_module_url"
}
EOF

        mkdir -p .vscode
        cat > .vscode/mcp.json <<EOF
{
    "servers": {
        "semoss": {
            "command": "npx",
            "args": ["-y", "@anthropic-ai/mcp-proxy@latest", "--transport", "streamable-http", "${base_url}${api_module_url}/mcp/sse"],
            "env": {
                "MCP_HEADERS": "Authorization: Bearer ${access_key} ${secret_key}\\nProject: ${project_id}"
            }
        }
    }
}
EOF

        echo ""
        echo -e "${GREEN}  ✅ Configuration saved!${NC}"
        add_result "✅ SEMOSS configured"
    else
        echo ""
        echo -e "${YELLOW}  ⏭️  Skipped for now — no worries, you can do this later.${NC}"
        add_result "⏭️  SEMOSS config (skipped)"
    fi
else
    echo -e "${YELLOW}  ⏭️  You're not inside a project folder right now.${NC}"
    echo -e "${DIM}     That's fine — clone your project first, then config:${NC}"
    echo -e "${CYAN}     git clone https://github.com/SEMOSS/vibe_setup_vscode.git my-app${NC}"
    echo -e "${CYAN}     cd my-app${NC}"
    echo -e "${CYAN}     Then re-run this script from inside that folder.${NC}"
    add_result "⏭️  SEMOSS config (not in project folder)"
fi

# =============================================================
# FINAL SUMMARY
# =============================================================
echo ""
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════╗"
echo -e "║                    SETUP SUMMARY                       ║"
echo -e "╠════════════════════════════════════════════════════════╣${NC}"

for result in "${RESULTS[@]}"; do
    echo -e "║  $result"
done

echo -e "${BOLD}╚════════════════════════════════════════════════════════╝${NC}"

if [ $error_count -eq 0 ]; then
    echo ""
    echo -e "${GREEN}${BOLD}  🎉 ALL DONE! Your environment is ready for vibe coding.${NC}"
    echo ""
    echo -e "  ${BOLD}WHAT TO DO NEXT:${NC}"
    echo -e "  ───────────────"
    echo -e "  1. ${CYAN}Close this Terminal and open a new one${NC} (so new commands work)"
    echo -e "  2. Open VS Code"
    echo -e "  3. Open your project folder in VS Code"
    echo -e "  4. Start coding! The MCP tools should connect automatically."
    echo ""
    echo -e "  ${BOLD}USEFUL COMMANDS:${NC}"
    echo -e "  ───────────────"
    echo -e "  ${CYAN}semoss-activate${NC}          — Activate the Python environment"
    echo -e "  ${CYAN}python scripts/semoss_asset_sync.py upload <file>${NC}"
    echo -e "                            — Upload a file to SEMOSS"
    echo ""
else
    echo ""
    echo -e "${RED}${BOLD}  ⚠️  $error_count ISSUE(S) NEED FIXING${NC}"
    echo ""
    echo -e "  ${BOLD}HOW TO FIX:${NC}"
    echo -e "  ──────────"
    echo ""
    for fix in "${FIXES[@]}"; do
        echo -e "${RED}$fix${NC}"
        echo ""
    done
    echo -e "  ${BOLD}After fixing, run this script again:${NC}"
    echo -e "  ${CYAN}chmod +x setup-scripts/setup_mac.sh && ./setup-scripts/setup_mac.sh${NC}"
    echo ""
fi

echo -e "${DIM}  Need help? Ask your team lead or post in the team Slack/Teams channel.${NC}"
echo ""
