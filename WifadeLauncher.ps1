# Wifade Launcher - Starts WifadeCore.exe in PowerShell environment
<#
.SYNOPSIS
    Wifade Launcher - Starts WifadeCore.exe in PowerShell environment
.DESCRIPTION
    This launcher ensures Wifade runs in a PowerShell console with proper Unicode support.
    It launches WifadeCore.exe within the current PowerShell session.
.PARAMETER Help
    Show help information
.PARAMETER Version
    Show version information
.PARAMETER Status
    Show WiFi status
.PARAMETER Scan
    Scan for available networks
.PARAMETER VerboseOutput
    Enable verbose output
.PARAMETER v
    Alias for VerboseOutput
#>

param(
    [switch]$Help,
    [switch]$Version,
    [switch]$Status,
    [switch]$Scan,
    [Alias("v")]
    [switch]$VerboseOutput,
    [switch]$List,
    [switch]$IP,
    [switch]$PublicIP,
    [switch]$Gateway,
    [switch]$DNS,
    [switch]$MAC,
    [switch]$Speed,
    [switch]$Restart,
    [switch]$Connect
)

# Check if running as administrator (but don't force it for testing)
function Test-Administrator {
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# Set console encoding for proper Unicode support
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Silently continue if console encoding cannot be set
}

# Suppress console cursor errors by setting error action preference
$ErrorActionPreference = "SilentlyContinue"

# Restore error action preference for the rest of the script
$ErrorActionPreference = "Continue"

# Get the directory where this launcher is located
try {
    if ($MyInvocation.MyCommand.Path) {
        $LauncherDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $LauncherDir = $PWD.Path
    }
} catch {
    $LauncherDir = $PWD.Path
}

$WifadeCoreExe = Join-Path $LauncherDir "WifadeCore.exe"

# Check if the core executable exists
if (-not (Test-Path $WifadeCoreExe)) {
    Write-Host "❌ WifadeCore.exe not found!" -ForegroundColor Red
    Write-Host "Expected location: $WifadeCoreExe" -ForegroundColor Yellow
    Write-Host "Current directory: $LauncherDir" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Please ensure both files are in the same directory:" -ForegroundColor Cyan
    Write-Host "  • Wifade.exe (this launcher)" -ForegroundColor White
    Write-Host "  • WifadeCore.exe (main application)" -ForegroundColor White
    
    # Only prompt for input if not running a quick command
    if (-not ($quickCommands -or $Restart -or $Connect)) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

# Check admin privileges for operations that actually need them (not for quick info commands)
$adminRequiredCommands = $Restart -or $Connect -or (-not ($Version -or $Help -or $List -or $IP -or $PublicIP -or $Gateway -or $DNS -or $MAC -or $Speed -or $Status -or $Scan))
if ($adminRequiredCommands) {
    if (-not (Test-Administrator)) {
        Write-Warning "⚠️ Administrator privileges recommended for full functionality"
        Write-Host "Some features may not work without elevated permissions" -ForegroundColor Yellow
    }
}

# Display launcher info for interactive mode (only if not running a quick command)
$quickCommands = $Help -or $Version -or $Status -or $Scan -or $VerboseOutput -or $List -or $IP -or $PublicIP -or $Gateway -or $DNS -or $MAC -or $Speed
if (-not $quickCommands) {
    Write-Host "🚀 Wifade Launcher" -ForegroundColor Cyan
    Write-Host "   Starting WifadeCore.exe in PowerShell environment..." -ForegroundColor Gray
    Write-Host ""
}

# Forward all arguments to WifadeCore.exe
try {
    if ($args.Count -gt 0 -or $quickCommands -or $Restart -or $Connect) {
        # Build argument list
        $argumentList = @()
        if ($Help) { $argumentList += "-Help" }
        if ($Version) { $argumentList += "-Version" }
        if ($Status) { $argumentList += "-Status" }
        if ($Scan) { $argumentList += "-Scan" }
        if ($VerboseOutput) { $argumentList += "-VerboseOutput" }
        if ($List) { $argumentList += "-List" }
        if ($IP) { $argumentList += "-IP" }
        if ($PublicIP) { $argumentList += "-PublicIP" }
        if ($Gateway) { $argumentList += "-Gateway" }
        if ($DNS) { $argumentList += "-DNS" }
        if ($MAC) { $argumentList += "-MAC" }
        if ($Speed) { $argumentList += "-Speed" }
        if ($Restart) { $argumentList += "-Restart" }
        if ($Connect) { $argumentList += "-Connect" }
        $argumentList += $args
        
        # Use Start-Process to better control the execution environment
        if ($argumentList.Count -gt 0) {
            $process = Start-Process -FilePath $WifadeCoreExe -ArgumentList $argumentList -Wait -PassThru -NoNewWindow
            $exitCode = $process.ExitCode
        } else {
            $process = Start-Process -FilePath $WifadeCoreExe -Wait -PassThru -NoNewWindow
            $exitCode = $process.ExitCode
        }
        
        # Exit with the same code as WifadeCore.exe
        exit $exitCode
    } else {
        # Use Start-Process for interactive mode to suppress stderr console errors
        $process = Start-Process -FilePath $WifadeCoreExe -Wait -PassThru -NoNewWindow
        exit $process.ExitCode
    }
} catch {
    Write-Host "❌ Failed to launch WifadeCore.exe" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "WifadeCore.exe path: $WifadeCoreExe" -ForegroundColor Gray
    
    # Only prompt for input if not running a quick command
    if (-not ($quickCommands -or $Restart -or $Connect)) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}