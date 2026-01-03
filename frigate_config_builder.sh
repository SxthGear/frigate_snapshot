#!/bin/bash

# Frigate Configuration Builder Script
# This script creates a configuration file for the snapshot upload process

CONFIG_FILE="${CONFIG_FILE:-./frigate_config.conf}"
DEFAULT_OUTPUT_DIR="${DEFAULT_OUTPUT_DIR:-./snapshots}"
DEFAULT_MAX_FILES="${DEFAULT_MAX_FILES:-50}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Function to read existing configuration
load_existing_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    print_color "$BLUE" "Loading existing configuration from: $CONFIG_FILE"
    
    # Parse existing configuration
    local existing_frigate_url=""
    local existing_camera_list=""
    local existing_output_dir=""
    local existing_max_files=""
    local existing_upload_method=""
    local existing_upload_server=""
    local existing_upload_port=""
    local existing_upload_username=""
    local existing_upload_password=""
    local existing_upload_api_key=""
    local existing_upload_remote_path=""
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        if [[ "$line" =~ ^FRIGATE_URL=(.+)$ ]]; then
            existing_frigate_url="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^SELECTED_CAMERAS=(.+)$ ]]; then
            existing_camera_list="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^OUTPUT_DIR=(.+)$ ]]; then
            existing_output_dir="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^MAX_FILES=(.+)$ ]]; then
            existing_max_files="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_METHOD=(.+)$ ]]; then
            existing_upload_method="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_SERVER=(.+)$ ]]; then
            existing_upload_server="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_PORT=(.+)$ ]]; then
            existing_upload_port="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_USERNAME=(.+)$ ]]; then
            existing_upload_username="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_PASSWORD=(.+)$ ]]; then
            existing_upload_password="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_API_KEY=(.+)$ ]]; then
            existing_upload_api_key="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^UPLOAD_REMOTE_PATH=(.+)$ ]]; then
            existing_upload_remote_path="${BASH_REMATCH[1]}"
        fi
    done < "$CONFIG_FILE"
    
    # Set global variables for use as defaults
    DEFAULT_FRIGATE_URL="$existing_frigate_url"
    DEFAULT_CAMERA_LIST="$existing_camera_list"
    DEFAULT_OUTPUT_DIR="$existing_output_dir"
    DEFAULT_MAX_FILES="$existing_max_files"
    DEFAULT_UPLOAD_METHOD="$existing_upload_method"
    DEFAULT_UPLOAD_SERVER="$existing_upload_server"
    DEFAULT_UPLOAD_PORT="$existing_upload_port"
    DEFAULT_UPLOAD_USERNAME="$existing_upload_username"
    DEFAULT_UPLOAD_PASSWORD="$existing_upload_password"
    DEFAULT_UPLOAD_API_KEY="$existing_upload_api_key"
    DEFAULT_UPLOAD_REMOTE_PATH="$existing_upload_remote_path"
    
    return 0
}

# Function to get user input with validation
get_input() {
    local prompt="$1"
    local default="$2"
    local validation="$3"
    local value
    
    while true; do
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " value
            # Use entered value if provided, otherwise use default
            if [ -n "$value" ]; then
                echo "$value"
                return 0
            else
                echo "$default"
                return 0
            fi
        else
            read -p "$prompt: " value
        fi
        
        if [ -z "$value" ] && [ -z "$default" ]; then
            print_color "$RED" "This field is required. Please enter a value."
            continue
        fi
        
        if [ -n "$validation" ]; then
            case "$validation" in
                "url")
                    if [[ "$value" =~ ^https?:// ]]; then
                        echo "$value"
                        return 0
                    else
                        print_color "$RED" "Please enter a valid URL (http:// or https://)"
                    fi
                    ;;
                "number")
                    if [[ "$value" =~ ^[0-9]+$ ]]; then
                        echo "$value"
                        return 0
                    else
                        print_color "$RED" "Please enter a valid number."
                    fi
                    ;;
                *)
                    echo "$value"
                    return 0
                    ;;
            esac
        else
            echo "$value"
            return 0
        fi
    done
}

# Function to test individual camera
test_camera() {
    local frigate_url="$1"
    local camera_name="$2"
    
    print_color "$BLUE" "Testing camera: $camera_name"
    print_color "$BLUE" "URL: $frigate_url/api/$camera_name/latest.jpg"
    
    # Test camera snapshot endpoint
    if response=$(curl -s -w "%{http_code}" --max-time 10 "$frigate_url/api/$camera_name/latest.jpg" 2>/dev/null); then
        http_code="${response: -3}"
        echo "DEBUG: Full response: '$response'"
        echo "DEBUG: HTTP code: $http_code"
        if [ "$http_code" -eq 200 ]; then
            print_color "$GREEN" "✓ Camera $camera_name is accessible"
            return 0
        else
            print_color "$RED" "✗ Camera $camera_name failed. HTTP code: $http_code"
            return 1
        fi
    else
        print_color "$RED" "✗ Failed to connect to camera $camera_name"
        return 1
    fi
}

# Function to test all cameras
test_all_cameras() {
    local frigate_url="$1"
    local camera_list="$2"
    
    print_color "$BLUE" "Testing cameras: $camera_list"
    
    # Convert comma-separated list to array
    IFS=',' read -ra cameras_array <<< "$camera_list"
    
    local valid_cameras=()
    local invalid_cameras=()
    
    for camera in "${cameras_array[@]}"; do
        # Remove whitespace
        camera=$(echo "$camera" | xargs)
        
        if [ -z "$camera" ]; then
            continue
        fi
        
        if test_camera "$frigate_url" "$camera"; then
            valid_cameras+=("$camera")
        else
            invalid_cameras+=("$camera")
        fi
    done
    
    # Show results
    if [ ${#valid_cameras[@]} -gt 0 ]; then
        print_color "$GREEN" "✓ Valid cameras (${#valid_cameras[@]}):"
        for camera in "${valid_cameras[@]}"; do
            echo "  - $camera"
        done
    fi
    
    if [ ${#invalid_cameras[@]} -gt 0 ]; then
        echo ""
        print_color "$RED" "✗ Invalid cameras (${#invalid_cameras[@]}):"
        for camera in "${invalid_cameras[@]}"; do
            echo "  - $camera"
        done
    fi
    
    if [ ${#valid_cameras[@]} -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

# Function to configure HTTP upload
configure_http_upload() {
    local upload_url="${DEFAULT_UPLOAD_SERVER:-}"
    local auth_method="none"
    local username="${DEFAULT_UPLOAD_USERNAME:-}"
    local password="${DEFAULT_UPLOAD_PASSWORD:-}"
    local api_key="${DEFAULT_UPLOAD_API_KEY:-}"
    
    upload_url=$(get_input "Enter upload URL" "$upload_url" "url")
    
    print_color "$BLUE" "Select authentication method:"
    echo "1. No authentication"
    echo "2. Basic auth (username/password)"
    echo "3. API key/Token"
    
    while true; do
        read -p "Select authentication method [1-3]: " auth_choice
        case "$auth_choice" in
            1)
                auth_method="none"
                break
                ;;
            2)
                auth_method="basic"
                username=$(get_input "Enter username" "$username" "")
                password=$(get_input "Enter password" "$password" "")
                break
                ;;
            3)
                auth_method="api_key"
                api_key=$(get_input "Enter API key/token" "$api_key" "")
                break
                ;;
            *)
                print_color "$RED" "Please enter a number between 1 and 3"
                ;;
        esac
    done
    
    # Store for global use
    DEFAULT_UPLOAD_SERVER="$upload_url"
    DEFAULT_UPLOAD_AUTH_METHOD="$auth_method"
    DEFAULT_UPLOAD_USERNAME="$username"
    DEFAULT_UPLOAD_PASSWORD="$password"
    DEFAULT_UPLOAD_API_KEY="$api_key"
}

# Function to configure FTP/SFTP upload
configure_ftp_upload() {
    local protocol="$1"
    local server="${DEFAULT_UPLOAD_SERVER:-}"
    local port="${DEFAULT_UPLOAD_PORT:-}"
    local username="${DEFAULT_UPLOAD_USERNAME:-}"
    local password="${DEFAULT_UPLOAD_PASSWORD:-}"
    local remote_path="${DEFAULT_UPLOAD_REMOTE_PATH:-}"
    
    server=$(get_input "Enter $protocol server address" "$server" "")
    
    # Set default port based on protocol
    local default_port
    if [ "$protocol" = "FTP" ]; then
        default_port="21"
    else
        default_port="22"
    fi
    
    port=$(get_input "Enter $protocol port" "${port:-$default_port}" "number")
    username=$(get_input "Enter username" "$username" "")
    password=$(get_input "Enter password" "$password" "")
    remote_path=$(get_input "Enter remote path" "$remote_path" "/uploads")
    
    # Store for global use
    DEFAULT_UPLOAD_SERVER="$server"
    DEFAULT_UPLOAD_PORT="$port"
    DEFAULT_UPLOAD_USERNAME="$username"
    DEFAULT_UPLOAD_PASSWORD="$password"
    DEFAULT_UPLOAD_REMOTE_PATH="$remote_path"
}

# Function to configure upload method
configure_upload_method() {
    print_color "$CYAN" "Select upload method:"
    echo "1) LOCAL (save files locally only)"
    echo "2) HTTP (upload to HTTP endpoint)"
    echo "3) FTP (upload to FTP server)"
    echo "4) SFTP (upload to SFTP server)"
    
    while true; do
        read -p "Select upload method [1-4]: " method_choice
        case "$method_choice" in
            1)
                UPLOAD_METHOD_CHOICE="LOCAL"
                break
                ;;
            2)
                UPLOAD_METHOD_CHOICE="HTTP"
                configure_http_upload
                break
                ;;
            3)
                UPLOAD_METHOD_CHOICE="FTP"
                configure_ftp_upload "FTP"
                break
                ;;
            4)
                UPLOAD_METHOD_CHOICE="SFTP"
                configure_ftp_upload "SFTP"
                break
                ;;
            *)
                print_color "$RED" "Please enter a number between 1 and 4"
                ;;
        esac
    done
}

# Function to generate configuration file
generate_config() {
    local frigate_url="$1"
    local camera_list_str="$2"
    local output_dir="$3"
    local max_files="$4"
    local upload_method="$5"
    
    print_color "$BLUE" "Generating configuration file: $CONFIG_FILE"
    
    cat > "$CONFIG_FILE" << EOF
# Frigate Snapshot Upload Configuration
# Generated on $(date)

# Frigate server settings
FRIGATE_URL=$frigate_url

# Camera selection (comma-separated list)
SELECTED_CAMERAS=$camera_list_str

# Output settings
OUTPUT_DIR=$output_dir
MAX_FILES=$max_files
LOG_FILE=./frigate_snapshot.log

# Upload configuration
EOF
    
    # Add upload method specific configuration
    case "$upload_method" in
        "HTTP")
            cat << EOF >> "$CONFIG_FILE"
UPLOAD_METHOD="HTTP"
UPLOAD_URL="$DEFAULT_UPLOAD_SERVER"
UPLOAD_AUTH_METHOD="$DEFAULT_UPLOAD_AUTH_METHOD"
EOF
            
            if [ "$DEFAULT_UPLOAD_AUTH_METHOD" = "basic" ]; then
                cat << EOF >> "$CONFIG_FILE"
UPLOAD_USERNAME="$DEFAULT_UPLOAD_USERNAME"
UPLOAD_PASSWORD="$DEFAULT_UPLOAD_PASSWORD"
EOF
            elif [ "$DEFAULT_UPLOAD_AUTH_METHOD" = "api_key" ]; then
                cat << EOF >> "$CONFIG_FILE"
UPLOAD_API_KEY="$DEFAULT_UPLOAD_API_KEY"
EOF
            fi
            ;;
        "FTP"|"SFTP")
            cat << EOF >> "$CONFIG_FILE"
UPLOAD_METHOD="$upload_method"
UPLOAD_SERVER="$DEFAULT_UPLOAD_SERVER"
UPLOAD_PORT="$DEFAULT_UPLOAD_PORT"
UPLOAD_USERNAME="$DEFAULT_UPLOAD_USERNAME"
UPLOAD_PASSWORD="$DEFAULT_UPLOAD_PASSWORD"
UPLOAD_REMOTE_PATH="$DEFAULT_UPLOAD_REMOTE_PATH"
EOF
            ;;
        "LOCAL")
            cat << EOF >> "$CONFIG_FILE"
UPLOAD_METHOD="LOCAL"
EOF
            ;;
    esac
    
    # Add script settings
    cat << EOF >> "$CONFIG_FILE"

# Script settings
SCRIPT_TIMEOUT="300"
RETRY_COUNT="3"
RETRY_DELAY="5"
EOF
    
    print_color "$GREEN" "✓ Configuration file generated successfully"
}

# Function to show current configuration
show_current_config() {
    print_color "$CYAN" "Current configuration:"
    echo "  Frigate URL: ${DEFAULT_FRIGATE_URL:-not set}"
    echo "  Cameras: ${DEFAULT_CAMERA_LIST:-not set}"
    echo "  Output directory: ${DEFAULT_OUTPUT_DIR:-not set}"
    echo "  Max files: ${DEFAULT_MAX_FILES:-not set}"
    echo "  Upload method: ${DEFAULT_UPLOAD_METHOD:-not set}"
    if [ -n "${DEFAULT_UPLOAD_SERVER:-}" ]; then
        echo "  Upload server: ${DEFAULT_UPLOAD_SERVER}"
    fi
    if [ -n "${DEFAULT_UPLOAD_PORT:-}" ] && [ "$DEFAULT_UPLOAD_METHOD" != "HTTP" ]; then
        echo "  Upload port: ${DEFAULT_UPLOAD_PORT}"
    fi
    if [ -n "${DEFAULT_UPLOAD_USERNAME:-}" ] && [ "$DEFAULT_UPLOAD_METHOD" != "HTTP" ]; then
        echo "  Upload username: ${DEFAULT_UPLOAD_USERNAME}"
    fi
    if [ -n "${DEFAULT_UPLOAD_API_KEY:-}" ] && [ "$DEFAULT_UPLOAD_METHOD" = "HTTP" ]; then
        echo "  Upload API key: ${DEFAULT_UPLOAD_API_KEY}"
    fi
    echo "  Upload remote path: ${DEFAULT_UPLOAD_REMOTE_PATH:-not set}"
}

# Function to modify specific configuration item
modify_config_item() {
    local item="$1"
    local description="$2"
    local current_value
    local new_value
    local prompt_text
    
    echo ""
    print_color "$BLUE" "=== Modify Configuration: $description ==="
    echo ""
    
    case "$item" in
        "frigate_url")
            current_value="$DEFAULT_FRIGATE_URL"
            prompt_text="Frigate server URL"
            ;;
        "cameras")
            current_value="$DEFAULT_CAMERA_LIST"
            prompt_text="Camera names (comma-separated)"
            ;;
        "output_dir")
            current_value="$DEFAULT_OUTPUT_DIR"
            prompt_text="Output directory"
            ;;
        "max_files")
            current_value="$DEFAULT_MAX_FILES"
            prompt_text="Maximum files to keep"
            ;;
        "upload_method")
            current_value="$DEFAULT_UPLOAD_METHOD"
            prompt_text="Upload method"
            echo ""
            print_color "$CYAN" "Select new upload method:"
            echo "1) LOCAL (save files locally only)"
            echo "2) HTTP (upload to HTTP endpoint)"
            echo "3) FTP (upload to FTP server)"
            echo "4) SFTP (upload to SFTP server)"
            
            while true; do
                read -p "Select upload method [1-4]: " method_choice
                case "$method_choice" in
                    1)
                        DEFAULT_UPLOAD_METHOD="LOCAL"
                        print_color "$GREEN" "✓ Updated Upload method"
                        return 0
                        ;;
                    2)
                        DEFAULT_UPLOAD_METHOD="HTTP"
                        configure_http_upload
                        print_color "$GREEN" "✓ Updated Upload method"
                        return 0
                        ;;
                    3)
                        DEFAULT_UPLOAD_METHOD="FTP"
                        configure_ftp_upload "FTP"
                        print_color "$GREEN" "✓ Updated Upload method"
                        return 0
                        ;;
                    4)
                        DEFAULT_UPLOAD_METHOD="SFTP"
                        configure_ftp_upload "SFTP"
                        print_color "$GREEN" "✓ Updated Upload method"
                        return 0
                        ;;
                    *)
                        print_color "$RED" "Please enter a number between 1 and 4"
                        ;;
                esac
            done
            ;;
        "ftp_server")
            current_value="$DEFAULT_UPLOAD_SERVER"
            prompt_text="FTP/SFTP server address"
            ;;
        "ftp_port")
            current_value="$DEFAULT_UPLOAD_PORT"
            prompt_text="FTP/SFTP port"
            ;;
        "ftp_credentials")
            current_value="$DEFAULT_UPLOAD_USERNAME"
            prompt_text="FTP/SFTP username"
            ;;
        "ftp_password")
            current_value="$DEFAULT_UPLOAD_PASSWORD"
            prompt_text="FTP/SFTP password"
            ;;
        "remote_path")
            current_value="$DEFAULT_UPLOAD_REMOTE_PATH"
            prompt_text="Remote path"
            ;;
        *)
            print_color "$RED" "Unknown configuration item: $item"
            return 1
            ;;
    esac
    
    if [ "$item" != "upload_method" ]; then
        echo "Current value: ${current_value:-not set}"
        new_value=$(get_input "Enter new $prompt_text" "$current_value" "")
    fi
    
    # Update the appropriate default variable
    case "$item" in
        "frigate_url")
            DEFAULT_FRIGATE_URL="$new_value"
            ;;
        "cameras")
            DEFAULT_CAMERA_LIST="$new_value"
            ;;
        "output_dir")
            DEFAULT_OUTPUT_DIR="$new_value"
            ;;
        "max_files")
            DEFAULT_MAX_FILES="$new_value"
            ;;
        "upload_method")
            DEFAULT_UPLOAD_METHOD="$new_value"
            ;;
        "ftp_server")
            DEFAULT_UPLOAD_SERVER="$new_value"
            ;;
        "ftp_port")
            DEFAULT_UPLOAD_PORT="$new_value"
            ;;
        "ftp_credentials")
            DEFAULT_UPLOAD_USERNAME="$new_value"
            ;;
        "ftp_password")
            DEFAULT_UPLOAD_PASSWORD="$new_value"
            ;;
        "remote_path")
            DEFAULT_UPLOAD_REMOTE_PATH="$new_value"
            ;;
    esac
    
    print_color "$GREEN" "✓ Updated $description"
}

# Function to show main menu
show_main_menu() {
    echo ""
    print_color "$GREEN" "=== Frigate Configuration Menu ==="
    print_color "$CYAN" "1. Show current configuration"
    print_color "$CYAN" "2. Modify configuration"
    print_color "$CYAN" "3. Test cameras"
    print_color "$CYAN" "4. Generate configuration file"
    print_color "$CYAN" "5. Exit"
    echo ""
    read -p "Select option [1-5]: " choice
        
        case "$choice" in
            1)
                show_current_config
                ;;
            2)
                echo ""
                print_color "$CYAN" "Select configuration item to modify:"
                echo "1) Frigate server URL"
                echo "2) Camera names"
                echo "3) Output directory"
                echo "4) Max files"
                echo "5) Upload method"
                echo "6) FTP/SFTP server address"
                echo "7) FTP/SFTP port"
                echo "8) FTP/SFTP username"
                echo "9) FTP/SFTP password"
                echo "10) Remote path"
                read -p "Select item [1-10]: " item_choice
                
                # Strip whitespace and handle empty input
                item_choice=$(echo "$item_choice" | tr -d '[:space:]')
                
                case "$item_choice" in
                    1) modify_config_item "frigate_url" "Frigate server URL" ;;
                    2) modify_config_item "cameras" "Camera names" ;;
                    3) modify_config_item "output_dir" "Output directory" ;;
                    4) modify_config_item "max_files" "Max files" ;;
                    5) modify_config_item "upload_method" "Upload method" ;;
                    6) modify_config_item "ftp_server" "FTP/SFTP server address" ;;
                    7) modify_config_item "ftp_port" "FTP/SFTP port" ;;
                    8) modify_config_item "ftp_credentials" "FTP/SFTP username" ;;
                    9) modify_config_item "ftp_password" "FTP/SFTP password" ;;
                    10) modify_config_item "remote_path" "Remote path" ;;
                    "") print_color "$RED" "No selection made" ;;
                    *) print_color "$RED" "Invalid choice: $item_choice" ;;
                esac
                ;;
            3)
                # Ensure camera list is properly set for testing
                if [ -z "${DEFAULT_CAMERA_LIST:-}" ]; then
                    print_color "$YELLOW" "Warning: No camera list set for testing. Using default cameras."
                    DEFAULT_CAMERA_LIST="front_door,back_yard,garage"
                fi
                test_all_cameras "${DEFAULT_FRIGATE_URL:-http://localhost:5000}" "${DEFAULT_CAMERA_LIST}"
                ;;
            4)
                if [ -z "${DEFAULT_FRIGATE_URL:-}" ] || [ -z "${DEFAULT_CAMERA_LIST:-}" ]; then
                    print_color "$RED" "Error: Frigate URL and cameras must be set before generating configuration"
                else
                    generate_config "${DEFAULT_FRIGATE_URL}" "${DEFAULT_CAMERA_LIST}" "${DEFAULT_OUTPUT_DIR}" "${DEFAULT_MAX_FILES}" "${DEFAULT_UPLOAD_METHOD}"
                fi
                ;;
            5)
                # Save configuration before exiting
                if [ -n "${DEFAULT_FRIGATE_URL:-}" ] && [ -n "${DEFAULT_CAMERA_LIST:-}" ]; then
                    generate_config "${DEFAULT_FRIGATE_URL}" "${DEFAULT_CAMERA_LIST}" "${DEFAULT_OUTPUT_DIR}" "${DEFAULT_MAX_FILES}" "${DEFAULT_UPLOAD_METHOD}"
                fi
                print_color "$GREEN" "Configuration saved. Exiting."
                exit 0
                ;;
            *)
                print_color "$RED" "Invalid choice"
                ;;
        esac
}

# Main configuration process
main() {
    print_color "$GREEN" "=== Frigate Snapshot Upload Configuration Builder ==="
    echo ""
    
    # Check if config file already exists and load it
    if load_existing_config; then
        show_current_config
        echo ""
        print_color "$GREEN" "Configuration loaded successfully!"
        print_color "$BLUE" "Press Enter to continue to main menu..."
        read -p ""
        show_main_menu
    else
        # No existing config, go through setup process
        print_color "$YELLOW" "No existing configuration file found."
        print_color "$CYAN" "Starting initial setup..."
        echo ""
        
        # Step 1: Get camera list from user
        print_color "$BLUE" "Step 1: Enter camera names"
        camera_list=$(get_input "Enter camera names (comma-separated)" "front_door,back_yard,garage")
        
        # Step 2: Get Frigate server location
        echo ""
        print_color "$BLUE" "Step 2: Configure Frigate server"
        frigate_url=$(get_input "Enter Frigate server URL" "http://localhost:5000" "url")
        
        # Step 3: Test all cameras
        echo ""
        print_color "$BLUE" "Step 3: Testing cameras"
        if ! test_all_cameras "$frigate_url" "$camera_list"; then
            print_color "$RED" "Warning: Some cameras failed validation"
            print_color "$YELLOW" "Do you want to continue anyway? (y/n)"
            read -r continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy] ]]; then
                print_color "$YELLOW" "Please check your camera names and Frigate server configuration"
                exit 1
            fi
        fi
        
        # Step 4: Configure output settings
        echo ""
        print_color "$BLUE" "Step 4: Configure output settings"
        output_dir=$(get_input "Enter output directory" "$DEFAULT_OUTPUT_DIR")
        max_files=$(get_input "Enter maximum files to keep (0 for unlimited)" "$DEFAULT_MAX_FILES" "number")
        
        # Step 5: Configure upload method
        echo ""
        print_color "$BLUE" "Step 5: Configure upload method"
        configure_upload_method
        upload_method="$UPLOAD_METHOD_CHOICE"
        
# Generate configuration
    echo ""
    generate_config "$frigate_url" "$camera_list" "$output_dir" "$max_files" "$upload_method"
    
    # Update global variables for display
    DEFAULT_FRIGATE_URL="$frigate_url"
    DEFAULT_CAMERA_LIST="$camera_list"
    DEFAULT_OUTPUT_DIR="$output_dir"
    DEFAULT_MAX_FILES="$max_files"
    DEFAULT_UPLOAD_METHOD="$upload_method"
    
    # Display final summary using updated globals
    echo ""
    print_color "$YELLOW" "Configuration Summary:"
    echo "  Frigate URL: $DEFAULT_FRIGATE_URL"
    echo "  Selected cameras: $DEFAULT_CAMERA_LIST"
    echo "  Output directory: $DEFAULT_OUTPUT_DIR"
    echo "  Max files: $DEFAULT_MAX_FILES"
    echo "  Upload method: $DEFAULT_UPLOAD_METHOD"
        
        echo ""
        print_color "$GREEN" "=== Configuration Complete ==="
        print_color "$BLUE" "Configuration file: $CONFIG_FILE"
        print_color "$BLUE" "Run the upload script with: ./frigate_upload.sh"
        echo ""
        
        # Show configuration summary
        print_color "$YELLOW" "Configuration Summary:"
        echo "  Frigate URL: $frigate_url"
        echo "  Selected cameras: $camera_list"
        echo "  Output directory: $output_dir"
        echo "  Max files: $max_files"
        echo "  Upload method: $upload_method"
    fi
}

# Function to show help
show_help() {
    cat << EOF
Frigate Configuration Builder - Enhanced Configuration Management

Usage: $0 [OPTIONS]

This script helps you create and manage Frigate snapshot upload configurations.

Features:
- Load existing configuration files
- Modify individual configuration items
- Test camera connectivity
- Interactive menu system
- Full validation

Options:
  -h, --help          Show this help message
  -c, --config FILE    Specify configuration file (default: ./frigate_config.conf)

Examples:
  $0                                    # Run with default config file
  $0 -c /path/to/config.conf           # Use custom config file

When run without an existing config file, the script will:
1. Prompt for camera names
2. Prompt for Frigate server URL
3. Test all cameras
4. Prompt for output settings
5. Prompt for upload method configuration
6. Generate configuration file

When run with an existing config file, the script will:
1. Load and display current configuration
2. Provide menu to modify individual items
3. Test camera connectivity
4. Generate updated configuration file

Configuration File Format:
The script generates a configuration file compatible with frigate_upload.sh

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Script entry point
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi