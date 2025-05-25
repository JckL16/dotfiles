#!/bin/bash

# WiFi Rofi Selector Script

separator="──────────────"

# Get the actual WiFi device name
get_wifi_device() {
    nmcli -t -f device,type dev status | grep wifi | head -1 | cut -d':' -f1
}

# Get WiFi status (enabled or disabled)
get_wifi_status() {
    nmcli radio wifi | grep -q "enabled" && echo "enabled" || echo "disabled"
}

# Toggle WiFi on/off
toggle_wifi() {
    if [ "$(get_wifi_status)" = "enabled" ]; then
        nmcli radio wifi off
    else
        nmcli radio wifi on
        sleep 1
    fi
}

# Get currently connected SSID
get_current_connection() {
    nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2
}

# Connect to a network (with or without password)
connect_to_network() {
    local ssid="$1"

    # Check for existing connection profile
    if nmcli con show | grep -Fxq "$ssid"; then
        if nmcli con up "$ssid" >/dev/null 2>&1; then
            notify-send "WiFi" "Connected to $ssid"
            return
        fi
    fi

    # Determine if the network is secured
    local security
    security=$(nmcli -t -f ssid,security dev wifi list | grep "^$ssid:" | cut -d':' -f2)

    if [ -n "$security" ] && [ "$security" != "--" ]; then
        # Prompt for password
        password=$(rofi -dmenu -password -p "Password for $ssid")
        if [ -z "$password" ]; then
            rofi -e "No password entered"
            exit 1
        fi

        if nmcli dev wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
            notify-send "WiFi" "Connected to $ssid"
        else
            rofi -e "Failed to connect to $ssid"
        fi
    else
        # Open network
        if nmcli dev wifi connect "$ssid" >/dev/null 2>&1; then
            notify-send "WiFi" "Connected to $ssid"
        else
            rofi -e "Failed to connect to $ssid"
        fi
    fi
}

# Main function to show the WiFi menu
show_networks() {
    nmcli dev wifi rescan >/dev/null 2>&1 &

    local current
    current=$(get_current_connection)

    local menu_options=""

    if [ "$(get_wifi_status)" = "enabled" ]; then
        menu_options="Turn Off WiFi\n"
    else
        menu_options="Turn On WiFi\n"
    fi

    menu_options+="$separator\n"

    if [ -n "$current" ]; then
        menu_options+="Connected: $current\nDisconnect\n$separator\n"
    fi

    local networks
    networks=$(nmcli -t -f ssid,signal,security dev wifi list | grep -v '^--' | sort -t':' -k2 -nr)

    while IFS=':' read -r ssid signal security; do
        if [ -n "$ssid" ] && [ "$ssid" != "$current" ]; then
            local security_text="[OPEN]"
            if [ -n "$security" ] && [ "$security" != "--" ]; then
                security_text="[SECURE]"
            fi
            menu_options+="$ssid ($signal%) $security_text\n"
        fi
    done <<< "$networks"

    chosen=$(echo -e "$menu_options" | rofi -dmenu -i -p "WiFi Networks" -theme-str 'listview { lines: 12; }')

    case "$chosen" in
        "Turn Off WiFi"|"Turn On WiFi")
            toggle_wifi
            ;;
        "Disconnect")
            local wifi_device
            wifi_device=$(get_wifi_device)
            if [ -n "$wifi_device" ]; then
                nmcli dev disconnect "$wifi_device"
                notify-send "WiFi" "Disconnected from $current"
            fi
            ;;
        "")
            exit 0
            ;;
        *)
            local ssid
            ssid=$(echo "$chosen" | sed 's/ ([0-9]*%) \[.*\]$//')
            connect_to_network "$ssid"
            ;;
    esac
}

# Start
if [ "$(get_wifi_status)" = "disabled" ]; then
    choice=$(echo -e "Enable WiFi\nCancel" | rofi -dmenu -p "WiFi is disabled")
    [ "$choice" = "Enable WiFi" ] && toggle_wifi && show_networks
else
    show_networks
fi
