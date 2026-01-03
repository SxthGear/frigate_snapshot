# Frigate Snapshot Upload System

A robust bash-based system for capturing snapshots from Frigate NVR and uploading them to various destinations (FTP, SFTP, HTTP, LOCAL).

## 🚀 Features

### Core Functionality
- **Automated Snapshot Capture**: Captures latest.jpg snapshots from Frigate cameras
- **Multiple Upload Methods**: FTP, SFTP, HTTP endpoints, or local storage only
- **Camera Validation**: Tests camera availability before processing
- **Retry Logic**: Configurable retry attempts with delays for failed uploads
- **File Cleanup**: Automatic management of snapshot files with configurable retention
- **Detailed Logging**: Comprehensive logging with timestamps and error details

### Configuration Management
- **Interactive Configuration Builder**: Guided setup with validation
- **Existing Config Editing**: Modify individual configuration items (10 configurable options)
- **Camera Discovery**: Automatic camera detection and validation with fallback on failures
- **Authentication Support**: Username/password, API keys, and special character handling (^, $, etc.)
- **Error Detection**: Advanced error detection with detailed failure analysis and debugging

### Upload Methods
1. **FTP/SFTP**: Traditional FTP/SFTP with passive mode and lftp fallback
2. **HTTP**: Custom HTTP endpoint uploads with authentication (basic, API key)
3. **LOCAL**: Save files locally without external uploads
4. **Mixed Support**: Configure different methods per deployment

### Production-Ready Features
- **Robust Error Handling**: Detects FTP authentication failures vs connection issues
- **Script Debugging**: FTP script logging and verbose output for troubleshooting
- **Connection Testing**: Pre-upload validation of server connectivity
- **Success Detection**: File transfer confirmation via FTP response codes and directory listings
- **Special Character Support**: Handles complex passwords with special characters
- **Retry with Backoff**: Configurable retry attempts with delays
- **File Overwriting**: Uses simple camera names (not timestamps) for consistent file management

## 📁 Files

- `frigate_upload.sh` - Main upload script
- `frigate_config_builder.sh` - Interactive configuration builder
- `frigate_config.conf` - Configuration file (auto-generated)
- `README.md` - This documentation

## 🚀 Quick Start

### 1. Initial Configuration
```bash
# Make scripts executable
chmod +x frigate_upload.sh frigate_config_builder.sh

# Run interactive configuration builder
./frigate_config_builder.sh
```

### 2. Configure Your Settings
The configuration builder will guide you through:
- Camera names (comma-separated)
- Frigate server URL
- Output directory and retention settings
- Upload method (FTP/SFTP/HTTP/LOCAL)
- Authentication credentials

### 3. Test Configuration
```bash
# Test your configuration
./frigate_upload.sh -t
```

### 4. Run Upload Script
```bash
# Execute full snapshot capture and upload
./frigate_upload.sh
```

## 🛠️ Installation

### Prerequisites
- **Bash 4.0+**: Modern bash with associative array support
- **curl**: For Frigate API communication
- **ftp/lftp**: For FTP/SFTP uploads (optional based on method)
- **Standard Unix tools**: grep, sed, awk, stat, etc.

### Manual Configuration
If you prefer manual setup:
```bash
# Create configuration file
cat > frigate_config.conf << 'EOF'
FRIGATE_URL="http://your-frigate-server:5000"
SELECTED_CAMERAS="front_door,back_yard"
UPLOAD_METHOD="LOCAL"
OUTPUT_DIR="./snapshots"
MAX_FILES="50"
EOF

# Test and run
./frigate_upload.sh -t
./frigate_upload.sh
```

## ⚙️ Configuration

### Configuration File Format
```bash
# Frigate Snapshot Upload Configuration
# Generated on Fri Jan  2 19:42:36 CST 2026

# Frigate server settings
FRIGATE_URL=http://your-frigate-server:5000

# Camera selection (comma-separated list)
SELECTED_CAMERAS=doorbell,driveway,side,yard,corner

# Output settings
OUTPUT_DIR=./snapshots
MAX_FILES=1
LOG_FILE=./frigate_snapshot.log

# Upload configuration
UPLOAD_METHOD="FTP"
UPLOAD_SERVER="ftp.example.com"
UPLOAD_PORT="21"
UPLOAD_USERNAME="johnrandolph@example.com"
UPLOAD_PASSWORD="supersecretpassword"
UPLOAD_REMOTE_PATH="/"

# Script settings
SCRIPT_TIMEOUT="300"
RETRY_COUNT="3"
RETRY_DELAY="5"
```

### Configuration Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|----------|---------|
| `FRIGATE_URL` | Frigate server URL | - | `http://192.168.1.100:5000` |
| `SELECTED_CAMERAS` | Camera names (comma-separated) | - | `front_door,back_yard,garage` |
| `OUTPUT_DIR` | Local directory for snapshots | `./snapshots` | `/home/user/frigate/snapshots` |
| `MAX_FILES` | Maximum files to keep (0=unlimited) | `50` | `100` |
| `LOG_FILE` | Log file path | `./frigate_snapshot.log` | `/var/log/frigate_upload.log` |
| `UPLOAD_METHOD` | Upload method | `LOCAL` | `FTP`, `SFTP`, `HTTP`, `LOCAL` |
| `UPLOAD_SERVER` | FTP/SFTP server address | - | `ftp.example.com` |
| `UPLOAD_PORT` | FTP/SFTP port | `21` (FTP), `22` (SFTP) | `2121` |
| `UPLOAD_USERNAME` | FTP/SFTP username | - | `user@example.com` |
| `UPLOAD_PASSWORD` | FTP/SFTP password | - | `secure-password123` |
| `UPLOAD_REMOTE_PATH` | Remote directory path | `/uploads` | `/public_html/snapshots` |
| `SCRIPT_TIMEOUT` | Script timeout in seconds | `300` | `600` |
| `RETRY_COUNT` | Number of retry attempts | `3` | `5` |
| `RETRY_DELAY` | Delay between retries (seconds) | `5` | `10` |

## 🎮 Usage

### Configuration Builder
```bash
# Interactive setup with default config file
./frigate_config_builder.sh

# Use custom config file
./frigate_config_builder.sh -c /path/to/config.conf

# Show help
./frigate_config_builder.sh -h
```

When run without an existing config file, script will:
1. Prompt for camera names
2. Prompt for Frigate server URL  
3. Test all cameras
4. Prompt for output settings
5. Prompt for upload method configuration
6. Generate configuration file

When run with an existing config file, script will:
1. Load and display current configuration
2. Provide menu to modify individual items
3. Test camera connectivity
4. Generate updated configuration file

### Main Upload Script
```bash
# Run with default config file
./frigate_upload.sh

# Use custom config file
./frigate_upload.sh -c /path/to/config.conf

# Test configuration and connection only
./frigate_upload.sh -t

# Show help
./frigate_upload.sh -h
```

### Command Line Options

Both scripts support these options:

#### Common Options
- `-c, --config FILE`: Specify configuration file (default: ./frigate_config.conf)
- `-h, --help`: Show help message

#### frigate_upload.sh Additional
- `-t, --test`: Test configuration and connection only

#### Examples
```bash
./frigate_config_builder.sh                                    # Run with default config file
./frigate_config_builder.sh -c /path/to/config.conf           # Use custom config file
./frigate_upload.sh                                    # Run with default config
./frigate_upload.sh -c /path/to/config.conf           # Use custom config file  
./frigate_upload.sh -t --test                            # Test configuration only
```

## 🌐 Upload Methods

### FTP/SFTP Upload
Features:
- Passive mode for firewall compatibility
- Binary transfer mode
- Automatic retry with exponential backoff
- Detailed error reporting and debugging
- Support for special characters in passwords

FTP Configuration Example:
```bash
UPLOAD_METHOD="FTP"
UPLOAD_SERVER="ftp.example.com"
UPLOAD_PORT="21"
UPLOAD_USERNAME="user@example.com"
UPLOAD_PASSWORD="p@ssw0rd!123"
UPLOAD_REMOTE_PATH="/public/snapshots"
```

### HTTP Upload
Features:
- Basic authentication (username/password)
- API key/token authentication
- Custom header support
- Multipart file uploads

HTTP Configuration Example:
```bash
UPLOAD_METHOD="HTTP"
UPLOAD_SERVER="https://api.example.com"
UPLOAD_AUTH_METHOD="basic"
UPLOAD_USERNAME="api_user"
UPLOAD_PASSWORD="api_key"
```

### Local Storage Only
Features:
- No network dependencies
- File cleanup and rotation
- Perfect for backup or testing

Local Configuration Example:
```bash
UPLOAD_METHOD="LOCAL"
OUTPUT_DIR="./local_snapshots"
MAX_FILES="100"
```

## 📊 Logging

### Log Format
```
[2026-01-02 20:21:12] === Frigate Snapshot Upload Script ===
[2026-01-02 20:21:12] Loading configuration from: ./frigate_config.conf
[2026-01-02 20:21:12] Configuration loaded successfully
[2026-01-02 20:21:12] ✓ Connection to Frigate server successful
[2026-01-02 20:21:12] ✓ Camera 'front_door' is accessible
[2026-01-02 20:21:13] ✓ Snapshot captured: ./snapshots/front_door.jpg
[2026-01-02 20:21:13] ✓ Successfully uploaded front_door.jpg via FTP
[2026-01-02 20:21:13] Script completed. Successfully processed 1/1 cameras
```

### Log Levels
- **INFO**: Normal operation messages
- **SUCCESS**: ✓ Successful operations
- **ERROR**: ✗ Failed operations with details
- **DEBUG**: Detailed troubleshooting information

## 🔧 Advanced Configuration

### Camera URL Format
The script expects Frigate API endpoints in this format:
```
http://your-frigate-server:5000/api/{camera_name}/latest.jpg
```

### Multiple Configuration Files
You can maintain different configurations for different environments:
```bash
# Production
./frigate_upload.sh -c production.conf

# Development
./frigate_upload.sh -c development.conf

# Testing
./frigate_upload.sh -c test.conf
```

### Environment Variables
Override configuration with environment variables:
```bash
export FRIGATE_URL="http://localhost:5000"
export UPLOAD_METHOD="LOCAL"
./frigate_upload.sh
```

## 🚨 Troubleshooting

### Common Issues

#### FTP Authentication Failed
```
✗ FTP authentication or connection failed
Error details:
  530 Login authentication failed
```
**Solutions:**
- Verify username and password
- Check FTP server address and port
- Ensure FTP account is active
- Try manual connection with FileZilla

#### Camera Not Found
```
✗ Camera 'unknown_camera' not found or not accessible
```
**Solutions:**
- Check camera name spelling in config
- Verify Frigate camera names
- Test API endpoint manually: `curl http://server:5000/api/camera/latest.jpg`

#### File Upload Issues
```
✗ FTP completed but no transfer confirmation
```
**Solutions:**
- Check file permissions on local files
- Verify remote directory exists and is writable
- Check disk space on server

### Debug Mode
Enable detailed debugging:
```bash
# Enable verbose FTP output
export DEBUG=1
./frigate_upload.sh

# Test configuration only
./frigate_upload.sh -t
```

### Performance Optimization

#### For High-Frequency Capture
```bash
# Reduce timeout and increase retry speed
SCRIPT_TIMEOUT="60"
RETRY_COUNT="1"
RETRY_DELAY="1"
```

#### For Large Files
```bash
# Increase timeout and reduce concurrent uploads
SCRIPT_TIMEOUT="600"
RETRY_COUNT="5"
RETRY_DELAY="10"
```

## 🔄 Automation

### Cron Setup
```bash
# Edit crontab
crontab -e

# Add entry (every 5 minutes)
*/5 * * * * /path/to/frigate_upload.sh >> /var/log/frigate_cron.log 2>&1

# Add entry (every hour)
0 * * * * /path/to/frigate_upload.sh
```

### Systemd Service
Create `/etc/systemd/system/frigate-upload.service`:
```ini
[Unit]
Description=Frigate Snapshot Upload
After=network.target

[Service]
Type=oneshot
User=frigate
WorkingDirectory=/opt/frigate-upload
ExecStart=/opt/frigate-upload/frigate_upload.sh
ExecStartPost=/bin/sleep 30

[Install]
WantedBy=multi-user.target
```

## 🔒 Security

### Password Security
- Store configuration files with restricted permissions: `chmod 600 frigate_config.conf`
- Consider using SSH keys instead of passwords for SFTP
- Use environment variables for sensitive data

### Network Security
- Use SFTP instead of FTP when possible
- Configure firewall rules for FTP/SFTP ports
- Consider VPN for remote server access

### File Security
- Regular cleanup of old snapshots prevents disk fill
- Monitor log files for unusual activity
- Validate uploaded file integrity

## 📈 Monitoring

### Log Monitoring
```bash
# Monitor recent activity
tail -f ./frigate_snapshot.log

# Check error patterns
grep "ERROR\|✗" ./frigate_snapshot.log

# Statistics summary
grep -c "✓.*uploaded" ./frigate_snapshot.log
```

### Health Checks
```bash
# Test script health
./frigate_upload.sh -t

# Check configuration
./frigate_config_builder.sh

# Verify server connectivity
curl -I http://your-frigate-server:5000/api/
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

### Documentation
- Check this README for common solutions
- Review log files for specific error details
- Test configuration before deployment

### Community
- GitHub Issues: Report bugs and feature requests
- Wiki: Community documentation and examples
- Discussions: Q&A and community support

### Version History
- **v1.0.0**: Initial release with basic FTP upload
- **v1.1.0**: Added SFTP and HTTP upload support
- **v1.2.0**: Enhanced error handling and retry logic
- **v1.3.0**: Improved configuration builder and camera validation
- **v1.4.0**: Production-ready with comprehensive logging
- **v1.5.0** (Current): Enhanced FTP error detection and fixed upload syntax
  - Fixed FTP script generation for special characters in passwords
  - Improved error detection to properly identify successful transfers
  - Removed faulty connection test that caused false negatives
  - Enhanced debugging capabilities with FTP script logging
  - Support for complex FTP credentials with special characters

## 🎯 Current Status: Production Ready

### ✅ Working Features
- **FTP Uploads**: Fully functional with proper error detection
- **Camera Processing**: Automatic snapshot capture from Frigate API
- **Configuration Management**: Interactive builder with 10 configurable options
- **Error Handling**: Comprehensive logging and retry logic
- **File Management**: Automatic cleanup and retention policies
- **Authentication**: Support for complex passwords with special characters
- **Testing**: Built-in configuration and connectivity validation

### 🔧 Recent Fixes (v1.5.0)
- Fixed FTP script syntax for proper file uploads
- Enhanced error detection to identify successful transfers
- Resolved authentication issues with special character handling
- Improved debugging capabilities with detailed FTP logging
- Fixed connection testing that caused false failures

### 📊 Proven in Production
The current implementation has been tested and verified to:
- Successfully upload files to FTP servers with complex credentials
- Handle multiple cameras (doorbell, driveway, side, yard) 
- Provide detailed logging for troubleshooting
- Work with various FTP server configurations
- Manage file lifecycle and cleanup properly

---

**Note**: Always test configurations in a non-production environment first. The script includes comprehensive error handling and logging to help troubleshoot any issues.
