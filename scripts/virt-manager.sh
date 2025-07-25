#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/virt_manager.sh.log"

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

# Function to prompt user for yes/no questions
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    
    local default_prompt="Y/n"
    if [ "$default" = "n" ]; then
        default_prompt="y/N"
    fi
    
    while true; do
        read -p "$prompt [$default_prompt]: " response
        case "${response:-$default}" in
            [Yy]*)
                return 0
                ;;
            [Nn]*)
                return 1
                ;;
            *)
                echo -e "${YELLOW}Please answer with y or n${RESET}"
                ;;
        esac
    done
}

# Print header
echo -e "${BOLD}${BLUE}=== QEMU/KVM Virtualization Setup Utility ===${RESET}"
log_message "Starting virtualization environment setup"

# Step 1: Check for virtualization support
echo -e "\n${BOLD}${BLUE}[1/6] Checking for virtualization support${RESET}"
if ! grep -E -q 'vmx|svm' /proc/cpuinfo; then
    echo -e "${RED}${BOLD}ERROR: Virtualization is not supported or enabled on this CPU.${RESET}"
    echo -e "${YELLOW}Please enable virtualization in BIOS or UEFI before proceeding.${RESET}"
    log_message "ERROR: Virtualization not supported or enabled on CPU"
    exit 1
else
    echo -e "${GREEN}✓ Virtualization support detected${RESET}"
    log_message "Virtualization support is enabled"
fi

# Step 2: Install virt-manager and dependencies
echo -e "\n${BOLD}${BLUE}[2/6] Installing virt-manager and dependencies${RESET}"
run_command "sudo pacman -S --noconfirm virt-manager qemu libvirt dnsmasq bridge-utils" "Installing virt-manager, QEMU, and dependencies" true

# Step 3: Enable and start libvirtd service
echo -e "\n${BOLD}${BLUE}[3/6] Enabling libvirtd service${RESET}"
run_command "sudo systemctl enable --now libvirtd" "Enabling and starting libvirtd service" true

# Step 4: Configure nested virtualization (optional)
echo -e "\n${BOLD}${BLUE}[4/6] Configuring nested virtualization${RESET}"
nested_enabled=false

# Detect CPU type
if grep -q 'vmx' /proc/cpuinfo; then
    cpu_type="intel"
    echo -e "${BLUE}Intel CPU detected${RESET}"
elif grep -q 'svm' /proc/cpuinfo; then
    cpu_type="amd"
    echo -e "${BLUE}AMD CPU detected${RESET}"
else
    cpu_type="unknown"
    echo -e "${YELLOW}⚠️ Could not determine CPU type for nested virtualization${RESET}"
    log_message "WARNING: Could not determine CPU type for nested virtualization"
fi

# Only prompt if we detected a compatible CPU
if [ "$cpu_type" != "unknown" ]; then
    if prompt_yes_no "Would you like to enable nested virtualization?" "y"; then
        log_message "User opted to enable nested virtualization"
        
        if [ "$cpu_type" = "intel" ]; then
            run_command "sudo modprobe -r kvm_intel && sudo modprobe kvm_intel nested=1" "Loading Intel KVM module with nested virtualization" false
            if run_command "echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm_intel.conf > /dev/null" "Setting Intel nested virtualization to persist across reboots" false; then
                nested_enabled=true
            fi
        elif [ "$cpu_type" = "amd" ]; then
            run_command "sudo modprobe -r kvm_amd && sudo modprobe kvm_amd nested=1" "Loading AMD KVM module with nested virtualization" false
            if run_command "echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm_amd.conf > /dev/null" "Setting AMD nested virtualization to persist across reboots" false; then
                nested_enabled=true
            fi
        fi
        
        if [ "$nested_enabled" = true ]; then
            echo -e "${GREEN}✓ Nested virtualization enabled successfully${RESET}"
        else
            echo -e "${YELLOW}⚠️ Failed to enable nested virtualization, but continuing with setup${RESET}"
            log_message "WARNING: Failed to enable nested virtualization, continuing with setup"
        fi
    else
        echo -e "${YELLOW}⚠️ Skipping nested virtualization as per user request${RESET}"
        log_message "User opted to skip nested virtualization"
    fi
else
    echo -e "${YELLOW}⚠️ Skipping nested virtualization due to incompatible CPU${RESET}"
    log_message "Skipping nested virtualization due to incompatible CPU"
fi

# Step 5: Configure virtual network
echo -e "\n${BOLD}${BLUE}[5/6] Configuring virtual network interface${RESET}"
run_command "sudo virsh net-start default 2>/dev/null || echo 'Network already running'" "Starting default virtual network" false
run_command "sudo virsh net-autostart default" "Setting virtual network to autostart" true

# Step 6: Add user to libvirt group
echo -e "\n${BOLD}${BLUE}[6/6] Setting up user permissions${RESET}"
run_command "sudo usermod -aG libvirt $(whoami)" "Adding current user to libvirt group" true

# Final status
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• QEMU/KVM virtualization stack installed${RESET}"
echo -e "${BLUE}• Libvirtd service enabled and running${RESET}"

# Conditional message based on nested virtualization status
if [ "$nested_enabled" = true ]; then
    echo -e "${BLUE}• Nested virtualization configured and enabled${RESET}"
else
    echo -e "${YELLOW}• Nested virtualization not enabled${RESET}"
fi

echo -e "${BLUE}• Virtual network interface configured${RESET}"
echo -e "${BLUE}• User permissions set${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo

# Add note about nested virtualization if not enabled
if [ "$nested_enabled" != true ]; then
    echo -e "${YELLOW}Note: Nested virtualization is not enabled. If you need this feature later,${RESET}"
    echo -e "${YELLOW}      you can enable it manually by following instructions in the KVM documentation.${RESET}"
fi

echo -e "${GREEN}${BOLD}Setup complete!${RESET}"
echo -e "${YELLOW}Note: You need to log out and log back in for group changes to take effect.${RESET}"
echo -e "${YELLOW}After logging back in, run 'virt-manager' to start the virtualization manager.${RESET}"
echo

log_message "Virtualization setup completed successfully"