#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${ROOT_DIR}/dist"
PACKAGE_NAME="mactahoe-gnome-theme"
VERSION="$(date +%Y%m%d)"
ARCHIVE="${PACKAGE_DIR}/${PACKAGE_NAME}-${VERSION}.tar.gz"

mkdir -p "${PACKAGE_DIR}"

tar \
  --exclude='.git' \
  --exclude='dist' \
  --exclude='vendor/*/.git' \
  --exclude='vendor/*/*/.git' \
  -czf "${ARCHIVE}" \
  -C "${ROOT_DIR}" \
  scripts vendor README.md

printf '%s\n' "${ARCHIVE}"
