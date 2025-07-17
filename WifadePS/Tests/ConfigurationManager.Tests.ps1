# Unit Tests for ConfigurationManager Class
# Uses Pester testing framework for PowerShell

BeforeAll {
    # Import required classes
    $ModulePath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    . "$ModulePath\Classes\BaseClasses.ps1"
    . "$ModulePath\Classes\DataModels.ps1"
    . "$ModulePath\Classes\ConfigurationManager.ps1"
    
    # Create test data directory
    $TestDataPath = Join-Path $TestDrive "TestData"
    New-Item -ItemType Directory -Path $TestDataPath -Force | Out-Null
    
    # Create test SSID file
    $TestSSIDFile = Join-Path $TestDataPath "test_ssids.txt"
    $TestSSIDContent = @"
TestNetwork1
TestNetwork2
Office-WiFi
Home_Router_5G
"@
    Set-Content -Path $TestSSIDFile -Value $TestSSIDContent
    
    # Create test password file
    $TestPasswordFile = Join-Path $TestDataPath "test_passwords.txt"
    $TestPasswordContent = @"
password123
admin
12345678
qwerty
letmein
password
123456
admin123
"@
    Set-Content -Path $TestPasswordFile -Value $TestPasswordContent
    
    # Create empty test files
    $EmptySSIDFile = Join-Path $TestDataPath "empty_ssids.txt"
    $EmptyPasswordFile = Join-Path $TestDataPath "empty_passwords.txt"
    Set-Content -Path $EmptySSIDFile -Value ""
    Set-Content -Path $EmptyPasswordFile -Value ""
    
    # Create invalid SSID file (too long SSIDs)
    $InvalidSSIDFile = Join-Path $TestDataPath "invalid_ssids.txt"
    $InvalidSSIDContent = @"
ValidSSID
ThisSSIDIsWayTooLongAndExceedsTheMaximumLengthOf32CharactersAllowedByIEEE802Standard
AnotherValidSSID
"@
    Set-Content -Path $InvalidSSIDFile -Value $InvalidSSIDContent
    
    # Create invalid password file (too short passwords)
    $InvalidPasswordFile = Join-Path $TestDataPath "invalid_passwords.txt"
    $InvalidPasswordContent = @"
validpassword123
abc
anothergoodpassword
x
"@
    Set-Content -Path $InvalidPasswordFile -Value $InvalidPasswordContent
}

Describe "ConfigurationManager Class Tests" {
    
    Context "Constructor Tests" {
        It "Should create instance with default constructor" {
            $configManager = [ConfigurationManager]::new()
            
            $configManager | Should -Not -BeNullOrEmpty
            $configManager.Configuration | Should -Not -BeNullOrEmpty
            $configManager.CommandLineArgs.GetType().Name | Should -Be "Hashtable"
            $configManager.ValidParameters | Should -Not -BeNullOrEmpty
            $configManager.HelpRequested | Should -Be $false
            $configManager.IsInitialized | Should -Be $false
        }
        
        It "Should create instance with initial configuration" {
            $initialConfig = @{
                'SSIDFile' = 'custom_ssids.txt'
                'PasswordFile' = 'custom_passwords.txt'
                'Verbose' = $true
            }
            
            $configManager = [ConfigurationManager]::new($initialConfig)
            
            $configManager | Should -Not -BeNullOrEmpty
            $configManager.Configuration.SSIDFilePath | Should -Be 'custom_ssids.txt'
            $configManager.Configuration.PasswordFilePath | Should -Be 'custom_passwords.txt'
            $configManager.Configuration.VerboseMode | Should -Be $true
            $configManager.Configuration.LogLevel | Should -Be ([LogLevel]::Debug)
        }
    }
    
    Context "Command Line Parsing Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should parse SSID file parameter (-s)" {
            $arguments = @('-s', 'custom_ssids.txt')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.SSIDFilePath | Should -Be 'custom_ssids.txt'
            $configManager.CommandLineArgs['SSIDFile'] | Should -Be 'custom_ssids.txt'
        }
        
        It "Should parse SSID file parameter (--ssid)" {
            $arguments = @('--ssid', 'custom_ssids.txt')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.SSIDFilePath | Should -Be 'custom_ssids.txt'
        }
        
        It "Should parse password file parameter (-w)" {
            $arguments = @('-w', 'custom_passwords.txt')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.PasswordFilePath | Should -Be 'custom_passwords.txt'
            $configManager.CommandLineArgs['PasswordFile'] | Should -Be 'custom_passwords.txt'
        }
        
        It "Should parse password file parameter (--password)" {
            $arguments = @('--password', 'custom_passwords.txt')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.PasswordFilePath | Should -Be 'custom_passwords.txt'
        }
        
        It "Should parse help parameter (-h)" {
            $arguments = @('-h')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.ShowHelp | Should -Be $true
            $configManager.HelpRequested | Should -Be $true
            $configManager.CommandLineArgs['Help'] | Should -Be $true
        }
        
        It "Should parse help parameter (--help)" {
            $arguments = @('--help')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.ShowHelp | Should -Be $true
            $configManager.HelpRequested | Should -Be $true
        }
        
        It "Should parse verbose parameter (-v)" {
            $arguments = @('-v')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.VerboseMode | Should -Be $true
            $result.LogLevel | Should -Be ([LogLevel]::Debug)
        }
        
        It "Should parse stealth parameter (--stealth)" {
            $arguments = @('--stealth')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.StealthMode | Should -Be $true
        }
        
        It "Should parse rate limit parameter (--rate-limit)" {
            $arguments = @('--rate-limit', '2000')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.RateLimitMs | Should -Be 2000
        }
        
        It "Should parse timeout parameter (--timeout)" {
            $arguments = @('--timeout', '45')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.ConnectionTimeoutSeconds | Should -Be 45
        }
        
        It "Should parse max attempts parameter (--max-attempts)" {
            $arguments = @('--max-attempts', '100')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.MaxAttemptsPerSSID | Should -Be 100
        }
        
        It "Should parse multiple parameters" {
            $arguments = @('-s', 'test_ssids.txt', '-w', 'test_passwords.txt', '-v', '--stealth', '--rate-limit', '1500')
            $result = $configManager.ParseCommandLineArguments($arguments)
            
            $result.SSIDFilePath | Should -Be 'test_ssids.txt'
            $result.PasswordFilePath | Should -Be 'test_passwords.txt'
            $result.VerboseMode | Should -Be $true
            $result.StealthMode | Should -Be $true
            $result.RateLimitMs | Should -Be 1500
        }
        
        It "Should throw exception for missing SSID file value" {
            $arguments = @('-s')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for missing password file value" {
            $arguments = @('-w')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for invalid rate limit value" {
            $arguments = @('--rate-limit', 'invalid')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for negative rate limit value" {
            $arguments = @('--rate-limit', '-100')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for invalid timeout value" {
            $arguments = @('--timeout', '0')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for unknown parameter" {
            $arguments = @('--unknown-param')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for unexpected argument" {
            $arguments = @('unexpected-argument')
            { $configManager.ParseCommandLineArguments($arguments) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
    }
    
    Context "SSID File Validation Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should validate valid SSID file" {
            $result = $configManager.ValidateSSIDFile($TestSSIDFile)
            $result | Should -Be $true
        }
        
        It "Should throw exception for empty SSID file path" {
            { $configManager.ValidateSSIDFile("") } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for null SSID file path" {
            { $configManager.ValidateSSIDFile($null) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for non-existent SSID file" {
            $nonExistentFile = Join-Path $TestDataPath "non_existent_ssids.txt"
            { $configManager.ValidateSSIDFile($nonExistentFile) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for empty SSID file" {
            { $configManager.ValidateSSIDFile($EmptySSIDFile) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should warn about long SSIDs but still validate" {
            $result = $configManager.ValidateSSIDFile($InvalidSSIDFile)
            $result | Should -Be $true
        }
    }
    
    Context "Password File Validation Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should validate valid password file" {
            $result = $configManager.ValidatePasswordFile($TestPasswordFile)
            $result | Should -Be $true
        }
        
        It "Should throw exception for empty password file path" {
            { $configManager.ValidatePasswordFile("") } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for null password file path" {
            { $configManager.ValidatePasswordFile($null) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for non-existent password file" {
            $nonExistentFile = Join-Path $TestDataPath "non_existent_passwords.txt"
            { $configManager.ValidatePasswordFile($nonExistentFile) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for empty password file" {
            { $configManager.ValidatePasswordFile($EmptyPasswordFile) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should warn about short passwords but still validate" {
            $result = $configManager.ValidatePasswordFile($InvalidPasswordFile)
            $result | Should -Be $true
        }
    }
    
    Context "File Loading Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should load SSID list correctly" {
            $ssidList = $configManager.LoadSSIDList($TestSSIDFile)
            
            $ssidList | Should -Not -BeNullOrEmpty
            $ssidList.Count | Should -Be 4
            $ssidList | Should -Contain "TestNetwork1"
            $ssidList | Should -Contain "TestNetwork2"
            $ssidList | Should -Contain "Office-WiFi"
            $ssidList | Should -Contain "Home_Router_5G"
        }
        
        It "Should load password list correctly" {
            $passwordList = $configManager.LoadPasswordList($TestPasswordFile)
            
            $passwordList | Should -Not -BeNullOrEmpty
            $passwordList.Count | Should -Be 8
            $passwordList | Should -Contain "password123"
            $passwordList | Should -Contain "admin"
            $passwordList | Should -Contain "12345678"
        }
        
        It "Should throw exception when loading invalid SSID file" {
            $nonExistentFile = Join-Path $TestDataPath "non_existent_ssids.txt"
            { $configManager.LoadSSIDList($nonExistentFile) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception when loading invalid password file" {
            $nonExistentFile = Join-Path $TestDataPath "non_existent_passwords.txt"
            { $configManager.LoadPasswordList($nonExistentFile) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
    }
    
    Context "Configuration Validation Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
            $configManager.Configuration.SSIDFilePath = $TestSSIDFile
            $configManager.Configuration.PasswordFilePath = $TestPasswordFile
        }
        
        It "Should validate valid configuration" {
            $result = $configManager.ValidateConfiguration(@{})
            $result | Should -Be $true
        }
        
        It "Should throw exception for negative rate limit" {
            $configManager.Configuration.RateLimitMs = -100
            { $configManager.ValidateConfiguration(@{}) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for zero timeout" {
            $configManager.Configuration.ConnectionTimeoutSeconds = 0
            { $configManager.ValidateConfiguration(@{}) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception for negative max attempts" {
            $configManager.Configuration.MaxAttemptsPerSSID = -1
            { $configManager.ValidateConfiguration(@{}) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
    }
    
    Context "Configuration Management Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should apply configuration from hashtable" {
            $config = @{
                'SSIDFile' = 'test_ssids.txt'
                'PasswordFile' = 'test_passwords.txt'
                'Verbose' = $true
                'Stealth' = $true
                'RateLimit' = 2000
                'Timeout' = 45
                'MaxAttempts' = 100
            }
            
            $configManager.ApplyConfiguration($config)
            
            $configManager.Configuration.SSIDFilePath | Should -Be 'test_ssids.txt'
            $configManager.Configuration.PasswordFilePath | Should -Be 'test_passwords.txt'
            $configManager.Configuration.VerboseMode | Should -Be $true
            $configManager.Configuration.StealthMode | Should -Be $true
            $configManager.Configuration.RateLimitMs | Should -Be 2000
            $configManager.Configuration.ConnectionTimeoutSeconds | Should -Be 45
            $configManager.Configuration.MaxAttemptsPerSSID | Should -Be 100
        }
        
        It "Should handle custom settings in configuration" {
            $config = @{
                'CustomSetting1' = 'Value1'
                'CustomSetting2' = 'Value2'
            }
            
            $configManager.ApplyConfiguration($config)
            
            $configManager.Configuration.CustomSettings['CustomSetting1'] | Should -Be 'Value1'
            $configManager.Configuration.CustomSettings['CustomSetting2'] | Should -Be 'Value2'
        }
        
        It "Should generate configuration summary" {
            $configManager.Configuration.SSIDFilePath = $TestSSIDFile
            $configManager.Configuration.PasswordFilePath = $TestPasswordFile
            $configManager.Configuration.VerboseMode = $true
            $configManager.Configuration.StealthMode = $true
            
            $summary = $configManager.GetConfigurationSummary()
            
            $summary | Should -Not -BeNullOrEmpty
            $summary | Should -Match "SSID File:"
            $summary | Should -Match "Password File:"
            $summary | Should -Match "Verbose Mode: True"
            $summary | Should -Match "Stealth Mode: True"
        }
    }
    
    Context "Help and Utility Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should detect help request from command line" {
            $arguments = @('-h')
            $configManager.ParseCommandLineArguments($arguments)
            
            $configManager.IsHelpRequested() | Should -Be $true
        }
        
        It "Should detect help request from configuration" {
            $configManager.Configuration.ShowHelp = $true
            
            $configManager.IsHelpRequested() | Should -Be $true
        }
        
        It "Should return current configuration" {
            $config = $configManager.GetConfiguration()
            
            $config | Should -Not -BeNullOrEmpty
            $config | Should -BeOfType ([WifadeConfiguration])
        }
        
        It "Should show help without throwing exception" {
            { $configManager.ShowHelp() } | Should -Not -Throw
        }
    }
    
    Context "Initialization and Disposal Tests" {
        BeforeEach {
            $configManager = [ConfigurationManager]::new()
        }
        
        It "Should initialize successfully" {
            $config = @{
                'SSIDFile' = $TestSSIDFile
                'PasswordFile' = $TestPasswordFile
            }
            
            { $configManager.Initialize($config) } | Should -Not -Throw
            $configManager.IsInitialized | Should -Be $true
        }
        
        It "Should dispose successfully" {
            $configManager.Initialize(@{})
            
            { $configManager.Dispose() } | Should -Not -Throw
            $configManager.IsInitialized | Should -Be $false
        }
        
        It "Should throw exception during initialization with invalid config" {
            $config = @{
                'SSIDFile' = 'non_existent_file.txt'
            }
            
            { $configManager.Initialize($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
    }
}

Describe "Integration Tests" {
    Context "End-to-End Configuration Tests" {
        It "Should handle complete configuration workflow" {
            $configManager = [ConfigurationManager]::new()
            
            # Parse command line arguments
            $arguments = @('-s', $TestSSIDFile, '-w', $TestPasswordFile, '-v', '--stealth', '--rate-limit', '1500')
            $config = $configManager.ParseCommandLineArguments($arguments)
            
            # Initialize with parsed configuration
            $configManager.Initialize(@{})
            
            # Validate configuration
            $isValid = $configManager.ValidateConfiguration(@{})
            
            # Load files
            $ssidList = $configManager.LoadSSIDList($config.SSIDFilePath)
            $passwordList = $configManager.LoadPasswordList($config.PasswordFilePath)
            
            # Verify results
            $config | Should -Not -BeNullOrEmpty
            $isValid | Should -Be $true
            $ssidList.Count | Should -Be 4
            $passwordList.Count | Should -Be 8
            $configManager.IsInitialized | Should -Be $true
            
            # Clean up
            $configManager.Dispose()
            $configManager.IsInitialized | Should -Be $false
        }
    }
}