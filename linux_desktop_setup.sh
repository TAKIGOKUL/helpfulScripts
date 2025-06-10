#!/bin/bash

# Linux Desktop Setup Script
# Comprehensive setup for Debian-based and Arch-based distributions
# Author: Assistant
# Version: 2.0

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Global variables
DISTRO_TYPE=""
PACKAGE_MANAGER=""
INSTALL_LOG="/tmp/desktop_setup.log"

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to print header
print_header() {
    echo
    print_color $BLUE "╔═══════════════════════════════════════════════════════════════╗"
    printf "${BLUE}║${WHITE}${BOLD}%63s${NC}${BLUE}║${NC}\n" "$1"
    print_color $BLUE "╚═══════════════════════════════════════════════════════════════╝"
    echo
}

# Function to print success message
print_success() {
    print_color $GREEN "✅ $1"
}

# Function to print error message
print_error() {
    print_color $RED "❌ $1"
}

# Function to print warning
print_warning() {
    print_color $YELLOW "⚠️  $1"
}

# Function to print info
print_info() {
    print_color $CYAN "ℹ️  $1"
}

# Function to detect distribution
detect_distro() {
    print_header "Detecting Linux Distribution"
    
    if command -v pacman &> /dev/null; then
        DISTRO_TYPE="arch"
        PACKAGE_MANAGER="pacman"
        print_success "Arch-based distribution detected"
    elif command -v apt &> /dev/null; then
        DISTRO_TYPE="debian"
        PACKAGE_MANAGER="apt"
        print_success "Debian-based distribution detected"
    else
        print_error "Unsupported distribution! This script supports Debian-based and Arch-based distributions only."
        exit 1
    fi
    
    # Display system information
    print_info "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    print_info "Kernel: $(uname -r)"
    print_info "Architecture: $(uname -m)"
}

# Function to confirm distribution choice
confirm_distro() {
    print_header "Distribution Confirmation"
    
    echo "Detected distribution type: $DISTRO_TYPE"
    echo
    print_color $YELLOW "Please confirm your distribution type:"
    echo "1. 🐧 Debian-based (Ubuntu, Linux Mint, Pop!_OS, Elementary, etc.)"
    echo "2. 🏹 Arch-based (Arch Linux, Manjaro, EndeavourOS, Garuda, etc.)"
    echo "3. 🚪 Exit"
    echo
    
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            DISTRO_TYPE="debian"
            PACKAGE_MANAGER="apt"
            print_success "Debian-based distribution selected"
            ;;
        2)
            DISTRO_TYPE="arch"
            PACKAGE_MANAGER="pacman"
            print_success "Arch-based distribution selected"
            ;;
        3)
            print_color $GREEN "Goodbye! 👋"
            exit 0
            ;;
        *)
            print_error "Invalid choice!"
            confirm_distro
            ;;
    esac
}

# Function to setup Chaotic AUR (Arch only)
setup_chaotic_aur() {
    print_header "Setting up Chaotic AUR"
    
    if [[ "$DISTRO_TYPE" != "arch" ]]; then
        print_warning "Chaotic AUR is only available for Arch-based distributions"
        return 1
    fi
    
    print_info "Setting up Chaotic AUR repository..."
    
    # Step 1: Retrieve primary key
    print_color $CYAN "🔑 Step 1: Retrieving primary key..."
    if sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; then
        print_success "Primary key retrieved successfully"
    else
        print_error "Failed to retrieve primary key"
        return 1
    fi
    
    # Step 2: Sign the key
    print_color $CYAN "🔏 Step 2: Signing the key..."
    if sudo pacman-key --lsign-key 3056513887B78AEB; then
        print_success "Key signed successfully"
    else
        print_error "Failed to sign key"
        return 1
    fi
    
    # Step 3: Install keyring and mirrorlist
    print_color $CYAN "📦 Step 3: Installing Chaotic keyring and mirrorlist..."
    if sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'; then
        print_success "Chaotic keyring and mirrorlist installed"
    else
        print_error "Failed to install keyring and mirrorlist"
        return 1
    fi
    
    # Step 4: Add to pacman.conf
    print_color $CYAN "⚙️  Step 4: Configuring pacman.conf..."
    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
        print_success "Chaotic AUR repository added to pacman.conf"
    else
        print_warning "Chaotic AUR already configured in pacman.conf"
    fi
    
    # Step 5: System update
    print_color $CYAN "🔄 Step 5: Updating system and syncing repositories..."
    if sudo pacman -Syu --noconfirm; then
        print_success "System updated successfully"
        print_success "Chaotic AUR setup completed! 🎉"
    else
        print_error "System update failed"
        return 1
    fi
}

# Function to install package managers (Debian)
install_package_managers_debian() {
    print_header "Installing Package Managers (Debian)"
    
    # Update package list
    print_info "Updating package list..."
    sudo apt update
    
    # Install apt-transport-https and curl
    print_info "Installing prerequisites..."
    sudo apt install -y apt-transport-https curl wget gpg software-properties-common
    
    # Install flatpak
    print_info "Installing Flatpak..."
    if sudo apt install -y flatpak; then
        print_success "Flatpak installed"
        # Add Flathub repository
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        print_success "Flathub repository added"
    else
        print_error "Failed to install Flatpak"
    fi
    
    # Install snapd
    print_info "Installing Snapd..."
    if sudo apt install -y snapd; then
        print_success "Snapd installed"
        # Enable snapd service
        sudo systemctl enable --now snapd.socket
        print_success "Snapd service enabled"
    else
        print_error "Failed to install Snapd"
    fi
    
    print_success "Package managers setup completed!"
}

# Function to install applications
install_applications() {
    print_header "Installing Applications"
    
    local apps_to_install=()
    
    echo "Select applications to install:"
    echo "1. 🌐 Brave Browser"
    echo "2. 💾 Balena Etcher"
    echo "3. 💻 Visual Studio Code"
    echo "4. 💬 Telegram Desktop"
    echo "5. 📧 Rambox"
    echo "6. 📱 Flutter SDK"
    echo "7. 🎨 Install All"
    echo "8. ⏭️  Skip Application Installation"
    echo
    
    read -p "Enter your choices (comma-separated, e.g., 1,3,4): " app_choices
    
    if [[ "$app_choices" == "8" ]]; then
        print_info "Skipping application installation"
        return 0
    fi
    
    if [[ "$app_choices" == "7" ]]; then
        app_choices="1,2,3,4,5,6"
    fi
    
    IFS=',' read -ra CHOICES <<< "$app_choices"
    
    for choice in "${CHOICES[@]}"; do
        case $choice in
            1) install_brave ;;
            2) install_balena ;;
            3) install_vscode ;;
            4) install_telegram ;;
            5) install_rambox ;;
            6) install_flutter ;;
            *) print_warning "Invalid choice: $choice" ;;
        esac
    done
}

# Function to install Brave Browser
install_brave() {
    print_info "Installing Brave Browser..."
    
    if [[ "$DISTRO_TYPE" == "debian" ]]; then
        # Add Brave repository
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        sudo apt update
        sudo apt install -y brave-browser
    elif [[ "$DISTRO_TYPE" == "arch" ]]; then
        # Install via AUR or Chaotic AUR
        if command -v yay &> /dev/null; then
            yay -S --noconfirm brave-bin
        elif grep -q "chaotic-aur" /etc/pacman.conf; then
            sudo pacman -S --noconfirm brave-bin
        else
            print_warning "AUR helper or Chaotic AUR needed for Brave installation"
        fi
    fi
    
    if command -v brave &> /dev/null || command -v brave-browser &> /dev/null; then
        print_success "Brave Browser installed successfully"
    else
        print_error "Failed to install Brave Browser"
    fi
}

# Function to install Balena Etcher
install_balena() {
    print_info "Installing Balena Etcher..."
    
    if [[ "$DISTRO_TYPE" == "debian" ]]; then
        # Install via AppImage or Flatpak
        if command -v flatpak &> /dev/null; then
            flatpak install -y flathub io.balena.etcher
        else
            print_warning "Installing Balena Etcher via download..."
            wget -O /tmp/balena-etcher.AppImage "https://github.com/balena-io/etcher/releases/latest/download/balenaEtcher-*-x64.AppImage"
            chmod +x /tmp/balena-etcher.AppImage
            sudo mv /tmp/balena-etcher.AppImage /usr/local/bin/balena-etcher
        fi
    elif [[ "$DISTRO_TYPE" == "arch" ]]; then
        if command -v yay &> /dev/null; then
            yay -S --noconfirm balena-etcher
        else
            print_warning "AUR helper needed for Balena Etcher installation"
        fi
    fi
    
    print_success "Balena Etcher installation attempted"
}

# Function to install Visual Studio Code
install_vscode() {
    print_info "Installing Visual Studio Code..."
    
    if [[ "$DISTRO_TYPE" == "debian" ]]; then
        # Add Microsoft repository
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
        sudo apt update
        sudo apt install -y code
    elif [[ "$DISTRO_TYPE" == "arch" ]]; then
        if command -v yay &> /dev/null; then
            yay -S --noconfirm visual-studio-code-bin
        elif grep -q "chaotic-aur" /etc/pacman.conf; then
            sudo pacman -S --noconfirm visual-studio-code-bin
        else
            print_warning "AUR helper or Chaotic AUR needed for VS Code installation"
        fi
    fi
    
    if command -v code &> /dev/null; then
        print_success "Visual Studio Code installed successfully"
    else
        print_error "Failed to install Visual Studio Code"
    fi
}

# Function to install Telegram Desktop
install_telegram() {
    print_info "Installing Telegram Desktop..."
    
    if [[ "$DISTRO_TYPE" == "debian" ]]; then
        if command -v flatpak &> /dev/null; then
            flatpak install -y flathub org.telegram.desktop
        else
            sudo apt install -y telegram-desktop
        fi
    elif [[ "$DISTRO_TYPE" == "arch" ]]; then
        sudo pacman -S --noconfirm telegram-desktop
    fi
    
    print_success "Telegram Desktop installation attempted"
}

# Function to install Rambox
install_rambox() {
    print_info "Installing Rambox..."
    
    if command -v flatpak &> /dev/null; then
        flatpak install -y flathub org.rambox.Rambox
        print_success "Rambox installed via Flatpak"
    else
        print_warning "Flatpak not available. Rambox installation skipped."
    fi
}

# Function to install Flutter SDK
install_flutter() {
    print_info "Installing Flutter SDK..."
    
    local flutter_dir="$HOME/development/flutter"
    
    # Create development directory
    mkdir -p "$HOME/development"
    
    # Download Flutter
    if [[ ! -d "$flutter_dir" ]]; then
        print_info "Downloading Flutter SDK..."
        git clone https://github.com/flutter/flutter.git "$flutter_dir"
    else
        print_warning "Flutter directory already exists, updating..."
        cd "$flutter_dir" && git pull
    fi
    
    # Add to PATH
    if ! grep -q "flutter/bin" "$HOME/.bashrc"; then
        echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> "$HOME/.bashrc"
        print_success "Flutter added to PATH in .bashrc"
    fi
    
    if ! grep -q "flutter/bin" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> "$HOME/.zshrc" 2>/dev/null || true
    fi
    
    # Export for current session
    export PATH="$PATH:$HOME/development/flutter/bin"
    
    print_success "Flutter SDK installed. Run 'flutter doctor' to check setup."
}

# Function to download wallpaper collections
download_wallpapers() {
    print_header "Downloading Wallpaper Collections"
    
    local wallpaper_dir="$HOME/Pictures/Wallpapers"
    mkdir -p "$wallpaper_dir"
    
    echo "Select wallpaper collections to download:"
    echo "1. 🎨 Minimalistic Wallpapers"
    echo "2. 🌈 Aesthetic Wallpapers"
    echo "3. 📥 Download Both"
    echo "4. ⏭️  Skip Wallpaper Download"
    echo
    
    read -p "Enter your choice (1-4): " wallpaper_choice
    
    case $wallpaper_choice in
        1|3)
            print_info "Downloading Minimalistic Wallpaper Collection..."
            git clone https://github.com/DenverCoder1/minimalistic-wallpaper-collection.git "$wallpaper_dir/minimalistic-wallpapers"
            print_success "Minimalistic wallpapers downloaded"
            ;&
        2|3)
            if [[ "$wallpaper_choice" == "2" ]] || [[ "$wallpaper_choice" == "3" ]]; then
                print_info "Downloading Aesthetic Wallpapers..."
                git clone https://github.com/D3Ext/aesthetic-wallpapers.git "$wallpaper_dir/aesthetic-wallpapers"
                print_success "Aesthetic wallpapers downloaded"
            fi
            ;;
        4)
            print_info "Skipping wallpaper download"
            return 0
            ;;
        *)
            print_error "Invalid choice!"
            ;;
    esac
    
    if [[ "$wallpaper_choice" != "4" ]]; then
        print_success "Wallpapers downloaded to: $wallpaper_dir"
        print_info "You can set wallpapers from your desktop environment's settings"
    fi
}

# Function to show Linux distribution websites
show_distro_websites() {
    while true; do
        print_header "Linux Distribution Resources"
        
        echo "Select distribution category:"
        echo "1. 🍃 Debian-based Distributions"
        echo "2. 🏹 Arch-based Distributions"
        echo "3. 🔙 Back to Main Menu"
        echo
        
        read -p "Enter your choice (1-3): " distro_menu_choice
        
        case $distro_menu_choice in
            1) show_debian_websites ;;
            2) show_arch_websites ;;
            3) return 0 ;;
            *) print_error "Invalid choice!" ;;
        esac
    done
}

# Function to show Debian-based distribution websites
show_debian_websites() {
    print_header "Debian-based Distributions"
    
    echo "🍃 Popular Debian-based Linux Distributions:"
    echo
    echo "1.  Elementary OS          - https://elementary.io/"
    echo "2.  Kali Linux            - https://www.kali.org/get-kali/#kali-platforms"
    echo "3.  Linux Mint            - https://linuxmint.com/download.php"
    echo "4.  Pop!_OS               - https://system76.com/pop/download/"
    echo "5.  Raspberry Pi OS       - https://www.raspberrypi.com/software/operating-systems/"
    echo "6.  Ubuntu Desktop        - https://ubuntu.com/download/desktop"
    echo "7.  Ubuntu Flavors        - https://ubuntu.com/desktop/flavors"
    echo "8.  Zorin OS              - https://zorin.com/os/download/"
    echo
    
    echo "Select a distribution to open its website:"
    read -p "Enter number (1-8) or 'b' for back: " choice
    
    case $choice in
        1) xdg-open "https://elementary.io/" 2>/dev/null ;;
        2) xdg-open "https://www.kali.org/get-kali/#kali-platforms" 2>/dev/null ;;
        3) xdg-open "https://linuxmint.com/download.php" 2>/dev/null ;;
        4) xdg-open "https://system76.com/pop/download/" 2>/dev/null ;;
        5) xdg-open "https://www.raspberrypi.com/software/operating-systems/" 2>/dev/null ;;
        6) xdg-open "https://ubuntu.com/download/desktop" 2>/dev/null ;;
        7) xdg-open "https://ubuntu.com/desktop/flavors" 2>/dev/null ;;
        8) xdg-open "https://zorin.com/os/download/" 2>/dev/null ;;
        b|B) return 0 ;;
        *) print_error "Invalid choice!" ;;
    esac
    
    if [[ "$choice" =~ ^[1-8]$ ]]; then
        print_success "Opening website in your default browser..."
    fi
}

# Function to show Arch-based distribution websites
show_arch_websites() {
    print_header "Arch-based Distributions"
    
    echo "🏹 Popular Arch-based Linux Distributions:"
    echo
    echo "1.  Archcraft             - https://archcraft.io/download.html"
    echo "2.  CachyOS               - https://cachyos.org/download/"
    echo "3.  EndeavourOS           - https://endeavouros.com/"
    echo "4.  Fedora                - https://www.fedoraproject.org/"
    echo "5.  Garuda Linux          - https://garudalinux.org/editions"
    echo "6.  Manjaro               - https://manjaro.org/products/download/x86"
    echo
    
    echo "Select a distribution to open its website:"
    read -p "Enter number (1-6) or 'b' for back: " choice
    
    case $choice in
        1) xdg-open "https://archcraft.io/download.html" 2>/dev/null ;;
        2) xdg-open "https://cachyos.org/download/" 2>/dev/null ;;
        3) xdg-open "https://endeavouros.com/" 2>/dev/null ;;
        4) xdg-open "https://www.fedoraproject.org/" 2>/dev/null ;;
        5) xdg-open "https://garudalinux.org/editions" 2>/dev/null ;;
        6) xdg-open "https://manjaro.org/products/download/x86" 2>/dev/null ;;
        b|B) return 0 ;;
        *) print_error "Invalid choice!" ;;
    esac
    
    if [[ "$choice" =~ ^[1-6]$ ]]; then
        print_success "Opening website in your default browser..."
    fi
}

# Function to show main menu
show_main_menu() {
    clear
    print_color $PURPLE "╔═══════════════════════════════════════════════════════════════╗"
    print_color $PURPLE "║                                                               ║"
    print_color $PURPLE "║${WHITE}${BOLD}              🚀 LINUX DESKTOP SETUP WIZARD 🚀               ${NC}${PURPLE}║"
    print_color $PURPLE "║                                                               ║"
    print_color $PURPLE "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # Show detected system info
    if [[ -n "$DISTRO_TYPE" ]]; then
        print_color $CYAN "🖥️  Detected System: $DISTRO_TYPE-based distribution"
        print_color $CYAN "📦 Package Manager: $PACKAGE_MANAGER"
    fi
    
    echo
    print_color $WHITE "${BOLD}SETUP OPTIONS:${NC}"
    echo
    print_color $GREEN "  1.  🔍 Detect/Confirm Distribution Type"
    
    if [[ "$DISTRO_TYPE" == "arch" ]]; then
        print_color $BLUE "  2.  🏹 Setup Chaotic AUR (Arch only)"
    else
        print_color $GRAY "  2.  🏹 Setup Chaotic AUR (Arch only) - Not Available"
    fi
    
    if [[ "$DISTRO_TYPE" == "debian" ]]; then
        print_color $YELLOW "  3.  📦 Install Package Managers (Flatpak, Snapd)"
    else
        print_color $GRAY "  3.  📦 Install Package Managers (Debian only) - Not Available"
    fi
    
    print_color $PURPLE "  4.  💻 Install Applications"
    print_color $CYAN "  5.  🎨 Download Wallpaper Collections"
    
    echo
    print_color $WHITE "${BOLD}RESOURCES:${NC}"
    print_color $BLUE "  6.  🌐 Linux Distribution Websites"
    
    echo
    print_color $WHITE "${BOLD}SYSTEM:${NC}"
    print_color $RED "  7.  🚪 Exit"
    
    echo
    print_color $WHITE "${BOLD}Enter your choice (1-7): ${NC}"
}

# Main program loop
main() {
    # Create log file
    touch "$INSTALL_LOG"
    
    # Initial distribution detection
    detect_distro
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) 
                detect_distro
                confirm_distro
                ;;
            2)
                if [[ "$DISTRO_TYPE" == "arch" ]]; then
                    setup_chaotic_aur
                else
                    print_error "Chaotic AUR is only available for Arch-based distributions!"
                fi
                ;;
            3)
                if [[ "$DISTRO_TYPE" == "debian" ]]; then
                    install_package_managers_debian
                else
                    print_error "Package manager setup is only needed for Debian-based distributions!"
                fi
                ;;
            4) install_applications ;;
            5) download_wallpapers ;;
            6) show_distro_websites ;;
            7)
                print_color $GREEN "🎉 Thank you for using Linux Desktop Setup Wizard!"
                print_info "Setup log saved to: $INSTALL_LOG"
                exit 0
                ;;
            *)
                print_error "Invalid choice! Please enter a number between 1-7."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..." -r
    done
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root!"
    print_info "Run as a regular user. The script will ask for sudo when needed."
    exit 1
fi

# Run main program
main "$@"
