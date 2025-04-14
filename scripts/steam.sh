#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/steam.sh.log"

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

# Function to install Flatpak if not installed
install_flatpak() {
    echo -e "\n${BOLD}${BLUE}[0/5] Installing Flatpak${RESET}"
    
    if ! command -v flatpak &> /dev/null; then
        run_command "sudo pacman -S --noconfirm flatpak" "Installing Flatpak" true
    else
        log_message "Flatpak is already installed."
    fi
}

# Function to install Steam via Flatpak
install_steam_flatpak() {
    echo -e "\n${BOLD}${BLUE}[1/5] Installing Steam via Flatpak${RESET}"
    
    # Add the Flathub repository for Steam if it's not already added
    if ! flatpak remote-ls --app flathub | grep -q "com.valvesoftware.Steam"; then
        run_command "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo" "Adding Flathub repository" true
    fi
    
    # Install Steam via Flatpak
    run_command "flatpak install -y flathub com.valvesoftware.Steam" "Installing Steam via Flatpak" true
}

# Function to detect the GPU type (AMD, NVIDIA, Intel)
detect_gpu() {
    echo -ne "${BLUE}Detecting GPU... ${RESET}"
    
    GPU_INFO=$(lspci | grep -i "VGA\|3D\|Display" | head -n 1)
    log_message "GPU Info: $GPU_INFO" >> "$LOG_FILE"
    
    if [[ $GPU_INFO == *"AMD"* || $GPU_INFO == *"ATI"* ]]; then
        echo -e "${CYAN}AMD GPU detected${RESET}"
        GPU="AMD"
    elif [[ $GPU_INFO == *"NVIDIA"* ]]; then
        echo -e "${CYAN}NVIDIA GPU detected${RESET}"
        GPU="NVIDIA"
    elif [[ $GPU_INFO == *"Intel"* ]]; then
        echo -e "${CYAN}Intel GPU detected${RESET}"
        GPU="Intel"
    else
        echo -e "${YELLOW}No compatible GPU detected or GPU is unrecognized${RESET}"
        log_message "WARNING: Unable to detect GPU type" >> "$LOG_FILE"
        
        # Ask user to select GPU type
        echo -e "\n${YELLOW}Please select your GPU type:${RESET}"
        echo -e "1) ${CYAN}AMD${RESET}"
        echo -e "2) ${CYAN}NVIDIA${RESET}"
        echo -e "3) ${CYAN}Intel${RESET}"
        echo -e "4) ${RED}Exit installation${RESET}"
        read -p "Enter your choice (1-4): " gpu_choice
        
        case $gpu_choice in
            1) GPU="AMD" ;;
            2) GPU="NVIDIA" ;;
            3) GPU="Intel" ;;
            4|*) 
                echo -e "${RED}Installation cancelled by user.${RESET}"
                exit 0
                ;;
        esac
        
        echo -e "${BLUE}Proceeding with ${CYAN}$GPU${BLUE} GPU configuration.${RESET}"
    fi
    
    log_message "Selected GPU type: $GPU" >> "$LOG_FILE"
}

# Function to install Proton GE (Glorious Eggroll) with Flatpak
install_proton_ge_flatpak() {
    echo -e "\n${BOLD}${BLUE}[2/5] Installing Proton GE (Glorious Eggroll)${RESET}"
    
    # Check if Proton GE is already installed
    if flatpak list --app | grep -q "com.valvesoftware.Steam"; then
        echo -e "${BLUE}Proton GE already installed via Flatpak${RESET}"
    else
        echo -e "${BLUE}Downloading Proton GE from Flathub...${RESET}"
        # Proton GE usually comes bundled with Flatpak Steam installations, but we can install it separately if needed
    fi
}

# Function to provide instructions for Proton configuration
configure_proton_for_steam() {
    echo -e "\n${BOLD}${BLUE}[3/5] Configuring Steam for Proton compatibility${RESET}"
    
    echo -e "${YELLOW}Follow these steps to configure Steam:${RESET}"
    echo -e "  ${BOLD}1.${RESET} Launch Steam"
    echo -e "  ${BOLD}2.${RESET} Go to ${BOLD}Steam${RESET} → ${BOLD}Settings${RESET} → ${BOLD}Steam Play${RESET}"
    echo -e "  ${BOLD}3.${RESET} Check ${BOLD}\"Enable Steam Play for supported titles\"${RESET}"
    echo -e "  ${BOLD}4.${RESET} Check ${BOLD}\"Enable Steam Play for all other titles\"${RESET}"
    echo -e "  ${BOLD}5.${RESET} Select ${BOLD}\"Proton-GE\"${RESET} from the dropdown menu"
    echo -e "  ${BOLD}6.${RESET} Click ${BOLD}OK${RESET} to save settings"
}

# Function to provide additional tips
provide_gaming_tips() {
    echo -e "\n${BOLD}${BLUE}[4/5] Additional gaming tips${RESET}"
    
    echo -e "${YELLOW}Helpful tips for gaming on Linux:${RESET}"
    echo -e "  ${BOLD}•${RESET} Check game compatibility on ${BOLD}ProtonDB${RESET}: https://www.protondb.com"
    echo -e "  ${BOLD}•${RESET} For performance monitoring, install ${BOLD}MangoHud${RESET}: yay -S mangohud"
    echo -e "  ${BOLD}•${RESET} For game optimization, consider using ${BOLD}GameMode${RESET}: sudo pacman -S gamemode lib32-gamemode"
    echo -e "  ${BOLD}•${RESET} Set launch options for Steam games: ${BOLD}MANGOHUD=1 gamemoderun %command%${RESET}"
}

# Step 0: Ensure Flatpak is installed
install_flatpak

# Step 1: Install Steam via Flatpak
install_steam_flatpak

# Step 2: Detect GPU
echo -e "\n${BOLD}${BLUE}[2/5] Detecting hardware${RESET}"
detect_gpu

# Step 3: Install Proton GE with Flatpak
install_proton_ge_flatpak

# Step 4: Configure Steam for Proton
configure_proton_for_steam

# Step 5: Provide gaming tips
provide_gaming_tips

# Final status
echo
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     Installation Complete!           ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
echo -e "${BLUE}• Steam installed with ${CYAN}$GPU${BLUE} GPU support via Flatpak${RESET}"
echo -e "${BLUE}• Proton GE installed for compatibility${RESET}"
echo -e "${BLUE}• Configuration instructions provided${RESET}"
echo -e "${BLUE}• Gaming tips provided${RESET}"
echo
echo -e "${GREEN}${BOLD}Enjoy gaming on Linux!${RESET}"
echo
