# Data Model Classes for WifadePS

# Network profile information
class NetworkProfile {
    [string]$SSID
    [string]$EncryptionType
    [int]$SignalStrength
    [string]$AuthenticationMethod
    [bool]$IsConnectable
    [datetime]$LastSeen
    [string]$BSSID
    [int]$Channel
    [string]$NetworkType
    
    NetworkProfile() {
        $this.LastSeen = Get-Date
        $this.IsConnectable = $false
        $this.SignalStrength = 0
    }
    
    NetworkProfile([string]$ssid, [string]$encryptionType) {
        $this.SSID = $ssid
        $this.EncryptionType = $encryptionType
        $this.LastSeen = Get-Date
        $this.IsConnectable = $false
        $this.SignalStrength = 0
    }
    
    [string] ToString() {
        return "SSID: $($this.SSID), Encryption: $($this.EncryptionType), Signal: $($this.SignalStrength)%"
    }
}

# Connection attempt tracking
class ConnectionAttempt {
    [string]$SSID
    [string]$Password
    [datetime]$Timestamp
    [bool]$Success
    [string]$ErrorMessage
    [timespan]$Duration
    [ConnectionStatus]$Status
    [int]$AttemptNumber
    
    ConnectionAttempt() {
        $this.Timestamp = Get-Date
        $this.Success = $false
        $this.Status = [ConnectionStatus]::Disconnected
        $this.Duration = [timespan]::Zero
        $this.AttemptNumber = 0
    }
    
    ConnectionAttempt([string]$ssid, [string]$password, [int]$attemptNumber) {
        $this.SSID = $ssid
        $this.Password = $password
        $this.AttemptNumber = $attemptNumber
        $this.Timestamp = Get-Date
        $this.Success = $false
        $this.Status = [ConnectionStatus]::Disconnected
        $this.Duration = [timespan]::Zero
    }
    
    [void] MarkAsStarted() {
        $this.Status = [ConnectionStatus]::Connecting
        $this.Timestamp = Get-Date
    }
    
    [void] MarkAsCompleted([bool]$success, [string]$errorMessage = "") {
        $this.Success = $success
        $this.Status = if ($success) { [ConnectionStatus]::Connected } else { [ConnectionStatus]::Failed }
        $this.ErrorMessage = $errorMessage
        $this.Duration = (Get-Date) - $this.Timestamp
    }
    
    [string] ToString() {
        $statusText = if ($this.Success) { "SUCCESS" } else { "FAILED" }
        return "[$($this.AttemptNumber)] $($this.SSID) - $statusText ($($this.Duration.TotalSeconds.ToString('F2'))s)"
    }
}

# Attack statistics and metrics
class AttackStatistics {
    [int]$TotalAttempts
    [int]$SuccessfulConnections
    [int]$FailedAttempts
    [timespan]$TotalDuration
    [hashtable]$ErrorBreakdown
    [datetime]$StartTime
    [datetime]$EndTime
    [hashtable]$SSIDStatistics
    [double]$SuccessRate
    
    AttackStatistics() {
        $this.TotalAttempts = 0
        $this.SuccessfulConnections = 0
        $this.FailedAttempts = 0
        $this.TotalDuration = [timespan]::Zero
        $this.ErrorBreakdown = @{}
        $this.SSIDStatistics = @{}
        $this.StartTime = Get-Date
        $this.SuccessRate = 0.0
    }
    
    [void] RecordAttempt([ConnectionAttempt]$attempt) {
        $this.TotalAttempts++
        
        if ($attempt.Success) {
            $this.SuccessfulConnections++
        } else {
            $this.FailedAttempts++
            
            # Track error types
            if ($attempt.ErrorMessage -and $attempt.ErrorMessage.Length -gt 0) {
                if ($this.ErrorBreakdown.ContainsKey($attempt.ErrorMessage)) {
                    $this.ErrorBreakdown[$attempt.ErrorMessage]++
                } else {
                    $this.ErrorBreakdown[$attempt.ErrorMessage] = 1
                }
            }
        }
        
        # Track per-SSID statistics
        if (-not $this.SSIDStatistics.ContainsKey($attempt.SSID)) {
            $this.SSIDStatistics[$attempt.SSID] = @{
                Attempts = 0
                Successes = 0
                Failures = 0
            }
        }
        
        $this.SSIDStatistics[$attempt.SSID].Attempts++
        if ($attempt.Success) {
            $this.SSIDStatistics[$attempt.SSID].Successes++
        } else {
            $this.SSIDStatistics[$attempt.SSID].Failures++
        }
        
        $this.TotalDuration = $this.TotalDuration.Add($attempt.Duration)
        $this.CalculateSuccessRate()
    }
    
    [void] CalculateSuccessRate() {
        if ($this.TotalAttempts -gt 0) {
            $this.SuccessRate = ($this.SuccessfulConnections / $this.TotalAttempts) * 100
        }
    }
    
    [void] Finalize() {
        $this.EndTime = Get-Date
        $this.CalculateSuccessRate()
    }
    
    [string] GetSummary() {
        $summary = @"
Attack Statistics Summary:
- Total Attempts: $($this.TotalAttempts)
- Successful Connections: $($this.SuccessfulConnections)
- Failed Attempts: $($this.FailedAttempts)
- Success Rate: $($this.SuccessRate.ToString('F2'))%
- Total Duration: $($this.TotalDuration.ToString('hh\:mm\:ss'))
- Average Time per Attempt: $((($this.TotalDuration.TotalSeconds / [Math]::Max($this.TotalAttempts, 1)).ToString('F2')))s
"@
        return $summary
    }
}

# Configuration settings container
class WifadeConfiguration {
    [string]$SSIDFilePath
    [string]$PasswordFilePath
    [bool]$ShowHelp
    [bool]$VerboseMode
    [bool]$StealthMode
    [int]$RateLimitMs
    [int]$ConnectionTimeoutSeconds
    [int]$MaxAttemptsPerSSID
    [LogLevel]$LogLevel
    [hashtable]$CustomSettings
    
    WifadeConfiguration() {
        $this.SSIDFilePath = "ssid.txt"
        $this.PasswordFilePath = "passwords.txt"
        $this.ShowHelp = $false
        $this.VerboseMode = $false
        $this.StealthMode = $false
        $this.RateLimitMs = 1000
        $this.ConnectionTimeoutSeconds = 30
        $this.MaxAttemptsPerSSID = 0  # 0 = unlimited
        $this.LogLevel = [LogLevel]::Info
        $this.CustomSettings = @{}
    }
    
    [bool] IsValid() {
        return (Test-Path $this.SSIDFilePath) -and (Test-Path $this.PasswordFilePath)
    }
    
    [string] ToString() {
        return "SSID File: $($this.SSIDFilePath), Password File: $($this.PasswordFilePath), Stealth: $($this.StealthMode)"
    }
}