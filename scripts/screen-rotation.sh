#!/usr/bin/env bash

# Script directory and log setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/screen-rotation.sh.log"

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
echo -e "${BOLD}${BLUE}=== Screen Rotation Setup Utility ===${RESET}"
log_message "Starting screen rotation setup for Samsung Book3 x360"

# Step 1: Install dependencies
echo -e "\n${BOLD}${BLUE}[1/4] Installing dependencies${RESET}"
run_command "sudo pacman -S --needed --noconfirm xorg-xinput iio-sensor-proxy xorg-xrandr" "Installing required packages" true

# Step 2: Creating auto-rotate script
echo -e "\n${BOLD}${BLUE}[2/4] Creating auto-rotate script${RESET}"

# Define script path
AUTO_ROTATE_SCRIPT="$HOME/.local/bin/auto-rotate.sh"

# Create bin directory if it doesn't exist
mkdir -p "$HOME/.local/bin"

# Create script content
cat > "$AUTO_ROTATE_SCRIPT" << 'EOF'
#!/bin/bash
# Set your internal display name
DISPLAY_OUTPUT="eDP-1"
# Input device names from `xinput`
STYLUS="WCOM016C:00 2D1F:0151 Stylus stylus"
ERASER="WCOM016C:00 2D1F:0151 Stylus eraser"
# Your touchscreen device name (replace if different)
TOUCHSCREEN="ELAN902C:00 04F3:406B"
# Coordinate Transformation Matrices
normal="1 0 0 0 1 0 0 0 1"
left="0 -1 1 1 0 0 0 0 1"
right="0 1 0 -1 0 1 0 0 1"
inverted="-1 0 1 0 -1 1 0 0 1"
# Rotate inputs function
rotate_inputs() {
MATRIX=$1
# Stylus and eraser rotation
xinput set-prop "$STYLUS" "Coordinate Transformation Matrix" $MATRIX
xinput set-prop "$ERASER" "Coordinate Transformation Matrix" $MATRIX
# Touchscreen rotation (via libinput and transformation matrix)
xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" $MATRIX
# Rotate the touchscreen via libinput (angle setting)
case "$MATRIX" in
"$normal") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 0 ;;
"$left") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 90 ;;
"$right") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 270 ;;
"$inverted") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 180 ;;
esac
}
# Listen to orientation events
monitor-sensor | while read -r line; do
case "$line" in
*normal*)
xrandr --output $DISPLAY_OUTPUT --rotate normal
rotate_inputs "$normal"
 ;;
*left*)
xrandr --output $DISPLAY_OUTPUT --rotate left
rotate_inputs "$left"
 ;;
*right*)
xrandr --output $DISPLAY_OUTPUT --rotate right
rotate_inputs "$right"
 ;;
*inverted*|*bottom-up*)
xrandr --output $DISPLAY_OUTPUT --rotate inverted
rotate_inputs "$inverted"
 ;;
esac
done
EOF

# Make script executable
chmod +x "$AUTO_ROTATE_SCRIPT"

if [[ -f "$AUTO_ROTATE_SCRIPT" && -x "$AUTO_ROTATE_SCRIPT" ]]; then
    echo -e "${GREEN}✓ Created auto-rotate script at $AUTO_ROTATE_SCRIPT${RESET}"
    log_message "Created auto-rotate script successfully"
else
    echo -e "${RED}✗ Failed to create auto-rotate script${RESET}"
    log_message "Failed to create auto-rotate script"
    exit 1
fi

# Step 3: Update i3 config
echo -e "\n${BOLD}${BLUE}[3/4] Updating i3 config${RESET}"

I3_CONFIG="$HOME/.config/i3/config"

# Check if i3 config exists
if [[ ! -f "$I3_CONFIG" ]]; then
    echo -e "${YELLOW}⚠️  i3 config not found at $I3_CONFIG${RESET}"
    log_message "i3 config not found at $I3_CONFIG"
    
    # Try alternate location
    I3_CONFIG="$HOME/.i3/config"
    if [[ ! -f "$I3_CONFIG" ]]; then
        echo -e "${RED}✗ i3 config not found at alternate location $I3_CONFIG${RESET}"
        log_message "i3 config not found at alternate location $I3_CONFIG"
        exit 1
    fi
    echo -e "${YELLOW}Found i3 config at alternate location: $I3_CONFIG${RESET}"
    log_message "Found i3 config at alternate location: $I3_CONFIG"
fi

# Check if auto-rotate is already in i3 config
if grep -q "auto-rotate.sh" "$I3_CONFIG"; then
    echo -e "${YELLOW}⚠️  auto-rotate.sh already configured in i3 config - skipping${RESET}"
    log_message "auto-rotate.sh already configured in i3 config - skipping"
else
    # Add the exec line to i3 config
    echo -e "\n# Auto-rotate screen based on orientation\nexec_always --no-startup-id $AUTO_ROTATE_SCRIPT" >> "$I3_CONFIG"
    echo -e "${GREEN}✓ Added auto-rotate script to i3 config${RESET}"
    log_message "Added auto-rotate script to i3 config"
fi

# Step 4: Test device detection
echo -e "\n${BOLD}${BLUE}[4/4] Testing device detection${RESET}"

# Function to check if device exists in xinput list
check_device() {
    local device_name="$1"
    local device_type="$2"
    
    if xinput list | grep -q "$device_name"; then
        echo -e "${GREEN}✓ $device_type \"$device_name\" found${RESET}"
        log_message "$device_type \"$device_name\" found"
        return 0
    else
        echo -e "${YELLOW}⚠️  $device_type \"$device_name\" not found in xinput list${RESET}"
        log_message "$device_type \"$device_name\" not found in xinput list"
        return 1
    fi
}

# Extract device names from script
STYLUS_NAME=$(grep "STYLUS=" "$AUTO_ROTATE_SCRIPT" | cut -d'"' -f2)
ERASER_NAME=$(grep "ERASER=" "$AUTO_ROTATE_SCRIPT" | cut -d'"' -f2)
TOUCHSCREEN_NAME=$(grep "TOUCHSCREEN=" "$AUTO_ROTATE_SCRIPT" | cut -d'"' -f2)

# Check devices
check_device "$STYLUS_NAME" "Stylus"
check_device "$ERASER_NAME" "Eraser" 
check_device "$TOUCHSCREEN_NAME" "Touchscreen"

# Show xinput list if any device not found
if ! (check_device "$STYLUS_NAME" "Stylus" >/dev/null && 
       check_device "$ERASER_NAME" "Eraser" >/dev/null && 
       check_device "$TOUCHSCREEN_NAME" "Touchscreen" >/dev/null); then
    echo -e "\n${YELLOW}⚠️  Some devices not found. Here's the full xinput list:${RESET}"
    xinput list
    echo -e "\n${YELLOW}⚠️  You may need to update the device names in $AUTO_ROTATE_SCRIPT${RESET}"
    log_message "Some devices not found in xinput list. User may need to update script."
fi

# Check if iio-sensor-proxy is running
echo -e "\n${BLUE}Checking if iio-sensor-proxy is running...${RESET}"
if systemctl is-active --quiet iio-sensor-proxy; then
    echo -e "${GREEN}✓ iio-sensor-proxy service is running${RESET}"
    log_message "iio-sensor-proxy service is running"
else
    echo -e "${YELLOW}⚠️  iio-sensor-proxy service is not running${RESET}"
    echo -e "${BLUE}Starting iio-sensor-proxy service...${RESET}"
    run_command "systemctl --user start iio-sensor-proxy" "Starting iio-sensor-proxy service" false
    
    # Try system service if user service fails
    if ! systemctl --user is-active --quiet iio-sensor-proxy; then
        run_command "sudo systemctl start iio-sensor-proxy" "Starting system iio-sensor-proxy service" false
    fi
    
    # Check again
    if systemctl is-active --quiet iio-sensor-proxy || systemctl --user is-active --quiet iio-sensor-proxy; then
        echo -e "${GREEN}✓ iio-sensor-proxy service started successfully${RESET}"
        log_message "iio-sensor-proxy service started successfully"
    else
        echo -e "${YELLOW}⚠️  Failed to start iio-sensor-proxy service. Ensure it's installed and enabled:${RESET}"
        echo -e "${BLUE}sudo systemctl enable --now iio-sensor-proxy${RESET}"
        log_message "Failed to start iio-sensor-proxy service"
    fi
fi

# Final status and info
echo
echo -e "${BOLD}${BLUE}=== Setup Complete ===${RESET}"
echo -e "${BLUE}• Auto-rotate script created at: ${BOLD}$AUTO_ROTATE_SCRIPT${RESET}"
echo -e "${BLUE}• i3 config updated to run the script on startup${RESET}"
echo -e "${BLUE}• Dependencies installed: ${BOLD}xorg-xinput, iio-sensor-proxy, xorg-xrandr${RESET}"
echo -e "${BLUE}• Log file available at: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${GREEN}${BOLD}Setup complete!${RESET}"
echo -e "${YELLOW}Note: You need to restart i3 (Super+Shift+R) or logout/login for changes to take effect.${RESET}"
echo -e "${YELLOW}If you experience any issues, you may need to edit the device names in the script.${RESET}"
echo

log_message "Screen rotation setup completed successfully"