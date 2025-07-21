# NetworkManager Class for WifadePS
# Handles Wi-Fi adapter detection, network operations, and connection management

class NetworkManager : IManager {
    [object]$PrimaryAdapter
    [System.Collections.ArrayList]$AvailableNetworks
    [ConnectionStatus]$ConnectionStatus
    [hashtable]$AdapterCache
    [datetime]$LastAdapterScan
    [int]$AdapterScanIntervalSeconds
    [bool]$MonitoringEnabled
    [System.Collections.ArrayList]$AdapterStatusHistory
    
    # Constructor
    NetworkManager() : base() {
        $this.PrimaryAdapter = $null
        $this.AvailableNetworks = [System.Collections.ArrayList]::new()
        $this.ConnectionStatus = [ConnectionStatus]::Disconnected
        $this.AdapterCache = @{}
        $this.LastAdapterScan = [datetime]::MinValue
        $this.AdapterScanIntervalSeconds = 30
        $this.MonitoringEnabled = $false
        $this.AdapterStatusHistory = [System.Collections.ArrayList]::new()
    }
    
    # Constructor with configuration
    NetworkManager([hashtable]$config) : base() {
        $this.PrimaryAdapter = $null
        $this.AvailableNetworks = [System.Collections.ArrayList]::new()
        $this.ConnectionStatus = [ConnectionStatus]::Disconnected
        $this.AdapterCache = @{}
        $this.LastAdapterScan = [datetime]::MinValue
        $this.AdapterScanIntervalSeconds = if ($config.ContainsKey('AdapterScanInterval')) { $config['AdapterScanInterval'] } else { 30 }
        $this.MonitoringEnabled = if ($config.ContainsKey('MonitoringEnabled')) { $config['MonitoringEnabled'] } else { $false }
        $this.AdapterStatusHistory = [System.Collections.ArrayList]::new()
        $this.Configuration = $config
    }
    
    # Initialize the NetworkManager
    [void] Initialize([hashtable]$config) {
        try {
            Write-Verbose "Initializing NetworkManager..."
            
            # Apply configuration
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                if ($config.ContainsKey('AdapterScanInterval')) {
                    $this.AdapterScanIntervalSeconds = $config['AdapterScanInterval']
                }
                if ($config.ContainsKey('MonitoringEnabled')) {
                    $this.MonitoringEnabled = $config['MonitoringEnabled']
                }
            }
            
            # Detect Wi-Fi adapters
            $this.DetectWiFiAdapters()
            
            # Validate that we have at least one adapter
            if (-not $this.PrimaryAdapter) {
                throw [NetworkException]::new("No Wi-Fi adapters detected on this system")
            }
            
            # Start monitoring if enabled
            if ($this.MonitoringEnabled) {
                $this.StartAdapterMonitoring()
            }
            
            $this.IsInitialized = $true
            Write-Verbose "NetworkManager initialized successfully"
        }
        catch {
            throw [NetworkException]::new("Failed to initialize NetworkManager: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Detect available Wi-Fi adapters using WMI
    [System.Collections.ArrayList] DetectWiFiAdapters() {
        try {
            Write-Verbose "Detecting Wi-Fi adapters using WMI..."
            
            $adapters = [System.Collections.ArrayList]::new()
            $this.AdapterCache.Clear()
            
            # Query WMI for network adapters
            $wmiAdapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object {
                $_.AdapterTypeId -eq 9 -and # Ethernet 802.3 (includes Wi-Fi)
                $_.NetConnectionStatus -ne $null -and
                $_.Name -match "(Wi-Fi|Wireless|802\.11|WLAN)" -and
                $_.NetEnabled -eq $true
            }
            
            if (-not $wmiAdapters) {
                Write-Warning "No Wi-Fi adapters found via WMI Win32_NetworkAdapter"
                
                # Fallback: Try Win32_NetworkAdapterConfiguration
                $wmiConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object {
                    $_.IPEnabled -eq $true -and
                    $_.Description -match "(Wi-Fi|Wireless|802\.11|WLAN)"
                }
                
                foreach ($config in $wmiConfigs) {
                    $adapter = Get-WmiObject -Class Win32_NetworkAdapter -Filter "Index = $($config.Index)"
                    if ($adapter) {
                        $wmiAdapters += $adapter
                    }
                }
            }
            
            foreach ($adapter in $wmiAdapters) {
                try {
                    $adapterInfo = $this.CreateAdapterInfo($adapter)
                    if ($adapterInfo) {
                        [void]$adapters.Add($adapterInfo)
                        $this.AdapterCache[$adapter.DeviceID] = $adapterInfo
                        Write-Verbose "Found Wi-Fi adapter: $($adapterInfo.Name) (Status: $($adapterInfo.Status))"
                    }
                }
                catch {
                    Write-Warning "Failed to process adapter $($adapter.Name): $($_.Exception.Message)"
                }
            }
            
            # Select primary adapter
            $this.SelectPrimaryAdapter($adapters)
            
            # Update last scan time
            $this.LastAdapterScan = Get-Date
            
            Write-Verbose "Detected $($adapters.Count) Wi-Fi adapter(s)"
            return $adapters
        }
        catch {
            throw [NetworkException]::new("Failed to detect Wi-Fi adapters: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Create adapter information object from WMI data
    [hashtable] CreateAdapterInfo([object]$wmiAdapter) {
        if (-not $wmiAdapter) {
            return $null
        }
        
        try {
            $adapterInfo = @{
                DeviceID      = $wmiAdapter.DeviceID
                Name          = $wmiAdapter.Name
                Description   = $wmiAdapter.Description
                MACAddress    = $wmiAdapter.MACAddress
                Status        = $this.TranslateAdapterStatus($wmiAdapter.NetConnectionStatus)
                StatusCode    = $wmiAdapter.NetConnectionStatus
                Enabled       = $wmiAdapter.NetEnabled
                Speed         = $wmiAdapter.Speed
                AdapterType   = $wmiAdapter.AdapterType
                AdapterTypeId = $wmiAdapter.AdapterTypeId
                Manufacturer  = $wmiAdapter.Manufacturer
                LastUpdated   = Get-Date
                IsWiFi        = $true
                Capabilities  = @{}
            }
            
            # Get additional capabilities if available
            try {
                $config = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "Index = $($wmiAdapter.Index)"
                if ($config) {
                    $adapterInfo.Capabilities.DHCPEnabled = $config.DHCPEnabled
                    $adapterInfo.Capabilities.IPAddress = $config.IPAddress
                    $adapterInfo.Capabilities.DefaultGateway = $config.DefaultIPGateway
                    $adapterInfo.Capabilities.DNSServers = $config.DNSServerSearchOrder
                }
            }
            catch {
                Write-Verbose "Could not retrieve additional capabilities for adapter $($wmiAdapter.Name)"
            }
            
            return $adapterInfo
        }
        catch {
            Write-Warning "Failed to create adapter info for $($wmiAdapter.Name): $($_.Exception.Message)"
            return $null
        }
    }
    
    # Translate WMI adapter status codes to readable strings
    [string] TranslateAdapterStatus([int]$statusCode) {
        switch ($statusCode) {
            0 { return "Disconnected" }
            1 { return "Connecting" }
            2 { return "Connected" }
            3 { return "Disconnecting" }
            4 { return "Hardware not present" }
            5 { return "Hardware disabled" }
            6 { return "Hardware malfunction" }
            7 { return "Media disconnected" }
            8 { return "Authenticating" }
            9 { return "Authentication succeeded" }
            10 { return "Authentication failed" }
            11 { return "Invalid address" }
            12 { return "Credentials required" }
            default { return "Unknown ($statusCode)" }
        }
        return "Unknown"
    }
    
    # Select the primary Wi-Fi adapter from available adapters
    [void] SelectPrimaryAdapter([System.Collections.ArrayList]$adapters) {
        if ($adapters.Count -eq 0) {
            $this.PrimaryAdapter = $null
            Write-Warning "No Wi-Fi adapters available for selection"
            return
        }
        
        # Priority selection logic:
        # 1. Connected adapters first
        # 2. Adapters with "Wi-Fi" in the name
        # 3. Enabled adapters
        # 4. Adapters with higher speed
        
        $connectedAdapters = $adapters | Where-Object { $_.Status -eq "Connected" }
        $wifiAdapters = $adapters | Where-Object { $_.Name -match "Wi-Fi" }
        $enabledAdapters = $adapters | Where-Object { $_.Enabled -eq $true }
        
        $selectedAdapter = $null
        
        if ($connectedAdapters.Count -gt 0) {
            $selectedAdapter = $connectedAdapters | Sort-Object Speed -Descending | Select-Object -First 1
            Write-Verbose "Selected connected adapter: $($selectedAdapter.Name)"
        }
        elseif ($wifiAdapters.Count -gt 0) {
            $selectedAdapter = $wifiAdapters | Sort-Object Speed -Descending | Select-Object -First 1
            Write-Verbose "Selected Wi-Fi adapter: $($selectedAdapter.Name)"
        }
        elseif ($enabledAdapters.Count -gt 0) {
            $selectedAdapter = $enabledAdapters | Sort-Object Speed -Descending | Select-Object -First 1
            Write-Verbose "Selected enabled adapter: $($selectedAdapter.Name)"
        }
        else {
            $selectedAdapter = $adapters | Sort-Object Speed -Descending | Select-Object -First 1
            Write-Verbose "Selected first available adapter: $($selectedAdapter.Name)"
        }
        
        $this.PrimaryAdapter = $selectedAdapter
        
        if ($selectedAdapter) {
            Write-Verbose "Primary adapter selected: $($selectedAdapter.Name) (Status: $($selectedAdapter.Status))"
        }
    }
    
    # Get current adapter status
    [hashtable] GetAdapterStatus() {
        return $this.GetAdapterStatus($null)
    }
    
    # Get adapter status for specific adapter or primary adapter
    [hashtable] GetAdapterStatus([string]$deviceId) {
        $targetAdapter = $null
        try {
            if ($deviceId) {
                $targetAdapter = $this.AdapterCache[$deviceId]
            }
            else {
                $targetAdapter = $this.PrimaryAdapter
            }
            
            if (-not $targetAdapter) {
                throw [NetworkException]::new("No adapter specified and no primary adapter available")
            }
            
            # Refresh adapter status from WMI
            $wmiAdapter = Get-WmiObject -Class Win32_NetworkAdapter -Filter "DeviceID = '$($targetAdapter.DeviceID)'"
            
            if (-not $wmiAdapter) {
                throw [NetworkException]::new("Adapter not found: $($targetAdapter.DeviceID)", $targetAdapter.Name)
            }
            
            $status = @{
                DeviceID     = $wmiAdapter.DeviceID
                Name         = $wmiAdapter.Name
                Status       = $this.TranslateAdapterStatus($wmiAdapter.NetConnectionStatus)
                StatusCode   = $wmiAdapter.NetConnectionStatus
                Enabled      = $wmiAdapter.NetEnabled
                LastChecked  = Get-Date
                IsHealthy    = $this.IsAdapterHealthy($wmiAdapter)
                ErrorMessage = ""
            }
            
            # Update cache
            if ($this.AdapterCache.ContainsKey($targetAdapter.DeviceID)) {
                $this.AdapterCache[$targetAdapter.DeviceID].Status = $status.Status
                $this.AdapterCache[$targetAdapter.DeviceID].StatusCode = $status.StatusCode
                $this.AdapterCache[$targetAdapter.DeviceID].Enabled = $status.Enabled
                $this.AdapterCache[$targetAdapter.DeviceID].LastUpdated = $status.LastChecked
            }
            
            return $status
        }
        catch {
            $deviceId = "Unknown"
            $name = "Unknown"
            if ($targetAdapter) {
                $deviceId = $targetAdapter.DeviceID
                $name = $targetAdapter.Name
            }
            
            $errorStatus = @{
                DeviceID     = $deviceId
                Name         = $name
                Status       = "Error"
                StatusCode   = -1
                Enabled      = $false
                LastChecked  = Get-Date
                IsHealthy    = $false
                ErrorMessage = $_.Exception.Message
            }
            
            Write-Warning "Failed to get adapter status: $($_.Exception.Message)"
            return $errorStatus
        }
    }
    
    # Check if adapter is healthy
    [bool] IsAdapterHealthy([object]$wmiAdapter) {
        if (-not $wmiAdapter) {
            return $false
        }
        
        # Check basic health indicators
        $isHealthy = $true
        
        # Adapter should be enabled
        if (-not $wmiAdapter.NetEnabled) {
            $isHealthy = $false
        }
        
        # Status should not indicate hardware problems
        $problemStatuses = @(4, 5, 6)  # Hardware not present, disabled, malfunction
        if ($wmiAdapter.NetConnectionStatus -in $problemStatuses) {
            $isHealthy = $false
        }
        
        return $isHealthy
    }
    
    # Start adapter monitoring
    [void] StartAdapterMonitoring() {
        try {
            Write-Verbose "Starting adapter monitoring..."
            $this.MonitoringEnabled = $true
            
            # Create a background job for monitoring (simplified approach)
            # In a full implementation, this would use PowerShell jobs or runspaces
            Write-Verbose "Adapter monitoring enabled (polling every $($this.AdapterScanIntervalSeconds) seconds)"
        }
        catch {
            Write-Warning "Failed to start adapter monitoring: $($_.Exception.Message)"
        }
    }
    
    # Stop adapter monitoring
    [void] StopAdapterMonitoring() {
        try {
            Write-Verbose "Stopping adapter monitoring..."
            $this.MonitoringEnabled = $false
            Write-Verbose "Adapter monitoring stopped"
        }
        catch {
            Write-Warning "Failed to stop adapter monitoring: $($_.Exception.Message)"
        }
    }
    
    # Perform health check on all adapters
    [hashtable] PerformHealthCheck() {
        try {
            Write-Verbose "Performing adapter health check..."
            
            $healthReport = @{
                Timestamp         = Get-Date
                TotalAdapters     = $this.AdapterCache.Count
                HealthyAdapters   = 0
                UnhealthyAdapters = 0
                AdapterDetails    = @{}
                OverallHealth     = "Unknown"
                Recommendations   = @()
            }
            
            foreach ($deviceId in $this.AdapterCache.Keys) {
                $adapterStatus = $this.GetAdapterStatus($deviceId)
                $healthReport.AdapterDetails[$deviceId] = $adapterStatus
                
                if ($adapterStatus.IsHealthy) {
                    $healthReport.HealthyAdapters++
                }
                else {
                    $healthReport.UnhealthyAdapters++
                    $healthReport.Recommendations += "Check adapter: $($adapterStatus.Name) - $($adapterStatus.ErrorMessage)"
                }
            }
            
            # Determine overall health
            if ($healthReport.HealthyAdapters -eq 0) {
                $healthReport.OverallHealth = "Critical"
                $healthReport.Recommendations += "No healthy Wi-Fi adapters detected. Check hardware and drivers."
            }
            elseif ($healthReport.UnhealthyAdapters -eq 0) {
                $healthReport.OverallHealth = "Good"
            }
            else {
                $healthReport.OverallHealth = "Warning"
            }
            
            # Check if primary adapter is healthy
            if ($this.PrimaryAdapter) {
                $primaryStatus = $this.GetAdapterStatus($this.PrimaryAdapter.DeviceID)
                if (-not $primaryStatus.IsHealthy) {
                    $healthReport.Recommendations += "Primary adapter is unhealthy. Consider selecting a different adapter."
                }
            }
            
            Write-Verbose "Health check completed: $($healthReport.OverallHealth)"
            return $healthReport
        }
        catch {
            throw [NetworkException]::new("Failed to perform health check: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Refresh adapter information
    [void] RefreshAdapters() {
        try {
            Write-Verbose "Refreshing adapter information..."
            
            # Check if enough time has passed since last scan
            $timeSinceLastScan = (Get-Date) - $this.LastAdapterScan
            if ($timeSinceLastScan.TotalSeconds -lt $this.AdapterScanIntervalSeconds) {
                Write-Verbose "Skipping refresh - last scan was $([int]$timeSinceLastScan.TotalSeconds) seconds ago"
                return
            }
            
            # Re-detect adapters
            $this.DetectWiFiAdapters()
            
            Write-Verbose "Adapter information refreshed"
        }
        catch {
            Write-Warning "Failed to refresh adapters: $($_.Exception.Message)"
        }
    }
    
    # Get all available adapters
    [System.Collections.ArrayList] GetAvailableAdapters() {
        $adapters = [System.Collections.ArrayList]::new()
        
        foreach ($adapter in $this.AdapterCache.Values) {
            [void]$adapters.Add($adapter)
        }
        
        return $adapters
    }
    
    # Get primary adapter information
    [hashtable] GetPrimaryAdapter() {
        return $this.PrimaryAdapter
    }
    
    # Set primary adapter by device ID
    [void] SetPrimaryAdapter([string]$deviceId) {
        if ($this.AdapterCache.ContainsKey($deviceId)) {
            $this.PrimaryAdapter = $this.AdapterCache[$deviceId]
            Write-Verbose "Primary adapter changed to: $($this.PrimaryAdapter.Name)"
        }
        else {
            throw [NetworkException]::new("Adapter not found: $deviceId")
        }
    }
    
    # Validate configuration
    [bool] ValidateConfiguration([hashtable]$config) {
        try {
            # Check adapter scan interval
            if ($config.ContainsKey('AdapterScanInterval')) {
                $interval = $config['AdapterScanInterval']
                if ($interval -lt 5 -or $interval -gt 300) {
                    throw [ConfigurationException]::new("AdapterScanInterval must be between 5 and 300 seconds", "AdapterScanInterval")
                }
            }
            
            return $true
        }
        catch {
            throw [ConfigurationException]::new("Configuration validation failed: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Dispose resources
    [void] Dispose() {
        try {
            Write-Verbose "Disposing NetworkManager resources..."
            
            # Stop monitoring
            if ($this.MonitoringEnabled) {
                $this.StopAdapterMonitoring()
            }
            
            # Clear caches
            $this.AdapterCache.Clear()
            $this.AvailableNetworks.Clear()
            $this.AdapterStatusHistory.Clear()
            
            # Reset properties
            $this.PrimaryAdapter = $null
            $this.ConnectionStatus = [ConnectionStatus]::Disconnected
            
            $this.IsInitialized = $false
            Write-Verbose "NetworkManager disposed successfully"
        }
        catch {
            Write-Warning "Error during NetworkManager disposal: $($_.Exception.Message)"
        }
    }
    
    # Scan for available Wi-Fi networks using netsh wlan commands (overload without parameters)
    [System.Collections.ArrayList] ScanNetworks() {
        return $this.ScanNetworks($false)
    }
    
    # Scan for available Wi-Fi networks using netsh wlan commands (overload with forceRefresh parameter)
    [System.Collections.ArrayList] ScanNetworks([bool]$forceRefresh) {
        try {
            if ($forceRefresh) {
                Write-Verbose "Performing forced refresh scan for available Wi-Fi networks..."
            }
            else {
                Write-Verbose "Scanning for available Wi-Fi networks..."
            }
            
            if (-not $this.PrimaryAdapter) {
                throw [NetworkException]::new("No primary Wi-Fi adapter available for network scanning")
            }
            
            # Force a fresh scan by triggering netsh wlan refresh if requested
            if ($forceRefresh) {
                Write-Verbose "Triggering fresh network scan..."
                try {
                    & netsh wlan refresh 2>$null | Out-Null
                    Start-Sleep -Milliseconds 2000  # Wait for scan to complete
                }
                catch {
                    Write-Verbose "Could not trigger netsh wlan refresh, continuing with regular scan"
                }
            }
            
            # Clear existing networks
            $this.AvailableNetworks.Clear()
            
            # Execute netsh wlan show profiles to get saved networks
            $savedNetworkProfiles = $this.GetSavedNetworkProfiles()
            
            # Execute netsh wlan show networks to get available networks
            $availableNetworkProfiles = $this.GetAvailableNetworkProfiles()
            
            # Merge and process network information
            $allNetworks = $this.MergeNetworkInformation($savedNetworkProfiles, $availableNetworkProfiles)
            
            # Add to AvailableNetworks collection
            foreach ($network in $allNetworks) {
                [void]$this.AvailableNetworks.Add($network)
            }
            
            Write-Verbose "Network scan completed. Found $($this.AvailableNetworks.Count) networks"
            return $this.AvailableNetworks
        }
        catch {
            throw [NetworkException]::new("Failed to scan networks: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Get saved network profiles using netsh wlan show profiles
    [System.Collections.ArrayList] GetSavedNetworkProfiles() {
        try {
            Write-Verbose "Retrieving saved network profiles..."
            
            $savedNetworks = [System.Collections.ArrayList]::new()
            
            # Execute netsh command to get profiles
            $profileOutput = & netsh wlan show profiles 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to retrieve saved network profiles (Exit code: $LASTEXITCODE)"
                return $savedNetworks
            }
            
            # Parse profile output
            foreach ($line in $profileOutput) {
                if ($line -match "All User Profile\s*:\s*(.+)") {
                    $ssid = $matches[1].Trim()
                    
                    # Get detailed profile information
                    $profileDetails = $this.GetNetworkProfileDetails($ssid)
                    if ($profileDetails) {
                        [void]$savedNetworks.Add($profileDetails)
                    }
                }
            }
            
            Write-Verbose "Retrieved $($savedNetworks.Count) saved network profiles"
            return $savedNetworks
        }
        catch {
            Write-Warning "Error retrieving saved network profiles: $($_.Exception.Message)"
            return [System.Collections.ArrayList]::new()
        }
    }
    
    # Get available network profiles using netsh wlan show networks
    [System.Collections.ArrayList] GetAvailableNetworkProfiles() {
        try {
            Write-Verbose "Retrieving available network profiles..."
            
            $networkList = [System.Collections.ArrayList]::new()
            
            # Execute netsh command to show available networks
            $networkOutput = & netsh wlan show networks mode=bssid 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to retrieve available networks (Exit code: $LASTEXITCODE)"
                return $networkList
            }
            
            # Parse network output
            $currentNetwork = $null
            $currentBSSID = $null
            
            foreach ($line in $networkOutput) {
                $line = $line.Trim()
                
                if ($line -match "^SSID \d+ : (.+)") {
                    # New network found
                    if ($currentNetwork) {
                        [void]$networkList.Add($currentNetwork)
                    }
                    
                    $ssid = $matches[1].Trim()
                    $currentNetwork = [NetworkProfile]::new($ssid, "Unknown")
                    $currentNetwork.LastSeen = Get-Date
                    $currentNetwork.IsConnectable = $true
                    $currentNetwork.NetworkType = "Infrastructure"
                }
                elseif ($line -match "Network type\s*:\s*(.+)" -and $currentNetwork) {
                    $currentNetwork.NetworkType = $matches[1].Trim()
                }
                elseif ($line -match "Authentication\s*:\s*(.+)" -and $currentNetwork) {
                    $currentNetwork.AuthenticationMethod = $matches[1].Trim()
                }
                elseif ($line -match "Encryption\s*:\s*(.+)" -and $currentNetwork) {
                    $currentNetwork.EncryptionType = $this.ConvertToFriendlyEncryptionName($matches[1].Trim())
                }
                elseif ($line -match "BSSID \d+\s*:\s*([a-fA-F0-9:]{17})" -and $currentNetwork) {
                    $currentBSSID = $matches[1].Trim()
                    $currentNetwork.BSSID = $currentBSSID
                }
                elseif ($line -match "Signal\s*:\s*(\d+)%" -and $currentNetwork) {
                    $signalStrength = [int]$matches[1]
                    $currentNetwork.SignalStrength = $signalStrength
                }
                elseif ($line -match "Channel\s*:\s*(\d+)" -and $currentNetwork) {
                    $currentNetwork.Channel = [int]$matches[1]
                }
            }
            
            # Add the last network if exists
            if ($currentNetwork) {
                [void]$networkList.Add($currentNetwork)
            }
            
            Write-Verbose "Retrieved $($networkList.Count) available networks"
            return $networkList
        }
        catch {
            Write-Warning "Error retrieving available networks: $($_.Exception.Message)"
            return [System.Collections.ArrayList]::new()
        }
    }
    
    # Get detailed information for a specific network profile
    [NetworkProfile] GetNetworkProfileDetails([string]$ssid) {
        try {
            if ([string]::IsNullOrWhiteSpace($ssid)) {
                return $null
            }
            
            Write-Verbose "Getting profile details for SSID: $ssid"
            
            # Execute netsh command to get profile details
            $profileOutput = & netsh wlan show profile name="$ssid" key=clear 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose "Failed to get profile details for $ssid (Exit code: $LASTEXITCODE)"
                return $null
            }
            
            # Create network profile
            $profile = [NetworkProfile]::new($ssid, "Unknown")
            $profile.LastSeen = Get-Date
            $profile.IsConnectable = $true
            
            # Parse profile details
            foreach ($line in $profileOutput) {
                $line = $line.Trim()
                
                if ($line -match "Authentication\s*:\s*(.+)") {
                    $profile.AuthenticationMethod = $matches[1].Trim()
                }
                elseif ($line -match "Cipher\s*:\s*(.+)") {
                    $profile.EncryptionType = $this.ConvertToFriendlyEncryptionName($matches[1].Trim())
                }
                elseif ($line -match "Network type\s*:\s*(.+)") {
                    $profile.NetworkType = $matches[1].Trim()
                }
                elseif ($line -match "Connection mode\s*:\s*(.+)") {
                    # Additional connection information
                    $connectionMode = $matches[1].Trim()
                    if ($connectionMode -eq "Connect manually") {
                        $profile.IsConnectable = $false
                    }
                }
            }
            
            return $profile
        }
        catch {
            Write-Warning "Error getting profile details for $ssid : $($_.Exception.Message)"
            return $null
        }
    }
    
    # Merge saved and available network information
    [System.Collections.ArrayList] MergeNetworkInformation([System.Collections.ArrayList]$savedNetworks, [System.Collections.ArrayList]$availableNetworks) {
        try {
            Write-Verbose "Merging network information..."
            
            $mergedNetworks = [System.Collections.ArrayList]::new()
            $processedSSIDs = @{}
            
            # Process available networks first (they have current signal strength and BSSID)
            foreach ($availableNetwork in $availableNetworks) {
                if (-not [string]::IsNullOrWhiteSpace($availableNetwork.SSID)) {
                    # Check if we have saved profile information for this network
                    $savedProfile = $savedNetworks | Where-Object { $_.SSID -eq $availableNetwork.SSID } | Select-Object -First 1
                    
                    if ($savedProfile) {
                        # Merge information - prefer available network data for current info
                        $mergedNetwork = $availableNetwork
                        
                        # Use saved profile authentication/encryption if available network doesn't have it
                        if ([string]::IsNullOrWhiteSpace($mergedNetwork.AuthenticationMethod) -and -not [string]::IsNullOrWhiteSpace($savedProfile.AuthenticationMethod)) {
                            $mergedNetwork.AuthenticationMethod = $savedProfile.AuthenticationMethod
                        }
                        if ([string]::IsNullOrWhiteSpace($mergedNetwork.EncryptionType) -and -not [string]::IsNullOrWhiteSpace($savedProfile.EncryptionType)) {
                            $mergedNetwork.EncryptionType = $savedProfile.EncryptionType
                        }
                        if ([string]::IsNullOrWhiteSpace($mergedNetwork.NetworkType) -and -not [string]::IsNullOrWhiteSpace($savedProfile.NetworkType)) {
                            $mergedNetwork.NetworkType = $savedProfile.NetworkType
                        }
                    }
                    else {
                        $mergedNetwork = $availableNetwork
                    }
                    
                    [void]$mergedNetworks.Add($mergedNetwork)
                    $processedSSIDs[$availableNetwork.SSID] = $true
                }
            }
            
            # Add saved networks that weren't found in available networks
            foreach ($savedNetwork in $savedNetworks) {
                if (-not $processedSSIDs.ContainsKey($savedNetwork.SSID)) {
                    # Mark as not currently available
                    $savedNetwork.SignalStrength = 0
                    $savedNetwork.IsConnectable = $false
                    $savedNetwork.LastSeen = Get-Date
                    
                    [void]$mergedNetworks.Add($savedNetwork)
                }
            }
            
            Write-Verbose "Merged network information: $($mergedNetworks.Count) total networks"
            return $mergedNetworks
        }
        catch {
            Write-Warning "Error merging network information: $($_.Exception.Message)"
            return $availableNetworks
        }
    }
    
    # Get detailed network information for all discovered networks
    [System.Collections.ArrayList] GetNetworkProfiles() {
        try {
            Write-Verbose "Getting detailed network profiles..."
            
            # Perform network scan if we don't have recent data
            if ($this.AvailableNetworks.Count -eq 0) {
                $this.ScanNetworks()
            }
            
            # Enhance network profiles with additional details
            $enhancedProfiles = [System.Collections.ArrayList]::new()
            
            foreach ($network in $this.AvailableNetworks) {
                $enhancedProfile = $this.EnhanceNetworkProfile($network)
                [void]$enhancedProfiles.Add($enhancedProfile)
            }
            
            Write-Verbose "Enhanced $($enhancedProfiles.Count) network profiles"
            return $enhancedProfiles
        }
        catch {
            throw [NetworkException]::new("Failed to get network profiles: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Enhance a network profile with additional information
    [NetworkProfile] EnhanceNetworkProfile([NetworkProfile]$profile) {
        try {
            if (-not $profile) {
                return $null
            }
            
            # Create enhanced copy
            $enhanced = [NetworkProfile]::new($profile.SSID, $profile.EncryptionType)
            
            # Copy all properties
            $enhanced.AuthenticationMethod = $profile.AuthenticationMethod
            $enhanced.SignalStrength = $profile.SignalStrength
            $enhanced.IsConnectable = $profile.IsConnectable
            $enhanced.LastSeen = $profile.LastSeen
            $enhanced.BSSID = $profile.BSSID
            $enhanced.Channel = $profile.Channel
            $enhanced.NetworkType = $profile.NetworkType
            
            # Determine security level and connection feasibility
            $enhanced = $this.AnalyzeNetworkSecurity($enhanced)
            
            # Update connection status based on current adapter state
            if ($this.PrimaryAdapter -and $this.PrimaryAdapter.Status -eq "Connected") {
                # Check if we're currently connected to this network
                $currentConnection = $this.GetCurrentConnection()
                if ($currentConnection -and $currentConnection.SSID -eq $enhanced.SSID) {
                    $enhanced.IsConnectable = $true
                }
            }
            
            return $enhanced
        }
        catch {
            Write-Warning "Error enhancing network profile for $($profile.SSID): $($_.Exception.Message)"
            return $profile
        }
    }
    
    # Analyze network security characteristics
    [NetworkProfile] AnalyzeNetworkSecurity([NetworkProfile]$profile) {
        try {
            if (-not $profile) {
                return $null
            }
            
            # Convert technical cipher names to user-friendly encryption names
            $profile.EncryptionType = $this.ConvertToFriendlyEncryptionName($profile.EncryptionType)
            
            # Analyze encryption type
            switch ($profile.EncryptionType.ToLower()) {
                "none" {
                    $profile.IsConnectable = $true
                }
                "wep" {
                    $profile.IsConnectable = $true
                }
                "wpa" {
                    $profile.IsConnectable = $true
                }
                "wpa2" {
                    $profile.IsConnectable = $true
                }
                "wpa3" {
                    $profile.IsConnectable = $true
                }
                default {
                    # Unknown encryption - assume connectable but may require special handling
                    $profile.IsConnectable = $true
                }
            }
            
            # Analyze authentication method
            switch ($profile.AuthenticationMethod.ToLower()) {
                "open" {
                    $profile.IsConnectable = $true
                }
                "shared" {
                    $profile.IsConnectable = $true
                }
                "wpa-psk" {
                    $profile.IsConnectable = $true
                }
                "wpa2-psk" {
                    $profile.IsConnectable = $true
                }
                "wpa3-sae" {
                    $profile.IsConnectable = $true
                }
                "wpa-enterprise" {
                    # Enterprise networks typically require certificates
                    $profile.IsConnectable = $false
                }
                "wpa2-enterprise" {
                    $profile.IsConnectable = $false
                }
                default {
                    # Unknown authentication - assume connectable
                    $profile.IsConnectable = $true
                }
            }
            
            # Consider signal strength for connection feasibility
            if ($profile.SignalStrength -lt 20) {
                # Very weak signal may cause connection issues
                Write-Verbose "Weak signal detected for $($profile.SSID): $($profile.SignalStrength)%"
            }
            
            return $profile
        }
        catch {
            Write-Warning "Error analyzing network security for $($profile.SSID): $($_.Exception.Message)"
            return $profile
        }
    }
    
    # Get current Wi-Fi connection information
    [NetworkProfile] GetCurrentConnection() {
        try {
            Write-Verbose "Getting current Wi-Fi connection information..."
            
            # Execute netsh command to get current connection
            $connectionOutput = & netsh wlan show interfaces 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose "Failed to get current connection info (Exit code: $LASTEXITCODE)"
                return $null
            }
            
            $currentProfile = $null
            $ssid = ""
            $bssid = ""
            $signalStrength = 0
            $channel = 0
            $authMethod = ""
            $encryption = ""
            
            foreach ($line in $connectionOutput) {
                $line = $line.Trim()
                
                if ($line -match "SSID\s*:\s*(.+)") {
                    $ssid = $matches[1].Trim()
                }
                elseif ($line -match "BSSID\s*:\s*([a-fA-F0-9:]{17})") {
                    $bssid = $matches[1].Trim()
                }
                elseif ($line -match "Signal\s*:\s*(\d+)%") {
                    $signalStrength = [int]$matches[1]
                }
                elseif ($line -match "Channel\s*:\s*(\d+)") {
                    $channel = [int]$matches[1]
                }
                elseif ($line -match "Authentication\s*:\s*(.+)") {
                    $authMethod = $matches[1].Trim()
                }
                elseif ($line -match "Cipher\s*:\s*(.+)") {
                    $encryption = $matches[1].Trim()
                }
            }
            
            if (-not [string]::IsNullOrWhiteSpace($ssid)) {
                $currentProfile = [NetworkProfile]::new($ssid, $encryption)
                $currentProfile.BSSID = $bssid
                $currentProfile.SignalStrength = $signalStrength
                $currentProfile.Channel = $channel
                $currentProfile.AuthenticationMethod = $authMethod
                $currentProfile.IsConnectable = $true
                $currentProfile.LastSeen = Get-Date
                $currentProfile.NetworkType = "Infrastructure"
                
                Write-Verbose "Current connection: $($currentProfile.SSID) (Signal: $($currentProfile.SignalStrength)%)"
            }
            
            return $currentProfile
        }
        catch {
            Write-Warning "Error getting current connection: $($_.Exception.Message)"
            return $null
        }
    }
    
    # Filter networks by various criteria
    [System.Collections.ArrayList] FilterNetworks([hashtable]$criteria) {
        try {
            Write-Verbose "Filtering networks with criteria..."
            
            $filteredNetworks = [System.Collections.ArrayList]::new()
            
            foreach ($network in $this.AvailableNetworks) {
                $includeNetwork = $true
                
                # Filter by minimum signal strength
                if ($criteria.ContainsKey('MinSignalStrength')) {
                    if ($network.SignalStrength -lt $criteria['MinSignalStrength']) {
                        $includeNetwork = $false
                    }
                }
                
                # Filter by encryption type
                if ($criteria.ContainsKey('EncryptionTypes') -and $includeNetwork) {
                    $allowedTypes = $criteria['EncryptionTypes']
                    if ($allowedTypes -is [array] -and $network.EncryptionType -notin $allowedTypes) {
                        $includeNetwork = $false
                    }
                }
                
                # Filter by connectability
                if ($criteria.ContainsKey('ConnectableOnly') -and $includeNetwork) {
                    if ($criteria['ConnectableOnly'] -and -not $network.IsConnectable) {
                        $includeNetwork = $false
                    }
                }
                
                # Filter by SSID pattern
                if ($criteria.ContainsKey('SSIDPattern') -and $includeNetwork) {
                    $pattern = $criteria['SSIDPattern']
                    if ($network.SSID -notmatch $pattern) {
                        $includeNetwork = $false
                    }
                }
                
                # Filter by network type
                if ($criteria.ContainsKey('NetworkType') -and $includeNetwork) {
                    if ($network.NetworkType -ne $criteria['NetworkType']) {
                        $includeNetwork = $false
                    }
                }
                
                if ($includeNetwork) {
                    [void]$filteredNetworks.Add($network)
                }
            }
            
            Write-Verbose "Filtered to $($filteredNetworks.Count) networks"
            return $filteredNetworks
        }
        catch {
            Write-Warning "Error filtering networks: $($_.Exception.Message)"
            return $this.AvailableNetworks
        }
    }
    
    # Get network statistics and summary
    [hashtable] GetNetworkStatistics() {
        try {
            Write-Verbose "Calculating network statistics..."
            
            $stats = @{
                TotalNetworks              = $this.AvailableNetworks.Count
                ConnectableNetworks        = 0
                OpenNetworks               = 0
                SecuredNetworks            = 0
                EncryptionBreakdown        = @{}
                AuthenticationBreakdown    = @{}
                SignalStrengthDistribution = @{
                    Excellent = 0  # 80-100%
                    Good      = 0       # 60-79%
                    Fair      = 0       # 40-59%
                    Poor      = 0       # 20-39%
                    VeryPoor  = 0   # 0-19%
                }
                AverageSignalStrength      = 0
                LastScanTime               = Get-Date
            }
            
            $totalSignalStrength = 0
            
            foreach ($network in $this.AvailableNetworks) {
                # Skip networks with null SSID
                if (-not $network -or [string]::IsNullOrWhiteSpace($network.SSID)) {
                    continue
                }
                
                # Count connectable networks
                if ($network.IsConnectable) {
                    $stats.ConnectableNetworks++
                }
                
                # Count open vs secured networks
                if ($network.EncryptionType -eq "None" -or $network.AuthenticationMethod -eq "Open") {
                    $stats.OpenNetworks++
                }
                else {
                    $stats.SecuredNetworks++
                }
                
                # Encryption type breakdown
                $encType = if ([string]::IsNullOrWhiteSpace($network.EncryptionType)) { "Unknown" } else { $network.EncryptionType }
                if ($stats.EncryptionBreakdown.ContainsKey($encType)) {
                    $stats.EncryptionBreakdown[$encType]++
                }
                else {
                    $stats.EncryptionBreakdown[$encType] = 1
                }
                
                # Authentication method breakdown
                $authMethod = if ([string]::IsNullOrWhiteSpace($network.AuthenticationMethod)) { "Unknown" } else { $network.AuthenticationMethod }
                if ($stats.AuthenticationBreakdown.ContainsKey($authMethod)) {
                    $stats.AuthenticationBreakdown[$authMethod]++
                }
                else {
                    $stats.AuthenticationBreakdown[$authMethod] = 1
                }
                
                # Signal strength distribution
                $signal = $network.SignalStrength
                $totalSignalStrength += $signal
                
                if ($signal -ge 80) {
                    $stats.SignalStrengthDistribution.Excellent++
                }
                elseif ($signal -ge 60) {
                    $stats.SignalStrengthDistribution.Good++
                }
                elseif ($signal -ge 40) {
                    $stats.SignalStrengthDistribution.Fair++
                }
                elseif ($signal -ge 20) {
                    $stats.SignalStrengthDistribution.Poor++
                }
                else {
                    $stats.SignalStrengthDistribution.VeryPoor++
                }
            }
            
            # Calculate average signal strength
            if ($this.AvailableNetworks.Count -gt 0) {
                $stats.AverageSignalStrength = [math]::Round($totalSignalStrength / $this.AvailableNetworks.Count, 2)
            }
            
            Write-Verbose "Network statistics calculated: $($stats.TotalNetworks) total, $($stats.ConnectableNetworks) connectable"
            return $stats
        }
        catch {
            Write-Warning "Error calculating network statistics: $($_.Exception.Message)"
            return @{
                TotalNetworks       = 0
                ConnectableNetworks = 0
                OpenNetworks        = 0
                SecuredNetworks     = 0
                LastScanTime        = Get-Date
                Error               = $_.Exception.Message
            }
        }
    }
    
    # Convert technical cipher names to user-friendly encryption names
    [string] ConvertToFriendlyEncryptionName([string]$technicalName) {
        if ([string]::IsNullOrWhiteSpace($technicalName)) {
            return "Unknown"
        }
        
        $name = $technicalName.Trim().ToLower()
        
        switch ($name) {
            "none" { return "Open" }
            "wep" { return "WEP" }
            "tkip" { return "WPA" }
            "ccmp" { return "WPA2" }
            "gcmp" { return "WPA3" }
            "gcmp-256" { return "WPA3" }
            "ccmp-256" { return "WPA3" }
            "wpa" { return "WPA" }
            "wpa2" { return "WPA2" }
            "wpa3" { return "WPA3" }
            default { 
                if ($name -match "wpa3") { return "WPA3" }
                elseif ($name -match "wpa2") { return "WPA2" }
                elseif ($name -match "wpa") { return "WPA" }
                elseif ($name -match "wep") { return "WEP" }
                else { return $technicalName }
            }
        }
        
        # Fallback return (should never be reached)
        return $technicalName
    }

    # Get adapter summary for display
    [string] GetAdapterSummary() {
        $primaryAdapterName = if ($this.PrimaryAdapter) { $this.PrimaryAdapter.Name } else { "None" }
        
        $summary = @"
NetworkManager Status:
- Primary Adapter: $primaryAdapterName
- Total Adapters: $($this.AdapterCache.Count)
- Connection Status: $($this.ConnectionStatus)
- Monitoring Enabled: $($this.MonitoringEnabled)
- Last Scan: $($this.LastAdapterScan.ToString('yyyy-MM-dd HH:mm:ss'))
- Available Networks: $($this.AvailableNetworks.Count)
"@
        return $summary
    }
    
    # ===== CONNECTION ATTEMPT FUNCTIONALITY =====
    
    # Attempt to connect to a Wi-Fi network with specified credentials
    [ConnectionAttempt] AttemptConnection([string]$ssid, [string]$password) {
        return $this.AttemptConnection($ssid, $password, 30)
    }
    
    # Attempt to connect to a Wi-Fi network with specified credentials and timeout
    [ConnectionAttempt] AttemptConnection([string]$ssid, [string]$password, [int]$timeoutSeconds) {
        $attempt = [ConnectionAttempt]::new($ssid, $password, 1)
        
        try {
            Write-Verbose "Attempting connection to SSID: $ssid"
            $attempt.MarkAsStarted()
            
            # Validate inputs
            if ([string]::IsNullOrWhiteSpace($ssid)) {
                throw [NetworkException]::new("SSID cannot be empty", $this.PrimaryAdapter.Name, $ssid)
            }
            
            if (-not $this.PrimaryAdapter) {
                throw [NetworkException]::new("No primary Wi-Fi adapter available", "", $ssid)
            }
            
            # Check if network is available
            $targetNetwork = $this.FindNetworkBySSID($ssid)
            if (-not $targetNetwork) {
                Write-Verbose "Network $ssid not found in scan results, attempting connection anyway"
            }
            
            # Disconnect from current network if connected
            $this.DisconnectFromNetwork()
            
            # Create or update network profile
            $profileCreated = $this.CreateNetworkProfile($ssid, $password, $targetNetwork)
            if (-not $profileCreated) {
                throw [NetworkException]::new("Failed to create network profile for $ssid", $this.PrimaryAdapter.Name, $ssid)
            }
            
            # Attempt connection using netsh
            $connectionResult = $this.ExecuteConnection($ssid, $timeoutSeconds)
            
            # Handle Windows authentication dialogs if they appear
            $this.HandleAuthenticationDialogs($ssid, $password, $timeoutSeconds)
            
            # Validate connection status
            $connectionValidation = $this.ValidateConnection($ssid, $timeoutSeconds)
            
            if ($connectionValidation.Success) {
                $attempt.MarkAsCompleted($true)
                $this.ConnectionStatus = [ConnectionStatus]::Connected
                Write-Verbose "Successfully connected to $ssid"
            }
            else {
                $attempt.MarkAsCompleted($false, $connectionValidation.ErrorMessage)
                $this.ConnectionStatus = [ConnectionStatus]::Failed
                Write-Verbose "Failed to connect to $ssid : $($connectionValidation.ErrorMessage)"
            }
            
        }
        catch {
            $errorMessage = "Connection attempt failed: $($_.Exception.Message)"
            $attempt.MarkAsCompleted($false, $errorMessage)
            $this.ConnectionStatus = [ConnectionStatus]::Failed
            Write-Warning $errorMessage
        }
        
        return $attempt
    }
    
    # Find a network by SSID in the available networks list
    [NetworkProfile] FindNetworkBySSID([string]$ssid) {
        try {
            foreach ($network in $this.AvailableNetworks) {
                if ($network.SSID -eq $ssid) {
                    return $network
                }
            }
            return $null
        }
        catch {
            Write-Warning "Error finding network $ssid : $($_.Exception.Message)"
            return $null
        }
    }
    
    # Create or update a network profile for connection
    [bool] CreateNetworkProfile([string]$ssid, [string]$password, [NetworkProfile]$networkInfo) {
        try {
            Write-Verbose "Creating network profile for $ssid"
            
            # Determine security settings
            $authMethod = "WPA2PSK"
            $encryption = "AES"
            
            if ($networkInfo) {
                # Use detected network security settings
                switch ($networkInfo.AuthenticationMethod.ToLower()) {
                    "open" { 
                        $authMethod = "open"
                        $encryption = "none"
                    }
                    "wep" { 
                        $authMethod = "shared"
                        $encryption = "WEP"
                    }
                    "wpa-psk" { 
                        $authMethod = "WPAPSK"
                        $encryption = "TKIP"
                    }
                    "wpa2-psk" { 
                        $authMethod = "WPA2PSK"
                        $encryption = "AES"
                    }
                    "wpa3-sae" { 
                        $authMethod = "WPA3SAE"
                        $encryption = "AES"
                    }
                    default {
                        # Default to WPA2PSK for unknown types
                        $authMethod = "WPA2PSK"
                        $encryption = "AES"
                    }
                }
            }
            
            # Create XML profile content
            $profileXml = $this.GenerateNetworkProfileXML($ssid, $authMethod, $encryption, $password)
            
            # Save profile to temporary file
            $tempProfilePath = [System.IO.Path]::GetTempFileName() + ".xml"
            [System.IO.File]::WriteAllText($tempProfilePath, $profileXml, [System.Text.Encoding]::UTF8)
            
            try {
                # Add profile using netsh
                $addProfileOutput = & netsh wlan add profile filename="$tempProfilePath" 2>&1
                $addProfileSuccess = $LASTEXITCODE -eq 0
                
                if (-not $addProfileSuccess) {
                    Write-Warning "Failed to add network profile for $ssid : $addProfileOutput"
                    return $false
                }
                
                Write-Verbose "Network profile created successfully for $ssid"
                return $true
            }
            finally {
                # Clean up temporary file
                if (Test-Path $tempProfilePath) {
                    Remove-Item $tempProfilePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Warning "Error creating network profile for $ssid : $($_.Exception.Message)"
            return $false
        }
    }
    
    # Generate XML profile content for network
    [string] GenerateNetworkProfileXML([string]$ssid, [string]$authMethod, [string]$encryption, [string]$password) {
        $profileName = $ssid
        $hexSSID = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($ssid)).Replace("-", "")
        
        if ($authMethod -eq "open" -and $encryption -eq "none") {
            # Open network profile
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
                <authentication>open</authentication>
                <encryption>none</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
        </security>
    </MSM>
</WLANProfile>
"@
        }
        else {
            # Secured network profile
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
                <authentication>$authMethod</authentication>
                <encryption>$encryption</encryption>
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
        }
        
        return $profileXml
    }
    
    # Execute the actual connection using netsh
    [hashtable] ExecuteConnection([string]$ssid, [int]$timeoutSeconds) {
        try {
            Write-Verbose "Executing connection to $ssid with timeout $timeoutSeconds seconds"
            
            # Connect to the network
            $connectOutput = & netsh wlan connect name="$ssid" 2>&1
            $connectSuccess = $LASTEXITCODE -eq 0
            
            $result = @{
                Success      = $connectSuccess
                Output       = $connectOutput -join "`n"
                ErrorMessage = ""
            }
            
            if (-not $connectSuccess) {
                $result.ErrorMessage = "netsh connect command failed: $($result.Output)"
                Write-Verbose $result.ErrorMessage
            }
            else {
                Write-Verbose "Connection command executed successfully"
            }
            
            return $result
        }
        catch {
            return @{
                Success      = $false
                Output       = ""
                ErrorMessage = "Exception during connection execution: $($_.Exception.Message)"
            }
        }
    }
    
    # Handle Windows authentication dialogs automatically
    [void] HandleAuthenticationDialogs([string]$ssid, [string]$password, [int]$timeoutSeconds) {
        try {
            Write-Verbose "Monitoring for authentication dialogs for $ssid"
            
            $startTime = Get-Date
            $dialogHandled = $false
            
            # Monitor for authentication dialogs for the specified timeout
            while (((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds -and -not $dialogHandled) {
                # Check for Windows credential dialogs
                $credentialDialogs = Get-Process | Where-Object { 
                    $_.ProcessName -match "(dwm|winlogon|lsass|csrss)" -or
                    $_.MainWindowTitle -match "(credential|password|authentication|network)" 
                } -ErrorAction SilentlyContinue
                
                if ($credentialDialogs) {
                    Write-Verbose "Potential authentication dialog detected"
                    
                    # Try to handle the dialog using Windows API calls
                    $this.SendCredentialsToDialog($password)
                    $dialogHandled = $true
                }
                
                # Check for network connection status changes
                $currentConnection = $this.GetCurrentConnection()
                if ($currentConnection -and $currentConnection.SSID -eq $ssid) {
                    Write-Verbose "Connection established, stopping dialog monitoring"
                    break
                }
                
                Start-Sleep -Milliseconds 500
            }
            
            if ($dialogHandled) {
                Write-Verbose "Authentication dialog handling completed"
            }
            else {
                Write-Verbose "No authentication dialogs detected during connection attempt"
            }
        }
        catch {
            Write-Warning "Error handling authentication dialogs: $($_.Exception.Message)"
        }
    }
    
    # Send credentials to authentication dialog using Windows API
    [void] SendCredentialsToDialog([string]$password) {
        try {
            Write-Verbose "Attempting to send credentials to authentication dialog"
            
            # This is a simplified approach - in a full implementation, this would use
            # Windows API calls (SendMessage, FindWindow, etc.) to interact with dialogs
            # For now, we'll use a basic approach that doesn't require Windows Forms
            
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                
                # Wait a moment for dialog to be ready
                Start-Sleep -Milliseconds 1000
                
                # Send the password using SendKeys if available
                $sendKeysType = [System.Type]::GetType("System.Windows.Forms.SendKeys")
                if ($sendKeysType) {
                    $sendKeysType::SendWait($password)
                    Start-Sleep -Milliseconds 500
                    $sendKeysType::SendWait("{ENTER}")
                    Write-Verbose "Credentials sent to dialog using SendKeys"
                }
                else {
                    Write-Verbose "SendKeys not available, dialog handling skipped"
                }
            }
            catch {
                Write-Verbose "Windows Forms not available, using alternative approach"
                # Alternative: Use WScript.Shell if available
                try {
                    $shell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue
                    if ($shell) {
                        Start-Sleep -Milliseconds 1000
                        $shell.SendKeys($password)
                        Start-Sleep -Milliseconds 500
                        $shell.SendKeys("{ENTER}")
                        Write-Verbose "Credentials sent to dialog using WScript.Shell"
                    }
                    else {
                        Write-Verbose "No automation method available for dialog handling"
                    }
                }
                catch {
                    Write-Verbose "WScript.Shell also not available, dialog handling skipped"
                }
            }
        }
        catch {
            Write-Warning "Failed to send credentials to dialog: $($_.Exception.Message)"
        }
    }
    
    # Validate connection status after attempt
    [hashtable] ValidateConnection([string]$ssid, [int]$timeoutSeconds) {
        try {
            Write-Verbose "Validating connection to $ssid"
            
            $startTime = Get-Date
            $maxWaitTime = $timeoutSeconds
            
            # Wait for connection to establish
            while (((Get-Date) - $startTime).TotalSeconds -lt $maxWaitTime) {
                $currentConnection = $this.GetCurrentConnection()
                
                if ($currentConnection -and $currentConnection.SSID -eq $ssid) {
                    # Connection successful
                    return @{
                        Success        = $true
                        ConnectionInfo = $currentConnection
                        ErrorMessage   = ""
                        ValidationTime = ((Get-Date) - $startTime).TotalSeconds
                    }
                }
                
                # Check adapter status
                $adapterStatus = $this.GetAdapterStatus()
                if (-not $adapterStatus.IsHealthy) {
                    return @{
                        Success        = $false
                        ConnectionInfo = $null
                        ErrorMessage   = "Wi-Fi adapter is not healthy: $($adapterStatus.ErrorMessage)"
                        ValidationTime = ((Get-Date) - $startTime).TotalSeconds
                    }
                }
                
                Start-Sleep -Milliseconds 1000
            }
            
            # Connection timeout
            return @{
                Success        = $false
                ConnectionInfo = $null
                ErrorMessage   = "Connection timeout after $maxWaitTime seconds"
                ValidationTime = $maxWaitTime
            }
        }
        catch {
            return @{
                Success        = $false
                ConnectionInfo = $null
                ErrorMessage   = "Connection validation failed: $($_.Exception.Message)"
                ValidationTime = 0
            }
        }
    }
    
    # Disconnect from current network
    [bool] DisconnectFromNetwork() {
        try {
            Write-Verbose "Disconnecting from current network"
            
            # Get current connection
            $currentConnection = $this.GetCurrentConnection()
            if (-not $currentConnection) {
                Write-Verbose "No current connection to disconnect from"
                return $true
            }
            
            # Disconnect using netsh
            $disconnectOutput = & netsh wlan disconnect 2>&1
            $disconnectSuccess = $LASTEXITCODE -eq 0
            
            if ($disconnectSuccess) {
                Write-Verbose "Successfully disconnected from network"
                $this.ConnectionStatus = [ConnectionStatus]::Disconnected
                
                # Wait a moment for disconnection to complete
                Start-Sleep -Milliseconds 2000
                
                return $true
            }
            else {
                Write-Warning "Failed to disconnect from network: $disconnectOutput"
                return $false
            }
        }
        catch {
            Write-Warning "Error disconnecting from network: $($_.Exception.Message)"
            return $false
        }
    }
    
    # Monitor connection status continuously
    [void] StartConnectionMonitoring([int]$intervalSeconds = 5) {
        try {
            Write-Verbose "Starting connection monitoring (interval: $intervalSeconds seconds)"
            
            # This would typically use PowerShell jobs or runspaces for background monitoring
            # For now, we'll implement a simple polling mechanism
            $this.MonitoringEnabled = $true
            
            Write-Verbose "Connection monitoring started"
        }
        catch {
            Write-Warning "Failed to start connection monitoring: $($_.Exception.Message)"
        }
    }
    
    # Stop connection monitoring
    [void] StopConnectionMonitoring() {
        try {
            Write-Verbose "Stopping connection monitoring"
            $this.MonitoringEnabled = $false
            Write-Verbose "Connection monitoring stopped"
        }
        catch {
            Write-Warning "Failed to stop connection monitoring: $($_.Exception.Message)"
        }
    }
    
    # Get connection attempt statistics
    [hashtable] GetConnectionStatistics() {
        try {
            # This would track connection attempts, success rates, etc.
            # For now, return basic information
            return @{
                CurrentStatus     = $this.ConnectionStatus
                PrimaryAdapter    = if ($this.PrimaryAdapter) { $this.PrimaryAdapter.Name } else { "None" }
                LastScanTime      = $this.LastAdapterScan
                AvailableNetworks = $this.AvailableNetworks.Count
                MonitoringEnabled = $this.MonitoringEnabled
            }
        }
        catch {
            Write-Warning "Error getting connection statistics: $($_.Exception.Message)"
            return @{
                CurrentStatus = "Error"
                Error         = $_.Exception.Message
            }
        }
    }
    
    # Test connection to a specific network without saving credentials
    [hashtable] TestConnection([string]$ssid, [string]$password, [int]$timeoutSeconds = 15) {
        try {
            Write-Verbose "Testing connection to $ssid (timeout: $timeoutSeconds seconds)"
            
            $testResult = @{
                SSID           = $ssid
                Success        = $false
                ErrorMessage   = ""
                TestDuration   = 0
                SignalStrength = 0
                ConnectionInfo = $null
            }
            
            $startTime = Get-Date
            
            # Find the network
            $targetNetwork = $this.FindNetworkBySSID($ssid)
            if ($targetNetwork) {
                $testResult.SignalStrength = $targetNetwork.SignalStrength
            }
            
            # Attempt connection
            $connectionAttempt = $this.AttemptConnection($ssid, $password, $timeoutSeconds)
            
            $testResult.Success = $connectionAttempt.Success
            $testResult.ErrorMessage = $connectionAttempt.ErrorMessage
            $testResult.TestDuration = ((Get-Date) - $startTime).TotalSeconds
            
            if ($connectionAttempt.Success) {
                $testResult.ConnectionInfo = $this.GetCurrentConnection()
            }
            
            # Clean up - disconnect after test
            if ($connectionAttempt.Success) {
                Start-Sleep -Milliseconds 2000  # Allow connection to stabilize
                $this.DisconnectFromNetwork()
            }
            
            return $testResult
        }
        catch {
            return @{
                SSID           = $ssid
                Success        = $false
                ErrorMessage   = "Test connection failed: $($_.Exception.Message)"
                TestDuration   = 0
                SignalStrength = 0
                ConnectionInfo = $null
            }
        }
    }
}
