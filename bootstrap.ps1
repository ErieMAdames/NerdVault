#Requires -Version 5.1
<#
.SYNOPSIS
    NerdVault CMS - Windows Development Environment Bootstrap

.DESCRIPTION
    Sets up a Windows machine for NerdVault CMS development:
      1. Enables WSL2 and installs Ubuntu
      2. Installs Docker Desktop (via winget)
      3. Hands off to bootstrap-wsl.sh for Linux-side tooling

    This script is IDEMPOTENT -- running it multiple times is safe.
    Each step checks whether the tool is already present before installing.

.NOTES
    Run this script in an ELEVATED (Administrator) PowerShell terminal.
    Some steps require a reboot; the script will tell you when.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ---------- helpers ----------------------------------------------------------

function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    $colors = @{ INFO = "Cyan"; OK = "Green"; WARN = "Yellow"; FAIL = "Red"; SKIP = "DarkGray" }
    $color  = if ($colors.ContainsKey($Level)) { $colors[$Level] } else { "White" }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

$summary = [ordered]@{}

function Record {
    param([string]$Component, [string]$Status)
    $script:summary[$Component] = $Status
}

function Print-Summary {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  BOOTSTRAP SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    foreach ($key in $summary.Keys) {
        $val   = $summary[$key]
        $color = switch ($val) {
            "Installed"        { "Green"  }
            "Already present"  { "DarkGray" }
            "Needs reboot"     { "Yellow" }
            "Manual action"    { "Yellow" }
            default            { "Red"    }
        }
        Write-Host "  $key : $val" -ForegroundColor $color
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# ---------- 1. administrator check ------------------------------------------

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Status "This script must run as Administrator. Re-launching elevated..." "WARN"
    try {
        Start-Process powershell.exe -Verb RunAs `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit 0
    } catch {
        Write-Status "Failed to elevate. Right-click PowerShell -> 'Run as Administrator' and try again." "FAIL"
        exit 1
    }
}

Write-Status "Running as Administrator."

# ---------- 2. WSL2 ---------------------------------------------------------

$needsReboot = $false

$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
$vmFeature  = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

if ($wslFeature.State -eq "Enabled" -and $vmFeature.State -eq "Enabled") {
    Write-Status "WSL2 Windows features already enabled." "SKIP"
    Record "WSL2 features" "Already present"
} else {
    Write-Status "Enabling WSL2 Windows features..."
    try {
        if ($wslFeature.State -ne "Enabled") {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
        }
        if ($vmFeature.State -ne "Enabled") {
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
        }
        Write-Status "WSL2 features enabled. A reboot is required before continuing." "OK"
        $needsReboot = $true
        Record "WSL2 features" "Needs reboot"
    } catch {
        Write-Status "Failed to enable WSL2 features: $_" "FAIL"
        Write-Status "Try manually: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux" "WARN"
        Record "WSL2 features" "FAILED"
    }
}

# Set WSL default version to 2 (safe to run even if already set)
try {
    wsl --set-default-version 2 2>$null | Out-Null
} catch {
    # Ignore -- may fail if WSL not fully installed yet (pre-reboot)
}

if ($needsReboot) {
    Write-Host ""
    Write-Status "=== REBOOT REQUIRED ===" "WARN"
    Write-Status "WSL2 features were just enabled. You must restart your computer." "WARN"
    Write-Status "After rebooting, re-run this script to continue setup." "WARN"
    Write-Host ""
    Print-Summary
    $response = Read-Host "Reboot now? (y/n)"
    if ($response -eq "y") {
        Restart-Computer -Force
    }
    exit 0
}

# ---------- 3. Ubuntu distro ------------------------------------------------

$distros = wsl --list --quiet 2>$null
if ($distros -match "Ubuntu") {
    Write-Status "Ubuntu is already installed in WSL." "SKIP"
    Record "Ubuntu (WSL)" "Already present"
} else {
    Write-Status "Installing Ubuntu in WSL (this may take a few minutes)..."
    try {
        wsl --install -d Ubuntu --no-launch 2>$null
        Write-Status "Ubuntu installed. You'll set up a username/password on first launch." "OK"
        Record "Ubuntu (WSL)" "Installed"
    } catch {
        Write-Status "Automatic install failed. Trying via Microsoft Store fallback..." "WARN"
        try {
            wsl --install -d Ubuntu 2>$null
            Record "Ubuntu (WSL)" "Installed"
        } catch {
            Write-Status "Could not install Ubuntu automatically." "FAIL"
            Write-Status "Install manually: open Microsoft Store, search 'Ubuntu', click Install." "WARN"
            Record "Ubuntu (WSL)" "FAILED - install manually from Microsoft Store"
        }
    }
}

# ---------- 4. Docker Desktop -----------------------------------------------

$dockerPath = (Get-Command "docker" -ErrorAction SilentlyContinue)
if ($dockerPath) {
    Write-Status "Docker is already on PATH ($($dockerPath.Source))." "SKIP"
    Record "Docker Desktop" "Already present"
} else {
    Write-Status "Installing Docker Desktop..."
    $wingetAvailable = Get-Command "winget" -ErrorAction SilentlyContinue

    if ($wingetAvailable) {
        try {
            winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
            Write-Status "Docker Desktop installed via winget." "OK"
            Record "Docker Desktop" "Installed"
        } catch {
            Write-Status "winget install failed: $_" "FAIL"
            Record "Docker Desktop" "FAILED - install manually from https://www.docker.com/products/docker-desktop/"
        }
    } else {
        Write-Status "winget not available. Download Docker Desktop manually:" "WARN"
        Write-Status "  https://www.docker.com/products/docker-desktop/" "WARN"
        Record "Docker Desktop" "Manual action"
    }

    Write-Host ""
    Write-Status "IMPORTANT: After Docker Desktop installs, open it and go to:" "WARN"
    Write-Status "  Settings > General > 'Use the WSL 2 based engine' (check it)" "WARN"
    Write-Status "  Settings > Resources > WSL Integration > enable for Ubuntu" "WARN"
}

# ---------- 5. VS Code reminder ---------------------------------------------

$codePath = (Get-Command "code" -ErrorAction SilentlyContinue)
if ($codePath) {
    Write-Status "VS Code is already on PATH." "SKIP"
    Record "VS Code" "Already present"
} else {
    Write-Status "VS Code not found on PATH." "WARN"
    Write-Status "Download from: https://code.visualstudio.com/" "WARN"
    Record "VS Code" "Manual action - download from https://code.visualstudio.com/"
}
Write-Status "Make sure to install the 'WSL' extension (ms-vscode-remote.remote-wsl) in VS Code." "INFO"

# ---------- 6. Run WSL companion script --------------------------------------

$wslScriptPath = Join-Path $PSScriptRoot "bootstrap-wsl.sh"
$wslScriptExists = Test-Path $wslScriptPath

if ($wslScriptExists) {
    Write-Host ""
    Write-Status "Running WSL companion script (bootstrap-wsl.sh)..."

    # Convert the Windows path to a WSL path
    $wslPath = wsl wslpath -u ($wslScriptPath -replace '\\', '/')

    try {
        wsl bash -c "chmod +x '$wslPath' && '$wslPath'"
        if ($LASTEXITCODE -eq 0) {
            Write-Status "WSL companion script completed." "OK"
            Record "WSL tools (Python, Node, etc.)" "Installed"
        } else {
            Write-Status "WSL companion script exited with code $LASTEXITCODE." "WARN"
            Record "WSL tools" "Partial - check output above"
        }
    } catch {
        Write-Status "Failed to run WSL script: $_" "FAIL"
        Write-Status "Run it manually inside WSL: bash bootstrap-wsl.sh" "WARN"
        Record "WSL tools" "FAILED - run manually: bash bootstrap-wsl.sh"
    }
} else {
    Write-Status "bootstrap-wsl.sh not found next to this script. Skipping WSL tool setup." "WARN"
    Write-Status "Place bootstrap-wsl.sh in the same folder and re-run, or run it manually in WSL." "WARN"
    Record "WSL tools" "Skipped - bootstrap-wsl.sh not found"
}

# ---------- 7. Summary -------------------------------------------------------

Print-Summary

Write-Host "NEXT STEPS:" -ForegroundColor Green
Write-Host "  1. Open Docker Desktop and enable WSL2 backend (see notes above)."
Write-Host "  2. Open VS Code and install the 'WSL' extension."
Write-Host "  3. In VS Code, press Ctrl+Shift+P -> 'WSL: Connect to WSL'."
Write-Host "  4. Open a terminal inside VS Code (now running in Ubuntu) and start Phase 1!"
Write-Host ""
