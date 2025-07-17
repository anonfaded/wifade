# Simple test of ConfigurationManager
$ModulePath = "WifadePS"
. "$ModulePath\Classes\BaseClasses.ps1"
. "$ModulePath\Classes\DataModels.ps1"

# Create a simple test class to isolate the issue
class TestConfigManager {
    [WifadeConfiguration]$Configuration
    [hashtable]$CommandLineArgs
    
    TestConfigManager() {
        $this.Configuration = [WifadeConfiguration]::new()
        $this.CommandLineArgs = [hashtable]::new()
    }
    
    [WifadeConfiguration] ParseArgs([string[]]$args) {
        Write-Host "ParseArgs called with: $($args -join ' ')"
        
        $i = 0
        while ($i -lt $args.Length) {
            $arg = $args[$i]
            Write-Host "Processing: $arg"
            
            if ($arg -eq '-s') {
                Write-Host "Found -s parameter"
                if (($i + 1) -lt $args.Length) {
                    $this.Configuration.SSIDFilePath = $args[$i + 1]
                    $this.CommandLineArgs['SSIDFile'] = $args[$i + 1]
                    Write-Host "Set SSID to: $($args[$i + 1])"
                    $i += 2
                } else {
                    Write-Host "ERROR: -s requires a value"
                    $i++
                }
            } else {
                Write-Host "Unknown parameter: $arg"
                $i++
            }
        }
        
        return $this.Configuration
    }
}

# Test the simple version
$testManager = [TestConfigManager]::new()
Write-Host "Initial SSID: $($testManager.Configuration.SSIDFilePath)"

$args = @('-s', 'custom_ssids.txt')
$result = $testManager.ParseArgs($args)

Write-Host "Final SSID: $($result.SSIDFilePath)"
Write-Host "CommandLineArgs: $($testManager.CommandLineArgs | ConvertTo-Json)"