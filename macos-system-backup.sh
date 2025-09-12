#!/bin/bash

# macOS System Backup and Restore Script
# This script creates backups of Homebrew packages, system settings, and generates restore commands

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create backup directory with timestamp
BACKUP_DIR="$HOME/macos-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}🔄 Starting macOS System Backup...${NC}"
echo -e "${BLUE}📁 Backup directory: $BACKUP_DIR${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Backup Homebrew packages
echo -e "\n${BLUE}📦 Backing up Homebrew packages...${NC}"

if command -v brew >/dev/null 2>&1; then
    # Export brew formulae
    brew list > "$BACKUP_DIR/brew-formulae.txt"
    print_status "Exported $(wc -l < "$BACKUP_DIR/brew-formulae.txt") formulae"
    
    # Export brew casks
    brew list --cask > "$BACKUP_DIR/brew-casks.txt" 2>/dev/null || touch "$BACKUP_DIR/brew-casks.txt"
    print_status "Exported $(wc -l < "$BACKUP_DIR/brew-casks.txt") casks"
    
    # Create Brewfile
    brew bundle dump --file="$BACKUP_DIR/Brewfile" --force
    print_status "Created Brewfile"
    
    # Backup brew services
    brew services list > "$BACKUP_DIR/brew-services.txt"
    print_status "Backed up brew services"
else
    print_warning "Homebrew not found"
fi

# 2. Backup system settings and preferences
echo -e "\n${BLUE}⚙️  Backing up system settings...${NC}"

# Export all user defaults
defaults read > "$BACKUP_DIR/user-defaults.plist"
print_status "Exported user defaults"

# Backup important system preferences
mkdir -p "$BACKUP_DIR/system-settings"

# Dock settings
defaults read com.apple.dock > "$BACKUP_DIR/system-settings/dock.plist" 2>/dev/null || touch "$BACKUP_DIR/system-settings/dock.plist"

# Finder settings
defaults read com.apple.finder > "$BACKUP_DIR/system-settings/finder.plist" 2>/dev/null || touch "$BACKUP_DIR/system-settings/finder.plist"

# Trackpad/Mouse settings
defaults read com.apple.AppleMultitouchTrackpad > "$BACKUP_DIR/system-settings/trackpad.plist" 2>/dev/null || touch "$BACKUP_DIR/system-settings/trackpad.plist"

# Keyboard settings
defaults read com.apple.HIToolbox > "$BACKUP_DIR/system-settings/keyboard.plist" 2>/dev/null || touch "$BACKUP_DIR/system-settings/keyboard.plist"

# Menu bar settings
defaults read com.apple.systemuiserver > "$BACKUP_DIR/system-settings/menubar.plist" 2>/dev/null || touch "$BACKUP_DIR/system-settings/menubar.plist"

print_status "Backed up system preferences"

# 3. Backup configuration files
echo -e "\n${BLUE}📄 Backing up configuration files...${NC}"

mkdir -p "$BACKUP_DIR/config-files"

# Shell configuration
for file in .zshrc .bashrc .bash_profile .profile .zprofile .zshenv; do
    if [ -f "$HOME/$file" ]; then
        cp "$HOME/$file" "$BACKUP_DIR/config-files/"
        print_status "Backed up $file"
    fi
done

# Git configuration
if [ -f "$HOME/.gitconfig" ]; then
    cp "$HOME/.gitconfig" "$BACKUP_DIR/config-files/"
    print_status "Backed up .gitconfig"
fi

# SSH configuration (without private keys for security)
if [ -d "$HOME/.ssh" ]; then
    mkdir -p "$BACKUP_DIR/config-files/.ssh"
    if [ -f "$HOME/.ssh/config" ]; then
        cp "$HOME/.ssh/config" "$BACKUP_DIR/config-files/.ssh/"
        print_status "Backed up SSH config"
    fi
    # Backup public keys only
    cp "$HOME/.ssh/"*.pub "$BACKUP_DIR/config-files/.ssh/" 2>/dev/null || true
    print_status "Backed up SSH public keys"
fi

# VS Code settings and extensions
if [ -d "$HOME/Library/Application Support/Code/User" ]; then
    mkdir -p "$BACKUP_DIR/config-files/vscode"
    cp "$HOME/Library/Application Support/Code/User/settings.json" "$BACKUP_DIR/config-files/vscode/" 2>/dev/null || true
    cp "$HOME/Library/Application Support/Code/User/keybindings.json" "$BACKUP_DIR/config-files/vscode/" 2>/dev/null || true
    
    # Export VS Code extensions
    if command -v code >/dev/null 2>&1; then
        code --list-extensions > "$BACKUP_DIR/config-files/vscode/extensions.txt"
        print_status "Backed up VS Code settings and extensions"
    fi
fi

# 4. Generate restore script
echo -e "\n${BLUE}🔧 Generating restore script...${NC}"

cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash

# macOS System Restore Script
# Generated automatically - review before running

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🔄 Starting macOS System Restore...${NC}"

# Install Homebrew if not present
if ! command -v brew >/dev/null 2>&1; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# Restore Homebrew packages
print_info "Restoring Homebrew packages..."

if [ -f "$SCRIPT_DIR/Brewfile" ]; then
    brew bundle install --file="$SCRIPT_DIR/Brewfile"
    print_status "Restored packages from Brewfile"
else
    # Fallback to individual package lists
    if [ -f "$SCRIPT_DIR/brew-formulae.txt" ]; then
        while read -r formula; do
            [ -n "$formula" ] && brew install "$formula" 2>/dev/null || print_warning "Failed to install: $formula"
        done < "$SCRIPT_DIR/brew-formulae.txt"
    fi
    
    if [ -f "$SCRIPT_DIR/brew-casks.txt" ]; then
        while read -r cask; do
            [ -n "$cask" ] && brew install --cask "$cask" 2>/dev/null || print_warning "Failed to install cask: $cask"
        done < "$SCRIPT_DIR/brew-casks.txt"
    fi
fi

# Restore configuration files
print_info "Restoring configuration files..."

if [ -d "$SCRIPT_DIR/config-files" ]; then
    # Shell configs
    for file in .zshrc .bashrc .bash_profile .profile .zprofile .zshenv .gitconfig; do
        if [ -f "$SCRIPT_DIR/config-files/$file" ]; then
            cp "$SCRIPT_DIR/config-files/$file" "$HOME/"
            print_status "Restored $file"
        fi
    done
    
    # SSH config
    if [ -d "$SCRIPT_DIR/config-files/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        cp "$SCRIPT_DIR/config-files/.ssh/"* "$HOME/.ssh/" 2>/dev/null || true
        chmod 644 "$HOME/.ssh/"*.pub 2>/dev/null || true
        chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
        print_status "Restored SSH configuration"
    fi
    
    # VS Code settings
    if [ -d "$SCRIPT_DIR/config-files/vscode" ]; then
        VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
        mkdir -p "$VSCODE_USER_DIR"
        
        [ -f "$SCRIPT_DIR/config-files/vscode/settings.json" ] && cp "$SCRIPT_DIR/config-files/vscode/settings.json" "$VSCODE_USER_DIR/"
        [ -f "$SCRIPT_DIR/config-files/vscode/keybindings.json" ] && cp "$SCRIPT_DIR/config-files/vscode/keybindings.json" "$VSCODE_USER_DIR/"
        
        # Install VS Code extensions
        if [ -f "$SCRIPT_DIR/config-files/vscode/extensions.txt" ] && command -v code >/dev/null 2>&1; then
            while read -r extension; do
                [ -n "$extension" ] && code --install-extension "$extension" 2>/dev/null || true
            done < "$SCRIPT_DIR/config-files/vscode/extensions.txt"
            print_status "Restored VS Code settings and extensions"
        fi
    fi
fi

print_info "Manual steps required:"
echo "1. Review and apply system preferences from the system-settings folder"
echo "2. Configure any app-specific settings manually"
echo "3. Sign into accounts and services"
echo "4. Generate new SSH private keys if needed"
echo "5. Restart any brew services: brew services start <service-name>"

echo -e "${GREEN}🎉 Restore completed!${NC}"
EOF

chmod +x "$BACKUP_DIR/restore.sh"
print_status "Created restore script"

# 5. Generate system settings restore commands
echo -e "\n${BLUE}📋 Generating system settings restore commands...${NC}"

cat > "$BACKUP_DIR/restore-system-settings.sh" << 'EOF'
#!/bin/bash

# System Settings Restore Commands
# Review and run these commands manually to restore your macOS settings

echo "🔧 System Settings Restore Commands"
echo "=================================="
echo ""
echo "⚠️  WARNING: Review these commands before running!"
echo "   Some settings may require admin privileges or restarts"
echo ""

# Note: You'll need to manually review the backed up .plist files
# and extract the specific settings you want to restore

echo "# Dock Settings (review dock.plist and apply manually)"
echo "# Examples:"
echo "# defaults write com.apple.dock tilesize -int 48"
echo "# defaults write com.apple.dock autohide -bool true"
echo "# killall Dock"
echo ""

echo "# Finder Settings (review finder.plist and apply manually)"
echo "# Examples:"
echo "# defaults write com.apple.finder ShowPathbar -bool true"
echo "# defaults write com.apple.finder ShowStatusBar -bool true"
echo "# killall Finder"
echo ""

echo "# Trackpad Settings (review trackpad.plist and apply manually)"
echo "# Examples:"
echo "# defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true"
echo ""

echo "📝 To find specific settings:"
echo "1. Open the .plist files in the system-settings folder"
echo "2. Look for the settings you want to restore"
echo "3. Use 'defaults write' commands to apply them"
echo "4. You can also use 'plutil -p file.plist' to view plist contents"
EOF

chmod +x "$BACKUP_DIR/restore-system-settings.sh"
print_status "Created system settings restore guide"

# 6. Create a summary
echo -e "\n${BLUE}📊 Creating backup summary...${NC}"

cat > "$BACKUP_DIR/BACKUP-SUMMARY.md" << EOF
# macOS Backup Summary

**Backup Date:** $(date)
**Backup Location:** $BACKUP_DIR

## What's Backed Up

### Homebrew Packages
- **Formulae:** $(cat "$BACKUP_DIR/brew-formulae.txt" | wc -l | xargs) packages
- **Casks:** $(cat "$BACKUP_DIR/brew-casks.txt" | wc -l | xargs) applications
- **Brewfile:** Complete package manifest
- **Services:** Brew services configuration

### System Settings
- User defaults (all applications)
- Dock preferences
- Finder preferences  
- Trackpad/Mouse settings
- Keyboard settings
- Menu bar configuration

### Configuration Files
- Shell configurations (.zshrc, .bashrc, etc.)
- Git configuration
- SSH configuration (public keys only)
- VS Code settings and extensions list

## How to Restore

### Quick Restore (Recommended)
Run the restore script:
\`\`\`bash
cd "$BACKUP_DIR"
./restore.sh
\`\`\`

### Manual Restore
1. **Homebrew packages:** Use Brewfile or individual package lists
2. **Configuration files:** Copy from config-files folder
3. **System settings:** Review system-settings folder and apply manually

### System Settings
Review the .plist files in system-settings/ and use \`defaults write\` commands to restore specific preferences.

## Security Notes
- SSH private keys are NOT backed up for security
- Generate new SSH keys or restore from secure backup separately
- Review all settings before applying on a new system

## Files in This Backup
EOF

ls -la "$BACKUP_DIR" >> "$BACKUP_DIR/BACKUP-SUMMARY.md"

print_status "Created backup summary"

# Final output
echo -e "\n${GREEN}🎉 Backup completed successfully!${NC}"
echo -e "${BLUE}📁 Backup location: $BACKUP_DIR${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the BACKUP-SUMMARY.md file"
echo "2. Test the restore.sh script in a safe environment"
echo "3. Store this backup in a secure location"
echo "4. Consider encrypting sensitive configuration files"
echo ""
echo -e "${BLUE}To restore on a fresh macOS installation:${NC}"
echo "1. Copy the backup folder to the new system"
echo "2. Run: chmod +x restore.sh && ./restore.sh"
echo "3. Manually configure system settings using the restore-system-settings.sh guide"
