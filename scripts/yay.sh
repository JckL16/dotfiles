#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/yay.sh.log"

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
    local fatal="${3:-false}"  # Whether failure is fatal
    
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
echo -e "${BOLD}${BLUE}=== Yay AUR Helper Installation Utility ===${RESET}"
log_message "Starting Yay AUR helper installation"

# Step 1: Install dependencies
echo -e "\n${BOLD}${BLUE}[1/5] Installing dependencies${RESET}"
run_command "sudo pacman -S --needed --noconfirm base-devel git" "Installing base-devel and git" true

# Step 2: Create temporary directory
echo -e "\n${BOLD}${BLUE}[2/5] Creating temporary directory${RESET}"
TEMP_DIR=$(mktemp -d)
log_message "Created temporary directory: $TEMP_DIR"
echo -e "${GREEN}✓ Created temporary directory: $TEMP_DIR${RESET}"

# Step 3: Clone yay repository
echo -e "\n${BOLD}${BLUE}[3/5] Cloning yay repository${RESET}"
run_command "git clone https://aur.archlinux.org/yay.git $TEMP_DIR/yay" "Cloning yay from AUR" true

# Step 4: Build and install yay
echo -e "\n${BOLD}${BLUE}[4/5] Building and installing yay${RESET}"
run_command "cd $TEMP_DIR/yay && makepkg -si --noconfirm" "Building and installing yay package" true

# Step 5: Clean up temporary files
echo -e "\n${BOLD}${BLUE}[5/5] Cleaning up temporary files${RESET}"
run_command "rm -rf $TEMP_DIR" "Removing temporary directory" false

# Check if yay is installed correctly
echo -e "\n${BOLD}${BLUE}Verifying installation${RESET}"
if command -v yay &> /dev/null; then
    YAY_VERSION=$(yay --version | head -n 1)
    echo -e "${GREEN}✓ Yay installed successfully: $YAY_VERSION${RESET}"
    log_message "Yay installed successfully: $YAY_VERSION"
else
    echo -e "${RED}${BOLD}ERROR: Yay installation could not be verified${RESET}"
    log_message "ERROR: Yay installation could not be verified"
    exit 1
fi

# Final status
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• Yay AUR helper installed${RESET}"
echo -e "${BLUE}• Dependencies configured${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}Setup complete!${RESET}"
echo -e "${YELLOW}Usage example: yay -S package-name${RESET}"
echo -e "${YELLOW}To search for packages: yay -Ss search-term${RESET}"
echo

log_message "Yay installation completed successfully"