# =============================================================
# Domitek Secrets Manager -- Setup
# =============================================================
# USAGE:
#   irm https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main/setup.ps1 | iex
#   OR
#   .\setup.ps1
#
# WHAT IT DOES:
#   1. Checks Node.js, Git, Claude Code -- installs if missing
#   2. Installs CredentialManager PowerShell module
#   3. Installs your IDE of choice (VS Code / Cursor / skip)
#   4. Asks where your project folder is (any drive)
#   5. Copies launcher scripts into your project folder
#   6. Installs Domitek Secrets Manager GUI in C:\DomitekVault
#   7. Creates desktop shortcut
#
# SAFE TO RUN MULTIPLE TIMES -- skips anything already installed
# =============================================================

param([switch]$Silent)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SCRIPT_DIR = $PSScriptRoot
$VAULT_GUI  = "C:\DomitekVault"

# When run via irm | iex, PSScriptRoot is empty -- download files first
if ([string]::IsNullOrEmpty($SCRIPT_DIR)) {
    $SCRIPT_DIR = "$env:TEMP\domitek-setup"
    Write-Host "  Downloading setup files from GitHub..." -ForegroundColor Cyan
    if (Test-Path $SCRIPT_DIR) { Remove-Item $SCRIPT_DIR -Recurse -Force }
    New-Item -ItemType Directory -Path "$SCRIPT_DIR\template" -Force | Out-Null

    $base = "https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main"
    $downloads = @(
        @{ url = "$base/Install-SecretsManager-v1.5.ps1"; dst = "Install-SecretsManager-v1.5.ps1" },
        @{ url = "$base/DomitekLaunch.bat";                dst = "DomitekLaunch.bat" },
        @{ url = "$base/DomitekLaunch.ps1";                dst = "DomitekLaunch.ps1" },
        @{ url = "$base/template/launch-template.ps1";     dst = "template\launch-template.ps1" },
        @{ url = "$base/domitek-setup-guide.md";           dst = "domitek-setup-guide.md" },
        @{ url = "$base/DomitekLaunch.ico";                dst = "DomitekLaunch.ico" },
        @{ url = "$base/logo_base64.txt";                  dst = "logo_base64.txt" },
        @{ url = "$base/remove-dsm.ps1";                  dst = "remove-dsm.ps1" }
    )

    foreach ($d in $downloads) {
        try {
            Invoke-WebRequest -Uri $d.url -OutFile (Join-Path $SCRIPT_DIR $d.dst) -UseBasicParsing
            Write-Host "  [OK] $($d.dst)" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not download: $($d.dst)" -ForegroundColor Yellow
        }
    }
    Write-Host ""
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
function Write-Skip { param($t) Write-Host "  [SKIP] $t (already installed)" -ForegroundColor DarkGray }
function Write-Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Write-Step { param($t) Write-Host "  >> $t" -ForegroundColor Cyan }
function Test-Cmd   { param($c) return $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }

# Hide internal DSM files from casual File Explorer browsing so users
# don't delete them by mistake. Hidden attribute does not prevent
# deletion from scripts using -Force (remove-dsm, dsm-reset, clean-wipe
# all handle this correctly) but does hide from default Explorer view.
function Set-FileHidden {
    param($path)
    if (Test-Path $path) {
        try {
            $item = Get-Item $path -Force
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
        } catch {}
    }
}

# -- Banner ----------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  =============================================" -ForegroundColor DarkGray
Write-Host "   Domitek Secrets Manager -- Setup" -ForegroundColor White
Write-Host "  =============================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Sets up secure AI development with no .env files." -ForegroundColor Gray
Write-Host "  Safe to run multiple times -- skips installed items." -ForegroundColor Gray
Write-Host ""
Write-Host "  This script will install and configure:" -ForegroundColor White
Write-Host "    - Node.js LTS" -ForegroundColor Gray
Write-Host "    - Git" -ForegroundColor Gray
Write-Host "    - Claude Code" -ForegroundColor Gray
Write-Host "    - Domitek Secrets Manager GUI" -ForegroundColor Gray
Write-Host "    - Your IDE of choice (VS Code or Cursor)" -ForegroundColor Gray
Write-Host "    - Desktop shortcut to launch menu" -ForegroundColor Gray
Write-Host ""

# =============================================================
# EXECUTION POLICY CHECK (Bug B fix)
# -------------------------------------------------------------
# Some PowerShell contexts -- notably PowerShell (x86) on systems
# where that architecture's policy scope is Restricted or AllSigned
# -- cannot execute the nested installer even when Unblock-File
# has been called on it. PowerShell x86 and x64 store execution
# policy in separate registry keys, so a system that looks
# "Unrestricted" from 64-bit PowerShell can still block scripts
# from 32-bit PowerShell.
#
# Detect restrictive policies up-front, warn the user, and offer
# a narrow (Process-scoped) bypass. Cancelling exits cleanly
# before any files are touched.
# =============================================================
$currentPolicy = Get-ExecutionPolicy
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  EXECUTION POLICY CHECK" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  This PowerShell session's execution policy is '$currentPolicy'," -ForegroundColor White
    Write-Host "  which blocks the installer script from running." -ForegroundColor White
    Write-Host ""
    Write-Host "  Setup can temporarily bypass this policy for THIS session only." -ForegroundColor Gray
    Write-Host "  The change affects only this PowerShell window and ends when it" -ForegroundColor Gray
    Write-Host "  closes. System-wide execution policy is not modified." -ForegroundColor Gray
    Write-Host ""
    Write-Host "    [1] Bypass policy for this setup session and continue" -ForegroundColor Cyan
    Write-Host "    [2] Cancel setup" -ForegroundColor DarkGray
    Write-Host ""
    $policyChoice = Read-Host "  Enter 1 or 2"

    if ($policyChoice -eq "1") {
        try {
            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
            Write-Host ""
            Write-Host "  [OK]   Execution policy bypassed for this session" -ForegroundColor Green
            Write-Host ""
        } catch {
            Write-Host ""
            Write-Host "  [WARN] Could not set process-scoped policy: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  [WARN] Setup cannot continue. Please run setup.ps1 from 64-bit" -ForegroundColor Yellow
            Write-Host "         PowerShell instead (not PowerShell x86)." -ForegroundColor Yellow
            Write-Host ""
            return
        }
    } else {
        Write-Host ""
        Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Setup cancelled." -ForegroundColor Yellow
        Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  No changes have been made. Your system is in the same state" -ForegroundColor Gray
        Write-Host "  as before you ran setup." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  To try again: re-run setup.ps1 from 64-bit PowerShell, or" -ForegroundColor Gray
        Write-Host "  choose option [1] when prompted to allow the session bypass." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Thanks for trying Domitek Secrets Manager." -ForegroundColor Cyan
        Write-Host ""
        return
    }
}

# Ask IDE preference
Write-Host "  Which IDE do you want to install?" -ForegroundColor White
Write-Host "    1. VS Code" -ForegroundColor Cyan
Write-Host "    2. Cursor" -ForegroundColor Cyan
Write-Host "    3. Both" -ForegroundColor Cyan
Write-Host "    4. Skip -- I will install my own" -ForegroundColor DarkGray
Write-Host ""
$ideChoice = Read-Host "  Enter 1, 2, 3 or 4"

if (-not $Silent) {
    Read-Host "  Press Enter to begin (or Ctrl+C to cancel)"
}

# =============================================================
# STEP 1 -- PREREQUISITES
# =============================================================
Write-Header "STEP 1 -- Checking prerequisites"

Write-Step "Checking Node.js..."
if (Test-Cmd "node") { Write-Skip "Node.js $(node --version)" }
else {
    Write-Step "Installing Node.js LTS -- UAC prompt may appear..."
    try {
        winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        Write-OK "Node.js installed"
    }
    catch { Write-Warn "Install manually: https://nodejs.org" }
}

Write-Step "Checking Git..."
if (Test-Cmd "git") { Write-Skip "Git" }
else {
    Write-Step "Installing Git..."
    try { winget install Git.Git --silent --accept-package-agreements --accept-source-agreements; Write-OK "Git installed" }
    catch { Write-Warn "Install manually: https://git-scm.com" }
}

Write-Step "Checking Claude Code..."
if (Test-Cmd "claude") { Write-Skip "Claude Code" }
else {
    Write-Step "Installing Claude Code..."
    try { npm install -g @anthropic-ai/claude-code; Write-OK "Claude Code installed -- run 'claude' to log in" }
    catch { Write-Warn "Install manually: npm install -g @anthropic-ai/claude-code" }
}

Write-Step "Checking CredentialManager module..."
if (Get-Module -ListAvailable -Name CredentialManager -ErrorAction SilentlyContinue) { Write-Skip "CredentialManager" }
else {
    try { Install-Module -Name CredentialManager -Force -Scope CurrentUser; Write-OK "CredentialManager installed" }
    catch { Write-Warn "Run manually: Install-Module CredentialManager -Force -Scope CurrentUser" }
}

if ($ideChoice -eq "1" -or $ideChoice -eq "3") {
    Write-Step "Checking VS Code..."
    if (Get-Command "code" -ErrorAction SilentlyContinue) { Write-Skip "VS Code" }
    else {
        Write-Step "Installing VS Code..."
        try { winget install Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements; Write-OK "VS Code installed" }
        catch { Write-Warn "Install manually: https://code.visualstudio.com" }
    }
}

if ($ideChoice -eq "2" -or $ideChoice -eq "3") {
    Write-Step "Checking Cursor..."
    if (Get-Command "cursor" -ErrorAction SilentlyContinue) { Write-Skip "Cursor" }
    else {
        Write-Step "Installing Cursor..."
        try { winget install Anysphere.Cursor --silent --accept-package-agreements --accept-source-agreements; Write-OK "Cursor installed" }
        catch { Write-Warn "Install manually: https://cursor.com" }
    }
}

if ($ideChoice -eq "4") {
    Write-Skip "IDE installation -- skipped by user"
}

# =============================================================
# STEP 2 -- PROJECT FOLDER
# =============================================================
Write-Header "STEP 2 -- Your project folder"

Write-Host "  Where is your project folder?" -ForegroundColor White
Write-Host "  Must include a folder name -- not just a drive." -ForegroundColor Gray
Write-Host ""
Write-Host "  Examples:" -ForegroundColor Gray
Write-Host "    C:\Projects\myapp" -ForegroundColor Gray
Write-Host "    E:\Work\myproject" -ForegroundColor Gray
Write-Host "    D:\Code\my-ai-app" -ForegroundColor Gray
Write-Host ""

do {
    $PROJECT_DIR = Read-Host "  Project folder path"
    if ([string]::IsNullOrWhiteSpace($PROJECT_DIR)) {
        $PROJECT_DIR = "C:\Projects\myproject"
    }
    if ($PROJECT_DIR -match '^[A-Za-z]:\\?$') {
        Write-Host "  Please include a folder name, e.g. E:\myproject" -ForegroundColor Yellow
        $PROJECT_DIR = ""
    }
} while ([string]::IsNullOrWhiteSpace($PROJECT_DIR))

$PROJECT_NAME = Split-Path $PROJECT_DIR -Leaf

foreach ($f in @($PROJECT_DIR, $VAULT_GUI)) {
    if (Test-Path $f) { Write-Skip $f }
    else { New-Item -ItemType Directory -Path $f -Force | Out-Null; Write-OK "Created: $f" }
}

# =============================================================
# STEP 3 -- COPY LAUNCHER SCRIPTS
# =============================================================
Write-Header "STEP 3 -- Copying launcher scripts"

$files = @(
    @{ src = "DomitekLaunch.bat";          dst = "$VAULT_GUI\DomitekLaunch.bat" },
    @{ src = "DomitekLaunch.ps1";          dst = "$VAULT_GUI\DomitekLaunch.ps1" },
    @{ src = "domitek-setup-guide.md";     dst = "$PROJECT_DIR\domitek-setup-guide.md" },
    @{ src = "DomitekLaunch.ico";          dst = "$VAULT_GUI\DomitekLaunch.ico" },
    @{ src = "logo_base64.txt";            dst = "$VAULT_GUI\logo_base64.txt" },
    @{ src = "remove-dsm.ps1";             dst = "$VAULT_GUI\remove-dsm.ps1" }
)

foreach ($f in $files) {
    $src = Join-Path $SCRIPT_DIR $f.src
    if (Test-Path $src) {
        Copy-Item $src $f.dst -Force
        Write-OK "Copied: $($f.dst)"
    } else {
        Write-Warn "Not found: $($f.src)"
    }
}

# Hide the brand-asset file from casual Explorer browsing
Set-FileHidden "$VAULT_GUI\logo_base64.txt"

# Copy launch template to vault
$templateSrc = Join-Path $SCRIPT_DIR "template\launch-template.ps1"
if (Test-Path $templateSrc) {
    Copy-Item $templateSrc "$VAULT_GUI\launch-template.ps1" -Force
    Unblock-File "$VAULT_GUI\launch-template.ps1"
}

Write-Step "Unblocking scripts..."
@("$VAULT_GUI\DomitekLaunch.ps1", "$VAULT_GUI\DomitekLaunch.bat") | ForEach-Object {
    if (Test-Path $_) { Unblock-File $_ }
}
Write-OK "Scripts unblocked"

# =============================================================
# STEP 4 -- INSTALL GUI
# =============================================================
Write-Header "STEP 4 -- Installing Domitek Secrets Manager GUI"

$installer = Join-Path $SCRIPT_DIR "Install-SecretsManager-v1.5.ps1"
$installedGui = "$VAULT_GUI\Domitek-Secrets-Manager.ps1"

if (Test-Path $installer) {
    Unblock-File $installer

    # Run installer with truthful reporting: capture any terminating
    # error AND verify the installer actually produced the GUI file
    # in the vault. Previous behavior printed [OK] unconditionally
    # even when & $installer threw a PSSecurityException, leaving
    # end users with a broken install and no indication of failure.
    $installError = $null
    try {
        & $installer
    } catch {
        $installError = $_.Exception.Message
    }

    if (Test-Path $installedGui) {
        Write-OK "Secrets Manager GUI installed"
    } else {
        if ($installError) {
            Write-Warn "Installer failed: $installError"
        } else {
            Write-Warn "Installer ran but GUI file not created at $installedGui"
        }
        Write-Warn "DSM is NOT installed. Try running setup.ps1 again from 64-bit"
        Write-Warn "PowerShell (not PowerShell x86), or install manually:"
        Write-Warn "  & '$installer'"
    }
} else {
    Write-Warn "Installer not found -- download Install-SecretsManager-v1.5.ps1 manually"
}

# =============================================================
# STEP 5 -- CONFIG AND DESKTOP SHORTCUT
# =============================================================
Write-Header "STEP 5 -- Saving config and creating desktop shortcut"

# Write config.json
$configObj = @{ project_name = $PROJECT_NAME; project_path = $PROJECT_DIR }
$configObj | ConvertTo-Json | Out-File "$VAULT_GUI\config.json" -Encoding UTF8
Set-FileHidden "$VAULT_GUI\config.json"
Write-OK "Config saved: $VAULT_GUI\config.json"

# Create desktop shortcut (targets powershell.exe directly to avoid cmd/PS double window)
$shortcutPath = "$env:USERPROFILE\Desktop\Domitek Launch.lnk"
$ps1Path      = "$VAULT_GUI\DomitekLaunch.ps1"
$iconPath     = "$VAULT_GUI\DomitekLaunch.ico"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = "powershell.exe"
$shortcut.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`""
$shortcut.WorkingDirectory = $VAULT_GUI
$shortcut.Description      = "Domitek Secrets Manager Launch Menu"
if (Test-Path $iconPath) { $shortcut.IconLocation = "$iconPath,0" }
$shortcut.Save()
Write-OK "Desktop shortcut created: Domitek Launch"

# =============================================================
# DONE
# =============================================================
Write-Header "SETUP COMPLETE"

Write-Host "  Ready! Here is what to do next:" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Double-click 'Domitek Launch' on your desktop" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Select [1] Launch Secrets Manager" -ForegroundColor Cyan
Write-Host "     Enter your project name and store your API keys" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Click Launch Claude Code" -ForegroundColor Cyan
Write-Host "     Secrets inject automatically -- nothing written to disk" -ForegroundColor Gray
Write-Host ""
Write-Host "  Guide: $PROJECT_DIR\domitek-setup-guide.md" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  A 'Domitek Launch' shortcut has been added to your desktop." -ForegroundColor Cyan
Write-Host ""

$openNow = Read-Host "  Open Secrets Manager now? (Y/N)"
if ($openNow.ToUpper() -eq "Y") {
    $tool = "$VAULT_GUI\Domitek-Secrets-Manager.ps1"
    if (Test-Path $tool) { & $tool }
    else { Write-Warn "Secrets Manager not found. Run the installer first." }
}



