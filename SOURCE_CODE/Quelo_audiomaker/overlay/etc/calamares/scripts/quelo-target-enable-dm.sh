#!/bin/bash
# Abilita LightDM + autologin LXQt sull'installato (niente SDDM).
set -euo pipefail

ROOT="${1:-/}"
log() { echo "quelo-target-enable-dm: $*"; }

run() {
  if [[ "${ROOT}" == "/" ]]; then
    "$@"
  else
    chroot "${ROOT}" "$@"
  fi
}

username=""
CHOICES="${ROOT}/etc/quelo-install-choices.yaml"
if [[ -f "${CHOICES}" ]]; then
  username="$(grep -E '^username:' "${CHOICES}" 2>/dev/null | awk '{print $2}' | tr -d '"' || true)"
fi
if [[ -z "${username}" || "${username}" == "null" ]]; then
  username="$(awk -F: '$3>=1000 && $1!="nobody" {print $1; exit}' "${ROOT}/etc/passwd" || true)"
fi

if ! run dpkg -l lightdm 2>/dev/null | grep -q '^ii'; then
  log "ATTENZIONE: lightdm non installato"
  exit 0
fi

run systemctl enable lightdm.service
run systemctl set-default graphical.target 2>/dev/null || true
# SDDM non deve interferire (eventuale residuo immagini vecchie).
run systemctl disable sddm.service 2>/dev/null || true
run systemctl mask sddm.service 2>/dev/null || true
log "enabled lightdm"

mkdir -p "${ROOT}/etc/lightdm/lightdm.conf.d"
if [[ -n "${username}" ]]; then
  cat >"${ROOT}/etc/lightdm/lightdm.conf.d/50-quelo.conf" <<EOF
[Seat:*]
autologin-user=${username}
autologin-user-timeout=0
user-session=lxqt
autologin-session=lxqt
greeter-session=lightdm-gtk-greeter
EOF
  if ! grep -q '^autologin:' "${ROOT}/etc/group" 2>/dev/null; then
    run groupadd -r autologin 2>/dev/null || true
  fi
  run usermod -aG autologin "${username}" 2>/dev/null || true
  log "autologin → ${username} (lxqt)"
else
  cat >"${ROOT}/etc/lightdm/lightdm.conf.d/50-quelo.conf" <<'EOF'
[Seat:*]
user-session=lxqt
greeter-session=lightdm-gtk-greeter
EOF
  log "ATTENZIONE: nessun utente per autologin — solo sessione lxqt"
fi

# Niente autologin root via getty+startx sull'installato.
rm -rf "${ROOT}/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true
rm -f "${ROOT}/root/.bash_profile" 2>/dev/null || true
rm -rf "${ROOT}/etc/sddm.conf.d" 2>/dev/null || true

log "ok"
exit 0
