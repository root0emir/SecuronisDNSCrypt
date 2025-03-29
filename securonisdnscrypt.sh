#!/bin/bash

# Securonis Linux - DNSCrypt Manager

set -e  

# ASCII Art Function
ascii_art() {
    cat << "EOF"
________                                     _____           
__  ___/______________  ________________________(_)_______   
_____ \_  _ \  ___/  / / /_  ___/  __ \_  __ \_  /__  ___/   
____/ //  __/ /__ / /_/ /_  /   / /_/ /  / / /  / _(__  )    
/____/ \___/\___/ \__,_/ /_/    \____//_/ /_//_/  /____/     
                                                             
_____________   _________________                      _____ 
___  __ \__  | / /_  ___/_  ____/___________  ___________  /_
__  / / /_   |/ /_____ \_  /    __  ___/_  / / /__  __ \  __/
_  /_/ /_  /|  / ____/ // /___  _  /   _  /_/ /__  /_/ / /_  
/_____/ /_/ |_/  /____/ \____/  /_/    _\__, / _  .___/\__/  
                                       /____/  /_/               
EOF
}

# Menu Function
menu() {
    ascii_art
    echo -e "\e[32m[Securonis Linux - DNSCrypt Manager]\e[0m"
    echo "1) Enable DNS Encryption"
    echo "2) Disable DNS Encryption"
    echo "3) Check DNS Status"
    echo "4) Exit"
}

# Enable DNSCrypt
enable_dnscrypt() {
    echo "[+] Installing DNSCrypt..."
    sudo apt update
    sudo apt install -y dnscrypt-proxy

    echo "[+] Configuring DNSCrypt..."
    CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    sudo bash -c "cat > $CONFIG_FILE" <<EOF
server_names = ['cloudflare', 'quad9']
listen_addresses = ['127.0.2.1:53']
max_clients = 250
ipv4_servers = true
ipv6_servers = false
dnscrypt_servers = true
doh_servers = false
require_dnssec = true
EOF

    echo "[+] Starting DNSCrypt service..."
    sudo systemctl enable dnscrypt-proxy
    sudo systemctl restart dnscrypt-proxy

    echo "[+] Updating system DNS settings..."
    sudo sed -i '/^nameserver/d' /etc/resolv.conf
    sudo bash -c "echo 'nameserver 127.0.2.1' >> /etc/resolv.conf"

    if command -v nmcli &>/dev/null; then
        active_connection=$(nmcli -t -f UUID con show --active)
        sudo nmcli connection modify "$active_connection" ipv4.dns "127.0.2.1"
        sudo nmcli connection modify "$active_connection" ipv4.ignore-auto-dns yes
        sudo systemctl restart NetworkManager
    fi

    echo "[✔] DNSCrypt has been successfully enabled!"
}

# Disable DNSCrypt without removing the package
disable_dnscrypt() {
    echo "[!] Disabling DNS Encryption..."
    sudo systemctl stop dnscrypt-proxy
    sudo systemctl disable dnscrypt-proxy

    echo "[+] Restoring default DNS settings..."
    sudo sed -i '/^nameserver/d' /etc/resolv.conf
    sudo bash -c "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"

    if command -v nmcli &>/dev/null; then
        active_connection=$(nmcli -t -f UUID con show --active)
        sudo nmcli connection modify "$active_connection" ipv4.dns "8.8.8.8"
        sudo nmcli connection modify "$active_connection" ipv4.ignore-auto-dns no
        sudo systemctl restart NetworkManager
    fi

    echo "[✔] DNS Encryption has been disabled!"
}

# Check DNS Status
check_status() {
    echo "[+] DNSCrypt Service Status:"
    sudo systemctl status dnscrypt-proxy | grep "Active:"

    echo "[+] DNS Resolution Test:"
    dig google.com +short
}

# Main Menu Loop
while true; do
    menu
    read -p "Enter your choice: " choice

    case $choice in
        1) enable_dnscrypt ;;
        2) disable_dnscrypt ;;
        3) check_status ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice! Please select a valid option.";;
    esac

    echo -e "\nPress any key to continue..."
    read -n 1 -s -r
done
