#!/usr/bin/env bash
set -euo pipefail

# dockctl - actualiza la app instalada desde el repo
# Uso: ./update.sh                 -> codigo + icono + regenera dist/
#      --no-dist                   -> no regenera los paquetes de dist/
#      --release                   -> ademas sube/actualiza los assets de la release v<version>

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "${DIR}/VERSION" 2>/dev/null || true)"
if [ -z "${VERSION}" ]; then
    VERSION="$(git -C "${DIR}" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0")"
fi

APP_DIR="${HOME}/.local/share/dockctl"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
AUTOSTART_DIR="${HOME}/.config/autostart"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"

REGEN_DIST=1
UPDATE_RELEASE=0
for arg in "$@"; do
    case "${arg}" in
        --no-dist) REGEN_DIST=0 ;;
        --release) UPDATE_RELEASE=1 ;;
        *) echo "Opcion desconocida: ${arg}" >&2; exit 1 ;;
    esac
done

echo "==> Codigo  ->  ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}"
cp -r "${DIR}/app/qml" "${APP_DIR}/qml"
cp -r "${DIR}/app/images" "${APP_DIR}/images"
cp "${DIR}/app/dockctl_app.py" "${APP_DIR}/dockctl_app.py"
cp "${DIR}/backend/backend.py" "${APP_DIR}/backend.py"
cp "${DIR}/backend/test_backend.py" "${APP_DIR}/test_backend.py"
chmod +x "${APP_DIR}/dockctl_app.py"

echo "==> Lanzador, icono y entradas de menu"
mkdir -p "${BIN_DIR}"
ln -sf "${APP_DIR}/dockctl_app.py" "${BIN_DIR}/dockctl"
mkdir -p "${ICON_DIR}"
cp "${DIR}/app/images/docker.svg" "${ICON_DIR}/dockctl.svg"
gtk-update-icon-cache -f -q "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true

mkdir -p "${DESKTOP_DIR}"
sed "s|^Exec=.*|Exec=${BIN_DIR}/dockctl|" \
    "${DIR}/app/org.gato99.dockctl.desktop" \
    > "${DESKTOP_DIR}/org.gato99.dockctl.desktop"
if [ -f "${AUTOSTART_DIR}/org.gato99.dockctl.desktop" ]; then
    sed "s|^Exec=.*|Exec=${BIN_DIR}/dockctl --hidden|" \
        "${DIR}/app/org.gato99.dockctl.desktop" \
        > "${AUTOSTART_DIR}/org.gato99.dockctl.desktop"
fi
SHORTCUT_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "${SHORTCUT_DIR}" ] || SHORTCUT_DIR="${HOME}/Desktop"
if [ -d "${SHORTCUT_DIR}" ]; then
    chmod +x "${DESKTOP_DIR}/org.gato99.dockctl.desktop"
    ln -sf "${DESKTOP_DIR}/org.gato99.dockctl.desktop" "${SHORTCUT_DIR}/dockctl.desktop"
    gio set "${SHORTCUT_DIR}/dockctl.desktop" metadata::trusted true 2>/dev/null || true
fi

if [ "${REGEN_DIST}" = "1" ]; then
    echo "==> Paquetes de distribucion  (v${VERSION})"
    "${DIR}/build.sh"
fi

if [ "${UPDATE_RELEASE}" = "1" ]; then
    echo "==> Release GitHub  v${VERSION}"
    if [ "${REGEN_DIST}" != "1" ]; then
        echo "    (!) --release requiere regenerar dist/ (quita --no-dist)" >&2
        exit 1
    fi
    ASSETS=("${DIR}/dist/dockctl-v${VERSION}.tar.gz" "${DIR}/dist/dockctl-v${VERSION}.zip")
    if gh release view "v${VERSION}" >/dev/null 2>&1; then
        gh release upload "v${VERSION}" "${ASSETS[@]}" --clobber
        echo "    assets actualizados en la release v${VERSION}"
    else
        gh release create "v${VERSION}" --title "v${VERSION}" "${ASSETS[@]}"
        echo "    release v${VERSION} creada"
    fi
fi

echo
echo "Listo. App actualizada (v${VERSION}). Reinicia la instancia en marcha para aplicar los cambios."
