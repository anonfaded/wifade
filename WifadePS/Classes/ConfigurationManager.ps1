# ConfigurationManager Class for WifadePS
# Handles command-line parameter parsing and configuration file management

class ConfigurationManager : IManager {
    [WifadeConfiguration]$Configuration
    [hashtable]$CommandLineArgs
    [string[]]$ValidParameters
    [bool]$HelpRequested
    
    ConfigurationManager() {
        $this.Configuration = [WifadeConfiguration]::new()
        $this.CommandLineArgs = [hashtable]::new()
        $this.ValidParameters = @('-s', '-w', '-h', '--ssid', '--password', '--help')
        $this.HelpRequested = $false
        $this.IsInitialized = $false
    }
    
    ConfigurationManager([hashtable]$initialConfig) {
        $this.Configuration = [WifadeConfiguration]::new()
        $this.CommandLineArgs = [hashtable]::new()
        $this.ValidParameters = @('-s', '-w', '-h', '--ssid', '--password', '--help')
        $this.HelpRequested = $false
        $this.IsInitialized = $false
        
        # Apply initial configuration
        if ($initialConfig) {
            $this.ApplyConfiguration($initialConfig)
        }
    }
    
    # Override Initialize method from IManager
    [void] Initialize([hashtable]$config) {
        try {
            Write-Verbose "Initializing ConfigurationManager..."
            
            if ($config) {
                $this.ApplyConfiguration($config)
                # Validate configuration after applying it
                $this.ValidateConfiguration(@{})
            }
            
            $this.IsInitialized = $true
            Write-Verbose "ConfigurationManager initialized successfully"
            
        } catch [ConfigurationException] {
            # Re-throw ConfigurationException as-is
            throw
        } catch {
            throw [ConfigurationException]::new("Failed to initialize ConfigurationManager: $($_.Exception.Message)")
        }
    }
    
    # Parse command-line arguments in Linux-style format
    [WifadeConfiguration] ParseCommandLineArguments([string[]]$arguments) {
        try {
            Write-Verbose "Parsing command-line arguments: $($arguments -join ' ')"
            
            $this.CommandLineArgs.Clear()
            $i = 0
            
            while ($i -lt $arguments.Length) {
                $arg = $arguments[$i]
                Write-Verbose "Processing argument: '$arg'"
                
                switch ($arg) {
                    { $_ -eq '-s' -or $_ -eq '--ssid' } {
                        Write-Verbose "Matched SSID parameter"
                        if (($i + 1) -ge $arguments.Length) {
                            throw [ConfigurationException]::new("Parameter '$arg' requires a value", "SSIDFile")
                        }
                        $this.Configuration.SSIDFilePath = $arguments[$i + 1]
                        $this.CommandLineArgs['SSIDFile'] = $arguments[$i + 1]
                        Write-Verbose "Set SSID file to: $($arguments[$i + 1])"
                        $i += 2
                        break
                    }
                    
                    { $_ -eq '-w' -or $_ -eq '--password' } {
                        if (($i + 1) -ge $arguments.Length) {
                            throw [ConfigurationException]::new("Parameter '$arg' requires a value", "PasswordFile")
                        }
                        $this.Configuration.PasswordFilePath = $arguments[$i + 1]
                        $this.CommandLineArgs['PasswordFile'] = $arguments[$i + 1]
                        $i += 2
                        break
                    }
                    
                    { $_ -eq '-h' -or $_ -eq '--help' } {
                        $this.Configuration.ShowHelp = $true
                        $this.HelpRequested = $true
                        $this.CommandLineArgs['Help'] = $true
                        $i++
                        break
                    }
                    
                    { $_ -eq '-v' -or $_ -eq '--verbose' } {
                        $this.Configuration.VerboseMode = $true
                        $this.Configuration.LogLevel = [LogLevel]::Debug
                        $this.CommandLineArgs['Verbose'] = $true
                        $i++
                        break
                    }
                    
                    '--stealth' {
                        $this.Configuration.StealthMode = $true
                        $this.CommandLineArgs['Stealth'] = $true
                        $i++
                        break
                    }
                    
                    '--rate-limit' {
                        if (($i + 1) -ge $arguments.Length) {
                            throw [ConfigurationException]::new("Parameter '$arg' requires a numeric value", "RateLimit")
                        }
                        $rateLimitValue = 0
                        if (-not [int]::TryParse($arguments[$i + 1], [ref]$rateLimitValue) -or $rateLimitValue -lt 0) {
                            throw [ConfigurationException]::new("Invalid rate limit value: $($arguments[$i + 1]). Must be a positive integer.", "RateLimit")
                        }
                        $this.Configuration.RateLimitMs = $rateLimitValue
                        $this.CommandLineArgs['RateLimit'] = $rateLimitValue
                        $i += 2
                        break
                    }
                    
                    '--timeout' {
                        if (($i + 1) -ge $arguments.Length) {
                            throw [ConfigurationException]::new("Parameter '$arg' requires a numeric value", "Timeout")
                        }
                        $timeoutValue = 0
                        if (-not [int]::TryParse($arguments[$i + 1], [ref]$timeoutValue) -or $timeoutValue -le 0) {
                            throw [ConfigurationException]::new("Invalid timeout value: $($arguments[$i + 1]). Must be a positive integer.", "Timeout")
                        }
                        $this.Configuration.ConnectionTimeoutSeconds = $timeoutValue
                        $this.CommandLineArgs['Timeout'] = $timeoutValue
                        $i += 2
                        break
                    }
                    
                    '--max-attempts' {
                        if (($i + 1) -ge $arguments.Length) {
                            throw [ConfigurationException]::new("Parameter '$arg' requires a numeric value", "MaxAttempts")
                        }
                        $maxAttemptsValue = 0
                        if (-not [int]::TryParse($arguments[$i + 1], [ref]$maxAttemptsValue) -or $maxAttemptsValue -lt 0) {
                            throw [ConfigurationException]::new("Invalid max attempts value: $($arguments[$i + 1]). Must be a non-negative integer.", "MaxAttempts")
                        }
                        $this.Configuration.MaxAttemptsPerSSID = $maxAttemptsValue
                        $this.CommandLineArgs['MaxAttempts'] = $maxAttemptsValue
                        $i += 2
                        break
                    }
                    
                    default {
                        if ($arg.StartsWith('-')) {
                            throw [ConfigurationException]::new("Unknown parameter: $arg", "UnknownParameter")
                        } else {
                            throw [ConfigurationException]::new("Unexpected argument: $arg", "UnexpectedArgument")
                        }
                    }
                }
            }
            
            Write-Verbose "Command-line parsing completed successfully"
            Write-Verbose "SSID File: $($this.Configuration.SSIDFilePath)"
            Write-Verbose "Password File: $($this.Configuration.PasswordFilePath)"
            Write-Verbose "Help Requested: $($this.Configuration.ShowHelp)"
            
            return $this.Configuration
            
        } catch [ConfigurationException] {
            throw
        } catch {
            throw [ConfigurationException]::new("Failed to parse command-line arguments: $($_.Exception.Message)")
        }
    }
    
    # Validate SSID file exists and is readable
    [bool] ValidateSSIDFile([string]$filePath) {
        try {
            Write-Verbose "Validating SSID file: $filePath"
            
            if ([string]::IsNullOrWhiteSpace($filePath)) {
                throw [ConfigurationException]::new("SSID file path cannot be empty", "SSIDFile", $filePath)
            }
            
            if (-not (Test-Path $filePath -PathType Leaf)) {
                throw [ConfigurationException]::new("SSID file not found: $filePath", "SSIDFile", $filePath)
            }
            
            # Check if file is readable
            try {
                $content = Get-Content $filePath -ErrorAction Stop
            } catch {
                throw [ConfigurationException]::new("Cannot read SSID file: $filePath. Error: $($_.Exception.Message)", "SSIDFile", $filePath)
            }
            
            # Check if file has content
            if (-not $content -or $content.Count -eq 0) {
                throw [ConfigurationException]::new("SSID file is empty: $filePath", "SSIDFile", $filePath)
            }
            
            # Validate SSID format (basic validation)
            $validSSIDs = 0
            foreach ($line in $content) {
                $ssid = $line.Trim()
                if (-not [string]::IsNullOrWhiteSpace($ssid)) {
                    # Check SSID length (IEEE 802.11 standard: 0-32 bytes)
                    if ($ssid.Length -gt 32) {
                        Write-Warning "SSID '$ssid' exceeds maximum length of 32 characters and may not be valid"
                    }
                    $validSSIDs++
                }
            }
            
            if ($validSSIDs -eq 0) {
                throw [ConfigurationException]::new("No valid SSIDs found in file: $filePath", "SSIDFile", $filePath)
            }
            
            Write-Verbose "SSID file validation successful. Found $validSSIDs valid SSIDs"
            return $true
            
        } catch [ConfigurationException] {
            throw
        } catch {
            throw [ConfigurationException]::new("SSID file validation failed: $($_.Exception.Message)", "SSIDFile", $filePath)
        }
    }
    
    # Validate password file exists and is readable
    [bool] ValidatePasswordFile([string]$filePath) {
        try {
            Write-Verbose "Validating password file: $filePath"
            
            if ([string]::IsNullOrWhiteSpace($filePath)) {
                throw [ConfigurationException]::new("Password file path cannot be empty", "PasswordFile", $filePath)
            }
            
            if (-not (Test-Path $filePath -PathType Leaf)) {
                throw [ConfigurationException]::new("Password file not found: $filePath", "PasswordFile", $filePath)
            }
            
            # Check if file is readable
            try {
                $content = Get-Content $filePath -ErrorAction Stop
            } catch {
                throw [ConfigurationException]::new("Cannot read password file: $filePath. Error: $($_.Exception.Message)", "PasswordFile", $filePath)
            }
            
            # Check if file has content
            if (-not $content -or $content.Count -eq 0) {
                throw [ConfigurationException]::new("Password file is empty: $filePath", "PasswordFile", $filePath)
            }
            
            # Validate password format (basic validation)
            $validPasswords = 0
            foreach ($line in $content) {
                $password = $line.Trim()
                if (-not [string]::IsNullOrWhiteSpace($password)) {
                    # Check password length (WPA/WPA2: 8-63 characters, WEP: 5, 10, 13, or 26 characters)
                    if ($password.Length -lt 5) {
                        Write-Warning "Password '$password' is shorter than minimum length (5 characters) and may not be valid for most networks"
                    } elseif ($password.Length -gt 63) {
                        Write-Warning "Password '$password' exceeds maximum WPA/WPA2 length (63 characters) and may not be valid"
                    }
                    $validPasswords++
                }
            }
            
            if ($validPasswords -eq 0) {
                throw [ConfigurationException]::new("No valid passwords found in file: $filePath", "PasswordFile", $filePath)
            }
            
            Write-Verbose "Password file validation successful. Found $validPasswords valid passwords"
            return $true
            
        } catch [ConfigurationException] {
            throw
        } catch {
            throw [ConfigurationException]::new("Password file validation failed: $($_.Exception.Message)", "PasswordFile", $filePath)
        }
    }
    
    # Load SSID list from file
    [string[]] LoadSSIDList([string]$filePath) {
        try {
            Write-Verbose "Loading SSID list from: $filePath"
            
            # Validate file first
            $this.ValidateSSIDFile($filePath)
            
            $content = Get-Content $filePath -ErrorAction Stop
            $ssidList = @()
            
            foreach ($line in $content) {
                $ssid = $line.Trim()
                if (-not [string]::IsNullOrWhiteSpace($ssid)) {
                    $ssidList += $ssid
                }
            }
            
            Write-Verbose "Successfully loaded $($ssidList.Count) SSIDs"
            return $ssidList
            
        } catch [ConfigurationException] {
            throw
        } catch {
            throw [ConfigurationException]::new("Failed to load SSID list: $($_.Exception.Message)", "SSIDFile", $filePath)
        }
    }
    
    # Load password list from file
    [string[]] LoadPasswordList([string]$filePath) {
        try {
            Write-Verbose "Loading password list from: $filePath"
            
            # Validate file first
            $this.ValidatePasswordFile($filePath)
            
            $content = Get-Content $filePath -ErrorAction Stop
            $passwordList = @()
            
            foreach ($line in $content) {
                $password = $line.Trim()
                if (-not [string]::IsNullOrWhiteSpace($password)) {
                    $passwordList += $password
                }
            }
            
            Write-Verbose "Successfully loaded $($passwordList.Count) passwords"
            return $passwordList
            
        } catch [ConfigurationException] {
            throw
        } catch {
            throw [ConfigurationException]::new("Failed to load password list: $($_.Exception.Message)", "PasswordFile", $filePath)
        }
    }
    
    # Override ValidateConfiguration method from IManager
    [bool] ValidateConfiguration([hashtable]$config) {
        try {
            Write-Verbose "Validating configuration..."
            
            # Validate SSID file if path is set
            if ($this.Configuration.SSIDFilePath -and -not [string]::IsNullOrWhiteSpace($this.Configuration.SSIDFilePath)) {
                $this.ValidateSSIDFile($this.Configuration.SSIDFilePath)
            }
            
            # Validate password file if path is set
            if ($this.Configuration.PasswordFilePath -and -not [string]::IsNullOrWhiteSpace($this.Configuration.PasswordFilePath)) {
                $this.ValidatePasswordFile($this.Configuration.PasswordFilePath)
            }
            
            # Validate numeric parameters
            if ($this.Configuration.RateLimitMs -lt 0) {
                throw [ConfigurationException]::new("Rate limit must be non-negative", "RateLimit")
            }
            
            if ($this.Configuration.ConnectionTimeoutSeconds -le 0) {
                throw [ConfigurationException]::new("Connection timeout must be positive", "Timeout")
            }
            
            if ($this.Configuration.MaxAttemptsPerSSID -lt 0) {
                throw [ConfigurationException]::new("Max attempts must be non-negative", "MaxAttempts")
            }
            
            Write-Verbose "Configuration validation successful"
            return $true
            
        } catch [ConfigurationException] {
            throw
        } catch {
            throw [ConfigurationException]::new("Configuration validation failed: $($_.Exception.Message)")
        }
    }
    
    # Apply configuration from hashtable
    [void] ApplyConfiguration([hashtable]$config) {
        try {
            Write-Verbose "Applying configuration from hashtable"
            
            foreach ($key in $config.Keys) {
                switch ($key) {
                    'SSIDFile' { $this.Configuration.SSIDFilePath = $config[$key] }
                    'PasswordFile' { $this.Configuration.PasswordFilePath = $config[$key] }
                    'Help' { 
                        $this.Configuration.ShowHelp = $config[$key]
                        if ($config[$key]) {
                            $this.HelpRequested = $true
                        }
                    }
                    'Verbose' { 
                        $this.Configuration.VerboseMode = $config[$key]
                        if ($config[$key]) {
                            $this.Configuration.LogLevel = [LogLevel]::Debug
                        }
                    }
                    'Stealth' { $this.Configuration.StealthMode = $config[$key] }
                    'RateLimit' { $this.Configuration.RateLimitMs = $config[$key] }
                    'Timeout' { $this.Configuration.ConnectionTimeoutSeconds = $config[$key] }
                    'MaxAttempts' { $this.Configuration.MaxAttemptsPerSSID = $config[$key] }
                    'LogLevel' { $this.Configuration.LogLevel = $config[$key] }
                    default {
                        $this.Configuration.CustomSettings[$key] = $config[$key]
                    }
                }
            }
            
            Write-Verbose "Configuration applied successfully"
            
        } catch {
            throw [ConfigurationException]::new("Failed to apply configuration: $($_.Exception.Message)")
        }
    }
    
    # Get configuration summary for display
    [string] GetConfigurationSummary() {
        $summary = @"
Configuration Summary:
- SSID File: $($this.Configuration.SSIDFilePath)
- Password File: $($this.Configuration.PasswordFilePath)
- Verbose Mode: $($this.Configuration.VerboseMode)
- Stealth Mode: $($this.Configuration.StealthMode)
- Rate Limit: $($this.Configuration.RateLimitMs)ms
- Connection Timeout: $($this.Configuration.ConnectionTimeoutSeconds)s
- Max Attempts per SSID: $(if ($this.Configuration.MaxAttemptsPerSSID -eq 0) { 'Unlimited' } else { $this.Configuration.MaxAttemptsPerSSID })
- Log Level: $($this.Configuration.LogLevel)
"@
        return $summary
    }
    
    # Display help information
    [void] ShowHelp() {
        $helpText = @"
WifadePS - Windows PowerShell Wi-Fi Security Testing Tool

USAGE:
    .\WifadePS.ps1 [OPTIONS]

OPTIONS:
    -s, --ssid <file>           Path to SSID file (default: ssid.txt)
    -w, --password <file>       Path to password file (default: passwords.txt)
    -h, --help                  Display this help information
    -v, --verbose               Enable verbose output mode
    --stealth                   Enable stealth mode with rate limiting
    --rate-limit <ms>           Rate limit in milliseconds (default: 1000)
    --timeout <seconds>         Connection timeout in seconds (default: 30)
    --max-attempts <number>     Maximum attempts per SSID (default: unlimited)

EXAMPLES:
    .\WifadePS.ps1
        Run with default configuration files
    
    .\WifadePS.ps1 -s "my_ssids.txt" -w "my_passwords.txt"
        Run with custom SSID and password files
    
    .\WifadePS.ps1 --stealth --rate-limit 2000 --verbose
        Run in stealth mode with 2-second delays and verbose output

CONFIGURATION FILES:
    SSID File Format:
        One SSID per line, plain text
        Example:
            MyNetwork
            OfficeWiFi
            HomeRouter
    
    Password File Format:
        One password per line, plain text
        Example:
            password123
            admin
            12345678

ETHICAL USAGE:
    This tool is intended for educational purposes and ethical security testing only.
    Always ensure you have explicit permission to test network security.

For more information, visit: https://github.com/wifade/wifade
"@
        
        Write-Host $helpText -ForegroundColor White
    }
    
    # Check if help was requested
    [bool] IsHelpRequested() {
        return $this.HelpRequested -or $this.Configuration.ShowHelp
    }
    
    # Get current configuration object
    [WifadeConfiguration] GetConfiguration() {
        return $this.Configuration
    }
    
    # Override Dispose method from IManager
    [void] Dispose() {
        Write-Verbose "Disposing ConfigurationManager..."
        $this.CommandLineArgs.Clear()
        $this.IsInitialized = $false
        Write-Verbose "ConfigurationManager disposed"
    }
}