# Simple test script
param([switch]$Help)

# Import classes
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptRoot\Classes\BaseClasses.ps1"
. "$ScriptRoot\Classes\DataModels.ps1"
. "$ScriptRoot\Classes\ConfigurationManager.ps1"
. "$ScriptRoot\Classes\NetworkManager.ps1"
. "$ScriptRoot\Classes\PasswordManager.ps1"
. "$ScriptRoot\Classes\UIManager.ps1"
. "$ScriptRoot\Classes\SettingsManager.ps1"
. "$ScriptRoot\Classes\ApplicationController.ps1"

if ($Help.IsPresent) {
    Write-Host "Help requested"
    return
}

Write-Host "Creating ApplicationController..."
$appConfig = @{
    SSIDFile = "ssid.txt"
    PasswordFile = "passwords.txt"
    VerboseMode = $false
    DebugMode = $false
    StealthMode = $false
    RateLimit = 1000
    Timeout = 30
    MaxAttempts = 0
}

try {
    $appController = [ApplicationController]::new($appConfig)
    Write-Host "ApplicationController created successfully"
    
    $appController.Initialize($appConfig)
    Write-Host "ApplicationController initialized successfully"
    
    Write-Host "Starting application..."
    $appController.Start()
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)"
}