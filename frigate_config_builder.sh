#!/bin/bash

# Frigate Configuration Builder Script
# Interactive menu-based configuration for Frigate snapshot uploads

CONFIG_FILE="config.txt"

# Color codes for UI (if supported)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored text
print_color() {
    local color="$1"
    local text="$2"
    if command -v tput >/dev/null 2>&1 && [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
        echo -e "${color}${text}${NC}"
    else
        echo "$text"
    fi
}

# Function to load existing config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            export "$key"="$value"
        done < "$CONFIG_FILE"
    fi
}

# Function to save config
save_config() {
    {
        echo "FRIGATE_URL=$FRIGATE_URL"
        echo "CAMERAS=$CAMERAS"
        echo "METHOD=$METHOD"
        case $METHOD in
            POST)
                echo "POST_URL=$POST_URL"
                echo "POST_AUTH=$POST_AUTH"
                ;;
            FTP)
                echo "FTP_HOST=$FTP_HOST"
                echo "FTP_USER=$FTP_USER"
                echo "FTP_PASS=$FTP_PASS"
                echo "FTP_PATH=$FTP_PATH"
                echo "EXTERNAL_IP=$EXTERNAL_IP"
                ;;
            SSH)
                echo "SSH_HOST=$SSH_HOST"
                echo "SSH_USER=$SSH_USER"
                echo "SSH_PASS=$SSH_PASS"
                echo "SSH_PATH=$SSH_PATH"
                ;;
            SFTP)
                echo "SFTP_HOST=$SFTP_HOST"
                echo "SFTP_USER=$SFTP_USER"
                echo "SFTP_PASS=$SFTP_PASS"
                echo "SFTP_PATH=$SFTP_PATH"
                ;;
            LOCAL)
                echo "LOCAL_DIR=$LOCAL_DIR"
                ;;
        esac
    } > "$CONFIG_FILE"
}

# Function to configure upload method
configure_method() {
    local method_choice
    print_color "$BLUE" "Select upload method:"
    echo "1) POST"
    echo "2) FTP"
    echo "3) SSH"
    echo "4) SFTP"
    echo "5) LOCAL"
    read -r method_choice

    case $method_choice in
        1)
            METHOD="POST"
            print_color "$GREEN" "Enter POST URL:"
            read -r POST_URL
            print_color "$GREEN" "Enter authentication (if any, e.g., user:pass or leave empty):"
            read -r POST_AUTH
            ;;
        2)
            METHOD="FTP"
            print_color "$GREEN" "Enter FTP host (without ftp://):"
            read -r FTP_HOST
            FTP_HOST=$(echo "$FTP_HOST" | sed 's|^ftp://||; s|/*$||')
            print_color "$GREEN" "Enter FTP username:"
            read -r FTP_USER
            print_color "$GREEN" "Enter FTP password:"
            read -rs FTP_PASS
            echo
            print_color "$GREEN" "Enter FTP upload path (e.g., /uploads/):"
            read -r FTP_PATH
            # Get external IP for FTP PORT command
            print_color "$YELLOW" "Detecting external IP address..."
            EXTERNAL_IP=$(curl -s https://api.ipify.org 2>/dev/null || wget -qO- https://api.ipify.org 2>/dev/null)
            if [[ ! "$EXTERNAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                print_color "$RED" "Warning: Could not detect valid external IP. FTP will use passive mode."
                EXTERNAL_IP="auto"
            else
                print_color "$GREEN" "External IP detected: $EXTERNAL_IP"
            fi
            ;;
        3)
            METHOD="SSH"
            print_color "$GREEN" "Enter SSH host:"
            read -r SSH_HOST
            print_color "$GREEN" "Enter SSH username:"
            read -r SSH_USER
            print_color "$GREEN" "Enter SSH password (or key path if using key authentication):"
            read -rs SSH_PASS
            echo
            print_color "$GREEN" "Enter remote SSH path (e.g., /home/user/uploads/):"
            read -r SSH_PATH
            ;;
        4)
            METHOD="SFTP"
            print_color "$GREEN" "Enter SFTP host:"
            read -r SFTP_HOST
            print_color "$GREEN" "Enter SFTP username:"
            read -r SFTP_USER
            print_color "$GREEN" "Enter SFTP password (or key path if using key authentication):"
            read -rs SFTP_PASS
            echo
            print_color "$GREEN" "Enter remote SFTP path (e.g., /uploads/):"
            read -r SFTP_PATH
            ;;
        5)
            METHOD="LOCAL"
            print_color "$GREEN" "Enter local directory path (e.g., /home/user/images/):"
            read -r LOCAL_DIR
            ;;
        *)
            print_color "$RED" "Invalid choice."
            return 1
            ;;
    esac
}

# Load existing config
load_config

# Main menu loop
while true; do
    clear
    print_color "$BLUE" "=================================="
    print_color "$BLUE" "  Frigate Configuration Builder"
    print_color "$BLUE" "=================================="
    echo
    print_color "$YELLOW" "Current Configuration:"
    echo "Frigate URL: ${FRIGATE_URL:-Not set}"
    echo "Cameras: ${CAMERAS:-Not set}"
    echo "Upload Method: ${METHOD:-Not set}"
    echo
    print_color "$GREEN" "Menu:"
    echo "1) Edit Frigate URL"
    echo "2) Edit Camera Names"
    echo "3) Edit Upload Method"
    echo "4) Save and Exit"
    echo "5) Exit without Saving"
    echo
    read -r choice

    case $choice in
        1)
            print_color "$GREEN" "Enter the Frigate server URL (e.g., http://localhost:5000):"
            read -r FRIGATE_URL
            ;;
        2)
            print_color "$GREEN" "Enter camera names separated by commas (e.g., camera1,camera2,camera3):"
            read -r CAMERAS
            ;;
        3)
            configure_method
            ;;
        4)
            save_config
            print_color "$GREEN" "Configuration saved to $CONFIG_FILE"
            exit 0
            ;;
        5)
            print_color "$YELLOW" "Exiting without saving."
            exit 0
            ;;
        *)
            print_color "$RED" "Invalid option. Please try again."
            sleep 1
            ;;
    esac
done
