# Frigate Snapshot Uploader

A shell script tool to automatically download the latest snapshots from Frigate NVR cameras and upload them to various destinations (FTP, SSH, SFTP, POST, or local storage).

## Features

- Interactive configuration script to set up Frigate connection and upload parameters
- Supports multiple upload methods: FTP, SSH, SFTP, HTTP POST, and local storage
- Downloads latest snapshots for configured cameras
- Stores images locally in a `snapshots/` directory
- Overwrites files on upload destinations

## Requirements

- Bash shell
- curl (for HTTP/FTP operations)
- wget (for external IP detection)
- scp/sftp (for SSH/SFTP uploads, if used)

## Installation

1. Clone or download the scripts to your system.
2. Make them executable: `chmod +x frigate_config.sh frigate_upload.sh`

## Usage

### Configuration

Run the configuration script to set up your settings:

```bash
./frigate_config.sh
```

This will guide you through:
- Setting the Frigate server URL
- Specifying camera names (comma-separated)
- Choosing and configuring the upload method

Settings are saved to `config.txt`.

### Upload

Run the upload script to download and upload snapshots:

```bash
./frigate_upload.sh
```

This will:
- Download the latest snapshot for each configured camera
- Save them locally in `./snapshots/`
- Upload to the configured destination

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

Copyright (c) 2026 Kris

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
