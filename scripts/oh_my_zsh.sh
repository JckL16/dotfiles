#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/oh_my_zsh.sh.log"

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
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
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
echo -e "${BOLD}${BLUE}=== Oh My Zsh Setup Utility ===${RESET}"
log_message "Starting Oh My Zsh, plugins, and Starship setup"

# Step 1: Install dependencies
echo -e "\n${BOLD}${BLUE}[1/7] Installing dependencies${RESET}"
run_command "sudo pacman -S --noconfirm zsh git curl fzf" "Installing Zsh, Git, Curl, and fzf" true

# Step 2: Install Oh My Zsh
echo -e "\n${BOLD}${BLUE}[2/7] Installing Oh My Zsh${RESET}"
# Export ZSH variable to prevent install.sh from changing shell automatically
export RUNZSH=no
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    run_command "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"" "Installing Oh My Zsh" true
else
    echo -e "${YELLOW}⚠️  Oh My Zsh already installed - skipping${RESET}"
    log_message "Oh My Zsh already installed - skipping"
fi

# Define ZSH_CUSTOM for plugins (in case it wasn't set by Oh My Zsh installer)
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Step 3: Install Zsh Autosuggestions
echo -e "\n${BOLD}${BLUE}[3/7] Installing Zsh Autosuggestions${RESET}"
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    run_command "git clone https://github.com/zsh-users/zsh-autosuggestions.git \"$ZSH_CUSTOM/plugins/zsh-autosuggestions\"" "Installing Zsh Autosuggestions" true
else
    echo -e "${YELLOW}⚠️  Zsh Autosuggestions already installed - skipping${RESET}"
    log_message "Zsh Autosuggestions already installed - skipping"
fi

# Step 4: Install Zsh Syntax Highlighting
echo -e "\n${BOLD}${BLUE}[4/7] Installing Zsh Syntax Highlighting${RESET}"
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    run_command "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \"$ZSH_CUSTOM/plugins/zsh-syntax-highlighting\"" "Installing Zsh Syntax Highlighting" true
else
    echo -e "${YELLOW}⚠️  Zsh Syntax Highlighting already installed - skipping${RESET}"
    log_message "Zsh Syntax Highlighting already installed - skipping"
fi

# Step 5: Install Starship prompt
echo -e "\n${BOLD}${BLUE}[5/7] Installing Starship prompt${RESET}"
run_command "sh -c \"\$(curl -fsSL https://starship.rs/install.sh)\" -- -y" "Installing Starship" true

# Step 6: Skipping Zsh config
echo -e "\n${BOLD}${BLUE}[6/7] Skipping .zshrc modification${RESET}"
echo -e "${YELLOW}⚠️  .zshrc is managed via dotfiles – skipping changes${RESET}"
log_message "Skipped .zshrc modifications – assumed managed via symlinks/dotfiles"

# Step 7: Set Zsh as default shell
echo -e "\n${BOLD}${BLUE}[7/7] Setting Zsh as default shell${RESET}"
# Use the full path to zsh instead of relying on which
ZSH_PATH="/usr/bin/zsh"
# Verify that this path exists before trying to use it
if [[ -f "$ZSH_PATH" ]]; then
    run_command "sudo chsh -s $ZSH_PATH $(whoami)" "Setting Zsh as default shell" true
else
    # Fall back to which zsh but run it without sudo to get the user-accessible path
    ZSH_PATH=$(which zsh)
    run_command "sudo chsh -s $ZSH_PATH $(whoami)" "Setting Zsh as default shell" true
fi

# Final status
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• Oh My Zsh installed${RESET}"
echo -e "${BLUE}• Plugins installed: ${BOLD}zsh-autosuggestions, zsh-syntax-highlighting, fzf${RESET}"
echo -e "${BLUE}• Starship prompt installed${RESET}"
echo -e "${BLUE}• Zsh set as default shell${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}Setup complete!${RESET}"
echo -e "${YELLOW}Note: You need to restart your terminal or run 'source ~/.zshrc' to apply changes.${RESET}"
echo

log_message "Oh My Zsh setup completed successfully"
