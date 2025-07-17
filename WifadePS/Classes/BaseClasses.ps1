# Base Classes and Interfaces for WifadePS

# Base exception class for all application errors
class WifadeException : System.Exception {
    [string]$Context
    [datetime]$Timestamp
    
    WifadeException([string]$message) : base($message) {
        $this.Timestamp = Get-Date
        $this.Context = ""
    }
    
    WifadeException([string]$message, [string]$context) : base($message) {
        $this.Timestamp = Get-Date
        $this.Context = $context
    }
    
    WifadeException([string]$message, [System.Exception]$innerException) : base($message, $innerException) {
        $this.Timestamp = Get-Date
        $this.Context = ""
    }
}

# Network-related exceptions
class NetworkException : WifadeException {
    [string]$AdapterName
    [string]$NetworkSSID
    
    NetworkException([string]$message) : base($message) {}
    
    NetworkException([string]$message, [string]$adapterName) : base($message) {
        $this.AdapterName = $adapterName
    }
    
    NetworkException([string]$message, [string]$adapterName, [string]$ssid) : base($message) {
        $this.AdapterName = $adapterName
        $this.NetworkSSID = $ssid
    }
}

# Configuration-related exceptions
class ConfigurationException : WifadeException {
    [string]$ConfigurationItem
    [string]$FilePath
    
    ConfigurationException([string]$message) : base($message) {}
    
    ConfigurationException([string]$message, [string]$configItem) : base($message) {
        $this.ConfigurationItem = $configItem
    }
    
    ConfigurationException([string]$message, [string]$configItem, [string]$filePath) : base($message) {
        $this.ConfigurationItem = $configItem
        $this.FilePath = $filePath
    }
}

# Security and ethical usage exceptions
class SecurityException : WifadeException {
    [string]$ViolationType
    [hashtable]$SecurityContext
    
    SecurityException([string]$message) : base($message) {
        $this.SecurityContext = @{}
    }
    
    SecurityException([string]$message, [string]$violationType) : base($message) {
        $this.ViolationType = $violationType
        $this.SecurityContext = @{}
    }
    
    SecurityException([string]$message, [string]$violationType, [hashtable]$context) : base($message) {
        $this.ViolationType = $violationType
        $this.SecurityContext = $context
    }
}

# Base interface for manager classes
class IManager {
    [bool]$IsInitialized = $false
    [hashtable]$Configuration = @{}
    
    # Virtual method to be overridden by derived classes
    [void] Initialize([hashtable]$config) {
        throw [System.NotImplementedException]::new("Initialize method must be implemented by derived class")
    }
    
    # Virtual method for cleanup
    [void] Dispose() {
        $this.IsInitialized = $false
    }
    
    # Validation method
    [bool] ValidateConfiguration([hashtable]$config) {
        return $true
    }
}

# Logging levels enumeration
enum LogLevel {
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
    Critical = 4
    Audit = 5
}

# Network connection status enumeration
enum ConnectionStatus {
    Disconnected = 0
    Connecting = 1
    Connected = 2
    Failed = 3
    Timeout = 4
}

# Attack strategy types
enum AttackStrategy {
    Dictionary = 0
    CommonPatterns = 1
    SSIDBased = 2
    Hybrid = 3
}