# Project Structure

## Overview
The Wifade project follows a simple, flat structure with platform-specific scripts and shared configuration files.

## Directory Layout
```
wifade/
├── img/                    # Images for documentation
│   ├── 1.jpg               # Screenshot of the tool in action
│   └── logo.png            # Project logo
├── linux-script.sh         # Linux implementation
├── macOS-script.sh         # macOS implementation
├── passwords.txt           # Default password list
├── README.md               # Project documentation
└── ssid.txt                # Default SSID list
```

## File Descriptions

### Scripts
- `linux-script.sh`: The Linux implementation using nmcli and xdotool
- `macOS-script.sh`: The macOS implementation using networksetup

### Configuration
- `passwords.txt`: Contains a list of passwords to try (one per line)
- `ssid.txt`: Contains a list of target SSIDs (one per line)

### Documentation
- `README.md`: Project documentation, usage instructions, and disclaimer
- `img/1.jpg`: Screenshot showing the tool in operation
- `img/logo.png`: Project logo image

## Conventions
- Script files are named according to their target platform
- Configuration files use simple text format with one entry per line
- Documentation follows standard Markdown conventions
- Images are stored in a dedicated directory