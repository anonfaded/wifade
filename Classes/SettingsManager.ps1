# SettingsManager Class for wifade
# Handles persistent configuration and settings storage

class SettingsManager : IManager {
    [string]$ConfigFilePath
    [hashtable]$Settings
    [hashtable]$DefaultSettings
    
    # Constructor
    SettingsManager() {
        $this.InitializeProperties()
    }
    
    # Constructor with configuration
    SettingsManager([hashtable]$config) {
        $this.InitializeProperties()
        $this.ApplyConfiguration($config)
    }
    
    # Initialize all properties
    [void] InitializeProperties() {
        # Initialize base class properties
        $this.IsInitialized = $false
        $this.Configuration = @{}
        
        # Set default config file path
        $configDir = Join-Path $env:USERPROFILE ".wifade"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $this.ConfigFilePath = Join-Path $configDir "config.json"
        
        # Initialize default settings
        $this.DefaultSettings = @{
            EthicalDisclaimerAccepted     = $false
            EthicalDisclaimerAcceptedDate = $null
            VerboseMode                   = $false
            ConnectionTimeoutSeconds      = 30
            MaxAttemptsPerSSID            = 0
            DefaultSSIDFile               = "ssid.txt"
            DefaultPasswordFile           = "passwords.txt"
            ColorScheme                   = @{
                Primary   = "Cyan"
                Secondary = "White"
                Success   = "Green"
                Warning   = "Yellow"
                Error     = "Red"
                Info      = "Blue"
                Verbose   = "Gray"
                Highlight = "Magenta"
                Border    = "DarkCyan"
            }
            LastUsed                      = $null
            Version                       = "1.0.0"
        }
        
        $this.Settings = @{}
    }
    
    # Initialize the SettingsManager
    [void] Initialize([hashtable]$config) {
        try {
            Write-Debug "Initializing SettingsManager..."
            
            # Apply configuration
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                $this.ApplyConfiguration($config)
            }
            
            # Load existing settings or create defaults
            $this.LoadSettings()
            
            $this.IsInitialized = $true
            Write-Debug "SettingsManager initialized successfully"
        }
        catch {
            throw [ConfigurationException]::new("Failed to initialize SettingsManager: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Apply configuration settings
    [void] ApplyConfiguration([hashtable]$config) {
        if ($config.ContainsKey('ConfigFilePath')) {
            $this.ConfigFilePath = $config['ConfigFilePath']
        }
    }
    
    # Load settings from file
    [void] LoadSettings() {
        try {
            if (Test-Path $this.ConfigFilePath) {
                Write-Debug "Loading settings from: $($this.ConfigFilePath)"
                $jsonContent = Get-Content -Path $this.ConfigFilePath -Raw -ErrorAction Stop
                $loadedSettings = $jsonContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                
                # Merge with defaults (defaults take precedence for missing keys)
                $this.Settings = $this.DefaultSettings.Clone()
                foreach ($key in $loadedSettings.Keys) {
                    $this.Settings[$key] = $loadedSettings[$key]
                }
                
                Write-Debug "Settings loaded successfully"
            }
            else {
                Write-Debug "No existing settings file found, using defaults"
                $this.Settings = $this.DefaultSettings.Clone()
                $this.SaveSettings()
            }
        }
        catch {
            Write-Warning "Failed to load settings: $($_.Exception.Message). Using defaults."
            $this.Settings = $this.DefaultSettings.Clone()
        }
    }
    
    # Save settings to file
    [void] SaveSettings() {
        try {
            Write-Debug "Saving settings to: $($this.ConfigFilePath)"
            
            # Ensure directory exists
            $configDir = Split-Path $this.ConfigFilePath -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            
            # Update last used timestamp
            $this.Settings.LastUsed = Get-Date
            
            # Convert to JSON and save
            $jsonContent = $this.Settings | ConvertTo-Json -Depth 10
            $jsonContent | Set-Content -Path $this.ConfigFilePath -Encoding UTF8 -ErrorAction Stop
            
            Write-Debug "Settings saved successfully"
        }
        catch {
            Write-Warning "Failed to save settings: $($_.Exception.Message)"
        }
    }
    
    # Get a setting value
    [object] GetSetting([string]$key) {
        if ($this.Settings.ContainsKey($key)) {
            return $this.Settings[$key]
        }
        return $null
    }
    
    # Set a setting value
    [void] SetSetting([string]$key, [object]$value) {
        $this.Settings[$key] = $value
        Write-Debug "Setting updated: $key = $value"
    }
    
    # Check if ethical disclaimer has been accepted
    [bool] IsEthicalDisclaimerAccepted() {
        return $this.GetSetting('EthicalDisclaimerAccepted') -eq $true
    }
    
    # Mark ethical disclaimer as accepted
    [void] AcceptEthicalDisclaimer() {
        $this.SetSetting('EthicalDisclaimerAccepted', $true)
        $this.SetSetting('EthicalDisclaimerAcceptedDate', (Get-Date))
        $this.SaveSettings()
        Write-Debug "Ethical disclaimer accepted and saved"
    }
    
    # Reset ethical disclaimer (for testing purposes)
    [void] ResetEthicalDisclaimer() {
        $this.SetSetting('EthicalDisclaimerAccepted', $false)
        $this.SetSetting('EthicalDisclaimerAcceptedDate', $null)
        $this.SaveSettings()
        Write-Debug "Ethical disclaimer reset"
    }
    
    # Get verbose mode setting
    [bool] IsVerboseMode() {
        return $this.GetSetting('VerboseMode') -eq $true
    }
    
    # Set verbose mode
    [void] SetVerboseMode([bool]$enabled) {
        $this.SetSetting('VerboseMode', $enabled)
        $this.SaveSettings()
    }
    
    # Get connection timeout setting
    [int] GetConnectionTimeout() {
        $timeout = $this.GetSetting('ConnectionTimeoutSeconds')
        if ($timeout) { 
            return $timeout 
        }
        else { 
            return 30 
        }
    }
    
    # Set connection timeout
    [void] SetConnectionTimeout([int]$seconds) {
        if ($seconds -lt 5 -or $seconds -gt 300) {
            throw [ConfigurationException]::new("Connection timeout must be between 5 and 300 seconds", "ConnectionTimeoutSeconds")
        }
        $this.SetSetting('ConnectionTimeoutSeconds', $seconds)
        $this.SaveSettings()
    }
    
    # Get max attempts per SSID setting
    [int] GetMaxAttemptsPerSSID() {
        $maxAttempts = $this.GetSetting('MaxAttemptsPerSSID')
        if ($maxAttempts) { 
            return $maxAttempts 
        }
        else { 
            return 0 
        }
    }
    
    # Set max attempts per SSID
    [void] SetMaxAttemptsPerSSID([int]$attempts) {
        if ($attempts -lt 0) {
            throw [ConfigurationException]::new("Max attempts per SSID cannot be negative", "MaxAttemptsPerSSID")
        }
        $this.SetSetting('MaxAttemptsPerSSID', $attempts)
        $this.SaveSettings()
    }
    
    # Get default SSID file path
    [string] GetDefaultSSIDFile() {
        $ssidFile = $this.GetSetting('DefaultSSIDFile')
        if ($ssidFile) { 
            return $ssidFile 
        }
        else { 
            return "ssid.txt" 
        }
    }
    
    # Set default SSID file path
    [void] SetDefaultSSIDFile([string]$filePath) {
        $this.SetSetting('DefaultSSIDFile', $filePath)
        $this.SaveSettings()
    }
    
    # Get default password file path
    [string] GetDefaultPasswordFile() {
        $passwordFile = $this.GetSetting('DefaultPasswordFile')
        if ($passwordFile) { 
            return $passwordFile 
        }
        else { 
            return "passwords.txt" 
        }
    }
    
    # Set default password file path
    [void] SetDefaultPasswordFile([string]$filePath) {
        $this.SetSetting('DefaultPasswordFile', $filePath)
        $this.SaveSettings()
    }
    
    # Get color scheme
    [hashtable] GetColorScheme() {
        $colorScheme = $this.GetSetting('ColorScheme')
        if ($colorScheme) { 
            return $colorScheme 
        }
        else { 
            return $this.DefaultSettings.ColorScheme 
        }
    }
    
    # Set color scheme
    [void] SetColorScheme([hashtable]$colorScheme) {
        $this.SetSetting('ColorScheme', $colorScheme)
        $this.SaveSettings()
    }
    
    # Export settings to a file
    [void] ExportSettings([string]$filePath) {
        try {
            $exportData = @{
                ExportedDate = Get-Date
                Version      = $this.GetSetting('Version')
                Settings     = $this.Settings
            }
            
            $jsonContent = $exportData | ConvertTo-Json -Depth 10
            $jsonContent | Set-Content -Path $filePath -Encoding UTF8 -ErrorAction Stop
            
            Write-Debug "Settings exported to: $filePath"
        }
        catch {
            throw [ConfigurationException]::new("Failed to export settings: $($_.Exception.Message)", "ExportSettings", $filePath)
        }
    }
    
    # Import settings from a file
    [void] ImportSettings([string]$filePath) {
        try {
            if (-not (Test-Path $filePath)) {
                throw [ConfigurationException]::new("Settings file not found: $filePath", "ImportSettings", $filePath)
            }
            
            $jsonContent = Get-Content -Path $filePath -Raw -ErrorAction Stop
            $importData = $jsonContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            
            if ($importData.ContainsKey('Settings')) {
                # Merge imported settings with current settings
                foreach ($key in $importData.Settings.Keys) {
                    $this.Settings[$key] = $importData.Settings[$key]
                }
                
                $this.SaveSettings()
                Write-Debug "Settings imported from: $filePath"
            }
            else {
                throw [ConfigurationException]::new("Invalid settings file format", "ImportSettings", $filePath)
            }
        }
        catch {
            throw [ConfigurationException]::new("Failed to import settings: $($_.Exception.Message)", "ImportSettings", $filePath)
        }
    }
    
    # Reset all settings to defaults
    [void] ResetToDefaults() {
        $this.Settings = $this.DefaultSettings.Clone()
        $this.SaveSettings()
        Write-Debug "Settings reset to defaults"
    }
    
    # Get all settings as a hashtable
    [hashtable] GetAllSettings() {
        return $this.Settings.Clone()
    }
    
    # Validate configuration
    [bool] ValidateConfiguration([hashtable]$config) {
        return $true
    }
    
    # Dispose resources
    [void] Dispose() {
        try {
            Write-Debug "Disposing SettingsManager resources..."
            
            # Save settings before disposing
            if ($this.IsInitialized) {
                $this.SaveSettings()
            }
            
            $this.IsInitialized = $false
            Write-Debug "SettingsManager disposed successfully"
        }
        catch {
            Write-Warning "Error during SettingsManager disposal: $($_.Exception.Message)"
        }
    }
}