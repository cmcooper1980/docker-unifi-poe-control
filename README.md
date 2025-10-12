[![GitHub Repo stars](https://img.shields.io/github/stars/cmcooper1980/docker-unifi-poe-control?logo=github&style=flat)](https://github.com/cmcooper1980/docker-unifi-poe-control) [![Docker Pulls](https://img.shields.io/docker/pulls/cmcooper1980/docker-unifi-poe-control?logo=docker)](https://hub.docker.com/r/cmcooper1980/docker-unifi-poe-control/tags) [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/cmcooper1980/docker-unifi-poe-control/latest?label=docker%20image%20ver.)](https://hub.docker.com/r/cmcooper1980/docker-unifi-poe-control/tags) [![GitHub last commit (branch)](https://img.shields.io/github/last-commit/cmcooper1980/docker-unifi-poe-control/main?logo=github)](https://github.com/cmcooper1980/docker-unifi-poe-control/commits/main/)

# Unifi PoE Control Docker Container

A docker container that uses the Unifi PoE Control Script by @wearelucid to set Power over Ethernet (PoE) status on specified ports of a UniFi switch to a desired state through the UniFi Network Controller.

## Prerequisites

- Docker
- Docker Compose
- Unifi Network Controller (tested with 9.5.18)

## How it works

- The Python script this repo provides is `unifi_poe_control.py`. It toggles PoE states via the UniFi Network Controller using **`aiounifi`** and supports:

  **_required args:_** controller host, username, password, switch MAC, and port indexes

  **`--state {on,off,enable,disable}`**

  **_options:_** **`--port`**, **`--site`**, **`--verify-ssl`**, **`--yes`**, **`--debug`**

  **_port index formats:_** **`1,3,5`**, ranges like **`1-8`**, or mixed **`1,3,5-8,12`**. 

- The entrypoint:

  - **_Run-once mode_** (**`CRON_MODE=0`**): builds the exact CLI from env vars and executes it immediately.

  - **_Cron mode_** (**`CRON_MODE=1`**): writes one or more cron lines that call the script with your chosen `STATE` and `PORT_INDEXES` at times you configure, then runs cron in the foreground and tails logs to `/var/log/cron.log`.
 
## Usage

Create a Unifi Admin account with a "Full Management" role of the network (uncheck "Use a Predefined Role" and select "None" for all other options available) that will specifically only be used for PoE control that is **$$\color{red}\text{Restricted to Local Access Only}$$**. This info is what you will enter into the `unifi_username.txt` and `unifi_password.txt` files. Create this account from the local management portal **NOT** from the Unifi cloud portal. You will also need to acquire your PoE switch's MAC address.

<img width="346" height="469" alt="Unifi Admin example (Large)" src="https://github.com/user-attachments/assets/ae0322ea-f53e-4e83-be83-007bfee35d0f" />


### docker build

1) Clone the repo locally

    `git clone https://github.com/cmcoper1980/docker-unifi-poe-control`

    `cd docker-unifi-poe-control`

2) edit the `unifi_username.txt` and `unifi_password.txt` files with your respective information

5) Run

    `docker compose up -d`

5) Check logs (optional)

    `docker logs -f <container_name>`

    #Inside the container:
    
    #`tail -f /var/log/cron.log`

### **_-OR-_**

### docker compose (pull from registry)

1) create a `unifi_username.txt` and a `unifi_password.txt` file and enter your respective information

2) Copy the `docker-compose.yml` file below into the same directory as the `unifi_username.txt` and `username_password.txt` files and edit the environment variables to suit your environment/requirements

```
secrets:
  unifi_username:
    file: ./unifi_username.txt
  unifi_password:
    file: ./unifi_password.txt

# If secrets not used, referenced username and password explicitly entered
# in the .env file/env: section will output to logs and console (great for debug but
# not for production)

services:
  unifi-poe-control:
    image: cmcooper1980/docker-unifi-poe-control:latest
    container_name: unifi-poe-control
    restart: unless-stopped
    secrets:
      - unifi_username
      - unifi_password
#    env_file:
#      - .env
# Uncomment the above two lines and delete this line and everything below if using the .env file from the repo
    environment:
      # ---- Base (required) ----
      - CONTROLLER_HOST=xxx.xxx.xxx.xxx #Unifi Controller IP Address
      #- USERNAME=username   # Unifi Admin account with Full Management role, only use to debug (will print to log/console)
      #- PASSWORD=password   # Unifi Admin account password, only use to debug (will print to log/console)
      - SWITCH_MAC=xx:xx:xx:xx:xx:xx   # MAC address of Unifi PoE Switch to control
      - TZ=America/Chicago   # system TZ
      #- CRON_TZ=America/Chicago   # cron TZ (overrides TZ for accurate cronjob schedules)

      # Default port set (used for RUN-ONCE mode)
      - PORT_INDEXES=1,2,3

      # ---- Options (map 1:1 to script flags) ----
      # STATE is mandatory in RUN-ONCE mode; not needed when using cron jobs (each job defines its own)
      - STATE=enable           # on|off|enable|disable
      - PORT=443            # Controller port
      - SITE=default        # Site name
      - VERIFY_SSL=false    # true to verify; default is not verifying (self-signed common)
      - YES=true            # skip confirmation
      - DEBUG=false         # verbose logging
      
      # ---- Scheduler mode ----
      # If CRON_MODE=0, RUN-ONCE mode, container runs command using default STATE value above.
      # If CRON_MODE=1, the container installs cron jobs and stays running with cron in foreground; ignores RUN_ONCE.
      - CRON_MODE=0

      # RUN_ONCE_MODE options:
      # idle (default mode, action will RUN ONCE and container remain idle until whenever container is restarted or rebuilt)
      # skip-if-done (action will RUN ONCE and create a marker; if marker is detected, will not perform RUN_ONCE if host or container is restarted but will with a rebuild)
      # exit (restart mode must be set to 'no', container will RUN ONCE then exit)
      - RUN_ONCE_MODE=idle

      # Simple paired jobs (enable/disable at specific times):
      # ─────────────────────────────────────────────────────────
      # Cron format: min hour day month day-of-week
      # Example: Turn ON (enable/auto) PoE weekdays at 07:00 for ports 1-8
      - ON_CRON=0 7 * * 1-5
      - ON_STATE=on
      - ON_PORT_INDEXES=1-8

      # Example: Turn OFF (disable) PoE weekdays at 19:00 for ports 1-8
      - OFF_CRON=0 19 * * 1-5
      - OFF_STATE=off
      - OFF_PORT_INDEXES=1-8

      # Advanced: multiple jobs (up to 10 shown; extend the loop in entrypoint if needed)
      # - JOB1_CRON=30 6 * * *
      # - JOB1_STATE=on
      # - JOB1_PORT_INDEXES=5,10-12
      # - JOB2_CRON=0 23 * * *
      # - JOB2_STATE=off
      # - JOB2_PORT_INDEXES=5,10-12

      # Cron heartbeat / diagnostics
      # Adds a once-per-minute date job for debugging (keeps log “alive”)
      # default is 0 or comment out to avoid filling log.
      DIAG_CRON=0
```

3) Run

    `docker compose up -d`

## Security & tips

- Prefer Docker/Compose secrets or your orchestrator’s secret store for PASSWORD (instead of a plain .env).

- If your controller uses a valid cert, set `VERIFY_SSL=true` (otherwise the script assumes self-signed and skips verification by default). 

- You can use either `on`|`enable` (maps to PoE “auto”) and `off`|`disable` (maps to PoE “off”).

 
########################################################################################################
 

# UniFi PoE Control Script (use script directly)

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
- UniFi Network Controller (tested with 9.5.18)

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
