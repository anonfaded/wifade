# ============================================================================
# WIFADE BUILD SCRIPT
# ============================================================================
# This script combines all PowerShell files into a single executable
# 
# REQUIREMENTS:
# - Run as Administrator (required for ps2exe compilation)
# - PowerShell 5.1 or later
# - ps2exe module (will be installed automatically if missing)
#
# USAGE:
# .\Build-Wifade.ps1
#
# OUTPUT:
# - build\Wifade.exe (compiled executable)
# - build\Wifade-Flat.ps1 (combined source script)
# ============================================================================

# Set execution policy for this session to bypass restrictions
Write-Host "Setting execution policy for build session..." -ForegroundColor Cyan
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "✅ Execution policy set to Bypass for this session" -ForegroundColor Green
} catch {
    Write-Warning "⚠️ Could not set execution policy. You may need to run as Administrator."
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "⚠️  ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host ""
    Write-Host "This build script requires Administrator privileges to:" -ForegroundColor Yellow
    Write-Host "  • Install ps2exe module (if not already installed)" -ForegroundColor White
    Write-Host "  • Compile PowerShell scripts to executable" -ForegroundColor White
    Write-Host "  • Set execution policy for compilation" -ForegroundColor White
    Write-Host ""
    Write-Host "Please run this script as Administrator:" -ForegroundColor Cyan
    Write-Host "  1. Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor White
    Write-Host "  2. Navigate to the Wifade project directory" -ForegroundColor White
    Write-Host "  3. Run: .\Build-Wifade.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "                    WIFADE BUILD SCRIPT v2.0" -ForegroundColor White
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Building Wifade executable..." -ForegroundColor Green
Write-Host ""

# Check and install ps2exe module if needed
Write-Host "Checking ps2exe module..." -ForegroundColor Yellow
$ps2exeModule = Get-Module -ListAvailable -Name ps2exe
if (-not $ps2exeModule) {
    Write-Host "ps2exe module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module ps2exe -Force -Scope CurrentUser
        Write-Host "✅ ps2exe module installed successfully" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to install ps2exe module: $($_.Exception.Message)"
        Write-Host "Please install manually: Install-Module ps2exe -Force" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ ps2exe module found (Version: $($ps2exeModule.Version))" -ForegroundColor Green
}

# Define paths
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $scriptRoot "Wifade.ps1"
$classesDir = Join-Path $scriptRoot "Classes"
$buildDir = Join-Path $scriptRoot "build"
$outputScript = Join-Path $buildDir "Wifade-Flat.ps1"
$outputExe = Join-Path $buildDir "Wifade.exe"
$iconPath = Join-Path $scriptRoot "img\logo.ico"

# Clean up existing build directory for fresh build
if (Test-Path $buildDir) {
    Write-Host "Cleaning existing build directory..." -ForegroundColor Yellow
    Remove-Item -Path $buildDir -Recurse -Force
}

# Create fresh build directory
Write-Host "Creating build directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

# Read the main script
Write-Host "Reading main script: $mainScript" -ForegroundColor Yellow
$mainContent = Get-Content $mainScript -Raw

# Extract the header (CmdletBinding and param) and footer (main logic) from Wifade.ps1
$headerEndPattern = '(?s)^(.*?param\s*\([^)]*\)\s*)(#.*?$)'
$matches = [regex]::Match($mainContent, $headerEndPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

if ($matches.Success) {
    $header = $matches.Groups[1].Value
    $footer = $mainContent.Substring($matches.Groups[1].Length)
} else {
    # Fallback: find the param block more carefully
    $lines = $mainContent -split "`r?`n"
    $paramStartIndex = -1
    $paramEndIndex = -1
    $parenCount = 0
    $inParam = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Look for param block start
        if ($line -match '^\s*param\s*\(' -and -not $inParam) {
            $paramStartIndex = $i
            $inParam = $true
            $parenCount = 1
            
            # Check if the opening paren is on the same line
            $afterParam = $line -replace '^\s*param\s*\(', ''
            for ($j = 0; $j -lt $afterParam.Length; $j++) {
                if ($afterParam[$j] -eq '(') { $parenCount++ }
                elseif ($afterParam[$j] -eq ')') { $parenCount-- }
            }
            
            if ($parenCount -eq 0) {
                $paramEndIndex = $i
                break
            }
        }
        elseif ($inParam) {
            # Count parentheses to find the end
            for ($j = 0; $j -lt $line.Length; $j++) {
                if ($line[$j] -eq '(') { $parenCount++ }
                elseif ($line[$j] -eq ')') { $parenCount-- }
            }
            
            if ($parenCount -eq 0) {
                $paramEndIndex = $i
                break
            }
        }
    }
    
    if ($paramStartIndex -ge 0 -and $paramEndIndex -ge 0) {
        $header = ($lines[0..$paramEndIndex] -join "`n") + "`n"
        $footer = ($lines[($paramEndIndex + 1)..($lines.Count - 1)] -join "`n")
    } else {
        Write-Warning "Could not properly parse param block, using simple split"
        $header = ""
        $footer = $mainContent
    }
}

# Define class files in dependency order (base classes first)
$classFiles = @(
    "BaseClasses.ps1",      # Contains IManager, exceptions, enums - MUST BE FIRST
    "DataModels.ps1",       # Contains data models (duplicates removed)
    "ConfigurationManager.ps1",
    "NetworkManager.ps1", 
    "PasswordManager.ps1",
    "UIManager.ps1",
    "ApplicationController.ps1"
)

# Combine all class files
Write-Host "Combining class files..." -ForegroundColor Yellow
$combinedClasses = ""

foreach ($classFile in $classFiles) {
    $classPath = Join-Path $classesDir $classFile
    if (Test-Path $classPath) {
        Write-Host "  Adding: $classFile" -ForegroundColor Cyan
        $classContent = Get-Content $classPath -Raw
        
        # Remove any CmdletBinding or param blocks from class files
        $classContent = $classContent -replace '(?s)^\s*\[CmdletBinding\(\)\]\s*', ''
        $classContent = $classContent -replace '(?s)^\s*param\s*\([^)]*\)\s*', ''
        
        $combinedClasses += "`n# === $classFile ===`n"
        $combinedClasses += $classContent
        $combinedClasses += "`n"
    } else {
        Write-Warning "Class file not found: $classPath"
    }
}

# Create the combined script
Write-Host "Creating combined script: $outputScript" -ForegroundColor Yellow

# Add version variable definition at the top to ensure it's available
$versionDefinition = @"
# ============================================================================
# VERSION CONFIGURATION - Extracted from VersionChecker.ps1
# ============================================================================
`$Script:WIFADE_VERSION = "2.0"

"@

# Remove dot-sourcing lines and fix ScriptRoot for compiled executable
$footerFixed = $footer -replace '# Import required classes and modules\s*\r?\n\$ScriptRoot = Split-Path -Parent \$MyInvocation\.MyCommand\.Path\s*\r?\n(\. "\$ScriptRoot\\Classes\\[^"]+\.ps1"\s*\r?\n)*', @"
# Classes are embedded in this compiled script - no external imports needed
# Set ScriptRoot for compiled executable compatibility
`$ScriptRoot = if (`$MyInvocation.MyCommand.Path) { 
    Split-Path -Parent `$MyInvocation.MyCommand.Path 
} else { 
    # For compiled executable, use current directory
    `$PWD.Path 
}

"@

$combinedScript = $header + "`n" + $versionDefinition + $combinedClasses + "`n" + $footerFixed

# Write the combined script
Set-Content -Path $outputScript -Value $combinedScript -Encoding UTF8

# Compile to executable using ps2exe
Write-Host "Compiling to executable: $outputExe" -ForegroundColor Yellow

try {
    # Check if ps2exe is available
    $ps2exeModule = Get-Module -ListAvailable -Name ps2exe
    if (-not $ps2exeModule) {
        throw "ps2exe module not found. Please install it with: Install-Module ps2exe -Force"
    }
    
    # Import ps2exe module
    Import-Module ps2exe -Force
    
    # Compile parameters (compatible with current ps2exe version)
    $compileParams = @{
        InputFile = $outputScript
        OutputFile = $outputExe
        NoConsole = $false
        NoOutput = $false
        NoError = $false
        Verbose = $false
        Debug = $false
        LongPaths = $true
        Title = "Wifade - WiFi Security Testing Tool"
        Description = "Windows PowerShell Wi-Fi Security Testing Tool"
        Company = "Wifade Project"
        Version = "2.0.0.0"
        Copyright = "© 2024 Wifade Project"
    }
    
    # Add icon if it exists
    if (Test-Path $iconPath) {
        $compileParams.IconFile = $iconPath
        Write-Host "Using icon: $iconPath" -ForegroundColor Cyan
    }
    
    # Compile the script
    Invoke-ps2exe @compileParams
    
    if (Test-Path $outputExe) {
        Write-Host ""
        Write-Host "✅ Successfully built: $outputExe" -ForegroundColor Green
        
        # Get file size for display
        $fileSize = [math]::Round((Get-Item $outputExe).Length / 1MB, 2)
        Write-Host "   File size: $fileSize MB" -ForegroundColor Cyan
        
        # Test the executable
        Write-Host ""
        Write-Host "Testing executable..." -ForegroundColor Yellow
        $testResult = & $outputExe -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Executable test passed" -ForegroundColor Green
            Write-Host "   Version output: $testResult" -ForegroundColor Cyan
        } else {
            Write-Warning "⚠️ Executable test failed with exit code: $LASTEXITCODE"
            Write-Host "   Error output: $testResult" -ForegroundColor Red
        }
    } else {
        throw "Compilation failed - executable not created"
    }
}
catch {
    Write-Host ""
    Write-Error "❌ Failed to compile executable: $($_.Exception.Message)"
    Write-Host "You may need to install ps2exe module:" -ForegroundColor Yellow
    Write-Host "Install-Module ps2exe -Force" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "                        BUILD COMPLETED SUCCESSFULLY!" -ForegroundColor White
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Output Files:" -ForegroundColor Cyan
Write-Host "   • Executable: $outputExe" -ForegroundColor White
Write-Host "   • Source:     $outputScript" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Usage Examples:" -ForegroundColor Cyan
Write-Host "   .\build\Wifade.exe -Help          # Show help" -ForegroundColor White
Write-Host "   .\build\Wifade.exe -Version       # Show version" -ForegroundColor White
Write-Host "   .\build\Wifade.exe -Status        # Show WiFi status" -ForegroundColor White
Write-Host "   .\build\Wifade.exe -Scan          # Scan for networks" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Important Notes:" -ForegroundColor Yellow
Write-Host "   • Run Wifade.exe as Administrator for full functionality" -ForegroundColor White
Write-Host "   • Some features require elevated privileges" -ForegroundColor White
Write-Host "   • The executable is portable and self-contained" -ForegroundColor White
Write-Host ""
Write-Host "Build completed successfully! 🎉" -ForegroundColor Green
