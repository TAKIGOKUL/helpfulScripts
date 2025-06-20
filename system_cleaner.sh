#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Starting System Cleanup & Optimization...${NC}"

### 1. Clear APT Cache
echo -e "\n${GREEN}🔹 Cleaning APT cache...${NC}"
apt clean
apt autoclean
apt autoremove -y

### 2. Clear Systemd Journal Logs
echo -e "\n${GREEN}🔹 Trimming journal logs...${NC}"
journalctl --vacuum-time=2d
journalctl --vacuum-size=100M

### 3. Clear Thumbnail & User Cache
echo -e "\n${GREEN}🔹 Cleaning thumbnail & user cache...${NC}"
rm -rf ~/.cache/thumbnails/*
rm -rf ~/.cache/*

### 4. Clear Temporary Files
echo -e "\n${GREEN}🔹 Removing temporary files...${NC}"
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /var/crash/*

### 5. Remove Old Kernels & Orphaned Packages
echo -e "\n${GREEN}🔹 Purging old kernels & unused packages...${NC}"
apt purge $(dpkg -l | grep '^rc' | awk '{print $2}') -y
apt autoremove --purge -y

### 6. Clean Snap & Flatpak Cache (if installed)
if command -v snap &> /dev/null; then
    echo -e "\n${GREEN}🔹 Cleaning Snap cache...${NC}"
    snap refresh --list
    rm -rf /var/lib/snapd/cache/*
fi

if command -v flatpak &> /dev/null; then
    echo -e "\n${GREEN}🔹 Cleaning Flatpak cache...${NC}"
    flatpak uninstall --unused -y
fi

### 7. Optimize Swap & SSD (if applicable)
echo -e "\n${GREEN}🔹 Optimizing swap & SSD...${NC}"
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl -p

if command -v fstrim &> /dev/null; then
    fstrim -av
fi

### 8. Install & Enable Preload (for faster app launches)
echo -e "\n${GREEN}🔹 Setting up preload...${NC}"
if ! command -v preload &> /dev/null; then
    apt install preload -y
fi
systemctl enable preload --now

### 9. Show Disk Usage Summary
echo -e "\n${GREEN}🔹 Disk usage summary:${NC}"
df -h | grep -v "tmpfs\|loop"

echo -e "\n${GREEN}✅ System cleanup & optimization complete!${NC}"
