#!/bin/bash

# Frigate Snapshot Upload Script - Clean Version

# Default configuration file path
CONFIG_FILE="${CONFIG_FILE:-./frigate_config.conf}"

# Global variables
CAPTURED_FILENAME=""
CAPTURE_RESULT=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE:-./frigate_snapshot.log}"
}

# Function to capture snapshot for a specific camera
capture_snapshot() {
    local camera_name="$1"
    local filename="${camera_name}.jpg"
    local filepath="$OUTPUT_DIR/$filename"

    log "Capturing snapshot for camera: $camera_name"

    mkdir -p "$OUTPUT_DIR" || {
        log "Failed to create output directory: $OUTPUT_DIR"
        CAPTURED_FILENAME=""
        return 1
    }

    local snap_url="$FRIGATE_URL/api/$camera_name/latest.jpg"
    if curl -s -f -o "$filepath" "$snap_url"; then
        if [ -s "$filepath" ]; then
            CAPTURED_FILENAME="$filepath"
            log "✓ Snapshot captured: $filepath"
            return 0
        else
            log "Downloaded empty snapshot: $filepath"
        fi
    else
        log "Failed to download snapshot from $snap_url"
    fi

    rm -f "$filepath" 2>/dev/null
    CAPTURED_FILENAME=""
    return 1
}


# FTP connection test removed - upload function handles connection testing

# Function to upload file (dispatch based on method)
upload_file() {
    local filepath="$1"
    
    if [ -z "$filepath" ] || [ ! -f "$filepath" ]; then
        log "Error: File not found or path is empty: $filepath"
        return 1
    fi
    
    case "$UPLOAD_METHOD" in
        "HTTP")
            log "HTTP upload not implemented"
            return 1
            ;;
        "FTP"|"SFTP")
            upload_ftp "$filepath" "$UPLOAD_METHOD"
            ;;
        "LOCAL")
            log "Local copy only - skipping upload for $(basename "$filepath")"
            return 0
            ;;
        *)
            log "Error: Unknown upload method: $UPLOAD_METHOD"
            return 1
            ;;
    esac
}


# Function to upload file via FTP/SFTP
upload_ftp() {
    local filepath="$1"
    local protocol="$2"
    local filename=$(basename "$filepath")
    
    log "Uploading $filename via $protocol to $UPLOAD_SERVER:$UPLOAD_REMOTE_PATH"
    
    local attempt=1
    while [ $attempt -le $RETRY_COUNT ]; do
        log "Upload attempt $attempt of $RETRY_COUNT"
        
        # Try using lftp first (more reliable)
        if command -v lftp >/dev/null 2>&1; then
            log "Using lftp for transfer"
            local lftp_output
            if lftp_output=$(lftp -u "$UPLOAD_USERNAME,$UPLOAD_PASSWORD" -p "$UPLOAD_PORT" "$UPLOAD_SERVER" \
                -e "cd $UPLOAD_REMOTE_PATH; put $filepath; quit" 2>&1); then
                if echo "$lftp_output" | grep -q -E "(put:.*succeeded|Transfer complete)"; then
                    log "✓ Successfully uploaded $filename via lftp"
                    return 0
                else
                    log "lftp transfer may have failed - checking output:"
                    echo "$lftp_output" | tail -5 | while IFS= read -r line; do
                        log "  $line"
                    done
                fi
            else
                log "lftp command failed"
                echo "$lftp_output" | tail -5 | while IFS= read -r line; do
                    log "  $line"
                done
            fi
        fi
        
        # Fallback to standard ftp command with corrected syntax
        log "Using standard ftp command as fallback"
        local ftp_script="/tmp/ftp_script_$$.txt"
        local filename=$(basename "$filepath")
        
        # Use printf to properly escape special characters and use correct PUT syntax
        printf '%s\n' "open $UPLOAD_SERVER $UPLOAD_PORT" > "$ftp_script"
        printf '%s\n' "user $UPLOAD_USERNAME $UPLOAD_PASSWORD" >> "$ftp_script"
        printf '%s\n' "binary" >> "$ftp_script"
        printf '%s\n' "passive" >> "$ftp_script"
        printf '%s\n' "cd $UPLOAD_REMOTE_PATH" >> "$ftp_script"
        printf '%s\n' "put \"$filepath\" $filename" >> "$ftp_script"
        printf '%s\n' "ls" >> "$ftp_script"
        printf '%s\n' "quit" >> "$ftp_script"
        
        # Log the FTP script for debugging
        log "FTP Script contents:"
        cat "$ftp_script" | while IFS= read -r line; do
            log "  $line"
        done
        
        # Run FTP with verbose output to log
        log "Running FTP command..."
        local ftp_output
        ftp_output=$(ftp -n -v < "$ftp_script" 2>&1)
        local ftp_result=$?
        
        # Check for specific FTP success and failure patterns
        if echo "$ftp_output" | grep -q -E "(530.*Login authentication failed|530.*not logged in|Connection refused|Connection timed out|No route to host|Unknown host|Authentication failed)"; then
            log "✗ FTP authentication or connection failed"
            log "Error details:"
            echo "$ftp_output" | tail -10 | while IFS= read -r line; do
                log "  $line"
            done
        elif echo "$ftp_output" | grep -q -E "(226.*File successfully transferred|226.*Transfer complete|File successfully transferred)"; then
            log "✓ Successfully uploaded $filename via FTP"
            rm -f "$ftp_script"
            return 0
        elif echo "$ftp_output" | grep -q -E "(530.*Permission denied|Upload failed|Permission denied|Access denied)"; then
            log "✗ FTP upload failed - permission or file error"
        elif [ $ftp_result -eq 0 ]; then
            # Check if uploaded file is now listed in the directory
            local uploaded_filename
            uploaded_filename=$(basename "$filepath")
            if echo "$ftp_output" | grep -q "$uploaded_filename"; then
                log "✓ Successfully uploaded $filename via FTP (file appears in directory listing)"
                rm -f "$ftp_script"
                return 0
            else
                log "✗ FTP completed but file not found in directory listing"
                log "Looking for: $uploaded_filename"
                echo "$ftp_output" | tail -10 | while IFS= read -r line; do
                    log "  $line"
                done
            fi
        else
            log "✗ FTP command failed with exit code: $ftp_result"
            echo "$ftp_output" | tail -5 | while IFS= read -r line; do
                log "  $line"
            done
        fi
        
        rm -f "$ftp_script"
        
        if [ $attempt -lt $RETRY_COUNT ]; then
            log "Retrying in $RETRY_DELAY seconds..."
            sleep "$RETRY_DELAY"
            ((attempt++))
        else
            break
        fi
    done
    
    log "✗ Failed to upload $filename via FTP after $RETRY_COUNT attempts"
    return 1
}

# Function to cleanup old snapshots
cleanup_old_snapshots() {
    if [ "$MAX_FILES" -eq 0 ]; then
        log "MAX_FILES is 0 - skipping cleanup"
        return 0
    fi
    
    log "Cleaning up old snapshots (keeping latest $MAX_FILES files)..."
    
    cd "$OUTPUT_DIR" || return 1
    local file_count=$(ls -1 *.jpg 2>/dev/null | wc -l)
    
    if [ "$file_count" -gt "$MAX_FILES" ]; then
        files_to_remove=$((file_count - MAX_FILES))
        ls -1t *.jpg | tail -n "$files_to_remove" | xargs -r rm -f
        log "Removed $files_to_remove old snapshot files"
    else
        log "No cleanup needed (current files: $file_count, max: $MAX_FILES)"
    fi
    cd - >/dev/null
}

# Function to test Frigate server connection
test_frigate_connection() {
    if curl -s --max-time 10 "$FRIGATE_URL/api/" > /dev/null 2>&1; then
        log "✓ Connection to Frigate server successful"
        return 0
    else
        log "✗ Failed to connect to Frigate server at $FRIGATE_URL"
        return 1
    fi
}

# Function to validate cameras exist
validate_cameras() {
    IFS=',' read -ra camera_array <<< "$SELECTED_CAMERAS"
    local valid_cameras=()
    
    for camera in "${camera_array[@]}"; do
        camera=$(echo "$camera" | xargs)  # Trim whitespace
        if curl -s -f --max-time 10 "$FRIGATE_URL/api/$camera/latest.jpg" > /dev/null 2>&1; then
            valid_cameras+=("$camera")
            log "✓ Camera '$camera' is accessible"
        else
            log "✗ Camera '$camera' not found or not accessible"
        fi
    done
    
    if [ ${#valid_cameras[@]} -eq 0 ]; then
        log "Error: No valid cameras found"
        return 1
    fi
    
    # Update camera_array with only valid cameras
    camera_array=("${valid_cameras[@]}")
    log "Found ${#camera_array[@]} valid cameras: ${camera_array[*]}"
    return 0
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "Error: Configuration file not found: $CONFIG_FILE"
        log "Please run ./frigate_config_builder.sh first to create a configuration"
        exit 1
    fi
    
    log "Loading configuration from: $CONFIG_FILE"
    
    # Source configuration file
    source "$CONFIG_FILE"
    
    # Validate required configuration
    local required_vars=("FRIGATE_URL" "SELECTED_CAMERAS" "OUTPUT_DIR")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log "Error: Missing required configuration variables: ${missing_vars[*]}"
        exit 1
    fi
    
    # Set defaults for optional variables
    MAX_FILES="${MAX_FILES:-50}"
    LOG_FILE="${LOG_FILE:-./frigate_snapshot.log}"
    SCRIPT_TIMEOUT="${SCRIPT_TIMEOUT:-300}"
    RETRY_COUNT="${RETRY_COUNT:-3}"
    RETRY_DELAY="${RETRY_DELAY:-5}"
    UPLOAD_METHOD="${UPLOAD_METHOD:-LOCAL}"
    
    log "Configuration loaded successfully"
}

# Main execution function
main() {
    log "=== Frigate Snapshot Upload Script ==="
    
    # Load configuration
    load_config
    
    # Test connection
    if ! test_frigate_connection; then
        log "Error: Cannot connect to Frigate server"
        exit 1
    fi
    
    # Validate cameras
    if ! validate_cameras; then
        log "Error: Camera validation failed"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Process each camera
    local success_count=0
    local total_count=${#camera_array[@]}
    
    log "Starting snapshot capture for $total_count cameras..."
    
    for camera in "${camera_array[@]}"; do
        log "Processing camera: $camera"
        
        capture_snapshot "$camera"
        capture_result=$?
        
        if [ "$capture_result" -eq 0 ] && [ -n "$CAPTURED_FILENAME" ] && [ -f "$CAPTURED_FILENAME" ]; then
            if upload_file "$CAPTURED_FILENAME"; then
                ((success_count++))
            else
                log "Upload failed for $camera, but snapshot was saved locally"
            fi
        else
            log "Failed to capture snapshot for $camera"
        fi
    done
    
    # Cleanup old files
    cleanup_old_snapshots
    
    # Final summary
    log "Script completed. Successfully processed $success_count/$total_count cameras"
    
    if [ "$success_count" -eq 0 ]; then
        log "Error: No snapshots were successfully captured"
        exit 1
    else
        log "✓ Successfully processed $success_count/$total_count cameras"
    fi
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -c, --config FILE    Specify configuration file (default: ./frigate_config.conf)
  -h, --help          Show this help message
  -t, --test          Test configuration and connection only

Examples:
  $0                                    # Run with default config
  $0 -c /path/to/config.conf           # Use custom config file
  $0 -t --test                            # Test configuration only

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--test)
            TEST_MODE=true
            shift
            ;;
        *)
            log "Unknown option: $1"
            show_help
            exit 0
            ;;
    esac
    shift
done

# Test mode
if [ "$TEST_MODE" = true ]; then
    log "=== Test Mode ==="
    load_config
    test_frigate_connection
    validate_cameras
    log "✓ Test completed successfully"
    exit 0
fi

# Script entry point
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi