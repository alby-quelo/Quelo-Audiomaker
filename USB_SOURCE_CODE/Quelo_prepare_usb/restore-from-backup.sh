#!/bin/bash
# Ripristino rapido dal backup ISO write+verify OK (14/07/2026 06:12).
# Uso: ./restore-from-backup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKUP="${SCRIPT_DIR}/_backup_working_iso_verify_2026-07-14_0612"

if [[ ! -d "${BACKUP}" ]]; then
  echo "ERRORE: backup non trovato: ${BACKUP}" >&2
  exit 1
fi

for f in quelo-write-iso.py quelo_prepare_win_lib.py prepare-usb-gui.py quelo_prepare_common.py; do
  cp -a "${BACKUP}/${f}" "${SCRIPT_DIR}/${f}"
done
cp -a "${BACKUP}/Quelo_prepare_usb_gui_win-0.71-alpha.zip" \
  "${PROJECT_DIR}/DOWNLOAD/Quelo_prepare_usb_gui_win-0.71-alpha.zip"

echo "Ripristinato da ${BACKUP}"
md5sum "${SCRIPT_DIR}/quelo-write-iso.py" "${BACKUP}/quelo-write-iso.py"
md5sum "${PROJECT_DIR}/DOWNLOAD/Quelo_prepare_usb_gui_win-0.71-alpha.zip" \
  "${BACKUP}/Quelo_prepare_usb_gui_win-0.71-alpha.zip"
echo ""
echo "ZIP pronto: ${PROJECT_DIR}/DOWNLOAD/Quelo_prepare_usb_gui_win-0.71-alpha.zip"
echo "CANCELLA la cartella vecchia sul Desktop Windows e usa SOLO questo zip."
