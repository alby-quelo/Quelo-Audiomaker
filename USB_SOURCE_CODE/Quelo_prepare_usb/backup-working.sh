#!/bin/bash
# Salva snapshot dei sorgenti prepare-usb Windows PRIMA di modifiche rischiose.
# Uso: ./backup-working.sh [nota-opzionale]
#
# Esempio:
#   ./backup-working.sh "prima-fix-partizioni-gpt"
#   cp _backup_.../quelo_prepare_win_lib.py .   # ripristino manuale

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STAMP="$(date +%Y-%m-%d_%H%M)"
NOTE="${1:-manual}"
SAFE_NOTE="$(echo "${NOTE}" | tr ' /\\:' '____' | tr -cd '[:alnum:]_-' | head -c 40)"
DEST="${SCRIPT_DIR}/_backup_${STAMP}_${SAFE_NOTE}"

FILES=(
  quelo-write-iso.py
  quelo_prepare_win_lib.py
  quelo_prepare_common.py
  prepare-usb-gui.py
  prepare-usb-gui.sh
  prepare-usb.sh
  build-archives.sh
)

mkdir -p "${DEST}"

for f in "${FILES[@]}"; do
  if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
    cp -a "${SCRIPT_DIR}/${f}" "${DEST}/"
  fi
done

if [[ -f "${PROJECT_DIR}/DOWNLOAD/Quelo_prepare_usb_gui_win-0.71-alpha.zip" ]]; then
  cp -a "${PROJECT_DIR}/DOWNLOAD/Quelo_prepare_usb_gui_win-0.71-alpha.zip" "${DEST}/"
fi

{
  echo "Backup: ${STAMP} — ${NOTE}"
  echo ""
  echo "Ripristino rapido (senza git):"
  echo "  cd ${SCRIPT_DIR}"
  for f in "${FILES[@]}"; do
    [[ -f "${DEST}/${f}" ]] && echo "  cp ${DEST}/${f} ."
  done
  echo "  cp ${DEST}/Quelo_prepare_usb_gui_win-0.71-alpha.zip ../../DOWNLOAD/"
  echo ""
  md5sum "${DEST}"/* 2>/dev/null || true
} >"${DEST}/RIPRISTINO.txt"

echo "OK: backup in ${DEST}"
cat "${DEST}/RIPRISTINO.txt"
