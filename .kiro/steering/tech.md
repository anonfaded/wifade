# Technical Stack

## Environment
- Bash scripting environment
- Linux and macOS compatible

## Dependencies
### Linux Version
- `nmcli` - Network Manager command-line interface
- `xdotool` - X11 automation tool (required for dismissing authentication dialogs)

### macOS Version
- `networksetup` - Built-in macOS network configuration utility

## Build System
- No build system required - scripts are executed directly

## Common Commands

### Setup
```bash
# Make scripts executable
chmod +x linux-script.sh
chmod +x macOS-script.sh
```

### Execution
#### Linux
```bash
# Run with default configuration
./linux-script.sh

# Run with custom SSID file
./linux-script.sh -s /path/to/ssid_file.txt

# Run with custom password file
./linux-script.sh -w /path/to/password_file.txt

# Display help
./linux-script.sh -h
```

#### macOS
```bash
# Run with default configuration
./macOS-script.sh
```
Note: The macOS version requires manual configuration of SSIDs and passwords within the script.

## Configuration Files
- `ssid.txt` - Contains target Wi-Fi network names (one per line)
- `passwords.txt` - Contains passwords to try (one per line)

## Code Style
- Bash scripting conventions
- Color-coded terminal output using ANSI escape sequences
- Function-based organization for reusable components