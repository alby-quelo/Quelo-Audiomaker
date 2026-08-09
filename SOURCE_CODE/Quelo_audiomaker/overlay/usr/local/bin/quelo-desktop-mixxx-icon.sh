#!/bin/bash
# Icona Mixxx sul Desktop (stesso schema di quelo-desktop-install-icon).
# Il Desktop live viene sostituito da QUELO-HOME (symlink): ripeti finché
# il Desktop "vero" è quello USB, altrimenti l'icona sparisce.
set -uo pipefail

SRC="/usr/share/applications/quelo-mixxx.desktop"
LOG_TAG="quelo-desktop-mixxx-icon"

log() { logger -t "${LOG_TAG}" "$*" 2>/dev/null || true; }

place() {
  local desktop_dir dest
  desktop_dir="$(readlink -f "${HOME:-/root}/Desktop" 2>/dev/null || true)"
  [[ -n "${desktop_dir}" ]] || desktop_dir="${HOME:-/root}/Desktop"
  dest="${desktop_dir}/quelo-mixxx.desktop"

  [[ -f "${SRC}" ]] || return 1
  mkdir -p "${desktop_dir}" 2>/dev/null || return 1
  cp -a "${SRC}" "${dest}" || return 1
  chmod a+x "${dest}" 2>/dev/null || true
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "/run/user/$(id -u)/bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  fi
  gio set "${dest}" metadata::trust true 2>/dev/null \
    || gio set -t string "${dest}" "metadata::trust" "true" 2>/dev/null \
    || true
  touch "${dest}" 2>/dev/null || true
  log "placed ${dest}"
  return 0
}

# Subito (Desktop locale), poi ritenta: mount QUELO-HOME può arrivare dopo.
place || true
for _ in $(seq 1 24); do
  sleep 5
  place || true
  ddir="$(readlink -f "${HOME:-/root}/Desktop" 2>/dev/null || true)"
  if [[ -n "${ddir}" && -f "${ddir}/quelo-mixxx.desktop" && "${ddir}" == */media/quelo-home/* ]]; then
    sleep 3
    place || true
    sleep 5
    place || true
    log "done (QUELO-HOME Desktop)"
    exit 0
  fi
done
log "done (timeout ritentativi)"
exit 0
