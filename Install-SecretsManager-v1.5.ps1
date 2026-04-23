# =============================================================
# Domitek Secrets Manager -- Installer v1.5
# =============================================================
# Copyright (c) 2026 Domitek. All rights reserved.
# scan.domitek.ai
#
# This script installs the Domitek Secrets Manager GUI to
# C:\DomitekVault on Windows 10/11.
#
# USAGE:
#   .\Install-SecretsManager-v1.5.ps1
#
# New in v1.5:
#   - Domitek logo in header (embedded)
#   - Key rotation reminders (30/90/180/Never)
#   - Days-remaining counter per key
#   - Wider form (620px) with rotation column
#   - Copyright notices
# =============================================================

$LOGO_BASE64 = Get-Content "C:\DomitekVault\logo_base64.txt" -Raw -ErrorAction SilentlyContinue

$app = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$VERSION        = "v1.5"
$HISTORY_FILE   = "$env:APPDATA\DomitekVault\project_history.json"
$ROTATION_FILE  = "C:\DomitekVault\rotation.json"
$LOGO_FILE      = "C:\DomitekVault\logo_base64.txt"
$CONFIG_FILE    = "C:\DomitekVault\config.json"
$MAX_HISTORY    = 5
$FORM_WIDTH     = 620

# Load logo at runtime
$LOGO_BASE64_EMBEDDED = $null
if (Test-Path $LOGO_FILE) {
    try { $LOGO_BASE64_EMBEDDED = (Get-Content $LOGO_FILE -Raw).Trim() } catch {}
}

$secretRows  = [System.Collections.ArrayList]@()
$rowHeight   = 32
$currentY    = 5

# -- Rotation helpers -----------------------------------------------
function Load-Rotation {
    if (Test-Path $ROTATION_FILE) {
        try {
            $raw = Get-Content $ROTATION_FILE -Raw
            $parsed = $raw | ConvertFrom-Json
            if ($null -ne $parsed) {
                $ht = @{}
                $parsed.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
                return $ht
            }
        } catch {}
    }
    return @{}
}

function Save-Rotation {
    param($projectName, $keyName, $days)
    $rot = Load-Rotation
    if ($days -eq "Never") {
        $rot["${projectName}_${keyName}"] = "Never"
    } else {
        $expiry = (Get-Date).AddDays([int]$days).ToString("yyyy-MM-dd")
        $rot["${projectName}_${keyName}"] = $expiry
    }

    # Write with Hidden-attribute clear-before-overwrite pattern.
    # rotation.json is an internal state file -- hide it from casual
    # File Explorer browsing so users don't delete by mistake.
    # Out-File refuses to overwrite a Hidden file, so we must clear
    # the attribute before write and re-apply after. Same pattern
    # as PRD 8.10 for .domitek-secrets.md.
    if (Test-Path $ROTATION_FILE) {
        try {
            $attrs = (Get-Item $ROTATION_FILE -Force).Attributes
            if ($attrs -band [System.IO.FileAttributes]::Hidden) {
                (Get-Item $ROTATION_FILE -Force).Attributes = $attrs -band (-bnot [System.IO.FileAttributes]::Hidden)
            }
        } catch {}
    }
    $rot | ConvertTo-Json | Out-File $ROTATION_FILE -Encoding UTF8
    try {
        $item = Get-Item $ROTATION_FILE -Force
        $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
    } catch {}
}

function Get-DaysRemaining {
    param($projectName, $keyName)
    $rot = Load-Rotation
    $entry = $rot["${projectName}_${keyName}"]
    if ($null -eq $entry) { return $null }
    if ($entry -eq "Never") { return 9999 }
    $expiry = [datetime]::ParseExact($entry, "yyyy-MM-dd", $null)
    return [int]($expiry - (Get-Date)).TotalDays
}

function Get-RotationColor {
    param($days)
    if ($null -eq $days) { return [System.Drawing.Color]::Gray }
    if ($days -gt 30)    { return [System.Drawing.Color]::FromArgb(0, 150, 80) }
    if ($days -gt 0)     { return [System.Drawing.Color]::FromArgb(200, 140, 0) }
    return [System.Drawing.Color]::FromArgb(200, 40, 40)
}

# -- History helpers ------------------------------------------------
function Load-History {
    if (Test-Path $HISTORY_FILE) {
        try {
            $raw = Get-Content $HISTORY_FILE -Raw
            $parsed = $raw | ConvertFrom-Json
            if ($null -eq $parsed) { return [System.Collections.ArrayList]@() }
            return [System.Collections.ArrayList]@($parsed)
        } catch {}
    }
    return [System.Collections.ArrayList]@()
}

function Save-History {
    param($projName)
    if ([string]::IsNullOrWhiteSpace($projName)) { return }
    $h = [System.Collections.ArrayList]@()
    $existing = Load-History
    if ($null -ne $existing) {
        foreach ($item in $existing) {
            if (-not [string]::IsNullOrWhiteSpace($item)) { $h.Add($item) | Out-Null }
        }
    }
    if ($h -contains $projName) { $h.Remove($projName) | Out-Null }
    $h.Insert(0, $projName) | Out-Null
    while ($h.Count -gt $MAX_HISTORY) { $h.RemoveAt($h.Count - 1) }
    $dir = Split-Path $HISTORY_FILE
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $h | ConvertTo-Json | Out-File $HISTORY_FILE -Encoding UTF8
}

function Save-Config {
    # Writes C:\DomitekVault\config.json with the current project.
    # Called after Store to Vault + Generate Script so DomitekLaunch.ps1
    # (and any other code that reads config.json) knows which project
    # the user is currently working on.
    #
    # Preserves the Hidden attribute if config.json was already hidden
    # (see setup.ps1 Set-FileHidden helper from earlier today).
    param($projName, $projPath)
    $cfg = [ordered]@{
        project_path = $projPath
        project_name = $projName
    }
    try {
        # If file exists and is Hidden, clear the attribute before write
        # so Out-File does not fail.
        $wasHidden = $false
        if (Test-Path $CONFIG_FILE) {
            $item = Get-Item $CONFIG_FILE -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::Hidden) {
                $wasHidden = $true
                $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
            }
        }
        $cfg | ConvertTo-Json | Out-File $CONFIG_FILE -Encoding UTF8
        # Re-apply Hidden if it was set
        if ($wasHidden) {
            $item = Get-Item $CONFIG_FILE -Force
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
        }
        return $true
    } catch {
        return $false
    }
}

function Refresh-History {
    $cboHistory.Items.Clear()
    $h = Load-History
    if ($null -ne $h) {
        foreach ($item in $h) {
            if (-not [string]::IsNullOrWhiteSpace($item)) { $cboHistory.Items.Add($item) | Out-Null }
        }
    }
}

function Load-VaultKeys {
    param($projName)
    if ([string]::IsNullOrWhiteSpace($projName)) { return }
    if ([System.IO.Path]::IsPathRooted($projName) -and (Test-Path $projName)) {
        $projName = Split-Path $projName -Leaf
    }
    $vaultLines = cmdkey /list 2>$null
    $keys = $vaultLines | Select-String "target=" | ForEach-Object {
        $t = ($_ -replace ".*target=", "" -replace "\s.*", "").Trim()
        if ($t -like "${projName}_*") { $t -replace "^${projName}_", "" }
    } | Where-Object { $_ }
    if ($keys.Count -gt 0) {
        Clear-SecretRows
        $rot = Load-Rotation
        foreach ($k in $keys) {
            $entry = $rot["${projName}_${k}"]
            $rotDays = "90"
            if ($null -ne $entry) {
                if ($entry -eq "Never") {
                    $rotDays = "Never"
                } else {
                    try {
                        $expiry = [datetime]::ParseExact($entry, "yyyy-MM-dd", $null)
                        $stored = [int]($expiry - (Get-Date)).TotalDays
                        # Work backwards to find original period
                        if ($stored -le 35)     { $rotDays = "30" }
                        elseif ($stored -le 100) { $rotDays = "90" }
                        else                     { $rotDays = "180" }
                    } catch { $rotDays = "90" }
                }
            }
            Add-SecretRow $k $rotDays
        }
        Set-Status "Loaded $($keys.Count) key(s) from vault for: $projName" ([System.Drawing.Color]::FromArgb(0, 100, 180))
    }
}

function Refresh-EnvPath {
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH","User")
}

function Find-IDEPath {
    param($cmdName, $fallbackPaths)
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($fp in $fallbackPaths) {
        if (Test-Path $fp) { return $fp }
    }
    return $null
}

$VSCodeFallbacks = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
)
$CursorFallbacks = @(
    "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd",
    "$env:LOCALAPPDATA\Programs\Cursor\resources\app\bin\cursor.cmd"
)
$projectTypes = @{
    "Claude Code Assistant"   = @("SUPABASE_URL","SUPABASE_ANON_KEY","N8N_WEBHOOK_SECRET","ELEVENLABS_API_KEY")
    "Claude Code Application" = @("ANTHROPIC_API_KEY","SUPABASE_URL","SUPABASE_ANON_KEY","ELEVENLABS_API_KEY")
}

function Clear-SecretRows {
    $pnlSecrets.Controls.Clear()
    $secretRows.Clear()
    $script:currentY = 5
}

function Start-InClaudeTerminal {
    # Launches launch-claude.ps1 in a clean terminal window.
    # Prefers Windows Terminal (wt.exe) because it defaults to a dark
    # theme and matches the look users get from the desktop shortcut.
    # Falls back to powershell.exe in conhost if wt.exe is missing.
    #
    # Either way we pass -NoLogo to suppress the Microsoft copyright
    # banner. The "Install the latest PowerShell" nag is handled inside
    # launch-template.ps1 via POWERSHELL_UPDATECHECK.
    param($launchScript, $projectPath)

    $wtExe = Get-Command "wt.exe" -ErrorAction SilentlyContinue
    if ($wtExe) {
        # wt.exe: -d sets starting directory, then nested powershell.exe args
        Start-Process "wt.exe" `
            -ArgumentList "-d", "`"$projectPath`"", "powershell.exe", "-ExecutionPolicy", "Bypass", "-NoExit", "-NoLogo", "-File", "`"$launchScript`""
    } else {
        # Fallback: plain powershell.exe (will appear in conhost, blue)
        Start-Process "powershell.exe" `
            -ArgumentList "-NoExit", "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", $launchScript `
            -WorkingDirectory $projectPath
    }
}

function Add-SecretRow {
    param($defaultName = "", $rotationDays = "90")
    $txtName             = New-Object System.Windows.Forms.TextBox
    $txtName.Font        = New-Object System.Drawing.Font("Segoe UI", 9)
    $txtName.Location    = New-Object System.Drawing.Point(5, $script:currentY)
    $txtName.Size        = New-Object System.Drawing.Size(185, 24)
    $txtName.Text        = $defaultName
    $txtName.BorderStyle = "FixedSingle"

    $txtValue              = New-Object System.Windows.Forms.TextBox
    $txtValue.Font         = New-Object System.Drawing.Font("Segoe UI", 9)
    $txtValue.Location     = New-Object System.Drawing.Point(198, $script:currentY)
    $txtValue.Size         = New-Object System.Drawing.Size(185, 24)
    $txtValue.PasswordChar = [char]0x25CF
    $txtValue.BorderStyle  = "FixedSingle"
    # Fire label refresh whenever the value field changes. The button label
    # at the bottom of the form reads "Generate Script" when all values are
    # empty, "Store to Vault + Generate Script" when any value has content.
    $txtValue.Add_TextChanged({ Update-StoreButtonLabel })

    $cboRotation              = New-Object System.Windows.Forms.ComboBox
    $cboRotation.Font         = New-Object System.Drawing.Font("Segoe UI", 8)
    $cboRotation.Location     = New-Object System.Drawing.Point(391, $script:currentY)
    $cboRotation.Size         = New-Object System.Drawing.Size(90, 24)
    $cboRotation.DropDownStyle= "DropDownList"
    $cboRotation.FlatStyle    = "Flat"
    $cboRotation.Items.AddRange(@("30 days","90 days","180 days","Never"))
    $cboRotation.SelectedItem = switch ($rotationDays) {
        "30"    { "30 days" }
        "180"   { "180 days" }
        "Never" { "Never" }
        default { "90 days" }
    }

    $daysY = $script:currentY + 5
    $lblDays              = New-Object System.Windows.Forms.Label
    $lblDays.Font         = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $lblDays.Location     = New-Object System.Drawing.Point(488, $daysY)
    $lblDays.Size         = New-Object System.Drawing.Size(95, 18)
    $lblDays.Text         = ""
    $lblDays.ForeColor    = [System.Drawing.Color]::Gray

    $pnlSecrets.Controls.AddRange(@($txtName, $txtValue, $cboRotation, $lblDays))
    $secretRows.Add(@{ Name = $txtName; Value = $txtValue; Rotation = $cboRotation; Days = $lblDays }) | Out-Null
    $script:currentY += $script:rowHeight
}

function Update-DaysLabels {
    param($projectName)
    if ([string]::IsNullOrWhiteSpace($projectName)) { return }
    if ([System.IO.Path]::IsPathRooted($projectName) -and (Test-Path $projectName)) {
        $projectName = Split-Path $projectName -Leaf
    }
    foreach ($row in $secretRows) {
        $k = $row.Name.Text.Trim()
        if ([string]::IsNullOrEmpty($k)) { continue }
        $days = Get-DaysRemaining $projectName $k
        if ($null -eq $days) {
            $row.Days.Text = ""
        } elseif ($days -eq 9999) {
            $row.Days.Text = "No expiry"
            $row.Days.ForeColor = [System.Drawing.Color]::Gray
        } elseif ($days -lt 0) {
            $row.Days.Text = "OVERDUE"
            $row.Days.ForeColor = [System.Drawing.Color]::FromArgb(200, 40, 40)
        } else {
            $row.Days.Text = "$days days left"
            $row.Days.ForeColor = Get-RotationColor $days
        }
    }
}

function Load-ProjectType {
    param($typeName)
    Clear-SecretRows
    foreach ($k in $projectTypes[$typeName]) { Add-SecretRow $k }
    if ($typeName -eq "Claude Code Assistant") {
        $lblTypeHint.Text      = "Launches Claude Code using claude.ai Max subscription. No Anthropic API key needed."
        $lblTypeHint.ForeColor = [System.Drawing.Color]::FromArgb(0, 130, 70)
    } else {
        $lblTypeHint.Text      = "Runs your application with Anthropic API billing. Injects API key into app process."
        $lblTypeHint.ForeColor = [System.Drawing.Color]::FromArgb(26, 95, 170)
    }
}

function Set-Status {
    param($text, [System.Drawing.Color]$color)
    $lblStatus.Text      = $text
    $lblStatus.ForeColor = $color
}

# -- Form -----------------------------------------------------------
$form                  = New-Object System.Windows.Forms.Form
$form.Text             = "Domitek Secrets Manager $VERSION"
$form.ClientSize       = New-Object System.Drawing.Size(620, 860)
$form.StartPosition    = "CenterScreen"
$form.FormBorderStyle  = "FixedSingle"
$form.MaximizeBox      = $false
$form.BackColor        = [System.Drawing.Color]::WhiteSmoke

# Set form icon if available
if (-not [string]::IsNullOrEmpty($LOGO_BASE64_EMBEDDED)) {
    try {
        $iconBytes = [Convert]::FromBase64String($ICON_BASE64_EMBEDDED)
        $iconStream = New-Object System.IO.MemoryStream(,$iconBytes)
        $form.Icon = New-Object System.Drawing.Icon($iconStream)
    } catch {}
}

# -- Header ---------------------------------------------------------
$pnlHeader            = New-Object System.Windows.Forms.Panel
$pnlHeader.Size       = New-Object System.Drawing.Size(620, 75)
$pnlHeader.Location   = New-Object System.Drawing.Point(0, 0)
$pnlHeader.BackColor  = [System.Drawing.Color]::FromArgb(30, 30, 50)

# Logo image
if (-not [string]::IsNullOrEmpty($LOGO_BASE64_EMBEDDED)) {
    try {
        $imgBytes  = [Convert]::FromBase64String($LOGO_BASE64_EMBEDDED)
        $imgStream = New-Object System.IO.MemoryStream(,$imgBytes)
        $bitmap    = New-Object System.Drawing.Bitmap($imgStream)
        $picLogo              = New-Object System.Windows.Forms.PictureBox
        $picLogo.Image        = $bitmap
        $picLogo.SizeMode     = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picLogo.Location     = New-Object System.Drawing.Point(10, 5)
        $picLogo.Size         = New-Object System.Drawing.Size(200, 65)
        $picLogo.BackColor    = [System.Drawing.Color]::Transparent
        $pnlHeader.Controls.Add($picLogo)
    } catch {
        # Fall back to text title if logo fails
        $lblTitle             = New-Object System.Windows.Forms.Label
        $lblTitle.Text        = "Domitek Secrets Manager"
        $lblTitle.Font        = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor   = [System.Drawing.Color]::White
        $lblTitle.Location    = New-Object System.Drawing.Point(15, 8)
        $lblTitle.Size        = New-Object System.Drawing.Size(340, 26)
        $pnlHeader.Controls.Add($lblTitle)
    }
} else {
    $lblTitle             = New-Object System.Windows.Forms.Label
    $lblTitle.Text        = "Domitek Secrets Manager"
    $lblTitle.Font        = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor   = [System.Drawing.Color]::White
    $lblTitle.Location    = New-Object System.Drawing.Point(15, 8)
    $lblTitle.Size        = New-Object System.Drawing.Size(340, 26)
    $pnlHeader.Controls.Add($lblTitle)
}

$lblVersion           = New-Object System.Windows.Forms.Label
$lblVersion.Text      = $VERSION
$lblVersion.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblVersion.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 160)
$lblVersion.Location  = New-Object System.Drawing.Point(545, 10)
$lblVersion.Size      = New-Object System.Drawing.Size(60, 18)
$lblVersion.TextAlign = "MiddleRight"

$lblSub               = New-Object System.Windows.Forms.Label
$lblSub.Text          = "Securely store credentials in Windows Credential Manager"
$lblSub.Font          = New-Object System.Drawing.Font("Segoe UI", 8)
$lblSub.ForeColor     = [System.Drawing.Color]::FromArgb(160, 160, 200)
$lblSub.Location      = New-Object System.Drawing.Point(215, 45)
$lblSub.Size          = New-Object System.Drawing.Size(390, 18)

$pnlHeader.Controls.AddRange(@($lblVersion, $lblSub))

# -- Project Name + Browse ------------------------------------------
$lblProj          = New-Object System.Windows.Forms.Label
$lblProj.Text     = "Project Name"
$lblProj.Font     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblProj.Location = New-Object System.Drawing.Point(15, 88)
$lblProj.Size     = New-Object System.Drawing.Size(580, 18)

$txtProject           = New-Object System.Windows.Forms.TextBox
$txtProject.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$txtProject.Location  = New-Object System.Drawing.Point(15, 108)
$txtProject.Size      = New-Object System.Drawing.Size(490, 26)
$txtProject.BorderStyle = "FixedSingle"

$btnBrowse            = New-Object System.Windows.Forms.Button
$btnBrowse.Text       = "Browse..."
$btnBrowse.Font       = New-Object System.Drawing.Font("Segoe UI", 9)
$btnBrowse.Location   = New-Object System.Drawing.Point(515, 107)
$btnBrowse.Size       = New-Object System.Drawing.Size(88, 28)
$btnBrowse.FlatStyle  = "Flat"
$btnBrowse.BackColor  = [System.Drawing.Color]::White
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description         = "Select your project folder"
    $dlg.ShowNewFolderButton = $false
    $startPath = $PWD.Path
    if (-not [string]::IsNullOrWhiteSpace($txtProject.Text) -and (Test-Path $txtProject.Text)) {
        $startPath = $txtProject.Text
    }
    $dlg.SelectedPath = $startPath
    if ($dlg.ShowDialog() -eq "OK") {
        $txtProject.Text = $dlg.SelectedPath
        $cleanName = Split-Path $dlg.SelectedPath -Leaf
        Save-History $dlg.SelectedPath
        Refresh-History
        Load-VaultKeys $dlg.SelectedPath
        Update-DaysLabels $dlg.SelectedPath
        Set-Status "Folder selected. Vault keys will use prefix: ${cleanName}_KEYNAME" ([System.Drawing.Color]::FromArgb(0, 100, 180))
    }
})

$lblProjHint          = New-Object System.Windows.Forms.Label
$lblProjHint.Text     = "Type a name (e.g. envproject) or browse to your project folder"
$lblProjHint.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$lblProjHint.ForeColor= [System.Drawing.Color]::Gray
$lblProjHint.Location = New-Object System.Drawing.Point(15, 137)
$lblProjHint.Size     = New-Object System.Drawing.Size(580, 16)

# -- Recent Projects ------------------------------------------------
$lblRecent            = New-Object System.Windows.Forms.Label
$lblRecent.Text       = "Recent projects"
$lblRecent.Font       = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblRecent.ForeColor  = [System.Drawing.Color]::Gray
$lblRecent.Location   = New-Object System.Drawing.Point(15, 158)
$lblRecent.Size       = New-Object System.Drawing.Size(120, 16)

$cboHistory               = New-Object System.Windows.Forms.ComboBox
$cboHistory.Font          = New-Object System.Drawing.Font("Segoe UI", 9)
$cboHistory.Location      = New-Object System.Drawing.Point(15, 176)
$cboHistory.Size          = New-Object System.Drawing.Size(588, 24)
$cboHistory.DropDownStyle = "DropDownList"
$cboHistory.FlatStyle     = "Flat"
$cboHistory.Add_SelectedIndexChanged({
    if ($cboHistory.SelectedItem) {
        $txtProject.Text = $cboHistory.SelectedItem.ToString()
        Load-VaultKeys $cboHistory.SelectedItem.ToString()
        Update-DaysLabels $cboHistory.SelectedItem.ToString()
    }
})

# -- Project Type ---------------------------------------------------
$lblType          = New-Object System.Windows.Forms.Label
$lblType.Text     = "Project Type"
$lblType.Font     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblType.Location = New-Object System.Drawing.Point(15, 210)
$lblType.Size     = New-Object System.Drawing.Size(580, 18)

$cboType              = New-Object System.Windows.Forms.ComboBox
$cboType.Font         = New-Object System.Drawing.Font("Segoe UI", 10)
$cboType.Location     = New-Object System.Drawing.Point(15, 230)
$cboType.Size         = New-Object System.Drawing.Size(588, 26)
$cboType.DropDownStyle= "DropDownList"
$cboType.FlatStyle    = "Flat"
$cboType.Items.AddRange(@("Claude Code Assistant", "Claude Code Application"))
$cboType.SelectedIndex = 0
$cboType.Add_SelectedIndexChanged({ Load-ProjectType $cboType.SelectedItem })

$lblTypeHint          = New-Object System.Windows.Forms.Label
$lblTypeHint.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$lblTypeHint.Location = New-Object System.Drawing.Point(15, 260)
$lblTypeHint.Size     = New-Object System.Drawing.Size(588, 32)
$lblTypeHint.AutoSize = $false

# -- Secrets Panel --------------------------------------------------
$lblSecrets          = New-Object System.Windows.Forms.Label
$lblSecrets.Text     = "Secrets"
$lblSecrets.Font     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblSecrets.Location = New-Object System.Drawing.Point(15, 300)
$lblSecrets.Size     = New-Object System.Drawing.Size(100, 18)

$lblColKey           = New-Object System.Windows.Forms.Label
$lblColKey.Text      = "KEY NAME"
$lblColKey.Font      = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$lblColKey.ForeColor = [System.Drawing.Color]::Gray
$lblColKey.Location  = New-Object System.Drawing.Point(20, 322)
$lblColKey.Size      = New-Object System.Drawing.Size(180, 14)

$lblColVal           = New-Object System.Windows.Forms.Label
$lblColVal.Text      = "SECRET VALUE"
$lblColVal.Font      = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$lblColVal.ForeColor = [System.Drawing.Color]::Gray
$lblColVal.Location  = New-Object System.Drawing.Point(210, 322)
$lblColVal.Size      = New-Object System.Drawing.Size(175, 14)

$lblColRot           = New-Object System.Windows.Forms.Label
$lblColRot.Text      = "ROTATE"
$lblColRot.Font      = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$lblColRot.ForeColor = [System.Drawing.Color]::Gray
$lblColRot.Location  = New-Object System.Drawing.Point(398, 322)
$lblColRot.Size      = New-Object System.Drawing.Size(80, 14)

$lblColDays          = New-Object System.Windows.Forms.Label
$lblColDays.Text     = "STATUS"
$lblColDays.Font     = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$lblColDays.ForeColor = [System.Drawing.Color]::Gray
$lblColDays.Location  = New-Object System.Drawing.Point(488, 322)
$lblColDays.Size      = New-Object System.Drawing.Size(100, 14)

$pnlSecrets              = New-Object System.Windows.Forms.Panel
$pnlSecrets.Location     = New-Object System.Drawing.Point(15, 338)
$pnlSecrets.Size         = New-Object System.Drawing.Size(588, 190)
$pnlSecrets.AutoScroll   = $true
$pnlSecrets.BorderStyle  = "FixedSingle"
$pnlSecrets.BackColor    = [System.Drawing.Color]::White

Load-ProjectType "Claude Code Assistant"

# -- Action Buttons -------------------------------------------------
$btnAdd           = New-Object System.Windows.Forms.Button
$btnAdd.Text      = "+ Add Secret"
$btnAdd.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$btnAdd.Location  = New-Object System.Drawing.Point(15, 538)
$btnAdd.Size      = New-Object System.Drawing.Size(120, 28)
$btnAdd.FlatStyle = "Flat"
$btnAdd.BackColor = [System.Drawing.Color]::White
$btnAdd.Add_Click({ Add-SecretRow "" })

$btnClear           = New-Object System.Windows.Forms.Button
$btnClear.Text      = "Clear Values"
$btnClear.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$btnClear.Location  = New-Object System.Drawing.Point(148, 538)
$btnClear.Size      = New-Object System.Drawing.Size(110, 28)
$btnClear.FlatStyle = "Flat"
$btnClear.BackColor = [System.Drawing.Color]::White
$btnClear.Add_Click({
    foreach ($row in $secretRows) {
        $row.Name.Text  = ""
        $row.Value.Text = ""
    }
    Set-Status "All fields cleared." ([System.Drawing.Color]::Gray)
})

$btnViewVault           = New-Object System.Windows.Forms.Button
$btnViewVault.Text      = "View Vault"
$btnViewVault.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$btnViewVault.Location  = New-Object System.Drawing.Point(267, 538)
$btnViewVault.Size      = New-Object System.Drawing.Size(100, 28)
$btnViewVault.FlatStyle = "Flat"
$btnViewVault.BackColor = [System.Drawing.Color]::FromArgb(20, 80, 140)
$btnViewVault.ForeColor = [System.Drawing.Color]::White
$btnViewVault.Add_Click({
    Start-Process "rundll32.exe" -ArgumentList "keymgr.dll, KRShowKeyMgr"
    Set-Status "Windows Credential Manager opened." ([System.Drawing.Color]::FromArgb(20, 80, 140))
})

# -- Divider --------------------------------------------------------
$lblDivider           = New-Object System.Windows.Forms.Label
$lblDivider.Text      = ""
$lblDivider.BorderStyle = "Fixed3D"
$lblDivider.Location  = New-Object System.Drawing.Point(15, 576)
$lblDivider.Size      = New-Object System.Drawing.Size(588, 2)

# -- Store + Close --------------------------------------------------
$btnStore           = New-Object System.Windows.Forms.Button
$btnStore.Text      = "Store to Vault + Generate Script"
$btnStore.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnStore.Location  = New-Object System.Drawing.Point(15, 588)
$btnStore.Size      = New-Object System.Drawing.Size(470, 36)
$btnStore.FlatStyle = "Flat"
$btnStore.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)
$btnStore.ForeColor = [System.Drawing.Color]::White
$btnStore.Add_Click({
    $projectName = $txtProject.Text.Trim()
    if ([string]::IsNullOrEmpty($projectName)) {
        Set-Status "ERROR: Please enter a project name first." ([System.Drawing.Color]::Red)
        return
    }

    $projectPath = $null
    if ([System.IO.Path]::IsPathRooted($projectName)) {
        # Rooted path: user typed or browsed to a specific folder.
        # Create it if missing so we respect the user's stated intent
        # instead of silently falling through to the browse dialog.
        if (-not (Test-Path $projectName)) {
            try {
                New-Item -ItemType Directory -Path $projectName -Force -ErrorAction Stop | Out-Null
            } catch {
                Set-Status "ERROR: Could not create project folder: $($_.Exception.Message)" ([System.Drawing.Color]::Red)
                return
            }
        }
        $projectPath = $projectName
        $projectName = Split-Path $projectName -Leaf
    } elseif (Test-Path "C:\Vault\$projectName") {
        # Short-name legacy path: C:\Vault\<name> exists.
        $projectPath = "C:\Vault\$projectName"
    }
    # If still null, the folder-browser dialog below handles it.

    $stored  = 0
    $skipped = 0
    $keys    = @()
    $nextPublicKeys = @()

    foreach ($row in $secretRows) {
        $k = $row.Name.Text.Trim()
        $v = $row.Value.Text.Trim()
        $rotSel = $row.Rotation.SelectedItem
        $rotDays = if ($rotSel -eq "Never") { "Never" } else { $rotSel -replace " days","" }

        if (-not [string]::IsNullOrEmpty($k)) { $keys += $k }

        # Skip rows that are missing key name OR value -- nothing to store.
        if ([string]::IsNullOrEmpty($k) -or [string]::IsNullOrEmpty($v)) { $skipped++; continue }

        New-StoredCredential -Target "${projectName}_${k}" -UserName "domitek" -Password $v -Persist LocalMachine | Out-Null
        # Rotation timestamp ONLY advances when a value was actually stored.
        # Previously this ran whenever a key name existed, which caused "89 days left"
        # to appear even on Store clicks with all values empty.
        Save-Rotation $projectName $k $rotDays
        $row.Value.Text = ""
        $stored++
        if ($k -match "URL|ANON|WEBHOOK_URL|WEBHOOK_SECRET") { $nextPublicKeys += $k }
    }

    Save-History $txtProject.Text.Trim()
    Refresh-History
    Update-DaysLabels $projectName

    # Zero-keys projects ARE valid -- user may be using claude.ai Max
    # subscription with no API keys and still wants DSM's protection
    # layer (deny rules, CLAUDE.md reminders, no-.env enforcement).
    # So we prompt for a folder and generate launch-claude.ps1 even
    # when there are no keys to store. The generated script handles
    # the zero-keys case gracefully inside launch-template.ps1.
    if ($null -eq $projectPath) {
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Select project folder to save launch-claude.ps1"
        if ($dlg.ShowDialog() -eq "OK") { $projectPath = $dlg.SelectedPath }
    }

    # Distinguish "fresh project with template defaults" from
    # "existing project being regenerated":
    #   Fresh project  -> no stored-this-click, no existing vault keys
    #                    -> treat form rows as template defaults, emit []
    #   Regenerate     -> no stored-this-click, BUT vault already has keys
    #                    -> honor the form-row keys so the launch script
    #                       still knows what to load from the vault
    # Only applies when nothing was stored THIS click. If the user stored
    # anything, $keys already reflects intent.
    if ($stored -eq 0 -and $keys.Count -gt 0) {
        $existingVaultLines = cmdkey /list 2>$null
        $existingKeys = $existingVaultLines | Select-String "target=" | ForEach-Object {
            $t = ($_ -replace ".*target=", "" -replace "\s.*", "").Trim()
            if ($t -like "${projectName}_*") { $t -replace "^${projectName}_", "" }
        } | Where-Object { $_ }
        if ($existingKeys.Count -eq 0) {
            # Fresh project: form rows are template defaults, not user intent.
            $keys = @()
            $nextPublicKeys = @()
        }
    }

    if ($null -ne $projectPath) {
        $nextPub = $nextPublicKeys
        if (Generate-LaunchScript $projectPath $projectName $keys $nextPub) {
            # Update config.json so DomitekLaunch.ps1 menu reflects
            # the project the user just configured. Without this, menu
            # [2] Launch Claude Code would still point to whichever
            # project setup.ps1 originally configured.
            $cfgOK = Save-Config $projectName $projectPath
            # Status message is HONEST about what happened based on
            # actual stored count AND whether any keys exist for this project.
            if ($stored -gt 0) {
                $msg = "Stored $stored secret(s) + generated launch-claude.ps1 in $projectPath"
            } elseif ($keys.Count -gt 0) {
                $msg = "Generated launch-claude.ps1 in $projectPath. No values provided -- vault unchanged."
            } else {
                $msg = "Generated launch-claude.ps1 in $projectPath. Zero-keys project -- Claude Code will launch with protection layer only."
            }
            if ($cfgOK) {
                Set-Status $msg ([System.Drawing.Color]::FromArgb(0, 150, 80))
            } else {
                Set-Status "$msg [WARN] config.json not updated -- menu may still show previous project." ([System.Drawing.Color]::FromArgb(180, 120, 0))
            }
            return
        }
    }

    # Fallback: project path was null AND user cancelled the folder picker.
    if ($stored -gt 0) {
        Set-Status "Stored $stored secret(s) for [$projectName]. Values cleared." ([System.Drawing.Color]::FromArgb(0, 150, 80))
    } else {
        Set-Status "Nothing happened -- select a project folder to generate launch-claude.ps1." ([System.Drawing.Color]::FromArgb(180, 120, 0))
    }
})

$btnClose           = New-Object System.Windows.Forms.Button
$btnClose.Text      = "Close"
$btnClose.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$btnClose.Location  = New-Object System.Drawing.Point(494, 588)
$btnClose.Size      = New-Object System.Drawing.Size(109, 36)
$btnClose.FlatStyle = "Flat"
$btnClose.BackColor = [System.Drawing.Color]::White
$btnClose.Add_Click({ $form.Close() })

function Update-StoreButtonLabel {
    # Scans secret rows; sets button label based on whether any value is populated.
    # Empty values across the board  -> "Generate Script"   (will not touch vault)
    # At least one populated value   -> "Store to Vault + Generate Script"
    # Called on every Value field TextChanged event so the label stays honest
    # about what the click will actually do.
    $hasValue = $false
    foreach ($row in $secretRows) {
        if (-not [string]::IsNullOrWhiteSpace($row.Value.Text)) {
            $hasValue = $true
            break
        }
    }
    if ($hasValue) {
        $btnStore.Text = "Store to Vault + Generate Script"
    } else {
        $btnStore.Text = "Generate Script"
    }
}

function Generate-LaunchScript {
    param($projectPath, $projectName, $keys, $nextPublicKeys)
    $templatePath = "C:\DomitekVault\launch-template.ps1"
    if (-not (Test-Path $templatePath)) {
        Set-Status "launch-template.ps1 not found. Please reinstall." ([System.Drawing.Color]::Red)
        return $false
    }
    $template = Get-Content $templatePath -Raw
    $keysArray = ($keys | ForEach-Object { "    `"$_`"" }) -join ",`n"
    $npArray   = ($nextPublicKeys | ForEach-Object { "    `"$_`"" }) -join ",`n"
    if ([string]::IsNullOrEmpty($npArray)) { $npArray = "" }
    $script = $template -replace "__PROJECT_NAME__", $projectName
    $script = $script -replace "__KEYS__", $keysArray
    $script = $script -replace "__NEXT_PUBLIC_KEYS__", $npArray
    $outputPath = Join-Path $projectPath "launch-claude.ps1"
    $script | Out-File -FilePath $outputPath -Encoding UTF8
    Unblock-File $outputPath
    return $true
}

function Test-AndRegenerate {
    param($projectPath, $projectName)
    $launchScript = Join-Path $projectPath "launch-claude.ps1"
    $needsRegen = $false
    if (-not (Test-Path $launchScript)) {
        $needsRegen = $true
    } else {
        $lc = Get-Content $launchScript -Raw -ErrorAction SilentlyContinue
        if ($null -eq $lc -or $lc -notmatch "Generated by Domitek Secrets Manager v1\.5") {
            $needsRegen = $true
        }
    }
    if (-not $needsRegen) { return $true }
    Set-Status "Updating launch-claude.ps1 from vault..." ([System.Drawing.Color]::FromArgb(0, 100, 180))
    $vaultLines = cmdkey /list 2>$null
    $keys = $vaultLines | Select-String "target=" | ForEach-Object {
        $t = ($_ -replace ".*target=", "" -replace "\s.*", "").Trim()
        if ($t -like "${projectName}_*") { $t -replace "^${projectName}_", "" }
    } | Where-Object { $_ }
    if ($keys.Count -eq 0) {
        # Zero-keys project: still regenerate the script. Claude Code
        # will launch with the protection layer (deny rules, CLAUDE.md
        # reminders) but no vault injection. Warning is visible in the
        # status bar but does NOT block the launch.
        Set-Status "No vault keys for $projectName. Launching with protection layer only." ([System.Drawing.Color]::FromArgb(180, 120, 0))
    }
    $nextPublicKeys = $keys | Where-Object { $_ -match "URL|ANON|WEBHOOK_URL|WEBHOOK_SECRET" }
    if (Generate-LaunchScript $projectPath $projectName $keys $nextPublicKeys) {
        if ($keys.Count -gt 0) {
            Set-Status "launch-claude.ps1 updated to v1.5." ([System.Drawing.Color]::FromArgb(0, 130, 70))
        }
        return $true
    }
    return $false
}

function Get-ProjectPath {
    $input = $txtProject.Text.Trim()
    if ([string]::IsNullOrEmpty($input)) {
        Set-Status "Please enter a project name or browse to a folder." ([System.Drawing.Color]::Red)
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($input) -and (Test-Path $input)) { return $input }
    $projectPath = "C:\Vault\$input"
    if (Test-Path $projectPath) { return $projectPath }
    Set-Status "Project folder not found. Use Browse to select your folder." ([System.Drawing.Color]::Red)
    return $null
}

# -- Launch Buttons -------------------------------------------------
$btnLaunch           = New-Object System.Windows.Forms.Button
$btnLaunch.Text      = "Launch Claude Code"
$btnLaunch.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnLaunch.Location  = New-Object System.Drawing.Point(15, 634)
$btnLaunch.Size      = New-Object System.Drawing.Size(192, 36)
$btnLaunch.FlatStyle = "Flat"
$btnLaunch.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 15)
$btnLaunch.ForeColor = [System.Drawing.Color]::FromArgb(255, 149, 82)
$btnLaunch.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 149, 82)
$btnLaunch.FlatAppearance.BorderSize  = 1
$btnLaunch.Add_Click({
    $projectPath = Get-ProjectPath
    if ($null -eq $projectPath) { return }
    $projName = Split-Path $projectPath -Leaf
    if (-not (Test-AndRegenerate $projectPath $projName)) { return }
    $launchScript = Join-Path $projectPath "launch-claude.ps1"
    $form.Close()
    Start-InClaudeTerminal -launchScript $launchScript -projectPath $projectPath
})

$btnVSCode           = New-Object System.Windows.Forms.Button
$btnVSCode.Text      = "Open in VS Code"
$btnVSCode.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnVSCode.Location  = New-Object System.Drawing.Point(216, 634)
$btnVSCode.Size      = New-Object System.Drawing.Size(131, 36)
$btnVSCode.FlatStyle = "Flat"
$btnVSCode.BackColor = [System.Drawing.Color]::FromArgb(0, 90, 158)
$btnVSCode.ForeColor = [System.Drawing.Color]::White
$btnVSCode.Add_Click({
    $projectPath = Get-ProjectPath
    if ($null -eq $projectPath) { return }
    $projName = Split-Path $projectPath -Leaf
    if (-not (Test-AndRegenerate $projectPath $projName)) { return }
    $launchScript = Join-Path $projectPath "launch-claude.ps1"

    $codeExe = Find-IDEPath "code" $VSCodeFallbacks
    if (-not $codeExe) {
        $result = [System.Windows.Forms.MessageBox]::Show("VS Code is not installed. Would you like to install it now?", "VS Code Not Found", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        Set-Status "Installing VS Code... please wait." ([System.Drawing.Color]::FromArgb(0, 90, 158))
        $btnVSCode.Enabled = $false
        $btnVSCode.Text = "Installing VS Code..."
        [System.Windows.Forms.Application]::DoEvents()

        Start-Process "powershell.exe" -ArgumentList "-Command winget install Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements" -Wait

        Refresh-EnvPath
        $codeExe = Find-IDEPath "code" $VSCodeFallbacks

        $btnVSCode.Enabled = $true
        $btnVSCode.Text = "Open in VS Code"

        if (-not $codeExe) {
            Set-Status "VS Code install finished but not detected. Close DSM and try again." ([System.Drawing.Color]::FromArgb(200, 40, 40))
            return
        }
        Set-Status "VS Code installed. Opening project..." ([System.Drawing.Color]::FromArgb(0, 130, 70))
    } else {
        Set-Status "Secrets injected. VS Code opening -- type 'claude' in the terminal." ([System.Drawing.Color]::FromArgb(0, 90, 158))
    }

    $form.Close()
    & $launchScript -NoLaunch
    Set-Location $projectPath
    & $codeExe .
})

$btnCursor           = New-Object System.Windows.Forms.Button
$btnCursor.Text      = "Open in Cursor"
$btnCursor.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnCursor.Location  = New-Object System.Drawing.Point(356, 634)
$btnCursor.Size      = New-Object System.Drawing.Size(131, 36)
$btnCursor.FlatStyle = "Flat"
$btnCursor.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 60)
$btnCursor.ForeColor = [System.Drawing.Color]::White
$btnCursor.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, 120, 180)
$btnCursor.FlatAppearance.BorderSize  = 1
$btnCursor.Add_Click({
    $projectPath = Get-ProjectPath
    if ($null -eq $projectPath) { return }
    $projName = Split-Path $projectPath -Leaf
    if (-not (Test-AndRegenerate $projectPath $projName)) { return }
    $launchScript = Join-Path $projectPath "launch-claude.ps1"

    $cursorExe = Find-IDEPath "cursor" $CursorFallbacks
    if (-not $cursorExe) {
        $result = [System.Windows.Forms.MessageBox]::Show("Cursor is not installed. Would you like to install it now?", "Cursor Not Found", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        Set-Status "Installing Cursor... please wait." ([System.Drawing.Color]::FromArgb(40, 40, 60))
        $btnCursor.Enabled = $false
        $btnCursor.Text = "Installing Cursor..."
        [System.Windows.Forms.Application]::DoEvents()

        Start-Process "powershell.exe" -ArgumentList "-Command winget install Anysphere.Cursor --silent --accept-package-agreements --accept-source-agreements" -Wait

        Refresh-EnvPath
        $cursorExe = Find-IDEPath "cursor" $CursorFallbacks

        $btnCursor.Enabled = $true
        $btnCursor.Text = "Open in Cursor"

        if (-not $cursorExe) {
            Set-Status "Cursor install finished but not detected. Close DSM and try again." ([System.Drawing.Color]::FromArgb(200, 40, 40))
            return
        }
        Set-Status "Cursor installed. Opening project..." ([System.Drawing.Color]::FromArgb(0, 130, 70))
    } else {
        Set-Status "Secrets injected. Cursor opening -- type 'claude' in the terminal." ([System.Drawing.Color]::FromArgb(40, 40, 60))
    }

    $form.Close()
    & $launchScript -NoLaunch
    Set-Location $projectPath
    & $cursorExe .
})

$btnScanLink           = New-Object System.Windows.Forms.Button
$btnScanLink.Text      = "scan.domitek.ai"
$btnScanLink.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$btnScanLink.Location  = New-Object System.Drawing.Point(496, 634)
$btnScanLink.Size      = New-Object System.Drawing.Size(107, 36)
$btnScanLink.FlatStyle = "Flat"
$btnScanLink.BackColor = [System.Drawing.Color]::WhiteSmoke
$btnScanLink.ForeColor = [System.Drawing.Color]::FromArgb(0, 90, 158)
$btnScanLink.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 90, 158)
$btnScanLink.Add_Click({ Start-Process "https://scan.domitek.ai" })

# -- Protection Toggle ----------------------------------------------
$SETTINGS_PATH = "$env:USERPROFILE\.claude\settings.json"

function Get-ProtectionState {
    if (-not (Test-Path $SETTINGS_PATH)) { return $false }
    $content = Get-Content $SETTINGS_PATH -Raw -ErrorAction SilentlyContinue
    return ($content -match '"Read\(\./\.env\)"')
}

function Update-ProtectionButton {
    $protected = Get-ProtectionState
    if ($protected) {
        $btnProtect.Text      = "Claude Code Protection: ON  (click to disable for demo)"
        $btnProtect.BackColor = [System.Drawing.Color]::FromArgb(20, 100, 60)
        $btnProtect.ForeColor = [System.Drawing.Color]::White
    } else {
        $btnProtect.Text      = "Claude Code Protection: OFF  (click to enable)"
        $btnProtect.BackColor = [System.Drawing.Color]::FromArgb(160, 40, 40)
        $btnProtect.ForeColor = [System.Drawing.Color]::White
    }
}

$btnProtect           = New-Object System.Windows.Forms.Button
$btnProtect.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnProtect.Location  = New-Object System.Drawing.Point(15, 680)
$btnProtect.Size      = New-Object System.Drawing.Size(588, 36)
$btnProtect.FlatStyle = "Flat"
$btnProtect.Add_Click({
    $protected = Get-ProtectionState
    $claudeDir = "$env:USERPROFILE\.claude"
    if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
    if ($protected) {
        $settingsJson = @"
{
  "permissions": {
    "deny": [],
    "allow": [
      "Bash(npm run dev)",
      "Bash(npm test)",
      "Bash(node index.js)",
      "Bash(git status)",
      "Bash(git diff)"
    ]
  }
}
"@
        $settingsJson | Out-File -FilePath $SETTINGS_PATH -Encoding UTF8
        Set-Status "Protection DISABLED. Claude Code can now read .env files (demo mode)." ([System.Drawing.Color]::FromArgb(180, 80, 20))
    } else {
        $settingsJson = @"
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./.env.local)",
      "Read(./.env.production)",
      "Bash(echo `$env:*)",
      "Bash(env)",
      "Bash(printenv)",
      "Bash(set)",
      "Bash(Get-ChildItem env:)",
      "Bash(dir env:)",
      "Bash(* `$env:*)",
      "Bash(* `${*}*)"
    ],
    "allow": [
      "Bash(npm run dev)",
      "Bash(npm test)",
      "Bash(node index.js)",
      "Bash(git status)",
      "Bash(git diff)"
    ]
  }
}
"@
        $settingsJson | Out-File -FilePath $SETTINGS_PATH -Encoding UTF8
        Set-Status "Protection ENABLED. Claude Code is blocked from reading .env files and env vars." ([System.Drawing.Color]::FromArgb(0, 130, 70))
    }
    Update-ProtectionButton
})

# -- Status Label ---------------------------------------------------
$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "Ready - Domitek Secrets Manager v1.5 | scan.domitek.ai"
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$lblStatus.Location  = New-Object System.Drawing.Point(15, 726)
$lblStatus.Size      = New-Object System.Drawing.Size(588, 48)
$lblStatus.AutoSize  = $false
$lblStatus.MaximumSize = New-Object System.Drawing.Size(588, 48)

# -- Copyright Footer -----------------------------------------------
$lblCopyright           = New-Object System.Windows.Forms.Label
$lblCopyright.Text      = "Copyright (c) 2026 Domitek. All rights reserved.  |  Author: Libis R. Bueno  |  scan.domitek.ai"
$lblCopyright.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblCopyright.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$lblCopyright.Location  = New-Object System.Drawing.Point(15, 834)
$lblCopyright.Size      = New-Object System.Drawing.Size(588, 18)
$lblCopyright.TextAlign = "MiddleCenter"

# -- Wire everything up ---------------------------------------------
$form.Controls.AddRange(@(
    $pnlHeader,
    $lblProj, $txtProject, $btnBrowse, $lblProjHint,
    $lblRecent, $cboHistory,
    $lblType, $cboType, $lblTypeHint,
    $lblSecrets, $lblColKey, $lblColVal, $lblColRot, $lblColDays, $pnlSecrets,
    $btnAdd, $btnClear, $btnViewVault,
    $lblDivider,
    $btnStore, $btnClose,
    $btnLaunch, $btnVSCode, $btnCursor, $btnScanLink,
    $btnProtect,
    $lblStatus,
    $lblCopyright
))

Refresh-History
Update-ProtectionButton
Update-StoreButtonLabel
$form.ShowDialog() | Out-Null
'@

$app | Out-File -FilePath "C:\DomitekVault\Domitek-Secrets-Manager.ps1" -Encoding UTF8
Unblock-File -Path "C:\DomitekVault\Domitek-Secrets-Manager.ps1"

# Save logo to DomitekVault if not already there
if (-not (Test-Path "C:\DomitekVault\logo_base64.txt") -and -not [string]::IsNullOrEmpty($LOGO_BASE64)) {
    $LOGO_BASE64 | Out-File "C:\DomitekVault\logo_base64.txt" -Encoding UTF8
}
Write-Host "Domitek Secrets Manager v1.5 saved to C:\DomitekVault" -ForegroundColor Green
Write-Host "Copyright (c) 2026 Domitek. All rights reserved. | Author: Libis R. Bueno" -ForegroundColor Gray

# Copy launch template if it exists alongside the installer
$templateSrc = Join-Path $PSScriptRoot "launch-template.ps1"
if (Test-Path $templateSrc) {
    Copy-Item $templateSrc "C:\DomitekVault\launch-template.ps1" -Force
    Write-Host "launch-template.ps1 deployed to C:\DomitekVault" -ForegroundColor Green
} elseif (-not (Test-Path "C:\DomitekVault\launch-template.ps1")) {
    Write-Host "[WARN] launch-template.ps1 not found. Download it alongside the installer." -ForegroundColor Yellow
}
Write-Host "Copyright (c) 2026 Domitek. All rights reserved." -ForegroundColor Gray
