#!/bin/bash

set -euo pipefail

APP_NAME="dyfi-updater"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

echo "============================================"
echo " DYFI Updater Linux Uninstaller"
echo "============================================"
echo ""

# ---------------- Check root ----------------

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this uninstaller with sudo:"
    echo ""
    echo "  sudo ./uninstall.sh"
    echo ""
    exit 1
fi

# ---------------- Stop and disable service ----------------

if systemctl list-unit-files | grep -q "^$APP_NAME.service"; then
    echo "Stopping service..."
    systemctl stop "$APP_NAME" || true

    echo "Disabling service..."
    systemctl disable "$APP_NAME" || true
else
    echo "Service not found, skipping stop/disable."
fi

# ---------------- Remove service file ----------------

if [ -f "$SERVICE_FILE" ]; then
    echo "Removing service file:"
    echo "  $SERVICE_FILE"
    rm -f "$SERVICE_FILE"

    echo "Reloading systemd..."
    systemctl daemon-reload
    systemctl reset-failed "$APP_NAME" 2>/dev/null || true
else
    echo "Service file not found, skipping."
fi

# ---------------- Remove install directory ----------------

if [ -d "$INSTALL_DIR" ]; then
    echo "Removing install directory:"
    echo "  $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
else
    echo "Install directory not found, skipping."
fi

# ---------------- Result ----------------

echo ""
echo "============================================"
echo " Uninstallation completed"
echo "============================================"
echo ""