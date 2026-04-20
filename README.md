# Domitek Secrets Manager

**Secure AI development with zero .env files.**

Stop Claude Code from silently loading your API keys. Store secrets in Windows Credential Manager — injected at runtime, gone when the session ends.

---

## Quick Install — New Machine

**Option A — One command (no git required):**

```powershell
irm https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main/setup.ps1 | iex
```

**Option B — Clone and run:**

```powershell
git clone https://github.com/LBu3n0/domitek-secrets-manager-public
cd domitek-secrets-manager-public
.\setup.ps1
```

The setup script detects what's installed, skips it, and only installs what's missing. Safe to run multiple times.

---

## What the setup script does

1. Checks Node.js, Git, Claude Code — installs what's missing
2. Installs CredentialManager PowerShell module
3. Installs your IDE of choice — VS Code, Cursor, both, or skip
4. **Asks where your project folder is** — works on any drive
5. Copies launcher scripts into your project folder
6. Installs the Domitek Secrets Manager GUI to `C:\DomitekVault`
7. Creates a **Domitek Launch** desktop shortcut
8. Opens the GUI so you can enter your secrets

---

## What's new in v1.5

- **Domitek logo** in the GUI header
- **Key rotation reminders** — set 30 / 90 / 180 day or Never rotation per key, with a days-remaining status column (green / yellow / red)
- **Auto-regenerate `launch-claude.ps1`** from `launch-template.ps1` whenever vault keys change
- **VS Code / Cursor install prompts** — if the IDE isn't found when you click Open in VS Code / Open in Cursor, DSM offers to install it via winget
- **Wider form** (620px) for easier key entry
- **Copyright footer** — Copyright (c) 2026 Domitek. All rights reserved. | Author: Libis R. Bueno | scan.domitek.ai

---

## Daily usage

Double-click the **Domitek Launch** shortcut on your desktop — or run:

```powershell
& "C:\DomitekVault\DomitekLaunch.bat"
```

Choose from the menu:

- **[1] Launch Secrets Manager** — opens the GUI
- **[2] Launch Claude Code** — injects vault secrets and starts Claude Code
- **[3] Update Tool** — downloads the latest installer and updates DSM
- **[4] View Vault** — opens Windows Credential Manager

From the Secrets Manager GUI you can:

- **Launch Claude Code** — standalone PowerShell with vault secrets injected
- **Open in VS Code** — injects vault secrets, then opens VS Code
- **Open in Cursor** — injects vault secrets, then opens Cursor
- **Toggle Claude Code Protection** — enables deny rules that block Claude from reading `.env` files or displaying environment variables

---

## Repo structure

```
domitek-secrets-manager-public/
  setup.ps1                        -- one-command machine setup
  Install-SecretsManager-v1.5.ps1  -- GUI installer (v1.5)
  DomitekLaunch.bat                -- entry point (double-click)
  DomitekLaunch.ps1                -- menu script
  DomitekLaunch.ico                -- launcher icon
  logo_base64.txt                  -- Domitek logo (base64)
  remove-dsm.ps1                   -- uninstall helper
  README.md                        -- this file
  template/
    launch-template.ps1            -- template DSM uses to generate launch-claude.ps1
```

---

## How it works

**The problem:**

```
[dotenv@17.3.1] injecting env (3) from .env
```

Claude Code automatically reads your `.env` file the moment it starts — silently, before you type a single prompt. That means every API key in that file is exposed to whatever the AI runs next.

**The solution — two layers:**

**Layer 1 — Deny rules:** Toggle in the Secrets Manager GUI. Blocks Claude Code from reading `.env` files and from displaying environment variables via `printenv`, `env`, `echo $env:*`, or `Get-ChildItem env:`.

**Layer 2 — OS Vault:** Remove the `.env` file from disk entirely. Secrets live in Windows Credential Manager — OS-encrypted, protected by your Windows login, injected into session memory at launch, and gone when the terminal closes.

---

## Prerequisites

| Requirement | How to check |
|---|---|
| Windows 10 or 11 | `winver` |
| PowerShell 5.1+ | Comes with Windows |
| Claude Max subscription | claude.ai |

Node.js, Git, and Claude Code are installed automatically by `setup.ps1` if missing.

---

## VS Code and Cursor

**VS Code:** Use the **Open in VS Code** button in the Secrets Manager. Vault secrets are injected before VS Code opens — the integrated terminal inherits them. If VS Code isn't installed, DSM offers to install it via winget; relaunch DSM after install to refresh PATH.

**Cursor:** Use the **Open in Cursor** button. Same injection and install-prompt behavior. Note: Cursor doesn't support Claude Code's deny rules, so Layer 2 (no `.env` file on disk) is your protection.

---

## Known limitations

- Windows only — macOS Keychain support is planned
- After installing VS Code or Cursor via the DSM install prompt, relaunch DSM for PATH refresh
- CredentialManager PowerShell module can only be removed after restarting PowerShell

---

## Built by

**Domitek AI Security** — scan.domitek.ai

*Copyright (c) 2026 Domitek. All rights reserved. | Author: Libis R. Bueno*
