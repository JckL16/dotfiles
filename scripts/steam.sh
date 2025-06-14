#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/steam_setup.log"

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
    local fatal="${3:-false}"
    
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

# Enable multilib repo in pacman.conf
enable_multilib_repo() {
    echo -e "\n${BOLD}${BLUE}[0/6] Enabling multilib repository${RESET}"
    log_message "Starting multilib repository configuration"
    
    # Check if the [multilib] section exists and is not commented out
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        # If it doesn't exist or is commented out, append [multilib] section
        run_command "echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' | sudo tee -a /etc/pacman.conf" "Appending [multilib] section to /etc/pacman.conf" true
    else
        log_message "Multilib section already enabled in /etc/pacman.conf, skipping append"
    fi

    # Update the package database
    run_command "sudo pacman -Sy" "Refreshing package database" true

    log_message "Multilib repository enabled successfully (or already enabled)"
}

# Detect GPU type (AMD, NVIDIA, Intel)
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
    fi
    log_message "Selected GPU type: $GPU" >> "$LOG_FILE"
}

# Install Steam and dependencies based on GPU type
install_steam_and_dependencies() {
    echo -e "\n${BOLD}${BLUE}[1/6] Installing Steam${RESET}"
    
    # Install Steam through Pacman
    run_command "sudo pacman -S --noconfirm steam" "Installing Steam" true
    
    # Install dependencies based on GPU type
    case "$GPU" in
        "AMD")
            PACKAGES=(
                "lib32-mesa"
                "mesa"
                "lib32-mesa-libgl"
                "vulkan-radeon"
                "lib32-vulkan-radeon"
                "lib32-alsa-lib"
                "lib32-libpulse"
                "lib32-opencl-mesa"
            )
            ;;
        "NVIDIA")
            PACKAGES=(
                "nvidia"
                "nvidia-utils"
                "lib32-nvidia-utils"
                "lib32-alsa-lib"
                "lib32-libpulse"
                "lib32-opencl-nvidia"
            )
            ;;
        "Intel")
            PACKAGES=(
                "lib32-mesa"
                "mesa"
                "lib32-mesa-libgl"
                "lib32-alsa-lib"
                "lib32-libpulse"
            )
            ;;
    esac
    
    # Install all dependencies
    for pkg in "${PACKAGES[@]}"; do
        run_command "sudo pacman -S --noconfirm $pkg" "Installing $pkg" true
    done
}

# Create Steam directories without running Steam
create_steam_directories() {
    echo -e "\n${BOLD}${BLUE}[2/6] Creating Steam directories${RESET}"
    
    STEAM_DIR="$HOME/.steam"
    STEAM_ROOT="$HOME/.local/share/Steam"
    
    # Create necessary Steam directories
    run_command "mkdir -p \"$STEAM_DIR/steam\"" "Creating .steam directory" false
    run_command "mkdir -p \"$STEAM_ROOT\"" "Creating Steam root directory" false
    run_command "mkdir -p \"$STEAM_DIR/steam/compatibilitytools.d\"" "Creating compatibilitytools.d directory" false
    
    # Create symlink if it doesn't exist
    if [ ! -L "$STEAM_DIR/steam" ] || [ "$(readlink "$STEAM_DIR/steam")" != "$STEAM_ROOT" ]; then
        run_command "ln -sf \"$STEAM_ROOT\" \"$STEAM_DIR/steam\"" "Creating Steam directory symlink" false
    fi
    
    log_message "Steam directories created without launching Steam"
}

# Alternative method: Run Steam briefly to initialize
initialize_steam_briefly() {
    echo -e "\n${BOLD}${BLUE}[2/6] Initializing Steam configuration${RESET}"
    
    # Check if we're in a display environment
    if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
        echo -e "${YELLOW}No display detected. Creating Steam directories manually...${RESET}"
        create_steam_directories
        return 0
    fi
    
    echo -e "${BLUE}Starting Steam briefly to create configuration files...${RESET}"
    log_message "Starting Steam initialization process"
    
    # Start Steam in the background and get its PID
    steam > /dev/null 2>&1 &
    STEAM_PID=$!
    
    echo -e "${BLUE}Steam started (PID: $STEAM_PID). Waiting for initialization...${RESET}"
    
    # Wait for Steam directories to be created (max 30 seconds)
    local timeout=30
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if [ -d "$HOME/.steam/steam" ] && [ -d "$HOME/.steam/steam/compatibilitytools.d" ]; then
            echo -e "${GREEN}✓ Steam directories created${RESET}"
            break
        fi
        sleep 1
        ((elapsed++))
        echo -ne "${BLUE}Waiting for Steam initialization... ${elapsed}s${RESET}\r"
    done
    
    echo # New line after the progress indicator
    
    # Kill Steam process
    if kill -0 $STEAM_PID 2>/dev/null; then
        echo -e "${BLUE}Closing Steam...${RESET}"
        kill $STEAM_PID 2>/dev/null
        
        # Wait a bit for graceful shutdown
        sleep 2
        
        # Force kill if still running
        if kill -0 $STEAM_PID 2>/dev/null; then
            echo -e "${YELLOW}Force closing Steam...${RESET}"
            kill -9 $STEAM_PID 2>/dev/null
        fi
        
        echo -e "${GREEN}✓ Steam closed${RESET}"
        log_message "Steam process terminated successfully"
    else
        echo -e "${YELLOW}Steam process already terminated${RESET}"
        log_message "Steam process was already terminated"
    fi
    
    # Verify directories were created
    if [ ! -d "$HOME/.steam/steam/compatibilitytools.d" ]; then
        echo -e "${YELLOW}Steam directories not found, creating manually...${RESET}"
        create_steam_directories
    fi
}

# Install Proton GE
install_proton_ge() {
    echo -e "\n${BOLD}${BLUE}[3/6] Installing Proton GE (Glorious Eggroll)${RESET}"
    
    # Ensure compatibility tools directory exists
    PROTON_GE_DIR="$HOME/.steam/steam/compatibilitytools.d"
    mkdir -p "$PROTON_GE_DIR"
    
    # Download Proton GE (latest release)
    TEMP_DIR=$(mktemp -d)
    PROTON_GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/latest"
    
    # Get the latest release URL and version
    LATEST_URL=$(curl -Ls -o /dev/null -w %{url_effective} "$PROTON_GE_URL")
    VERSION=$(echo "$LATEST_URL" | grep -oP '(?<=tag/)[^/]+$')
    DOWNLOAD_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$VERSION/${VERSION}.tar.gz"
    
    log_message "Latest Proton GE version: $VERSION" >> "$LOG_FILE"
    log_message "Download URL: $DOWNLOAD_URL" >> "$LOG_FILE"
    
    # Download the Proton GE tarball
    run_command "curl -L \"$DOWNLOAD_URL\" -o \"$TEMP_DIR/proton-ge.tar.gz\"" "Downloading Proton GE $VERSION" true
    
    # Extract to the Proton directory
    run_command "tar -xzf \"$TEMP_DIR/proton-ge.tar.gz\" -C \"$PROTON_GE_DIR\"" "Extracting Proton GE" true
    
    # Clean up
    run_command "rm -rf \"$TEMP_DIR\"" "Cleaning up temporary files" false
    
    echo -e "${GREEN}Proton GE $VERSION installed to Steam.${RESET}"
}

# Show setup instructions for Steam
show_instructions() {
    echo -e "\n${BOLD}${BLUE}[4/6] Steam Configuration Instructions${RESET}"
    
    echo -e "${YELLOW}Follow these steps to configure Steam:${RESET}"
    echo -e "  ${BOLD}1.${RESET} Launch Steam"
    echo -e "  ${BOLD}2.${RESET} Go to ${BOLD}Steam${RESET} → ${BOLD}Settings${RESET} → ${BOLD}Steam Play${RESET}"
    echo -e "  ${BOLD}3.${RESET} Check ${BOLD}\"Enable Steam Play for supported titles\"${RESET}"
    echo -e "  ${BOLD}4.${RESET} Check ${BOLD}\"Enable Steam Play for all other titles\"${RESET}"
    echo -e "  ${BOLD}5.${RESET} Select ${BOLD}\"Proton-GE\"${RESET} from the dropdown menu"
    echo -e "  ${BOLD}6.${RESET} Click ${BOLD}OK${RESET} to save settings"
}

# Main script execution
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     Steam Gaming Setup Utility       ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"

# Step 1: Enable multilib repo
enable_multilib_repo

# Step 2: Detect GPU
detect_gpu

# Step 3: Install Steam and dependencies
install_steam_and_dependencies

# Step 4: Initialize Steam (briefly) or create directories manually
initialize_steam_briefly

# Step 5: Install Proton GE
install_proton_ge

# Step 6: Show instructions
show_instructions

echo -e "\n${BOLD}${BLUE}[5/6] Setup Summary${RESET}"
echo -e "${GREEN}✓ Multilib repository enabled${RESET}"
echo -e "${GREEN}✓ $GPU GPU drivers and libraries installed${RESET}"
echo -e "${GREEN}✓ Steam installed${RESET}"
echo -e "${GREEN}✓ Steam directories initialized${RESET}"
echo -e "${GREEN}✓ Proton GE installed${RESET}"

echo -e "\n${BOLD}${BLUE}[6/6] Final Notes${RESET}"
echo -e "${BLUE}• Steam is ready to use${RESET}"
echo -e "${BLUE}• Proton GE is available in Steam settings${RESET}"
echo -e "${BLUE}• Log file: ${BOLD}$LOG_FILE${RESET}"

log_message "Steam and Proton GE setup completed successfully"
echo -e "\n${GREEN}${BOLD}Steam gaming setup complete!${RESET}"