#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_file="$SCRIPT_DIR/packages"
yay_package_file="$SCRIPT_DIR/yay-packages"
dotfiles_dir="$SCRIPT_DIR/dotfiles"
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
echo

# Install system packages
echo -e "${BOLD}${BLUE}[1/3] Installing system packages...${RESET}"
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

# Install yay packages
echo -e "${BOLD}${BLUE}[2/3] Installing AUR packages with yay...${RESET}"
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
echo -e "${BOLD}${BLUE}[3/3] Setting up dotfiles...${RESET}"
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

# Final completion message
echo
echo -e "${BOLD}${BLUE}=== Installation Summary ===${RESET}"
echo -e "${BLUE}System packages: ${GREEN}$success_count successful${RESET}, ${RED}$error_count failed${RESET}"
echo -e "${BLUE}AUR packages: ${GREEN}$yay_success_count successful${RESET}, ${RED}$yay_error_count failed${RESET}"
echo -e "${BLUE}Dotfiles: ${GREEN}$dotfiles_success installed${RESET}, ${YELLOW}$dotfiles_backup backed up${RESET}, ${RED}$dotfiles_error failed${RESET}"

if [ $dotfiles_backup -gt 0 ]; then
    echo -e "${BLUE}Backup of original files created at: ${BOLD}$backup_dir${RESET}"
fi

echo -e "${BLUE}Log files are available in: ${BOLD}$log_dir${RESET}"
echo
echo -e "${GREEN}${BOLD}Setup complete!${RESET}"