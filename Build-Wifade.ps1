# ============================================================================
# WIFADE BUILD SCRIPT
# ============================================================================
# This script combines all PowerShell files into a single executable
# 
# REQUIREMENTS:
# - Run as Administrator (required for ps2exe compilation)
# - PowerShell 7.x
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
$regexMatches = [regex]::Match($mainContent, $headerEndPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

if ($regexMatches.Success) {
    $header = $regexMatches.Groups[1].Value
    $footer = $mainContent.Substring($regexMatches.Groups[1].Length)
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
    "VersionChecker.ps1",   # Contains VersionChecker class
    "ConfigurationManager.ps1",
    "SettingsManager.ps1",  # Contains SettingsManager class
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

# Process icon to create proper multi-resolution ICO file
Write-Host "Processing icon file..." -ForegroundColor Yellow

$pngPath = Join-Path $scriptRoot "img\icon.png"
$icoPath = Join-Path $scriptRoot "img\logo.ico"
$processedIcoPath = Join-Path $buildDir "logo.ico"

if (Test-Path $pngPath) {
    Write-Host "  Found PNG source: $pngPath" -ForegroundColor Cyan
    
    try {
        # Load System.Drawing assembly for image processing
        Add-Type -AssemblyName System.Drawing
        
        # Load the original PNG
        $originalImage = [System.Drawing.Image]::FromFile($pngPath)
        
        # Define standard ICO sizes (most important ones)
        $iconSizes = @(16, 24, 32, 48, 64, 128, 256)
        
        Write-Host "  Creating multi-resolution ICO with sizes: $($iconSizes -join ', ')" -ForegroundColor Cyan
        
        # Create a temporary directory for individual icon files
        $tempIconDir = Join-Path $buildDir "temp_icons"
        if (Test-Path $tempIconDir) { Remove-Item $tempIconDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempIconDir -Force | Out-Null
        
        $tempIconFiles = @()
        
        # Create resized versions
        foreach ($size in $iconSizes) {
            $tempIconFile = Join-Path $tempIconDir "icon_$size.png"
            
            # Create new bitmap with the target size
            $resizedBitmap = New-Object System.Drawing.Bitmap($size, $size)
            $graphics = [System.Drawing.Graphics]::FromImage($resizedBitmap)
            
            # Set high quality rendering
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            
            # Draw the resized image
            $graphics.DrawImage($originalImage, 0, 0, $size, $size)
            
            # Save as PNG
            $resizedBitmap.Save($tempIconFile, [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Cleanup
            $graphics.Dispose()
            $resizedBitmap.Dispose()
            
            $tempIconFiles += $tempIconFile
        }
        
        # Dispose original image
        $originalImage.Dispose()
        
        # Use magick (ImageMagick) if available, otherwise try convert command
        $magickAvailable = $false
        try {
            $null = Get-Command "magick" -ErrorAction Stop
            $magickAvailable = $true
            Write-Host "  Using ImageMagick to create ICO file..." -ForegroundColor Cyan
        }
        catch {
            Write-Host "  ImageMagick not found, trying alternative method..." -ForegroundColor Yellow
        }
        
        if ($magickAvailable) {
            # Use ImageMagick to create proper ICO file
            $magickArgs = @($tempIconFiles) + @($processedIcoPath)
            & magick @magickArgs
            
            if (Test-Path $processedIcoPath) {
                Write-Host "  ✅ Successfully created multi-resolution ICO file" -ForegroundColor Green
                $iconPath = $processedIcoPath
            } else {
                Write-Warning "  ⚠️ ImageMagick failed, using original ICO file"
                if (Test-Path $icoPath) {
                    Copy-Item $icoPath $processedIcoPath
                    $iconPath = $processedIcoPath
                }
            }
        } else {
            # Fallback: Copy original ICO if it exists
            Write-Host "  Using original ICO file (ImageMagick not available for multi-resolution)" -ForegroundColor Yellow
            if (Test-Path $icoPath) {
                Copy-Item $icoPath $processedIcoPath
                $iconPath = $processedIcoPath
                Write-Host "  ✅ Copied original ICO file" -ForegroundColor Green
            } else {
                Write-Warning "  ⚠️ No ICO file found, executable will be built without icon"
                $iconPath = $null
            }
        }
        
        # Cleanup temp directory
        if (Test-Path $tempIconDir) {
            Remove-Item $tempIconDir -Recurse -Force
        }
    }
    catch {
        Write-Warning "  ⚠️ Icon processing failed: $($_.Exception.Message)"
        Write-Host "  Using original ICO file if available..." -ForegroundColor Yellow
        if (Test-Path $icoPath) {
            Copy-Item $icoPath $processedIcoPath
            $iconPath = $processedIcoPath
        } else {
            $iconPath = $null
        }
    }
} else {
    Write-Warning "  PNG source not found: $pngPath"
    if (Test-Path $icoPath) {
        Copy-Item $icoPath $processedIcoPath
        $iconPath = $processedIcoPath
        Write-Host "  Using existing ICO file" -ForegroundColor Cyan
    } else {
        Write-Warning "  No icon files found, executable will be built without icon"
        $iconPath = $null
    }
}

# Compile to executables using ps2exe
Write-Host "Compiling executables..." -ForegroundColor Yellow

try {
    # Check if ps2exe is available
    $ps2exeModule = Get-Module -ListAvailable -Name ps2exe
    if (-not $ps2exeModule) {
        throw "ps2exe module not found. Please install it with: Install-Module ps2exe -Force"
    }
    
    # Import ps2exe module
    Import-Module ps2exe -Force
    
    # Define output paths
    $coreExe = Join-Path $buildDir "WifadeCore.exe"
    $launcherExe = Join-Path $buildDir "Wifade.exe"
    $launcherScript = Join-Path $PSScriptRoot "WifadeLauncher.ps1"
    
    # 1. Compile the main application as WifadeCore.exe
    Write-Host "  Building WifadeCore.exe (main application)..." -ForegroundColor Cyan
    $coreParams = @{
        InputFile = $outputScript
        OutputFile = $coreExe
        NoConsole = $false
        NoOutput = $false
        NoError = $false
        Verbose = $false
        Debug = $false
        LongPaths = $true
        UNICODEEncoding = $true
        RequireAdmin = $false  # Launcher will handle admin requirements
        Title = "WifadeCore - WiFi Security Testing Tool Core"
        Description = "Wifi Manager with in-built Bruteforcer - Core Application"
        Company = "FadSec Lab"
        Version = "2.0"
        Copyright = "© 2024-2025 faded.dev"
    }
    
    # Add icon if it exists
    if ($iconPath -and (Test-Path $iconPath)) {
        $coreParams.IconFile = $iconPath
        Write-Host "    Using processed icon: $iconPath" -ForegroundColor Gray
    }
    
    # Compile the core application
    Invoke-ps2exe @coreParams
    
    if (-not (Test-Path $coreExe)) {
        throw "Failed to create WifadeCore.exe"
    }
    
    $coreFileSize = [math]::Round((Get-Item $coreExe).Length / 1MB, 2)
    Write-Host "    ✅ WifadeCore.exe created ($coreFileSize MB)" -ForegroundColor Green
    
    # 2. Compile the launcher as Wifade.exe
     Write-Host "  Building Wifade.exe (PowerShell launcher)..." -ForegroundColor Cyan
     $launcherParams = @{
         InputFile = $launcherScript
         OutputFile = $launcherExe
         NoConsole = $false
         NoOutput = $false
         NoError = $false
         Verbose = $false
         Debug = $false
         LongPaths = $true
         UNICODEEncoding = $true
         RequireAdmin = $false  # Launcher handles admin check gracefully
         Title = "Wifade - WiFi Security Testing Tool"
         Description = "Wifi Manager with in-built Bruteforcer - PowerShell Launcher"
         Company = "FadSec Lab"
         Version = "2.0"
         Copyright = "© 2024-2025 faded.dev"
     }
    
    # Add icon if it exists
    if ($iconPath -and (Test-Path $iconPath)) {
        $launcherParams.IconFile = $iconPath
        Write-Host "    Using processed icon: $iconPath" -ForegroundColor Gray
    }
    
    # Compile the launcher
    Invoke-ps2exe @launcherParams
    
    if (-not (Test-Path $launcherExe)) {
        throw "Failed to create Wifade.exe launcher"
    }
    
    $launcherFileSize = [math]::Round((Get-Item $launcherExe).Length / 1MB, 2)
    Write-Host "    ✅ Wifade.exe launcher created ($launcherFileSize MB)" -ForegroundColor Green
    
    # Test both executables
    Write-Host ""
    Write-Host "Testing executables..." -ForegroundColor Yellow
    
    # Test core executable
    Write-Host "  Testing WifadeCore.exe..." -ForegroundColor Cyan
    $coreTestResult = & $coreExe -Version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ WifadeCore.exe test passed" -ForegroundColor Green
        Write-Host "    Version output: $coreTestResult" -ForegroundColor Gray
    } else {
        Write-Warning "    ⚠️ WifadeCore.exe test failed with exit code: $LASTEXITCODE"
        Write-Host "    Error output: $coreTestResult" -ForegroundColor Red
    }
    
    # Test launcher executable
    Write-Host "  Testing Wifade.exe launcher..." -ForegroundColor Cyan
    
    # Change to build directory for launcher test to ensure it finds WifadeCore.exe
    $originalLocation = Get-Location
    try {
        Set-Location $buildDir
        $launcherTestResult = & ".\Wifade.exe" -Version 2>&1
        $launcherExitCode = $LASTEXITCODE
    } finally {
        Set-Location $originalLocation
    }
    
    if ($launcherExitCode -eq 0) {
        Write-Host "    ✅ Wifade.exe launcher test passed" -ForegroundColor Green
        if ($launcherTestResult) {
            Write-Host "    Launcher output: $launcherTestResult" -ForegroundColor Gray
        }
    } else {
        Write-Warning "    ⚠️ Wifade.exe launcher test failed with exit code: $launcherExitCode"
        Write-Host "    Error output: $launcherTestResult" -ForegroundColor Red
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
Write-Host "   • Main Launcher:     $(Join-Path $buildDir "Wifade.exe")" -ForegroundColor White
Write-Host "   • Core Application:  $(Join-Path $buildDir "WifadeCore.exe")" -ForegroundColor White
Write-Host "   • Combined Source:   $outputScript" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Usage:" -ForegroundColor Cyan
Write-Host "   Simply run the main launcher - it will automatically start WifadeCore.exe in PowerShell:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   .\build\Wifade.exe                    # Launch Wifade in PowerShell" -ForegroundColor White
Write-Host "   .\build\Wifade.exe -Help              # Show help in PowerShell" -ForegroundColor White
Write-Host "   .\build\Wifade.exe -Version           # Show version in PowerShell" -ForegroundColor White
Write-Host "   .\build\Wifade.exe -Scan              # Scan networks in PowerShell" -ForegroundColor White
Write-Host ""
Write-Host "✨ Key Benefits:" -ForegroundColor Cyan
Write-Host "   • Clean UI: Only Wifade.exe is visible to users" -ForegroundColor Green
Write-Host "   • PowerShell Environment: Runs in PowerShell, not cmd.exe" -ForegroundColor Green
Write-Host "   • Unicode Support: Proper display of arrows (→) and special characters" -ForegroundColor Green
Write-Host "   • Admin Elevation: Launcher handles administrator privileges" -ForegroundColor Green
Write-Host "   • Portable: Both files work together as a complete package" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Important Notes:" -ForegroundColor Yellow
Write-Host "   • Keep both Wifade.exe and WifadeCore.exe in the same directory" -ForegroundColor White
Write-Host "   • Wifade.exe is the launcher that users should run" -ForegroundColor White
Write-Host "   • WifadeCore.exe contains the main application logic" -ForegroundColor White
Write-Host "   • Administrator privileges are required for full functionality" -ForegroundColor White
Write-Host ""
Write-Host "Build completed successfully! 🎉" -ForegroundColor Green
