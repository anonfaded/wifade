# Wifade

<div align="center">

**A powerful, command-line driven Wi-Fi management and security testing tool for Windows, built with PowerShell.**

![Wifade Screenshot](https://raw.githubusercontent.com/anonfaded/wifade/main/img/1.jpg)

</div>

---

## 🚀 Features

Wifade provides a comprehensive suite of tools for managing Wi-Fi connections directly from your terminal through an interactive UI or quick command-line flags.

*   **👨‍💻 Interactive TUI:** A polished, menu-driven interface for easy navigation and operation.
*   **📶 Wi-Fi Management:**
    *   **Scan:** Discover and list all available Wi-Fi networks with details like signal strength, encryption type, and status.
    *   **Connect:** Securely connect to any Wi-Fi network, including open and password-protected ones.
    *   **Status:** Get a detailed report of your current connection, including private/public IP, gateway, DNS, MAC address, and link speed.
    *   **Control:** Disconnect from networks or restart your Wi-Fi adapter with simple commands.
*   **🔑 Password Security Testing:**
    *   **Dictionary Attack:** Test network password strength using a built-in wordlist of over 4,700 common passwords.
    *   **Custom Wordlists:** Select and use your own custom password files for targeted testing.
*   **⚡️ Quick CLI Actions:** Bypass the interactive UI for instant results. Use flags to get your IP, scan networks, check status, and more.
*   **🪟 Windows Integration:**
    *   Installs easily with a setup wizard.
    *   Automatically added to your system's `PATH`, so you can run `wifade` from any terminal (`cmd`, `PowerShell`, `Windows Terminal`).
    *   Checks for updates automatically on startup.
*   **⚠️ Ethical Use Focus:** Includes a mandatory disclaimer and human verification step to ensure responsible use of its security testing features.

## 📦 Installation

1.  Go to the [**GitHub Releases**](https://github.com/anonfaded/wifade/releases) page.
2.  Download the latest `WifadeSetup-X.X.exe` installer.
3.  Run the installer. It requires administrator privileges to add `wifade` to your system's PATH.
4.  Once installed, you can open any terminal and run the `wifade` command.

## 🖥️ Usage

Wifade can be launched in two modes: Interactive Mode for a full user interface, or CLI Mode for quick, direct commands.

### Interactive Mode

Simply run the command without any parameters to launch the full interactive interface.

```sh
wifade
```

### CLI Mode (Quick Actions)

Use flags to perform actions instantly without entering the interactive menu. This is perfect for scripting or quick checks.

```bash
# Display comprehensive Wi-Fi status
wifade -Status

# Scan for and list available networks
wifade -Scan

# Get your private and public IP addresses
wifade -IP
wifade -PublicIP

# Connect to a network directly
# (Use quotes if the SSID has spaces)
wifade "My Network Name" mypassword123
wifade -Connect "My Network Name" mypassword123

# See a quick reference of all commands
wifade -List

# Show detailed help documentation
wifade -Help
```

## 💀 Attack Mode

Wifade's password security testing features are accessible from the interactive menu.

1.  **Dictionary Attack:** Uses the built-in `probable-v2-wpa-top4800.txt` wordlist. This file contains over 4,700 of the most common WPA passwords.
2.  **Custom Password File:** Allows you to use your own wordlist. You can select a `.txt` file using the file picker dialog.

Upon entering Attack Mode for the first time, you will be required to accept an **ethical usage disclaimer**.

## ⚖️ Disclaimer

This tool is intended for **educational purposes and ethical security testing only**.

*   Do not test networks that you do not own or have explicit, written permission to test.
*   Unauthorized access to computer networks is illegal. The user is solely responsible for their actions.
*   The developers of Wifade are not responsible for any misuse of this tool.

## 🛠️ Building from Source

If you want to build the project yourself, follow these steps:

1.  Ensure you have **PowerShell 7+** installed.
2.  Install the required `ps2exe` module:
    ```powershell
    Install-Module -Name ps2exe -Force
    ```
3.  Run the build script from a PowerShell 7 terminal with **Administrator privileges**:
    ```powershell
    ./Build-Wifade.ps1
    ```
4.  The compiled executables (`wifade.exe`, `WifadeCore.exe`) and other assets will be placed in the `build/` directory.

## 🤝 Contributing

Contributions are welcome! If you're interested in improving **Wifade**, feel free to fork the repository, make your changes, and submit a pull request. If you find any bugs, please open an issue.
