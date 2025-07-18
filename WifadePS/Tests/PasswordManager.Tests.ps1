# Unit Tests for PasswordManager Class

BeforeAll {
    # Import required classes
    . "$PSScriptRoot\..\Classes\BaseClasses.ps1"
    . "$PSScriptRoot\..\Classes\DataModels.ps1"
    . "$PSScriptRoot\..\Classes\PasswordManager.ps1"
    
    # Create test password file
    $script:TestPasswordFile = "$TestDrive\test_passwords.txt"
    $script:EmptyPasswordFile = "$TestDrive\empty_passwords.txt"
    $script:InvalidPasswordFile = "$TestDrive\nonexistent.txt"
    
    # Create test password content
    $testPasswords = @(
        "password123",
        "admin",
        "12345678",
        "qwerty",
        "letmein",
        "password",
        "123456789",
        "welcome123",
        "# This is a comment",
        "",
        "   ",  # Whitespace only
        "guest",
        "wifi123",
        "router"
    )
    
    $testPasswords | Out-File -FilePath $script:TestPasswordFile -Encoding UTF8
    "" | Out-File -FilePath $script:EmptyPasswordFile -Encoding UTF8
}

Describe "PasswordManager Class Tests" {
    
    Context "Constructor Tests" {
        It "Should create PasswordManager with default constructor" {
            $passwordManager = [PasswordManager]::new()
            
            $passwordManager | Should -Not -BeNullOrEmpty
            $passwordManager.PasswordList | Should -Not -BeNull -Because "PasswordList should be initialized as an empty collection"
            $passwordManager.PasswordList.Count | Should -Be 0
            $passwordManager.CurrentIndex | Should -Be 0
            $passwordManager.AttackStatistics | Should -Not -BeNullOrEmpty
            $passwordManager.CurrentStrategy | Should -Be ([AttackStrategy]::Dictionary)
            $passwordManager.StealthMode | Should -Be $false
        }
        
        It "Should create PasswordManager with configuration" {
            $config = @{
                RateLimitEnabled = $true
                MinDelayMs = 500
                MaxDelayMs = 2000
                AttackStrategy = [AttackStrategy]::SSIDBased
                StealthMode = $true
            }
            
            $passwordManager = [PasswordManager]::new($config)
            
            $passwordManager.RateLimitSettings.Enabled | Should -Be $true
            $passwordManager.RateLimitSettings.MinDelayMs | Should -Be 500
            $passwordManager.RateLimitSettings.MaxDelayMs | Should -Be 2000
            $passwordManager.CurrentStrategy | Should -Be ([AttackStrategy]::SSIDBased)
            $passwordManager.StealthMode | Should -Be $true
        }
    }
    
    Context "Initialization Tests" {
        It "Should initialize successfully with valid password file" {
            $passwordManager = [PasswordManager]::new()
            $config = @{ PasswordFilePath = $script:TestPasswordFile }
            
            { $passwordManager.Initialize($config) } | Should -Not -Throw
            $passwordManager.IsInitialized | Should -Be $true
            $passwordManager.PasswordList.Count | Should -BeGreaterThan 0
        }
        
        It "Should throw exception when password file path is missing" {
            $passwordManager = [PasswordManager]::new()
            $config = @{}
            
            { $passwordManager.Initialize($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception when password file does not exist" {
            $passwordManager = [PasswordManager]::new()
            $config = @{ PasswordFilePath = $script:InvalidPasswordFile }
            
            { $passwordManager.Initialize($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should throw exception when password file is empty" {
            $passwordManager = [PasswordManager]::new()
            $config = @{ PasswordFilePath = $script:EmptyPasswordFile }
            
            { $passwordManager.Initialize($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
    }
    
    Context "Password Loading Tests" {
        It "Should load passwords from file correctly" {
            $passwordManager = [PasswordManager]::new()
            
            { $passwordManager.LoadPasswords($script:TestPasswordFile) } | Should -Not -Throw
            
            # Should have loaded valid passwords (excluding comments and empty lines)
            $passwordManager.PasswordList.Count | Should -Be 11  # 14 total - 3 invalid (comment, empty, whitespace)
            $passwordManager.PasswordList | Should -Contain "password123"
            $passwordManager.PasswordList | Should -Contain "admin"
            $passwordManager.PasswordList | Should -Not -Contain "# This is a comment"
        }
        
        It "Should handle duplicate passwords correctly" {
            $duplicatePasswordFile = "$TestDrive\duplicate_passwords.txt"
            @("password", "admin", "password", "guest", "admin") | Out-File -FilePath $duplicatePasswordFile -Encoding UTF8
            
            $passwordManager = [PasswordManager]::new()
            $passwordManager.LoadPasswords($duplicatePasswordFile)
            
            # Should only have unique passwords
            $passwordManager.PasswordList.Count | Should -Be 3
            $passwordManager.PasswordList | Should -Contain "password"
            $passwordManager.PasswordList | Should -Contain "admin"
            $passwordManager.PasswordList | Should -Contain "guest"
        }
    }
    
    Context "Password Iterator Tests" {
        BeforeEach {
            $script:passwordManager = [PasswordManager]::new()
            $script:passwordManager.LoadPasswords($script:TestPasswordFile)
        }
        
        It "Should return passwords in sequence" {
            $firstPassword = $script:passwordManager.GetNextPassword()
            $secondPassword = $script:passwordManager.GetNextPassword()
            
            $firstPassword | Should -Not -BeNullOrEmpty
            $secondPassword | Should -Not -BeNullOrEmpty
            $firstPassword | Should -Not -Be $secondPassword
        }
        
        It "Should return null when no more passwords available" {
            # Exhaust all passwords
            while ($script:passwordManager.HasMorePasswords()) {
                $null = $script:passwordManager.GetNextPassword()
            }
            
            $nextPassword = $script:passwordManager.GetNextPassword()
            $nextPassword | Should -BeNullOrEmpty
        }
        
        It "Should reset iterator correctly" {
            # Get some passwords
            $firstPassword = $script:passwordManager.GetNextPassword()
            $null = $script:passwordManager.GetNextPassword()
            
            # Reset
            $script:passwordManager.Reset()
            
            # Should start from beginning again
            $resetPassword = $script:passwordManager.GetNextPassword()
            $resetPassword | Should -Be $firstPassword
            $script:passwordManager.CurrentIndex | Should -Be 1
        }
        
        It "Should track progress correctly" {
            $initialProgress = $script:passwordManager.GetProgress()
            $initialProgress.CurrentIndex | Should -Be 0
            $initialProgress.ProgressPercent | Should -Be 0
            
            # Get a few passwords
            $null = $script:passwordManager.GetNextPassword()
            $null = $script:passwordManager.GetNextPassword()
            
            $progress = $script:passwordManager.GetProgress()
            $progress.CurrentIndex | Should -Be 2
            $progress.ProgressPercent | Should -BeGreaterThan 0
        }
    }
    
    Context "SSID-Based Password Generation Tests" {
        BeforeEach {
            $script:passwordManager = [PasswordManager]::new()
            $script:passwordManager.LoadPasswords($script:TestPasswordFile)
            $script:passwordManager.SetAttackStrategy([AttackStrategy]::SSIDBased)
        }
        
        It "Should generate SSID-based passwords" {
            $ssid = "TestNetwork"
            $script:passwordManager.GenerateSSIDBasedPasswords($ssid)
            
            $script:passwordManager.GeneratedPasswords.Count | Should -BeGreaterThan 0
            $script:passwordManager.GeneratedPasswords | Should -Contain $ssid
            $script:passwordManager.GeneratedPasswords | Should -Contain ($ssid + "123")
            $script:passwordManager.GeneratedPasswords | Should -Contain $ssid.ToLower()
        }
        
        It "Should return SSID-based passwords before dictionary passwords" {
            $ssid = "TestNetwork"
            $password = $script:passwordManager.GetNextPassword($ssid)
            
            # Should be an SSID-based password
            $password | Should -Match $ssid
        }
    }
    
    Context "Attack Statistics Tests" {
        BeforeEach {
            $script:passwordManager = [PasswordManager]::new()
            $script:passwordManager.LoadPasswords($script:TestPasswordFile)
        }
        
        It "Should record successful connection attempts" {
            $attempt = [ConnectionAttempt]::new("TestSSID", "password123", 1)
            $attempt.MarkAsCompleted($true, "")
            
            $script:passwordManager.RecordAttempt($attempt)
            
            $stats = $script:passwordManager.GetStatistics()
            $stats.TotalAttempts | Should -Be 1
            $stats.SuccessfulConnections | Should -Be 1
            $stats.FailedAttempts | Should -Be 0
        }
        
        It "Should record failed connection attempts" {
            $attempt = [ConnectionAttempt]::new("TestSSID", "wrongpassword", 1)
            $attempt.MarkAsCompleted($false, "Authentication failed")
            
            $script:passwordManager.RecordAttempt($attempt)
            
            $stats = $script:passwordManager.GetStatistics()
            $stats.TotalAttempts | Should -Be 1
            $stats.SuccessfulConnections | Should -Be 0
            $stats.FailedAttempts | Should -Be 1
            $stats.ErrorBreakdown["Authentication failed"] | Should -Be 1
        }
        
        It "Should calculate success rate correctly" {
            # Record mixed attempts
            $successAttempt = [ConnectionAttempt]::new("TestSSID", "password123", 1)
            $successAttempt.MarkAsCompleted($true, "")
            $script:passwordManager.RecordAttempt($successAttempt)
            
            $failAttempt = [ConnectionAttempt]::new("TestSSID", "wrongpassword", 2)
            $failAttempt.MarkAsCompleted($false, "Authentication failed")
            $script:passwordManager.RecordAttempt($failAttempt)
            
            $stats = $script:passwordManager.GetStatistics()
            $stats.SuccessRate | Should -Be 50.0
        }
    }
    
    Context "Rate Limiting Tests" {
        BeforeEach {
            $config = @{
                RateLimitEnabled = $true
                MinDelayMs = 100
                MaxDelayMs = 200
            }
            $script:passwordManager = [PasswordManager]::new($config)
            $script:passwordManager.LoadPasswords($script:TestPasswordFile)
        }
        
        It "Should implement rate limiting when enabled" {
            $startTime = Get-Date
            
            # First call should not delay
            $script:passwordManager.ImplementRateLimiting()
            
            # Second call should delay
            $script:passwordManager.ImplementRateLimiting()
            
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds
            
            # Should have some delay (at least minimum delay)
            $duration | Should -BeGreaterOrEqual 90  # Allow some tolerance
        }
        
        It "Should enable rate limiting in stealth mode" {
            $passwordManager = [PasswordManager]::new()
            $passwordManager.SetStealthMode($true)
            
            $passwordManager.StealthMode | Should -Be $true
            $passwordManager.RateLimitSettings.Enabled | Should -Be $true
        }
    }
    
    Context "Configuration Validation Tests" {
        It "Should validate valid configuration" {
            $passwordManager = [PasswordManager]::new()
            $config = @{
                PasswordFilePath = $script:TestPasswordFile
                MinDelayMs = 1000
                MaxDelayMs = 3000
            }
            
            { $passwordManager.ValidateConfiguration($config) } | Should -Not -Throw
        }
        
        It "Should reject invalid delay settings" {
            $passwordManager = [PasswordManager]::new()
            $config = @{
                MinDelayMs = -100
            }
            
            { $passwordManager.ValidateConfiguration($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
        
        It "Should reject MaxDelayMs less than MinDelayMs" {
            $passwordManager = [PasswordManager]::new()
            $config = @{
                MinDelayMs = 3000
                MaxDelayMs = 1000
            }
            
            { $passwordManager.ValidateConfiguration($config) } | Should -Throw -ExceptionType ([ConfigurationException])
        }
    }
    
    Context "Disposal Tests" {
        It "Should dispose resources correctly" {
            $passwordManager = [PasswordManager]::new()
            $passwordManager.LoadPasswords($script:TestPasswordFile)
            
            { $passwordManager.Dispose() } | Should -Not -Throw
            $passwordManager.IsInitialized | Should -Be $false
            $passwordManager.PasswordList.Count | Should -Be 0
        }
    }
}