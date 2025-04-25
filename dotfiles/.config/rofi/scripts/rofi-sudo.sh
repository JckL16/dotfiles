#!/bin/bash

# Function to execute sudo command in a terminal without blocking
run_sudo_command() {
    # Use setsid to detach the terminal from the parent process
    if command -v alacritty >/dev/null 2>&1; then
        setsid -f alacritty -e bash -c "sudo $1; echo; echo 'Press Enter to close'; read" >/dev/null 2>&1
    elif command -v kitty >/dev/null 2>&1; then
        setsid -f kitty bash -c "sudo $1; echo; echo 'Press Enter to close'; read" >/dev/null 2>&1
    elif command -v gnome-terminal >/dev/null 2>&1; then
        setsid -f gnome-terminal -- bash -c "sudo $1; echo; echo 'Press Enter to close'; read" >/dev/null 2>&1
    elif command -v xterm >/dev/null 2>&1; then
        setsid -f xterm -e bash -c "sudo $1; echo; echo 'Press Enter to close'; read" >/dev/null 2>&1
    else
        # Fallback
        i3-sensible-terminal -e bash -c "sudo $1; echo; echo 'Press Enter to close'; read"
    fi
}

# If argument provided, execute it
if [ "$1" ]; then
    run_sudo_command "$1"
    exit 0
fi

# Show list of common sudo commands
echo "pacman -Syu"
echo "systemctl restart NetworkManager"
echo "vim /etc/fstab"
echo "vim /etc/hosts"
echo "journalctl -xe"
echo "pacman -Rns"