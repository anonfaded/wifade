#!/usr/bin/env pwsh
<#
.SYNOPSIS
    WifadePS - Windows PowerShell Wi-Fi Security Testing Tool
    
.DESCRIPTION
    A PowerShell implementation of the Wifade Wi-Fi password brute-forcing tool
    designed for ethical security testing on Windows systems.
    
.PARAMETER SSIDFile
    Path to file containing target SSID list (default: ssid.txt)
    
.PARAMETER PasswordFile
    Path to file containing password list (default: passwords.txt)
    
.PARAMETER Help
    Display help information
    
.PARAMETER VerboseOutput
    Enable verbose output mode
    
.PARAMETER DebugMode
    Enable debug mode
    
.PARAMETER Stealth
    Enable stealth mode with rate limiting
    
.PARAMETER RateLimit
    Rate limit in milliseconds between attempts (default: 1000)
    
.PARAMETER Timeout
    Connection timeout in seconds (default: 30)
    
.PARAMETER MaxAttempts
    Maximum attempts per SSID (default: unlimited)
    
.EXAMPLE
    .\WifadePS.ps1
    Run with default configuration files
    
.EXAMPLE
    .\WifadePS.ps1 -SSIDFile "custom_ssids.txt" -PasswordFile "custom_passwords.txt"
    Run with custom configuration files
    
.EXAMPLE
    .\WifadePS.ps1 -Stealth -RateLimit 2000 -DebugMode
    Run in stealth mode with 2-second delays and debug output
    
.NOTES
    This tool is intended for educational purposes and ethical security testing only.
    Always ensure you have explicit permission to test network security.
    
    Author: WifadePS Development Team
    Version: 1.0.0
    
.LINK
    https://github.com/wifade/wifade
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to SSID file")]
    [Alias("s")]
    [string]$SSIDFile = "ssid.txt",
    
    [Parameter(Mandatory = $false, HelpMessage = "Path to password file")]
    [Alias("w")]
    [string]$PasswordFile = "passwords.txt",
    
    [Parameter(Mandatory = $false, HelpMessage = "Display help information")]
    [Alias("h")]
    [switch]$Help,
    
    [Parameter(Mandatory = $false, HelpMessage = "Enable verbose output")]
    [Alias("v")]
    [switch]$VerboseOutput,
    
    [Parameter(Mandatory = $false, HelpMessage = "Enable debug mode")]
    [Alias("d")]
    [switch]$DebugMode,
    
    [Parameter(Mandatory = $false, HelpMessage = "Enable stealth mode")]
    [switch]$Stealth,
    
    [Parameter(Mandatory = $false, HelpMessage = "Rate limit in milliseconds")]
    [int]$RateLimit = 1000,
    
    [Parameter(Mandatory = $false, HelpMessage = "Connection timeout in seconds")]
    [int]$Timeout = 30,
    
    [Parameter(Mandatory = $false, HelpMessage = "Maximum attempts per SSID (0 = unlimited)")]
    [int]$MaxAttempts = 0
)

# Set error action preference for consistent error handling
$ErrorActionPreference = "Stop"

# Import required classes and modules
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptRoot\Classes\DataModels.ps1"
. "$ScriptRoot\Classes\ConfigurationManager.ps1"
. "$ScriptRoot\Classes\NetworkManager.ps1"
. "$ScriptRoot\Classes\PasswordManager.ps1"
. "$ScriptRoot\Classes\SettingsManager.ps1"
. "$ScriptRoot\Classes\UIManager.ps1"
. "$ScriptRoot\Classes\ApplicationController.ps1"

# Application constants
$Script:APP_NAME = "WifadePS"
$Script:APP_VERSION = "1.0.0"
$Script:APP_DESCRIPTION = "Windows PowerShell Wi-Fi Security Testing Tool"

function Show-Help {
    <#
    .SYNOPSIS
        Display detailed help information
    #>
    
    $helpText = @"
USAGE:
    .\WifadePS.ps1 [OPTIONS]

OPTIONS:
    -SSIDFile, -s <path>        Path to SSID file (default: ssid.txt)
    -PasswordFile, -w <path>    Path to password file (default: passwords.txt)
    -Help, -h                   Display this help information
    -VerboseOutput, -v          Enable verbose output mode
    -DebugMode, -d              Enable debug mode with detailed information
    -Stealth                    Enable stealth mode with rate limiting
    -RateLimit <ms>             Rate limit in milliseconds (default: 1000)
    -Timeout <seconds>          Connection timeout in seconds (default: 30)
    -MaxAttempts <number>       Maximum attempts per SSID (default: unlimited)

EXAMPLES:
    .\WifadePS.ps1
        Run with default configuration files (ssid.txt and passwords.txt)
    
    .\WifadePS.ps1 -s "my_ssids.txt" -w "my_passwords.txt"
        Run with custom SSID and password files
    
    .\WifadePS.ps1 -Stealth -RateLimit 2000 -VerboseOutput
        Run in stealth mode with 2-second delays and verbose output
    
    .\WifadePS.ps1 -DebugMode -MaxAttempts 50 -Timeout 15
        Run in debug mode with 50 attempts per SSID and 15-second timeout

CONFIGURATION FILES:
    SSID File Format:
        One SSID per line, plain text
        Example:
            MyNetwork
            OfficeWiFi
            HomeRouter
    
    Password File Format:
        One password per line, plain text
        Example:
            password123
            admin
            12345678

INTERACTIVE INTERFACE:
    The tool provides an interactive menu-driven interface with the following options:
    
    1. Scan Wi-Fi Networks    - Discover available Wi-Fi networks in range
    2. Attack Mode           - Choose from various password attack strategies
    3. View Results          - Review previous attack results and statistics
    4. Settings              - Configure application settings and preferences
    5. Help                  - Display help information
    q. Quit                  - Exit the application

ETHICAL USAGE:
    This tool is intended for educational purposes and ethical security testing only.
    
    IMPORTANT LEGAL NOTICE:
    - Only test networks you own or have explicit written permission to test
    - Unauthorized access to computer networks is illegal in most jurisdictions
    - Users are solely responsible for compliance with applicable laws
    - The developers assume no liability for misuse of this tool

SYSTEM REQUIREMENTS:
    - Windows 10/11 or Windows Server 2016+
    - PowerShell 5.1 or PowerShell 7.x
    - Wi-Fi adapter with appropriate drivers
    - Administrator privileges (recommended)

For more information, visit: https://github.com/wifade/wifade
"@
    
    Write-Host $helpText -ForegroundColor White
}

function Main {
    <#
    .SYNOPSIS
        Main application entry point
    #>
    
    try {
        # Show help if requested
        if ($Help.IsPresent) {
            Show-Help
            return
        }
        
        # Build application configuration
        $appConfig = @{
            SSIDFile     = $SSIDFile
            PasswordFile = $PasswordFile
            VerboseMode  = $VerboseOutput.IsPresent
            DebugMode    = $DebugMode.IsPresent
            StealthMode  = $Stealth.IsPresent
            RateLimit    = $RateLimit
            Timeout      = $Timeout
            MaxAttempts  = $MaxAttempts
        }
        
        Write-Host "Starting WifadePS..." -ForegroundColor Green
        
        # Initialize and start the interactive application
        $appController = [ApplicationController]::new($appConfig)
        $appController.Initialize($appConfig)
        $appController.Start()
        
    }
    catch [WifadeException] {
        Write-Host "Application Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Context) {
            Write-Host "Context: $($_.Exception.Context)" -ForegroundColor Red
        }
        exit 1
    }
    catch {
        Write-Host "Unexpected Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Error Type: $($_.Exception.GetType().Name)" -ForegroundColor Red
        if ($DebugMode.IsPresent) {
            Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        }
        exit 1
    }
    finally {
        # Cleanup
        if ($appController) {
            $appController.Dispose()
        }
    }
}

# Entry point - only run if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Main
}