# Mattermost Installation Script

This repository contains a Bash script to automate the installation and removal of Mattermost, a flexible, open-source messaging platform that enables secure team collaboration.

## Features

- Automated installation and configuration of Mattermost, PostgreSQL, Nginx, and other necessary packages.
- Supports both package and existing installation methods.
- Automated SSL setup with Let's Encrypt.
- Generates and configures a self-signed SSL certificate if the domain is not reachable.
- Automated removal and cleanup of Mattermost and all associated components, users, and groups.

## Prerequisites

- Debian/Ubuntu (Recommended: Debain 11+ or Ubuntu 20.04+)
- Root access
- Domain name (optional, but required for SSL)
- DNS Pointing to domain name/subdomain name of your choice

## Usage

1. Clone this repository:
   ```sh
   git clone https://github.com/yashodhank/install_mattermost.git
   cd repository
   ```

2. Make the script executable:
   ```sh
   chmod +x install_mattermost.sh
   ```

3. Run the script with the desired action (install or remove) and installation method (package or existing):
   ```sh
   sudo ./install_mattermost.sh install package
   ```
   or
   ```sh
   sudo ./install_mattermost.sh remove
   ```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Disclaimer

Use this script at your own risk. The author(s) will not be responsible for any damage, data loss, or other issues that may occur during the installation or removal process.
