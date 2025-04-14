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

# Function to enable multilib repository
enable_multilib_repo() {
    echo -e "\n${BOLD}${BLUE}[0/5] Checking for multilib repository${RESET}"

    if grep -q "^\[multilib\]" /etc/pacman.conf && grep -A 1 "\[multilib\]" /etc/pacman.conf | grep -q "^\s*Include"; then
        echo -e "${GREEN}✓ Multilib repository already enabled${RESET}"
        log_message "Multilib repository already enabled" >> "$LOG_FILE"
    else
        echo -e "${YELLOW}⚠️  Multilib repository is not enabled.${RESET}"
        read -p "Do you want to enable it now? [Y/n]: " enable_reply
        enable_reply=${enable_reply,,}  # to lowercase

        if [[ $enable_reply =~ ^(y|yes|)$ ]]; then
            sudo sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
            sudo sed -i '/#Include = \/etc\/pacman.d\/mirrorlist/{
                s/^#//
                :a
                n
                /^\[.*\]/q
                s/^#//
                ba
            }' /etc/pacman.conf

            echo -e "${BLUE}Updating package databases...${RESET}"
            run_command "sudo pacman -Sy" "Updating package databases" true

            echo -e "${GREEN}✓ Multilib enabled and databases updated${RESET}"
            log_message "Multilib repository enabled" >> "$LOG_FILE"
        else
            echo -e "${RED}Multilib is required for Steam. Exiting.${RESET}"
            log_message "ERROR: User declined enabling multilib" >> "$LOG_FILE"
            exit 1
        fi
    fi
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

# Function to install dependencies for Steam and Proton with AMD graphics
install_amd_dependencies() {
    echo -e "\n${BOLD}${BLUE}[2/5] Installing AMD GPU dependencies${RESET}"
    
    PACKAGES=(
        "steam"
        "lib32-mesa"
        "mesa"
        "lib32-mesa-libgl"
        "vulkan-radeon"
        "lib32-vulkan-radeon"
        "lib32-alsa-lib"
        "lib32-libpulse"
        "lib32-opencl-mesa"
    )
    
    for pkg in "${PACKAGES[@]}"; do
        run_command "sudo pacman -S --noconfirm $pkg" "Installing $pkg" true
    done
}

# Function to install dependencies for Steam and Proton with NVIDIA graphics
install_nvidia_dependencies() {
    echo -e "\n${BOLD}${BLUE}[2/5] Installing NVIDIA GPU dependencies${RESET}"
    
    PACKAGES=(
        "steam"
        "nvidia"
        "nvidia-utils"
        "lib32-nvidia-utils"
        "lib32-alsa-lib"
        "lib32-libpulse"
        "lib32-opencl-nvidia"
    )
    
    for pkg in "${PACKAGES[@]}"; do
        run_command "sudo pacman -S --noconfirm $pkg" "Installing $pkg" true
    done
}

# Function to install dependencies for Steam and Proton with Intel graphics
install_intel_dependencies() {
    echo -e "\n${BOLD}${BLUE}[2/5] Installing Intel GPU dependencies${RESET}"
    
    PACKAGES=(
        "steam"
        "lib32-mesa"
        "mesa"
        "lib32-mesa-libgl"
        "lib32-alsa-lib"
        "lib32-libpulse"
    )
    
    for pkg in "${PACKAGES[@]}"; do
        run_command "sudo pacman -S --noconfirm $pkg" "Installing $pkg" true
    done
}

# Function to install Proton GE (Glorious Eggroll)
install_proton_ge() {
    echo -e "\n${BOLD}${BLUE}[3/5] Installing Proton GE (Glorious Eggroll)${RESET}"
    
    # Create directories for Proton
    STEAM_DIR="$HOME/.steam/steam"
    PROTON_GE_DIR="$STEAM_DIR/compatibilitytools.d"
    
    run_command "mkdir -p \"$PROTON_GE_DIR\"" "Creating Proton directory" true
    
    # Install ProtonUp-Qt for managing Proton GE versions
    echo -e "\n${BLUE}Installing ProtonUp-Qt (Proton GE manager)${RESET}"
    if command -v yay &>/dev/null; then
        run_command "yay -S --noconfirm protonup-qt" "Installing ProtonUp-Qt" false
    else
        echo -e "${YELLOW}⚠️  yay not found. You'll need to install ProtonUp-Qt manually.${RESET}"
        log_message "WARNING: yay not found for ProtonUp-Qt installation" >> "$LOG_FILE"
    fi
    
    # Download latest Proton GE release
    echo -e "\n${BLUE}Downloading latest Proton GE...${RESET}"
    TEMP_DIR=$(mktemp -d)
    PROTON_GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/latest"
    
    # Get the latest release URL
    LATEST_URL=$(curl -Ls -o /dev/null -w %{url_effective} "$PROTON_GE_URL")
    VERSION=$(echo "$LATEST_URL" | grep -oP '(?<=tag/)[^/]+$')
    DOWNLOAD_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$VERSION/${VERSION}.tar.gz"
    
    log_message "Latest Proton GE version: $VERSION" >> "$LOG_FILE"
    log_message "Download URL: $DOWNLOAD_URL" >> "$LOG_FILE"
    
    run_command "curl -L \"$DOWNLOAD_URL\" -o \"$TEMP_DIR/proton-ge.tar.gz\"" "Downloading Proton GE $VERSION" true
    
    # Extract to Steam compatibility tools directory
    run_command "tar -xzf \"$TEMP_DIR/proton-ge.tar.gz\" -C \"$PROTON_GE_DIR\"" "Extracting Proton GE" true
    
    # Clean up
    run_command "rm -rf \"$TEMP_DIR\"" "Cleaning up temporary files" false
    
    echo -e "${GREEN}Proton GE $VERSION installed to Steam.${RESET}"
}

# Function to provide instructions for Proton configuration
configure_proton_for_steam() {
    echo -e "\n${BOLD}${BLUE}[4/5] Configuring Steam for Proton compatibility${RESET}"
    
    echo -e "${YELLOW}Follow these steps to configure Steam:${RESET}"
    echo -e "  ${BOLD}1.${RESET} Launch Steam"
    echo -e "  ${BOLD}2.${RESET} Go to ${BOLD}Steam${RESET} → ${BOLD}Settings${RESET} → ${BOLD}Steam Play${RESET}"
    echo -e "  ${BOLD}3.${RESET} Check ${BOLD}\"Enable Steam Play for supported titles\"${RESET}"
    echo -e "  ${BOLD}4.${RESET} Check ${BOLD}\"Enable Steam Play for all other titles\"${RESET}"
    echo -e "  ${BOLD}5.${RESET} Select ${BOLD}\"Proton-GE\"${RESET} from the dropdown menu"
    echo -e "  ${BOLD}6.${RESET} Click ${BOLD}OK${RESET} to save settings"
    
    # Log configuration instructions
    log_message "Configuration instructions provided to user" >> "$LOG_FILE"
}

# Function to provide additional tips
provide_gaming_tips() {
    echo -e "\n${BOLD}${BLUE}[5/5] Additional gaming tips${RESET}"
    
    echo -e "${YELLOW}Helpful tips for gaming on Linux:${RESET}"
    echo -e "  ${BOLD}•${RESET} Check game compatibility on ${BOLD}ProtonDB${RESET}: https://www.protondb.com"
    echo -e "  ${BOLD}•${RESET} For performance monitoring, install ${BOLD}MangoHud${RESET}: yay -S mangohud"
    echo -e "  ${BOLD}•${RESET} For game optimization, consider using ${BOLD}GameMode${RESET}: sudo pacman -S gamemode lib32-gamemode"
    echo -e "  ${BOLD}•${RESET} Set launch options for Steam games: ${BOLD}MANGOHUD=1 gamemoderun %command%${RESET}"
    
    # Log tips provided
    log_message "Gaming tips provided to user" >> "$LOG_FILE"
}

# Print header
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     Steam Gaming Setup Utility       ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
log_message "Starting Steam and Proton installation" >> "$LOG_FILE"

# Step 0: Ensure multilib is enabled
enable_multilib_repo

# Step 1: Detect GPU
echo -e "\n${BOLD}${BLUE}[1/5] Detecting hardware${RESET}"
detect_gpu

# Install dependencies based on the GPU type
case "$GPU" in
    "AMD")
        install_amd_dependencies
        ;;
    "NVIDIA")
        install_nvidia_dependencies
        ;;
    "Intel")
        install_intel_dependencies
        ;;
    *)
        echo -e "${RED}${BOLD}Error: Unknown GPU type selected. Exiting installation.${RESET}"
        exit 1
        ;;
esac

# Install Proton GE
install_proton_ge

# Configure Proton
configure_proton_for_steam

# Provide gaming tips
provide_gaming_tips

# Final status
echo
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     Installation Complete!           ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
echo -e "${BLUE}• Steam installed with ${CYAN}$GPU${BLUE} GPU support${RESET}"
echo -e "${BLUE}• Proton GE installed for compatibility${RESET}"
echo -e "${BLUE}• Configuration instructions provided${RESET}"
echo -e "${BLUE}• Gaming tips provided${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}Enjoy gaming on Linux!${RESET}"
echo

log_message "Steam gaming setup completed successfully" >> "$LOG_FILE"