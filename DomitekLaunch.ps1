[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$VAULT_DIR       = "C:\DomitekVault"
$TOOL_PATH       = "$VAULT_DIR\Domitek-Secrets-Manager.ps1"
$CONFIG_PATH     = "$VAULT_DIR\config.json"
$REMOVE_SCRIPT   = "$VAULT_DIR\remove-dsm.ps1"
$DEV_FLAG        = "$VAULT_DIR\.dev-mode"
$UPDATE_URL      = "https://raw.githubusercontent.com/LBU3N0/domitek-secrets-manager/main/Install-SecretsManager-v1.5.ps1"
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
    Write-Host "  [2]  Launch Claude Code" -ForegroundColor Cyan
    Write-Host "       Injects vault secrets and starts Claude Code" -ForegroundColor DarkGray
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
        Write-Host "  [ERROR] launch-claude.ps1 not found at: $launchScript" -ForegroundColor Red
        Write-Host "  Open Secrets Manager and click Store to Vault to regenerate it." -ForegroundColor Yellow
        return $false
    }
    Write-Host "  Loading vault secrets and starting Claude Code..." -ForegroundColor Cyan
    Start-Process "powershell.exe" `
        -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$launchScript`"" `
        -WorkingDirectory $config.project_path
    return $true
}

function Step-Update {
    Write-Host ""
    Write-Host "  Downloading latest installer from GitHub..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $UPDATE_URL -OutFile $INSTALLER_TMP -UseBasicParsing
        Unblock-File -Path $INSTALLER_TMP
        Write-Host "  Running installer..." -ForegroundColor Cyan
        & $INSTALLER_TMP
        Write-Host "  [OK] Tool updated successfully." -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Update failed: $_" -ForegroundColor Red
        Write-Host "  Check your internet connection and try again." -ForegroundColor Yellow
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
        Write-Host "    https://raw.githubusercontent.com/LBU3N0/domitek-secrets-manager/main/remove-dsm.ps1" -ForegroundColor Gray
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
        "3" { Step-Update; Pause-Menu }
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
