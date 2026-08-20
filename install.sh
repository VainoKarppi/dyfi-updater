#!/bin/bash

set -euo pipefail

APP_NAME="dyfi-updater"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo " DYFI Updater Linux Installer"
echo "============================================"
echo ""

# ---------------- Check root ----------------

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this installer with sudo:"
    echo ""
    echo "  sudo ./install.sh"
    echo ""
    exit 1
fi

# ---------------- Detect invoking user ----------------
# SUDO_USER is the user who ran "sudo ./install.sh".
# If the installer was executed directly as root, fall back
# to the owner of the installer directory.

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    SERVICE_USER="$SUDO_USER"
else
    SERVICE_USER="$(stat -c '%U' "$SCRIPT_DIR")"
fi

# Make sure the detected user actually exists
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "ERROR: Could not determine a valid service user."
    exit 1
fi

echo "Service user: $SERVICE_USER"
echo ""

# ---------------- Check files ----------------

if [ ! -d "$SCRIPT_DIR/csharp" ]; then
    echo "ERROR: csharp directory not found."
    echo "Run this installer from the root of the release package."
    exit 1
fi

# ---------------- Detect architecture ----------------

ARCH="$(uname -m)"

case "$ARCH" in
    aarch64)
        RUNTIME="linux-arm64"
        ;;
    x86_64)
        RUNTIME="linux-x64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

EXECUTABLE="$SCRIPT_DIR/csharp/$RUNTIME/dyfi-updater"

if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: DYFI Updater executable not found:"
    echo "  $EXECUTABLE"
    exit 1
fi

echo "Detected architecture: $ARCH"
echo "Using runtime: $RUNTIME"
echo ""

# ---------------- Stop existing service ----------------

if systemctl list-unit-files | grep -q "^$APP_NAME.service"; then
    echo "Stopping existing service..."
    systemctl stop "$APP_NAME" || true
fi

# ---------------- Install application ----------------

echo "Installing to:"
echo "  $INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

echo "Copying application..."

cp -R "$SCRIPT_DIR/csharp" "$INSTALL_DIR/"

for dir in python docker powershell shell; do
    if [ -d "$SCRIPT_DIR/$dir" ]; then
        cp -R "$SCRIPT_DIR/$dir" "$INSTALL_DIR/"
    fi
done

# ---------------- Permissions ----------------

chmod +x "$INSTALL_DIR/csharp/$RUNTIME/dyfi-updater"

chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

# ---------------- Create systemd service ----------------

echo "Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=DYFI Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/csharp/$RUNTIME
ExecStart=$INSTALL_DIR/csharp/$RUNTIME/dyfi-updater
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# ---------------- Enable service ----------------

echo "Reloading systemd..."

systemctl daemon-reload

echo "Enabling service..."

systemctl enable "$APP_NAME"

# ---------------- Start service ----------------

echo "Starting service..."

systemctl restart "$APP_NAME"

# ---------------- Result ----------------

echo ""
echo "============================================"
echo " Installation completed"
echo "============================================"
echo ""

systemctl --no-pager --full status "$APP_NAME"

echo ""
echo "Installation directory:"
echo "  $INSTALL_DIR"

echo ""
echo "Service user:"
echo "  $SERVICE_USER"

echo ""
echo "Service commands:"
echo ""
echo "  Status:  systemctl status $APP_NAME"
echo "  Logs:    journalctl -u $APP_NAME -f"
echo "  Stop:    sudo systemctl stop $APP_NAME"
echo "  Start:   sudo systemctl start $APP_NAME"
echo ""