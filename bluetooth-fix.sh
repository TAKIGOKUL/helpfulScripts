#!/bin/bash

# Ubuntu Bluetooth Troubleshooting Script
# Diagnoses and fixes common Bluetooth adapter issues in Ubuntu

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

step() {
    echo -e "${CYAN}Step $1:${NC} $2"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# System information
show_system_info() {
    header "System Information"
    
    log "Ubuntu version: $(lsb_release -d | cut -f2)"
    log "Kernel version: $(uname -r)"
    log "Architecture: $(uname -m)"
    echo
}

# Step 1: Check hardware detection
check_hardware() {
    header "Step 1: Hardware Detection"
    
    step 1 "Checking USB devices for Bluetooth adapters"
    
    # Check lsusb for Bluetooth devices
    bluetooth_usb=$(lsusb | grep -i bluetooth || true)
    if [[ -n "$bluetooth_usb" ]]; then
        success "USB Bluetooth adapter detected:"
        echo -e "${GREEN}$bluetooth_usb${NC}"
    else
        warn "No USB Bluetooth adapter found in lsusb output"
    fi
    
    # Check PCI devices for built-in Bluetooth
    bluetooth_pci=$(lspci | grep -i bluetooth || true)
    if [[ -n "$bluetooth_pci" ]]; then
        success "PCI Bluetooth adapter detected:"
        echo -e "${GREEN}$bluetooth_pci${NC}"
    else
        warn "No PCI Bluetooth adapter found in lspci output"
    fi
    
    # Check dmesg for Bluetooth messages
    step 1 "Checking kernel messages for Bluetooth"
    bluetooth_dmesg=$(dmesg | grep -i bluetooth | tail -5 || true)
    if [[ -n "$bluetooth_dmesg" ]]; then
        log "Recent Bluetooth kernel messages:"
        echo -e "${CYAN}$bluetooth_dmesg${NC}"
    else
        warn "No Bluetooth messages found in kernel log"
    fi
    
    echo
}

# Step 2: Check rfkill status
check_rfkill() {
    header "Step 2: Radio Kill Switch Status"
    
    step 2 "Checking rfkill status"
    
    if command -v rfkill &> /dev/null; then
        rfkill_output=$(rfkill list)
        echo -e "${CYAN}$rfkill_output${NC}"
        
        # Check if Bluetooth is blocked
        if echo "$rfkill_output" | grep -i bluetooth | grep -q "blocked: yes"; then
            warn "Bluetooth is blocked by rfkill"
            
            read -p "Do you want to unblock Bluetooth? (y/N): " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                log "Unblocking Bluetooth..."
                sudo rfkill unblock bluetooth
                sudo rfkill unblock all
                success "Bluetooth unblocked"
            fi
        else
            success "Bluetooth is not blocked by rfkill"
        fi
    else
        warn "rfkill command not found. Installing..."
        sudo apt update && sudo apt install -y rfkill
    fi
    
    echo
}

# Step 3: Check Bluetooth service
check_bluetooth_service() {
    header "Step 3: Bluetooth Service Status"
    
    step 3 "Checking bluetooth.service status"
    
    service_status=$(systemctl is-active bluetooth || true)
    service_enabled=$(systemctl is-enabled bluetooth || true)
    
    log "Service status: $service_status"
    log "Service enabled: $service_enabled"
    
    if [[ "$service_status" != "active" ]]; then
        warn "Bluetooth service is not active"
        
        read -p "Do you want to start the Bluetooth service? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log "Starting Bluetooth service..."
            sudo systemctl start bluetooth
            sudo systemctl enable bluetooth
            success "Bluetooth service started and enabled"
        fi
    else
        success "Bluetooth service is running"
    fi
    
    # Show detailed service status
    step 3 "Detailed service information"
    systemctl status bluetooth --no-pager -l
    
    echo
}

# Step 4: Check kernel modules
check_kernel_modules() {
    header "Step 4: Kernel Modules"
    
    step 4 "Checking loaded Bluetooth kernel modules"
    
    bluetooth_modules=$(lsmod | grep -E "(bluetooth|btusb|btintel|btrtl|btbcm)" || true)
    if [[ -n "$bluetooth_modules" ]]; then
        success "Bluetooth kernel modules loaded:"
        echo -e "${GREEN}$bluetooth_modules${NC}"
    else
        warn "No Bluetooth kernel modules found"
        
        read -p "Do you want to load Bluetooth kernel modules? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log "Loading Bluetooth kernel modules..."
            sudo modprobe bluetooth
            sudo modprobe btusb
            success "Bluetooth kernel modules loaded"
        fi
    fi
    
    echo
}

# Step 5: Check hci devices
check_hci_devices() {
    header "Step 5: HCI Device Status"
    
    step 5 "Checking HCI devices"
    
    if command -v hciconfig &> /dev/null; then
        hci_output=$(hciconfig -a || true)
        if [[ -n "$hci_output" ]]; then
            success "HCI devices found:"
            echo -e "${GREEN}$hci_output${NC}"
        else
            warn "No HCI devices found"
        fi
    else
        warn "hciconfig not found. Installing bluez..."
        sudo apt update && sudo apt install -y bluez
    fi
    
    # Try bluetoothctl
    step 5 "Checking with bluetoothctl"
    if command -v bluetoothctl &> /dev/null; then
        log "Bluetoothctl list output:"
        timeout 5 bluetoothctl list || warn "bluetoothctl timed out or failed"
    fi
    
    echo
}

# Step 6: Check /sys/class/bluetooth
check_sys_bluetooth() {
    header "Step 6: System Bluetooth Directory"
    
    step 6 "Checking /sys/class/bluetooth"
    
    if [[ -d /sys/class/bluetooth ]]; then
        bluetooth_devices=$(ls /sys/class/bluetooth/ 2>/dev/null || true)
        if [[ -n "$bluetooth_devices" ]]; then
            success "Bluetooth devices found in /sys/class/bluetooth:"
            echo -e "${GREEN}$bluetooth_devices${NC}"
        else
            warn "/sys/class/bluetooth exists but is empty"
        fi
    else
        error "/sys/class/bluetooth does not exist - no Bluetooth support loaded"
    fi
    
    echo
}

# Step 7: Power management fix
power_management_fix() {
    header "Step 7: Power Management Issues"
    
    step 7 "Attempting power management fixes"
    
    read -p "Do you want to try power management fixes? This may help with resume issues (y/N): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Performing power flush (shutdown and AC disconnect simulation)..."
        warn "This will restart the Bluetooth service and reload modules"
        
        # Stop Bluetooth service
        sudo systemctl stop bluetooth
        
        # Remove and reload btusb module
        sudo rmmod btusb 2>/dev/null || true
        sleep 2
        sudo modprobe btusb
        
        # Restart Bluetooth service
        sudo systemctl start bluetooth
        
        # Unblock any RF kills
        sudo rfkill unblock all
        
        success "Power management fix applied"
    fi
    
    echo
}

# Step 8: Install/reinstall Bluetooth packages
reinstall_bluetooth() {
    header "Step 8: Bluetooth Package Management"
    
    step 8 "Checking installed Bluetooth packages"
    
    packages=("bluez" "bluez-tools" "blueman" "pulseaudio-module-bluetooth")
    missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        warn "Missing packages: ${missing_packages[*]}"
        
        read -p "Do you want to install missing Bluetooth packages? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log "Installing missing packages..."
            sudo apt update
            sudo apt install -y "${missing_packages[@]}"
            success "Packages installed"
        fi
    else
        success "All essential Bluetooth packages are installed"
        
        read -p "Do you want to reinstall Bluetooth packages to fix corruption? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log "Reinstalling Bluetooth packages..."
            sudo apt update
            sudo apt install --reinstall -y bluez bluez-tools
            success "Packages reinstalled"
        fi
    fi
    
    echo
}

# Step 9: BIOS/UEFI recommendations
bios_recommendations() {
    header "Step 9: BIOS/UEFI Settings"
    
    step 9 "BIOS/UEFI recommendations"
    
    echo -e "${YELLOW}If the above steps didn't work, try these BIOS/UEFI fixes:${NC}"
    echo "1. Reboot and enter BIOS/UEFI setup"
    echo "2. Look for Bluetooth settings (usually under 'Advanced' or 'Integrated Peripherals')"
    echo "3. Disable Bluetooth, save and exit"
    echo "4. Reboot, enter BIOS/UEFI again"
    echo "5. Re-enable Bluetooth, save and exit"
    echo "6. Boot back into Ubuntu"
    echo
    echo -e "${YELLOW}Also check for:${NC}"
    echo "• Fast Boot (disable it)"
    echo "• Secure Boot (may need to be disabled)"
    echo "• USB Legacy Support (enable it)"
    echo "• Power Management settings for USB devices"
    
    echo
}

# Step 10: Generate diagnostic report
generate_report() {
    header "Step 10: Diagnostic Report"
    
    step 10 "Generating diagnostic report"
    
    report_file="bluetooth_diagnostic_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Ubuntu Bluetooth Diagnostic Report"
        echo "Generated on: $(date)"
        echo "=================================="
        echo
        
        echo "System Information:"
        echo "- Ubuntu: $(lsb_release -d | cut -f2)"
        echo "- Kernel: $(uname -r)"
        echo "- Architecture: $(uname -m)"
        echo
        
        echo "Hardware Detection:"
        echo "- USB Devices:"
        lsusb | grep -i bluetooth || echo "  No USB Bluetooth devices found"
        echo "- PCI Devices:"
        lspci | grep -i bluetooth || echo "  No PCI Bluetooth devices found"
        echo
        
        echo "RF Kill Status:"
        rfkill list || echo "rfkill not available"
        echo
        
        echo "Service Status:"
        systemctl status bluetooth --no-pager || echo "Service status unavailable"
        echo
        
        echo "Kernel Modules:"
        lsmod | grep -E "(bluetooth|btusb|btintel|btrtl|btbcm)" || echo "No Bluetooth modules loaded"
        echo
        
        echo "HCI Configuration:"
        hciconfig -a 2>/dev/null || echo "No HCI devices found"
        echo
        
        echo "Bluetoothctl List:"
        timeout 5 bluetoothctl list 2>/dev/null || echo "bluetoothctl failed or timed out"
        echo
        
        echo "System Bluetooth Directory:"
        if [[ -d /sys/class/bluetooth ]]; then
            ls -la /sys/class/bluetooth/ || echo "Directory exists but listing failed"
        else
            echo "/sys/class/bluetooth does not exist"
        fi
        echo
        
        echo "Recent Kernel Messages:"
        dmesg | grep -i bluetooth | tail -10 || echo "No Bluetooth kernel messages"
        
    } > "$report_file"
    
    success "Diagnostic report saved to: $report_file"
    log "You can share this file when seeking help on forums"
    
    echo
}

# Main troubleshooting function
main() {
    header "Ubuntu Bluetooth Troubleshooting Tool"
    
    log "This script will diagnose and attempt to fix Bluetooth adapter issues"
    log "Some steps may require sudo privileges"
    echo
    
    check_root
    show_system_info
    check_hardware
    check_rfkill
    check_bluetooth_service
    check_kernel_modules
    check_hci_devices
    check_sys_bluetooth
    power_management_fix
    reinstall_bluetooth
    bios_recommendations
    generate_report
    
    header "Troubleshooting Complete"
    
    log "If Bluetooth is still not working:"
    echo "1. Try the BIOS/UEFI recommendations above"
    echo "2. Reboot your system completely (not just restart)"
    echo "3. Check if your hardware is supported on Linux"
    echo "4. Consider using an external USB Bluetooth adapter"
    echo "5. Share the diagnostic report on Ubuntu forums for help"
    
    success "Troubleshooting session completed!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
