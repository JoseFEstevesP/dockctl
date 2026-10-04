#!/usr/bin/env bash
set -euo pipefail

# dockctl - instalacion de la app de bandeja para gestionar contenedores Docker
# Uso: ./install.sh            (SKIP_AUTOSTART=1 ./install.sh para no arrancar al inicio)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${HOME}/.local/share/dockctl"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
AUTOSTART_DIR="${HOME}/.config/autostart"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"

echo "==> Migracion: retirando el widget y el servicio anteriores"
systemctl --user disable --now dockctl 2>/dev/null || true
rm -f "${HOME}/.config/systemd/user/dockctl.service"
rm -rf "${HOME}/.local/share/plasma/plasmoids/org.gato99.dockctl"
systemctl --user daemon-reload 2>/dev/null || true

echo "==> App  ->  ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}"
cp -r "${DIR}/app/qml" "${APP_DIR}/qml"
cp -r "${DIR}/app/images" "${APP_DIR}/images"
cp "${DIR}/app/dockctl_app.py" "${APP_DIR}/dockctl_app.py"
cp "${DIR}/backend/backend.py" "${APP_DIR}/backend.py"
cp "${DIR}/backend/test_backend.py" "${APP_DIR}/test_backend.py"
chmod +x "${APP_DIR}/dockctl_app.py"

echo "==> Lanzador  ->  ${BIN_DIR}/dockctl"
mkdir -p "${BIN_DIR}"
ln -sf "${APP_DIR}/dockctl_app.py" "${BIN_DIR}/dockctl"

echo "==> Icono  ->  ${ICON_DIR}/dockctl.svg"
mkdir -p "${ICON_DIR}"
cp "${DIR}/app/images/docker.svg" "${ICON_DIR}/dockctl.svg"
gtk-update-icon-cache -f -q "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
rm -f "${HOME}/.cache/icon-cache.kcache" 2>/dev/null || true

echo "==> Entrada de menu  ->  ${DESKTOP_DIR}/org.gato99.dockctl.desktop"
mkdir -p "${DESKTOP_DIR}"
sed "s|^Exec=.*|Exec=${BIN_DIR}/dockctl|" \
    "${DIR}/app/org.gato99.dockctl.desktop" \
    > "${DESKTOP_DIR}/org.gato99.dockctl.desktop"

SHORTCUT_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "${SHORTCUT_DIR}" ] || SHORTCUT_DIR="${HOME}/Desktop"
if [ -d "${SHORTCUT_DIR}" ]; then
    echo "==> Acceso directo  ->  ${SHORTCUT_DIR}/dockctl.desktop"
    chmod +x "${DESKTOP_DIR}/org.gato99.dockctl.desktop"
    ln -sf "${DESKTOP_DIR}/org.gato99.dockctl.desktop" "${SHORTCUT_DIR}/dockctl.desktop"
    gio set "${SHORTCUT_DIR}/dockctl.desktop" metadata::trusted true 2>/dev/null || true
else
    echo "==> Acceso directo: no existe ${SHORTCUT_DIR}, se omite"
fi

if [ "${SKIP_AUTOSTART:-0}" != "1" ]; then
    printf 'Arrancar la app al iniciar sesion? [S/n] '
    read -r consulta || consulta="s"
    case "${consulta}" in
        [nN]|[nN][oO])
            rm -f "${AUTOSTART_DIR}/org.gato99.dockctl.desktop"
            echo "    autostart desactivado"
            ;;
        *)
            mkdir -p "${AUTOSTART_DIR}"
            sed "s|^Exec=.*|Exec=${BIN_DIR}/dockctl --hidden|" \
                "${DIR}/app/org.gato99.dockctl.desktop" \
                > "${AUTOSTART_DIR}/org.gato99.dockctl.desktop"
            echo "    autostart activado en ${AUTOSTART_DIR}"
            ;;
    esac
fi

echo
echo "Listo. Arranca la app con 'dockctl' (o desde el menu: Contenedores Docker)."
echo "Buscara el icono de la bandeja del sistema; si no lo ves, instala un area"
echo "de bandeja (en Plasma ya viene de serie)."
