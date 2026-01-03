#!/bin/bash

# Frigate Upload Script
# This script reads the configuration file and uploads images from Frigate cameras

CONFIG_FILE="config.txt"

# Spinner function for progress indication
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run command with spinner
run_with_spinner() {
    local cmd="$1"
    local msg="$2"
    echo -n "$msg"
    eval "$cmd" > /dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    local status=$?
    if [ $status -eq 0 ]; then
        echo "✓"
    else
        echo "✗"
        return $status
    fi
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found. Please run the configuration script first."
    exit 1
fi

# Load configuration
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    export "$key"="$value"
done < "$CONFIG_FILE"

# Function to upload file based on method
upload_file() {
    local file_path="$1"
    local filename=$(basename "$file_path")

    case $METHOD in
        POST)
            if [ -z "$POST_URL" ]; then
                echo "Error: POST_URL not configured"
                return 1
            fi
            if [ -n "$POST_AUTH" ]; then
                curl -s -X POST -u "$POST_AUTH" -F "file=@$file_path" "$POST_URL" > /dev/null 2>&1
            else
                curl -s -X POST -F "file=@$file_path" "$POST_URL" > /dev/null 2>&1
            fi
            ;;
        FTP)
            if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ]; then
                echo "Error: FTP_HOST or FTP_USER not configured"
                return 1
            fi
            # Ensure FTP_PATH starts and ends with /
            FTP_PATH=$(echo "$FTP_PATH" | sed 's|^/*||; s|/*$||')  # remove leading/trailing slashes
            if [ -z "$FTP_PATH" ]; then
                FTP_PATH="/"
            else
                FTP_PATH="/$FTP_PATH/"
            fi
            ftp_url="ftp://$FTP_HOST$FTP_PATH$filename"
            curl -s --user "$FTP_USER:$FTP_PASS" -T "$file_path" "$ftp_url" > /dev/null 2>&1
            ;;
        SSH)
            if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
                echo "Error: SSH_HOST or SSH_USER not configured"
                return 1
            fi
            # Assuming password authentication; for key-based, modify accordingly
            sshpass -p "$SSH_PASS" scp "$file_path" "$SSH_USER@$SSH_HOST:$SSH_PATH$filename" > /dev/null 2>&1 2>&1 || {
                echo "Warning: sshpass not available or SSH failed. Ensure SSH key is set up or install sshpass."
                scp "$file_path" "$SSH_USER@$SSH_HOST:$SSH_PATH$filename" > /dev/null 2>&1
            }
            ;;
        SFTP)
            if [ -z "$SFTP_HOST" ] || [ -z "$SFTP_USER" ]; then
                echo "Error: SFTP_HOST or SFTP_USER not configured"
                return 1
            fi
            # Using sftp with password; may require expect for automation
            echo "put $file_path $SFTP_PATH$filename" | sftp -o PasswordAuthentication=yes -o User="$SFTP_USER" -o Password="$SFTP_PASS" "$SFTP_HOST" > /dev/null 2>&1 2>&1 || {
                echo "SFTP upload failed. Ensure sftp is configured properly."
            }
            ;;
        LOCAL)
            if [ -z "$LOCAL_DIR" ]; then
                echo "Error: LOCAL_DIR not configured"
                return 1
            fi
            # Ensure LOCAL_DIR ends with /
            LOCAL_DIR=$(echo "$LOCAL_DIR" | sed 's|/*$|/|')
            cp "$file_path" "$LOCAL_DIR$filename" > /dev/null 2>&1
            ;;
        *)
            echo "Unknown upload method: $METHOD"
            return 1
            ;;
    esac
}

# Process each camera
IFS=',' read -ra CAMERA_ARRAY <<< "$CAMERAS"
for camera in "${CAMERA_ARRAY[@]}"; do
    # Trim whitespace
    camera=$(echo "$camera" | xargs)

    echo "Processing camera: $camera"

    # Create snapshots directory if it doesn't exist
    snapshots_dir="./snapshots"
    mkdir -p "$snapshots_dir"

    # Create file for the snapshot
    snapshot_file="$snapshots_dir/${camera}.jpg"

    # Download latest snapshot from Frigate
    if run_with_spinner "curl -s -o \"$snapshot_file\" \"$FRIGATE_URL/api/$camera/latest.jpg\"" "Downloading snapshot"; then
        echo "Downloaded latest snapshot for camera $camera"
    else
        echo "Error: Failed to download snapshot for camera $camera"
        continue
    fi

    # Check if file exists and has content
    if [ ! -f "$snapshot_file" ] || [ ! -s "$snapshot_file" ]; then
        echo "Error: Downloaded file is empty or missing: $snapshot_file"
        rm -f "$snapshot_file"
        continue
    fi

    # Upload the file
    if run_with_spinner "upload_file \"$snapshot_file\"" "Uploading snapshot"; then
        echo "Upload successful for camera $camera"
    else
        echo "Upload failed for camera $camera"
    fi
done

echo "All cameras processed."
