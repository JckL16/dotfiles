#!/usr/bin/env bash
# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/ly.sh.log"

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
    local fatal="${3:-false}" # Whether failure is fatal
    
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
        
        if [ "$fatal" = "true" ]; then
            echo -e "\n${RED}${BOLD}Fatal error: $desc failed. Check $LOG_FILE for details.${RESET}"
            log_message "FATAL ERROR: Exiting script due to previous error"
            exit 1
        fi
        
        return 1
    fi
}

# Print header
echo -e "${BOLD}${BLUE}=== LY Display Manager Setup ===${RESET}"
log_message "Starting LY Display Manager setup"

# Step 1: Install LY
echo -e "\n${BOLD}${BLUE}[1/2] Installing LY Display Manager${RESET}"
run_command "sudo pacman -S ly --noconfirm" "Installing LY Display Manager" true

# Step 2: Configure services (but don't start)
echo -e "\n${BOLD}${BLUE}[2/2] Configuring LY service${RESET}"
run_command "sudo systemctl enable ly" "Enabling LY service to start on boot" true

# Final status
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• LY Display Manager installed${RESET}"
echo -e "${BLUE}• LY service enabled for boot${RESET}"
echo -e "${YELLOW}• LY service NOT started (will start on next boot)${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo

echo -e "${GREEN}${BOLD}LY has been successfully installed and configured!${RESET}"
echo -e "${YELLOW}LY will start automatically on next boot. Current session preserved.${RESET}"
echo -e "${BLUE}To manually start LY later, use: ${BOLD}sudo systemctl start ly${RESET}"
echo

log_message "LY Display Manager setup completed successfully"