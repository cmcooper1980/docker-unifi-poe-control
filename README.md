# UniFi PoE Control Script

A Python script that uses the `aiounifi` library to set Power over Ethernet (PoE) status on specified ports of a UniFi switch to a desired state through the UniFi Network Controller.

## Features

- **Set PoE Status**: Set PoE on/off for individual ports or ranges of ports to a specific desired state
- **Flexible Port Selection**: Support for individual ports, ranges, and comma-separated lists
- **Safety Features**:
  - User confirmation before making changes (can be bypassed with `--yes`)
  - Verification of changes after execution
  - Checks for PoE capability on each port

## Prerequisites

- Python 3.8 or later
- UniFi Network Controller (tested with 9.2)

## Getting Network Controller Credentials

You will need a local user created in your UniFi OS Console to log in with. Ubiquiti SSO Cloud Users will not work.

1. Login to your Local Portal on your UniFi OS device, and select Users. <br> **Note:** This **must** be done from the UniFi OS by accessing it directly by IP address (i.e. Local Portal), not via unifi.ui.com or within the UniFi Network app.

2. Go to **Admins & Users** from the left hand side menu or [IP address]/admins/users e.g. 192.168.1.1/admins/users.

3. Select **Add New Admin.**
4. Check **Restrict to local access only** and fill out the fields for your user. Select Full Management for Network. **OS Settings** are not used, so they can be set to **None**.
5. In the bottom right, select **Add**.

## Installation

1. **Clone or download this repository**

2. **Create virtual environment**

   ```bash
   python3 -m venv venv
   source ./venv/bin/activate
   ```

3. **Install dependencies** (if not using the existing virtual environment):

   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Basic Syntax

```bash
python unifi_poe_control.py <controller_host> <username> <password> <switch_mac> <port_indexes> --state <on|off> [options]
```

### Arguments

- `controller_host`: IP address or hostname of your UniFi controller
- `username`: Username for UniFi controller login
- `password`: Password for UniFi controller login
- `switch_mac`: MAC address of the target switch (any format: `aa:bb:cc:dd:ee:ff`, `aa-bb-cc-dd-ee-ff`, or `aabbccddeeff`)
- `port_indexes`: Port numbers to configure (see examples below for formats)

### Required Options

- `--state {on,off,enable,disable}`: Desired PoE state (on/enable to turn on, off/disable to turn off)

### Additional Options

- `--port PORT`: Controller port (default: 443)
- `--site SITE`: Site name (default: "default")
- `--verify-ssl`: Verify SSL certificates (default: disabled for self-signed certs)
- `--yes`: Skip confirmation prompt (for automation)
- `--debug`: Enable debug logging
- `--help`: Show help message

### Port Index Formats

The script supports flexible port specification:

- **Individual ports**: `1,3,5,8`
- **Ranges**: `1-8` (ports 1 through 8)
- **Mixed**: `1,3,5-8,12` (ports 1, 3, 5, 6, 7, 8, and 12)

## Examples

### Basic Usage - Enable PoE

Enable PoE on ports 1, 2, and 3:

```bash
python unifi_poe_control.py 192.168.1.1 admin mypassword 00:11:22:33:44:55 1,2,3 --state on
```

### Basic Usage - Disable PoE

Disable PoE on ports 1, 2, and 3:

```bash
python unifi_poe_control.py 192.168.1.1 admin mypassword 00:11:22:33:44:55 1,2,3 --state off
```

### Range of Ports

Enable PoE on ports 1 through 8:

```bash
python unifi_poe_control.py 192.168.1.1 admin mypassword 00:11:22:33:44:55 1-8 --state on
```

### Custom Controller Port

For a controller on a non-standard port (like UniFi OS on port 443):

```bash
python unifi_poe_control.py 192.168.1.1 admin mypassword 00:11:22:33:44:55 5,10-12 --state off --port 443
```

### Multiple Sites

For a specific site (not the default):

```bash
python unifi_poe_control.py unifi.local admin mypassword aa:bb:cc:dd:ee:ff 1-24 --state on --site branch-office
```

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
python unifi_poe_control.py 192.168.1.1 admin mypassword 00:11:22:33:44:55 1,2,3 --state on --debug
```

### Automation Mode

Skip confirmation prompts for scripting and automation:

```bash
# For scripts and automation - no user interaction required
python unifi_poe_control.py 192.168.1.1 admin mypassword 00:11:22:33:44:55 1,2,3 --state off --yes
```

## PoE Modes

When setting PoE states:

- `--state on` or `--state enable` → sets port to "auto" (enable PoE with automatic detection)
- `--state off` or `--state disable` → sets port to "off" (disable PoE)

## License

This script is provided as-is for educational and operational purposes. Use responsibly and test in non-production environments first.
