#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$SCRIPT_DIR/packages"
yay_package_file="$SCRIPT_DIR/yay-packages"
dotfiles_dir="$SCRIPT_DIR/dotfiles"
scripts_dir="$SCRIPT_DIR/scripts"
log_dir="$SCRIPT_DIR/logs"
backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# ANSI color codes for better formatting
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"
RESET="\033[0m"

# Create logs directory if it doesn't exist
mkdir -p "$log_dir"

# Function to display usage
show_usage() {
    echo -e "${BOLD}${BLUE}=== System Setup Utility Usage ===${RESET}"
    echo -e "Usage: $0 [options] [scripts...]"
    echo -e ""
    echo -e "Options:"
    echo -e "  -h, --help         Show this help message"
    echo -e "  -l, --list         List available installation scripts"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0                 Run only the main installation process"
    echo -e "  $0 --list          List available installation scripts"
    echo -e "  $0 audio yay       Run main installation plus the audio.sh and yay.sh scripts"
    echo
    echo -e "${BLUE}Note: Scripts should be specified without the .sh extension${RESET}"
}

# Function to list available scripts
list_scripts() {
    echo -e "${BOLD}${BLUE}=== Available Installation Scripts ===${RESET}"
    
    if [ ! -d "$scripts_dir" ] || [ -z "$(ls -A "$scripts_dir" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No installation scripts found in $scripts_dir${RESET}"
        return
    }
    
    echo -e "${BLUE}The following scripts are available in the scripts directory:${RESET}"
    echo
    
    for script in "$scripts_dir"/*.sh; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script" .sh)
            # Extract first comment line as description if available
            description=$(head -n 5 "$script" | grep -E "^#[[:space:]]+" | head -n 1 | sed 's/^#[[:space:]]\+//')
            if [ -n "$description" ]; then
                echo -e "${GREEN}${script_name}${RESET}: $description"
            else
                echo -e "${GREEN}${script_name}${RESET}"
            fi
        fi
    done
    echo
    echo -e "${BLUE}Run with: $0 [script1] [script2] ...${RESET}"
}

# Function to run a specific script
run_script() {
    local script_name="$1"
    local script_path="$scripts_dir/${script_name}.sh"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: Script '$script_name' not found at $script_path${RESET}"
        return 1
    fi
    
    echo -e "\n${BOLD}${BLUE}=== Running $script_name Script ===${RESET}"
    
    # Make the script executable if it's not
    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi
    
    # Execute the script
    if "$script_path"; then
        echo -e "${GREEN}✓ Script $script_name completed successfully${RESET}"
        return 0
    else
        echo -e "${RED}✗ Script $script_name failed with exit code $?${RESET}"
        return 1
    fi
}

# Process command line arguments
scripts_to_run=()
skip_main=false

# Check if no arguments were provided
if [ $# -eq 0 ]; then
    # Default behavior: run main installation
    :
else
    # Process arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_scripts
                exit 0
                ;;
            *)
                # Treat as script name
                scripts_to_run+=("$1")
                ;;
        esac
        shift
    done
fi

# Clear previous log files properly
find "$log_dir" -type f -delete 2>/dev/null || echo -e "${YELLOW}⚠️  Warning: Could not clear previous log files.${RESET}"

# Count packages
package_count=$(wc -l < "$package_file" 2>/dev/null || echo 0)
yay_package_count=$(wc -l < "$yay_package_file" 2>/dev/null || echo 0)

# Print header
echo -e "${BOLD}${BLUE}=== System Setup Utility ===${RESET}"
echo -e "${BLUE}Found: ${BOLD}$package_count${RESET}${BLUE} system packages and ${BOLD}$yay_package_count${RESET}${BLUE} AUR packages${RESET}"
echo -e "${BLUE}Dotfiles source: ${BOLD}$dotfiles_dir${RESET}"
echo -e "${BLUE}Logs will be saved to: ${BOLD}$log_dir${RESET}"

if [ ${#scripts_to_run[@]} -gt 0 ]; then
    echo -e "${BLUE}Additional scripts to run: ${BOLD}${scripts_to_run[*]}${RESET}"
fi
echo

# Install system packages
echo -e "${BOLD}${BLUE}[1/4] Installing system packages...${RESET}"
echo

success_count=0
error_count=0

if [ -f "$package_file" ] && [ -s "$package_file" ]; then
    while IFS= read -r package || [[ -n "$package" ]]; do
        # Skip empty lines and comments
        [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
        
        echo -ne "${BLUE}Installing ${BOLD}$package${RESET}${BLUE}... ${RESET}"
        
        # Log file specific to the package
        package_log="$log_dir/$package.log"
        
        # Use sudo for pacman, redirecting output to log
        if sudo pacman -S "$package" --noconfirm > "$package_log" 2>&1; then
            echo -e "${GREEN}✓ OK${RESET}"
            ((success_count++))
        else
            echo -e "${RED}✗ ERROR${RESET}"
            echo "Installation failed for package $package. See log for details." >> "$package_log"
            ((error_count++))
        fi
    done < "$package_file"
else
    echo -e "${YELLOW}⚠️  No system packages found to install.${RESET}"
fi

echo
echo -e "${BLUE}System packages: ${GREEN}$success_count successful${RESET}, ${RED}$error_count failed${RESET}"
echo

# Run the Yay installation script if it exists
yay_script="$scripts_dir/yay.sh"
if [ -f "$yay_script" ]; then
    echo -e "${BOLD}${BLUE}[2/4] Setting up Yay AUR helper...${RESET}"
    echo
    
    # Check if yay is already installed
    if command -v yay &> /dev/null; then
        echo -e "${GREEN}✓ Yay is already installed${RESET}"
    else
        # Make the script executable if it's not
        if [ ! -x "$yay_script" ]; then
            chmod +x "$yay_script"
        fi
        
        # Execute the yay installation script
        if "$yay_script"; then
            echo -e "${GREEN}✓ Yay installation completed successfully${RESET}"
        else
            echo -e "${RED}✗ Yay installation failed with exit code $?${RESET}"
            echo -e "${YELLOW}⚠️  Skipping AUR packages installation${RESET}"
            # Remove yay from scripts_to_run if it was added manually
            for i in "${!scripts_to_run[@]}"; do
                if [[ "${scripts_to_run[i]}" = "yay" ]]; then
                    unset 'scripts_to_run[i]'
                fi
            done
        fi
    fi
    echo
else
    echo -e "${BOLD}${BLUE}[2/4] Yay installation script not found at $yay_script${RESET}"
    echo -e "${YELLOW}⚠️  Skipping Yay setup step${RESET}"
    echo
fi

# Install yay packages
echo -e "${BOLD}${BLUE}[3/4] Installing AUR packages with yay...${RESET}"
echo

yay_success_count=0
yay_error_count=0

if [ -f "$yay_package_file" ] && [ -s "$yay_package_file" ]; then
    if ! command -v yay &> /dev/null; then
        echo -e "${YELLOW}⚠️  yay is not installed. Skipping AUR packages.${RESET}"
    else
        while IFS= read -r package || [[ -n "$package" ]]; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
            
            echo -ne "${BLUE}Installing ${BOLD}$package${RESET}${BLUE}... ${RESET}"
            
            # Log file specific to the package
            package_log="$log_dir/yay-$package.log"
            
            # yay doesn't need sudo
            if yay -S "$package" --noconfirm > "$package_log" 2>&1; then
                echo -e "${GREEN}✓ OK${RESET}"
                ((yay_success_count++))
            else
                echo -e "${RED}✗ ERROR${RESET}"
                echo "Installation failed for package $package. See log for details." >> "$package_log"
                ((yay_error_count++))
            fi
        done < "$yay_package_file"
    fi
else
    echo -e "${YELLOW}⚠️  No AUR packages found to install.${RESET}"
fi

echo
echo -e "${BLUE}AUR packages: ${GREEN}$yay_success_count successful${RESET}, ${RED}$yay_error_count failed${RESET}"
echo

# Install dotfiles
echo -e "${BOLD}${BLUE}[4/4] Setting up dotfiles...${RESET}"
echo

dotfiles_success=0
dotfiles_backup=0
dotfiles_error=0

if [ -d "$dotfiles_dir" ]; then
    # Create backup directory if needed
    mkdir -p "$backup_dir"
    
    # Find all files in the dotfiles directory (including hidden files)
    find "$dotfiles_dir" -type f | while read -r src_file; do
        # Get the relative path from the dotfiles directory
        rel_path="${src_file#$dotfiles_dir/}"
        # Calculate destination path in home directory
        dest_file="$HOME/$rel_path"
        # Create the destination directory if it doesn't exist
        dest_dir=$(dirname "$dest_file")
        
        echo -ne "${BLUE}Processing ${BOLD}$rel_path${RESET}${BLUE}... ${RESET}"
        
        # Create parent directory if it doesn't exist
        if [ ! -d "$dest_dir" ]; then
            mkdir -p "$dest_dir"
        fi
        
        # Backup existing file if it exists and is not a symlink to our dotfile
        if [ -f "$dest_file" ] && [ ! -L "$dest_file" -o "$(readlink -f "$dest_file")" != "$(readlink -f "$src_file")" ]; then
            backup_path="$backup_dir/$rel_path"
            backup_dir_path=$(dirname "$backup_path")
            mkdir -p "$backup_dir_path"
            mv "$dest_file" "$backup_path"
            echo -ne "${YELLOW}(backed up) ${RESET}"
            ((dotfiles_backup++))
        fi
        
        # Create symlink
        if ln -sf "$src_file" "$dest_file" 2>/dev/null; then
            echo -e "${GREEN}✓ OK${RESET}"
            ((dotfiles_success++))
        else
            echo -e "${RED}✗ ERROR${RESET}"
            ((dotfiles_error++))
        fi
    done
else
    echo -e "${YELLOW}⚠️  Dotfiles directory not found at: $dotfiles_dir${RESET}"
fi

# Run additional requested scripts
if [ ${#scripts_to_run[@]} -gt 0 ]; then
    echo -e "\n${BOLD}${BLUE}=== Running Additional Scripts ===${RESET}"
    echo
    
    script_success=0
    script_failed=0
    
    for script_name in "${scripts_to_run[@]}"; do
        # Skip if script is "yay" since we already ran it
        if [ "$script_name" = "yay" ]; then
            echo -e "${YELLOW}Skipping yay.sh as it was already executed${RESET}"
            continue
        fi
        
        if run_script "$script_name"; then
            ((script_success++))
        else
            ((script_failed++))
        fi
    done
    
    echo
    echo -e "${BLUE}Additional scripts: ${GREEN}$script_success successful${RESET}, ${RED}$script_failed failed${RESET}"
fi

# Final completion message
echo
echo -e "${BOLD}${BLUE}=== Installation Summary ===${RESET}"
echo -e "${BLUE}System packages: ${GREEN}$success_count successful${RESET}, ${RED}$error_count failed${RESET}"
echo -e "${BLUE}AUR packages: ${GREEN}$yay_success_count successful${RESET}, ${RED}$yay_error_count failed${RESET}"
echo -e "${BLUE}Dotfiles: ${GREEN}$dotfiles_success installed${RESET}, ${YELLOW}$dotfiles_backup backed up${RESET}, ${RED}$dotfiles_error failed${RESET}"

if [ ${#scripts_to_run[@]} -gt 0 ]; then
    echo -e "${BLUE}Additional scripts: ${GREEN}$script_success successful${RESET}, ${RED}$script_failed failed${RESET}"
fi

if [ $dotfiles_backup -gt 0 ]; then
    echo -e "${BLUE}Backup of original files created at: ${BOLD}$backup_dir${RESET}"
fi

echo -e "${BLUE}Log files are available in: ${BOLD}$log_dir${RESET}"
echo
echo -e "${GREEN}${BOLD}Setup complete!${RESET}"