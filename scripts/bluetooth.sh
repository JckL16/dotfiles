#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/bluetooth.sh.log"

# ANSI color codes for better formatting
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
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
    echo -e "[$timestamp] $1" >> "$LOG_FILE"
}

# Function to handle commands and their output
run_command() {
    local cmd="$1"
    local desc="$2"
    
    echo -ne "${BLUE}$desc... ${RESET}"
    log_message "COMMAND: $cmd"
    
    # Run the command and capture output
    output=$(eval "$cmd" 2>&1)
    status=$?
    
    # Log the output regardless of success/failure
    log_message "OUTPUT:\n$output"
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ OK${RESET}"
        log_message "STATUS: Success"
        return 0
    else
        echo -e "${RED}✗ ERROR${RESET}"
        log_message "STATUS: Failed (exit code $status)"
        return 1
    fi
}

# Print header
echo -e "${BOLD}${BLUE}=== Bluetooth Setup Utility ===${RESET}"
log_message "Starting Bluetooth setup"

# Step 1: Install dependencies
echo -e "\n${BOLD}${BLUE}[1/2] Installing Bluetooth dependencies${RESET}"
dependencies=("bluez" "bluez-utils" "blueman")

for pkg in "${dependencies[@]}"; do
    if run_command "sudo pacman -S $pkg --noconfirm" "Installing $pkg"; then
        echo -e "   ${GREEN}$pkg installed successfully${RESET}"
    else
        echo -e "   ${RED}Failed to install $pkg. Check $LOG_FILE for details${RESET}"
    fi
done

# Step 2: Configure services
echo -e "\n${BOLD}${BLUE}[2/2] Configuring Bluetooth services${RESET}"

run_command "sudo systemctl enable bluetooth" "Enabling Bluetooth service"
run_command "sudo systemctl start bluetooth" "Starting Bluetooth service"

# Final status
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• Bluetooth packages installed${RESET}"
echo -e "${BLUE}• Bluetooth service enabled and started${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}To use the Bluetooth GUI, run:${RESET} blueman-manager"
echo

log_message "Bluetooth setup completed successfully"