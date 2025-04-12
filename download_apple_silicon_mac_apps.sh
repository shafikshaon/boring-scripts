#!/bin/bash

################################################################################
# macOS Development Environment Setup Script
# Author: Shafikur Rahman
# Description: Automated setup script for macOS development environment
################################################################################

# Strict error handling
set -euo pipefail

# Color definitions
readonly RESET='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'

# Global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/macos_setup_$(date +%Y%m%d_%H%M%S).log"
ERRORS=()

# Logging functions
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $1" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✓${RESET} $1"
}

log_info() {
    log "${BLUE}ℹ${RESET} $1"
}

log_warning() {
    log "${YELLOW}⚠${RESET} $1"
}

log_error() {
    log "${RED}✖${RESET} $1"
    ERRORS+=("$1")
}

# Helper functions
check_prerequisites() {
    log_info "Checking system prerequisites..."
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is intended for macOS only. Current OS: $(uname)"
        exit 1
    fi

    # Check macOS version
    local macos_version=$(sw_vers -productVersion)
    if [[ "${macos_version%%.*}" -lt "11" ]]; then
        log_error "This script requires macOS Big Sur (11.0) or later. Current version: $macos_version"
        exit 1
    fi
    log_success "macOS version $macos_version detected"

    # Check if running with sudo
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run with sudo. Please run as a normal user"
        exit 1
    fi
    
    # Check for Apple Silicon or Intel
    local cpu_type=$(uname -m)
    if [[ "$cpu_type" == "arm64" ]]; then
        log_success "Apple Silicon (M1/M2) detected"
        # Ensure Rosetta 2 is installed for Apple Silicon
        if ! pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
            log_info "Installing Rosetta 2..."
            sudo softwareupdate --install-rosetta --agree-to-license
            log_success "Rosetta 2 installed"
        fi
    else
        log_success "Intel processor detected"
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_error "No internet connection detected. This script requires internet access"
        exit 1
    fi
    log_success "Internet connectivity confirmed"

    # Check available disk space (minimum 20GB)
    local available_space=$(df -H / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${available_space%.*}" -lt 20 ]; then
        log_error "Insufficient disk space. At least 20GB required, only ${available_space}GB available"
        exit 1
    fi
    log_success "Sufficient disk space available: ${available_space}GB"
}

setup_sudo_access() {
    log_info "Setting up sudo access..."
    sudo -v
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

install_xcode_tools() {
    if ! xcode-select -p &>/dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        log_success "Xcode Command Line Tools installed"
    else
        log_info "Xcode Command Line Tools already installed"
    fi
}

install_homebrew() {
    if ! command -v brew &>/dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
        log_success "Homebrew installed"
    else
        log_info "Updating Homebrew..."
        brew update
    fi
}

install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed"
    else
        log_info "Oh My Zsh already installed"
    fi
}

# Package arrays
readonly BREW_PACKAGES=(
    git
    tree
    wget
    jq
    ripgrep
    fd
    bat
    tldr
    python
    pyenv
    awscli
    azure-cli
    pnpm
    go
    rustup
    htop
    neofetch
    kubernetes-cli
    helm
    postgresql@17
)

readonly BREW_CASKS=(
    iterm2
    visual-studio-code
    docker
    dbeaver-community
    tableplus
    notion
    slack
    google-chrome
    firefox
    postman
    insomnia
    figma
    sublime-text
    zoom
    pgadmin4
    stats
    vlc
    signal
    claude
    maccy
    anaconda
    mysqlworkbench
    telegram-desktop
    google-chrome@canary
    keyboard-cowboy
    shottr
    sourcetree
    whatsapp
    openoffice
)

install_packages() {
    log_info "Installing Homebrew packages..."
    for package in "${BREW_PACKAGES[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_info "$package already installed"
        else
            log_info "Installing $package..."
            brew install "$package" || log_error "Failed to install $package"
        fi
    done
}

install_casks() {
    log_info "Installing Homebrew casks..."
    for cask in "${BREW_CASKS[@]}"; do
        if brew list --cask "$cask" &>/dev/null; then
            log_info "$cask already installed"
        else
            log_info "Installing $cask..."
            brew install --cask "$cask" || log_error "Failed to install $cask"
        fi
    done
}

setup_databases() {
    # PostgreSQL
    log_info "Setting up PostgreSQL..."
    if ! brew list postgresql@17 &>/dev/null; then
        brew install postgresql@17
        brew services start postgresql@17
        log_success "PostgreSQL installed and started"
    fi

    # MongoDB
    log_info "Setting up MongoDB..."
    if ! brew list mongodb-community &>/dev/null; then
        brew tap mongodb/brew
        brew install mongodb-community
        brew services start mongodb-community
        log_success "MongoDB installed and started"
    fi
}

setup_node() {
    log_info "Setting up Node.js environment..."
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # Configure NVM
        {
            echo 'export NVM_DIR="$HOME/.nvm"'
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
        } >> ~/.zshrc
        
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # Install LTS version
        nvm install --lts
        nvm use --lts
        log_success "Node.js environment configured"
    fi
}

setup_python() {
    log_info "Setting up Python environment..."
    if command -v pyenv &>/dev/null; then
        if ! grep -q 'pyenv init' ~/.zshrc; then
            {
                echo 'export PYENV_ROOT="$HOME/.pyenv"'
                echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
                echo 'eval "$(pyenv init -)"'
            } >> ~/.zshrc
        fi
        
        pyenv install 3.13.2 -s
        pyenv global 3.13.2
        log_success "Python environment configured"
    fi
}

setup_git() {
    log_info "Setting up Git configuration..."
    
    # Prompt for Git configuration if not set
    if [ -z "$(git config --global user.name)" ]; then
        read -p "Enter your Git name: " git_name
        git config --global user.name "$git_name"
    fi

    if [ -z "$(git config --global user.email)" ]; then
        read -p "Enter your Git email: " git_email
        git config --global user.email "$git_email"
    fi

    # Set up SSH key for GitHub
    setup_github_ssh
}

setup_github_ssh() {
    local key_path="$HOME/.ssh/id_ed25519_github"
    
    if [[ ! -f "$key_path" ]]; then
        log_info "Setting up GitHub SSH key..."
        read -p "Enter your GitHub email: " github_email
        
        ssh-keygen -t ed25519 -C "$github_email" -f "$key_path" -N ""
        eval "$(ssh-agent -s)"
        ssh-add "$key_path"
        
        log_success "SSH key generated at $key_path"
        echo "Your public SSH key (add this to GitHub):"
        cat "${key_path}.pub"
    else
        log_info "GitHub SSH key already exists at $key_path"
    fi
}

setup_development_directory() {
    log_info "Setting up development directory..."
    mkdir -p ~/Development/{personal,work,experiments}
    log_success "Development directories created"
}

setup_shell_customization() {
    log_info "Setting up shell customization..."
    
    # Add useful aliases
    {
        echo "# Custom aliases"
        echo 'alias ll="ls -la"'
        echo 'alias python="python3"'
        echo 'alias pip="pip3"'
        echo 'alias k="kubectl"'
        echo 'alias dc="docker-compose"'
    } >> ~/.zshrc
}

main() {
    log_info "Starting macOS development environment setup..."
    
    # Initial setup
    check_prerequisites
    setup_sudo_access
    
    # Core installations
    install_xcode_tools
    install_homebrew
    install_oh_my_zsh
    
    # Package installations
    install_packages
    install_casks
    
    # Development environment setup
    setup_databases
    setup_node
    setup_python
    setup_git
    setup_development_directory
    setup_shell_customization
    
    # Final steps
    if [ ${#ERRORS[@]} -eq 0 ]; then
        log_success "Setup completed successfully!"
        log_info "Please restart your terminal for all changes to take effect"
    else
        log_error "Setup completed with ${#ERRORS[@]} errors:"
        for error in "${ERRORS[@]}"; do
            log_error "- $error"
        done
    fi
    
    log_info "Setup log available at: $LOG_FILE"
}

# Execute main function
main
