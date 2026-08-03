#!/bin/bash
# quelo-trust-desktop-icons.sh
#
# Rimuove il badge "!" (untrusted) dalle icone .desktop sul Desktop
# gestito da PCManFM-Qt / LXQt.
#
# CAUSA DEL BUG
# -------------
# PCManFM-Qt mostra un emblema "!" su ogni .desktop eseguibile non fidato.
# La fiducia e' l'attributo GVFS `metadata::trust` (stringa "true"), salvato in:
#   ~/.local/share/gvfs-metadata/
# Sulla live /root e' tmpfs (overlay): al reboot il trust sparisce.
# Le .desktop stanno su QUELO-HOME (exFAT) e restano, quindi il "!" torna.
#
# Chiave corretta: metadata::trust  (NON metadata::trusted — non basta per LXQt)
# Richiede anche file NON world-writable (fmask=0022 sul mount QUELO-HOME).
#
# ORDINE CRITICO
# --------------
# 1) spegnere il gestore desktop (pcmanfm-qt --desktop-off)
# 2) impostare metadata::trust su tutte le *.desktop
# 3) riaccendere il desktop (cosi' carica gia' trustato)
# Se si fa gio set a desktop gia' caricato, PCManFM tiene il badge in cache.
#
# Verificato su Quelo Audiomaker 0.08 alpha (2026-07-30).
set -uo pipefail

DESKTOP_DIR="${HOME:-/root}/Desktop"
LOG_TAG="quelo-trust-desktop-icons"
LOCK_DIR="/tmp/quelo-trust-desktop-icons.lock"

log() { logger -t "${LOG_TAG}" "$*" 2>/dev/null || true; }

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  log "gia' in esecuzione, esco"
  exit 0
fi
trap 'rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT

ensure_dbus() {
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "/run/user/$(id -u)/bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  fi
}

wait_session() {
  local end=$((SECONDS + 90))
  while ((SECONDS < end)); do
    ensure_dbus
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && pgrep -x lxqt-session >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  log "ATTENZIONE: timeout attesa sessione"
  return 1
}

trust_icon() {
  local f="$1"
  [[ -f "${f}" ]] || return 1
  chmod a+x "${f}" 2>/dev/null || true
  ensure_dbus
  if gio set -t string "${f}" metadata::trust true 2>/dev/null \
     || gio set "${f}" metadata::trust true 2>/dev/null; then
    log "trust OK: ${f}"
    return 0
  fi
  log "ATTENZIONE: trust fallito: ${f}"
  return 1
}

trust_all_desktop_icons() {
  local f count=0
  shopt -s nullglob
  for f in "${DESKTOP_DIR}"/*.desktop; do
    trust_icon "${f}" && ((count++)) || true
  done
  shopt -u nullglob
  log "icone trustate: ${count}"
}

resolve_xauth() {
  if [[ -n "${XAUTHORITY:-}" && -r "${XAUTHORITY}" ]]; then
    return 0
  fi
  if [[ -r "${HOME:-}/.Xauthority" ]]; then
    export XAUTHORITY="${HOME}/.Xauthority"
  elif [[ -r /root/.Xauthority ]]; then
    export XAUTHORITY="/root/.Xauthority"
  else
    export XAUTHORITY="${HOME:-/root}/.Xauthority"
  fi
}

stop_desktop() {
  export DISPLAY="${DISPLAY:-:0}"
  resolve_xauth
  ensure_dbus
  if pgrep -x pcmanfm-qt >/dev/null 2>&1; then
    pcmanfm-qt --desktop-off 2>/dev/null || true
    local i
    for i in 1 2 3 4 5; do
      pgrep -x pcmanfm-qt >/dev/null 2>&1 || break
      sleep 1
    done
  fi
}

restore_wallpaper() {
  local conf="${HOME:-/root}/.config/pcmanfm-qt/lxqt/settings.conf"
  local wall mode
  wall="$(awk -F= '/^Wallpaper=/{print $2; exit}' "${conf}" 2>/dev/null || true)"
  mode="$(awk -F= '/^WallpaperMode=/{print $2; exit}' "${conf}" 2>/dev/null || true)"
  [[ -n "${wall}" && -f "${wall}" ]] || return 0
  pcmanfm-qt --set-wallpaper="${wall}" --wallpaper-mode="${mode:-stretch}" 2>/dev/null || true
}

start_desktop() {
  export DISPLAY="${DISPLAY:-:0}"
  resolve_xauth
  ensure_dbus
  if pgrep -x pcmanfm-qt >/dev/null 2>&1; then
    restore_wallpaper
    return 0
  fi
  nohup pcmanfm-qt --desktop --profile=lxqt >/dev/null 2>&1 &
  disown || true
  local i
  for i in 1 2 3 4 5 6 7 8; do
    if pgrep -x pcmanfm-qt >/dev/null 2>&1; then
      sleep 1
      restore_wallpaper
      return 0
    fi
    sleep 1
  done
  log "ATTENZIONE: pcmanfm-qt desktop non ripartito"
  return 1
}

is_live() {
  [[ -d /run/live ]] && return 0
  grep -Eq '(^|[[:space:]])boot=live([[:space:]]|$)' /proc/cmdline 2>/dev/null && return 0
  return 1
}

icon_is_trusted() {
  local f="$1" info
  [[ -f "${f}" ]] || return 1
  info="$(gio info -a metadata::trust "${f}" 2>/dev/null || true)"
  printf '%s' "${info}" | grep -qiE 'metadata::trust[: ]+true'
}

all_desktop_icons_trusted() {
  local f any=0
  shopt -s nullglob
  for f in "${DESKTOP_DIR}"/*.desktop; do
    any=1
    if ! icon_is_trusted "${f}"; then
      shopt -u nullglob
      return 1
    fi
  done
  shopt -u nullglob
  [[ "${any}" -eq 1 ]]
}

run_live_trust_cycles() {
  # LIVE invariata: due cicli stop/start (tmpfs perde il trust ogni boot).
  stop_desktop
  trust_all_desktop_icons
  start_desktop
  sleep 2

  trust_all_desktop_icons
  if [[ -f "${DESKTOP_DIR}/trash-can.desktop" ]]; then
    stop_desktop
    trust_all_desktop_icons
    start_desktop
    sleep 1
    trust_all_desktop_icons
  fi
}

run_installed_trust_once() {
  # INSTALLATA: gvfs-metadata resta su /home.
  # 1) già fidato → niente spegnimento desktop
  # 2) altrimenti un solo ciclo (niente secondo lampeggio per il cestino)
  if all_desktop_icons_trusted; then
    log "installata: icone già fidate, skip (niente nero)"
    return 0
  fi
  log "installata: un solo ciclo trust"
  stop_desktop
  trust_all_desktop_icons
  start_desktop
}

place_mixxx_desktop_icon() {
  local src="/usr/share/applications/quelo-mixxx.desktop"
  local desktop_dir dest
  desktop_dir="$(readlink -f "${DESKTOP_DIR}" 2>/dev/null || true)"
  [[ -n "${desktop_dir}" ]] || desktop_dir="${DESKTOP_DIR}"
  dest="${desktop_dir}/quelo-mixxx.desktop"
  [[ -f "${src}" ]] || { log "SKIP mixxx: manca ${src}"; return 1; }
  mkdir -p "${desktop_dir}" 2>/dev/null || return 1
  cp -a "${src}" "${dest}" || return 1
  chmod a+x "${dest}" 2>/dev/null || true
  log "mixxx desktop: ${dest}"
  return 0
}

# --- main ---
wait_session || true
ensure_dbus
export DISPLAY="${DISPLAY:-:0}"
resolve_xauth

if is_live; then
  run_live_trust_cycles
  # Mixxx DOPO il refresh: altrimenti l'icona sparisce col desktop-off/on.
  if place_mixxx_desktop_icon; then
    stop_desktop
    trust_all_desktop_icons
    start_desktop
    sleep 1
    trust_all_desktop_icons
  fi
else
  run_installed_trust_once
  # Installata: assicurati che Mixxx sia sul Desktop (skel) e fidato.
  place_mixxx_desktop_icon || true
  if ! all_desktop_icons_trusted; then
    stop_desktop
    trust_all_desktop_icons
    start_desktop
  else
    trust_icon "${DESKTOP_DIR}/quelo-mixxx.desktop" || true
  fi
fi

# Cuscinetto dopo l'ultimo refresh, poi marker (il ripristino sessione aspetta questo).
sleep 1
touch /tmp/quelo-trust-desktop-icons.done 2>/dev/null || true
log "completato (done marker)"
exit 0
