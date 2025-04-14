#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/audio.sh.log"

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
echo -e "${BOLD}${BLUE}=== Audio System Setup Utility ===${RESET}"
log_message "Starting audio system (sof-firmware, PulseAudio, pavucontrol) setup"

# Step 1: Install sof-firmware
echo -e "\n${BOLD}${BLUE}[1/5] Installing Sound Open Firmware${RESET}"
run_command "sudo pacman -S --noconfirm sof-firmware alsa-firmware" "Installing sof-firmware and alsa-firmware" true

# Step 2: Install PulseAudio and related packages
echo -e "\n${BOLD}${BLUE}[2/5] Installing PulseAudio${RESET}"
run_command "sudo pacman -S --noconfirm pulseaudio pulseaudio-alsa" "Installing PulseAudio and ALSA module" true

# Step 3: Install pavucontrol
echo -e "\n${BOLD}${BLUE}[3/5] Installing PulseAudio Volume Control${RESET}"
run_command "sudo pacman -S --noconfirm pavucontrol" "Installing pavucontrol" true

# Step 4: Configure and start PulseAudio
echo -e "\n${BOLD}${BLUE}[4/5] Configuring PulseAudio${RESET}"

# Restart pulseaudio to apply changes
run_command "systemctl --user enable pulseaudio.socket pulseaudio.service" "Enabling PulseAudio service for current user" false
run_command "systemctl --user restart pulseaudio.service" "Restarting PulseAudio service" false

# Step 5: Test audio detection
echo -e "\n${BOLD}${BLUE}[5/5] Verifying audio devices${RESET}"
echo -ne "${BLUE}Checking for audio devices... ${RESET}"

# Run aplay -l to list audio devices
audio_devices=$(aplay -l 2>&1)
log_message "Audio devices detected:\n$audio_devices"

if echo "$audio_devices" | grep -q "no soundcards found"; then
    echo -e "${YELLOW}⚠️ No audio devices detected${RESET}"
    log_message "WARNING: No audio devices detected"
else
    echo -e "${GREEN}✓ Audio devices detected${RESET}"
    device_count=$(echo "$audio_devices" | grep -c "^card")
    echo -e "${GREEN}Found $device_count audio device(s)${RESET}"
    log_message "Found $device_count audio device(s)"
fi

# Check if PulseAudio is running
echo -ne "${BLUE}Checking PulseAudio status... ${RESET}"
if pulseaudio --check; then
    echo -e "${GREEN}✓ PulseAudio is running${RESET}"
    log_message "PulseAudio is running"
else
    echo -e "${YELLOW}⚠️ PulseAudio is not running, attempting to start it${RESET}"
    log_message "WARNING: PulseAudio is not running"
    run_command "pulseaudio --start" "Starting PulseAudio" false
fi

# Final status
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• Sound Open Firmware (sof-firmware) installed${RESET}"
echo -e "${BLUE}• PulseAudio installed and configured${RESET}"
echo -e "${BLUE}• PulseAudio Volume Control (pavucontrol) installed${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}Audio system setup complete!${RESET}"
echo -e "${YELLOW}You can control your audio settings by running: pavucontrol${RESET}"
echo -e "${YELLOW}If you don't hear sound, try rebooting your system to load the firmware.${RESET}"
echo

log_message "Audio system setup completed successfully"