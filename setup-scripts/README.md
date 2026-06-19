# SEMOSS Vibe Coding — Setup Scripts

Everything you need to start vibe coding with SEMOSS, installed in one command.

---

## 🍎 macOS Setup

### Option A: One-liner (recommended for most people)

Open **Terminal** (search "Terminal" in Spotlight), paste this, and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/SEMOSS/vibe_setup_vscode/main/setup-scripts/setup_mac.sh | bash
```

### Option B: From cloned repo

```bash
chmod +x setup-scripts/setup_mac.sh && ./setup-scripts/setup_mac.sh
```

---

## 🪟 Windows Setup

1. Search for **PowerShell** in the Start Menu
2. **Right-click → Run as Administrator**
3. Paste these two lines:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-scripts\setup_windows.ps1
```

---

## What gets installed

| Tool | Why you need it |
|------|----------------|
| **Xcode CLI Tools** (macOS) | Required before anything else can install |
| **Homebrew** (macOS) | Installs Python and Node for you |
| **Python 3.13** | Runs the SEMOSS sync script (`semoss_asset_sync.py`) |
| **~/.semoss-venv** | Isolated Python environment (won't mess up other Python projects) |
| **ai-server-sdk** | SEMOSS Python SDK — connects to your SEMOSS instance |
| **Node.js + npx** | Needed by VS Code to connect to SEMOSS MCP tools |

---

## After setup

| Task | macOS command | Windows command |
|------|--------------|-----------------|
| Activate Python env | `semoss-activate` | `~\.semoss-venv\Scripts\activate` |
| Upload a file | `python scripts/semoss_asset_sync.py upload <file>` | Same |
| Pull from remote | `python scripts/semoss_asset_sync.py sync-from-remote version/assets/portals --overwrite` | Same |
| Configure credentials | `python scripts/semoss_asset_sync.py configure-local --help` | Same |

---

## Troubleshooting

### "brew: command not found"
Close Terminal and open a new one. If still broken:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### "python3.13: command not found"
```bash
brew install python@3.13
```
Then close and reopen Terminal.

### "semoss-activate: command not found"
Open a new Terminal window (the alias was just added to your profile).

### "execution of scripts is disabled" (Windows)
Run this first:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### SDK import error
Delete the venv and re-run setup:
```bash
rm -rf ~/.semoss-venv   # macOS
# or
Remove-Item -Recurse -Force "$env:USERPROFILE\.semoss-venv"  # Windows
```

### "npx not found"
Close your terminal, reopen it. npx comes with Node.js but needs a fresh shell.

---

## Still stuck?

Ask your team lead or post in the team Slack/Teams channel.
