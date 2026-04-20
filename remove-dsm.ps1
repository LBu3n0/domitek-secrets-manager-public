# =============================================================
# Domitek Secrets Manager -- Remove DSM (End User)
# =============================================================
# USAGE:
#   From the Domitek Launch menu, select [5] Remove DSM
#   OR directly:
#   & "C:\DomitekVault\remove-dsm.ps1"
#
# WHAT IT DOES:
#   Uninstalls DSM with a choice of scope and double confirmation.
#
#   Scope options:
#     [1] DSM only -- keeps Node.js, Git, Claude Code, IDEs, and
#         the CredentialManager module removed ONLY if chosen.
#         Removes DSM folders, launch scripts, and desktop shortcut.
#     [2] Full setup -- everything setup.ps1 installed.
#     [3] Cancel -- exit without doing anything.
#
#   Vault credentials are asked separately (Y/N) after scope choice.
#
# Copyright (c) 2026 Domitek. All rights reserved.
# Author: Libis R. Bueno | scan.domitek.ai
# =============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =============================================================
# RELEASE CWD LOCK (PRD 8.9 vault-lock fix, belt before suspenders)
# -------------------------------------------------------------
# The desktop shortcut's Start-In directory may be C:\DomitekVault,
# and menu [5]'s Start-Process invocation inherits that CWD into
# the uninstaller's new window. The process itself then pins the
# folder it's trying to delete in Step 4.
#
# Set-Location updates the PowerShell provider location; assigning
# [Environment]::CurrentDirectory updates the Win32 CWD (what
# Windows actually checks for "folder in use"). Both are needed.
# This runs unconditionally so every invocation path is covered:
# menu [5] (pre-copied to %TEMP%), standalone, and self-exec'd.
# =============================================================
Set-Location $env:TEMP
[Environment]::CurrentDirectory = $env:TEMP

# =============================================================
# SELF-RELOCATE to %TEMP% (PRD 8.9 vault-lock fix)
# -------------------------------------------------------------
# If this script is loaded from inside C:\DomitekVault it cannot
# delete that folder while running. Copy self to %TEMP%, spawn a
# fresh PowerShell window running the temp copy, then hard-exit
# the current process so any parent (DomitekLaunch.ps1) also
# releases its handles on C:\DomitekVault.
# =============================================================
$scriptPath = $PSCommandPath
if ($scriptPath -and $scriptPath -like "C:\DomitekVault\*") {
    $tempCopy = Join-Path $env:TEMP "remove-dsm-$PID.ps1"
    try {
        Copy-Item $scriptPath $tempCopy -Force -ErrorAction Stop
        Set-Location $env:TEMP
        Start-Process powershell.exe -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy","Bypass",
            "-File","`"$tempCopy`""
        ) -WindowStyle Normal
        [Environment]::Exit(0)
    } catch {
        Write-Host ""
        Write-Host "  [WARN] Could not relocate to TEMP: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  [WARN] Continuing in-place. Vault folder delete may fail." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 2
    }
}

# -- Helpers ---------------------------------------------------------------
function Write-Header { param($t)
    Write-Host ""
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  $t" -ForegroundColor White
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}
function Write-OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Write-Skip { param($t) Write-Host "  [SKIP] $t" -ForegroundColor DarkGray }
function Write-Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Write-Step { param($t) Write-Host "  >> $t" -ForegroundColor Cyan }
function Test-Cmd   { param($c) return $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }

# -- Read project path from config.json (so we know where the launch scripts live)
function Get-ProjectDir {
    $cfg = "C:\DomitekVault\config.json"
    if (Test-Path $cfg) {
        try {
            $data = Get-Content $cfg -Raw | ConvertFrom-Json
            if ($data.project_path) { return $data.project_path }
        } catch {}
    }
    return $null
}

# -- Banner ----------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  =============================================" -ForegroundColor DarkGray
Write-Host "   Remove Domitek Secrets Manager" -ForegroundColor Red
Write-Host "  =============================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Choose what to remove:" -ForegroundColor White
Write-Host ""
Write-Host "    [1] DSM only" -ForegroundColor Cyan
Write-Host "        - Removes C:\DomitekVault and launch scripts" -ForegroundColor Gray
Write-Host "        - Removes launch-claude.ps1 and .domitek-secrets.md" -ForegroundColor Gray
Write-Host "          from your project folder" -ForegroundColor Gray
Write-Host "        - Strips the 'Domitek Secrets' section from CLAUDE.md" -ForegroundColor Gray
Write-Host "          (keeps any content you wrote)" -ForegroundColor Gray
Write-Host "        - Removes CredentialManager PowerShell module" -ForegroundColor Gray
Write-Host "        - Removes desktop shortcut" -ForegroundColor Gray
Write-Host "        - Keeps Node.js, Git, Claude Code, VS Code, Cursor" -ForegroundColor Gray
Write-Host ""
Write-Host "    [2] DSM + all apps setup.ps1 installed" -ForegroundColor Cyan
Write-Host "        - Everything from [1], plus:" -ForegroundColor Gray
Write-Host "        - Uninstalls Node.js, Git, Claude Code" -ForegroundColor Gray
Write-Host "        - Uninstalls VS Code and Cursor" -ForegroundColor Gray
Write-Host "        - Removes npm/nextjs leftover folders" -ForegroundColor Gray
Write-Host "        - Removes Claude Code user config (~\.claude)" -ForegroundColor Gray
Write-Host ""
Write-Host "    [3] Cancel" -ForegroundColor DarkGray
Write-Host ""

$scope = Read-Host "  Enter 1, 2 or 3"

if ($scope -eq "3" -or $scope -ne "1" -and $scope -ne "2") {
    Write-Host ""
    Write-Host "  Cancelled. Nothing was removed." -ForegroundColor Yellow
    Write-Host ""
    exit
}

# -- Scope description and first confirmation -----------------------------
Write-Host ""
if ($scope -eq "1") {
    Write-Host "  You chose: [1] DSM only" -ForegroundColor Cyan
} else {
    Write-Host "  You chose: [2] DSM + all installed apps" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "  This action is IRREVERSIBLE." -ForegroundColor Red
Write-Host ""

$firstConfirm = Read-Host "  Proceed? (Y/N)"
if ($firstConfirm.ToUpper() -ne "Y") {
    Write-Host ""
    Write-Host "  Cancelled. Nothing was removed." -ForegroundColor Yellow
    Write-Host ""
    exit
}

# -- Second confirmation: typed UNINSTALL ---------------------------------
Write-Host ""
Write-Host "  Final confirmation." -ForegroundColor Yellow
Write-Host ""
$typedConfirm = Read-Host "  Type UNINSTALL (all caps) to proceed"
if ($typedConfirm -cne "UNINSTALL") {
    Write-Host ""
    Write-Host "  Confirmation not matched. Nothing was removed." -ForegroundColor Yellow
    Write-Host ""
    exit
}

# =============================================================
# STEP 1 -- UNINSTALL APPLICATIONS (scope [2] only)
# =============================================================
if ($scope -eq "2") {
    Write-Header "STEP 1 -- Uninstalling applications"

    $apps = @(
        @{ name = "Claude Code";  id = "Anthropic.ClaudeCode" },
        @{ name = "Cursor";       id = "Anysphere.Cursor" },
        @{ name = "VS Code";      id = "Microsoft.VisualStudioCode" },
        @{ name = "Git";          id = "Git.Git" },
        @{ name = "Node.js LTS";  id = "OpenJS.NodeJS.LTS" }
    )

    if (-not (Test-Cmd "winget")) {
        Write-Warn "winget not available -- skipping application uninstall"
        Write-Warn "Uninstall manually from: Settings > Apps > Installed apps"
    } else {
        foreach ($app in $apps) {
            Write-Step "Uninstalling $($app.name)..."
            try {
                $result = winget uninstall --id $app.id --silent --accept-source-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "$($app.name) uninstalled"
                } else {
                    Write-Skip "$($app.name) (not installed or already removed)"
                }
            } catch {
                Write-Skip "$($app.name) (not installed)"
            }
        }
    }
} else {
    Write-Header "STEP 1 -- Application uninstall (skipped for DSM-only)"
    Write-Skip "Node.js, Git, Claude Code, VS Code, Cursor all kept as-is"
}

# =============================================================
# STEP 2 -- REMOVE CREDENTIALMANAGER POWERSHELL MODULE
# =============================================================
Write-Header "STEP 2 -- Removing CredentialManager module"

if (Get-Module -ListAvailable -Name CredentialManager -ErrorAction SilentlyContinue) {
    try {
        Uninstall-Module -Name CredentialManager -AllVersions -Force -ErrorAction Stop
        Write-OK "CredentialManager module removed"
    } catch {
        Write-Warn "CredentialManager is in use -- will be removed on next restart"
        Write-Warn "(Close all PowerShell windows, then it will free up)"
    }
} else {
    Write-Skip "CredentialManager (not installed)"
}

# =============================================================
# STEP 3 -- VAULT CREDENTIALS (Y/N)
# =============================================================
Write-Header "STEP 3 -- Vault credentials"

Write-Host "  Your stored API keys and secrets are still in" -ForegroundColor White
Write-Host "  Windows Credential Manager." -ForegroundColor White
Write-Host ""
Write-Host "  Remove them?" -ForegroundColor White
Write-Host "    Y = Remove all DSM-stored credentials" -ForegroundColor Gray
Write-Host "    N = Keep them (useful if you plan to reinstall DSM)" -ForegroundColor Gray
Write-Host ""

$credChoice = Read-Host "  Remove vault credentials? (Y/N)"
if ($credChoice.ToUpper() -eq "Y") {
    $vaultLines = cmdkey /list 2>$null
    $removed = 0
    foreach ($line in $vaultLines) {
        if ($line -match "Target:\s*(.+)$") {
            $target = $matches[1].Trim()
            $detail = cmdkey /list:"$target" 2>$null | Out-String
            if ($detail -match "(?m)^\s*User:\s*domitek\s*$") {
                try {
                    cmdkey /delete:"$target" 2>&1 | Out-Null
                    $removed++
                } catch {}
            }
        }
    }
    if ($removed -gt 0) { Write-OK "Removed $removed vault credential(s)" }
    else { Write-Skip "No DSM vault credentials found" }
} else {
    Write-Skip "Vault credentials kept"
}

# =============================================================
# CAPTURE PROJECT PATH BEFORE STEP 4 (ordering bug fix)
# -------------------------------------------------------------
# Step 4 deletes C:\DomitekVault, which contains config.json --
# the file Get-ProjectDir reads to find the user's project
# folder. If we don't capture the path BEFORE the vault wipe,
# Step 5 will get $null back from Get-ProjectDir and silently
# skip cleaning the user's project folder, leaving orphan
# launch-claude.ps1 and domitek-setup-guide.md files behind.
# =============================================================
$projectDir = Get-ProjectDir

# =============================================================
# STEP 4 -- REMOVE FOLDERS AND FILES
# =============================================================
Write-Header "STEP 4 -- Removing DSM folders and files"

# Build path list based on scope
$paths = @(
    # Always remove (DSM-specific)
    "C:\DomitekVault",
    "$env:APPDATA\DomitekVault",
    "$env:USERPROFILE\Desktop\Domitek Launch.lnk"
)

if ($scope -eq "2") {
    # Scope [2] also cleans up Node.js leftovers and Claude Code config
    $paths += @(
        "$env:APPDATA\npm",
        "$env:APPDATA\npm-cache",
        "$env:APPDATA\nextjs-nodejs",
        "$env:LOCALAPPDATA\anthropic-claude-code",
        "$env:LOCALAPPDATA\Programs\cursor"
    )
}

foreach ($p in $paths) {
    if (-not (Test-Path $p)) {
        Write-Skip "Not found: $p"
        continue
    }

    # Retry-with-verify: Remove-Item -Recurse can report success while
    # leaving locked children (e.g., AMSI/Defender read handles on a
    # just-executed .ps1 file). Don't trust its return -- Test-Path after
    # each attempt, retry up to 5 times with a short delay in between.
    $maxAttempts = 5
    $removed     = $false
    $lastError   = $null

    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            Remove-Item $p -Recurse -Force -ErrorAction Stop
        } catch {
            $lastError = $_.Exception.Message
        }

        Start-Sleep -Milliseconds 500
        if (-not (Test-Path $p)) {
            $removed = $true
            break
        }

        if ($i -lt $maxAttempts) { Start-Sleep -Seconds 1 }
    }

    if ($removed) {
        Write-OK "Removed: $p"
    } elseif ($lastError) {
        Write-Warn "Could not remove: $p ($lastError)"
    } else {
        Write-Warn "Could not remove: $p (still present after $maxAttempts attempts -- handle may still be held)"
    }
}

# =============================================================
# STEP 5 -- REMOVE LAUNCH SCRIPTS FROM USER'S PROJECT FOLDER
# =============================================================
Write-Header "STEP 5 -- Cleaning user's project folder"

# $projectDir was captured BEFORE Step 4 wiped config.json (see
# the capture block above Step 4). Don't re-read it here.
if ($null -eq $projectDir) {
    Write-Skip "No project path configured (config.json was missing or unreadable)"
} elseif (-not (Test-Path $projectDir)) {
    Write-Skip "Project folder no longer exists: $projectDir"
} else {
    Write-Host "  Project folder: $projectDir" -ForegroundColor Gray

    # Files DSM fully owns -- always safe to delete
    $dsmOwnedFiles = @(
        "$projectDir\launch-claude.ps1",
        "$projectDir\.domitek-secrets.md",
        "$projectDir\domitek-setup-guide.md"
    )
    foreach ($pf in $dsmOwnedFiles) {
        if (Test-Path $pf) {
            try {
                Remove-Item $pf -Force -ErrorAction Stop
                Write-OK "Removed: $pf"
            } catch {
                Write-Warn "Could not remove: $pf"
            }
        } else {
            Write-Skip "Not found: $pf"
        }
    }

    # CLAUDE.md -- surgical cleanup. Strip only the Domitek section,
    # preserve any user-authored content. Delete the file only if it
    # becomes empty/whitespace after removal.
    $claudeMd = "$projectDir\CLAUDE.md"
    if (Test-Path $claudeMd) {
        try {
            $existing = [System.IO.File]::ReadAllText($claudeMd)
            $pattern = "(?ms)\r?\n?## Domitek Secrets \(auto-generated\).*?(?=\r?\n## [^#\r\n]|\z)"
            $stripped = [regex]::Replace($existing, $pattern, "")
            $stripped = $stripped.TrimEnd()

            if ([string]::IsNullOrWhiteSpace($stripped)) {
                Remove-Item $claudeMd -Force
                Write-OK "Removed: $claudeMd (was Domitek-only content)"
            } else {
                # Preserve user's content, write back without the Domitek section
                [System.IO.File]::WriteAllText($claudeMd, $stripped, (New-Object System.Text.UTF8Encoding $false))
                Write-OK "Stripped Domitek section from: $claudeMd (user content preserved)"
            }
        } catch {
            Write-Warn "Could not process CLAUDE.md: $($_.Exception.Message)"
        }
    } else {
        Write-Skip "Not found: $claudeMd"
    }

    Write-Host "  Your project code and other files were not touched." -ForegroundColor DarkGray
}

# =============================================================
# STEP 6 -- REMOVE CLAUDE CODE USER CONFIG (scope [2] only)
# =============================================================
if ($scope -eq "2") {
    Write-Header "STEP 6 -- Removing Claude Code user config"
    $claudeDir = "$env:USERPROFILE\.claude"
    if (Test-Path $claudeDir) {
        try {
            Remove-Item $claudeDir -Recurse -Force -ErrorAction Stop
            Write-OK "Removed: $claudeDir"
        } catch {
            Write-Warn "Could not remove $claudeDir -- close Claude Code and retry"
        }
    } else {
        Write-Skip "Not found: $claudeDir"
    }
}

# =============================================================
# DONE
# =============================================================
Write-Header "REMOVAL COMPLETE"

Write-Host "  Domitek Secrets Manager has been removed." -ForegroundColor Green
Write-Host ""
Write-Host "  Notes:" -ForegroundColor White
Write-Host "    - Your project folder and your code were not touched" -ForegroundColor Gray
if ($scope -eq "1") {
    Write-Host "    - Node.js, Git, Claude Code, VS Code, and Cursor were kept" -ForegroundColor Gray
} else {
    Write-Host "    - If any app uninstalls were skipped, check Settings > Apps" -ForegroundColor Gray
}
Write-Host "    - CredentialManager module (if still loaded) fully clears" -ForegroundColor Gray
Write-Host "      after you close all PowerShell windows" -ForegroundColor Gray
Write-Host ""
Write-Host "  To reinstall DSM later:" -ForegroundColor Cyan
Write-Host "    irm https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main/setup.ps1 | iex" -ForegroundColor Gray
Write-Host ""

Read-Host "  Press Enter to close"
