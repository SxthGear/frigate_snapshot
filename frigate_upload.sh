# Frigate Upload Script
# This script reads the configuration file and uploads images from Frigate cameras

VERSION="3.0"
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

# Help and version
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Frigate Upload v$VERSION"
    echo "Downloads or captures snapshots from Frigate/API or RTSP, adds watermarks, and uploads."
    echo ""
    echo "Usage: $0 [--help|-h] [--version|-v]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --version, -v  Show version"
    echo ""
    echo "Run without options to start upload process."
    exit 0
fi

if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "Frigate Upload v$VERSION"
    exit 0
fi

# Dependency check
echo "Checking dependencies..."
deps="curl ffmpeg"
for dep in $deps; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Error: $dep is required but not found."
        exit 1
    fi
done
echo "Dependencies OK."

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

# Retry function
retry_simple() {
    local message="$1"
    local cmd="$2"
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts for $message"
        if eval "$cmd" > /dev/null 2>&1; then
            echo "$message successful"
            return 0
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            sleep 2
        fi
    done
    echo "$message failed after $max_attempts attempts"
    return 1
}

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
            curl -s --user "$FTP_USER:$FTP_PASS" -T "$file_path" "ftp://$FTP_HOST$FTP_PATH$filename" > /dev/null 2>&1
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
total_cameras=${#CAMERA_ARRAY[@]}
current_camera=1
for camera in "${CAMERA_ARRAY[@]}"; do
    # Trim whitespace
    camera=$(echo "$camera" | xargs)

    echo "Processing camera: $camera ($current_camera/$total_cameras)"

    # Create snapshots directory if it doesn't exist
    snapshots_dir="./snapshots"
    mkdir -p "$snapshots_dir"

    # Create file for the snapshot
    snapshot_file="$snapshots_dir/${camera}.jpg"

    # Download latest snapshot from Frigate
    SERVER_BASE=$(echo "$FRIGATE_URL" | sed 's|:\([0-9]*\)$||')
    attempt=1
    success=0
    while [ $attempt -le 3 ]; do
        echo "Attempt $attempt/3"
        if [ "$SOURCE" = "RTSP" ]; then
            printf "Capturing snapshot from RTSP "
            ffmpeg -y -rtsp_transport udp -ss 1 -fflags +discardcorrupt -avoid_negative_ts make_zero -i "$RTSP_BASE$camera" -vf scale=1920:1080 -frames:v 1 -q:v 2 "$snapshot_file" 2>&1
            pid=$!
            delay=0.1
            spinstr='|/-\'
            while ps a | awk '{print $1}' | grep -q $pid; do
                temp=${spinstr#?}
                printf " [%c]  " "$spinstr"
                spinstr=$temp${spinstr%"$temp"}
                sleep $delay
                printf "\b\b\b\b\b\b"
            done
            printf "    \b\b\b\b"
            wait $pid
            if [ $? -eq 0 ]; then
                printf "✓\n"
                success=1
            else
                printf "✗\n"
            fi
        elif [ "$SOURCE" = "MJPEG" ]; then
            printf "Downloading snapshot from MJPEG "
            curl -s -o "$snapshot_file" "$SERVER_BASE:1984/api/frame.jpeg?src=$camera" > /dev/null 2>&1 &
            pid=$!
            delay=0.1
            spinstr='|/-\'
            while ps a | awk '{print $1}' | grep -q $pid; do
                temp=${spinstr#?}
                printf " [%c]  " "$spinstr"
                spinstr=$temp${spinstr%"$temp"}
                sleep $delay
                printf "\b\b\b\b\b\b"
            done
            printf "    \b\b\b\b"
            wait $pid
            if [ $? -eq 0 ]; then
                printf "✓\n"
                success=1
                break
            else
                printf "✗\n"
            fi
        else
            printf "Downloading snapshot "
            curl -s -o "$snapshot_file" "$FRIGATE_URL/api/$camera/latest.jpg" > /dev/null 2>&1 &
            pid=$!
            delay=0.1
            spinstr='|/-\'
            while ps a | awk '{print $1}' | grep -q $pid; do
                temp=${spinstr#?}
                printf " [%c]  " "$spinstr"
                spinstr=$temp${spinstr%"$temp"}
                sleep $delay
                printf "\b\b\b\b\b\b"
            done
            printf "    \b\b\b\b"
            wait $pid
            if [ $? -eq 0 ]; then
                printf "✓\n"
                success=1
            else
                printf "✗\n"
            fi
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le 3 ]; then
            sleep 2
        fi
    done

    # Check if file exists and has content
    if [ ! -f "$snapshot_file" ] || [ ! -s "$snapshot_file" ]; then
        echo "Error: Downloaded file is empty or missing: $snapshot_file"
        rm -f "$snapshot_file"
        continue
    fi

    # Add watermark with camera name and timestamp
    DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    DATE_TIME_ESC=$(echo "$DATE_TIME" | sed 's/:/\\:/g')
    camera_cap=$(echo "${camera:0:1}" | tr '[:lower:]' '[:upper:]')${camera:1}
    if command -v ffmpeg >/dev/null 2>&1; then
        temp_file="${snapshot_file%.*}_tmp.${snapshot_file##*.}"
        printf "Adding watermark "
        ffmpeg -y -i "$snapshot_file" -frames:v 1 -vf "drawtext=text='$camera_cap':x=10:y=h-th-10:fontsize=24:fontcolor=white:bordercolor=black:borderw=2:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf, drawtext=text='$DATE_TIME_ESC':x=w-tw-10:y=h-th-10:fontsize=24:fontcolor=white:bordercolor=black:borderw=2:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" "$temp_file" > /dev/null 2>&1 &
        pid=$!
        delay=0.1
        spinstr='|/-\'
        while ps a | awk '{print $1}' | grep -q $pid; do
            temp=${spinstr#?}
            printf " [%c]  " "$spinstr"
            spinstr=$temp${spinstr%"$temp"}
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
        printf "    \b\b\b\b"
        wait $pid
        if [ $? -eq 0 ]; then
            printf "✓\n"
            mv "$temp_file" "$snapshot_file"
        else
            printf "✗\n"
            echo "Warning: Failed to add watermark, using original image"
            rm -f "$temp_file"
        fi
    else
        echo "Warning: ffmpeg not found, skipping watermark"
    fi

    # Upload the file
    attempt=1
    success=0
    while [ $attempt -le 3 ]; do
        echo "Attempt $attempt/3"
        printf "Uploading snapshot "
        upload_file "$snapshot_file" > /dev/null 2>&1 &
        pid=$!
        delay=0.1
        spinstr='|/-\'
        while ps a | awk '{print $1}' | grep -q $pid; do
            temp=${spinstr#?}
            printf " [%c]  " "$spinstr"
            spinstr=$temp${spinstr%"$temp"}
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
        printf "    \b\b\b\b"
        wait $pid
        if [ $? -eq 0 ]; then
            printf "✓\n"
            success=1
            break
        else
            printf "✗\n"
            attempt=$((attempt + 1))
            if [ $attempt -le 3 ]; then
                sleep 2
            fi
        fi
    done
    if [ $success -eq 0 ]; then
        echo "Uploading snapshot failed after 3 attempts"
    fi
    current_camera=$((current_camera + 1))
done

echo "All cameras processed."
