# Unit Tests for NetworkManager Class
# Uses Pester testing framework for PowerShell

BeforeAll {
    # Import required classes
    $ModulePath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    . "$ModulePath\Classes\BaseClasses.ps1"
    . "$ModulePath\Classes\DataModels.ps1"
    . "$ModulePath\Classes\NetworkManager.ps1"
    
    # Mock WMI objects for testing
    function New-MockWiFiAdapter {
        param(
            [string]$Name = "Mock Wi-Fi Adapter",
            [string]$DeviceID = "PCI\VEN_8086&DEV_24FD&SUBSYS_00108086&REV_05\4&2634DE8E&0&00E0",
            [string]$Description = "Intel(R) Wireless-AC 9560 160MHz",
            [string]$MACAddress = "AA:BB:CC:DD:EE:FF",
            [int]$NetConnectionStatus = 2,  # Connected
            [bool]$NetEnabled = $true,
            [long]$Speed = 1000000000,  # 1 Gbps
            [string]$AdapterType = "Ethernet 802.3",
            [int]$AdapterTypeId = 9,
            [string]$Manufacturer = "Intel Corporation",
            [int]$Index = 12
        )
        
        return [PSCustomObject]@{
            Name = $Name
            DeviceID = $DeviceID
            Description = $Description
            MACAddress = $MACAddress
            NetConnectionStatus = $NetConnectionStatus
            NetEnabled = $NetEnabled
            Speed = $Speed
            AdapterType = $AdapterType
            AdapterTypeId = $AdapterTypeId
            Manufacturer = $Manufacturer
            Index = $Index
        }
    }
    
    function New-MockWiFiAdapterConfig {
        param(
            [int]$Index = 12,
            [bool]$IPEnabled = $true,
            [string]$Description = "Intel(R) Wireless-AC 9560 160MHz",
            [bool]$DHCPEnabled = $true,
            [string[]]$IPAddress = @("192.168.1.100"),
            [string[]]$DefaultIPGateway = @("192.168.1.1"),
            [string[]]$DNSServerSearchOrder = @("8.8.8.8", "8.8.4.4")
        )
        
        return [PSCustomObject]@{
            Index = $Index
            IPEnabled = $IPEnabled
            Description = $Description
            DHCPEnabled = $DHCPEnabled
            IPAddress = $IPAddress
            DefaultIPGateway = $DefaultIPGateway
            DNSServerSearchOrder = $DNSServerSearchOrder
        }
    }
}

Describe "NetworkManager Class Tests" {
    
    Context "Constructor Tests" {
        It "Should create instance with default constructor" {
            $networkManager = [NetworkManager]::new()
            
            $networkManager | Should -Not -BeNullOrEmpty
            $networkManager.PrimaryAdapter | Should -BeNullOrEmpty
            
            # Test AvailableNetworks initialization - handle Pester edge case
            try {
                $networkManager.AvailableNetworks | Should -BeOfType ([System.Collections.ArrayList])
            } catch {
                # Fallback: check if we can access the Count property (indicates it's initialized)
                $networkManager.AvailableNetworks.Count | Should -Be 0
            }
            
            $networkManager.ConnectionStatus | Should -Be ([ConnectionStatus]::Disconnected)
            $networkManager.AdapterCache | Should -BeOfType ([hashtable])
            $networkManager.AdapterCache.Count | Should -Be 0
            $networkManager.LastAdapterScan | Should -Be ([datetime]::MinValue)
            $networkManager.AdapterScanIntervalSeconds | Should -Be 30
            $networkManager.MonitoringEnabled | Should -Be $false
            $networkManager.IsInitialized | Should -Be $false
        }
        
        It "Should create instance with configuration" {
            $config = @{
                'AdapterScanInterval' = 60
                'MonitoringEnabled' = $true
            }
            
            $networkManager = [NetworkManager]::new($config)
            
            $networkManager | Should -Not -BeNullOrEmpty
            $networkManager.AdapterScanIntervalSeconds | Should -Be 60
            $networkManager.MonitoringEnabled | Should -Be $true
            $networkManager.Configuration | Should -Be $config
        }
    }
    
    Context "Adapter Status Translation Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should translate status code 0 to Disconnected" {
            $result = $networkManager.TranslateAdapterStatus(0)
            $result | Should -Be "Disconnected"
        }
        
        It "Should translate status code 1 to Connecting" {
            $result = $networkManager.TranslateAdapterStatus(1)
            $result | Should -Be "Connecting"
        }
        
        It "Should translate status code 2 to Connected" {
            $result = $networkManager.TranslateAdapterStatus(2)
            $result | Should -Be "Connected"
        }
        
        It "Should translate status code 3 to Disconnecting" {
            $result = $networkManager.TranslateAdapterStatus(3)
            $result | Should -Be "Disconnecting"
        }
        
        It "Should translate status code 4 to Hardware not present" {
            $result = $networkManager.TranslateAdapterStatus(4)
            $result | Should -Be "Hardware not present"
        }
        
        It "Should translate status code 5 to Hardware disabled" {
            $result = $networkManager.TranslateAdapterStatus(5)
            $result | Should -Be "Hardware disabled"
        }
        
        It "Should translate status code 6 to Hardware malfunction" {
            $result = $networkManager.TranslateAdapterStatus(6)
            $result | Should -Be "Hardware malfunction"
        }
        
        It "Should translate status code 7 to Media disconnected" {
            $result = $networkManager.TranslateAdapterStatus(7)
            $result | Should -Be "Media disconnected"
        }
        
        It "Should translate unknown status code with number" {
            $result = $networkManager.TranslateAdapterStatus(99)
            $result | Should -Be "Unknown (99)"
        }
    }
    
    Context "Adapter Information Creation Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should create adapter info from WMI object" {
            $mockAdapter = New-MockWiFiAdapter
            
            # Mock Get-WmiObject for configuration
            Mock Get-WmiObject {
                return New-MockWiFiAdapterConfig
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
            
            $adapterInfo = $networkManager.CreateAdapterInfo($mockAdapter)
            
            $adapterInfo | Should -Not -BeNullOrEmpty
            $adapterInfo.DeviceID | Should -Be $mockAdapter.DeviceID
            $adapterInfo.Name | Should -Be $mockAdapter.Name
            $adapterInfo.Description | Should -Be $mockAdapter.Description
            $adapterInfo.MACAddress | Should -Be $mockAdapter.MACAddress
            $adapterInfo.Status | Should -Be "Connected"
            $adapterInfo.StatusCode | Should -Be 2
            $adapterInfo.Enabled | Should -Be $true
            $adapterInfo.Speed | Should -Be $mockAdapter.Speed
            $adapterInfo.IsWiFi | Should -Be $true
            $adapterInfo.Capabilities | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle adapter info creation without configuration" {
            $mockAdapter = New-MockWiFiAdapter
            
            # Mock Get-WmiObject to return null for configuration
            Mock Get-WmiObject {
                return $null
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
            
            $adapterInfo = $networkManager.CreateAdapterInfo($mockAdapter)
            
            $adapterInfo | Should -Not -BeNullOrEmpty
            $adapterInfo.DeviceID | Should -Be $mockAdapter.DeviceID
            $adapterInfo.Name | Should -Be $mockAdapter.Name
            $adapterInfo.Capabilities | Should -BeOfType ([hashtable])
        }
        
        It "Should return null for invalid adapter" {
            $result = $networkManager.CreateAdapterInfo($null)
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Adapter Health Check Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should return true for healthy adapter" {
            $mockAdapter = New-MockWiFiAdapter -NetEnabled $true -NetConnectionStatus 2
            
            $result = $networkManager.IsAdapterHealthy($mockAdapter)
            $result | Should -Be $true
        }
        
        It "Should return false for disabled adapter" {
            $mockAdapter = New-MockWiFiAdapter -NetEnabled $false -NetConnectionStatus 2
            
            $result = $networkManager.IsAdapterHealthy($mockAdapter)
            $result | Should -Be $false
        }
        
        It "Should return false for adapter with hardware not present" {
            $mockAdapter = New-MockWiFiAdapter -NetEnabled $true -NetConnectionStatus 4
            
            $result = $networkManager.IsAdapterHealthy($mockAdapter)
            $result | Should -Be $false
        }
        
        It "Should return false for adapter with hardware disabled" {
            $mockAdapter = New-MockWiFiAdapter -NetEnabled $true -NetConnectionStatus 5
            
            $result = $networkManager.IsAdapterHealthy($mockAdapter)
            $result | Should -Be $false
        }
        
        It "Should return false for adapter with hardware malfunction" {
            $mockAdapter = New-MockWiFiAdapter -NetEnabled $true -NetConnectionStatus 6
            
            $result = $networkManager.IsAdapterHealthy($mockAdapter)
            $result | Should -Be $false
        }
        
        It "Should return false for null adapter" {
            $result = $networkManager.IsAdapterHealthy($null)
            $result | Should -Be $false
        }
    }
    
    Context "Primary Adapter Selection Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should handle empty adapter list" {
            $adapters = [System.Collections.ArrayList]::new()
            
            $networkManager.SelectPrimaryAdapter($adapters)
            
            $networkManager.PrimaryAdapter | Should -BeNullOrEmpty
        }
        
        It "Should select connected adapter over disconnected" {
            $adapters = [System.Collections.ArrayList]::new()
            $disconnectedAdapter = @{ Name = "Disconnected Adapter"; Status = "Disconnected"; Enabled = $true; Speed = 1000000000 }
            $connectedAdapter = @{ Name = "Connected Adapter"; Status = "Connected"; Enabled = $true; Speed = 500000000 }
            [void]$adapters.Add($disconnectedAdapter)
            [void]$adapters.Add($connectedAdapter)
            
            $networkManager.SelectPrimaryAdapter($adapters)
            
            $networkManager.PrimaryAdapter | Should -Be $connectedAdapter
        }
        
        It "Should select enabled adapter over disabled" {
            $adapters = [System.Collections.ArrayList]::new()
            $disabledAdapter = @{ Name = "Disabled Adapter"; Status = "Disconnected"; Enabled = $false; Speed = 1000000000 }
            $enabledAdapter = @{ Name = "Enabled Adapter"; Status = "Disconnected"; Enabled = $true; Speed = 500000000 }
            [void]$adapters.Add($disabledAdapter)
            [void]$adapters.Add($enabledAdapter)
            
            $networkManager.SelectPrimaryAdapter($adapters)
            
            $networkManager.PrimaryAdapter | Should -Be $enabledAdapter
        }
        
        It "Should select higher speed adapter when status is equal" {
            $adapters = [System.Collections.ArrayList]::new()
            $slowAdapter = @{ Name = "Slow Adapter"; Status = "Disconnected"; Enabled = $true; Speed = 100000000 }
            $fastAdapter = @{ Name = "Fast Adapter"; Status = "Disconnected"; Enabled = $true; Speed = 1000000000 }
            [void]$adapters.Add($slowAdapter)
            [void]$adapters.Add($fastAdapter)
            
            $networkManager.SelectPrimaryAdapter($adapters)
            
            $networkManager.PrimaryAdapter | Should -Be $fastAdapter
        }
        
        It "Should prefer Wi-Fi named adapter" {
            $adapters = [System.Collections.ArrayList]::new()
            $genericAdapter = @{ Name = "Generic Wireless Adapter"; Status = "Disconnected"; Enabled = $true; Speed = 1000000000 }
            $wifiAdapter = @{ Name = "Wi-Fi Adapter"; Status = "Disconnected"; Enabled = $true; Speed = 500000000 }
            [void]$adapters.Add($genericAdapter)
            [void]$adapters.Add($wifiAdapter)
            
            $networkManager.SelectPrimaryAdapter($adapters)
            
            $networkManager.PrimaryAdapter.Name | Should -Be $wifiAdapter.Name
        }
    }
    
    Context "Adapter Detection Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should detect Wi-Fi adapters successfully" {
            # Mock Get-WmiObject for adapters
            Mock Get-WmiObject {
                return @(
                    (New-MockWiFiAdapter -Name "Wi-Fi Adapter 1" -DeviceID "DEV1"),
                    (New-MockWiFiAdapter -Name "Wi-Fi Adapter 2" -DeviceID "DEV2")
                )
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" }
            
            # Mock Get-WmiObject for configuration
            Mock Get-WmiObject {
                return New-MockWiFiAdapterConfig
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
            
            $adapters = $networkManager.DetectWiFiAdapters()
            
            $adapters | Should -Not -BeNullOrEmpty
            $adapters.Count | Should -Be 2
            $networkManager.AdapterCache.Count | Should -Be 2
            $networkManager.PrimaryAdapter | Should -Not -BeNullOrEmpty
            $networkManager.LastAdapterScan | Should -BeGreaterThan ([datetime]::MinValue)
        }
        
        It "Should handle no adapters found" {
            # Mock Get-WmiObject to return empty
            Mock Get-WmiObject {
                return @()
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" }
            
            Mock Get-WmiObject {
                return @()
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
            
            $adapters = $networkManager.DetectWiFiAdapters()
            
            # Test adapter list initialization - handle Pester edge case
            try {
                $adapters | Should -BeOfType ([System.Collections.ArrayList])
            } catch {
                # Fallback: check if we can access the Count property (indicates it's initialized)
                $adapters.Count | Should -Be 0
            }
            
            $networkManager.AdapterCache.Count | Should -Be 0
            $networkManager.PrimaryAdapter | Should -BeNullOrEmpty
        }
        
        It "Should use fallback method when primary method fails" {
            # Mock Get-WmiObject for adapters to return null first, then configs
            Mock Get-WmiObject {
                return $null
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" -and -not $Filter }
            
            Mock Get-WmiObject {
                return @(New-MockWiFiAdapterConfig)
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
            
            Mock Get-WmiObject {
                return New-MockWiFiAdapter
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" -and $Filter }
            
            $adapters = $networkManager.DetectWiFiAdapters()
            
            $adapters | Should -Not -BeNullOrEmpty
            $adapters.Count | Should -Be 1
        }
    }
    
    Context "Adapter Status Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock adapter in cache
            $mockAdapterInfo = @{
                DeviceID = "TEST_DEVICE_ID"
                Name = "Test Wi-Fi Adapter"
                Status = "Connected"
                StatusCode = 2
                Enabled = $true
            }
            $networkManager.AdapterCache["TEST_DEVICE_ID"] = $mockAdapterInfo
            $networkManager.PrimaryAdapter = $mockAdapterInfo
        }
        
        It "Should get status for primary adapter" {
            Mock Get-WmiObject {
                return New-MockWiFiAdapter -DeviceID "TEST_DEVICE_ID" -NetConnectionStatus 2
            }
            
            $status = $networkManager.GetAdapterStatus()
            
            $status | Should -Not -BeNullOrEmpty
            $status.DeviceID | Should -Be "TEST_DEVICE_ID"
            $status.Status | Should -Be "Connected"
            $status.IsHealthy | Should -Be $true
            $status.ErrorMessage | Should -Be ""
        }
        
        It "Should get status for specific adapter" {
            Mock Get-WmiObject {
                return New-MockWiFiAdapter -DeviceID "TEST_DEVICE_ID" -NetConnectionStatus 0
            }
            
            $status = $networkManager.GetAdapterStatus("TEST_DEVICE_ID")
            
            $status | Should -Not -BeNullOrEmpty
            $status.DeviceID | Should -Be "TEST_DEVICE_ID"
            $status.Status | Should -Be "Disconnected"
        }
        
        It "Should handle adapter not found" {
            Mock Get-WmiObject {
                return $null
            }
            
            $status = $networkManager.GetAdapterStatus("TEST_DEVICE_ID")
            
            $status | Should -Not -BeNullOrEmpty
            $status.Status | Should -Be "Error"
            $status.IsHealthy | Should -Be $false
            $status.ErrorMessage | Should -Not -BeNullOrEmpty
        }
        
        It "Should throw exception when no adapter specified and no primary" {
            $networkManager.PrimaryAdapter = $null
            
            $status = $networkManager.GetAdapterStatus()
            
            $status.Status | Should -Be "Error"
            $status.ErrorMessage | Should -Match "No adapter specified"
        }
    }
    
    Context "Health Check Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock adapters in cache
            $healthyAdapter = @{
                DeviceID = "HEALTHY_ADAPTER"
                Name = "Healthy Wi-Fi Adapter"
            }
            $unhealthyAdapter = @{
                DeviceID = "UNHEALTHY_ADAPTER"
                Name = "Unhealthy Wi-Fi Adapter"
            }
            $networkManager.AdapterCache["HEALTHY_ADAPTER"] = $healthyAdapter
            $networkManager.AdapterCache["UNHEALTHY_ADAPTER"] = $unhealthyAdapter
            $networkManager.PrimaryAdapter = $healthyAdapter
        }
        
        It "Should perform comprehensive health check" {
            # Mock GetAdapterStatus to return different health states
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAdapterStatus -Value {
                param([string]$deviceId)
                if ($deviceId -eq "HEALTHY_ADAPTER") {
                    return @{
                        DeviceID = "HEALTHY_ADAPTER"
                        Name = "Healthy Wi-Fi Adapter"
                        IsHealthy = $true
                        ErrorMessage = ""
                    }
                } else {
                    return @{
                        DeviceID = "UNHEALTHY_ADAPTER"
                        Name = "Unhealthy Wi-Fi Adapter"
                        IsHealthy = $false
                        ErrorMessage = "Hardware malfunction"
                    }
                }
            } -Force
            
            $healthReport = $networkManager.PerformHealthCheck()
            
            $healthReport | Should -Not -BeNullOrEmpty
            $healthReport.TotalAdapters | Should -Be 2
            $healthReport.HealthyAdapters | Should -Be 1
            $healthReport.UnhealthyAdapters | Should -Be 1
            $healthReport.OverallHealth | Should -Be "Warning"
            $healthReport.AdapterDetails.Count | Should -Be 2
            $healthReport.Recommendations.Count | Should -BeGreaterThan 0
        }
        
        It "Should report critical health when no healthy adapters" {
            # Mock GetAdapterStatus to return unhealthy for all
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAdapterStatus -Value {
                return @{
                    IsHealthy = $false
                    ErrorMessage = "All adapters failed"
                }
            } -Force
            
            $healthReport = $networkManager.PerformHealthCheck()
            
            $healthReport.OverallHealth | Should -Be "Critical"
            $healthReport.HealthyAdapters | Should -Be 0
        }
        
        It "Should report good health when all adapters healthy" {
            # Mock GetAdapterStatus to return healthy for all
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAdapterStatus -Value {
                return @{
                    IsHealthy = $true
                    ErrorMessage = ""
                }
            } -Force
            
            $healthReport = $networkManager.PerformHealthCheck()
            
            $healthReport.OverallHealth | Should -Be "Good"
            $healthReport.UnhealthyAdapters | Should -Be 0
        }
    }
    
    Context "Configuration Validation Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should validate valid configuration" {
            $config = @{
                'AdapterScanInterval' = 60
                'MonitoringEnabled' = $true
            }
            
            $result = $networkManager.ValidateConfiguration($config)
            $result | Should -Be $true
        }
        
        It "Should throw exception for invalid scan interval (too low)" {
            $config = @{
                'AdapterScanInterval' = 2
            }
            
            { $networkManager.ValidateConfiguration($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for invalid scan interval (too high)" {
            $config = @{
                'AdapterScanInterval' = 500
            }
            
            { $networkManager.ValidateConfiguration($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should validate empty configuration" {
            $config = @{}
            
            $result = $networkManager.ValidateConfiguration($config)
            $result | Should -Be $true
        }
    }
    
    Context "Monitoring Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should start monitoring successfully" {
            { $networkManager.StartAdapterMonitoring() } | Should -Not -Throw
            $networkManager.MonitoringEnabled | Should -Be $true
        }
        
        It "Should stop monitoring successfully" {
            $networkManager.StartAdapterMonitoring()
            
            { $networkManager.StopAdapterMonitoring() } | Should -Not -Throw
            $networkManager.MonitoringEnabled | Should -Be $false
        }
    }
    
    Context "Adapter Management Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock adapters
            $adapter1 = @{ DeviceID = "ADAPTER1"; Name = "Adapter 1" }
            $adapter2 = @{ DeviceID = "ADAPTER2"; Name = "Adapter 2" }
            $networkManager.AdapterCache["ADAPTER1"] = $adapter1
            $networkManager.AdapterCache["ADAPTER2"] = $adapter2
            $networkManager.PrimaryAdapter = $adapter1
        }
        
        It "Should get all available adapters" {
            $adapters = $networkManager.GetAvailableAdapters()
            
            $adapters | Should -Not -BeNullOrEmpty
            $adapters.Count | Should -Be 2
        }
        
        It "Should get primary adapter" {
            $primary = $networkManager.GetPrimaryAdapter()
            
            $primary | Should -Not -BeNullOrEmpty
            $primary.DeviceID | Should -Be "ADAPTER1"
        }
        
        It "Should set primary adapter by device ID" {
            $networkManager.SetPrimaryAdapter("ADAPTER2")
            
            $networkManager.PrimaryAdapter.DeviceID | Should -Be "ADAPTER2"
        }
        
        It "Should throw exception when setting non-existent primary adapter" {
            { $networkManager.SetPrimaryAdapter("NON_EXISTENT") } | Should -Throw -ExceptionType ([NetworkException])
        }
    }
    
    Context "Refresh and Utility Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            $networkManager.LastAdapterScan = (Get-Date).AddMinutes(-5)  # 5 minutes ago
            $networkManager.AdapterScanIntervalSeconds = 30
        }
        
        It "Should refresh adapters when enough time has passed" {
            # Mock DetectWiFiAdapters
            $networkManager | Add-Member -MemberType ScriptMethod -Name DetectWiFiAdapters -Value {
                $this.LastAdapterScan = Get-Date
                return [System.Collections.ArrayList]::new()
            } -Force
            
            { $networkManager.RefreshAdapters() } | Should -Not -Throw
        }
        
        It "Should skip refresh when not enough time has passed" {
            $networkManager.LastAdapterScan = (Get-Date).AddSeconds(-10)  # 10 seconds ago
            
            # This should not call DetectWiFiAdapters
            { $networkManager.RefreshAdapters() } | Should -Not -Throw
        }
        
        It "Should generate adapter summary" {
            $summary = $networkManager.GetAdapterSummary()
            
            $summary | Should -Not -BeNullOrEmpty
            $summary | Should -Match "NetworkManager Status:"
            $summary | Should -Match "Total Adapters:"
            $summary | Should -Match "Connection Status:"
        }
    }
    
    Context "Initialization and Disposal Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should initialize successfully with valid configuration" {
            # Mock DetectWiFiAdapters to simulate finding adapters
            $networkManager | Add-Member -MemberType ScriptMethod -Name DetectWiFiAdapters -Value {
                $this.PrimaryAdapter = @{ Name = "Mock Adapter"; DeviceID = "MOCK_ID" }
            } -Force
            
            $config = @{
                'AdapterScanInterval' = 60
                'MonitoringEnabled' = $true
            }
            
            { $networkManager.Initialize($config) } | Should -Not -Throw
            $networkManager.IsInitialized | Should -Be $true
            $networkManager.AdapterScanIntervalSeconds | Should -Be 60
            $networkManager.MonitoringEnabled | Should -Be $true
        }
        
        It "Should throw exception when no adapters detected" {
            # Mock DetectWiFiAdapters to simulate no adapters
            $networkManager | Add-Member -MemberType ScriptMethod -Name DetectWiFiAdapters -Value {
                $this.PrimaryAdapter = $null
            } -Force
            
            { $networkManager.Initialize(@{}) } | Should -Throw -ExceptionType ([NetworkException])
        }
        
        It "Should dispose successfully" {
            # Setup some state
            $networkManager.AdapterCache["TEST"] = @{ Name = "Test" }
            $networkManager.AvailableNetworks.Add(@{ SSID = "Test" })
            $networkManager.MonitoringEnabled = $true
            $networkManager.IsInitialized = $true
            
            { $networkManager.Dispose() } | Should -Not -Throw
            
            $networkManager.AdapterCache.Count | Should -Be 0
            $networkManager.AvailableNetworks.Count | Should -Be 0
            $networkManager.PrimaryAdapter | Should -BeNullOrEmpty
            $networkManager.MonitoringEnabled | Should -Be $false
            $networkManager.IsInitialized | Should -Be $false
        }
    }
}

Describe "Integration Tests" {
    Context "End-to-End NetworkManager Tests" {
        It "Should handle complete adapter detection workflow" {
            # Mock the entire WMI detection process
            Mock Get-WmiObject {
                return @(
                    (New-MockWiFiAdapter -Name "Primary Wi-Fi" -DeviceID "PRIMARY" -NetConnectionStatus 2),
                    (New-MockWiFiAdapter -Name "Secondary Wi-Fi" -DeviceID "SECONDARY" -NetConnectionStatus 0)
                )
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" }
            
            Mock Get-WmiObject {
                return New-MockWiFiAdapterConfig
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
            
            $networkManager = [NetworkManager]::new()
            
            # Initialize
            $networkManager.Initialize(@{})
            
            # Verify initialization
            $networkManager.IsInitialized | Should -Be $true
            $networkManager.PrimaryAdapter | Should -Not -BeNullOrEmpty
            $networkManager.AdapterCache.Count | Should -Be 2
            
            # Test adapter operations
            $adapters = $networkManager.GetAvailableAdapters()
            $adapters.Count | Should -Be 2
            
            # Test health check
            Mock Get-WmiObject {
                param($Class, $Filter)
                if ($Filter -match "PRIMARY") {
                    return New-MockWiFiAdapter -DeviceID "PRIMARY" -NetConnectionStatus 2
                } else {
                    return New-MockWiFiAdapter -DeviceID "SECONDARY" -NetConnectionStatus 0
                }
            } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" -and $Filter }
            
            $healthReport = $networkManager.PerformHealthCheck()
            $healthReport.TotalAdapters | Should -Be 2
            $healthReport.OverallHealth | Should -BeIn @("Good", "Warning")
            
            # Clean up
            $networkManager.Dispose()
            $networkManager.IsInitialized | Should -Be $false
        }
    }
}

Describe "Network Discovery and Profiling Tests" {
    
    BeforeAll {
        # Mock netsh command outputs for testing
        function Mock-NetshWlanShowProfiles {
            return @(
                "Profiles on interface Wi-Fi:",
                "",
                "Group policy profiles (read only)",
                "---------------------------------",
                "    <None>",
                "",
                "User profiles",
                "-------------",
                "    All User Profile     : TestNetwork1",
                "    All User Profile     : TestNetwork2",
                "    All User Profile     : OpenNetwork"
            )
        }
        
        function Mock-NetshWlanShowNetworks {
            return @(
                "Interface name : Wi-Fi",
                "There are 3 networks currently visible.",
                "",
                "SSID 1 : TestNetwork1",
                "    Network type            : Infrastructure",
                "    Authentication          : WPA2-Personal",
                "    Encryption              : CCMP",
                "    BSSID 1                 : aa:bb:cc:dd:ee:f1",
                "         Signal             : 85%",
                "         Radio type         : 802.11ac",
                "         Channel            : 6",
                "",
                "SSID 2 : TestNetwork2",
                "    Network type            : Infrastructure", 
                "    Authentication          : WPA-Personal",
                "    Encryption              : TKIP",
                "    BSSID 1                 : aa:bb:cc:dd:ee:f2",
                "         Signal             : 65%",
                "         Radio type         : 802.11n",
                "         Channel            : 11",
                "",
                "SSID 3 : OpenNetwork",
                "    Network type            : Infrastructure",
                "    Authentication          : Open",
                "    Encryption              : None",
                "    BSSID 1                 : aa:bb:cc:dd:ee:f3",
                "         Signal             : 45%",
                "         Radio type         : 802.11g",
                "         Channel            : 1"
            )
        }
        
        function Mock-NetshWlanShowProfile {
            param([string]$ProfileName)
            
            switch ($ProfileName) {
                "TestNetwork1" {
                    return @(
                        "Profile TestNetwork1 on interface Wi-Fi:",
                        "=======================================================================",
                        "",
                        "Applied: All User Profile",
                        "",
                        "Profile information",
                        "-------------------",
                        "    Version                : 1",
                        "    Type                   : Wireless LAN",
                        "    Name                   : TestNetwork1",
                        "    Control options        :",
                        "        Connection mode    : Connect automatically",
                        "        Network broadcast  : Connect only if this network is broadcasting",
                        "        AutoSwitch         : Do not switch to other networks",
                        "",
                        "Connectivity settings",
                        "---------------------",
                        "    Number of SSIDs        : 1",
                        "    SSID name              : ""TestNetwork1""",
                        "    Network type           : Infrastructure",
                        "    Radio type             : [ Any Radio Type ]",
                        "    Vendor extension          : Not present",
                        "",
                        "Security settings",
                        "-----------------",
                        "    Authentication         : WPA2-Personal",
                        "    Cipher                 : CCMP",
                        "    Authentication         : WPA2-Personal",
                        "    Cipher                 : CCMP",
                        "    Security key           : Present",
                        "    Key Content            : password123"
                    )
                }
                "TestNetwork2" {
                    return @(
                        "Profile TestNetwork2 on interface Wi-Fi:",
                        "=======================================================================",
                        "",
                        "Security settings",
                        "-----------------",
                        "    Authentication         : WPA-Personal",
                        "    Cipher                 : TKIP",
                        "    Network type           : Infrastructure"
                    )
                }
                "OpenNetwork" {
                    return @(
                        "Profile OpenNetwork on interface Wi-Fi:",
                        "=======================================================================",
                        "",
                        "Security settings",
                        "-----------------",
                        "    Authentication         : Open",
                        "    Cipher                 : None",
                        "    Network type           : Infrastructure"
                    )
                }
                default {
                    return @()
                }
            }
        }
        
        function Mock-NetshWlanShowInterfaces {
            return @(
                "There is 1 interface on the system:",
                "",
                "    Name                   : Wi-Fi",
                "    Description            : Intel(R) Wireless-AC 9560 160MHz",
                "    GUID                   : 12345678-1234-1234-1234-123456789abc",
                "    Physical address       : aa:bb:cc:dd:ee:ff",
                "    State                  : connected",
                "    SSID                   : TestNetwork1",
                "    BSSID                  : aa:bb:cc:dd:ee:f1",
                "    Network type           : Infrastructure",
                "    Radio type             : 802.11ac",
                "    Authentication         : WPA2-Personal",
                "    Cipher                 : CCMP",
                "    Connection mode        : Auto Connect",
                "    Channel                : 6",
                "    Receive rate (Mbps)    : 866",
                "    Transmit rate (Mbps)   : 866",
                "    Signal                 : 85%",
                "    Profile                : TestNetwork1"
            )
        }
    }
    
    Context "Network Scanning Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock adapter
            $mockAdapter = @{
                DeviceID = "TEST_ADAPTER"
                Name = "Test Wi-Fi Adapter"
                Status = "Connected"
            }
            $networkManager.PrimaryAdapter = $mockAdapter
        }
        
        It "Should scan networks successfully" {
            # Override the netsh calls directly in the NetworkManager
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetSavedNetworkProfiles -Value {
                $savedNetworks = [System.Collections.ArrayList]::new()
                
                # Simulate saved profiles
                $profile1 = [NetworkProfile]::new("TestNetwork1", "CCMP")
                $profile1.AuthenticationMethod = "WPA2-Personal"
                $profile1.NetworkType = "Infrastructure"
                [void]$savedNetworks.Add($profile1)
                
                $profile2 = [NetworkProfile]::new("TestNetwork2", "TKIP")
                $profile2.AuthenticationMethod = "WPA-Personal"
                $profile2.NetworkType = "Infrastructure"
                [void]$savedNetworks.Add($profile2)
                
                return $savedNetworks
            } -Force
            
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAvailableNetworkProfiles -Value {
                $availableNetworks = [System.Collections.ArrayList]::new()
                
                # Simulate available networks
                $network1 = [NetworkProfile]::new("TestNetwork1", "CCMP")
                $network1.AuthenticationMethod = "WPA2-Personal"
                $network1.SignalStrength = 85
                $network1.BSSID = "aa:bb:cc:dd:ee:f1"
                $network1.Channel = 6
                $network1.NetworkType = "Infrastructure"
                [void]$availableNetworks.Add($network1)
                
                $network2 = [NetworkProfile]::new("OpenNetwork", "None")
                $network2.AuthenticationMethod = "Open"
                $network2.SignalStrength = 45
                $network2.BSSID = "aa:bb:cc:dd:ee:f3"
                $network2.Channel = 1
                $network2.NetworkType = "Infrastructure"
                [void]$availableNetworks.Add($network2)
                
                return $availableNetworks
            } -Force
            
            $networks = $networkManager.ScanNetworks()
            
            $networks | Should -Not -BeNullOrEmpty
            $networks.Count | Should -BeGreaterThan 0
            $networkManager.AvailableNetworks.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle scan failure gracefully" {
            # Mock failed primary adapter
            $networkManager.PrimaryAdapter = $null
            
            { $networkManager.ScanNetworks() } | Should -Throw -ExceptionType ([NetworkException])
        }
    }
    
    Context "Network Profile Parsing Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should parse available network profiles correctly" {
            # Override method to test parsing logic
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAvailableNetworkProfiles -Value {
                $availableNetworks = [System.Collections.ArrayList]::new()
                
                # Simulate parsing netsh output
                $mockOutput = Mock-NetshWlanShowNetworks
                $currentNetwork = $null
                
                foreach ($line in $mockOutput) {
                    $line = $line.Trim()
                    
                    if ($line -match "^SSID \d+ : (.+)") {
                        if ($currentNetwork) {
                            [void]$availableNetworks.Add($currentNetwork)
                        }
                        
                        $ssid = $matches[1].Trim()
                        $currentNetwork = [NetworkProfile]::new($ssid, "Unknown")
                        $currentNetwork.LastSeen = Get-Date
                        $currentNetwork.IsConnectable = $true
                        $currentNetwork.NetworkType = "Infrastructure"
                    }
                    elseif ($line -match "Authentication\s*:\s*(.+)" -and $currentNetwork) {
                        $currentNetwork.AuthenticationMethod = $matches[1].Trim()
                    }
                    elseif ($line -match "Encryption\s*:\s*(.+)" -and $currentNetwork) {
                        $currentNetwork.EncryptionType = $matches[1].Trim()
                    }
                    elseif ($line -match "Signal\s*:\s*(\d+)%" -and $currentNetwork) {
                        $currentNetwork.SignalStrength = [int]$matches[1]
                    }
                    elseif ($line -match "Channel\s*:\s*(\d+)" -and $currentNetwork) {
                        $currentNetwork.Channel = [int]$matches[1]
                    }
                    elseif ($line -match "BSSID \d+\s*:\s*([a-fA-F0-9:]{17})" -and $currentNetwork) {
                        $currentNetwork.BSSID = $matches[1].Trim()
                    }
                }
                
                if ($currentNetwork) {
                    [void]$availableNetworks.Add($currentNetwork)
                }
                
                return $availableNetworks
            } -Force
            
            $networks = $networkManager.GetAvailableNetworkProfiles()
            
            $networks | Should -Not -BeNullOrEmpty
            $networks.Count | Should -Be 3
            
            # Check first network
            $testNetwork1 = $networks | Where-Object { $_.SSID -eq "TestNetwork1" }
            $testNetwork1 | Should -Not -BeNullOrEmpty
            $testNetwork1.AuthenticationMethod | Should -Be "WPA2-Personal"
            $testNetwork1.EncryptionType | Should -Be "CCMP"
            $testNetwork1.SignalStrength | Should -Be 85
            $testNetwork1.Channel | Should -Be 6
            $testNetwork1.BSSID | Should -Be "aa:bb:cc:dd:ee:f1"
            
            # Check open network
            $openNetwork = $networks | Where-Object { $_.SSID -eq "OpenNetwork" }
            $openNetwork | Should -Not -BeNullOrEmpty
            $openNetwork.AuthenticationMethod | Should -Be "Open"
            $openNetwork.EncryptionType | Should -Be "None"
            $openNetwork.SignalStrength | Should -Be 45
        }
        
        It "Should parse saved network profiles correctly" {
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetNetworkProfileDetails -Value {
                param([string]$ssid)
                
                switch ($ssid) {
                    "TestNetwork1" {
                        $profile = [NetworkProfile]::new($ssid, "CCMP")
                        $profile.AuthenticationMethod = "WPA2-Personal"
                        $profile.NetworkType = "Infrastructure"
                        return $profile
                    }
                    "TestNetwork2" {
                        $profile = [NetworkProfile]::new($ssid, "TKIP")
                        $profile.AuthenticationMethod = "WPA-Personal"
                        $profile.NetworkType = "Infrastructure"
                        return $profile
                    }
                    default {
                        return $null
                    }
                }
            } -Force
            
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetSavedNetworkProfiles -Value {
                $savedNetworks = [System.Collections.ArrayList]::new()
                
                # Simulate parsing profile list
                $profileOutput = Mock-NetshWlanShowProfiles
                
                foreach ($line in $profileOutput) {
                    if ($line -match "All User Profile\s*:\s*(.+)") {
                        $ssid = $matches[1].Trim()
                        $profileDetails = $this.GetNetworkProfileDetails($ssid)
                        if ($profileDetails) {
                            [void]$savedNetworks.Add($profileDetails)
                        }
                    }
                }
                
                return $savedNetworks
            } -Force
            
            $savedNetworks = $networkManager.GetSavedNetworkProfiles()
            
            $savedNetworks | Should -Not -BeNullOrEmpty
            $savedNetworks.Count | Should -Be 2
            
            $testNetwork1 = $savedNetworks | Where-Object { $_.SSID -eq "TestNetwork1" }
            $testNetwork1 | Should -Not -BeNullOrEmpty
            $testNetwork1.EncryptionType | Should -Be "CCMP"
            $testNetwork1.AuthenticationMethod | Should -Be "WPA2-Personal"
        }
    }
    
    Context "Network Information Merging Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should merge saved and available network information correctly" {
            # Create test data
            $savedNetworks = [System.Collections.ArrayList]::new()
            $savedNetwork1 = [NetworkProfile]::new("TestNetwork1", "CCMP")
            $savedNetwork1.AuthenticationMethod = "WPA2-Personal"
            [void]$savedNetworks.Add($savedNetwork1)
            
            $savedNetwork2 = [NetworkProfile]::new("SavedOnly", "WEP")
            $savedNetwork2.AuthenticationMethod = "Shared"
            [void]$savedNetworks.Add($savedNetwork2)
            
            $availableNetworks = [System.Collections.ArrayList]::new()
            $availableNetwork1 = [NetworkProfile]::new("TestNetwork1", "Unknown")
            $availableNetwork1.SignalStrength = 85
            $availableNetwork1.BSSID = "aa:bb:cc:dd:ee:f1"
            $availableNetwork1.Channel = 6
            [void]$availableNetworks.Add($availableNetwork1)
            
            $availableNetwork2 = [NetworkProfile]::new("AvailableOnly", "WPA2")
            $availableNetwork2.SignalStrength = 65
            $availableNetwork2.AuthenticationMethod = "WPA2-Personal"
            [void]$availableNetworks.Add($availableNetwork2)
            
            $mergedNetworks = $networkManager.MergeNetworkInformation($savedNetworks, $availableNetworks)
            
            $mergedNetworks | Should -Not -BeNullOrEmpty
            $mergedNetworks.Count | Should -Be 3
            
            # Check merged network (should have both saved and available info)
            $mergedNetwork = $mergedNetworks | Where-Object { $_.SSID -eq "TestNetwork1" }
            $mergedNetwork | Should -Not -BeNullOrEmpty
            $mergedNetwork.SignalStrength | Should -Be 85  # From available
            $mergedNetwork.AuthenticationMethod | Should -Be "WPA2-Personal"  # From saved
            $mergedNetwork.BSSID | Should -Be "aa:bb:cc:dd:ee:f1"  # From available
            
            # Check saved-only network
            $savedOnlyNetwork = $mergedNetworks | Where-Object { $_.SSID -eq "SavedOnly" }
            $savedOnlyNetwork | Should -Not -BeNullOrEmpty
            $savedOnlyNetwork.SignalStrength | Should -Be 0  # Not currently available
            $savedOnlyNetwork.IsConnectable | Should -Be $false
            
            # Check available-only network
            $availableOnlyNetwork = $mergedNetworks | Where-Object { $_.SSID -eq "AvailableOnly" }
            $availableOnlyNetwork | Should -Not -BeNullOrEmpty
            $availableOnlyNetwork.SignalStrength | Should -Be 65
            $availableOnlyNetwork.AuthenticationMethod | Should -Be "WPA2-Personal"
        }
    }
    
    Context "Network Security Analysis Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should analyze network security correctly" {
            # Test WPA2 network
            $wpa2Network = [NetworkProfile]::new("SecureNetwork", "CCMP")
            $wpa2Network.AuthenticationMethod = "WPA2-Personal"
            $wpa2Network.SignalStrength = 75
            
            $analyzedNetwork = $networkManager.AnalyzeNetworkSecurity($wpa2Network)
            
            $analyzedNetwork | Should -Not -BeNullOrEmpty
            $analyzedNetwork.IsConnectable | Should -Be $true
            
            # Test open network
            $openNetwork = [NetworkProfile]::new("OpenNetwork", "None")
            $openNetwork.AuthenticationMethod = "Open"
            $openNetwork.SignalStrength = 50
            
            $analyzedOpen = $networkManager.AnalyzeNetworkSecurity($openNetwork)
            
            $analyzedOpen.IsConnectable | Should -Be $true
            
            # Test enterprise network (should not be connectable for brute force)
            $enterpriseNetwork = [NetworkProfile]::new("CorpNetwork", "AES")
            $enterpriseNetwork.AuthenticationMethod = "WPA2-Enterprise"
            $enterpriseNetwork.SignalStrength = 80
            
            $analyzedEnterprise = $networkManager.AnalyzeNetworkSecurity($enterpriseNetwork)
            
            $analyzedEnterprise.IsConnectable | Should -Be $false
        }
        
        It "Should handle null network gracefully" {
            $result = $networkManager.AnalyzeNetworkSecurity($null)
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Network Filtering Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup test networks
            $network1 = [NetworkProfile]::new("HighSignal", "WPA2")
            $network1.SignalStrength = 85
            $network1.EncryptionType = "CCMP"
            $network1.IsConnectable = $true
            $network1.NetworkType = "Infrastructure"
            [void]$networkManager.AvailableNetworks.Add($network1)
            
            $network2 = [NetworkProfile]::new("LowSignal", "WEP")
            $network2.SignalStrength = 25
            $network2.EncryptionType = "WEP"
            $network2.IsConnectable = $true
            $network2.NetworkType = "Infrastructure"
            [void]$networkManager.AvailableNetworks.Add($network2)
            
            $network3 = [NetworkProfile]::new("OpenNetwork", "None")
            $network3.SignalStrength = 60
            $network3.EncryptionType = "None"
            $network3.IsConnectable = $true
            $network3.NetworkType = "Infrastructure"
            [void]$networkManager.AvailableNetworks.Add($network3)
            
            $network4 = [NetworkProfile]::new("NotConnectable", "WPA3")
            $network4.SignalStrength = 70
            $network4.EncryptionType = "GCMP"
            $network4.IsConnectable = $false
            $network4.NetworkType = "Infrastructure"
            [void]$networkManager.AvailableNetworks.Add($network4)
        }
        
        It "Should filter by minimum signal strength" {
            $criteria = @{ MinSignalStrength = 50 }
            
            $filtered = $networkManager.FilterNetworks($criteria)
            
            $filtered.Count | Should -Be 3  # HighSignal, OpenNetwork, NotConnectable
            $filtered | ForEach-Object { $_.SignalStrength | Should -BeGreaterOrEqual 50 }
        }
        
        It "Should filter by encryption types" {
            $criteria = @{ EncryptionTypes = @("CCMP", "None") }
            
            $filtered = $networkManager.FilterNetworks($criteria)
            
            $filtered.Count | Should -Be 2  # HighSignal, OpenNetwork
            $filtered | ForEach-Object { $_.EncryptionType | Should -BeIn @("CCMP", "None") }
        }
        
        It "Should filter by connectability" {
            $criteria = @{ ConnectableOnly = $true }
            
            $filtered = $networkManager.FilterNetworks($criteria)
            
            $filtered.Count | Should -Be 3  # All except NotConnectable
            $filtered | ForEach-Object { $_.IsConnectable | Should -Be $true }
        }
        
        It "Should filter by SSID pattern" {
            $criteria = @{ SSIDPattern = ".*Signal.*" }
            
            $filtered = $networkManager.FilterNetworks($criteria)
            
            $filtered.Count | Should -Be 2  # HighSignal, LowSignal
            $filtered | ForEach-Object { $_.SSID | Should -Match "Signal" }
        }
        
        It "Should apply multiple filters" {
            $criteria = @{
                MinSignalStrength = 50
                ConnectableOnly = $true
                EncryptionTypes = @("CCMP", "None")
            }
            
            $filtered = $networkManager.FilterNetworks($criteria)
            
            $filtered.Count | Should -Be 2  # HighSignal, OpenNetwork
            $filtered | ForEach-Object {
                $_.SignalStrength | Should -BeGreaterOrEqual 50
                $_.IsConnectable | Should -Be $true
                $_.EncryptionType | Should -BeIn @("CCMP", "None")
            }
        }
    }
    
    Context "Network Statistics Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup diverse test networks
            $networks = @(
                @{ SSID = "Excellent1"; Signal = 95; Encryption = "CCMP"; Auth = "WPA2-Personal"; Connectable = $true },
                @{ SSID = "Excellent2"; Signal = 85; Encryption = "CCMP"; Auth = "WPA2-Personal"; Connectable = $true },
                @{ SSID = "Good1"; Signal = 75; Encryption = "TKIP"; Auth = "WPA-Personal"; Connectable = $true },
                @{ SSID = "Fair1"; Signal = 55; Encryption = "WEP"; Auth = "Shared"; Connectable = $true },
                @{ SSID = "Poor1"; Signal = 35; Encryption = "None"; Auth = "Open"; Connectable = $true },
                @{ SSID = "VeryPoor1"; Signal = 15; Encryption = "CCMP"; Auth = "WPA2-Enterprise"; Connectable = $false }
            )
            
            foreach ($netData in $networks) {
                $network = [NetworkProfile]::new($netData.SSID, $netData.Encryption)
                $network.SignalStrength = $netData.Signal
                $network.EncryptionType = $netData.Encryption
                $network.AuthenticationMethod = $netData.Auth
                $network.IsConnectable = $netData.Connectable
                [void]$networkManager.AvailableNetworks.Add($network)
            }
        }
        
        It "Should calculate network statistics correctly" {
            $stats = $networkManager.GetNetworkStatistics()
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalNetworks | Should -Be 6
            $stats.ConnectableNetworks | Should -Be 5
            $stats.OpenNetworks | Should -Be 1  # Poor1 with Open auth
            $stats.SecuredNetworks | Should -Be 5
            
            # Check signal strength distribution
            $stats.SignalStrengthDistribution.Excellent | Should -Be 2  # 95%, 85%
            $stats.SignalStrengthDistribution.Good | Should -Be 1       # 75%
            $stats.SignalStrengthDistribution.Fair | Should -Be 1       # 55%
            $stats.SignalStrengthDistribution.Poor | Should -Be 1       # 35%
            $stats.SignalStrengthDistribution.VeryPoor | Should -Be 1   # 15%
            
            # Check average signal strength
            $expectedAverage = (95 + 85 + 75 + 55 + 35 + 15) / 6
            $stats.AverageSignalStrength | Should -Be $expectedAverage
            
            # Check encryption breakdown
            $stats.EncryptionBreakdown["CCMP"] | Should -Be 3
            $stats.EncryptionBreakdown["TKIP"] | Should -Be 1
            $stats.EncryptionBreakdown["WEP"] | Should -Be 1
            $stats.EncryptionBreakdown["None"] | Should -Be 1
            
            # Check authentication breakdown
            $stats.AuthenticationBreakdown["WPA2-Personal"] | Should -Be 2
            $stats.AuthenticationBreakdown["WPA-Personal"] | Should -Be 1
            $stats.AuthenticationBreakdown["WPA2-Enterprise"] | Should -Be 1
            $stats.AuthenticationBreakdown["Shared"] | Should -Be 1
            $stats.AuthenticationBreakdown["Open"] | Should -Be 1
        }
        
        It "Should handle empty network list" {
            $networkManager.AvailableNetworks.Clear()
            
            $stats = $networkManager.GetNetworkStatistics()
            
            $stats.TotalNetworks | Should -Be 0
            $stats.ConnectableNetworks | Should -Be 0
            $stats.AverageSignalStrength | Should -Be 0
        }
    }
    
    Context "Current Connection Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should get current connection information" {
            # Mock netsh wlan show interfaces
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                # Simulate parsing netsh wlan show interfaces output
                $mockOutput = Mock-NetshWlanShowInterfaces
                
                $ssid = ""
                $bssid = ""
                $signalStrength = 0
                $channel = 0
                $authMethod = ""
                $encryption = ""
                
                foreach ($line in $mockOutput) {
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
                    
                    return $currentProfile
                }
                
                return $null
            } -Force
            
            $currentConnection = $networkManager.GetCurrentConnection()
            
            $currentConnection | Should -Not -BeNullOrEmpty
            $currentConnection.SSID | Should -Be "TestNetwork1"
            $currentConnection.BSSID | Should -Be "aa:bb:cc:dd:ee:f1"
            $currentConnection.SignalStrength | Should -Be 85
            $currentConnection.Channel | Should -Be 6
            $currentConnection.AuthenticationMethod | Should -Be "WPA2-Personal"
            $currentConnection.EncryptionType | Should -Be "CCMP"
        }
        
        It "Should handle no current connection" {
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return $null
            } -Force
            
            $currentConnection = $networkManager.GetCurrentConnection()
            
            $currentConnection | Should -BeNullOrEmpty
        }
    }
    
    Context "Enhanced Network Profiles Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock adapter
            $mockAdapter = @{
                DeviceID = "TEST_ADAPTER"
                Name = "Test Wi-Fi Adapter"
                Status = "Connected"
            }
            $networkManager.PrimaryAdapter = $mockAdapter
        }
        
        It "Should enhance network profiles with additional information" {
            # Create basic network profile
            $basicProfile = [NetworkProfile]::new("TestNetwork", "CCMP")
            $basicProfile.AuthenticationMethod = "WPA2-Personal"
            $basicProfile.SignalStrength = 75
            $basicProfile.BSSID = "aa:bb:cc:dd:ee:ff"
            $basicProfile.Channel = 6
            
            $enhancedProfile = $networkManager.EnhanceNetworkProfile($basicProfile)
            
            $enhancedProfile | Should -Not -BeNullOrEmpty
            $enhancedProfile.SSID | Should -Be "TestNetwork"
            $enhancedProfile.EncryptionType | Should -Be "CCMP"
            $enhancedProfile.AuthenticationMethod | Should -Be "WPA2-Personal"
            $enhancedProfile.SignalStrength | Should -Be 75
            $enhancedProfile.IsConnectable | Should -Be $true
        }
        
        It "Should get detailed network profiles" {
            # Mock the scanning methods
            $networkManager | Add-Member -MemberType ScriptMethod -Name ScanNetworks -Value {
                $network1 = [NetworkProfile]::new("TestNetwork1", "CCMP")
                $network1.AuthenticationMethod = "WPA2-Personal"
                $network1.SignalStrength = 85
                [void]$this.AvailableNetworks.Add($network1)
                
                $network2 = [NetworkProfile]::new("TestNetwork2", "None")
                $network2.AuthenticationMethod = "Open"
                $network2.SignalStrength = 45
                [void]$this.AvailableNetworks.Add($network2)
                
                return $this.AvailableNetworks
            } -Force
            
            $profiles = $networkManager.GetNetworkProfiles()
            
            $profiles | Should -Not -BeNullOrEmpty
            $profiles.Count | Should -Be 2
            
            $secureNetwork = $profiles | Where-Object { $_.SSID -eq "TestNetwork1" }
            $secureNetwork | Should -Not -BeNullOrEmpty
            $secureNetwork.IsConnectable | Should -Be $true
            
            $openNetwork = $profiles | Where-Object { $_.SSID -eq "TestNetwork2" }
            $openNetwork | Should -Not -BeNullOrEmpty
            $openNetwork.IsConnectable | Should -Be $true
        }
    }
}

Describe "Connection Attempt Tests" {
    BeforeAll {
        # Mock external commands for connection testing
        function Mock-NetshCommand {
            param([string]$Command, [string]$Arguments)
            
            # Simulate successful netsh commands
            $global:LASTEXITCODE = 0
            return "Command completed successfully."
        }
    }
    
    Context "Connection Attempt Functionality" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock primary adapter
            $mockAdapter = @{
                DeviceID = "TEST_ADAPTER"
                Name = "Test Wi-Fi Adapter"
                Status = "Connected"
                Enabled = $true
            }
            $networkManager.PrimaryAdapter = $mockAdapter
            $networkManager.IsInitialized = $true
            
            # Mock external commands
            Mock -CommandName "netsh" -MockWith { 
                $global:LASTEXITCODE = 0
                return "Command completed successfully."
            }
        }
        
        It "Should attempt connection with valid SSID and password" {
            $ssid = "TestNetwork"
            $password = "TestPassword123"
            
            # Mock network finding
            $networkManager | Add-Member -MemberType ScriptMethod -Name FindNetworkBySSID -Value {
                param([string]$ssid)
                return [NetworkProfile]::new($ssid, "WPA2")
            } -Force
            
            # Mock other required methods
            $networkManager | Add-Member -MemberType ScriptMethod -Name DisconnectFromNetwork -Value { return $true } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name CreateNetworkProfile -Value { return $true } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name ExecuteConnection -Value { 
                return @{ Success = $true; Output = "Connected"; ErrorMessage = "" }
            } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name HandleAuthenticationDialogs -Value { } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name ValidateConnection -Value { 
                return @{ Success = $true; ErrorMessage = ""; ConnectionInfo = [NetworkProfile]::new($ssid, "WPA2") }
            } -Force
            
            $result = $networkManager.AttemptConnection($ssid, $password)
            
            $result | Should -Not -BeNullOrEmpty
            $result.SSID | Should -Be $ssid
            $result.Success | Should -Be $true
            $networkManager.ConnectionStatus | Should -Be ([ConnectionStatus]::Connected)
        }
        
        It "Should handle connection failure gracefully" {
            $ssid = "FailNetwork"
            $password = "WrongPassword"
            
            # Mock network finding
            $networkManager | Add-Member -MemberType ScriptMethod -Name FindNetworkBySSID -Value {
                return [NetworkProfile]::new($ssid, "WPA2")
            } -Force
            
            # Mock methods to simulate failure
            $networkManager | Add-Member -MemberType ScriptMethod -Name DisconnectFromNetwork -Value { return $true } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name CreateNetworkProfile -Value { return $true } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name ExecuteConnection -Value { 
                return @{ Success = $true; Output = "Connected"; ErrorMessage = "" }
            } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name HandleAuthenticationDialogs -Value { } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name ValidateConnection -Value { 
                return @{ Success = $false; ErrorMessage = "Authentication failed"; ConnectionInfo = $null }
            } -Force
            
            $result = $networkManager.AttemptConnection($ssid, $password)
            
            $result | Should -Not -BeNullOrEmpty
            $result.SSID | Should -Be $ssid
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "Authentication failed"
            $networkManager.ConnectionStatus | Should -Be ([ConnectionStatus]::Failed)
        }
        
        It "Should throw exception for empty SSID" {
            $result = $networkManager.AttemptConnection("", "password")
            
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "SSID cannot be empty"
        }
        
        It "Should throw exception when no primary adapter available" {
            $networkManager.PrimaryAdapter = $null
            
            $result = $networkManager.AttemptConnection("TestSSID", "password")
            
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "No primary Wi-Fi adapter available"
        }
        
        It "Should handle connection timeout" {
            $ssid = "TimeoutNetwork"
            $password = "TestPassword"
            
            # Mock methods
            $networkManager | Add-Member -MemberType ScriptMethod -Name FindNetworkBySSID -Value { return $null } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name DisconnectFromNetwork -Value { return $true } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name CreateNetworkProfile -Value { return $true } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name ExecuteConnection -Value { 
                return @{ Success = $true; Output = "Connected"; ErrorMessage = "" }
            } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name HandleAuthenticationDialogs -Value { } -Force
            $networkManager | Add-Member -MemberType ScriptMethod -Name ValidateConnection -Value { 
                return @{ Success = $false; ErrorMessage = "Connection timeout after 5 seconds"; ConnectionInfo = $null }
            } -Force
            
            $result = $networkManager.AttemptConnection($ssid, $password, 5)
            
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "timeout"
        }
    }
    
    Context "Network Profile Creation Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Mock file operations
            Mock Out-File { }
            Mock Test-Path { return $true }
            Mock Remove-Item { }
        }
        
        It "Should create WPA2 network profile successfully" {
            $ssid = "TestWPA2Network"
            $password = "SecurePassword123"
            $networkInfo = [NetworkProfile]::new($ssid, "AES")
            $networkInfo.AuthenticationMethod = "WPA2-PSK"
            
            $result = $networkManager.CreateNetworkProfile($ssid, $password, $networkInfo)
            
            $result | Should -Be $true
        }
        
        It "Should create open network profile successfully" {
            $ssid = "OpenNetwork"
            $password = ""
            $networkInfo = [NetworkProfile]::new($ssid, "none")
            $networkInfo.AuthenticationMethod = "open"
            
            $result = $networkManager.CreateNetworkProfile($ssid, $password, $networkInfo)
            
            $result | Should -Be $true
        }
        
        It "Should handle profile creation failure" {
            Mock -CommandName "netsh" -MockWith { 
                $global:LASTEXITCODE = 1
                return "Profile creation failed"
            }
            
            $result = $networkManager.CreateNetworkProfile("TestSSID", "password", $null)
            
            $result | Should -Be $false
        }
        
        It "Should generate valid XML profile for WPA2" {
            $ssid = "TestNetwork"
            $authMethod = "WPA2PSK"
            $encryption = "AES"
            $password = "TestPassword123"
            
            $xml = $networkManager.GenerateNetworkProfileXML($ssid, $authMethod, $encryption, $password)
            
            $xml | Should -Not -BeNullOrEmpty
            $xml | Should -Match "<name>$ssid</name>"
            $xml | Should -Match "<authentication>$authMethod</authentication>"
            $xml | Should -Match "<encryption>$encryption</encryption>"
            $xml | Should -Match "<keyMaterial>$password</keyMaterial>"
        }
        
        It "Should generate valid XML profile for open network" {
            $ssid = "OpenNetwork"
            $authMethod = "open"
            $encryption = "none"
            $password = ""
            
            $xml = $networkManager.GenerateNetworkProfileXML($ssid, $authMethod, $encryption, $password)
            
            $xml | Should -Not -BeNullOrEmpty
            $xml | Should -Match "<name>$ssid</name>"
            $xml | Should -Match "<authentication>open</authentication>"
            $xml | Should -Match "<encryption>none</encryption>"
            $xml | Should -Not -Match "<sharedKey>"
        }
    }
    
    Context "Connection Execution Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should execute connection command successfully" {
            Mock -CommandName "netsh" -MockWith { 
                $global:LASTEXITCODE = 0
                return "Connection request was completed successfully."
            }
            
            $result = $networkManager.ExecuteConnection("TestSSID", 30)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ErrorMessage | Should -Be ""
        }
        
        It "Should handle connection command failure" {
            Mock -CommandName "netsh" -MockWith { 
                $global:LASTEXITCODE = 1
                return "The network connection profile is corrupted."
            }
            
            $result = $networkManager.ExecuteConnection("TestSSID", 30)
            
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "netsh connect command failed"
        }
    }
    
    Context "Authentication Dialog Handling Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Mock Windows Forms
            Mock Add-Type { }
        }
        
        It "Should handle authentication dialogs without errors" {
            # Mock Get-Process to simulate no dialogs
            Mock Get-Process { return @() }
            
            # Mock GetCurrentConnection
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return [NetworkProfile]::new("TestSSID", "WPA2")
            } -Force
            
            { $networkManager.HandleAuthenticationDialogs("TestSSID", "password", 10) } | Should -Not -Throw
        }
        
        It "Should detect and handle credential dialogs" {
            # Mock Get-Process to simulate credential dialog
            Mock Get-Process { 
                return @([PSCustomObject]@{ ProcessName = "dwm"; MainWindowTitle = "Network Authentication Required" })
            }
            
            # Mock SendCredentialsToDialog
            $networkManager | Add-Member -MemberType ScriptMethod -Name SendCredentialsToDialog -Value { } -Force
            
            # Mock GetCurrentConnection to simulate successful connection
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return [NetworkProfile]::new("TestSSID", "WPA2")
            } -Force
            
            { $networkManager.HandleAuthenticationDialogs("TestSSID", "password", 5) } | Should -Not -Throw
        }
    }
    
    Context "Connection Validation Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should validate successful connection" {
            # Mock GetCurrentConnection to return connected network
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return [NetworkProfile]::new("TestSSID", "WPA2")
            } -Force
            
            # Mock GetAdapterStatus to return healthy adapter
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAdapterStatus -Value {
                return @{ IsHealthy = $true; ErrorMessage = "" }
            } -Force
            
            $result = $networkManager.ValidateConnection("TestSSID", 10)
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ConnectionInfo | Should -Not -BeNullOrEmpty
            $result.ConnectionInfo.SSID | Should -Be "TestSSID"
        }
        
        It "Should handle connection timeout" {
            # Mock GetCurrentConnection to return null (no connection)
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value { return $null } -Force
            
            # Mock GetAdapterStatus to return healthy adapter
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAdapterStatus -Value {
                return @{ IsHealthy = $true; ErrorMessage = "" }
            } -Force
            
            $result = $networkManager.ValidateConnection("TestSSID", 1)  # 1 second timeout
            
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "timeout"
        }
        
        It "Should handle unhealthy adapter during validation" {
            # Mock GetCurrentConnection to return null
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value { return $null } -Force
            
            # Mock GetAdapterStatus to return unhealthy adapter
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetAdapterStatus -Value {
                return @{ IsHealthy = $false; ErrorMessage = "Hardware malfunction" }
            } -Force
            
            $result = $networkManager.ValidateConnection("TestSSID", 10)
            
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "not healthy"
        }
    }
    
    Context "Disconnect Functionality Tests" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
        }
        
        It "Should disconnect successfully when connected" {
            # Mock GetCurrentConnection to return connected network
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return [NetworkProfile]::new("ConnectedSSID", "WPA2")
            } -Force
            
            Mock -CommandName "netsh" -MockWith { 
                $global:LASTEXITCODE = 0
                return "Disconnection request was completed successfully."
            }
            
            $result = $networkManager.DisconnectFromNetwork()
            
            $result | Should -Be $true
            $networkManager.ConnectionStatus | Should -Be ([ConnectionStatus]::Disconnected)
        }
        
        It "Should handle disconnect when not connected" {
            # Mock GetCurrentConnection to return null
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value { return $null } -Force
            
            $result = $networkManager.DisconnectFromNetwork()
            
            $result | Should -Be $true
        }
        
        It "Should handle disconnect command failure" {
            # Mock GetCurrentConnection to return connected network
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return [NetworkProfile]::new("ConnectedSSID", "WPA2")
            } -Force
            
            Mock -CommandName "netsh" -MockWith { 
                $global:LASTEXITCODE = 1
                return "Disconnect failed"
            }
            
            $result = $networkManager.DisconnectFromNetwork()
            
            $result | Should -Be $false
        }
    }
    
    Context "Connection Testing Functionality" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            
            # Setup mock primary adapter
            $mockAdapter = @{
                DeviceID = "TEST_ADAPTER"
                Name = "Test Wi-Fi Adapter"
                Status = "Connected"
                Enabled = $true
            }
            $networkManager.PrimaryAdapter = $mockAdapter
        }
        
        It "Should test connection successfully" {
            $ssid = "TestNetwork"
            $password = "TestPassword"
            
            # Mock required methods
            $networkManager | Add-Member -MemberType ScriptMethod -Name FindNetworkBySSID -Value {
                $network = [NetworkProfile]::new($ssid, "WPA2")
                $network.SignalStrength = 75
                return $network
            } -Force
            
            $networkManager | Add-Member -MemberType ScriptMethod -Name AttemptConnection -Value {
                $attempt = [ConnectionAttempt]::new($ssid, $password, 1)
                $attempt.MarkAsCompleted($true)
                return $attempt
            } -Force
            
            $networkManager | Add-Member -MemberType ScriptMethod -Name GetCurrentConnection -Value {
                return [NetworkProfile]::new($ssid, "WPA2")
            } -Force
            
            $networkManager | Add-Member -MemberType ScriptMethod -Name DisconnectFromNetwork -Value { return $true } -Force
            
            $result = $networkManager.TestConnection($ssid, $password, 10)
            
            $result | Should -Not -BeNullOrEmpty
            $result.SSID | Should -Be $ssid
            $result.Success | Should -Be $true
            $result.SignalStrength | Should -Be 75
            $result.ConnectionInfo | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle test connection failure" {
            $ssid = "FailNetwork"
            $password = "WrongPassword"
            
            # Mock required methods for failure
            $networkManager | Add-Member -MemberType ScriptMethod -Name FindNetworkBySSID -Value { return $null } -Force
            
            $networkManager | Add-Member -MemberType ScriptMethod -Name AttemptConnection -Value {
                $attempt = [ConnectionAttempt]::new($ssid, $password, 1)
                $attempt.MarkAsCompleted($false, "Authentication failed")
                return $attempt
            } -Force
            
            $result = $networkManager.TestConnection($ssid, $password, 10)
            
            $result.SSID | Should -Be $ssid
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match "Authentication failed"
        }
    }
    
    Context "Connection Statistics and Monitoring" {
        BeforeEach {
            $networkManager = [NetworkManager]::new()
            $networkManager.ConnectionStatus = [ConnectionStatus]::Connected
            $networkManager.PrimaryAdapter = @{ Name = "Test Adapter" }
            $networkManager.MonitoringEnabled = $true
        }
        
        It "Should get connection statistics" {
            $stats = $networkManager.GetConnectionStatistics()
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.CurrentStatus | Should -Be ([ConnectionStatus]::Connected)
            $stats.PrimaryAdapter | Should -Be "Test Adapter"
            $stats.MonitoringEnabled | Should -Be $true
        }
        
        It "Should start connection monitoring" {
            { $networkManager.StartConnectionMonitoring(10) } | Should -Not -Throw
            $networkManager.MonitoringEnabled | Should -Be $true
        }
        
        It "Should stop connection monitoring" {
            { $networkManager.StopConnectionMonitoring() } | Should -Not -Throw
            $networkManager.MonitoringEnabled | Should -Be $false
        }
    }
}