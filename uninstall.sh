#!/usr/bin/env bash
set -euo pipefail

# dockctl - desinstalacion completa de la app de bandeja

APP_DIR="${HOME}/.local/share/dockctl"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
AUTOSTART_DIR="${HOME}/.config/autostart"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"

# Restos de la version anterior (widget + servicio systemd)
systemctl --user disable --now dockctl 2>/dev/null || true
rm -f "${HOME}/.config/systemd/user/dockctl.service"
rm -rf "${HOME}/.local/share/plasma/plasmoids/org.gato99.dockctl"
systemctl --user daemon-reload 2>/dev/null || true

pkill -f "${APP_DIR}/dockctl_app.py" 2>/dev/null || true
pkill -f "${BIN_DIR}/dockctl" 2>/dev/null || true

rm -rf "${APP_DIR}"
rm -f "${BIN_DIR}/dockctl"
rm -f "${DESKTOP_DIR}/org.gato99.dockctl.desktop"
rm -f "${AUTOSTART_DIR}/org.gato99.dockctl.desktop"
SHORTCUT_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "${SHORTCUT_DIR}" ] || SHORTCUT_DIR="${HOME}/Desktop"
rm -f "${SHORTCUT_DIR}/dockctl.desktop"
rm -f "${ICON_DIR}/dockctl.svg"
rm -rf "${HOME}/.cache/dockctl"
gtk-update-icon-cache -f -q "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
rm -f "${HOME}/.cache/icon-cache.kcache" 2>/dev/null || true

echo "Listo: app, lanzador, icono y entradas de menu eliminados."
echo "Se conserva la configuracion (QSettings): ~/.config/dockctl/"
echo "Borrarla con: rm -rf ~/.config/dockctl"
