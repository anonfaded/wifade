$ModulePath = "WifadePS"
. "$ModulePath\Classes\BaseClasses.ps1"
. "$ModulePath\Classes\DataModels.ps1"
. "$ModulePath\Classes\ConfigurationManager.ps1"

$configManager = [ConfigurationManager]::new()
Write-Host "Before parsing - SSID: $($configManager.Configuration.SSIDFilePath)"

try {
    $args = @('-s', 'custom_ssids.txt')
    $result = $configManager.ParseCommandLineArguments($args)
    Write-Host "After parsing - SSID: $($result.SSIDFilePath)"
    Write-Host "CommandLineArgs keys: $($configManager.CommandLineArgs.Keys -join ', ')"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)"
}
