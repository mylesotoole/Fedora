#!/bin/bash

# Make sure script is run as root
[ "$EUID" -ne 0 ] && {
    echo "This script must be run as root."
    exit 1
}

# Set Visual Studio Code as default text editor
sudo tee /etc/xdg/mimeapps.list <<EOF
[Default Applications]
text/plain=code.desktop
EOF

# Start Steam minimized at login
sudo tee /etc/xdg/autostart/steam.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Steam
Exec=flatpak run com.valvesoftware.Steam -silent
StartupNotify=false
Terminal=false
EOF

# Start Discord minimized at login
sudo tee /etc/xdg/autostart/discord.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Discord
Exec=flatpak run com.discordapp.Discord --start-minimized
StartupNotify=false
Terminal=false
EOF

# Configure GNOME settings
sudo tee /etc/dconf/db/local.d/custom <<EOF
# Dark mode by default
[org/gnome/desktop/interface]
color-scheme='prefer-dark'

# Minimize and maximize buttons
[org/gnome/desktop/wm/preferences]
button-layout=':minimize,maximize,close'

# System tray
[org/gnome/shell/extensions/appindicator]
legacy-tray-enabled=false
[org/gnome/shell]
enabled-extensions=['background-logo@fedorahosted.org', 'appindicatorsupport@rgcjonas.gmail.com']

# Privacy
[org/gnome/system/location]
enabled=false
[org/gnome/desktop/privacy]
remember-recent-files=false
remove-old-trash-files=true
remove-old-temp-files=true
remember-app-usage=false
hide-identity=true
old-files-age=uint32 7
[org/gnome/desktop/notifications]
show-in-lock-screen=false
EOF

# Update GNOME settings
sudo dconf update
sudo dconf reset -f /

# Enable third party repos
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
for repo_file in /etc/yum.repos.d/*{rpmfusion,google,PyCharm}*.repo; do
    sudo sed -i 's/^enabled=0/enabled=1/' "$repo_file"
done

# Enable Visual Studio Code repo
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

# Remove unwanted packages
remove_packages=(
    mediawriter
    rhythmbox
    simple-scan
    snapshot
    baobab
    yelp
    gnome-calendar
    gnome-calculator
    gnome-connections
    gnome-contacts
    gnome-tour
    gnome-boxes
    gnome-characters
    gnome-system-monitor
    gnome-weather
    gnome-maps
    gnome-clocks
    gnome-font-viewer
    libreoffice-calc
    libreoffice-impress
    libreoffice-writer
    gnome-logs
    gnome-abrt
    gnome-color-manager
    gnome-text-editor
    firefox
)
sudo dnf -y remove "${remove_packages[@]}"

# Refresh software store
sudo pkill gnome-software

# Install Flatpak and configure applications
install_flatpaks=(
    com.valvesoftware.Steam
    com.discordapp.Discord
    com.spotify.Client
    org.mozilla.firefox
    io.github.shiftey.Desktop
)
for flatpak in "${install_flatpaks[@]}"; do
    sudo flatpak -y install flathub "$flatpak"
done

# Configure Flatpak overides
sudo flatpak override --filesystem=home com.discordapp.Discord
sudo flatpak override --filesystem=/mnt com.valvesoftware.Steam

# Update system
sudo dnf -y upgrade && sudo dnf -y autoremove

# Remove unwanted packages
install_packages=(
    code
    gnome-shell-extension-appindicator
    akmod-nvidia
    gnome-session-xsession
)
sudo dnf -y install "${install_packages[@]}"

# Disable Wayland for NVIDIA
sudo sed -i '/^#WaylandEnable=false$/s/^#//' /etc/gdm/custom.conf

# Reboot to apply changes
sudo reboot
