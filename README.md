<div align="center">

# Wifade

**An automated bash script for Wi-Fi password brute-forcing, designed to seamlessly unlock network secrets across linux and macOS**

[![GitHub all releases](https://img.shields.io/github/downloads/anonfaded/wifade/total?label=Downloads&logo=github)](https://github.com/anonfaded/wifade/releases/)

</div>

---

## 📱 Screenshot

<div align="center">
<img src="/img/1.jpg" style="width: 700px; height: auto;" >
</div>

## ⬇️ Download

Download the linux and macOS scripts from the [releases page](https://github.com/anonfaded/wifade/releases/tag/v1.0).


## Features

- Automated password testing on multiple SSIDs.
- Simple configuration of target SSIDs and passwords.
- (Future versions may include password dictionary support.)

## How It Works

The script systematically attempts to connect to Wi-Fi networks using a list of passwords. For Linux, it employs the escape key to dismiss any authentication dialogs, ensuring uninterrupted operation.

## Getting Started
### Prerequisites

- A Linux or macOS system with bash support.
- Necessary network permissions for ethical testing.



### Usage

#### Installation

### Prerequisites

Before using Wifade, ensure you have the necessary package installed to enable the escape key functionality for dismissing authentication dialogs on Linux:

    Install xdotool for simulating key presses:

```bash
    sudo apt-get install xdotool
```

After installing xdotool, follow the installation instructions below for Wifade to set up the script on your system.

Clone the repository:

```
git clone https://github.com/anonfaded/wifade.git
```

Navigate to the WiFade directory:

```
cd wifade
```

Make the script executable:

```bash
chmod +x linux-script.sh
```

Run the script from your terminal:

1. For linux version of script:
```bash
./linux-script.sh
```
2. For macOS version of script:
```bash
./macOS-script.sh
```

### Configuration

Edit the script to specify your target Wi-Fi networks and passwords:

1. SSIDs: Locate the SSIDS array and add the SSIDs(WiFi names) of the networks you wish to test.

```bash
SSIDS=("YourSSID1" "YourSSID2" "YourSSID3")
```

2. Passwords: In the PASSWORDS array, list all the passwords you want to attempt.

```bash
PASSWORDS=("password1" "password2" "password3")
```

Please ensure you only edit these sections to avoid unexpected script behavior.

## Script Execution

Once initiated, the script begins its operation. Simply observe the terminal output; if the correct password is discovered, it will be highlighted in color alongside a success message.

## Contributions

Contributions are welcome! If you're interested in improving **Wifade** or adding new features, feel free to fork the repository, make your changes, and submit a pull request. 

### Issues and macOS Testing

If you encounter any issues while using this script, especially with macOS, as it has not been extensively tested on this platform, please don't hesitate to open an issue on GitHub. When reporting, kindly include detailed information about the problem and the context in which it occurs to help us make improvements. Your feedback and contributions are highly appreciated as they help enhance the tool's reliability and functionality across different environments.

## Disclaimer

This tool is intended for educational purposes and ethical security testing only. Always ensure you have explicit permission to test network security to avoid legal repercussions.
