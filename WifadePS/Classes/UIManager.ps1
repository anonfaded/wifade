# UIManager Class for WifadePS
# Handles interactive CLI interface, menus, and user interactions

class UIManager : IManager {
    [hashtable]$ColorScheme
    [bool]$DebugMode
    [bool]$VerboseMode
    [hashtable]$MenuOptions
    [string]$CurrentMenu
    [int]$TerminalWidth
    [int]$TerminalHeight
    
    # Constructor
    UIManager() {
        $this.InitializeProperties()
    }
    
    # Constructor with configuration
    UIManager([hashtable]$config) {
        $this.InitializeProperties()
        $this.ApplyConfiguration($config)
    }
    
    # Initialize all properties
    [void] InitializeProperties() {
        # Initialize base class properties
        $this.IsInitialized = $false
        $this.Configuration = @{}
        
        # Initialize UIManager properties
        $this.ColorScheme = @{
            Primary   = "Cyan"
            Secondary = "White"
            Success   = "Green"
            Warning   = "Yellow"
            Error     = "Red"
            Info      = "Blue"
            Debug     = "Gray"
            Highlight = "Magenta"
            Border    = "DarkCyan"
        }
        
        $this.DebugMode = $false
        $this.VerboseMode = $false
        $this.CurrentMenu = "Main"
        
        # Get terminal dimensions
        try {
            $host = Get-Host
            $this.TerminalWidth = $host.UI.RawUI.WindowSize.Width
            $this.TerminalHeight = $host.UI.RawUI.WindowSize.Height
        }
        catch {
            $this.TerminalWidth = 80
            $this.TerminalHeight = 25
        }
        
        $this.InitializeMenuOptions()
    }
    
    # Initialize menu options
    [void] InitializeMenuOptions() {
        $this.MenuOptions = @{
            Main       = @(
                @{ Key = "1"; Text = "Scan Wi-Fi Networks"; Action = "ScanNetworks" }
                @{ Key = "2"; Text = "Attack Mode"; Action = "AttackMode" }
                @{ Key = "3"; Text = "View Results"; Action = "ViewResults" }
                @{ Key = "4"; Text = "Settings"; Action = "Settings" }
                @{ Key = "5"; Text = "Help"; Action = "Help" }
                @{ Key = "q"; Text = "Quit"; Action = "Quit" }
            )
            AttackMode = @(
                @{ Key = "1"; Text = "Dictionary Attack"; Action = "DictionaryAttack" }
                @{ Key = "2"; Text = "SSID-Based Attack"; Action = "SSIDAttack" }
                @{ Key = "3"; Text = "Hybrid Attack"; Action = "HybridAttack" }
                @{ Key = "4"; Text = "Custom Attack"; Action = "CustomAttack" }
                @{ Key = "b"; Text = "Back to Main Menu"; Action = "BackToMain" }
            )
            Settings   = @(
                @{ Key = "1"; Text = "Toggle Debug Mode"; Action = "ToggleDebug" }
                @{ Key = "2"; Text = "Toggle Stealth Mode"; Action = "ToggleStealth" }
                @{ Key = "3"; Text = "Set Rate Limit"; Action = "SetRateLimit" }
                @{ Key = "4"; Text = "Configure Files"; Action = "ConfigureFiles" }
                @{ Key = "5"; Text = "Export Settings"; Action = "ExportSettings" }
                @{ Key = "b"; Text = "Back to Main Menu"; Action = "BackToMain" }
            )
        }
    }
    
    # Initialize the UIManager
    [void] Initialize([hashtable]$config) {
        try {
            Write-Debug "Initializing UIManager..."
            
            # Apply configuration
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                $this.ApplyConfiguration($config)
            }
            
            # Initialize console settings
            $this.InitializeConsole()
            
            $this.IsInitialized = $true
            Write-Debug "UIManager initialized successfully"
        }
        catch {
            throw [ConfigurationException]::new("Failed to initialize UIManager: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Apply configuration settings
    [void] ApplyConfiguration([hashtable]$config) {
        if ($config.ContainsKey('DebugMode')) {
            $this.DebugMode = $config['DebugMode']
        }
        if ($config.ContainsKey('VerboseMode')) {
            $this.VerboseMode = $config['VerboseMode']
        }
        if ($config.ContainsKey('ColorScheme')) {
            foreach ($key in $config['ColorScheme'].Keys) {
                $this.ColorScheme[$key] = $config['ColorScheme'][$key]
            }
        }
    }
    
    # Initialize console settings
    [void] InitializeConsole() {
        try {
            # Set console title
            $host = Get-Host
            $host.UI.RawUI.WindowTitle = "WifadePS - Wi-Fi Security Testing Tool"
            
            # Enable ANSI color support if possible
            $psVersion = Get-Variable PSVersionTable -ValueOnly -ErrorAction SilentlyContinue
            if ($psVersion -and $psVersion.PSVersion.Major -ge 7) {
                try {
                    $psStyle = Get-Variable PSStyle -ValueOnly -ErrorAction SilentlyContinue
                    if ($psStyle) {
                        $psStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Ansi
                    }
                }
                catch {
                    # Ignore ANSI color support errors
                }
            }
        }
        catch {
            Write-Debug "Could not initialize console settings: $($_.Exception.Message)"
        }
    }
    
    # Display the main application banner
    [void] ShowBanner() {
        $this.ClearScreen()
        
        $banner = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║  ██╗    ██╗██╗███████╗ █████╗ ██████╗ ███████╗██████╗ ███████╗               ║
║  ██║    ██║██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝               ║
║  ██║ █╗ ██║██║█████╗  ███████║██║  ██║█████╗  ██████╔╝███████╗               ║
║  ██║███╗██║██║██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔═══╝ ╚════██║               ║
║  ╚███╔███╔╝██║██║     ██║  ██║██████╔╝███████╗██║     ███████║               ║
║   ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝     ╚══════╝               ║
║                                                                              ║
║  Windows PowerShell Wi-Fi Security Testing Tool                             ║
║  Version: 1.0.0                                                             ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@
        
        Write-Host $banner -ForegroundColor $this.ColorScheme.Primary
        Write-Host ""
    }
    
    # Display the main menu
    [string] ShowMainMenu() {
        $this.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor $this.ColorScheme.Border
        Write-Host "║                                MAIN MENU                                    ║" -ForegroundColor $this.ColorScheme.Border
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        foreach ($option in $this.MenuOptions.Main) {
            $keyColor = $this.ColorScheme.Highlight
            $textColor = $this.ColorScheme.Secondary
            Write-Host "  [$($option.Key)]" -ForegroundColor $keyColor -NoNewline
            Write-Host " $($option.Text)" -ForegroundColor $textColor
        }
        
        Write-Host ""
        Write-Host "Select an option: " -ForegroundColor $this.ColorScheme.Info -NoNewline
        
        return Read-Host
    }
    
    # Display attack mode menu
    [string] ShowAttackModeMenu() {
        $this.ClearScreen()
        $this.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor $this.ColorScheme.Border
        Write-Host "║                              ATTACK MODE                                     ║" -ForegroundColor $this.ColorScheme.Border
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        foreach ($option in $this.MenuOptions.AttackMode) {
            $keyColor = $this.ColorScheme.Highlight
            $textColor = $this.ColorScheme.Secondary
            Write-Host "  [$($option.Key)]" -ForegroundColor $keyColor -NoNewline
            Write-Host " $($option.Text)" -ForegroundColor $textColor
        }
        
        Write-Host ""
        Write-Host "Select attack type: " -ForegroundColor $this.ColorScheme.Info -NoNewline
        
        return Read-Host
    }
    
    # Display settings menu
    [string] ShowSettingsMenu() {
        $this.ClearScreen()
        $this.ShowBanner()
        
        Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor $this.ColorScheme.Border
        Write-Host "║                                SETTINGS                                      ║" -ForegroundColor $this.ColorScheme.Border
        Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        # Show current settings
        Write-Host "Current Settings:" -ForegroundColor $this.ColorScheme.Info
        Write-Host "  Debug Mode: " -ForegroundColor $this.ColorScheme.Secondary -NoNewline
        $debugStatus = if ($this.DebugMode) { "ON" } else { "OFF" }
        $debugColor = if ($this.DebugMode) { $this.ColorScheme.Success } else { $this.ColorScheme.Warning }
        Write-Host $debugStatus -ForegroundColor $debugColor
        Write-Host "  Verbose Mode: " -ForegroundColor $this.ColorScheme.Secondary -NoNewline
        $verboseStatus = if ($this.VerboseMode) { "ON" } else { "OFF" }
        $verboseColor = if ($this.VerboseMode) { $this.ColorScheme.Success } else { $this.ColorScheme.Warning }
        Write-Host $verboseStatus -ForegroundColor $verboseColor
        Write-Host ""
        
        foreach ($option in $this.MenuOptions.Settings) {
            $keyColor = $this.ColorScheme.Highlight
            $textColor = $this.ColorScheme.Secondary
            Write-Host "  [$($option.Key)]" -ForegroundColor $keyColor -NoNewline
            Write-Host " $($option.Text)" -ForegroundColor $textColor
        }
        
        Write-Host ""
        Write-Host "Select an option: " -ForegroundColor $this.ColorScheme.Info -NoNewline
        
        return Read-Host
    }
    
    # Display progress bar
    [void] ShowProgress([int]$current, [int]$total, [string]$status = "") {
        if ($total -eq 0) { return }
        
        $percentage = [Math]::Round(($current / $total) * 100, 1)
        $barWidth = 50
        $filledWidth = [Math]::Round(($percentage / 100) * $barWidth)
        
        $bar = "█" * $filledWidth + "░" * ($barWidth - $filledWidth)
        
        Write-Host "`r" -NoNewline
        Write-Host "Progress: [" -ForegroundColor $this.ColorScheme.Info -NoNewline
        Write-Host $bar -ForegroundColor $this.ColorScheme.Success -NoNewline
        Write-Host "] " -ForegroundColor $this.ColorScheme.Info -NoNewline
        Write-Host "$percentage%" -ForegroundColor $this.ColorScheme.Highlight -NoNewline
        Write-Host " ($current/$total)" -ForegroundColor $this.ColorScheme.Secondary -NoNewline
        
        if ($status) {
            Write-Host " - $status" -ForegroundColor $this.ColorScheme.Info -NoNewline
        }
    }
    
    # Display success message
    [void] ShowSuccess([string]$message) {
        Write-Host "✓ $message" -ForegroundColor $this.ColorScheme.Success
    }
    
    # Display warning message
    [void] ShowWarning([string]$message) {
        Write-Host "⚠ $message" -ForegroundColor $this.ColorScheme.Warning
    }
    
    # Display error message
    [void] ShowError([string]$message) {
        Write-Host "✗ $message" -ForegroundColor $this.ColorScheme.Error
    }
    
    # Display info message
    [void] ShowInfo([string]$message) {
        Write-Host "ℹ $message" -ForegroundColor $this.ColorScheme.Info
    }
    
    # Display debug message (only if debug mode is enabled)
    [void] ShowDebug([string]$message) {
        if ($this.DebugMode) {
            Write-Host "[DEBUG] $message" -ForegroundColor $this.ColorScheme.Debug
        }
    }
    
    # Display verbose message (only if verbose mode is enabled)
    [void] ShowVerbose([string]$message) {
        if ($this.VerboseMode) {
            Write-Host "[VERBOSE] $message" -ForegroundColor $this.ColorScheme.Debug
        }
    }
    
    # Clear the screen
    [void] ClearScreen() {
        Clear-Host
    }
    
    # Wait for user input
    [void] WaitForKeyPress([string]$message = "Press any key to continue...") {
        Write-Host ""
        try {
            $consoleHost = Get-Host
            Write-Host $message -ForegroundColor $this.ColorScheme.Info
            $null = $consoleHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        catch {
            # Fallback to Read-Host if ReadKey is not available
            $null = Read-Host $message
        }
    }
    
    # Get user confirmation
    [bool] GetConfirmation([string]$message, [bool]$defaultYes = $false) {
        $prompt = if ($defaultYes) { " (Y/n)" } else { " (y/N)" }
        Write-Host "$message$prompt" -ForegroundColor $this.ColorScheme.Info -NoNewline
        Write-Host ": " -NoNewline
        
        $response = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $defaultYes
        }
        
        return $response -match '^[Yy]([Ee][Ss])?$'
    }
    
    # Get user input with validation
    [string] GetUserInput([string]$prompt, [string]$validationPattern = "", [string]$errorMessage = "Invalid input. Please try again.") {
        do {
            Write-Host $prompt -ForegroundColor $this.ColorScheme.Info -NoNewline
            Write-Host ": " -NoNewline
            $input = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($validationPattern) -or $input -match $validationPattern) {
                return $input
            }
            
            $this.ShowError($errorMessage)
        } while ($true)
        
        return ""  # This should never be reached, but PowerShell requires it
    }
    
    # Display network list in a formatted table
    [void] ShowNetworkList([array]$networks) {
        if ($networks.Count -eq 0) {
            $this.ShowWarning("No networks found.")
            return
        }
        
        Write-Host ""
        Write-Host "Available Networks:" -ForegroundColor $this.ColorScheme.Primary
        Write-Host "=" * 80 -ForegroundColor $this.ColorScheme.Border
        
        $header = "  {0,-3} {1,-25} {2,-10} {3,-15} {4,-10}" -f "No.", "SSID", "Signal", "Encryption", "Status"
        Write-Host $header -ForegroundColor $this.ColorScheme.Info
        Write-Host "  " + ("-" * 75) -ForegroundColor $this.ColorScheme.Border
        
        for ($i = 0; $i -lt $networks.Count; $i++) {
            $network = $networks[$i]
            $signalBar = $this.GetSignalStrengthBar($network.SignalStrength)
            $signalText = "$signalBar $($network.SignalStrength)%"
            
            $status = if ($network.IsConnectable) { "Available" } else { "Unavailable" }
            
            $line = "  {0,-3} {1,-25} {2,-10} {3,-15} {4,-10}" -f ($i + 1), $network.SSID, $signalText, $network.EncryptionType, $status
            Write-Host $line -ForegroundColor $this.ColorScheme.Secondary
        }
        
        Write-Host ""
    }
    
    # Get signal strength bar representation
    [string] GetSignalStrengthBar([int]$signalStrength) {
        if ($signalStrength -ge 80) { return "████" }
        elseif ($signalStrength -ge 60) { return "███░" }
        elseif ($signalStrength -ge 40) { return "██░░" }
        elseif ($signalStrength -ge 20) { return "█░░░" }
        else { return "░░░░" }
    }
    
    # Toggle debug mode
    [void] ToggleDebugMode() {
        $this.DebugMode = -not $this.DebugMode
        $status = if ($this.DebugMode) { "enabled" } else { "disabled" }
        $this.ShowSuccess("Debug mode $status")
    }
    
    # Toggle verbose mode
    [void] ToggleVerboseMode() {
        $this.VerboseMode = -not $this.VerboseMode
        $status = if ($this.VerboseMode) { "enabled" } else { "disabled" }
        $this.ShowSuccess("Verbose mode $status")
    }
    
    # Validate configuration
    [bool] ValidateConfiguration([hashtable]$config) {
        return $true
    }
    
    # Dispose resources
    [void] Dispose() {
        try {
            Write-Debug "Disposing UIManager resources..."
            
            # Reset console title
            try {
                $host = Get-Host
                $host.UI.RawUI.WindowTitle = "Windows PowerShell"
            }
            catch {
                # Ignore errors when resetting console title
            }
            
            $this.IsInitialized = $false
            Write-Debug "UIManager disposed successfully"
        }
        catch {
            Write-Warning "Error during UIManager disposal: $($_.Exception.Message)"
        }
    }
}