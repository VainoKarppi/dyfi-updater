#!/bin/bash

set -e

APP_NAME="dyfi-updater"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

echo ""
echo "============================================"
echo " DYFI Updater Installer"
echo "============================================"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run:"
    echo ""
    echo "  sudo ./install.sh"
    echo ""
    exit 1
fi

# Directory containing install.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check executable
if [ ! -f "$SCRIPT_DIR/$APP_NAME" ]; then
    echo "ERROR: $APP_NAME executable not found."
    echo "Expected:"
    echo "  $SCRIPT_DIR/$APP_NAME"
    exit 1
fi

# Stop existing service
if systemctl list-unit-files | grep -q "^$APP_NAME.service"; then
    echo "Stopping existing $APP_NAME service..."
    systemctl stop "$APP_NAME" || true
fi

# Create installation directory
echo "Installing to $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"

# Copy application
echo "Copying application files..."

cp "$SCRIPT_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

# Copy settings only if it doesn't already exist
if [ ! -f "$INSTALL_DIR/settings.json" ] && [ -f "$SCRIPT_DIR/settings.json" ]; then
    echo "Installing settings.json..."
    cp "$SCRIPT_DIR/settings.json" "$INSTALL_DIR/settings.json"
fi

# Make executable
chmod +x "$INSTALL_DIR/$APP_NAME"

# Make pi owner
chown -R pi:pi "$INSTALL_DIR"

# Create systemd service
echo "Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=DYFI Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$APP_NAME
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable service
systemctl enable "$APP_NAME"

# Start service
echo "Starting $APP_NAME..."

systemctl restart "$APP_NAME"

echo ""
echo "============================================"
echo " Installation completed"
echo "============================================"
echo ""

systemctl --no-pager --full status "$APP_NAME"

echo ""
echo "Application:"
echo "  $INSTALL_DIR"

echo ""
echo "Service:"
echo "  systemctl status $APP_NAME"

echo ""
echo "Logs:"
echo "  journalctl -u $APP_NAME -f"

echo ""
