#!/bin/bash

# Function to download a file with user confirmation
download_with_confirmation() {
    local url=$1
    local filename=$2

    read -p "Do you want to download $filename from $url? (y/n): " confirmation
    if [[ $confirmation == "y" ]]; then
        echo "Downloading $filename..."
        curl -L -# -o "$filename" "$url"
        echo "$filename downloaded successfully."
	echo
	echo
    else
        echo "Skipping $filename."
	echo
	echo
    fi
}


# Function to run a script directly from a URL with user confirmation
run_script_with_confirmation() {
    local url=$1

    read -p "Do you want to run the script from $url? (y/n): " confirmation
    if [[ $confirmation == "y" ]]; then
        echo "Running the script from $url..."
        /bin/bash -c "$(curl -fsSL $url)"
        echo "Script executed successfully."
	echo
	echo
    else
        echo "Skipping the script from $url."
	echo
	echo
    fi
}


# URLs for each application
chrome_url="https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
stats_url="https://github.com/exelban/stats/releases/latest/download/Stats.dmg"
google_drive_url="https://dl.google.com/drive-file-stream/GoogleDrive.dmg"
jetbrains_url="https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.28.1.15219.dmg"
whatsapp_url="https://web.whatsapp.com/desktop/mac/files/WhatsApp.dmg"
telegram_url="https://telegram.org/dl/desktop/mac"
signal_url="https://updates.signal.org/desktop/signal-desktop-mac-universal-7.13.0.dmg"
skype_url="https://go.skype.com/mac.download"
vscode_url="https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64"
kaspersky_url="https://pdc1.fra5.pdc.kaspersky.com/DownloadManagers/e2/e2b52382-93cc-4a28-8cb3-cfdad7d75070/Kaspersky.dmg"
postman_url="https://dl.pstmn.io/download/latest/osx_arm64"
wps_url="https://wdl1.pcfg.cache.wpscdn.com/wpsdl/macwpsoffice/download/installer/WPS_Office_Installer_0024.21300041.zip"
notion_url="https://www.notion.so/desktop/mac/download"
vlc_url="https://get.videolan.org/vlc/3.0.21/macosx/vlc-3.0.21-arm64.dmg"
zoom_url="https://zoom.us/client/latest/Zoom.pkg"
postgresql_url="https://get.enterprisedb.com/postgresql/postgresql-16.3-1-osx.dmg"
ohmyzsh_url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
anaconda_url="https://repo.anaconda.com/archive/Anaconda3-2023.03-MacOSX-x86_64.pkg"
iterm2_url="https://iterm2.com/downloads/stable/iTerm2-3_4_19.zip"
chrome_canary_url="https://dl.google.com/chrome/mac/universal/canary/googlechromecanary.dmg"
anydesk_url="https://download.anydesk.com/anydesk.dmg"
segate_url="https://www.seagate.com/content/dam/seagate/migrated-assets/www-content/support-content/software/toolkit/_Shared/master/SeagateToolkit.zip"

# Downloading each application with user confirmation
download_with_confirmation "$stats_url" "Stats.dmg"
download_with_confirmation "$chrome_url" "GoogleChrome.dmg"
download_with_confirmation "$google_drive_url" "GoogleDrive.dmg"
download_with_confirmation "$jetbrains_url" "JetBrainsToolbox.dmg"
download_with_confirmation "$whatsapp_url" "WhatsApp.dmg"
download_with_confirmation "$telegram_url" "Telegram.dmg"
download_with_confirmation "$signal_url" "Signal.dmg"
download_with_confirmation "$skype_url" "Skype.dmg"
download_with_confirmation "$vscode_url" "VSCode.dmg"
download_with_confirmation "$kaspersky_url" "Kaspersky.dmg"
download_with_confirmation "$postman_url" "Postman.dmg"
download_with_confirmation "$wps_url" "WPS_Office_Installer_0024.21300041.zip"
download_with_confirmation "$notion_url" "Notion.dmg"
download_with_confirmation "$vlc_url" "VLC.dmg"
download_with_confirmation "$zoom_url" "Zoom.pkg"
download_with_confirmation "$postgresql_url" "PostgreSQL.dmg"
download_with_confirmation "$anaconda_url" "Anaconda.pkg"
download_with_confirmation "$iterm2_url" "iTerm2.zip"
download_with_confirmation "$chrome_canary_url" "ChromeCanary.dmg"
download_with_confirmation "$anydesk_url" "AnyDesk.dmg"
download_with_confirmation "$segate_url" "SeagateToolkit.zip"

# Running the script with user confirmation
run_script_with_confirmation "$ohmyzsh_url"

echo "All downloads completed."



echo
echo
echo


#!/bin/bash

# Function to generate an ed25519 SSH key
generate_ssh_key() {
    local email=$1
    local key_path="$HOME/.ssh/id_ed25519_github"

    # Check if the key already exists
    if [[ -f "$key_path" ]]; then
        echo
        echo "An SSH key already exists at $key_path."
        read -p "Do you want to overwrite it? (y/n): " overwrite
        if [[ $overwrite != "y" ]]; then
            echo "Aborting the SSH key generation."
            return
        fi
        # Backup existing key
        mv "$key_path" "$key_path.backup.$(date +%s)"
        echo "Existing key backed up to $key_path.backup."
    fi

    echo
    echo "Generating a new ed25519 SSH key for GitHub..."
    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""

    if [[ $? -ne 0 ]]; then
        echo "Failed to generate SSH key."
        exit 1
    fi

    echo
    echo "SSH key generated successfully."
}

# Function to display the SSH public key
display_public_key() {
    local key_path="$HOME/.ssh/id_ed25519_github.pub"
    echo
    echo "Your new SSH public key is:"
    echo
    echo "####################################################################################################################"
    cat "$key_path"
    echo "####################################################################################################################"
    echo
    echo "Copy the above key and add it to your GitHub account under SSH and GPG keys."
}

# Function to add the SSH key to the SSH agent
add_key_to_ssh_agent() {
    local key_path="$HOME/.ssh/id_ed25519_github"

    echo
    echo "Adding your SSH private key to the SSH agent..."
    eval "$(ssh-agent -s)"
    ssh-add "$key_path"

    if [[ $? -ne 0 ]]; then
        echo "Failed to add SSH key to the SSH agent."
        exit 1
    fi

    echo "SSH key added to the SSH agent successfully."
}

# Prompt the user for their email
echo
read -p "Enter your GitHub email address: " github_email

# Generate the SSH key
generate_ssh_key "$github_email"

# Display the public key
display_public_key

# Add the SSH key to the SSH agent
add_key_to_ssh_agent

echo
echo "All done! You can now use this SSH key with GitHub."


