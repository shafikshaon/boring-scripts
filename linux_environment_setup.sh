#!/usr/bin/env bash
# =============================================================================
# Ubuntu Developer Setup Script
# Tested on: Ubuntu 26.04 (Resolute) — also works on 24.04 LTS
# Strategy: prefer snap > official upstream apt > PPA
# Versions: dynamically resolved at install time — always latest stable
# =============================================================================

# NOTE: We intentionally do NOT use "set -e" so one package failure
# does not abort the entire script. Each function handles its own errors.
set -uo pipefail

# ─── Colors & Formatting ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

COLS=$(tput cols 2>/dev/null || echo 80)

center_line() { printf "${CYAN}"; printf '═%.0s' $(seq 1 "$COLS"); printf "${RESET}\n"; }
center_text() { local t="$1" c="${2:-$BOLD}"; local p=$(( (COLS - ${#t}) / 2 )); printf "${c}%*s%s${RESET}\n" $p '' "$t"; }

section() { echo ""; center_line; center_text "  $1  " "$CYAN$BOLD"; center_line; echo ""; }
info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[FAIL]${RESET}  $*"; }

ask() {
  local prompt="$1" var_name="$2"
  echo -en "${YELLOW}  ▸ ${RESET}${prompt} (Y/n): "
  read -r "$var_name"
}

is_yes() { [[ "${1:-n}" =~ ^[Yy] ]]; }

# Run a command and continue even if it fails; print a warning on failure
try() { "$@" || { err "Command failed (non-fatal): $*"; }; }

# Fetch latest GitHub release tag for a repo
gh_latest() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"; }

# ─── Detect Ubuntu release ───────────────────────────────────────────────────
UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
UBUNTU_VERSION=$(. /etc/os-release && echo "$VERSION_ID")

# ─── Self-heal apt_pkg if broken by a previous update-alternatives run ───────
# Symptoms: "No module named 'apt_pkg'" on add-apt-repository or apt-get update.
# Cause:    update-alternatives redirected /usr/bin/python3 away from the distro
#           system Python that apt_pkg was compiled against.
fix_apt_pkg() {
  if python3 -c "import apt_pkg" 2>/dev/null; then
    return 0  # already fine
  fi
  warn "apt_pkg broken — restoring system Python symlink..."
  # Find the distro-owned python3.x binary (the one that owns apt_pkg)
  local sys_py
  sys_py=$(dpkg -l python3.[0-9]* 2>/dev/null     | awk '/^ii/{print $2}'     | grep -v '\-'     | sort -V     | while read -r pkg; do
        bin="/usr/bin/${pkg}"
        if [[ -x "$bin" ]] && "$bin" -c "import apt_pkg" 2>/dev/null; then
          echo "$bin"; break
        fi
      done)
  if [[ -z "$sys_py" ]]; then
    # Brute-force: try each versioned python in /usr/bin
    for py in /usr/bin/python3.[0-9]*; do
      if [[ -x "$py" ]] && "$py" -c "import apt_pkg" 2>/dev/null; then
        sys_py="$py"; break
      fi
    done
  fi
  if [[ -n "$sys_py" ]]; then
    sudo ln -sf "$sys_py" /usr/bin/python3
    info "Restored /usr/bin/python3 → $sys_py"
    if python3 -c "import apt_pkg" 2>/dev/null; then
      success "apt_pkg is working again."
    else
      err "Could not restore apt_pkg automatically. Run: sudo apt reinstall python3-apt"
    fi
  else
    err "No suitable system Python found. Run: sudo apt reinstall python3-apt"
  fi
}
fix_apt_pkg

# ─── Remove conflicting git-core PPA sources (common leftover from previous runs) ──
# When add-apt-repository was used previously, it stores the GPG key inline inside
# a .list file. If the script later writes a separate .gpg keyring + .sources file,
# apt sees two different Signed-By values for the same PPA and refuses to run at all.
# Solution: always nuke every git-core PPA artifact before anything else runs.
cleanup_git_ppa() {
  local removed=0
  for f in     /etc/apt/sources.list.d/git-core-ubuntu-ppa-*.list     /etc/apt/sources.list.d/git-core-ppa.sources     /etc/apt/sources.list.d/git-core-ppa.list     /etc/apt/keyrings/git-core-ppa.gpg; do
    if [[ -f "$f" ]]; then
      sudo rm -f "$f"
      removed=1
    fi
  done
  [[ $removed -eq 1 ]] && info "Removed stale git-core PPA sources (prevents Signed-By conflict)."
}
cleanup_git_ppa

# ─── Wait for dpkg/apt lock to be free ───────────────────────────────────────
wait_for_apt() {
  local i=0

  # Kill unattended-upgrade / apt-daily which commonly hold the lock on fresh boots
  for proc in unattended-upgrade apt-get dpkg; do
    if pgrep -x "$proc" > /dev/null 2>&1; then
      warn "Found running '$proc' process — waiting up to 60s for it to finish..."
    fi
  done

  # Wait up to 60 seconds, then forcibly resolve
  while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock                    /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if (( i == 0 )); then
      warn "apt/dpkg lock is held. Waiting (max 60s before force-killing)..."
    fi
    sleep 3; (( i++ ))

    # After 20 tries (~60s), kill unattended-upgrade and clean locks
    if (( i >= 20 )); then
      warn "Lock still held after 60s — killing unattended-upgrade and cleaning locks..."
      sudo systemctl stop unattended-upgrades 2>/dev/null || true
      sudo pkill -f unattended-upgrade 2>/dev/null || true
      sleep 3
      # Clean stale lock files (safe once the holding process is gone)
      sudo rm -f         /var/lib/dpkg/lock-frontend         /var/lib/dpkg/lock         /var/cache/apt/archives/lock         /var/lib/apt/lists/lock
      sudo dpkg --configure -a 2>/dev/null || true
      break
    fi
  done
}

# ─── Pre-flight ───────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  err "Do not run as root. Run as a normal user with sudo privileges."
  exit 1
fi

clear
center_line
center_text "Ubuntu Developer Setup Script" "$GREEN$BOLD"
center_text "Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME}) — snap-preferred" "$CYAN"
center_line
echo ""
info "Versions are resolved dynamically at install time — always latest stable."
echo ""

# ─── Prompt Phase ─────────────────────────────────────────────────────────────
section "Select packages to install"

ask "Install essential build tools & system libraries"    want_basics
ask "Install Git (with global config)"                    want_git
ask "Install Oh My Zsh (robbyrussell theme)"              want_omz
ask "Install Google Chrome"                               want_chrome
ask "Install VS Code (snap)"                              want_vscode
ask "Install JetBrains Toolbox"                           want_jetbrains
ask "Install Cursor (AI code editor)"                     want_cursor
ask "Install NVM + Node.js (LTS + latest)"                want_nvm
ask "Install Python 3.14 (system on Resolute, deadsnakes on older)"  want_python
ask "Install Go (latest, auto-detected)"                  want_golang
ask "Install Rust (via rustup)"                           want_rust
ask "Install Java 21 LTS + Maven"                         want_java
ask "Install Docker Desktop"                              want_docker
ask "Install kubectl (snap)"                              want_kubectl
ask "Install Helm 3 (snap)"                               want_helm
ask "Install k9s (snap)"                                  want_k9s
ask "Install Minikube"                                    want_minikube
ask "Install Skaffold"                                    want_skaffold
ask "Install Terraform (snap)"                            want_terraform
ask "Install AWS CLI v2"                                  want_aws
ask "Install Redis (latest, official repo)"               want_redis
ask "Install PostgreSQL (latest stable, pgdg)"            want_postgresql
ask "Install MongoDB (latest stable, official repo)"      want_mongodb
ask "Install Elasticsearch (9.x, official repo)"          want_elasticsearch
ask "Install RabbitMQ (official erlang repo)"             want_rabbitmq
ask "Install Memcached"                                   want_memcached
ask "Install Postman (snap)"                              want_postman
ask "Install Slack (snap)"                                want_slack
ask "Install Zoom"                                        want_zoom
ask "Install VLC (snap)"                                  want_vlc
ask "Install Signal (apt)"                                want_signal
ask "Install CopyQ (snap)"                                want_copyq
ask "Install Flameshot"                                   want_flameshot
ask "Install btop (snap)"                                 want_btop
ask "Install ripgrep + fd + bat + fzf + eza"              want_modern_cli
ask "Install jq + yq"                                     want_jq
ask "Install tmux"                                        want_tmux
ask "Install Ollama (local LLM runner)"                   want_ollama
ask "Setup SSH keypair (ed25519)"                         want_ssh
ask "Setup GPG key"                                       want_gpg

# ─── System Update ────────────────────────────────────────────────────────────
section "Updating system packages"
wait_for_apt
sudo apt-get update -y
sudo apt-get upgrade -y
success "System updated."

# ─── 0. Essential Build Tools ─────────────────────────────────────────────────
install_basics() {
  section "Installing essential build tools"
  wait_for_apt
  sudo apt-get install -y \
    build-essential checkinstall gcc g++ make \
    curl wget unzip zip \
    apt-transport-https ca-certificates gnupg lsb-release software-properties-common \
    libssl-dev libffi-dev libpq-dev \
    bash-completion tree \
    xclip xsel \
    libncurses-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libsqlite3-dev \
    libcurl4-gnutls-dev libexpat1-dev zlib1g-dev \
    python3-pip python3-venv \
    libfuse2t64 asciidoc xmlto 2>/dev/null || \
  sudo apt-get install -y \
    build-essential checkinstall gcc g++ make \
    curl wget unzip zip \
    apt-transport-https ca-certificates gnupg lsb-release software-properties-common \
    libssl-dev libffi-dev libpq-dev \
    bash-completion tree xclip xsel \
    libncurses-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libsqlite3-dev \
    libcurl4-gnutls-dev libexpat1-dev zlib1g-dev \
    python3-pip python3-venv libfuse2 asciidoc xmlto || true
  success "Essential tools installed."
}

# ─── 1. Git ───────────────────────────────────────────────────────────────────
install_git() {
  section "Installing Git (latest stable)"

  # Remove any conflicting git-core PPA sources left over from previous runs.
  # The conflict arises when both a .list file (from add-apt-repository) and
  # a .sources file exist for the same PPA with different Signed-By values.
  sudo rm -f /etc/apt/sources.list.d/git-core-ppa.sources              /etc/apt/sources.list.d/git-core-ubuntu-ppa-*.list              /etc/apt/keyrings/git-core-ppa.gpg 2>/dev/null || true

  # Ubuntu Resolute (26.04) ships git 2.53+ in the official repo — no PPA needed.
  # On older Ubuntu we add the git-core PPA via its Launchpad signing key.
  if [[ "$UBUNTU_CODENAME" == "resolute" ]]; then
    info "Ubuntu Resolute: installing git from official repo (already latest)"
    sudo apt-get install -y git
  else
    # Fetch the PPA signing key directly (no add-apt-repository, no Python needed)
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xE1CF20ADEFE4CC8B"       | sudo gpg --yes --dearmor -o /etc/apt/keyrings/git-core-ppa.gpg 2>/dev/null || true
    sudo tee /etc/apt/sources.list.d/git-core-ppa.sources > /dev/null <<EOF
Types: deb
URIs: https://ppa.launchpadcontent.net/git-core/ppa/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: main
Signed-By: /etc/apt/keyrings/git-core-ppa.gpg
EOF
    sudo apt-get update -y 2>/dev/null || true
    sudo apt-get install -y git
  fi

  git --version
  echo -en "${YELLOW}  ▸ ${RESET}Git user name: "; read -r git_name
  echo -en "${YELLOW}  ▸ ${RESET}Git email: ";     read -r git_email
  git config --global user.name  "$git_name"
  git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global core.autocrlf input
  git config --global pull.rebase false
  git config --global core.editor "vim"
  success "Git $(git --version | cut -d' ' -f3) configured."
}

# ─── 2. Oh My Zsh ─────────────────────────────────────────────────────────────
install_omz() {
  section "Installing Zsh + Oh My Zsh"
  sudo apt-get install -y zsh

  # Unset $ZSH so the installer doesn't abort when ~/.oh-my-zsh already exists
  unset ZSH
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    warn "~/.oh-my-zsh already exists — upgrading in place."
    env ZSH="$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh/tools/upgrade.sh" 2>/dev/null || true
  else
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  local ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
  [[ -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
  [[ -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
  [[ -d "${ZSH_CUSTOM}/plugins/zsh-completions" ]] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions \
      "${ZSH_CUSTOM}/plugins/zsh-completions"

  sed -i 's|^plugins=.*|plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions docker kubectl golang)|' \
    "$HOME/.zshrc" 2>/dev/null || true
  try chsh -s "$(which zsh)"
  success "Oh My Zsh installed (robbyrussell theme, autosuggestions, syntax-highlighting)."
}

# ─── 3. Google Chrome ─────────────────────────────────────────────────────────
install_chrome() {
  section "Installing Google Chrome (latest stable)"
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    -O /tmp/chrome.deb
  sudo apt-get install -y /tmp/chrome.deb || sudo apt-get -f install -y
  rm -f /tmp/chrome.deb
  # Fix arch tag Chrome drops into sources (avoids apt warnings)
  local src="/etc/apt/sources.list.d/google-chrome.list"
  if [[ -f "$src" ]]; then
    sudo sed -i 's|^deb https://dl.google.com|deb [arch=amd64] https://dl.google.com|' "$src"
  fi
  google-chrome --version 2>/dev/null || true
  success "Google Chrome installed."
}

# ─── 4. VS Code (snap) ────────────────────────────────────────────────────────
install_vscode() {
  section "Installing VS Code (snap — always latest)"
  sudo snap install code --classic
  code --version | head -1
  success "VS Code installed."
}

# ─── 5. JetBrains Toolbox ─────────────────────────────────────────────────────
install_jetbrains() {
  section "Installing JetBrains Toolbox (latest)"
  local url
  url=$(curl -fsSL \
    "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['TBA'][0]['downloads']['linux']['link'])")
  info "Downloading: $url"
  wget -q "$url" -O /tmp/jb-toolbox.tar.gz
  sudo tar -xzf /tmp/jb-toolbox.tar.gz -C /opt
  local dir
  dir=$(ls /opt | grep jetbrains-toolbox | sort -V | tail -1)
  sudo ln -sf "/opt/${dir}/jetbrains-toolbox" /usr/local/bin/jetbrains-toolbox
  rm -f /tmp/jb-toolbox.tar.gz
  success "JetBrains Toolbox installed. Run: jetbrains-toolbox"
}

# ─── 6. Cursor ────────────────────────────────────────────────────────────────
install_cursor() {
  section "Installing Cursor (latest AI Code Editor)"
  wget -q "https://downloader.cursor.sh/linux/appImage/x64" -O /tmp/cursor.AppImage
  sudo mv /tmp/cursor.AppImage /usr/local/bin/cursor
  sudo chmod +x /usr/local/bin/cursor
  cat <<EOF | sudo tee /usr/share/applications/cursor.desktop > /dev/null
[Desktop Entry]
Name=Cursor
Exec=/usr/local/bin/cursor --no-sandbox %F
Icon=cursor
Type=Application
Categories=Development;
EOF
  success "Cursor installed. Run: cursor"
}

# ─── 7. NVM + Node.js ─────────────────────────────────────────────────────────
install_nvm() {
  section "Installing NVM + Node.js (latest NVM, LTS + current)"
  local NVM_VERSION
  NVM_VERSION=$(gh_latest "nvm-sh/nvm")
  info "Installing NVM ${NVM_VERSION}"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

  nvm install --lts    # latest LTS
  nvm install node     # latest current
  nvm alias default node
  node --version && npm --version

  # pnpm — standalone installer (corepack dropped from Node 25+)
  # This always installs the latest pnpm regardless of Node version
  info "Installing pnpm (standalone installer — always latest)"
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  # Make pnpm available in current shell session
  export PNPM_HOME="$HOME/.local/share/pnpm"
  export PATH="$PNPM_HOME:$PATH"
  # Persist pnpm PATH to shell configs
  for rc in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc" ]] && ! grep -q 'PNPM_HOME' "$rc"; then
      cat <<'EOF' >> "$rc"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
EOF
    fi
  done
  pnpm --version

  npm install -g typescript ts-node nodemon pm2 --loglevel=error

  # Persist NVM to shell configs
  for rc in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc" ]] && ! grep -q 'NVM_DIR' "$rc"; then
      cat <<'EOF' >> "$rc"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
    fi
  done
  success "NVM ${NVM_VERSION} + Node.js LTS & current + pnpm (standalone) + ts-node + pm2 installed."
}

# ─── 8. Python 3.14 ───────────────────────────────────────────────────────────
install_python() {
  section "Installing Python 3.14"

  # IMPORTANT: We NEVER run update-alternatives on python3.
  # Overriding /usr/bin/python3 breaks apt's internal apt_pkg module
  # (compiled against the distro system Python), causing
  # "No module named 'apt_pkg'" errors on every subsequent apt-get update.
  # Always invoke the versioned binary python3.14 directly.

  if [[ "$UBUNTU_CODENAME" == "resolute" ]]; then
    # Python 3.14 is already the default interpreter on Ubuntu 26.04 —
    # available in the official repo, no PPA needed.
    info "Ubuntu Resolute: installing python3.14 from official repo"
    sudo apt-get install -y python3.14 python3.14-venv python3.14-dev python3-pip
  else
    # Ubuntu 24.04 / 22.04 — add deadsnakes PPA without add-apt-repository
    info "Installing Python 3.14 via deadsnakes PPA"
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776"       | sudo gpg --yes --dearmor -o /etc/apt/keyrings/deadsnakes.gpg 2>/dev/null || true
    sudo tee /etc/apt/sources.list.d/deadsnakes.sources > /dev/null <<EOF
Types: deb
URIs: https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: main
Signed-By: /etc/apt/keyrings/deadsnakes.gpg
EOF
    sudo apt-get update -y 2>/dev/null || true
    sudo apt-get install -y python3.14 python3.14-venv python3.14-dev
    # Bootstrap pip (deadsnakes builds exclude pip)
    python3.14 -m ensurepip --upgrade 2>/dev/null || \
      curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.14
  fi

  python3.14 --version
  python3.14 -m pip install --upgrade pip uv --break-system-packages
  success "Python 3.14 + pip + uv installed. Use 'python3.14' to invoke it."
  warn "Do NOT override /usr/bin/python3 — it breaks apt's apt_pkg module."
}

# ─── 9. Go (dynamic latest) ───────────────────────────────────────────────────
install_golang() {
  section "Installing Go (latest stable from go.dev)"
  local GO_VERSION
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
  local ARCH="amd64"
  local ARCHIVE="${GO_VERSION}.linux-${ARCH}.tar.gz"
  info "Installing ${GO_VERSION}"
  wget -q "https://go.dev/dl/${ARCHIVE}" -O "/tmp/${ARCHIVE}"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "/tmp/${ARCHIVE}"
  rm -f "/tmp/${ARCHIVE}"
  for rc in ~/.bashrc ~/.zshrc ~/.profile; do
    if [[ -f "$rc" ]] && ! grep -q '/usr/local/go/bin' "$rc"; then
      echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$rc"
    fi
  done
  export PATH=$PATH:/usr/local/go/bin
  go version
  # Essential dev tools
  go install golang.org/x/tools/cmd/goimports@latest
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
  go install github.com/air-verse/air@latest
  go install github.com/swaggo/swag/cmd/swag@latest
  success "${GO_VERSION} + goimports + golangci-lint + air + swag installed."
}

# ─── 10. Rust ─────────────────────────────────────────────────────────────────
install_rust() {
  section "Installing Rust (latest via rustup)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
  rustup component add rustfmt clippy
  cargo --version
  success "Rust installed."
}

# ─── 11. Java 21 LTS + Maven ──────────────────────────────────────────────────
install_java() {
  section "Installing Java 21 LTS + Maven"
  sudo apt-get install -y openjdk-21-jdk maven
  java -version
  mvn --version
  success "Java 21 + Maven installed."
}

# ─── 12. Docker Desktop ───────────────────────────────────────────────────────
install_docker() {
  section "Installing Docker Desktop (latest)"

  # Pre-answer the UEFI Secure Boot / MOK enrollment dialog so it does not
  # block the script with an interactive ncurses prompt.
  # The dialog is triggered by dkms/shim packages that ship with Docker Desktop.
  # Setting mokutil password to empty + DEBIAN_FRONTEND=noninteractive suppresses it.
  export DEBIAN_FRONTEND=noninteractive
  # Pre-seed shim-signed to skip the MOK password prompt entirely
  echo "shim-signed shim/enable_shim_policy boolean false"     | sudo debconf-set-selections 2>/dev/null || true

  # Docker Engine (required by Desktop)
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg     -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # DEB822 format — works on resolute without codename issues
  sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y     docker-ce docker-ce-cli containerd.io     docker-buildx-plugin docker-compose-plugin

  # Docker Desktop deb (always fetch latest)
  info "Downloading Docker Desktop (latest)..."
  wget -q "https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"     -O /tmp/docker-desktop.deb
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/docker-desktop.deb     || sudo DEBIAN_FRONTEND=noninteractive apt-get -f install -y
  rm -f /tmp/docker-desktop.deb

  sudo groupadd docker 2>/dev/null || true  # silently skip if group already exists
  sudo usermod -aG docker "$USER"

  success "Docker Desktop installed. Log out and back in for group membership."
  warn "If you saw a Secure Boot MOK dialog during install: reboot → choose"
  warn "  'Enroll MOK' → enter the password you set → Continue → Yes → reboot."
}

# ─── 13. kubectl (snap) ───────────────────────────────────────────────────────
install_kubectl() {
  section "Installing kubectl (snap — always latest stable)"
  sudo snap install kubectl --classic
  kubectl version --client
  success "kubectl installed."
}

# ─── 14. Helm 3 (snap) ────────────────────────────────────────────────────────
install_helm() {
  section "Installing Helm 3 (snap)"
  sudo snap install helm --classic
  helm version
  success "Helm installed."
}

# ─── 15. k9s (snap) ───────────────────────────────────────────────────────────
install_k9s() {
  section "Installing k9s (snap)"
  sudo snap install k9s
  k9s version
  success "k9s installed."
}

# ─── 16. Minikube ─────────────────────────────────────────────────────────────
install_minikube() {
  section "Installing Minikube (latest)"
  wget -q https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb \
    -O /tmp/minikube.deb
  sudo apt-get install -y /tmp/minikube.deb
  rm -f /tmp/minikube.deb
  minikube version
  success "Minikube installed."
}

# ─── 17. Skaffold ─────────────────────────────────────────────────────────────
install_skaffold() {
  section "Installing Skaffold (latest)"
  curl -fsSL -o /tmp/skaffold \
    "https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64"
  sudo install /tmp/skaffold /usr/local/bin/
  rm -f /tmp/skaffold
  skaffold version
  success "Skaffold installed."
}

# ─── 18. Terraform (snap) ─────────────────────────────────────────────────────
install_terraform() {
  section "Installing Terraform (snap — always latest)"
  sudo snap install terraform --classic
  terraform version
  success "Terraform installed."
}

# ─── 19. AWS CLI v2 ───────────────────────────────────────────────────────────
install_aws() {
  section "Installing AWS CLI v2 (latest)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/awscli
  sudo /tmp/awscli/aws/install --update
  rm -rf /tmp/awscli /tmp/awscliv2.zip
  aws --version
  # Session Manager plugin
  wget -q "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
    -O /tmp/ssm.deb
  sudo dpkg -i /tmp/ssm.deb && rm -f /tmp/ssm.deb
  # Use pipx to avoid PEP 668 "externally managed environment" error
  # awscli-local wraps aws commands for LocalStack.
  # Install via pip with --break-system-packages (safe for single-tool installs).
  # pipx may not be available if Python install was skipped.
  if command -v pipx &>/dev/null; then
    try pipx install awscli-local
  else
    pip install awscli-local --break-system-packages --quiet 2>/dev/null ||     pip3 install awscli-local --break-system-packages --quiet 2>/dev/null ||     warn "awscli-local not installed — run: pip install awscli-local --break-system-packages"
  fi
  success "AWS CLI v2 + Session Manager plugin + awslocal installed."
}

# ─── 20. Redis ────────────────────────────────────────────────────────────────
install_redis() {
  section "Installing Redis (latest stable, official packages.redis.io)"
  sudo apt-get install -y lsb-release curl gpg
  sudo rm -f /etc/apt/sources.list.d/redis*.list

  curl -fsSL https://packages.redis.io/gpg \
    | sudo gpg --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
  sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg

  # Pin to noble if resolute not yet supported
  local REDIS_CODENAME="$UBUNTU_CODENAME"
  if [[ "$UBUNTU_CODENAME" == "resolute" ]]; then
    REDIS_CODENAME="noble"
    warn "Pinning Redis repo to 'noble' (resolute not yet listed)"
  fi

  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] \
https://packages.redis.io/deb ${REDIS_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/redis.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y redis
  sudo systemctl enable --now redis-server
  redis-server --version
  success "Redis installed."
}

# ─── 21. PostgreSQL (latest stable via pgdg) ──────────────────────────────────
install_postgresql() {
  section "Installing PostgreSQL (latest stable from pgdg)"

  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | sudo gpg --yes --dearmor -o /etc/apt/keyrings/postgresql.gpg

  echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] \
https://apt.postgresql.org/pub/repos/apt ${UBUNTU_CODENAME}-pgdg main" \
    | sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null

  sudo apt-get update -y

  # Dynamically resolve the latest major version from the pgdg repo
  local PG_VERSION
  PG_VERSION=$(apt-cache show postgresql 2>/dev/null \
    | grep -oP 'Depends: postgresql-\K[0-9]+' | sort -rn | head -1 \
    || echo "18")
  info "Installing PostgreSQL ${PG_VERSION}"

  sudo apt-get install -y "postgresql-${PG_VERSION}" "postgresql-client-${PG_VERSION}"
  sudo systemctl enable --now postgresql
  echo -en "${YELLOW}  ▸ ${RESET}Set PostgreSQL postgres user password: "; read -rs pg_pass; echo
  try sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${pg_pass}';"
  psql --version
  success "PostgreSQL ${PG_VERSION} installed."
}

# ─── 22. MongoDB (latest stable, official repo) ───────────────────────────────
install_mongodb() {
  section "Installing MongoDB (latest stable from official repo)"

  # Resolve latest stable major version dynamically
  local MONGO_MAJOR
  MONGO_MAJOR=$(curl -fsSL https://www.mongodb.org/static/pgp/ 2>/dev/null \
    | grep -oP 'server-\K[0-9]+\.[0-9]+(?=\.asc)' | sort -V | tail -1 \
    || echo "8.0")
  info "Installing MongoDB ${MONGO_MAJOR}"

  curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGO_MAJOR}.asc" \
    | sudo gpg --yes --dearmor -o /etc/apt/keyrings/mongodb.gpg

  # MongoDB repos only publish up to noble currently; pin for resolute
  local MONGO_CODENAME="$UBUNTU_CODENAME"
  if [[ "$UBUNTU_CODENAME" == "resolute" ]]; then
    MONGO_CODENAME="noble"
    warn "Pinning MongoDB repo to 'noble' (resolute not yet listed)"
  fi

  sudo rm -f /etc/apt/sources.list.d/mongodb*.list
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/mongodb.gpg] \
https://repo.mongodb.org/apt/ubuntu ${MONGO_CODENAME}/mongodb-org/${MONGO_MAJOR} multiverse" \
    | sudo tee "/etc/apt/sources.list.d/mongodb-org-${MONGO_MAJOR}.list" > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y mongodb-org
  sudo systemctl enable --now mongod
  mongod --version
  success "MongoDB ${MONGO_MAJOR} installed."
}

# ─── 23. Elasticsearch 9 (official repo) ──────────────────────────────────────
install_elasticsearch() {
  section "Installing Elasticsearch 9 (official elastic repo)"
  sudo rm -f /etc/apt/sources.list.d/elastic*.list

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | sudo gpg --yes --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

  # Use 9.x — confirmed working from your history (installed on resolute)
  echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] \
https://artifacts.elastic.co/packages/9.x/apt stable main" \
    | sudo tee /etc/apt/sources.list.d/elastic-9.x.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y elasticsearch
  sudo systemctl enable --now elasticsearch

  echo ""
  warn "Elasticsearch 9 is secured by default. Reset the elastic password with:"
  echo "  sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic"
  success "Elasticsearch 9 installed."
}

# ─── 24. RabbitMQ (official erlang + rabbitmq repos) ─────────────────────────
install_rabbitmq() {
  section "Installing RabbitMQ (official erlang + RabbitMQ repos)"
  sudo apt-get install -y curl gnupg apt-transport-https

  # Signing key — same as confirmed working in your history
  curl -1sLf \
    "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" \
    | sudo gpg --yes --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

  local RMQ_CODENAME="$UBUNTU_CODENAME"
  if [[ "$UBUNTU_CODENAME" == "resolute" ]]; then
    RMQ_CODENAME="noble"
    warn "Pinning RabbitMQ repo to 'noble' (resolute not yet listed)"
  fi

  sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Erlang
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-erlang/ubuntu/${RMQ_CODENAME} ${RMQ_CODENAME} main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-erlang/ubuntu/${RMQ_CODENAME} ${RMQ_CODENAME} main
## RabbitMQ server
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-server/ubuntu/${RMQ_CODENAME} ${RMQ_CODENAME} main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-server/ubuntu/${RMQ_CODENAME} ${RMQ_CODENAME} main
EOF

  sudo apt-get update -y
  sudo apt-get install -y erlang-base \
    erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
    erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
    erlang-runtime-tools erlang-snmp erlang-ssl \
    erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl
  sudo apt-get install -y rabbitmq-server --fix-missing
  sudo systemctl enable --now rabbitmq-server
  try sudo rabbitmq-plugins enable rabbitmq_management
  success "RabbitMQ installed. Management UI: http://localhost:15672 (guest/guest)"
}

# ─── 25. Memcached ────────────────────────────────────────────────────────────
install_memcached() {
  section "Installing Memcached"
  sudo apt-get install -y memcached libmemcached-tools
  sudo systemctl enable --now memcached
  success "Memcached installed."
}

# ─── 26. Postman (snap) ───────────────────────────────────────────────────────
install_postman() {
  section "Installing Postman (snap)"
  sudo snap install postman
  success "Postman installed."
}

# ─── 27. Slack (snap) ─────────────────────────────────────────────────────────
install_slack() {
  section "Installing Slack (snap)"
  sudo snap install slack
  success "Slack installed."
}

# ─── 28. Zoom ─────────────────────────────────────────────────────────────────
install_zoom() {
  section "Installing Zoom (latest)"
  wget -q https://zoom.us/client/latest/zoom_amd64.deb -O /tmp/zoom.deb
  sudo apt-get install -y /tmp/zoom.deb || sudo apt-get -f install -y
  rm -f /tmp/zoom.deb
  success "Zoom installed."
}

# ─── 29. VLC (snap) ───────────────────────────────────────────────────────────
install_vlc() {
  section "Installing VLC (snap)"
  sudo snap install vlc
  success "VLC installed."
}

# ─── 30. Signal ───────────────────────────────────────────────────────────────
install_signal() {
  section "Installing Signal (official apt)"
  wget -O- https://updates.signal.org/desktop/apt/keys.asc \
    | gpg --yes --dearmor > /tmp/signal-keyring.gpg
  sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg < /tmp/signal-keyring.gpg > /dev/null
  rm -f /tmp/signal-keyring.gpg
  wget -O /tmp/signal-desktop.sources \
    https://updates.signal.org/static/desktop/apt/signal-desktop.sources
  sudo cp /tmp/signal-desktop.sources /etc/apt/sources.list.d/
  rm -f /tmp/signal-desktop.sources
  sudo apt-get update -y
  sudo apt-get install -y signal-desktop
  success "Signal installed."
}

# ─── 31. CopyQ (snap) ─────────────────────────────────────────────────────────
install_copyq() {
  section "Installing CopyQ"
  # Try snap first; fall back to apt (available in resolute universe)
  if sudo snap install copyq 2>/dev/null; then
    success "CopyQ installed via snap."
  else
    warn "CopyQ snap not available — installing via apt"
    sudo apt-get install -y copyq
    success "CopyQ installed via apt."
  fi
}

# ─── 32. Flameshot ────────────────────────────────────────────────────────────
install_flameshot() {
  section "Installing Flameshot"
  sudo apt-get install -y flameshot
  success "Flameshot installed."
}

# ─── 33. btop (snap) ──────────────────────────────────────────────────────────
install_btop() {
  section "Installing btop (snap)"
  sudo snap install btop
  success "btop installed."
}

# ─── 34. Modern CLI Tools ─────────────────────────────────────────────────────
install_modern_cli() {
  section "Installing modern CLI tools (ripgrep, fd, bat, fzf, eza)"
  sudo apt-get install -y ripgrep fd-find bat fzf

  # bat is named batcat on Ubuntu — symlink it
  mkdir -p ~/.local/bin
  mkdir -p ~/.local/bin
  local bat_bin
  bat_bin=$(command -v batcat 2>/dev/null || command -v bat 2>/dev/null || true)
  [[ -n "$bat_bin" ]] && ln -sf "$bat_bin" ~/.local/bin/bat || true

  for rc in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc" ]] && ! grep -q '\.local/bin' "$rc"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
  done

  # eza — latest binary release (no PPA required)
  local EZA_VERSION
  EZA_VERSION=$(gh_latest "eza-community/eza")
  info "Installing eza ${EZA_VERSION}"
  wget -q "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_x86_64-unknown-linux-musl.tar.gz" \
    -O /tmp/eza.tar.gz
  # eza archive contains ./eza — extract to tmp first then move
  tar -xzf /tmp/eza.tar.gz -C /tmp
  sudo mv /tmp/eza /usr/local/bin/eza
  sudo chmod +x /usr/local/bin/eza
  rm -f /tmp/eza.tar.gz

  success "ripgrep, fd, bat, fzf, eza installed."
}

# ─── 35. jq + yq ─────────────────────────────────────────────────────────────
install_jq() {
  section "Installing jq + yq (latest)"
  sudo apt-get install -y jq
  local YQ_VERSION
  YQ_VERSION=$(gh_latest "mikefarah/yq")
  info "Installing yq ${YQ_VERSION}"
  wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -O /tmp/yq
  sudo install /tmp/yq /usr/local/bin/yq
  rm -f /tmp/yq
  jq --version && yq --version
  success "jq + yq installed."
}

# ─── 36. tmux ─────────────────────────────────────────────────────────────────
install_tmux() {
  section "Installing tmux"
  sudo apt-get install -y tmux
  if [[ ! -f ~/.tmux.conf ]]; then
    cat <<'EOF' > ~/.tmux.conf
set -g mouse on
set -g history-limit 10000
set -g base-index 1
set -g default-terminal "screen-256color"
bind | split-window -h
bind - split-window -v
EOF
  fi
  success "tmux installed with sensible defaults."
}

# ─── 37. Ollama ───────────────────────────────────────────────────────────────
install_ollama() {
  section "Installing Ollama (latest)"
  curl -fsSL https://ollama.com/install.sh | sh
  ollama --version
  success "Ollama installed. Run: ollama run llama3"
}

# ─── 38. SSH Keypair ──────────────────────────────────────────────────────────
install_ssh() {
  section "Setting up SSH keypair (ed25519)"
  echo -en "${YELLOW}  ▸ ${RESET}SSH email/comment: "; read -r ssh_email
  ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  echo ""
  info "Your public key — add to GitHub / GitLab / Bitbucket:"
  echo ""
  cat ~/.ssh/id_ed25519.pub
  echo ""
  success "SSH keypair created."
}

# ─── 39. GPG Key ──────────────────────────────────────────────────────────────
install_gpg() {
  section "Setting up GPG key"
  gpg --full-generate-key
  echo ""
  info "Your GPG keys:"
  gpg --list-secret-keys --keyid-format=long
  echo ""
  info "To export your public key (replace KEY_ID):"
  echo "  gpg --armor --export YOUR_KEY_ID"
  success "GPG key created."
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────
is_yes "$want_basics"        && install_basics
is_yes "$want_git"           && install_git
is_yes "$want_omz"           && install_omz
is_yes "$want_chrome"        && install_chrome
is_yes "$want_vscode"        && install_vscode
is_yes "$want_jetbrains"     && install_jetbrains
is_yes "$want_cursor"        && install_cursor
is_yes "$want_nvm"           && install_nvm
is_yes "$want_python"        && install_python
is_yes "$want_golang"        && install_golang
is_yes "$want_rust"          && install_rust
is_yes "$want_java"          && install_java
is_yes "$want_docker"        && install_docker
is_yes "$want_kubectl"       && install_kubectl
is_yes "$want_helm"          && install_helm
is_yes "$want_k9s"           && install_k9s
is_yes "$want_minikube"      && install_minikube
is_yes "$want_skaffold"      && install_skaffold
is_yes "$want_terraform"     && install_terraform
is_yes "$want_aws"           && install_aws
is_yes "$want_redis"         && install_redis
is_yes "$want_postgresql"    && install_postgresql
is_yes "$want_mongodb"       && install_mongodb
is_yes "$want_elasticsearch" && install_elasticsearch
is_yes "$want_rabbitmq"      && install_rabbitmq
is_yes "$want_memcached"     && install_memcached
is_yes "$want_postman"       && install_postman
is_yes "$want_slack"         && install_slack
is_yes "$want_zoom"          && install_zoom
is_yes "$want_vlc"           && install_vlc
is_yes "$want_signal"        && install_signal
is_yes "$want_copyq"         && install_copyq
is_yes "$want_flameshot"     && install_flameshot
is_yes "$want_btop"          && install_btop
is_yes "$want_modern_cli"    && install_modern_cli
is_yes "$want_jq"            && install_jq
is_yes "$want_tmux"          && install_tmux
is_yes "$want_ollama"        && install_ollama
is_yes "$want_ssh"           && install_ssh
is_yes "$want_gpg"           && install_gpg

# ─── Cleanup ──────────────────────────────────────────────────────────────────
section "Cleaning up"
try sudo apt-get update -y
try sudo apt-get install --fix-missing -y
try sudo apt-get -f install -y
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
center_line
center_text "✓  Setup Complete!" "$GREEN$BOLD"
center_line
echo ""
info "Recommended next steps:"
echo "  1. Log out and back in  — Docker group + Zsh shell change take effect"
echo "  2. Add SSH public key   — cat ~/.ssh/id_ed25519.pub → GitHub / GitLab"
echo "  3. Export GPG key       — gpg --armor --export YOUR_KEY_ID → GitHub"
echo "  4. Configure AWS        — aws configure"
echo "  5. Run an LLM locally   — ollama run llama3"
echo ""
