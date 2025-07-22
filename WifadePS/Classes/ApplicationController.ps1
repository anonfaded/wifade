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
            Write-Host "[DEBUG] Step 1: Starting ApplicationController initialization..." -ForegroundColor Yellow
            
            # Apply configuration
            Write-Host "[DEBUG] Step 2: Applying configuration..." -ForegroundColor Yellow
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                $this.ApplyConfiguration($config)
            }
            Write-Host "[DEBUG] Step 2: Configuration applied successfully" -ForegroundColor Green
            
            # Initialize SettingsManager first
            Write-Host "[DEBUG] Step 3: Initializing SettingsManager..." -ForegroundColor Yellow
            try {
                $this.SettingsManager = New-Object SettingsManager
                $this.SettingsManager.Initialize(@{})
                Write-Host "[DEBUG] Step 3: SettingsManager initialized successfully" -ForegroundColor Green
            }
            catch {
                Write-Host "[DEBUG] Step 3: SettingsManager failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Warning "Could not initialize SettingsManager: $($_.Exception.Message)"
            }
            
            # Initialize UIManager with settings
            Write-Host "[DEBUG] Step 4: Preparing UIManager configuration..." -ForegroundColor Yellow
            $debugMode = $false
            $verboseMode = $false
            $colorScheme = @{}
            
            if ($null -ne $this.SettingsManager) {
                Write-Host "[DEBUG] Step 4a: Getting settings from SettingsManager..." -ForegroundColor Yellow
                try {
                    $debugMode = $this.SettingsManager.IsDebugMode()
                    $verboseMode = $this.SettingsManager.IsVerboseMode()
                    $colorScheme = $this.SettingsManager.GetColorScheme()
                    Write-Host "[DEBUG] Step 4a: Settings retrieved successfully" -ForegroundColor Green
                }
                catch {
                    Write-Host "[DEBUG] Step 4a: Failed to get settings: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Warning "Could not get settings: $($_.Exception.Message)"
                }
            }
            
            Write-Host "[DEBUG] Step 5: Creating UIManager..." -ForegroundColor Yellow
            $uiConfig = @{
                DebugMode   = $debugMode
                VerboseMode = $verboseMode
                ColorScheme = $colorScheme
            }
            try {
                $this.UIManager = New-Object UIManager -ArgumentList $uiConfig
                Write-Host "[DEBUG] Step 5a: UIManager object created" -ForegroundColor Green
                $this.UIManager.Initialize($uiConfig)
                Write-Host "[DEBUG] Step 5b: UIManager initialized successfully" -ForegroundColor Green
            }
            catch {
                Write-Host "[DEBUG] Step 5: UIManager failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "[DEBUG] Step 5: Full error: $($_.Exception)" -ForegroundColor Red
                Write-Warning "Could not initialize UIManager: $($_.Exception.Message)"
            }
            
            $this.IsInitialized = $true
            Write-Host "[DEBUG] Step 6: ApplicationController initialization completed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "[DEBUG] FATAL ERROR in Initialize: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[DEBUG] FATAL ERROR details: $($_.Exception)" -ForegroundColor Red
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
                    if ($this.SettingsManager.IsDebugMode()) {
                        $this.UIManager.ShowDebug("Stack trace: $($_.ScriptStackTrace)")
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
            "3" { $this.HandleViewResults() }
            "4" { $this.HandleSettings() }
            "5" { $this.HandleHelp() }
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
                    $displayName = if ($currentConnection.DisplayName) { $currentConnection.DisplayName } else { $currentConnection.SSID }
                    $this.UIManager.ShowSuccess("Currently connected to: $displayName (Signal: $($currentConnection.SignalStrength)%)")
                } else {
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
                        $displayName = if ($currentConnection.DisplayName) { $currentConnection.DisplayName } else { $currentConnection.SSID }
                        $this.UIManager.ShowSuccess("Currently connected to: $displayName (Signal: $($currentConnection.SignalStrength)%)")
                    } else {
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
                    Write-Host "  [d] Disconnect from current network" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [s] Show current connection status" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host "  [b] Back to main menu" -ForegroundColor $this.UIManager.ColorScheme.Secondary
                    Write-Host ""
                    
                    $choice = $this.UIManager.GetUserInput("Select an option", "^(\d+|[rRdDsSbB])$", "Please enter a valid option")
                    
                    switch ($choice.ToLower()) {
                        "r" {
                            $this.UIManager.ShowInfo("Rescanning networks...")
                            $networks = $this.NetworkManager.ScanNetworks($true)
                            $this.UIManager.ShowSuccess("Found $($networks.Count) networks after rescan")
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
                                } else {
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
                if ($this.SettingsManager.IsDebugMode()) {
                    $this.UIManager.ShowDebug("Error details: $($_.Exception)")
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
            $this.UIManager.ShowInfo("Attempting to connect to '$ssid'...")
            $this.UIManager.ShowInfo("This may take up to 15 seconds...")
            
            # Use NetworkManager's connection method with shorter timeout
            $connectionAttempt = $this.NetworkManager.AttemptConnection($ssid, $password, 15)
            
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
                    Write-Host "  Channel: $($currentConnection.Channel)" -ForegroundColor White
                }
            } else {
                $this.UIManager.ShowError("Failed to connect to '$ssid'")
                if ($connectionAttempt.ErrorMessage) {
                    $this.UIManager.ShowError("Error: $($connectionAttempt.ErrorMessage)")
                }
            }
            
        }
        catch {
            $this.UIManager.ShowError("Connection attempt failed: $($_.Exception.Message)")
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
            
            $displayName = if ($currentConnection.DisplayName) { $currentConnection.DisplayName } else { $currentConnection.SSID }
            $confirmed = $this.UIManager.GetConfirmation("Disconnect from '$displayName'?", $false)
            if ($confirmed) {
                $this.UIManager.ShowInfo("Disconnecting from '$($currentConnection.SSID)'...")
                
                $success = $this.NetworkManager.DisconnectFromNetwork()
                if ($success) {
                    $this.UIManager.ShowSuccess("Successfully disconnected from network")
                } else {
                    $this.UIManager.ShowError("Failed to disconnect from network")
                }
            }
        }
        catch {
            $this.UIManager.ShowError("Failed to disconnect: $($_.Exception.Message)")
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
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
                
                # Try to get saved password using both SSID and DisplayName
                $savedPassword = $this.NetworkManager.GetSavedPassword($currentConnection.SSID)
                if ([string]::IsNullOrWhiteSpace($savedPassword) -and $currentConnection.DisplayName) {
                    $savedPassword = $this.NetworkManager.GetSavedPassword($currentConnection.DisplayName)
                }
                
                if (-not [string]::IsNullOrWhiteSpace($savedPassword)) {
                    Write-Host "  Saved Password: $savedPassword" -ForegroundColor White
                } else {
                    Write-Host "  Saved Password: [Not available or open network]" -ForegroundColor Gray
                }
            } else {
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
                "2" { $this.HandleCustomAttack() }
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
        Write-Host "║                           DICTIONARY ATTACK                                  ║" -ForegroundColor Cyan
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
            
            # Network selection loop with rescan option
            do {
                # Display networks and let user select
                $this.UIManager.ShowNetworkList($networks)
                
                $networkChoice = $this.UIManager.GetUserInput("Enter network number to attack (1-$($networks.Count)), 'r' to rescan, or 'b' to go back", "^(\d+|[rRbB])$", "Please enter a valid network number, 'r' to rescan, or 'b' to go back")
                
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
            
            # Confirm attack
            $confirmed = $this.UIManager.GetConfirmation("Start dictionary attack on '$($targetNetwork.SSID)'?", $false)
            if (-not $confirmed) {
                $this.UIManager.ShowInfo("Attack cancelled.")
                $this.UIManager.WaitForKeyPress("Press any key to continue...")
                return
            }
            
            # Start dictionary attack
            $this.ExecuteDictionaryAttack($targetNetwork)
            
        }
        catch {
            $this.UIManager.ShowError("Dictionary attack failed: $($_.Exception.Message)")
            if ($this.SettingsManager.IsDebugMode()) {
                $this.UIManager.ShowDebug("Error details: $($_.Exception)")
            }
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    

    

    
    # Handle custom attack
    [void] HandleCustomAttack() {
        $this.UIManager.ClearScreen()
        $this.UIManager.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                            CUSTOM ATTACK                                     ║" -ForegroundColor Cyan
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
            
            # Network selection loop with rescan option
            do {
                # Display networks and let user select
                $this.UIManager.ShowNetworkList($networks)
                
                $networkChoice = $this.UIManager.GetUserInput("Enter network number to attack (1-$($networks.Count)), 'r' to rescan, or 'b' to go back", "^(\d+|[rRbB])$", "Please enter a valid network number, 'r' to rescan, or 'b' to go back")
                
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
            if ($this.SettingsManager.IsDebugMode()) {
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
                "1" { $this.HandleToggleDebug() }
                "2" { $this.HandleToggleStealth() }
                "3" { $this.HandleSetRateLimit() }
                "4" { $this.HandleConfigureFiles() }
                "5" { $this.HandleExportSettings() }
                "b" { return }
                default {
                    $this.UIManager.ShowWarning("Invalid option. Please try again.")
                    $this.UIManager.WaitForKeyPress("Press any key to continue...")
                }
            }
        } while ($true)
    }
    
    # Handle toggle debug mode
    [void] HandleToggleDebug() {
        $currentState = $this.SettingsManager.IsDebugMode()
        $newDebugState = $currentState -eq $false
        $this.SettingsManager.SetDebugMode($newDebugState)
        $this.UIManager.ToggleDebugMode()
        
        $newState = "disabled"
        if ($newDebugState -eq $true) {
            $newState = "enabled"
        }
        $this.UIManager.ShowSuccess("Debug mode $newState")
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle toggle stealth mode
    [void] HandleToggleStealth() {
        $currentState = $this.SettingsManager.IsStealthMode()
        $newStealthState = $currentState -eq $false
        $this.SettingsManager.SetStealthMode($newStealthState)
        
        $newState = "disabled"
        if ($newStealthState -eq $true) {
            $newState = "enabled"
        }
        $this.UIManager.ShowSuccess("Stealth mode $newState")
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle set rate limit
    [void] HandleSetRateLimit() {
        $currentLimit = $this.SettingsManager.GetRateLimit()
        $this.UIManager.ShowInfo("Current rate limit: $currentLimit ms")
        
        $newLimit = $this.UIManager.GetUserInput("Enter new rate limit (0-60000 ms)", "^\d+$", "Please enter a valid number")
        
        try {
            $this.SettingsManager.SetRateLimit([int]$newLimit)
            $this.UIManager.ShowSuccess("Rate limit set to $newLimit ms")
        }
        catch {
            $this.UIManager.ShowError("Failed to set rate limit: $($_.Exception.Message)")
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle configure files
    [void] HandleConfigureFiles() {
        $this.UIManager.ShowWarning("File configuration functionality is not yet implemented.")
        $this.UIManager.ShowInfo("This feature will be available in the next update.")
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
    # Handle export settings
    [void] HandleExportSettings() {
        $defaultPath = "wifadeps_settings_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $filePath = $this.UIManager.GetUserInput("Enter export file path", "", "")
        
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            $filePath = $defaultPath
        }
        
        try {
            $this.SettingsManager.ExportSettings($filePath)
            $this.UIManager.ShowSuccess("Settings exported to: $filePath")
        }
        catch {
            $this.UIManager.ShowError("Failed to export settings: $($_.Exception.Message)")
        }
        
        $this.UIManager.WaitForKeyPress("Press any key to continue...")
    }
    
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
                $passwordConfig = @{
                    PasswordFilePath = $this.AppConfig.PasswordFile
                    RateLimitEnabled = $this.AppConfig.StealthMode
                    MinDelayMs = $this.AppConfig.RateLimit
                    MaxDelayMs = $this.AppConfig.RateLimit * 2
                    AttackStrategy = [AttackStrategy]::Dictionary
                    StealthMode = $this.AppConfig.StealthMode
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
            $this.UIManager.ShowInfo("Starting dictionary attack on '$($targetNetwork.SSID)'...")
            
            # Reset password manager for new attack
            $this.PasswordManager.Reset()
            $this.PasswordManager.SetAttackStrategy([AttackStrategy]::Dictionary)
            
            $attemptCount = 0
            $maxAttempts = if ($this.AppConfig.MaxAttempts -gt 0) { $this.AppConfig.MaxAttempts } else { $this.PasswordManager.GetTotalPasswordCount() }
            $successfulConnection = $false
            
            $this.UIManager.ShowInfo("Total passwords to try: $maxAttempts")
            Write-Host ""
            
            # Attack loop
            while ($this.PasswordManager.HasMorePasswords() -and $attemptCount -lt $maxAttempts -and -not $successfulConnection) {
                try {
                    # Get next password
                    $password = $this.PasswordManager.GetNextPassword($targetNetwork.SSID)
                    if (-not $password) {
                        break
                    }
                    
                    $attemptCount++
                    
                    # Create connection attempt record
                    $attempt = [ConnectionAttempt]::new($targetNetwork.SSID, $password, $attemptCount)
                    $attempt.MarkAsStarted()
                    
                    # Show progress
                    $this.UIManager.ShowProgress($attemptCount, $maxAttempts, "Trying: $password")
                    
                    # Apply rate limiting if enabled
                    if ($this.AppConfig.StealthMode) {
                        $this.PasswordManager.ImplementRateLimiting()
                    }
                    
                    # Attempt connection (simulated for now - will be replaced with actual connection logic)
                    $connectionResult = $this.AttemptWiFiConnection($targetNetwork.SSID, $password)
                    
                    # Mark attempt as completed
                    $attempt.MarkAsCompleted($connectionResult.Success, $connectionResult.ErrorMessage)
                    
                    # Record attempt in statistics
                    $this.PasswordManager.RecordAttempt($attempt)
                    
                    if ($connectionResult.Success) {
                        $successfulConnection = $true
                        Write-Host ""
                        $this.UIManager.ShowSuccess("SUCCESS! Connected to '$($targetNetwork.SSID)' with password: '$password'")
                        break
                    } else {
                        if ($this.SettingsManager.IsDebugMode()) {
                            $this.UIManager.ShowDebug("Failed: $password - $($connectionResult.ErrorMessage)")
                        }
                    }
                }
                catch {
                    Write-Host ""
                    $this.UIManager.ShowError("Error during attempt $attemptCount : $($_.Exception.Message)")
                    if ($this.SettingsManager.IsDebugMode()) {
                        $this.UIManager.ShowDebug("Stack trace: $($_.ScriptStackTrace)")
                    }
                }
            }
            
            Write-Host ""
            
            # Show final results
            if ($successfulConnection) {
                $this.UIManager.ShowSuccess("Dictionary attack completed successfully!")
            } else {
                $this.UIManager.ShowWarning("Dictionary attack completed without success.")
                $this.UIManager.ShowInfo("Tried $attemptCount passwords.")
            }
            
            # Show statistics
            $stats = $this.PasswordManager.GetStatistics()
            Write-Host ""
            $this.UIManager.ShowInfo("Attack Statistics:")
            Write-Host $stats.GetSummary() -ForegroundColor White
            
        }
        catch {
            $this.UIManager.ShowError("Dictionary attack failed: $($_.Exception.Message)")
            throw
        }
    }
    

    
    # Attempt Wi-Fi connection (placeholder - will be enhanced with actual Windows networking)
    [hashtable] AttemptWiFiConnection([string]$ssid, [string]$password) {
        try {
            # This is a placeholder implementation
            # In the real implementation, this would use Windows networking APIs
            # For now, we'll simulate the connection attempt
            
            Start-Sleep -Milliseconds 500  # Simulate connection time
            
            # Simulate random success/failure for demonstration
            # In reality, this would attempt actual Wi-Fi connection
            $random = Get-Random -Minimum 1 -Maximum 100
            $success = $random -le 5  # 5% success rate for simulation
            
            $result = @{
                Success = $success
                ErrorMessage = if ($success) { "" } else { "Authentication failed" }
                Duration = [timespan]::FromMilliseconds(500)
            }
            
            return $result
        }
        catch {
            return @{
                Success = $false
                ErrorMessage = "Connection attempt failed: $($_.Exception.Message)"
                Duration = [timespan]::FromMilliseconds(500)
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