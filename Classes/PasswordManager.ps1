# PasswordManager Class for wifade
# Handles password list management, attack strategies, and statistics tracking

class PasswordManager : IManager {
    [System.Collections.Generic.List[string]]$PasswordList
    [int]$CurrentIndex
    [AttackStatistics]$AttackStatistics
    [hashtable]$RateLimitSettings
    [AttackStrategy]$CurrentStrategy
    [System.Collections.Generic.List[string]]$GeneratedPasswords
    [hashtable]$PasswordCache
    [bool]$StealthMode
    [datetime]$LastAttemptTime
    [int]$MinDelayMs
    [int]$MaxDelayMs
    
    # Constructor
    PasswordManager() {
        $this.InitializeProperties()
    }
    
    # Initialize all properties
    [void] InitializeProperties() {
        # Initialize base class properties
        $this.IsInitialized = $false
        $this.Configuration = @{}
        
        # Initialize PasswordManager properties
        $this.PasswordList = [System.Collections.Generic.List[string]]::new()
        $this.CurrentIndex = 0
        $this.AttackStatistics = [AttackStatistics]::new()
        $this.RateLimitSettings = @{
            Enabled = $false
            MinDelayMs = 1000
            MaxDelayMs = 3000
            AdaptiveDelay = $false
        }
        $this.CurrentStrategy = [AttackStrategy]::Dictionary
        $this.GeneratedPasswords = [System.Collections.Generic.List[string]]::new()
        $this.PasswordCache = @{}
        $this.StealthMode = $false
        $this.LastAttemptTime = [datetime]::MinValue
        $this.MinDelayMs = 1000
        $this.MaxDelayMs = 3000
    }
    
    # Constructor with configuration
    PasswordManager([hashtable]$config) {
        $this.InitializeProperties()
        $this.ApplyConfiguration($config)
    }
    
    # Initialize the PasswordManager
    [void] Initialize([hashtable]$config) {
        try {
            Write-Verbose "Initializing PasswordManager..."
            
            # Apply configuration
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                $this.ApplyConfiguration($config)
            }
            
            # Validate required configuration
            if (-not $config.ContainsKey('PasswordFile')) {
                throw [ConfigurationException]::new("PasswordFile is required for PasswordManager initialization", "PasswordFile")
            }
            
            # Load passwords from file
            $this.LoadPasswords($config['PasswordFile'])
            
            # Initialize attack statistics
            $this.AttackStatistics = [AttackStatistics]::new()
            
            $this.IsInitialized = $true
            Write-Verbose "PasswordManager initialized successfully with $($this.PasswordList.Count) passwords"
        }
        catch {
            throw [ConfigurationException]::new("Failed to initialize PasswordManager: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Apply configuration settings
    [void] ApplyConfiguration([hashtable]$config) {
        if ($config.ContainsKey('RateLimitEnabled')) {
            $this.RateLimitSettings.Enabled = $config['RateLimitEnabled']
        }
        if ($config.ContainsKey('MinDelayMs')) {
            $this.RateLimitSettings.MinDelayMs = $config['MinDelayMs']
            $this.MinDelayMs = $config['MinDelayMs']
        }
        if ($config.ContainsKey('MaxDelayMs')) {
            $this.RateLimitSettings.MaxDelayMs = $config['MaxDelayMs']
            $this.MaxDelayMs = $config['MaxDelayMs']
        }
        if ($config.ContainsKey('AdaptiveDelay')) {
            $this.RateLimitSettings.AdaptiveDelay = $config['AdaptiveDelay']
        }
        if ($config.ContainsKey('AttackStrategy')) {
            $this.CurrentStrategy = $config['AttackStrategy']
        }
        if ($config.ContainsKey('StealthMode')) {
            $this.StealthMode = $config['StealthMode']
            if ($this.StealthMode) {
                $this.RateLimitSettings.Enabled = $true
            }
        }
    }
    
    # Load passwords from a given file path
    [void] LoadPasswords([string]$filePath) {
        try {
            if ([string]::IsNullOrWhiteSpace($filePath)) {
                throw "Password file path cannot be null or empty."
            }
            Write-Verbose "Attempting to load passwords from provided path: '$filePath'"

            $resolvedPath = $null
            
            # Primary approach: Use hardcoded installation path since we enforce installation to C:\Program Files\Wifade
            $hardcodedAppRoot = "C:\Program Files\Wifade"
            $potentialHardcodedPath = Join-Path $hardcodedAppRoot $filePath
            if (Test-Path $potentialHardcodedPath) {
                $resolvedPath = $potentialHardcodedPath
                Write-Verbose "Path resolved using hardcoded installation path: '$resolvedPath'"
            }
            
            # Fallback 1: Check if the path is already absolute
            if (-not $resolvedPath -and (Test-Path $filePath)) {
                $resolvedPath = $filePath
                Write-Verbose "Path appears to be absolute and valid: '$resolvedPath'"
            }
            
            # Fallback 2: Development environment - try relative to current script location
            if (-not $resolvedPath) {
                # For development, try common development paths
                $devPaths = @(
                    (Get-Location).Path,
                    (Split-Path $PSScriptRoot -Parent),
                    $PSScriptRoot
                )
                
                foreach ($devPath in $devPaths) {
                    if ($devPath) {
                        $potentialPath = Join-Path $devPath $filePath
                        if (Test-Path $potentialPath) {
                            $resolvedPath = $potentialPath
                            Write-Verbose "Path resolved for development: '$resolvedPath'"
                            break
                        }
                    }
                }
            }

            if (-not $resolvedPath -or -not (Test-Path $resolvedPath)) {
                throw "Could not find password file. Provided Path: '$filePath'. Hardcoded path tried: '$potentialHardcodedPath'. Current Location: '$(Get-Location)'."
            }
            
            $this.PasswordList.Clear()
            
            # Fix type conversion issue: explicitly cast to string array
            $passwordContent = Get-Content -Path $resolvedPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Get-Unique
            foreach ($password in $passwordContent) {
                $this.PasswordList.Add([string]$password)
            }
            
            Write-Verbose "Successfully loaded $($this.PasswordList.Count) unique passwords from '$resolvedPath'"
        }
        catch {
            throw [ConfigurationException]::new("Failed to load passwords from file '$filePath': $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Get next password using iterator pattern
    [string] GetNextPassword() {
        return $this.GetNextPassword($null)
    }
    
    # Get next password with optional SSID for pattern generation
    [string] GetNextPassword([string]$ssid) {
        try {
            # Check if we have passwords available
            if ($this.PasswordList.Count -eq 0) {
                throw [ConfigurationException]::new("No passwords available. Load passwords first.", "PasswordList")
            }
            
            # Handle different attack strategies
            switch ($this.CurrentStrategy) {
                ([AttackStrategy]::Dictionary) {
                    return $this.GetNextDictionaryPassword()
                }
                ([AttackStrategy]::CommonPatterns) {
                    return $this.GetNextCommonPatternPassword($ssid)
                }
                ([AttackStrategy]::SSIDBased) {
                    return $this.GetNextSSIDBasedPassword($ssid)
                }
                ([AttackStrategy]::Hybrid) {
                    return $this.GetNextHybridPassword($ssid)
                }
                default {
                    return $this.GetNextDictionaryPassword()
                }
            }
        }
        catch {
            throw [ConfigurationException]::new("Failed to get next password: $($_.Exception.Message)", $_.Exception)
        }
        
        return $null
    }
    
    # Get next password from dictionary list
    [string] GetNextDictionaryPassword() {
        if ($this.CurrentIndex -ge $this.PasswordList.Count) {
            return $null  # No more passwords
        }
        
        $password = $this.PasswordList[$this.CurrentIndex]
        $this.CurrentIndex++
        return $password
    }
    
    # Get next password using common patterns
    [string] GetNextCommonPatternPassword([string]$ssid) {
        # For now, fall back to dictionary approach
        # This can be enhanced with pattern generation logic
        return $this.GetNextDictionaryPassword()
    }
    
    # Get next password based on SSID patterns
    [string] GetNextSSIDBasedPassword([string]$ssid) {
        if ([string]::IsNullOrWhiteSpace($ssid)) {
            return $this.GetNextDictionaryPassword()
        }
        
        # Generate SSID-based passwords if not already done
        if ($this.GeneratedPasswords.Count -eq 0) {
            $this.GenerateSSIDBasedPasswords($ssid)
        }
        
        # Return generated passwords first, then fall back to dictionary
        if ($this.GeneratedPasswords.Count -gt 0) {
            $password = $this.GeneratedPasswords[0]
            $this.GeneratedPasswords.RemoveAt(0)
            return $password
        }
        
        return $this.GetNextDictionaryPassword()
    }
    
    # Get next password using hybrid approach
    [string] GetNextHybridPassword([string]$ssid) {
        # Alternate between SSID-based and dictionary passwords
        if ($this.CurrentIndex % 2 -eq 0) {
            $ssidPassword = $this.GetNextSSIDBasedPassword($ssid)
            if ($ssidPassword) {
                return $ssidPassword
            }
        }
        
        return $this.GetNextDictionaryPassword()
    }
    
    # Generate SSID-based password variations
    [void] GenerateSSIDBasedPasswords([string]$ssid) {
        try {
            if ([string]::IsNullOrWhiteSpace($ssid)) {
                return
            }
            
            Write-Verbose "Generating SSID-based passwords for: $ssid"
            
            $this.GeneratedPasswords.Clear()
            $patterns = @()
            
            # Common SSID-based patterns
            $patterns += $ssid                          # Exact SSID
            $patterns += $ssid.ToLower()               # Lowercase
            $patterns += $ssid.ToUpper()               # Uppercase
            $patterns += $ssid + "123"                 # SSID + 123
            $patterns += $ssid + "1234"                # SSID + 1234
            $patterns += $ssid + "2023"                # SSID + year
            $patterns += $ssid + "2024"                # SSID + current year
            $patterns += "password" + $ssid            # password + SSID
            $patterns += $ssid + "password"            # SSID + password
            $patterns += $ssid + "admin"               # SSID + admin
            $patterns += "admin" + $ssid               # admin + SSID
            
            # Add patterns with common suffixes
            $commonSuffixes = @("1", "12", "123", "1234", "12345", "2023", "2024", "!")
            foreach ($suffix in $commonSuffixes) {
                $patterns += $ssid + $suffix
            }
            
            # Add patterns with common prefixes
            $commonPrefixes = @("wifi", "net", "home", "guest")
            foreach ($prefix in $commonPrefixes) {
                $patterns += $prefix + $ssid
            }
            
            # Remove duplicates and add to generated passwords
            $uniquePatterns = $patterns | Select-Object -Unique
            foreach ($pattern in $uniquePatterns) {
                if (-not [string]::IsNullOrWhiteSpace($pattern) -and $pattern.Length -le 63) {
                    $this.GeneratedPasswords.Add($pattern)
                }
            }
            
            Write-Verbose "Generated $($this.GeneratedPasswords.Count) SSID-based password patterns"
        }
        catch {
            Write-Warning "Failed to generate SSID-based passwords: $($_.Exception.Message)"
        }
    }
    
    # Reset password iterator
    [void] Reset() {
        $this.CurrentIndex = 0
        $this.GeneratedPasswords.Clear()
        Write-Verbose "Password iterator reset"
    }
    
    # Check if more passwords are available
    [bool] HasMorePasswords() {
        switch ($this.CurrentStrategy) {
            ([AttackStrategy]::Dictionary) {
                return $this.CurrentIndex -lt $this.PasswordList.Count
            }
            ([AttackStrategy]::SSIDBased) {
                return $this.GeneratedPasswords.Count -gt 0 -or $this.CurrentIndex -lt $this.PasswordList.Count
            }
            ([AttackStrategy]::Hybrid) {
                return $this.GeneratedPasswords.Count -gt 0 -or $this.CurrentIndex -lt $this.PasswordList.Count
            }
            default {
                return $this.CurrentIndex -lt $this.PasswordList.Count
            }
        }
        
        return $false
    }
    
    # Get total password count
    [int] GetTotalPasswordCount() {
        $total = $this.PasswordList.Count
        if ($this.CurrentStrategy -eq [AttackStrategy]::SSIDBased -or $this.CurrentStrategy -eq [AttackStrategy]::Hybrid) {
            $total += $this.GeneratedPasswords.Count
        }
        return $total
    }
    
    # Get current progress
    [hashtable] GetProgress() {
        $totalPasswords = $this.GetTotalPasswordCount()
        $processedPasswords = $this.CurrentIndex
        
        if ($this.CurrentStrategy -eq [AttackStrategy]::SSIDBased -or $this.CurrentStrategy -eq [AttackStrategy]::Hybrid) {
            # Account for consumed generated passwords
            $originalGeneratedCount = if ($this.GeneratedPasswords.Count -gt 0) { $this.GeneratedPasswords.Count } else { 0 }
            $processedPasswords += $originalGeneratedCount
        }
        
        $progressPercent = if ($totalPasswords -gt 0) { ($processedPasswords / $totalPasswords) * 100 } else { 0 }
        
        return @{
            CurrentIndex = $this.CurrentIndex
            TotalPasswords = $totalPasswords
            ProcessedPasswords = $processedPasswords
            RemainingPasswords = $totalPasswords - $processedPasswords
            ProgressPercent = [Math]::Round($progressPercent, 2)
            Strategy = $this.CurrentStrategy.ToString()
        }
    }
    
    # Implement rate limiting
    [void] ImplementRateLimiting() {
        if (-not $this.RateLimitSettings.Enabled -and -not $this.StealthMode) {
            return
        }
        
        try {
            $currentTime = Get-Date
            
            # Calculate time since last attempt
            if ($this.LastAttemptTime -ne [datetime]::MinValue) {
                $timeSinceLastAttempt = $currentTime - $this.LastAttemptTime
                
                # Determine delay based on settings
                $delayMs = $this.MinDelayMs
                
                if ($this.RateLimitSettings.AdaptiveDelay) {
                    # Adaptive delay based on recent success/failure rate
                    $recentFailureRate = $this.CalculateRecentFailureRate()
                    if ($recentFailureRate -gt 0.8) {
                        # High failure rate - increase delay
                        $delayMs = $this.MaxDelayMs
                    } elseif ($recentFailureRate -lt 0.2) {
                        # Low failure rate - use minimum delay
                        $delayMs = $this.MinDelayMs
                    } else {
                        # Moderate failure rate - use random delay in range
                        $delayMs = Get-Random -Minimum $this.MinDelayMs -Maximum $this.MaxDelayMs
                    }
                } else {
                    # Fixed or random delay
                    if ($this.MinDelayMs -eq $this.MaxDelayMs) {
                        $delayMs = $this.MinDelayMs
                    } else {
                        $delayMs = Get-Random -Minimum $this.MinDelayMs -Maximum $this.MaxDelayMs
                    }
                }
                
                # Apply delay if needed
                $requiredDelay = $delayMs - $timeSinceLastAttempt.TotalMilliseconds
                if ($requiredDelay -gt 0) {
                    Write-Verbose "Rate limiting: Waiting $([Math]::Round($requiredDelay))ms"
                    Start-Sleep -Milliseconds ([Math]::Round($requiredDelay))
                }
            }
            
            $this.LastAttemptTime = Get-Date
        }
        catch {
            Write-Warning "Error in rate limiting: $($_.Exception.Message)"
        }
    }
    
    # Calculate recent failure rate for adaptive delay
    [double] CalculateRecentFailureRate() {
        # Simple implementation - can be enhanced with sliding window
        if ($this.AttackStatistics.TotalAttempts -eq 0) {
            return 0.5  # Default moderate rate
        }
        
        return ($this.AttackStatistics.FailedAttempts / $this.AttackStatistics.TotalAttempts)
    }
    
    # Record connection attempt
    [void] RecordAttempt([ConnectionAttempt]$attempt) {
        try {
            $this.AttackStatistics.RecordAttempt($attempt)
            Write-Verbose "Recorded attempt: $($attempt.ToString())"
        }
        catch {
            Write-Warning "Failed to record attempt: $($_.Exception.Message)"
        }
    }
    
    # Get attack statistics
    [AttackStatistics] GetStatistics() {
        return $this.AttackStatistics
    }
    
    # Set attack strategy
    [void] SetAttackStrategy([AttackStrategy]$strategy) {
        $this.CurrentStrategy = $strategy
        Write-Verbose "Attack strategy changed to: $($strategy.ToString())"
        
        # Reset iterator when strategy changes
        $this.Reset()
    }
    
    # Enable/disable stealth mode
    [void] SetStealthMode([bool]$enabled) {
        $this.StealthMode = $enabled
        if ($enabled) {
            $this.RateLimitSettings.Enabled = $true
            Write-Verbose "Stealth mode enabled - rate limiting activated"
        } else {
            Write-Verbose "Stealth mode disabled"
        }
    }
    
    # Validate configuration
    [bool] ValidateConfiguration([hashtable]$config) {
        try {
            # Validate password file path
            if ($config.ContainsKey('PasswordFilePath')) {
                $filePath = $config['PasswordFilePath']
                if ([string]::IsNullOrWhiteSpace($filePath)) {
                    throw [ConfigurationException]::new("PasswordFilePath cannot be empty", "PasswordFilePath")
                }
                if (-not (Test-Path $filePath)) {
                    throw [ConfigurationException]::new("Password file not found: $filePath", "PasswordFilePath", $filePath)
                }
            }
            
            # Validate rate limiting settings
            if ($config.ContainsKey('MinDelayMs')) {
                $minDelay = $config['MinDelayMs']
                if ($minDelay -lt 0 -or $minDelay -gt 60000) {
                    throw [ConfigurationException]::new("MinDelayMs must be between 0 and 60000", "MinDelayMs")
                }
            }
            
            if ($config.ContainsKey('MaxDelayMs')) {
                $maxDelay = $config['MaxDelayMs']
                if ($maxDelay -lt 0 -or $maxDelay -gt 60000) {
                    throw [ConfigurationException]::new("MaxDelayMs must be between 0 and 60000", "MaxDelayMs")
                }
                
                # Ensure max >= min
                $minDelay = if ($config.ContainsKey('MinDelayMs')) { $config['MinDelayMs'] } else { $this.MinDelayMs }
                if ($maxDelay -lt $minDelay) {
                    throw [ConfigurationException]::new("MaxDelayMs must be greater than or equal to MinDelayMs", "MaxDelayMs")
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
            Write-Verbose "Disposing PasswordManager resources..."
            
            # Finalize statistics
            $this.AttackStatistics.Finalize()
            
            # Clear collections
            $this.PasswordList.Clear()
            $this.GeneratedPasswords.Clear()
            $this.PasswordCache.Clear()
            
            # Reset properties
            $this.CurrentIndex = 0
            $this.LastAttemptTime = [datetime]::MinValue
            
            $this.IsInitialized = $false
            Write-Verbose "PasswordManager disposed successfully"
        }
        catch {
            Write-Warning "Error during PasswordManager disposal: $($_.Exception.Message)"
        }
    }
}