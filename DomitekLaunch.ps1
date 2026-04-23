[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$VAULT_DIR       = "C:\DomitekVault"
$TOOL_PATH       = "$VAULT_DIR\Domitek-Secrets-Manager.ps1"
$CONFIG_PATH     = "$VAULT_DIR\config.json"
$REMOVE_SCRIPT   = "$VAULT_DIR\remove-dsm.ps1"
$DEV_FLAG        = "$VAULT_DIR\.dev-mode"
$UPDATE_BASE_URL = "https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main"
$INSTALLER_TMP   = "$env:TEMP\Install-SecretsManager-latest.ps1"

# Dev-only script search paths (private repo first, Downloads as fallback)
$DEV_RESET_PATHS = @(
    "C:\GitHub\domitek-secrets-manager-private\dsm-reset.ps1",
    "$env:USERPROFILE\Downloads\dsm-reset.ps1"
)
$CLEAN_WIPE_PATHS = @(
    "C:\GitHub\domitek-secrets-manager-private\clean-wipe.ps1",
    "$env:USERPROFILE\Downloads\clean-wipe.ps1"
)

# -- Helpers ---------------------------------------------------------------
function Get-Config {
    if (Test-Path $CONFIG_PATH) {
        try {
            $raw = Get-Content $CONFIG_PATH -Raw
            return $raw | ConvertFrom-Json
        } catch { return $null }
    }
    return $null
}

function Test-DevMode {
    return (Test-Path $DEV_FLAG)
}

function Find-FirstPath {
    param($paths)
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Run-DevScript {
    param($sourcePath, $label)
    # Copy to %TEMP% before running, since the script may wipe C:\DomitekVault
    # (and itself if run from there). Running from %TEMP% avoids self-deletion.
    $tempCopy = Join-Path $env:TEMP (Split-Path $sourcePath -Leaf)
    try {
        Copy-Item $sourcePath $tempCopy -Force
        Unblock-File $tempCopy
        Write-Host ""
        Write-Host "  Running $label from: $tempCopy" -ForegroundColor Cyan
        Write-Host ""
        & $tempCopy
    } catch {
        Write-Host "  [ERROR] Could not run $label : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-Menu {
    $config      = Get-Config
    $projectName = if ($config) { $config.project_name } else { "[not configured]" }
    $projectPath = if ($config) { $config.project_path } else { "[not configured]" }
    $tStatus     = if (Test-Path $TOOL_PATH) { "[FOUND]" } else { "[NOT FOUND]" }
    $tColor      = if (Test-Path $TOOL_PATH) { "Green" } else { "Red" }
    $devMode     = Test-DevMode

    # Detect first-run state: config exists but launch-claude.ps1 has not
    # been generated yet. Menu option [2] changes its label so users don't
    # land in a dead-end error on their first click.
    $isFirstRun = $false
    if ($config -and $config.project_path) {
        $launchScriptPath = Join-Path $config.project_path "launch-claude.ps1"
        if (-not (Test-Path $launchScriptPath)) {
            $isFirstRun = $true
        }
    }

    Clear-Host
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor DarkGray
    Write-Host "   Domitek Secrets Manager -- Launch Menu" -ForegroundColor White
    Write-Host "  =============================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Project : " -NoNewline -ForegroundColor Gray
    Write-Host $projectName -ForegroundColor Cyan
    Write-Host "  Path    : " -NoNewline -ForegroundColor Gray
    Write-Host $projectPath -ForegroundColor Cyan
    Write-Host "  Tool    : " -NoNewline -ForegroundColor Gray
    Write-Host $tStatus -ForegroundColor $tColor
    if ($devMode) {
        Write-Host "  Mode    : " -NoNewline -ForegroundColor Gray
        Write-Host "[DEV MODE]" -ForegroundColor Magenta
    }
    Write-Host ""
    Write-Host "  [1]  Launch Secrets Manager" -ForegroundColor Cyan
    Write-Host "       Opens the GUI to manage vault secrets" -ForegroundColor DarkGray
    Write-Host ""
    if ($isFirstRun) {
        Write-Host "  [2]  Configure Keys (first-run setup required)" -ForegroundColor Yellow
        Write-Host "       Opens Secrets Manager to store your first secrets" -ForegroundColor DarkGray
    } else {
        Write-Host "  [2]  Launch Claude Code" -ForegroundColor Cyan
        Write-Host "       Injects secrets + launches last project. Use [1] to switch." -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  [3]  Update Tool" -ForegroundColor Yellow
    Write-Host "       Downloads latest version from GitHub and installs" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [4]  View Vault" -ForegroundColor Blue
    Write-Host "       Opens Windows Credential Manager" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [5]  Remove DSM" -ForegroundColor Red
    Write-Host "       Uninstall Domitek Secrets Manager" -ForegroundColor DarkGray
    Write-Host ""
    if ($devMode) {
        Write-Host "  [6]  Dev Reset  (public-tool testing)" -ForegroundColor Magenta
        Write-Host "       Aggressive wipe of setup.ps1 installs" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [7]  Clean Wipe (private-tool testing)" -ForegroundColor Magenta
        Write-Host "       Full dev env wipe (DSM + demo + repos + test creds)" -ForegroundColor DarkGray
        Write-Host ""
    }
    Write-Host "  [Q]  Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Step-LaunchTool {
    if (-not (Test-Path $TOOL_PATH)) {
        Write-Host "  [ERROR] Tool not found: $TOOL_PATH" -ForegroundColor Red
        Write-Host "  Run option [3] to update/install it first." -ForegroundColor Yellow
        return $false
    }
    Write-Host "  Launching Secrets Manager..." -ForegroundColor Cyan
    Start-Process "powershell.exe" `
        -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TOOL_PATH`""
    return $true
}

function Step-LaunchClaude {
    $config = Get-Config
    if ($null -eq $config) {
        Write-Host "  [ERROR] config.json not found in $VAULT_DIR" -ForegroundColor Red
        Write-Host "  Run setup.ps1 first to configure your project." -ForegroundColor Yellow
        return $false
    }
    $launchScript = Join-Path $config.project_path "launch-claude.ps1"
    if (-not (Test-Path $launchScript)) {
        # First-run state: config exists but launch-claude.ps1 has not been
        # generated. Route to the GUI so the user can store their first
        # secrets. After they click "Store to Vault + Generate Script" in
        # the GUI, launch-claude.ps1 exists and menu option [2] will relabel
        # to "Launch Claude Code" on next render.
        Write-Host ""
        Write-Host "  First-run setup detected." -ForegroundColor Yellow
        Write-Host "  Opening Secrets Manager so you can configure your keys..." -ForegroundColor Cyan
        Write-Host ""
        Start-Sleep -Seconds 1
        return Step-LaunchTool
    }
    Write-Host "  Loading vault secrets and starting Claude Code..." -ForegroundColor Cyan
    # Prefer Windows Terminal for a clean dark-theme window matching the
    # desktop shortcut. Fallback to powershell.exe in conhost if wt.exe
    # is missing (some Windows 10 builds). Either way, -NoLogo suppresses
    # the Microsoft copyright banner; the "Install latest PowerShell" nag
    # is handled inside launch-template.ps1 via POWERSHELL_UPDATECHECK.
    $wtExe = Get-Command "wt.exe" -ErrorAction SilentlyContinue
    if ($wtExe) {
        Start-Process "wt.exe" `
            -ArgumentList "-d", "`"$($config.project_path)`"", "powershell.exe", "-ExecutionPolicy", "Bypass", "-NoExit", "-NoLogo", "-File", "`"$launchScript`""
    } else {
        Start-Process "powershell.exe" `
            -ArgumentList "-ExecutionPolicy", "Bypass", "-NoExit", "-NoLogo", "-File", $launchScript `
            -WorkingDirectory $config.project_path
    }
    return $true
}

function Step-Update {
    Write-Host ""
    Write-Host "  Downloading latest DSM files from GitHub..." -ForegroundColor Cyan
    Write-Host ""

    # Files that need refreshing on update. Each entry: url suffix, destination.
    # Destinations use $VAULT_DIR and Get-Config->project_path where needed.
    $config = Get-Config
    $projectPath = if ($config -and $config.project_path) { $config.project_path } else { $null }

    $updateFiles = @(
        @{ src = "DomitekLaunch.ps1";        dst = "$VAULT_DIR\DomitekLaunch.ps1";       hide = $false }
        @{ src = "DomitekLaunch.bat";        dst = "$VAULT_DIR\DomitekLaunch.bat";       hide = $false }
        @{ src = "DomitekLaunch.ico";        dst = "$VAULT_DIR\DomitekLaunch.ico";       hide = $false }
        @{ src = "remove-dsm.ps1";           dst = "$VAULT_DIR\remove-dsm.ps1";          hide = $false }
        @{ src = "logo_base64.txt";          dst = "$VAULT_DIR\logo_base64.txt";         hide = $true  }
        @{ src = "template/launch-template.ps1"; dst = "$VAULT_DIR\launch-template.ps1"; hide = $false }
    )

    # Also refresh the setup guide in the user's project folder if we know it
    if ($projectPath) {
        $updateFiles += @{ src = "domitek-setup-guide.md"; dst = "$projectPath\domitek-setup-guide.md"; hide = $false }
    }

    $successCount = 0
    $failCount    = 0
    foreach ($f in $updateFiles) {
        $url = "$UPDATE_BASE_URL/$($f.src)"
        try {
            # If destination is Hidden, clear the attribute before overwrite
            # so Invoke-WebRequest + file write does not fail.
            if (Test-Path $f.dst) {
                try {
                    $item = Get-Item $f.dst -Force
                    if ($item.Attributes -band [System.IO.FileAttributes]::Hidden) {
                        $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
                    }
                } catch {}
            }
            Invoke-WebRequest -Uri $url -OutFile $f.dst -UseBasicParsing
            Unblock-File -Path $f.dst -ErrorAction SilentlyContinue
            # Re-apply Hidden if this file is internal
            if ($f.hide) {
                try {
                    $item = Get-Item $f.dst -Force
                    $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
                } catch {}
            }
            Write-Host "  [OK]   $($f.src)" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host "  [WARN] $($f.src) -- $($_.Exception.Message)" -ForegroundColor Yellow
            $failCount++
        }
    }

    # Refresh the GUI installer last (runs the installer which rewrites the GUI)
    Write-Host ""
    Write-Host "  Updating Secrets Manager GUI..." -ForegroundColor Cyan
    try {
        $installerUrl = "$UPDATE_BASE_URL/Install-SecretsManager-v1.5.ps1"
        Invoke-WebRequest -Uri $installerUrl -OutFile $INSTALLER_TMP -UseBasicParsing
        Unblock-File -Path $INSTALLER_TMP
        & $INSTALLER_TMP
        # Verify the GUI file actually exists post-install
        if (Test-Path $TOOL_PATH) {
            Write-Host "  [OK]   Secrets Manager GUI refreshed" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  [WARN] GUI installer ran but $TOOL_PATH was not created" -ForegroundColor Yellow
            $failCount++
        }
    } catch {
        Write-Host "  [WARN] GUI installer failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $failCount++
    }

    Write-Host ""
    if ($failCount -eq 0) {
        Write-Host "  [OK] Update complete ($successCount files refreshed)." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Relaunching with updated version in 2 seconds..." -ForegroundColor Cyan
        Start-Sleep -Seconds 2

        # Spawn a new DomitekLaunch.ps1 process so the user sees the
        # refreshed version without having to restart manually. The
        # NEW process loads the NEW code from disk. This process
        # (running the OLD in-memory DomitekLaunch) exits cleanly.
        # No -NoExit: the Read-Host loop already keeps PowerShell alive
        # while waiting for input, and -NoExit caused the menu window
        # to stay open after user picks an option that returns true.
        Start-Process "powershell.exe" `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$VAULT_DIR\DomitekLaunch.ps1`"" `
            -WorkingDirectory $VAULT_DIR

        return $true
    } else {
        Write-Host "  [PARTIAL] $successCount refreshed, $failCount failed." -ForegroundColor Yellow
        Write-Host "  Check your internet connection and try again." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Review the [WARN] messages above. When ready, close this window" -ForegroundColor Yellow
        Write-Host "  and re-open Domitek Launch from your desktop." -ForegroundColor Yellow
        return $false
    }
}

function Step-ViewVault {
    Write-Host ""
    Write-Host "  Opening Windows Credential Manager..." -ForegroundColor Blue
    Start-Process "rundll32.exe" -ArgumentList "keymgr.dll, KRShowKeyMgr"
    Write-Host "  [OK] Look for your project credentials in the vault." -ForegroundColor Green
}

function Step-RemoveDSM {
    if (-not (Test-Path $REMOVE_SCRIPT)) {
        Write-Host "  [ERROR] remove-dsm.ps1 not found at: $REMOVE_SCRIPT" -ForegroundColor Red
        Write-Host "  Run option [3] Update Tool to reinstall it, or download manually:" -ForegroundColor Yellow
        Write-Host "    https://raw.githubusercontent.com/LBu3n0/domitek-secrets-manager-public/main/remove-dsm.ps1" -ForegroundColor Gray
        return $false
    }
    # Copy remove-dsm to %TEMP% (it will delete C:\DomitekVault)
    # Launch it in a NEW powershell window, then exit THIS menu
    # so DomitekLaunch.ps1 stops holding C:\DomitekVault open.
    $tempCopy = "$env:TEMP\remove-dsm.ps1"
    try {
        Copy-Item $REMOVE_SCRIPT $tempCopy -Force
        Unblock-File $tempCopy
        Write-Host ""
        Write-Host "  Launching uninstaller in a new window..." -ForegroundColor Cyan
        Write-Host "  This menu will close." -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
        Start-Process "powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempCopy`""
        # Exit THIS launch menu so the DomitekLaunch.ps1 process releases C:\DomitekVault
        return $true
    } catch {
        Write-Host "  [ERROR] Could not run remove-dsm.ps1: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Step-DevReset {
    $script = Find-FirstPath $DEV_RESET_PATHS
    if ($null -eq $script) {
        Write-Host "  [ERROR] dsm-reset.ps1 not found. Searched:" -ForegroundColor Red
        $DEV_RESET_PATHS | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        return $false
    }
    Run-DevScript $script "Dev Reset"
    return $true
}

function Step-CleanWipe {
    $script = Find-FirstPath $CLEAN_WIPE_PATHS
    if ($null -eq $script) {
        Write-Host "  [ERROR] clean-wipe.ps1 not found. Searched:" -ForegroundColor Red
        $CLEAN_WIPE_PATHS | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        return $false
    }
    Run-DevScript $script "Clean Wipe"
    return $true
}

function Pause-Menu {
    Write-Host ""
    Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# =============================================================
# Main loop
# =============================================================
$running = $true
while ($running) {
    Show-Menu
    $devMode = Test-DevMode
    $choice = Read-Host "  Select an option"

    switch ($choice.ToUpper()) {
        "1" {
            if (Step-LaunchTool) { $running = $false }
            else { Pause-Menu }
        }
        "2" {
            if (Step-LaunchClaude) { $running = $false }
            else { Pause-Menu }
        }
        "3" {
            if (Step-Update) { $running = $false }
            else { Pause-Menu }
        }
        "4" { Step-ViewVault; Pause-Menu }
        "5" {
            if (Step-RemoveDSM) { $running = $false }
            else { Pause-Menu }
        }
        "6" {
            if ($devMode) {
                if (Step-DevReset) { $running = $false } else { Pause-Menu }
            } else {
                Write-Host "  Invalid option." -ForegroundColor Yellow
                Pause-Menu
            }
        }
        "7" {
            if ($devMode) {
                if (Step-CleanWipe) { $running = $false } else { Pause-Menu }
            } else {
                Write-Host "  Invalid option." -ForegroundColor Yellow
                Pause-Menu
            }
        }
        "Q" {
            Write-Host "  Goodbye." -ForegroundColor DarkGray
            $running = $false
        }
        default {
            Write-Host "  Invalid option." -ForegroundColor Yellow
            Pause-Menu
        }
    }
}
