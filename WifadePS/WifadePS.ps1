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
    [int]$MaxAttempts = 0,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display current Wi-Fi private IP address and exit")]
    [switch]$IP,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display current Wi-Fi connection status and exit")]
    [switch]$Status,
    
    [Parameter(Mandatory = $false, HelpMessage = "Scan and list available Wi-Fi networks and exit")]
    [switch]$Scan,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display current public IP address and exit")]
    [switch]$PublicIP,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display default gateway IP address and exit")]
    [switch]$Gateway,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display DNS servers and exit")]
    [switch]$DNS,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display Wi-Fi adapter MAC address and exit")]
    [switch]$MAC,
    
    [Parameter(Mandatory = $false, HelpMessage = "Display Wi-Fi connection speed and exit")]
    [switch]$Speed,
    
    [Parameter(Mandatory = $false, HelpMessage = "Restart Wi-Fi adapter and exit")]
    [switch]$Restart
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
. "$ScriptRoot\Classes\SettingsManager.ps1"
. "$ScriptRoot\Classes\UIManager.ps1"
. "$ScriptRoot\Classes\ApplicationController.ps1"

# Application constants
$Script:APP_NAME = "WifadePS"
$Script:APP_VERSION = "1.0.0"
$Script:APP_DESCRIPTION = "Windows PowerShell Wi-Fi Security Testing Tool"

function Get-WiFiPrivateIP {
    <#
    .SYNOPSIS
        Get the current Wi-Fi private IP address
    #>
    
    try {
        # Get Wi-Fi adapter IP configuration
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address -and $_.NetProfile.IPv4Connectivity -eq "Internet" } | Select-Object -First 1
        
        if ($ipConfig -and $ipConfig.IPv4Address) {
            return $ipConfig.IPv4Address.IPAddress
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

function Get-WiFiPublicIP {
    <#
    .SYNOPSIS
        Get the current public IP address
    #>
    
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop).Trim()
        return $publicIP
    }
    catch {
        return $null
    }
}

function Get-WiFiGateway {
    <#
    .SYNOPSIS
        Get the default gateway IP address
    #>
    
    try {
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address -and $_.NetProfile.IPv4Connectivity -eq "Internet" } | Select-Object -First 1
        
        if ($ipConfig -and $ipConfig.IPv4DefaultGateway) {
            return $ipConfig.IPv4DefaultGateway.NextHop
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

function Get-WiFiDNS {
    <#
    .SYNOPSIS
        Get the DNS servers
    #>
    
    try {
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address -and $_.NetProfile.IPv4Connectivity -eq "Internet" } | Select-Object -First 1
        
        if ($ipConfig -and $ipConfig.DNSServer) {
            $dnsServers = $ipConfig.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses
            if ($dnsServers) {
                return $dnsServers -join ', '
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-WiFiMAC {
    <#
    .SYNOPSIS
        Get the Wi-Fi adapter MAC address
    #>
    
    try {
        $adapter = Get-NetAdapter -InterfaceAlias "Wi-Fi*" | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            return $adapter.MacAddress
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-WiFiSpeed {
    <#
    .SYNOPSIS
        Get the Wi-Fi connection speed
    #>
    
    try {
        $adapter = Get-NetAdapter -InterfaceAlias "Wi-Fi*" | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            return $adapter.LinkSpeed
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-WiFiStatus {
    <#
    .SYNOPSIS
        Get comprehensive Wi-Fi status information using NetworkManager
    #>
    
    try {
        # Initialize NetworkManager
        $networkConfig = @{
            AdapterScanInterval = 30
            MonitoringEnabled   = $false
        }
        $networkManager = New-Object NetworkManager -ArgumentList $networkConfig
        $networkManager.Initialize($networkConfig)
        
        # Get current connection
        $currentConnection = $networkManager.GetCurrentConnection()
        
        if (-not $currentConnection) {
            return "Not connected to any Wi-Fi network"
        }
        
        # Get IP information
        $privateIP = Get-WiFiPrivateIP
        $publicIP = Get-WiFiPublicIP
        $gateway = Get-WiFiGateway
        
        # Format output
        $status = @()
        $status += "SSID: $($currentConnection.SSID)"
        $status += "Signal: $($currentConnection.SignalStrength)%"
        $status += "Encryption: $($currentConnection.EncryptionType)"
        if ($privateIP) { $status += "Private IP: $privateIP" }
        if ($publicIP) { $status += "Public IP: $publicIP" } else { $status += "Public IP: [Unable to retrieve]" }
        if ($gateway) { $status += "Gateway: $gateway" }
        
        return $status -join "`n"
    }
    catch {
        return $null
    }
}

function Get-WiFiNetworks {
    <#
    .SYNOPSIS
        Scan and list available Wi-Fi networks using NetworkManager
    #>
    
    try {
        # Initialize NetworkManager
        $networkConfig = @{
            AdapterScanInterval = 30
            MonitoringEnabled   = $false
        }
        $networkManager = New-Object NetworkManager -ArgumentList $networkConfig
        $networkManager.Initialize($networkConfig)
        
        # Scan for networks
        $networks = $networkManager.ScanNetworks()
        
        if ($networks.Count -eq 0) {
            return "No networks found"
        }
        
        # Format output as a nice table
        $output = @()
        
        # Add header
        $output += "Available Networks:"
        $output += "=" * 80
        $output += "{0,-4} {1,-25} {2,-8} {3,-12} {4,-10}" -f "No.", "SSID", "Signal", "Encryption", "Status"
        $output += "-" * 80
        
        # Add network entries
        for ($i = 0; $i -lt $networks.Count; $i++) {
            $network = $networks[$i]
            $signalBars = ""
            $signalStrength = $network.SignalStrength
            
            # Create signal strength bars
            if ($signalStrength -ge 75) { $signalBars = "████" }
            elseif ($signalStrength -ge 50) { $signalBars = "███░" }
            elseif ($signalStrength -ge 25) { $signalBars = "██░░" }
            else { $signalBars = "█░░░" }
            
            $status = if ($signalStrength -gt 0) { "Available" } else { "Unavailable" }
            $signalDisplay = "$signalBars $($signalStrength)%"
            
            # Truncate SSID if too long
            $displaySSID = if ($network.SSID.Length -gt 23) { 
                $network.SSID.Substring(0, 20) + "..." 
            } else { 
                $network.SSID 
            }
            
            $output += "{0,-4} {1,-25} {2,-8} {3,-12} {4,-10}" -f "$($i + 1).", $displaySSID, $signalDisplay, $network.EncryptionType, $status
        }
        
        return $output -join "`n"
    }
    catch {
        return "Unable to scan networks: $($_.Exception.Message)"
    }
}

function Restart-WiFiAdapter {
    <#
    .SYNOPSIS
        Restart the Wi-Fi adapter
    #>
    
    try {
        Write-Host "Restarting Wi-Fi adapter..." -ForegroundColor Yellow
        
        # Get Wi-Fi adapter
        $adapter = Get-NetAdapter -InterfaceAlias "Wi-Fi*" | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if (-not $adapter) {
            Write-Host "No active Wi-Fi adapter found" -ForegroundColor Red
            return $false
        }
        
        $adapterName = $adapter.Name
        Write-Host "Found adapter: $adapterName" -ForegroundColor Green
        
        # Try to restart using different methods
        try {
            Disable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 3
            Enable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 5
            Write-Host "Wi-Fi adapter restarted successfully" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Admin privileges required. Trying alternative method..." -ForegroundColor Yellow
            & netsh interface set interface name="$adapterName" admin=disabled 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            & netsh interface set interface name="$adapterName" admin=enabled 2>&1 | Out-Null
            Start-Sleep -Seconds 5
            Write-Host "Wi-Fi adapter restart attempted" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "Failed to restart Wi-Fi adapter: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
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
    -IP                         Display current Wi-Fi private IP address and exit
    -Status                     Display current Wi-Fi connection status and exit
    -Scan                       Scan and list available Wi-Fi networks and exit
    -PublicIP                   Display current public IP address and exit
    -Gateway                    Display default gateway IP address and exit
    -DNS                        Display DNS servers and exit
    -MAC                        Display Wi-Fi adapter MAC address and exit
    -Speed                      Display Wi-Fi connection speed and exit
    -Restart                    Restart Wi-Fi adapter and exit
    -VerboseOutput, -v          Enable verbose output mode
    -DebugMode, -d              Enable debug mode with detailed information
    -Stealth                    Enable stealth mode with rate limiting
    -RateLimit <ms>             Rate limit in milliseconds (default: 1000)
    -Timeout <seconds>          Connection timeout in seconds (default: 30)
    -MaxAttempts <number>       Maximum attempts per SSID (default: unlimited)

EXAMPLES:
    .\WifadePS.ps1
        Run with default configuration files (ssid.txt and passwords.txt)
    
    .\WifadePS.ps1 -IP
        Display current Wi-Fi private IP address and exit
    
    .\WifadePS.ps1 -Status
        Display comprehensive Wi-Fi connection status and exit
    
    .\WifadePS.ps1 -Scan
        Scan and list available Wi-Fi networks and exit
    
    .\WifadePS.ps1 -PublicIP
        Display current public IP address and exit
    
    .\WifadePS.ps1 -Gateway
        Display default gateway IP address and exit
    
    .\WifadePS.ps1 -DNS
        Display DNS servers and exit
    
    .\WifadePS.ps1 -MAC
        Display Wi-Fi adapter MAC address and exit
    
    .\WifadePS.ps1 -Speed
        Display Wi-Fi connection speed and exit
    
    .\WifadePS.ps1 -Restart
        Restart Wi-Fi adapter and exit
    
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
        
        # Show IP address if requested
        if ($IP.IsPresent) {
            $privateIP = Get-WiFiPrivateIP
            if ($privateIP) {
                Write-Host $privateIP
            }
            else {
                Write-Host "No Wi-Fi connection found or unable to retrieve IP address" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Show status if requested
        if ($Status.IsPresent) {
            $status = Get-WiFiStatus
            if ($status) {
                Write-Host $status
            }
            else {
                Write-Host "Unable to retrieve Wi-Fi status" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Scan networks if requested
        if ($Scan.IsPresent) {
            $networks = Get-WiFiNetworks
            if ($networks) {
                Write-Host $networks
            }
            else {
                Write-Host "Unable to scan networks" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Show public IP if requested
        if ($PublicIP.IsPresent) {
            $publicIP = Get-WiFiPublicIP
            if ($publicIP) {
                Write-Host $publicIP
            }
            else {
                Write-Host "Unable to retrieve public IP address" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Show gateway if requested
        if ($Gateway.IsPresent) {
            $gateway = Get-WiFiGateway
            if ($gateway) {
                Write-Host $gateway
            }
            else {
                Write-Host "Unable to retrieve gateway address" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Show DNS if requested
        if ($DNS.IsPresent) {
            $dns = Get-WiFiDNS
            if ($dns) {
                Write-Host $dns
            }
            else {
                Write-Host "Unable to retrieve DNS servers" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Show MAC address if requested
        if ($MAC.IsPresent) {
            $mac = Get-WiFiMAC
            if ($mac) {
                Write-Host $mac
            }
            else {
                Write-Host "Unable to retrieve MAC address" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Show speed if requested
        if ($Speed.IsPresent) {
            $speed = Get-WiFiSpeed
            if ($speed) {
                Write-Host $speed
            }
            else {
                Write-Host "Unable to retrieve connection speed" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Restart Wi-Fi adapter if requested
        if ($Restart.IsPresent) {
            $success = Restart-WiFiAdapter
            if (-not $success) {
                exit 1
            }
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