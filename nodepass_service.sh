#!/bin/bash
#
# NodePass Port Forwarding Service
# 
# This script creates and manages a NodePass port forwarding service
# using an INI configuration file.
#
# Author: Manus AI +TOF@ns
# Date: May 16, 2025

# Default values
CONFIG_FILE="/etc/nodepass/config.ini"
NODEPASS_BIN="/usr/local/bin/nodepass"
PIDFILE="/var/run/nodepass.pid"
LOGFILE="/var/log/nodepass.log"
TEMP_DIR="/tmp/nodepass_download"

# Function to display usage information
usage() {
    echo "Usage: $0 {start|stop|restart|status|install|update} [config_file]"
    echo ""
    echo "Commands:"
    echo "  start       Start the NodePass service"
    echo "  stop        Stop the NodePass service"
    echo "  restart     Restart the NodePass service"
    echo "  status      Check the status of the NodePass service"
    echo "  install     Install NodePass as a system service"
    echo "  update      Download and install the latest NodePass binary"
    echo ""
    echo "Options:"
    echo "  config_file Path to the configuration file (default: $CONFIG_FILE)"
    exit 1
}

# Function to read INI configuration file
read_ini() {
    local file="$1"
    local section="$2"
    local key="$3"
    local result=$(awk -F '=' '/^\['"$section"'\]/{flag=1; next} /^\[/{flag=0} flag && $1 ~ /^'"$key"'/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$file")
    echo "$result"
}

# Function to check if the service is running
is_running() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE")
        if ps -p "$pid" > /dev/null; then
            return 0  # Running
        fi
    fi
    return 1  # Not running
}

# Function to download and install the latest NodePass binary
update_nodepass() {
    echo "Downloading the latest NodePass binary..."
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Determine system architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_NAME="amd64"
            ;;
        aarch64|arm64)
            ARCH_NAME="arm64"
            ;;
        armv7*)
            ARCH_NAME="armv7"
            ;;
        armv6*)
            ARCH_NAME="armv6"
            ;;
        i386|i686)
            ARCH_NAME="386"
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Get the latest release URL (including pre-releases)
    echo "Detecting latest NodePass release..."
    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/yosebyte/nodepass/releases | grep "browser_download_url.*linux_${ARCH_NAME}.tar.gz" | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$LATEST_RELEASE_URL" ]; then
        echo "Failed to find a suitable release for your architecture."
        exit 1
    fi
    
    # Extract version from URL
    VERSION=$(echo "$LATEST_RELEASE_URL" | grep -o 'nodepass_[0-9.]*' | cut -d '_' -f 2)
    echo "Found NodePass version $VERSION for $ARCH_NAME"
    
    # Download the tarball
    echo "Downloading from $LATEST_RELEASE_URL..."
    if ! curl -L -o "nodepass.tar.gz" "$LATEST_RELEASE_URL"; then
        echo "Failed to download NodePass."
        exit 1
    fi
    
    # Extract the binary
    echo "Extracting NodePass binary..."
    if ! tar -xzf "nodepass.tar.gz"; then
        echo "Failed to extract NodePass."
        exit 1
    fi
    
    # Create directory if it doesn't exist
    sudo mkdir -p "$(dirname "$NODEPASS_BIN")"
    
    # Install the binary
    echo "Installing NodePass to $NODEPASS_BIN..."
    if [ -f "nodepass" ]; then
        sudo cp "nodepass" "$NODEPASS_BIN"
        sudo chmod +x "$NODEPASS_BIN"
    else
        echo "NodePass binary not found in the extracted files."
        exit 1
    fi
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    echo "NodePass $VERSION has been successfully installed to $NODEPASS_BIN"
}

# Function to check if NodePass binary exists
check_nodepass() {
    if [ ! -f "$NODEPASS_BIN" ]; then
        echo "NodePass binary not found at $NODEPASS_BIN"
        echo "Attempting to download and install the latest version..."
        update_nodepass
    fi
}

# Function to start the service
start_service() {
    echo "Starting NodePass service..."
    
    # Check if already running
    if is_running; then
        echo "NodePass service is already running."
        return 0
    fi
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Read configuration
    local server_mode=$(read_ini "$CONFIG_FILE" "general" "mode")
    local server_port=$(read_ini "$CONFIG_FILE" "server" "port")
    local client_port=$(read_ini "$CONFIG_FILE" "client" "port")
    local server_host=$(read_ini "$CONFIG_FILE" "server" "host")
    local client_host=$(read_ini "$CONFIG_FILE" "client" "host")
    local tls_mode=$(read_ini "$CONFIG_FILE" "security" "tls_mode")
    local log_level=$(read_ini "$CONFIG_FILE" "logging" "level")
    local log_file=$(read_ini "$CONFIG_FILE" "logging" "file")
    
    # Set defaults if not specified
    server_mode=${server_mode:-"server"}
    server_port=${server_port:-"10101"}
    client_port=${client_port:-"8080"}
    server_host=${server_host:-"0.0.0.0"}
    client_host=${client_host:-"127.0.0.1"}
    tls_mode=${tls_mode:-"1"}
    log_level=${log_level:-"info"}
    log_file=${log_file:-"$LOGFILE"}
    
    # Build NodePass command based on mode
    local cmd=""
    if [ "$server_mode" = "server" ]; then
        cmd="$NODEPASS_BIN \"server://$server_host:$server_port/$client_host:$client_port?log=$log_level&tls=$tls_mode\""
    elif [ "$server_mode" = "client" ]; then
        cmd="$NODEPASS_BIN \"client://$server_host:$server_port/$client_host:$client_port?log=$log_level\""
    elif [ "$server_mode" = "master" ]; then
        cmd="$NODEPASS_BIN \"master://$server_host:$server_port/api?log=$log_level&tls=$tls_mode\""
    else
        echo "Error: Invalid mode specified in config: $server_mode"
        exit 1
    fi
    
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"
    
    # Start NodePass as a daemon
    echo "Starting NodePass with command: $cmd"
    eval "nohup $cmd >> $log_file 2>&1 &"
    local pid=$!
    echo $pid > "$PIDFILE"
    
    # Check if process is running
    sleep 1
    if ps -p $pid > /dev/null; then
        echo "NodePass service started successfully (PID: $pid)"
        return 0
    else
        echo "Error: Failed to start NodePass service"
        rm -f "$PIDFILE"
        return 1
    fi
}

# Function to stop the service
stop_service() {
    echo "Stopping NodePass service..."
    
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE")
        if ps -p "$pid" > /dev/null; then
            echo "Stopping NodePass process (PID: $pid)..."
            kill "$pid"
            
            # Wait for process to terminate
            local count=0
            while ps -p "$pid" > /dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if ps -p "$pid" > /dev/null; then
                echo "Process did not terminate gracefully, forcing..."
                kill -9 "$pid"
            fi
            
            echo "NodePass service stopped"
        else
            echo "NodePass service is not running (stale PID file)"
        fi
        rm -f "$PIDFILE"
    else
        echo "NodePass service is not running (no PID file)"
    fi
}

# Function to check service status
check_status() {
    if is_running; then
        local pid=$(cat "$PIDFILE")
        echo "NodePass service is running (PID: $pid)"
        return 0
    else
        echo "NodePass service is not running"
        return 1
    fi
}

# Function to install as a system service
install_service() {
    echo "Installing NodePass as a system service..."
    
    # Create service directory if it doesn't exist
    local service_dir="/etc/nodepass"
    mkdir -p "$service_dir"
    
    # Create default config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Creating default configuration file at $CONFIG_FILE"
        cat > "$CONFIG_FILE" << EOF
[general]
mode = server

[server]
host = 0.0.0.0
port = 10101

[client]
host = 127.0.0.1
port = 8080

[security]
tls_mode = 1

[logging]
level = info
file = /var/log/nodepass.log
EOF
    fi
    
    # Copy this script to /usr/local/bin if not already there
    local script_path=$(readlink -f "$0")
    local install_path="/usr/local/bin/nodepass-service"
    
    if [ "$script_path" != "$install_path" ]; then
        echo "Installing script to $install_path"
        cp "$script_path" "$install_path"
        chmod +x "$install_path"
    fi
    
    # Create systemd service file
    local service_file="/etc/systemd/system/nodepass.service"
    echo "Creating systemd service file at $service_file"
    
    cat > "$service_file" << EOF
[Unit]
Description=NodePass Port Forwarding Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/nodepass-service start
ExecStop=/usr/local/bin/nodepass-service stop
PIDFile=/var/run/nodepass.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable nodepass.service
    
    echo "NodePass service installed successfully"
    echo "You can now start it with: systemctl start nodepass"
    echo "To check status: systemctl status nodepass"
    echo "Configuration file is at: $CONFIG_FILE"
}

# Main script execution
if [ $# -lt 1 ]; then
    usage
fi

# Set config file if provided as second argument
if [ $# -ge 2 ]; then
    CONFIG_FILE="$2"
fi

# Process command
case "$1" in
    start)
        check_nodepass
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        start_service
        ;;
    status)
        check_status
        ;;
    install)
        check_nodepass
        install_service
        ;;
    update)
        update_nodepass
        ;;
    *)
        usage
        ;;
esac

exit 0
