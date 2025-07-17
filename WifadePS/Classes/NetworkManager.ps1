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
                $_.AdapterTypeId -eq 9 -and  # Ethernet 802.3 (includes Wi-Fi)
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
                DeviceID = $wmiAdapter.DeviceID
                Name = $wmiAdapter.Name
                Description = $wmiAdapter.Description
                MACAddress = $wmiAdapter.MACAddress
                Status = $this.TranslateAdapterStatus($wmiAdapter.NetConnectionStatus)
                StatusCode = $wmiAdapter.NetConnectionStatus
                Enabled = $wmiAdapter.NetEnabled
                Speed = $wmiAdapter.Speed
                AdapterType = $wmiAdapter.AdapterType
                AdapterTypeId = $wmiAdapter.AdapterTypeId
                Manufacturer = $wmiAdapter.Manufacturer
                LastUpdated = Get-Date
                IsWiFi = $true
                Capabilities = @{}
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
            } else {
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
                DeviceID = $wmiAdapter.DeviceID
                Name = $wmiAdapter.Name
                Status = $this.TranslateAdapterStatus($wmiAdapter.NetConnectionStatus)
                StatusCode = $wmiAdapter.NetConnectionStatus
                Enabled = $wmiAdapter.NetEnabled
                LastChecked = Get-Date
                IsHealthy = $this.IsAdapterHealthy($wmiAdapter)
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
                DeviceID = $deviceId
                Name = $name
                Status = "Error"
                StatusCode = -1
                Enabled = $false
                LastChecked = Get-Date
                IsHealthy = $false
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
                Timestamp = Get-Date
                TotalAdapters = $this.AdapterCache.Count
                HealthyAdapters = 0
                UnhealthyAdapters = 0
                AdapterDetails = @{}
                OverallHealth = "Unknown"
                Recommendations = @()
            }
            
            foreach ($deviceId in $this.AdapterCache.Keys) {
                $adapterStatus = $this.GetAdapterStatus($deviceId)
                $healthReport.AdapterDetails[$deviceId] = $adapterStatus
                
                if ($adapterStatus.IsHealthy) {
                    $healthReport.HealthyAdapters++
                } else {
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
        } else {
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
"@
        return $summary
    }
}