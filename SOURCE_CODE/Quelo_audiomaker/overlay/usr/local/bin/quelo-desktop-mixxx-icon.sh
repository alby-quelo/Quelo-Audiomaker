#!/bin/bash
# Icona Mixxx sul Desktop — SOLO dopo il refresh trust (altrimenti sparisce).
set -uo pipefail

SRC="/usr/share/applications/quelo-mixxx.desktop"
LOG_TAG="quelo-desktop-mixxx-icon"
TRUST_DONE="/tmp/quelo-trust-desktop-icons.done"
TRUST_LOCK="/tmp/quelo-trust-desktop-icons.lock"

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
  gio set -t string "${dest}" metadata::trust true 2>/dev/null \
    || gio set "${dest}" metadata::trust true 2>/dev/null \
    || true
  touch "${dest}" 2>/dev/null || true
  log "placed ${dest}"
  return 0
}

# Attendi fine del trust (refresh desktop). Non piazzare prima: si perde.
wait_trust_done() {
  local end=$((SECONDS + 180))
  while ((SECONDS < end)); do
    if [[ -f "${TRUST_DONE}" ]] && [[ ! -d "${TRUST_LOCK}" ]]; then
      return 0
    fi
    sleep 1
  done
  log "ATTENZIONE: timeout attesa trust — provo comunque"
  return 1
}

wait_trust_done || true
sleep 2

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
