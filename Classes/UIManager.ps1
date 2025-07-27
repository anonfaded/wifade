# UIManager Class for wifade
# Handles interactive CLI interface, menus, and user interactions

class UIManager : IManager {
    [hashtable]$ColorScheme
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
            Primary   = "Red"
            Secondary = "White"
            Success   = "Green"
            Warning   = "Yellow"
            Error     = "Red"
            Info      = "Blue"
            Verbose   = "Gray"
            Highlight = "Red"
            Border    = "Red"
        }
        
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
                @{ Key = "3"; Text = "Settings"; Action = "Settings" }
                @{ Key = "4"; Text = "Help"; Action = "Help" }
                @{ Key = "q"; Text = "Quit"; Action = "Quit" }
            )
            AttackMode = @(
                @{ Key = "1"; Text = "Use Built-in Wordlist (4700+ common passwords)"; Action = "DictionaryAttack" }
                @{ Key = "2"; Text = "Use Custom Password File (select your own wordlist)"; Action = "CustomPasswordFile" }
                @{ Key = "b"; Text = "Back to Main Menu"; Action = "BackToMain" }
            )
            Settings   = @(
                @{ Key = "1"; Text = "Toggle Verbose Mode"; Action = "ToggleVerbose" }
                @{ Key = "b"; Text = "Back to Main Menu"; Action = "BackToMain" }
            )
        }
    }
    
    # Initialize the UIManager
    [void] Initialize([hashtable]$config) {
        try {
            Write-Verbose "Initializing UIManager..."
            
            # Apply configuration
            if ($config.Count -gt 0) {
                $this.Configuration = $config
                $this.ApplyConfiguration($config)
            }
            
            # Initialize console settings
            $this.InitializeConsole()
            
            $this.IsInitialized = $true
            Write-Verbose "UIManager initialized successfully"
        }
        catch {
            throw [ConfigurationException]::new("Failed to initialize UIManager: $($_.Exception.Message)", $_.Exception)
        }
    }
    
    # Apply configuration settings
    [void] ApplyConfiguration([hashtable]$config) {
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
            $host.UI.RawUI.WindowTitle = "wifade - Wi-Fi Security Testing Tool"
            
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
            Write-Verbose "Could not initialize console settings: $($_.Exception.Message)"
        }
    }
    
# Display the main application banner
[void] ShowBanner() {
    $this.ClearScreen()
    
    $bannerTop = @"
            
        █     █░ ██▓  █████▒▄▄▄      ▓█████▄ ▓█████ 
        ▓█░ █ ░█░▓██▒▓██   ▒▒████▄    ▒██▀ ██▌▓█   ▀ 
        ▒█░ █ ░█ ▒██▒▒████ ░▒██  ▀█▄  ░██   █▌▒███   
        ░█░ █ ░█ ░██░░▓█▒  ░░██▄▄▄▄██ ░▓█▄   ▌▒▓█  ▄ 
        ░░██▒██▓ ░██░░▒█░    ▓█   ▓██▒░▒████▓ ░▒████▒
        ░ ▓░▒ ▒  ░▓   ▒ ░    ▒▒   ▓▒█░ ▒▒▓  ▒ ░░ ▒░ ░
        ▒ ░ ░   ▒ ░ ░       ▒   ▒▒ ░ ░ ▒  ▒  ░ ░  ░
        ░   ░   ▒ ░ ░ ░     ░   ▒    ░ ░  ░    ░   
            ░     ░               ░  ░   ░       ░  ░
                                        ░        
                                        
            █▓▒­░⡷⠂ 𝒫𝓇𝑜𝒿𝑒𝒸𝓉 𝒷𝓎 𝐹𝒶𝒹𝒮𝑒𝒸 𝐿𝒶𝒷 ⠐⢾░▒▓█
"@

    Write-Host $bannerTop -ForegroundColor Red

    # Manually color each part of the box
    Write-Host "                 ┌─────── Author ─────────┐" -ForegroundColor Red
    Write-Host -NoNewline "                 │         " -ForegroundColor Red
    Write-Host -NoNewline "𝓕𝓪𝓭𝓮𝓭" -ForegroundColor Blue
    Write-Host "          │" -ForegroundColor Red

    Write-Host -NoNewline "                 │  " -ForegroundColor Red
    Write-Host -NoNewline "discord.gg/kvAZvdkuuN" -ForegroundColor Cyan
    Write-Host " │" -ForegroundColor Red

    Write-Host "                 └────────────────────────┘" -ForegroundColor Red

    Write-Host ""
}

    
    # Display the main menu
    [string] ShowMainMenu() {
        Write-Host "╭──📡 WIFADE ──────────────────────────────────────╮" -ForegroundColor $this.ColorScheme.Border
        Write-Host "│                    MAIN MENU                     │" -ForegroundColor $this.ColorScheme.Border
        Write-Host "╰──────────────────────────────────────────────────╯" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        Write-Host "╭─ 📜 Available Options" -ForegroundColor $this.ColorScheme.Border
        
        # Calculate the maximum key length for proper padding
        $maxKeyLength = ($this.MenuOptions.Main | ForEach-Object { $_.Key.Length } | Measure-Object -Maximum).Maximum
        $paddingLength = $maxKeyLength + 1  # Add some extra space
        
        foreach ($option in $this.MenuOptions.Main) {
            $keyColor = $this.ColorScheme.Highlight
            $textColor = $this.ColorScheme.Secondary
            Write-Host "│ → " -ForegroundColor $this.ColorScheme.Border -NoNewline
            Write-Host ("{0,-$paddingLength}" -f "$($option.Key)") -ForegroundColor $keyColor -NoNewline
            Write-Host ": " -ForegroundColor $this.ColorScheme.Border -NoNewline
            Write-Host "$($option.Text)" -ForegroundColor $textColor
        }
        
        Write-Host "╰──────────────────────────────────────" -ForegroundColor $this.ColorScheme.Border
        Write-Host "Enter option:" -ForegroundColor $this.ColorScheme.Info
        Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
        
        return Read-Host
    }
    
    # Display attack mode menu
    [string] ShowAttackModeMenu() {
        $this.ClearScreen()
        $this.ShowBanner()
        
        Write-Host "╭──💀 ATTACK MODE ─────────────────────────────────╮" -ForegroundColor $this.ColorScheme.Border
        Write-Host "│            WI-FI BRUTE FORCE OPTIONS             │" -ForegroundColor $this.ColorScheme.Border
        Write-Host "╰──────────────────────────────────────────────────╯" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        # Add descriptive text
        Write-Host "Select a password source for Wi-Fi brute force attack:" -ForegroundColor $this.ColorScheme.Info
        Write-Host "Both options will attempt to brute force the selected Wi-Fi network using passwords" -ForegroundColor $this.ColorScheme.Secondary
        Write-Host "from either the built-in wordlist or your custom password file." -ForegroundColor $this.ColorScheme.Secondary
        Write-Host ""
        
        Write-Host "╭─ 🔑 Password Sources" -ForegroundColor $this.ColorScheme.Border
        
        # Calculate the maximum key length for proper padding
        $maxKeyLength = ($this.MenuOptions.AttackMode | ForEach-Object { $_.Key.Length } | Measure-Object -Maximum).Maximum
        $paddingLength = $maxKeyLength + 2  # Add some extra space
        
        foreach ($option in $this.MenuOptions.AttackMode) {
            $keyColor = $this.ColorScheme.Highlight
            $textColor = $this.ColorScheme.Secondary
            Write-Host "│ → " -ForegroundColor $this.ColorScheme.Border -NoNewline
            Write-Host ("{0,-$paddingLength}" -f "$($option.Key)") -ForegroundColor $keyColor -NoNewline
            Write-Host ": " -ForegroundColor $this.ColorScheme.Border -NoNewline
            Write-Host "$($option.Text)" -ForegroundColor $textColor
        }
        
        Write-Host "╰──────────────────────────────────────" -ForegroundColor $this.ColorScheme.Border
        Write-Host "Enter option:" -ForegroundColor $this.ColorScheme.Info
        Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
        
        return Read-Host
    }
    
    # Display settings menu
    [string] ShowSettingsMenu() {
        $this.ClearScreen()
        $this.ShowBanner()
        
        Write-Host "╭──⚙️  SETTINGS ───────────────────────────────────╮" -ForegroundColor $this.ColorScheme.Border
        Write-Host "│                    SETTINGS                      │" -ForegroundColor $this.ColorScheme.Border
        Write-Host "╰──────────────────────────────────────────────────╯" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        # Show current settings
        Write-Host "╭─ 🔧 Current Configuration" -ForegroundColor $this.ColorScheme.Border
        Write-Host "│ " -ForegroundColor $this.ColorScheme.Border -NoNewline
        Write-Host "Verbose Mode: " -ForegroundColor $this.ColorScheme.Info -NoNewline
        $verboseStatus = if ($this.VerboseMode) { "ON" } else { "OFF" }
        $verboseColor = if ($this.VerboseMode) { $this.ColorScheme.Success } else { $this.ColorScheme.Warning }
        Write-Host $verboseStatus -ForegroundColor $verboseColor
        Write-Host "╰──────────────────────────────────────" -ForegroundColor $this.ColorScheme.Border
        Write-Host ""
        
        Write-Host "╭─ ⚙️ Available Options" -ForegroundColor $this.ColorScheme.Border
        
        # Calculate the maximum key length for proper padding
        $maxKeyLength = ($this.MenuOptions.Settings | ForEach-Object { $_.Key.Length } | Measure-Object -Maximum).Maximum
        $paddingLength = $maxKeyLength + 2  # Add some extra space
        
        foreach ($option in $this.MenuOptions.Settings) {
            $keyColor = $this.ColorScheme.Highlight
            $textColor = $this.ColorScheme.Secondary
            Write-Host "│ → " -ForegroundColor $this.ColorScheme.Border -NoNewline
            Write-Host ("{0,-$paddingLength}" -f "$($option.Key)") -ForegroundColor $keyColor -NoNewline
            Write-Host ": " -ForegroundColor $this.ColorScheme.Border -NoNewline
            Write-Host "$($option.Text)" -ForegroundColor $textColor
        }
        
        Write-Host "╰──────────────────────────────────────" -ForegroundColor $this.ColorScheme.Border
        Write-Host "Enter option:" -ForegroundColor $this.ColorScheme.Info
        Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
        
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
    
    # Display verbose message (only if verbose mode is enabled)
    [void] ShowVerbose([string]$message) {
        if ($this.VerboseMode) {
            Write-Host "[VERBOSE] $message" -ForegroundColor $this.ColorScheme.Verbose
        }
    }
    
    # Display debug message (alias for ShowVerbose for backward compatibility)
    [void] ShowDebug([string]$message) {
        $this.ShowVerbose($message)
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
            Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
            $null = $consoleHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        catch {
            # Fallback to Read-Host if ReadKey is not available
            Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
            $null = Read-Host
        }
    }
    
    # Get user confirmation
    [bool] GetConfirmation([string]$message, [bool]$defaultYes = $false) {
        $prompt = if ($defaultYes) { " (Y/n)" } else { " (y/N)" }
        Write-Host "$message$prompt" -ForegroundColor $this.ColorScheme.Info
        Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
        
        $response = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $defaultYes
        }
        
        return $response -match '^[Yy]([Ee][Ss])?$'
    }
    
    # Get user input with validation
    [string] GetUserInput([string]$prompt, [string]$validationPattern = "", [string]$errorMessage = "Invalid input. Please try again.") {
        do {
            Write-Host $prompt -ForegroundColor $this.ColorScheme.Info
            Write-Host "❯ " -ForegroundColor $this.ColorScheme.Highlight -NoNewline
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
        Write-Host "╭─ 📶 Available Networks" -ForegroundColor $this.ColorScheme.Border
        Write-Host "│" -ForegroundColor $this.ColorScheme.Border
        
        # Table header
        Write-Host "│ " -NoNewline -ForegroundColor $this.ColorScheme.Border
        Write-Host "#  " -NoNewline -ForegroundColor $this.ColorScheme.Info
        Write-Host "SSID                     " -NoNewline -ForegroundColor $this.ColorScheme.Info
        Write-Host "Signal     " -NoNewline -ForegroundColor $this.ColorScheme.Info
        Write-Host "Encryption      " -NoNewline -ForegroundColor $this.ColorScheme.Info
        Write-Host "Status" -ForegroundColor $this.ColorScheme.Info
        
        # Table separator
        Write-Host "│ " -NoNewline -ForegroundColor $this.ColorScheme.Border
        Write-Host "─" -NoNewline -ForegroundColor $this.ColorScheme.Secondary
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor $this.ColorScheme.Secondary
        
        # Table content
        for ($i = 0; $i -lt $networks.Count; $i++) {
            $network = $networks[$i]
            $signalBar = $this.GetSignalStrengthBar($network.SignalStrength)
            $signalText = "$signalBar $($network.SignalStrength)%"
            
            $status = if ($network.IsConnectable) { "Available" } else { "Unavailable" }
            
            Write-Host "│ " -NoNewline -ForegroundColor $this.ColorScheme.Border
            Write-Host ("{0,-3}" -f ($i + 1)) -NoNewline -ForegroundColor $this.ColorScheme.Highlight
            Write-Host ("{0,-25}" -f $network.SSID) -NoNewline -ForegroundColor $this.ColorScheme.Secondary
            Write-Host ("{0,-10}" -f $signalText) -NoNewline -ForegroundColor $this.ColorScheme.Secondary
            Write-Host ("{0,-15}" -f $network.EncryptionType) -NoNewline -ForegroundColor $this.ColorScheme.Secondary
            Write-Host ("{0,-10}" -f $status) -ForegroundColor $this.ColorScheme.Secondary
        }
        
        # Table bottom border
        Write-Host "╰──────────────────────────────────────" -ForegroundColor $this.ColorScheme.Border
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
            Write-Verbose "Disposing UIManager resources..."
            
            # Reset console title
            try {
                $host = Get-Host
                $host.UI.RawUI.WindowTitle = "Windows PowerShell"
            }
            catch {
                # Ignore errors when resetting console title
            }
            
            $this.IsInitialized = $false
            Write-Verbose "UIManager disposed successfully"
        }
        catch {
            Write-Warning "Error during UIManager disposal: $($_.Exception.Message)"
        }
    }
}