# ============================================================================
# VERSION CONFIGURATION
# ============================================================================
# Update this version number when releasing new versions
$Script:WIFADE_VERSION = "2.0"

class VersionChecker {
    [string] $CurrentVersion
    [string] $RepoUrl
    [string] $ReleasesUrl
    [bool] $VerboseMode
    [bool] $UpdateAvailable
    [string] $LatestVersion
    [string] $ReleaseUrl
    [bool] $CheckCompleted
    
    VersionChecker([string] $currentVersion, [string] $repoUrl, [bool] $verboseMode = $false) {
        $this.CurrentVersion = $currentVersion
        $this.RepoUrl = $repoUrl
        $this.ReleasesUrl = "$repoUrl/releases/latest"
        $this.VerboseMode = $verboseMode
        $this.UpdateAvailable = $false
        $this.LatestVersion = ""
        $this.ReleaseUrl = ""
        $this.CheckCompleted = $false
    }
    
    # Convenience constructor that uses the default version
    VersionChecker([string] $repoUrl, [bool] $verboseMode = $false) {
        $this.CurrentVersion = $Script:WIFADE_VERSION
        $this.RepoUrl = $repoUrl
        $this.ReleasesUrl = "$repoUrl/releases/latest"
        $this.VerboseMode = $verboseMode
        $this.UpdateAvailable = $false
        $this.LatestVersion = ""
        $this.ReleaseUrl = ""
        $this.CheckCompleted = $false
    }
    
    [hashtable] GetLatestVersion() {
        try {
            # Create web request with browser-like headers
            $headers = @{
                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            # Make the request with shorter timeout for faster startup
            $response = Invoke-WebRequest -Uri $this.ReleasesUrl -Headers $headers -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            
            # Check if response is valid
            if ($null -eq $response) {
                if ($this.VerboseMode) {
                    Write-Host "Received null response from GitHub" -ForegroundColor Yellow
                }
                return @{
                    Version = $null
                    Url = $this.ReleasesUrl
                    Success = $false
                }
            }
            
            # Get final URL safely
            $finalUrl = $this.ReleasesUrl
            if ($null -ne $response.BaseResponse -and $null -ne $response.BaseResponse.ResponseUri) {
                $finalUrl = $response.BaseResponse.ResponseUri.ToString()
            }
            
            if ($this.VerboseMode) {
                Write-Host "Final URL: $finalUrl" -ForegroundColor Cyan
                Write-Host "Response status: $($response.StatusCode)" -ForegroundColor Cyan
                Write-Host "│ " -ForegroundColor Cyan -NoNewline
                Read-Host "Press Enter to continue"
            }
            
            # Extract version from URL (usually ends with /tag/vX.Y.Z or /tag/X.Y.Z)
            if ($finalUrl -match '/tag/v?(\d+\.\d+(?:\.\d+)?)') {
                $version = $matches[1]
                if ($this.VerboseMode) {
                    Write-Host "Extracted version from URL: $version" -ForegroundColor Green
                    Write-Host "│ " -ForegroundColor Green -NoNewline
                    Read-Host "Press Enter to continue"
                }
                return @{
                    Version = $version
                    Url = $finalUrl
                    Success = $true
                }
            }
            
            # If URL extraction fails, try to parse the content
            if ($null -ne $response.Content) {
                $content = $response.Content
                if ($this.VerboseMode) {
                    Write-Host "Content length: $($content.Length) characters" -ForegroundColor Cyan
                    # Show first 500 characters of content for debugging
                    $preview = if ($content.Length -gt 500) { $content.Substring(0, 500) + "..." } else { $content }
                    Write-Host "Content preview: $preview" -ForegroundColor Gray
                    Write-Host "│ " -ForegroundColor Cyan -NoNewline
                    Read-Host "Press Enter to continue"
                }
                
                # Try multiple patterns for version extraction
                $patterns = @(
                    'Release\s+v?(\d+\.\d+(?:\.\d+)?)',
                    'tag/v?(\d+\.\d+(?:\.\d+)?)',
                    'releases/tag/v?(\d+\.\d+(?:\.\d+)?)',
                    '"tag_name":\s*"v?(\d+\.\d+(?:\.\d+)?)"',
                    'Version\s+v?(\d+\.\d+(?:\.\d+)?)'
                )
                
                foreach ($pattern in $patterns) {
                    if ($content -match $pattern) {
                        $version = $matches[1]
                        if ($this.VerboseMode) {
                            Write-Host "Extracted version from content using pattern '$pattern': $version" -ForegroundColor Green
                            Write-Host "│ " -ForegroundColor Green -NoNewline
                            Read-Host "Press Enter to continue"
                        }
                        return @{
                            Version = $version
                            Url = $finalUrl
                            Success = $true
                        }
                    }
                }
                
                if ($this.VerboseMode) {
                    Write-Host "No version pattern matched in content" -ForegroundColor Yellow
                    Write-Host "│ " -ForegroundColor Yellow -NoNewline
                    Read-Host "Press Enter to continue"
                }
            }
            
            if ($this.VerboseMode) {
                Write-Host "Could not extract version number from GitHub release page" -ForegroundColor Yellow
            }
            
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
            }
            
        } catch [System.Net.WebException] {
            if ($this.VerboseMode) {
                Write-Host "Network error checking for updates: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "│ " -ForegroundColor Red -NoNewline
                Read-Host "Press Enter to continue"
            }
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
            }
        } catch [System.TimeoutException] {
            if ($this.VerboseMode) {
                Write-Host "Timeout while checking for updates" -ForegroundColor Red
                Write-Host "│ " -ForegroundColor Red -NoNewline
                Read-Host "Press Enter to continue"
            }
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
            }
        } catch {
            if ($this.VerboseMode) {
                Write-Host "Error checking for updates: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "│ " -ForegroundColor Red -NoNewline
                Read-Host "Press Enter to continue"
            }
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
            }
        }
    }
    
    [array] VersionToArray([string] $versionString) {
        return $versionString.Split('.') | ForEach-Object { [int]$_ }
    }
    
    [bool] IsUpdateAvailable([string] $currentVersion, [string] $latestVersion) {
        try {
            $currentArray = $this.VersionToArray($currentVersion)
            $latestArray = $this.VersionToArray($latestVersion)
            
            # Compare version arrays
            $maxLength = [Math]::Max($currentArray.Length, $latestArray.Length)
            
            for ($i = 0; $i -lt $maxLength; $i++) {
                $currentPart = if ($i -lt $currentArray.Length) { $currentArray[$i] } else { 0 }
                $latestPart = if ($i -lt $latestArray.Length) { $latestArray[$i] } else { 0 }
                
                if ($latestPart -gt $currentPart) {
                    return $true
                } elseif ($latestPart -lt $currentPart) {
                    return $false
                }
            }
            
            return $false
        } catch {
            if ($this.VerboseMode) {
                Write-Host "Error comparing versions: $($_.Exception.Message)" -ForegroundColor Red
            }
            return $false
        }
    }
    
    [void] CheckForUpdatesAsync() {
        # Run update check in background job for faster startup
        $job = Start-Job -ScriptBlock {
            param($releasesUrl, $verboseMode)
            
            try {
                $headers = @{
                    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
                
                $response = Invoke-WebRequest -Uri $releasesUrl -Headers $headers -TimeoutSec 5 -UseBasicParsing
                $finalUrl = $response.BaseResponse.ResponseUri.ToString()
                
                if ($finalUrl -match '/tag/v?(\d+\.\d+(?:\.\d+)?)') {
                    return @{
                        Version = $matches[1]
                        Url = $finalUrl
                        Success = $true
                    }
                }
                
                $content = $response.Content
                if ($content -match 'Release\s+v?(\d+\.\d+(?:\.\d+)?)') {
                    return @{
                        Version = $matches[1]
                        Url = $finalUrl
                        Success = $true
                    }
                }
                
                return @{
                    Version = $null
                    Url = $releasesUrl
                    Success = $false
                }
                
            } catch {
                return @{
                    Version = $null
                    Url = $releasesUrl
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $this.ReleasesUrl, $this.VerboseMode
        
        # Store job for later retrieval
        $this.UpdateCheckJob = $job
    }
    
    [hashtable] CheckForUpdates() {
        if ($this.VerboseMode) {
            Write-Host "Checking for updates..." -ForegroundColor Cyan
            Write-Host "Current version: $($this.CurrentVersion)" -ForegroundColor White
        }
        
        try {
            $result = $this.GetLatestVersion()
            $this.CheckCompleted = $true
            
            if ($result.Success -and $result.Version) {
                $this.LatestVersion = $result.Version
                $this.ReleaseUrl = $result.Url
                $this.UpdateAvailable = $this.IsUpdateAvailable($this.CurrentVersion, $this.LatestVersion)
                
                if ($this.VerboseMode) {
                    Write-Host "Latest version: $($this.LatestVersion)" -ForegroundColor White
                    if ($this.UpdateAvailable) {
                        Write-Host "Update available!" -ForegroundColor Green
                    } else {
                        Write-Host "No update available - already latest version" -ForegroundColor Green
                    }
                }
                
                return @{
                    UpdateAvailable = $this.UpdateAvailable
                    LatestVersion = $this.LatestVersion
                    ReleaseUrl = $this.ReleaseUrl
                    Success = $true
                }
            } else {
                 if ($this.VerboseMode) {
                     Write-Host "Failed to check for updates" -ForegroundColor Red
                     Write-Host "│ " -ForegroundColor Red -NoNewline
                     Read-Host "Press Enter to continue"
                 }
                 
                 return @{
                     UpdateAvailable = $false
                     LatestVersion = $null
                     ReleaseUrl = $this.ReleasesUrl
                     Success = $false
                 }
             }
         } catch {
             # Silently handle errors unless in verbose mode
             if ($this.VerboseMode) {
                 Write-Host "Error during update check: $($_.Exception.Message)" -ForegroundColor Red
                 Write-Host "│ " -ForegroundColor Red -NoNewline
                 Read-Host "Press Enter to continue"
             }
            
            $this.CheckCompleted = $true
            return @{
                UpdateAvailable = $false
                LatestVersion = $null
                ReleaseUrl = $this.ReleasesUrl
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    [hashtable] CheckForUpdatesQuiet() {
        # Silent version that never shows any output, but still sets flags properly
        try {
            $result = $this.GetLatestVersionQuiet()
            $this.CheckCompleted = $true
            
            if ($result.Success -and $result.Version) {
                $this.LatestVersion = $result.Version
                $this.ReleaseUrl = $result.Url
                $this.UpdateAvailable = $this.IsUpdateAvailable($this.CurrentVersion, $this.LatestVersion)
                
                return @{
                    UpdateAvailable = $this.UpdateAvailable
                    LatestVersion = $this.LatestVersion
                    ReleaseUrl = $this.ReleaseUrl
                    Success = $true
                    CurrentVersion = $this.CurrentVersion
                }
            } else {
                # Ensure UpdateAvailable is explicitly set to false
                $this.UpdateAvailable = $false
                return @{
                    UpdateAvailable = $false
                    LatestVersion = $null
                    ReleaseUrl = $this.ReleasesUrl
                    Success = $false
                    CurrentVersion = $this.CurrentVersion
                }
            }
        } catch {
            $this.CheckCompleted = $true
            # Ensure UpdateAvailable is explicitly set to false on error
            $this.UpdateAvailable = $false
            return @{
                UpdateAvailable = $false
                LatestVersion = $null
                ReleaseUrl = $this.ReleasesUrl
                Success = $false
                Error = $_.Exception.Message
                CurrentVersion = $this.CurrentVersion
            }
        }
    }
    
    [hashtable] GetLatestVersionQuiet() {
        try {
            # Create web request with browser-like headers
            $headers = @{
                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
            }
            
            # Make the request with longer timeout for better reliability
            $response = Invoke-WebRequest -Uri $this.ReleasesUrl -Headers $headers -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            
            # Check if response is valid
            if ($null -eq $response) {
                return @{
                    Version = $null
                    Url = $this.ReleasesUrl
                    Success = $false
                    Error = "Null response from GitHub"
                }
            }
            
            # Check response status
            if ($response.StatusCode -ne 200) {
                return @{
                    Version = $null
                    Url = $this.ReleasesUrl
                    Success = $false
                    Error = "HTTP $($response.StatusCode)"
                }
            }
            
            # Get final URL safely
            $finalUrl = $this.ReleasesUrl
            if ($null -ne $response.BaseResponse -and $null -ne $response.BaseResponse.ResponseUri) {
                $finalUrl = $response.BaseResponse.ResponseUri.ToString()
            }
            
            # Extract version from URL (usually ends with /tag/vX.Y.Z)
            if ($finalUrl -match '/tag/v?(\d+\.\d+(?:\.\d+)?)') {
                $version = $matches[1]
                return @{
                    Version = $version
                    Url = $finalUrl
                    Success = $true
                }
            }
            
            # If URL extraction fails, try to parse the content
            if ($null -ne $response.Content) {
                $content = $response.Content
                
                # Try multiple patterns for version extraction
                $patterns = @(
                    'Release\s+v?(\d+\.\d+(?:\.\d+)?)',
                    'tag/v?(\d+\.\d+(?:\.\d+)?)',
                    'releases/tag/v?(\d+\.\d+(?:\.\d+)?)',
                    '"tag_name":\s*"v?(\d+\.\d+(?:\.\d+)?)"',
                    'Version\s+v?(\d+\.\d+(?:\.\d+)?)'
                )
                
                foreach ($pattern in $patterns) {
                    if ($content -match $pattern) {
                        return @{
                            Version = $matches[1]
                            Url = $finalUrl
                            Success = $true
                        }
                    }
                }
            }
            
            # If we get here, no version was found
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
                Error = "No version found in response"
            }
            
        } catch [System.Net.WebException] {
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
                Error = "Network error: $($_.Exception.Message)"
            }
        } catch [System.TimeoutException] {
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
                Error = "Request timeout"
            }
        } catch {
            return @{
                Version = $null
                Url = $this.ReleasesUrl
                Success = $false
                Error = "Unexpected error: $($_.Exception.Message)"
            }
        }
    }
    
    [string] GetUpdateNotificationText() {
        if ($this.UpdateAvailable) {
            return "🚀 Update Available! Current: v$($this.CurrentVersion) → Latest: v$($this.LatestVersion)"
        }
        return ""
    }
    
    [string] GetUpdateUrl() {
        return $this.ReleaseUrl
    }
    
    [void] ShowUpdateNotification() {
        if ($this.UpdateAvailable) {
            Write-Host ""
            Write-Host "╭──" -ForegroundColor Yellow -NoNewline
            Write-Host "🚀 UPDATE AVAILABLE " -ForegroundColor Green -NoNewline
            Write-Host "" 
            Write-Host "│ " -ForegroundColor Yellow -NoNewline
            Write-Host "Current version: " -ForegroundColor White -NoNewline
            Write-Host "v$($this.CurrentVersion)" -ForegroundColor Red
            Write-Host "│ " -ForegroundColor Yellow -NoNewline
            Write-Host "Latest version:  " -ForegroundColor White -NoNewline
            Write-Host "v$($this.LatestVersion)" -ForegroundColor Green
            Write-Host "│ " -ForegroundColor Yellow -NoNewline
            Write-Host "Download: " -ForegroundColor White -NoNewline
            Write-Host "$($this.ReleaseUrl)" -ForegroundColor Cyan
            Write-Host "╰───────────────────────────────────────────────────" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}