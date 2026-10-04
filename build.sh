#!/usr/bin/env bash
set -euo pipefail

# Genera los paquetes de codigo fuente: dist/dockctl-v<version>.tar.gz y .zip
cd "$(dirname "${BASH_SOURCE[0]}")"
ROOT="$PWD"
NAME="$(basename "${ROOT}")"

VERSION="$(cat VERSION 2>/dev/null || true)"
if [ -z "${VERSION}" ]; then
    VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0")"
fi

mkdir -p dist
rm -f "dist/dockctl-v${VERSION}.tar.gz" "dist/dockctl-v${VERSION}.zip"

tar --exclude=.git --exclude=dist --exclude=__pycache__ --exclude='*.pyc' \
    -czf "dist/dockctl-v${VERSION}.tar.gz" -C "${ROOT}/.." "${NAME}"
(cd "${ROOT}/.." && zip -qr "${ROOT}/dist/dockctl-v${VERSION}.zip" "${NAME}" \
    -x "${NAME}/.git/*" -x "${NAME}/dist/*" \
    -x "*/__pycache__/*" -x "*.pyc")

echo "paquetes generados (v${VERSION}):"
echo "  dist/dockctl-v${VERSION}.tar.gz"
echo "  dist/dockctl-v${VERSION}.zip"
