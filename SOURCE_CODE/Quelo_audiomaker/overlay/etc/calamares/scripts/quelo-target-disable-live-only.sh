#!/bin/bash
# Disattiva sul target tutto ciò che serve SOLO alla live.
# NON tocca i file sull'ISO/live in esecuzione: opera solo su ${ROOT}.
set -euo pipefail

ROOT="${1:-/}"
log() { echo "quelo-target-disable-live-only: $*"; }

run() {
  if [[ "${ROOT}" == "/" ]]; then
    "$@"
  else
    chroot "${ROOT}" "$@"
  fi
}

log "disabilito servizi USB Quelo"
run systemctl disable quelo-usb-mount-home.service 2>/dev/null || true
run systemctl disable quelo-usb-mount-persist.service 2>/dev/null || true
run systemctl mask quelo-usb-mount-home.service 2>/dev/null || true
run systemctl mask quelo-usb-mount-persist.service 2>/dev/null || true

# Stesse regole della live: QUELO-HOME visibile; persistence + ISO nascosti.
UDEV_RULES="${ROOT}/etc/udev/rules.d/99-quelo-ignore-managed-partitions.rules"
log "udev: QUELO-HOME visibile; nascosti persistence e volumi ISO"
cat > "${UDEV_RULES}" <<'EOF'
# Quelo Audiomaker — regole udisks (sistema installato)
# QUELO-HOME: VISIBILE. persistence + volumi ISO: nascosti.
SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="persistence", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="QUELO-AUDIOMAKER*", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="QUELO-VIDEOMAKER*", ENV{UDISKS_IGNORE}="1"
SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="QUELO-OFFICE*", ENV{UDISKS_IGNORE}="1"
EOF

# Solo ripristino sessione live: sull'installata non serve.
# Trust icone Desktop (badge !): DEVE restare anche sull'installata
# (HOME.desktop sta su ~/Desktop ext4; fmask di /media/HOME non basta).
log "rimuovo autostart ripristino sessione (solo installata; trust icone resta)"
rm -f "${ROOT}/etc/xdg/autostart/quelo-load-sessione-gui.desktop"
rm -f "${ROOT}/etc/skel/.config/autostart/quelo-load-sessione-gui.desktop" 2>/dev/null || true
find "${ROOT}/home" -path '*/.config/autostart/quelo-load-sessione-gui.desktop' -delete 2>/dev/null || true

# Autologin root via getty+startx: non serve sull'installato.
rm -rf "${ROOT}/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true
rm -f "${ROOT}/root/.bash_profile" 2>/dev/null || true

log "ok"
exit 0
