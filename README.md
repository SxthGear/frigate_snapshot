# Frigate Snapshot Uploader

A comprehensive shell script tool to automatically download the latest snapshots from Frigate NVR cameras, add professional watermarks, and upload them to various destinations (FTP, SSH, SFTP, HTTP POST, or local storage). Features advanced retry logic, progress indicators, and dependency validation for reliable operation.

## Features

- **Interactive Configuration**: Menu-based setup with colored UI for Frigate URL, cameras, and upload methods
- **Multiple Upload Methods**: FTP (with passive mode), SSH/SCP, SFTP, HTTP POST, and local storage
- **Watermarking**: Adds camera name (lower left) and timestamp (lower right) with white text and black outlines using ffmpeg
- **Robust Operation**: Dependency checks, retry logic (3 attempts with delays), and animated progress spinners
- **Progress Tracking**: Real-time indicators for camera processing, attempts, and operation status
- **Error Handling**: Comprehensive logging, validation, and user-friendly error messages
- **Command-Line Options**: Help (`--help`), version (`--version`), and clean output
- **Local Storage**: Saves watermarked images in `./snapshots/` with camera-specific filenames

## Requirements

- Bash shell
- curl (for HTTP/FTP operations)
- wget (for external IP detection)
- ffmpeg (for watermarking)
- scp/sftp (for SSH/SFTP uploads, if used)

## Installation

1. Clone or download the scripts to your system.
2. Make them executable: `chmod +x frigate_config_v2.1.sh frigate_upload_v2.1.sh`
3. Run configuration: `./frigate_config_v2.1.sh`
4. Execute uploads: `./frigate_upload_v2.1.sh`

## Usage

### Configuration

Set up your Frigate connection and upload preferences:

```bash
./frigate_config_v2.1.sh [--help|--version]
```

This interactive menu guides you through:
- Frigate server URL
- Camera names (comma-separated)
- Upload method and credentials

Settings are saved to `config.txt`. Use `--help` for options or re-run to edit.

### Upload

Download, watermark, and upload snapshots:

```bash
./frigate_upload_v2.1.sh [--help|--version]
```

Process flow:
- Validates dependencies and configuration
- Downloads latest snapshots for each camera
- Applies watermarks (camera name + timestamp)
- Uploads to the configured destination with retries
- Shows progress with spinners and success indicators

Example output:
```
Checking dependencies...
Dependencies OK.
Processing camera: driveway (1/4)
Attempt 1/3
Downloading snapshot  [|] ✓
Adding watermark  [|] ✓
Attempt 1/3
Uploading snapshot  [|] ✓
All cameras processed.
```

## Version History

- **v2.1 (Current)**: Enhanced with dependency checks, retry logic, progress spinners, help/version options, and improved error handling.
- **v2**: Added ffmpeg watermarking with camera names and timestamps.
- **Original**: Basic FTP upload functionality.

For older versions, see archived scripts (`frigate_config.sh`, `frigate_upload.sh`, `frigate_config_v2.sh`, `frigate_upload_v2.sh`).

## Configuration Options

### Frigate Settings
- **Server URL**: The URL of your Frigate server (e.g., `http://localhost:5000`)
- **Cameras**: Comma-separated list of camera names as configured in Frigate

### Upload Methods

#### FTP
- Host (without `ftp://`)
- Username and password
- Upload path (e.g., `/uploads/`)

#### SSH/SCP
- Host
- Username and password/key
- Remote path

#### SFTP
- Host
- Username and password/key
- Remote path

#### HTTP POST
- POST URL
- Optional authentication

#### Local
- Local directory path

## File Naming

Images are saved locally and uploaded with the camera name as filename (e.g., `driveway.jpg`). Existing files are overwritten.

## Troubleshooting

- Ensure Frigate is running and accessible
- Check network connectivity and firewall settings
- For FTP issues, verify credentials and server permissions
- Scripts use passive FTP mode for compatibility behind NAT/proxy

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
