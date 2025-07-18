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
    
.PARAMETER Verbose
    Enable verbose output mode
    
.PARAMETER Stealth
    Enable stealth mode with rate limiting
    
.PARAMETER RateLimit
    Rate limit in milliseconds between attempts (default: 1000)
    
.PARAMETER Timeout
    Connection timeout in seconds (default: 30)
    
.EXAMPLE
    .\WifadePS.ps1
    Run with default configuration files
    
.EXAMPLE
    .\WifadePS.ps1 -SSIDFile "custom_ssids.txt" -PasswordFile "custom_passwords.txt"
    Run with custom configuration files
    
.EXAMPLE
    .\WifadePS.ps1 -Stealth -RateLimit 2000
    Run in stealth mode with 2-second delays
    
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
    [Parameter(Mandatory=$false, HelpMessage="Path to SSID file")]
    [Alias("s")]
    [string]$SSIDFile = "ssid.txt",
    
    [Parameter(Mandatory=$false, HelpMessage="Path to password file")]
    [Alias("w")]
    [string]$PasswordFile = "passwords.txt",
    
    [Parameter(Mandatory=$false, HelpMessage="Display help information")]
    [Alias("h")]
    [switch]$Help,
    
    [Parameter(Mandatory=$false, HelpMessage="Enable verbose output")]
    [Alias("v")]
    [switch]$VerboseOutput,
    
    [Parameter(Mandatory=$false, HelpMessage="Enable stealth mode")]
    [switch]$Stealth,
    
    [Parameter(Mandatory=$false, HelpMessage="Rate limit in milliseconds")]
    [int]$RateLimit = 1000,
    
    [Parameter(Mandatory=$false, HelpMessage="Connection timeout in seconds")]
    [int]$Timeout = 30,
    
    [Parameter(Mandatory=$false, HelpMessage="Maximum attempts per SSID (0 = unlimited)")]
    [int]$MaxAttempts = 0
)

# Set error action preference for consistent error handling
$ErrorActionPreference = "Stop"

# Import required classes and modules
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptRoot\Classes\BaseClasses.ps1"
. "$ScriptRoot\Classes\DataModels.ps1"
. "$ScriptRoot\Classes\ConfigurationManager.ps1"
. "$ScriptRoot\Classes\NetworkManager.ps1"
. "$ScriptRoot\Classes\PasswordManager.ps1"

# Application constants
$Script:APP_NAME = "WifadePS"
$Script:APP_VERSION = "1.0.0"
$Script:APP_DESCRIPTION = "Windows PowerShell Wi-Fi Security Testing Tool"

# Global configuration manager and configuration object
$Script:ConfigManager = $null
$Script:Config = $null

function Show-Banner {
    <#
    .SYNOPSIS
        Display the application banner and version information
    #>
    
    $banner = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║  ██╗    ██╗██╗███████╗ █████╗ ██████╗ ███████╗██████╗ ███████╗               ║
║  ██║    ██║██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝               ║
║  ██║ █╗ ██║██║█████╗  ███████║██║  ██║█████╗  ██████╔╝███████╗               ║
║  ██║███╗██║██║██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔═══╝ ╚════██║               ║
║  ╚███╔███╔╝██║██║     ██║  ██║██████╔╝███████╗██║     ███████║               ║
║   ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝     ╚══════╝               ║
║                                                                              ║
║  $($Script:APP_DESCRIPTION.PadRight(76)) ║
║  Version: $($Script:APP_VERSION.PadRight(67)) ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@
    
    Write-Host $banner -ForegroundColor Cyan
}

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
    -Verbose, -v                Enable verbose output mode
    -Stealth                    Enable stealth mode with rate limiting
    -RateLimit <ms>             Rate limit in milliseconds (default: 1000)
    -Timeout <seconds>          Connection timeout in seconds (default: 30)
    -MaxAttempts <number>       Maximum attempts per SSID (default: unlimited)

EXAMPLES:
    .\WifadePS.ps1
        Run with default configuration files (ssid.txt and passwords.txt)
    
    .\WifadePS.ps1 -s "my_ssids.txt" -w "my_passwords.txt"
        Run with custom SSID and password files
    
    .\WifadePS.ps1 -Stealth -RateLimit 2000 -Verbose
        Run in stealth mode with 2-second delays and verbose output
    
    .\WifadePS.ps1 -MaxAttempts 50 -Timeout 15
        Limit to 50 attempts per SSID with 15-second timeout

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

function Show-EthicalWarning {
    <#
    .SYNOPSIS
        Display ethical usage warning and require user acknowledgment
    #>
    
    $warningText = @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                            ETHICAL USAGE WARNING                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  This tool is designed for EDUCATIONAL and ETHICAL SECURITY TESTING only.   ║
║                                                                              ║
║  LEGAL REQUIREMENTS:                                                         ║
║  • You must own the networks you are testing, OR                            ║
║  • You must have explicit written permission from the network owner         ║
║                                                                              ║
║  PROHIBITED USES:                                                            ║
║  • Testing networks without permission                                       ║
║  • Accessing networks for malicious purposes                                 ║
║  • Any activity that violates local, state, or federal laws                 ║
║                                                                              ║
║  DISCLAIMER:                                                                 ║
║  • Users are solely responsible for compliance with applicable laws          ║
║  • The developers assume no liability for misuse of this tool               ║
║  • Unauthorized network access may result in criminal prosecution           ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@
    
    Write-Host $warningText -ForegroundColor Yellow
    Write-Host "Do you acknowledge that you will use this tool ethically and legally? (y/N): " -ForegroundColor Red -NoNewline
    
    $response = Read-Host
    if ($response -notmatch '^[Yy]([Ee][Ss])?$') {
        Write-Host "`nEthical acknowledgment required. Exiting..." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`nThank you for your commitment to ethical security testing.`n" -ForegroundColor Green
}

function Initialize-Configuration {
    <#
    .SYNOPSIS
        Initialize the global configuration manager and configuration object
    #>
    
    try {
        # Create ConfigurationManager instance
        $Script:ConfigManager = [ConfigurationManager]::new()
        
        # Build configuration hashtable from PowerShell parameters
        $configHash = @{
            'SSIDFile' = $SSIDFile
            'PasswordFile' = $PasswordFile
            'Help' = $Help.IsPresent
            'Verbose' = $VerboseOutput.IsPresent
            'Stealth' = $Stealth.IsPresent
            'RateLimit' = $RateLimit
            'Timeout' = $Timeout
            'MaxAttempts' = $MaxAttempts
        }
        
        # Initialize ConfigurationManager with the configuration
        $Script:ConfigManager.Initialize($configHash)
        
        # Get the configuration object
        $Script:Config = $Script:ConfigManager.GetConfiguration()
        
        Write-Verbose "Configuration initialized successfully using ConfigurationManager"
        Write-Verbose "SSID File: $($Script:Config.SSIDFilePath)"
        Write-Verbose "Password File: $($Script:Config.PasswordFilePath)"
        Write-Verbose "Stealth Mode: $($Script:Config.StealthMode)"
        Write-Verbose "Rate Limit: $($Script:Config.RateLimitMs)ms"
        
    } catch {
        throw [ConfigurationException]::new("Failed to initialize configuration: $($_.Exception.Message)")
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Test system prerequisites and configuration files using ConfigurationManager
    #>
    
    Write-Verbose "Testing system prerequisites..."
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw [ConfigurationException]::new("PowerShell 5.0 or higher is required")
    }
    
    # Check if running on Windows
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        throw [ConfigurationException]::new("This tool is designed for Windows systems only")
    }
    
    # Use ConfigurationManager to validate configuration and files
    $Script:ConfigManager.ValidateConfiguration(@{})
    
    # Load files to get counts for verbose output
    $ssidList = $Script:ConfigManager.LoadSSIDList($Script:Config.SSIDFilePath)
    $passwordList = $Script:ConfigManager.LoadPasswordList($Script:Config.PasswordFilePath)
    
    Write-Verbose "Prerequisites check completed successfully"
    Write-Verbose "Found $($ssidList.Count) SSIDs and $($passwordList.Count) passwords"
}

function Start-WifiSecurityTest {
    <#
    .SYNOPSIS
        Start the Wi-Fi security testing process using NetworkManager and PasswordManager
    #>
    
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                          STARTING WI-FI SECURITY TEST                       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Initialize NetworkManager
        Write-Host "[1/4] Initializing Network Manager..." -ForegroundColor Yellow
        $networkConfig = @{
            AdapterScanInterval = 30
            MonitoringEnabled = $false
        }
        $networkManager = [NetworkManager]::new($networkConfig)
        $networkManager.Initialize($networkConfig)
        
        Write-Host "✓ Network Manager initialized successfully" -ForegroundColor Green
        Write-Host "  Primary Adapter: $($networkManager.PrimaryAdapter.Name)" -ForegroundColor White
        Write-Host "  Adapter Status: $($networkManager.PrimaryAdapter.Status)" -ForegroundColor White
        Write-Host ""
        
        # Initialize PasswordManager
        Write-Host "[2/4] Initializing Password Manager..." -ForegroundColor Yellow
        $passwordConfig = @{
            PasswordFilePath = $Script:Config.PasswordFilePath
            RateLimitEnabled = $Script:Config.StealthMode
            MinDelayMs = $Script:Config.RateLimitMs
            MaxDelayMs = $Script:Config.RateLimitMs * 2
            AttackStrategy = [AttackStrategy]::Dictionary
            StealthMode = $Script:Config.StealthMode
        }
        $passwordManager = [PasswordManager]::new($passwordConfig)
        $passwordManager.Initialize($passwordConfig)
        
        Write-Host "✓ Password Manager initialized successfully" -ForegroundColor Green
        Write-Host "  Loaded Passwords: $($passwordManager.PasswordList.Count)" -ForegroundColor White
        Write-Host "  Attack Strategy: $($passwordManager.CurrentStrategy)" -ForegroundColor White
        Write-Host "  Stealth Mode: $($passwordManager.StealthMode)" -ForegroundColor White
        Write-Host ""
        
        # Scan for available networks
        Write-Host "[3/4] Scanning for Wi-Fi networks..." -ForegroundColor Yellow
        $availableNetworks = $networkManager.ScanNetworks()
        
        Write-Host "✓ Network scan completed" -ForegroundColor Green
        Write-Host "  Found Networks: $($availableNetworks.Count)" -ForegroundColor White
        
        if ($availableNetworks.Count -gt 0) {
            Write-Host ""
            Write-Host "Available Networks:" -ForegroundColor Cyan
            Write-Host "===================" -ForegroundColor Cyan
            
            foreach ($network in $availableNetworks | Select-Object -First 10) {
                $signalBar = Get-SignalStrengthBar $network.SignalStrength
                Write-Host "  SSID: $($network.SSID.PadRight(25)) | Signal: $signalBar $($network.SignalStrength)% | Encryption: $($network.EncryptionType)" -ForegroundColor White
            }
            
            if ($availableNetworks.Count -gt 10) {
                Write-Host "  ... and $($availableNetworks.Count - 10) more networks" -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        # Load target SSIDs
        Write-Host "[4/4] Loading target SSIDs..." -ForegroundColor Yellow
        $targetSSIDs = $Script:ConfigManager.LoadSSIDList($Script:Config.SSIDFilePath)
        
        Write-Host "✓ Target SSIDs loaded successfully" -ForegroundColor Green
        Write-Host "  Target SSIDs: $($targetSSIDs.Count)" -ForegroundColor White
        Write-Host ""
        
        # Show matching networks
        $matchingNetworks = $availableNetworks | Where-Object { $_.SSID -in $targetSSIDs }
        
        if ($matchingNetworks.Count -gt 0) {
            Write-Host "Target Networks Found:" -ForegroundColor Green
            Write-Host "======================" -ForegroundColor Green
            
            foreach ($network in $matchingNetworks) {
                $signalBar = Get-SignalStrengthBar $network.SignalStrength
                Write-Host "  ✓ $($network.SSID.PadRight(25)) | Signal: $signalBar $($network.SignalStrength)% | Encryption: $($network.EncryptionType)" -ForegroundColor Green
            }
            Write-Host ""
            
            # Demonstrate password iteration
            Write-Host "Password Attack Simulation:" -ForegroundColor Cyan
            Write-Host "===========================" -ForegroundColor Cyan
            
            $targetNetwork = $matchingNetworks[0]
            Write-Host "Target: $($targetNetwork.SSID)" -ForegroundColor White
            Write-Host ""
            
            # Show first few passwords that would be tried
            Write-Host "Passwords to attempt:" -ForegroundColor Yellow
            $passwordManager.Reset()
            $attemptCount = 0
            $maxDisplay = 10
            
            while ($passwordManager.HasMorePasswords() -and $attemptCount -lt $maxDisplay) {
                $password = $passwordManager.GetNextPassword($targetNetwork.SSID)
                if ($password) {
                    $attemptCount++
                    Write-Host "  [$attemptCount] $password" -ForegroundColor White
                    
                    # Simulate rate limiting
                    if ($passwordManager.StealthMode) {
                        Start-Sleep -Milliseconds 100  # Reduced for demo
                    }
                }
            }
            
            if ($passwordManager.HasMorePasswords()) {
                $remaining = $passwordManager.PasswordList.Count - $attemptCount
                Write-Host "  ... and $remaining more passwords" -ForegroundColor Gray
            }
            
            Write-Host ""
            Write-Host "NOTE: This is a demonstration only. No actual connection attempts were made." -ForegroundColor Yellow
            Write-Host "      In a real test, each password would be attempted against the target network." -ForegroundColor Yellow
            
        } else {
            Write-Host "No target networks found in range." -ForegroundColor Yellow
            Write-Host "Available networks do not match any SSIDs in your target list." -ForegroundColor Yellow
            
            if ($targetSSIDs.Count -gt 0) {
                Write-Host ""
                Write-Host "Your target SSIDs:" -ForegroundColor Cyan
                foreach ($ssid in $targetSSIDs | Select-Object -First 5) {
                    Write-Host "  - $ssid" -ForegroundColor White
                }
                if ($targetSSIDs.Count -gt 5) {
                    Write-Host "  ... and $($targetSSIDs.Count - 5) more" -ForegroundColor Gray
                }
            }
        }
        
        # Show statistics
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                              TEST SUMMARY                                    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        
        $stats = $passwordManager.GetStatistics()
        Write-Host "Networks Scanned: $($availableNetworks.Count)" -ForegroundColor White
        Write-Host "Target Networks: $($targetSSIDs.Count)" -ForegroundColor White
        Write-Host "Matching Networks: $($matchingNetworks.Count)" -ForegroundColor White
        Write-Host "Passwords Loaded: $($passwordManager.PasswordList.Count)" -ForegroundColor White
        Write-Host "Attack Strategy: $($passwordManager.CurrentStrategy)" -ForegroundColor White
        Write-Host "Stealth Mode: $($passwordManager.StealthMode)" -ForegroundColor White
        
        Write-Host ""
        Write-Host "✓ Wi-Fi Security Test Framework Ready!" -ForegroundColor Green
        Write-Host "  All components initialized and working correctly." -ForegroundColor White
        Write-Host "  Ready for full implementation of connection attempts." -ForegroundColor White
        
    } catch {
        Write-Host "✗ Error during Wi-Fi security test: $($_.Exception.Message)" -ForegroundColor Red
        throw
    } finally {
        # Cleanup resources
        if ($networkManager) {
            $networkManager.Dispose()
        }
        if ($passwordManager) {
            $passwordManager.Dispose()
        }
    }
}

function Get-SignalStrengthBar {
    <#
    .SYNOPSIS
        Convert signal strength percentage to a visual bar
    #>
    param([int]$SignalStrength)
    
    if ($SignalStrength -ge 80) { return "████████" }
    elseif ($SignalStrength -ge 60) { return "██████  " }
    elseif ($SignalStrength -ge 40) { return "████    " }
    elseif ($SignalStrength -ge 20) { return "██      " }
    else { return "        " }
}

function Main {
    <#
    .SYNOPSIS
        Main application entry point
    #>
    
    try {
        # Show banner
        Show-Banner
        
        # Initialize configuration
        Initialize-Configuration
        
        # Show help if requested
        if ($Script:Config.ShowHelp) {
            Show-Help
            return
        }
        
        # Show ethical warning and require acknowledgment (skip in test mode)
        if (-not $env:WIFADE_TEST_MODE) {
            Show-EthicalWarning
        }
        
        # Test prerequisites
        Test-Prerequisites
        
        Write-Host "Configuration loaded successfully!" -ForegroundColor Green
        Write-Host "SSID File: $($Script:Config.SSIDFilePath)" -ForegroundColor White
        Write-Host "Password File: $($Script:Config.PasswordFilePath)" -ForegroundColor White
        Write-Host "Stealth Mode: $($Script:Config.StealthMode)" -ForegroundColor White
        Write-Host ""
        
        # Initialize and run the main application components
        Start-WifiSecurityTest
        
    } catch [WifadeException] {
        Write-Host "Application Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Context) {
            Write-Host "Context: $($_.Exception.Context)" -ForegroundColor Red
        }
        exit 1
    } catch {
        Write-Host "Unexpected Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        exit 1
    }
}

# Entry point - only run if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Main
}