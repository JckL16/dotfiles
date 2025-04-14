#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/steam-flatpak-install.log"

# ANSI color codes for better formatting
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Clear previous log file if it exists
if [[ -f "$LOG_FILE" ]]; then
    rm "$LOG_FILE"
    echo -e "${BLUE}Cleared previous log file${RESET}" >> "$LOG_FILE"
fi

# Function to log messages
log_message() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to handle commands and their output
run_command() {
    local cmd="$1"
    local desc="$2"
    local fatal="${3:-false}"  # Whether failure is fatal
    
    echo -ne "${BLUE}$desc... ${RESET}"
    log_message "COMMAND: $cmd" >> "$LOG_FILE"
    
    # Run the command and capture output
    output=$(eval "$cmd" 2>&1)
    status=$?
    
    # Log the output regardless of success/failure
    echo "$output" >> "$LOG_FILE"
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ OK${RESET}"
        log_message "STATUS: Success" >> "$LOG_FILE"
        return 0
    else
        echo -e "${RED}✗ ERROR${RESET}"
        log_message "STATUS: Failed (exit code $status)" >> "$LOG_FILE"
        
        if [ "$fatal" = "true" ]; then
            echo -e "\n${RED}${BOLD}Fatal error: $desc failed. Check $LOG_FILE for details.${RESET}"
            log_message "FATAL ERROR: Exiting script due to previous error" >> "$LOG_FILE"
            exit 1
        fi
        
        return 1
    fi
}

# Function to install Flatpak if not already installed
install_flatpak() {
    echo -e "\n${BOLD}${BLUE}[1/5] Checking Flatpak installation${RESET}"
    
    if ! command -v flatpak &> /dev/null; then
        run_command "sudo pacman -S --noconfirm flatpak" "Installing Flatpak" true
    else
        echo -e "${GREEN}Flatpak is already installed.${RESET}"
    fi
}

# Function to add the Flathub repository for Steam
add_flathub_repo() {
    echo -e "\n${BOLD}${BLUE}[2/5] Adding Flathub repository${RESET}"
    
    run_command "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo" "Adding Flathub repository" true
}

# Function to install Steam via Flatpak
install_steam_flatpak() {
    echo -e "\n${BOLD}${BLUE}[3/5] Installing Steam via Flatpak${RESET}"
    
    run_command "flatpak install --assumeyes flathub com.valvesoftware.Steam" "Installing Steam from Flathub" true
}

# Function to ensure Flatpak permissions for Steam
set_flatpak_permissions() {
    echo -e "\n${BOLD}${BLUE}[4/5] Setting Flatpak permissions for Steam${RESET}"
    
    # Grant necessary access to Steam's Flatpak for devices and sound
    run_command "flatpak override --user --device=dri com.valvesoftware.Steam" "Granting access to video devices" false
    run_command "flatpak override --user --device=audio com.valvesoftware.Steam" "Granting access to audio devices" false
    run_command "flatpak override --user --filesystem=home com.valvesoftware.Steam" "Granting access to home directory" false
    run_command "flatpak override --user --share=network com.valvesoftware.Steam" "Granting network access" false
    run_command "flatpak override --user --device=all com.valvesoftware.Steam" "Granting access to all devices (for Steam's requirements)" false
}

# Function to run Steam after installation
run_steam() {
    echo -e "\n${BOLD}${BLUE}[5/5] Running Steam${RESET}"
    
    run_command "flatpak run com.valvesoftware.Steam" "Running Steam" false
}

# Print header
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     Steam Flatpak Installation       ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
log_message "Starting Flatpak Steam installation" >> "$LOG_FILE"

# Step 1: Install Flatpak if not installed
install_flatpak

# Step 2: Add Flathub repository
add_flathub_repo

# Step 3: Install Steam via Flatpak
install_steam_flatpak

# Step 4: Set Flatpak permissions for Steam
set_flatpak_permissions

# Step 5: Run Steam
run_steam

# Final status
echo
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     Installation Complete!           ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
echo -e "${BLUE}• Steam installed via Flatpak from Flathub${RESET}"
echo -e "${BLUE}• Necessary permissions granted for devices and audio${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}Enjoy gaming on Linux!${RESET}"
echo

log_message "Steam Flatpak installation completed successfully" >> "$LOG_FILE"
