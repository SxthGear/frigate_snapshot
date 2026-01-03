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

[Add your license here]
