#!/usr/bin/env pwsh
<#
.SYNOPSIS
    wifade - Windows PowerShell Wi-Fi Security Testing Tool
    
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
    

    

    
.EXAMPLE
    .\wifade.ps1
    Run with default configuration files
    
.EXAMPLE
    .\wifade.ps1 -SSIDFile "custom_ssids.txt" -PasswordFile "custom_passwords.txt"
    Run with custom configuration files
    
.EXAMPLE
    .\wifade.ps1 -VerboseOutput
    Run with verbose output enabled
    
.NOTES
    This tool is intended for educational purposes and ethical security testing only.
    Always ensure you have explicit permission to test network security.
    
    Author: wifade Development Team
    Version: 1.0.0
    
.LINK
    https://github.com/anonfaded/wifade
#>

[CmdletBinding()]
param(

    
    [Parameter(Mandatory = $false, HelpMessage = "Path to password file")]
    [Alias("w")]
    [string]$PasswordFile = "passwords\probable-v2-wpa-top4800.txt",
    
    [Parameter(Mandatory = $false, HelpMessage = "Display help information")]
    [Alias("h")]
    [switch]$Help,
    
    [Parameter(Mandatory = $false, HelpMessage = "List all available command-line parameters")]
    [switch]$List,
    
    [Parameter(Mandatory = $false, HelpMessage = "Enable verbose output")]
    [Alias("v")]
    [switch]$VerboseOutput,
    

    

    
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
    [switch]$Restart,
    
    [Parameter(Mandatory = $false, HelpMessage = "Connect to Wi-Fi network - specify SSID and password as positional arguments")]
    [switch]$Connect,
    
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = "SSID of the network to connect to (use quotes for SSIDs with spaces)")]
    [string]$ConnectSSID,
    
    [Parameter(Position = 1, Mandatory = $false, HelpMessage = "Password for the network")]
    [string]$ConnectPassword
    
    # Second $List parameter removed to fix duplicate parameter error
)

# Set error action preference for consistent error handling
$ErrorActionPreference = "Stop"

# Load Windows Forms assembly for file dialog functionality
# This must be done BEFORE loading any classes that might use it
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Verbose "Windows Forms assembly loaded successfully"
}
catch {
    Write-Warning "Could not load Windows Forms assembly: $($_.Exception.Message)"
    Write-Warning "File picker dialog functionality will not be available"
}

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
$Script:APP_NAME = "wifade"
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
            # Display styled "not connected" message
            Write-Host ""
            Write-Host "╭─ " -ForegroundColor Red -NoNewline
            Write-Host "📶 Wi-Fi Connection Status" -ForegroundColor Blue -NoNewline

            Write-Host "│" -ForegroundColor Red -NoNewline
            Write-Host "                                    " -NoNewline
            Write-Host "│" -ForegroundColor Red
            Write-Host "│ " -ForegroundColor Red -NoNewline
            Write-Host "❌ Not connected to any Wi-Fi network" -ForegroundColor Red
            Write-Host "│" -ForegroundColor Red -NoNewline
            Write-Host "                                    " -NoNewline
            Write-Host "│" -ForegroundColor Red
            Write-Host "╰────────────────────────────────────" -ForegroundColor Red
            Write-Host ""
            return
        }
        
        # Get IP information
        $privateIP = Get-WiFiPrivateIP
        $publicIP = Get-WiFiPublicIP
        $gateway = Get-WiFiGateway
        
        # Create signal strength visual
        $signalStrength = $currentConnection.SignalStrength
        $signalBars = ""
        if ($signalStrength -ge 75) { $signalBars = "████" }
        elseif ($signalStrength -ge 50) { $signalBars = "███░" }
        elseif ($signalStrength -ge 25) { $signalBars = "██░░" }
        elseif ($signalStrength -gt 0) { $signalBars = "█░░░" }
        else { $signalBars = "░░░░" }
        
        # Display styled status information
        Write-Host ""
        Write-Host "╭─ " -ForegroundColor Red -NoNewline
        Write-Host "📶 Wi-Fi Connection Status" -ForegroundColor Blue -NoNewline

        Write-Host ""

        
        # Using proper string formatting with consistent padding (10 chars + colon)
        Write-Host "│ " -ForegroundColor Red -NoNewline
        Write-Host ("{0,-10} : " -f "SSID") -ForegroundColor Blue -NoNewline
        Write-Host "$($currentConnection.SSID)" -ForegroundColor White
        
        # Signal with bars
        Write-Host "│ " -ForegroundColor Red -NoNewline
        Write-Host ("{0,-10} : " -f "Signal") -ForegroundColor Blue -NoNewline
        Write-Host "$signalBars $($signalStrength)%" -ForegroundColor White
        
        # Encryption
        Write-Host "│ " -ForegroundColor Red -NoNewline
        Write-Host ("{0,-10} : " -f "Encryption") -ForegroundColor Blue -NoNewline
        Write-Host "$($currentConnection.EncryptionType)" -ForegroundColor White
        
        # Private IP
        if ($privateIP) {
            Write-Host "│ " -ForegroundColor Red -NoNewline
            Write-Host ("{0,-10} : " -f "Private IP") -ForegroundColor Blue -NoNewline
            Write-Host "$privateIP" -ForegroundColor White
        }
        
        # Public IP
        if ($publicIP) {
            Write-Host "│ " -ForegroundColor Red -NoNewline
            Write-Host ("{0,-10} : " -f "Public IP") -ForegroundColor Blue -NoNewline
            Write-Host "$publicIP" -ForegroundColor White
        } else {
            Write-Host "│ " -ForegroundColor Red -NoNewline
            Write-Host ("{0,-10} : " -f "Public IP") -ForegroundColor Blue -NoNewline
            Write-Host "[Unable to retrieve]" -ForegroundColor Red
        }
        
        # Gateway
        if ($gateway) {
            Write-Host "│ " -ForegroundColor Red -NoNewline
            Write-Host ("{0,-10} : " -f "Gateway") -ForegroundColor Blue -NoNewline
            Write-Host "$gateway" -ForegroundColor White
        }
        

        Write-Host "╰────────────────────────────────────" -ForegroundColor Red
        Write-Host ""
    }
    catch {
        # Display styled error message
        Write-Host ""
        Write-Host "╭─ " -ForegroundColor Red -NoNewline
        Write-Host "📶 Wi-Fi Connection Status" -ForegroundColor Blue -NoNewline
        Write-Host " ─╮" -ForegroundColor Red
        Write-Host "│" -ForegroundColor Red -NoNewline
        Write-Host "                                    " -NoNewline
        Write-Host "│" -ForegroundColor Red
        Write-Host "│ " -ForegroundColor Red -NoNewline
        Write-Host "❌ Unable to retrieve Wi-Fi status" -ForegroundColor Red
        Write-Host "│" -ForegroundColor Red -NoNewline
        Write-Host "                                    " -NoNewline
        Write-Host "│" -ForegroundColor Red
        Write-Host "╰────────────────────────────────────╯" -ForegroundColor Red
        Write-Host ""
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
            Write-Host "No networks found" -ForegroundColor Red
            return
        }
        
        # Format output with the exact same design and colors as UIManager's ShowNetworkList
        # Using the exact ColorScheme: Border=Red, Info=Blue, Secondary=White, Highlight=Red
        Write-Host ""
        Write-Host "╭─ 📶 Available Networks" -ForegroundColor Red
        Write-Host "│" -ForegroundColor Red
        
        # Table header
        Write-Host "│ " -NoNewline -ForegroundColor Red
        Write-Host "#  " -NoNewline -ForegroundColor Blue
        Write-Host "SSID                     " -NoNewline -ForegroundColor Blue
        Write-Host "Signal     " -NoNewline -ForegroundColor Blue
        Write-Host "Encryption      " -NoNewline -ForegroundColor Blue
        Write-Host "Status" -ForegroundColor Blue
        
        # Table separator
        Write-Host "│ " -NoNewline -ForegroundColor Red
        Write-Host "─" -NoNewline -ForegroundColor White
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor White
        
        # Table content
        for ($i = 0; $i -lt $networks.Count; $i++) {
            $network = $networks[$i]
            $signalStrength = $network.SignalStrength
            
            # Create signal strength bars
            $signalBars = ""
            if ($signalStrength -ge 75) { $signalBars = "████" }
            elseif ($signalStrength -ge 50) { $signalBars = "███░" }
            elseif ($signalStrength -ge 25) { $signalBars = "██░░" }
            elseif ($signalStrength -gt 0) { $signalBars = "█░░░" }
            else { $signalBars = "░░░░" }
            
            $signalText = "$signalBars $($signalStrength)%"
            $status = if ($network.IsConnectable) { "Available" } else { "Unavailable" }
            
            Write-Host "│ " -NoNewline -ForegroundColor Red
            Write-Host ("{0,-3}" -f ($i + 1)) -NoNewline -ForegroundColor Red
            Write-Host ("{0,-25}" -f $network.SSID) -NoNewline -ForegroundColor White
            Write-Host ("{0,-10}" -f $signalText) -NoNewline -ForegroundColor White
            Write-Host ("{0,-15}" -f $network.EncryptionType) -NoNewline -ForegroundColor White
            Write-Host ("{0,-10}" -f $status) -ForegroundColor White
        }
        
        # Table bottom border
        Write-Host "╰──────────────────────────────────────" -ForegroundColor Red
        Write-Host ""
    }
    catch {
        Write-Host "Unable to scan networks: $($_.Exception.Message)" -ForegroundColor Red
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

function Connect-WiFiNetwork {
    <#
    .SYNOPSIS
        Connect to a Wi-Fi network using NetworkManager
    #>
    param(
        [string]$SSID,
        [string]$Password
    )
    
    try {
        if ([string]::IsNullOrWhiteSpace($SSID)) {
            Write-Host "Error: SSID cannot be empty" -ForegroundColor Red
            return $false
        }
        
        Write-Host "Connecting to Wi-Fi network: '$SSID'..." -ForegroundColor Yellow
        
        # Initialize NetworkManager
        $networkConfig = @{
            AdapterScanInterval = 30
            MonitoringEnabled   = $false
        }
        $networkManager = New-Object NetworkManager -ArgumentList $networkConfig
        $networkManager.Initialize($networkConfig)
        
        # Check if already connected to this network
        $currentConnection = $networkManager.GetCurrentConnection()
        if ($currentConnection -and $currentConnection.SSID -eq $SSID) {
            Write-Host "Already connected to '$SSID'!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Connection Details:" -ForegroundColor Cyan
            Write-Host "  SSID: $($currentConnection.SSID)" -ForegroundColor White
            Write-Host "  Signal: $($currentConnection.SignalStrength)%" -ForegroundColor White
            Write-Host "  Encryption: $($currentConnection.EncryptionType)" -ForegroundColor White
            
            # Get IP information
            $privateIP = Get-WiFiPrivateIP
            if ($privateIP) {
                Write-Host "  Private IP: $privateIP" -ForegroundColor White
            }
            return $true
        }
        
        # Validate password if provided (skip validation for open networks)
        if (-not [string]::IsNullOrWhiteSpace($Password)) {
            # Try to find the network to get its security information
            $networks = $networkManager.ScanNetworks()
            $targetNetwork = $networks | Where-Object { $_.SSID -eq $SSID } | Select-Object -First 1
            
            if ($targetNetwork) {
                $passwordValidation = $networkManager.ValidatePassword($Password, $targetNetwork)
                if (-not $passwordValidation.IsValid) {
                    Write-Host "Invalid password: $($passwordValidation.ErrorMessage)" -ForegroundColor Red
                    return $false
                }
            }
        }
        
        # Attempt connection
        Write-Host "Attempting connection..." -ForegroundColor Yellow
        $connectionResult = $networkManager.AttemptConnection($SSID, $Password, 8)
        
        if ($connectionResult.Success) {
            Write-Host "Successfully connected to '$SSID'!" -ForegroundColor Green
            
            # Show connection details
            $currentConnection = $networkManager.GetCurrentConnection()
            if ($currentConnection) {
                Write-Host ""
                Write-Host "Connection Details:" -ForegroundColor Cyan
                Write-Host "  SSID: $($currentConnection.SSID)" -ForegroundColor White
                Write-Host "  Signal: $($currentConnection.SignalStrength)%" -ForegroundColor White
                Write-Host "  Encryption: $($currentConnection.EncryptionType)" -ForegroundColor White
                
                # Get IP information
                $privateIP = Get-WiFiPrivateIP
                if ($privateIP) {
                    Write-Host "  Private IP: $privateIP" -ForegroundColor White
                }
            }
            return $true
        }
        else {
            # Provide specific error messages based on the failure type
            if ($connectionResult.ErrorMessage -match "must be between 8 and 63 characters|must be at least 8 characters|WEP password must be") {
                Write-Host "Invalid password format: $($connectionResult.ErrorMessage)" -ForegroundColor Red
            }
            elseif ($connectionResult.ErrorMessage -match "authentication|password|credential") {
                Write-Host "Failed to connect to '$SSID' - Incorrect password" -ForegroundColor Red
                Write-Host "Please verify the password and try again." -ForegroundColor Yellow
            }
            elseif ($connectionResult.ErrorMessage -match "timeout") {
                Write-Host "Failed to connect to '$SSID' - Connection timeout" -ForegroundColor Red
                Write-Host "The network may be out of range or experiencing issues." -ForegroundColor Yellow
            }
            else {
                Write-Host "Failed to connect to '$SSID'" -ForegroundColor Red
                if ($connectionResult.ErrorMessage) {
                    Write-Host "Error: $($connectionResult.ErrorMessage)" -ForegroundColor Red
                }
            }
            return $false
        }
    }
    catch {
        Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-ParameterList {
    <#
    .SYNOPSIS
        Display concise list of all available parameters
    #>
    
    # Header with border
    Write-Host "╭─ " -ForegroundColor Red -NoNewline
    Write-Host "📋 Wifade - Quick Parameter Reference" -ForegroundColor Blue -NoNewline


    
    # QUICK ACTIONS Section
    Write-Host ""
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host ""
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "⚡ QUICK ACTIONS:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-IP" -ForegroundColor Red -NoNewline
    Write-Host "                         " -NoNewline
    Write-Host "Show current private IP address" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Status" -ForegroundColor Red -NoNewline
    Write-Host "                     " -NoNewline
    Write-Host "Show Wi-Fi connection status" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Scan" -ForegroundColor Red -NoNewline
    Write-Host "                       " -NoNewline
    Write-Host "List available Wi-Fi networks" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-PublicIP" -ForegroundColor Red -NoNewline
    Write-Host "                   " -NoNewline
    Write-Host "Show current public IP address" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Gateway" -ForegroundColor Red -NoNewline
    Write-Host "                    " -NoNewline
    Write-Host "Show default gateway IP" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-DNS" -ForegroundColor Red -NoNewline
    Write-Host "                        " -NoNewline
    Write-Host "Show DNS servers" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-MAC" -ForegroundColor Red -NoNewline
    Write-Host "                        " -NoNewline
    Write-Host "Show Wi-Fi adapter MAC address" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Speed" -ForegroundColor Red -NoNewline
    Write-Host "                      " -NoNewline
    Write-Host "Show connection speed" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Restart" -ForegroundColor Red -NoNewline
    Write-Host "                    " -NoNewline
    Write-Host "Restart Wi-Fi adapter" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # CONNECTION Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "🔗 CONNECTION:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Connect SSID password" -ForegroundColor Red -NoNewline
    Write-Host "      " -NoNewline
    Write-Host "Connect to Wi-Fi network" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "SSID password" -ForegroundColor Red -NoNewline
    Write-Host "               " -NoNewline
    Write-Host "Connect to Wi-Fi network (direct)" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # INTERACTIVE MODE Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "🎮 INTERACTIVE MODE:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "(no parameters)" -ForegroundColor Red -NoNewline
    Write-Host "             " -NoNewline
    Write-Host "Launch full interactive interface" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # CONFIGURATION Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "⚙️  CONFIGURATION:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-VerboseOutput, -v" -ForegroundColor Red -NoNewline
    Write-Host "          " -NoNewline
    Write-Host "Enable verbose output" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # BUILT-IN WORDLIST Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "📚 BUILT-IN WORDLIST:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "Default wordlist: " -ForegroundColor White -NoNewline
    Write-Host "passwords\probable-v2-wpa-top4800.txt" -ForegroundColor Red -NoNewline
    Write-Host " (4700+ common passwords)" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "Custom wordlists can be selected through the interactive Attack Mode menu" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # HELP Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "❓ HELP:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-Help, -h" -ForegroundColor Red -NoNewline
    Write-Host "                   " -NoNewline
    Write-Host "Show detailed help information" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host "-List" -ForegroundColor Red -NoNewline
    Write-Host "                       " -NoNewline
    Write-Host "Show this parameter list" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # EXAMPLES Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "💡 EXAMPLES:" -ForegroundColor Blue
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 -IP" -ForegroundColor Red -NoNewline
    Write-Host "                    " -NoNewline
    Write-Host "# Show IP address" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 -Scan" -ForegroundColor Red -NoNewline
    Write-Host "                  " -NoNewline
    Write-Host "# List networks" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 MyWiFi password123" -ForegroundColor Red -NoNewline
    Write-Host "     " -NoNewline
    Write-Host "# Connect to network" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host '.\wifade.ps1 "WiFi Name" password' -ForegroundColor Red -NoNewline
    Write-Host "   " -NoNewline
    Write-Host "# Connect (SSID with spaces)" -ForegroundColor White
    Write-Host "│   " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1" -ForegroundColor Red -NoNewline
    Write-Host "                        " -NoNewline
    Write-Host "# Launch interactive mode" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # Footer
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "For detailed help: " -ForegroundColor White -NoNewline
    Write-Host ".\wifade.ps1 -Help" -ForegroundColor Red
    Write-Host "╰────────────────────────────────────────────────────" -ForegroundColor Red
}

# Second Show-ParameterList function removed to fix duplicate function error

function Show-Help {
    <#
    .SYNOPSIS
        Display detailed help information with styled output
    #>
    
    Write-Host ""
    Write-Host "╭─ " -ForegroundColor Red -NoNewline
    Write-Host "📖 Wifade Help Documentation" -ForegroundColor Blue -NoNewline


    
    # USAGE Section
    Write-Host ""
    Write-Host ""
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "🚀 USAGE:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 [OPTIONS]" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # OPTIONS Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "⚙️  OPTIONS:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Help, -h" -ForegroundColor Red -NoNewline
    Write-Host "                   Display this help information" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-IP" -ForegroundColor Red -NoNewline
    Write-Host "                         Display current Wi-Fi private IP address and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Status" -ForegroundColor Red -NoNewline
    Write-Host "                     Display current Wi-Fi connection status and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Scan" -ForegroundColor Red -NoNewline
    Write-Host "                       Scan and list available Wi-Fi networks and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-PublicIP" -ForegroundColor Red -NoNewline
    Write-Host "                   Display current public IP address and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Gateway" -ForegroundColor Red -NoNewline
    Write-Host "                    Display default gateway IP address and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-DNS" -ForegroundColor Red -NoNewline
    Write-Host "                        Display DNS servers and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-MAC" -ForegroundColor Red -NoNewline
    Write-Host "                        Display Wi-Fi adapter MAC address and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Speed" -ForegroundColor Red -NoNewline
    Write-Host "                      Display Wi-Fi connection speed and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Restart" -ForegroundColor Red -NoNewline
    Write-Host "                    Restart Wi-Fi adapter and exit" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-Connect" -ForegroundColor Red -NoNewline
    Write-Host "                    Connect to Wi-Fi network (requires SSID and password)" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "-VerboseOutput, -v" -ForegroundColor Red -NoNewline
    Write-Host "          Enable verbose output mode" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # POSITIONAL PARAMETERS Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "📝 POSITIONAL PARAMETERS:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "SSID" -ForegroundColor Red -NoNewline
    Write-Host "                        Network name to connect to (use quotes for names with spaces)" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "Password" -ForegroundColor Red -NoNewline
    Write-Host "                    Network password" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # EXAMPLES Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "💡 EXAMPLES:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Run the tool" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 -IP" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Display current Wi-Fi private IP address and exit" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 -Status" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Display comprehensive Wi-Fi connection status and exit" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 -Scan" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Scan and list available Wi-Fi networks and exit" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 -Connect MyNetwork mypassword123" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Connect to Wi-Fi network using -Connect flag" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 MyNetwork mypassword123" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Connect to Wi-Fi network using positional parameters" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host ".\wifade.ps1 " -ForegroundColor Red -NoNewline
    Write-Host '"2nd Floor"' -ForegroundColor Red -NoNewline
    Write-Host " mypassword123" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "Connect to network with spaces in SSID (quotes required)" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # BUILT-IN WORDLIST Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "📚 BUILT-IN WORDLIST:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "Default wordlist: " -ForegroundColor White -NoNewline
    Write-Host "passwords\probable-v2-wpa-top4800.txt" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "Contains 4700+ most common Wi-Fi passwords for effective dictionary attacks" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # CUSTOM PASSWORD FILES Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "📄 CUSTOM PASSWORD FILES:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "Format: " -ForegroundColor White -NoNewline
    Write-Host "One password per line, plain text (.txt file)" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "Example content:" -ForegroundColor White
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "password123" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "12345678" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "qwerty123" -ForegroundColor Red
    Write-Host "│        " -ForegroundColor Red -NoNewline
    Write-Host "welcome123" -ForegroundColor Red
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "Custom wordlists can be selected through Attack Mode → Custom Password File" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # INTERACTIVE INTERFACE Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "🖥️  INTERACTIVE INTERFACE:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "The tool provides an interactive menu-driven interface with the following options:" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "1. Scan Wi-Fi Networks" -ForegroundColor Red -NoNewline
    Write-Host "   - Discover available Wi-Fi networks in range" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "2. Attack Mode" -ForegroundColor Red -NoNewline
    Write-Host "           - Choose the default dictionary or custom:" -ForegroundColor White
    Write-Host "│                              " -ForegroundColor Red -NoNewline
    Write-Host "• Dictionary Attack (uses built-in 4700+ password wordlist)" -ForegroundColor White
    Write-Host "│                              " -ForegroundColor Red -NoNewline
    Write-Host "• Custom Password File (select your own wordlist)" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "3. Settings" -ForegroundColor Red -NoNewline
    Write-Host "              - Configure application settings and preferences" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "4. Help" -ForegroundColor Red -NoNewline
    Write-Host "                  - Display this help page" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "q. Quit" -ForegroundColor Red -NoNewline
    Write-Host "                  - Exit the application" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # ETHICAL USAGE Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "⚖️  ETHICAL USAGE:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "This tool is intended for educational purposes and ethical security testing only." -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "IMPORTANT LEGAL NOTICE:" -ForegroundColor Red
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- Only test networks you own or have explicit written permission to test" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- Unauthorized access to computer networks is illegal in most jurisdictions" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- Users are solely responsible for compliance with applicable laws" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- The developer isn’t responsible for any misuse — if you do something shady, they’re out of the picture" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # SYSTEM REQUIREMENTS Section
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "💻 SYSTEM REQUIREMENTS:" -ForegroundColor Blue
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- Windows 10/11 or Linux/MacOS(Coming soon)" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- PowerShell 5.1 or PowerShell 7.x" -ForegroundColor White
    Write-Host "│    " -ForegroundColor Red -NoNewline
    Write-Host "- Administrator privileges (recommended)" -ForegroundColor White
    Write-Host "│" -ForegroundColor Red
    
    # Footer
    Write-Host "│ " -ForegroundColor Red -NoNewline
    Write-Host "For more information, visit: " -ForegroundColor White -NoNewline
    Write-Host "https://github.com/anonfaded/Wifade" -ForegroundColor Red
    Write-Host "╰────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Red
    Write-Host ""
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
        
        # Show parameter list if requested
        if ($List.IsPresent) {
            Show-ParameterList
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
            try {
                Get-WiFiStatus
            }
            catch {
                Write-Host "Unable to retrieve Wi-Fi status: $($_.Exception.Message)" -ForegroundColor Red
                exit 1
            }
            return
        }
        
        # Scan networks if requested
        if ($Scan.IsPresent) {
            try {
                Get-WiFiNetworks
            }
            catch {
                Write-Host "Unable to scan networks: $($_.Exception.Message)" -ForegroundColor Red
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
        
        # Connect to Wi-Fi network if requested
        if ($Connect.IsPresent -or $ConnectSSID) {
            if ([string]::IsNullOrWhiteSpace($ConnectSSID)) {
                Write-Host "Error: SSID is required for connection" -ForegroundColor Red
                Write-Host "Usage: .\wifade.ps1 -Connect 'SSID Name' 'password'" -ForegroundColor Yellow
                Write-Host "   or: .\wifade.ps1 'SSID Name' 'password'" -ForegroundColor Yellow
                exit 1
            }
            
            $success = Connect-WiFiNetwork -SSID $ConnectSSID -Password $ConnectPassword
            if (-not $success) {
                exit 1
            }
            return
        }
        
        # Build application configuration
        $appConfig = @{
            VerboseMode = $VerboseOutput.IsPresent
            PasswordFile = $PasswordFile
        }
        
        Write-Host "Starting wifade..." -ForegroundColor Green
        
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