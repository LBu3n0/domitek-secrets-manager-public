# Domitek Secrets Manager — Setup Guide
**Version 1.5 | April 2026**

---

## WHAT IT DOES

Keeps your API keys and credentials out of `.env` files and safely stored in Windows Credential Manager. Secrets inject into memory when you launch Claude Code — nothing written to disk, nothing to commit, nothing to leak.

DSM also reminds you to rotate your keys on a schedule you set, and connects to scan.domitek.ai so you can check whether any secrets already leaked into past Git commits.

---

## SETUP

Run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main/setup.ps1 | iex
```

Setup installs Node.js, Git, Claude Code, and the Secrets Manager GUI automatically. When prompted:

- Choose your IDE — VS Code, Cursor, both, or skip
- Enter your project folder path (works on any drive)

When complete, a **Domitek Launch** shortcut appears on your desktop, and the Secrets Manager GUI opens automatically.

---

## FIRST TIME: STORING YOUR SECRETS

1. Double-click **Domitek Launch** on your desktop (or it opens automatically after setup)
2. Select **[1] Launch Secrets Manager**
3. Enter a project name, or browse to your project folder
4. Pick a **project type**:
   - **Claude Code Assistant** — for developers using their Claude Max subscription (no ANTHROPIC_API_KEY needed)
   - **Claude Code Application** — for apps that call the Anthropic API directly (includes ANTHROPIC_API_KEY)
   Each type pre-fills common key names (Supabase, ElevenLabs, n8n) so you're not typing them from scratch.
5. Enter your secret values — they're masked during entry
6. For each key, set a **rotation period** from the dropdown: 30 / 90 / 180 days / Never
7. Click **Store to Vault + Generate Script**

Your secrets are now in Windows Credential Manager. DSM also generates a `launch-claude.ps1` in your project folder — that's the launcher that injects your secrets into Claude Code's session memory.

---

## DAILY USE

Double-click **Domitek Launch** on your desktop.

| Option | What it does |
|---|---|
| **[1] Launch Secrets Manager** | Manage vault secrets, rotations, and IDE launches |
| **[2] Launch Claude Code** | Inject secrets and start Claude Code (uses your saved project path) |
| **[3] Update Tool** | Get the latest version from GitHub |
| **[4] View Vault** | Open Windows Credential Manager |

---

## LAUNCHING YOUR IDE FROM DSM

Inside the Secrets Manager, after selecting a project:

- **Launch Claude Code** — standalone PowerShell with vault secrets injected
- **Open in VS Code** — injects vault secrets, then opens VS Code in your project folder
- **Open in Cursor** — injects vault secrets, then opens Cursor in your project folder

Secrets exist only in the launched session's memory. When the terminal or IDE closes, they're gone.

**If VS Code or Cursor isn't installed** when you click the button, DSM offers to install it via winget. After the install completes, **close and reopen DSM** so the system PATH refreshes — then the button will find the IDE.

---

## KEY ROTATION REMINDERS

Strong security hygiene means rotating keys on a schedule. DSM tracks when each key is due for rotation so you don't have to keep a separate calendar.

- Set a period per key: **30 / 90 / 180 days / Never**
- The **Status column** shows how many days remain until each key needs rotating:
  - 🟢 **Green** — more than 30 days remaining
  - 🟡 **Yellow** — less than 30 days remaining (plan to rotate soon)
  - 🔴 **Red** — overdue (rotate now)
- Rotation metadata is stored in `C:\DomitekVault\rotation.json`

**To update a rotation period without changing the value:** change the dropdown, leave the value field blank, click **Store to Vault + Generate Script**. Only the rotation date is updated — your existing key value is preserved.

**When a key goes red:** go to the service (Anthropic console, Supabase dashboard, etc.), generate a new key, paste it into DSM, set a fresh rotation period, and click Store.

---

## CLAUDE CODE PROTECTION

The GUI has a protection toggle that writes deny rules to `~/.claude/settings.json`:

- Blocks Claude Code from reading `.env`, `.env.local`, `.env.production`, etc.
- Blocks Claude Code from displaying environment variables via `echo $env:*`, `printenv`, `env`, `Get-ChildItem env:`, etc.

To enable:

1. Open the Secrets Manager
2. Click **Claude Code Protection: OFF** — it turns green when enabled

Recommended for all real work. To disable temporarily (for demos or testing), click again — it turns red.

---

## AUTO-REGENERATE LAUNCH SCRIPT

DSM checks whether your `launch-claude.ps1` matches the current v1.5 template. If it's out of date — for example, created by an older version, or missing keys you've added since — DSM regenerates it automatically when you next click **Store to Vault + Generate Script**.

The regeneration uses the template at `C:\DomitekVault\launch-template.ps1` and fills in your current vault keys. No manual editing of launch scripts is ever required.

---

## SCANNING YOUR REPOS FOR EXISTING LEAKS

DSM prevents new leaks. But if you previously committed secrets to a Git repo — even if you deleted the file later — they may still be in the Git history.

In the Secrets Manager GUI, click the **scan.domitek.ai** button. It opens the Domitek repo scanner in your browser, where you can point it at your GitHub repositories and check whether any credentials already leaked. An important catch before making any repo public.

Prevention (DSM) pairs with detection (scan.domitek.ai) — you want both.

---

## UPDATING

From the launch menu, select **[3] Update Tool**. DSM downloads the latest installer from the public GitHub repo and runs it automatically. Your vault contents and rotation settings are preserved across updates.

---

## TROUBLESHOOTING

**Secrets show as missing when launching Claude Code**
→ Open the Secrets Manager, select your project, re-enter any missing values, click **Store to Vault + Generate Script**.

**Desktop shortcut not working**
→ Run directly in PowerShell:
```powershell
& "C:\DomitekVault\DomitekLaunch.bat"
```

**Claude Code not found after setup**
→ Close and reopen PowerShell, then run `claude` again.

**VS Code or Cursor not found after install prompt**
→ Close and reopen the Secrets Manager. The PATH needs a session refresh.

**Status column is empty for existing keys**
→ Select the key, choose a rotation period from the dropdown, click **Store to Vault + Generate Script**. Value field can be left blank — only the rotation date is updated.

**Launch script looks out of date**
→ Click **Store to Vault + Generate Script** — DSM regenerates it from the current template.

---

*Copyright (c) 2026 Domitek. All rights reserved. | Author: Libis R. Bueno | scan.domitek.ai*
