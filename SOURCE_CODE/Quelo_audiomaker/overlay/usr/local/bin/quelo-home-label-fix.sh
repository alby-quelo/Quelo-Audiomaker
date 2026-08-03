#!/bin/bash
# Icona HOME sul Desktop (A+B con pcmanfm QuickExec).
#
# Trust LXQt = metadata::trust in ~/.local/share/gvfs-metadata (NON sul file
# exFAT). Su live /root e' tmpfs → va rifatto ogni sessione.
# Chiave corretta upstream: metadata::trust (non metadata::trusted).
set -uo pipefail

DESKTOP_DIR="${HOME}/Desktop"
DESKTOP_LINK="${DESKTOP_DIR}/HOME.desktop"
PCMANFM_CONF="${HOME}/.config/pcmanfm-qt/lxqt/settings.conf"
HOME_MNT="/media/quelo-home"
HOME_URL="file:///media/quelo-home/home"

log() { logger -t quelo-home-label-fix "$*" 2>/dev/null || true; }

ensure_quick_exec() {
  mkdir -p "$(dirname "${PCMANFM_CONF}")" 2>/dev/null || true
  if [[ ! -f "${PCMANFM_CONF}" ]]; then
    printf '%s\n' '[Behavior]' 'QuickExec=true' >"${PCMANFM_CONF}"
    log "creato settings.conf con QuickExec=true"
    return
  fi
  if grep -q '^QuickExec=' "${PCMANFM_CONF}" 2>/dev/null; then
    sed -i 's/^QuickExec=.*/QuickExec=true/' "${PCMANFM_CONF}"
  elif grep -q '^\[Behavior\]' "${PCMANFM_CONF}" 2>/dev/null; then
    sed -i '/^\[Behavior\]/a QuickExec=true' "${PCMANFM_CONF}"
  else
    printf '\n[Behavior]\nQuickExec=true\n' >>"${PCMANFM_CONF}"
  fi
  if grep -q '^DesktopShortcuts=.*Home' "${PCMANFM_CONF}" 2>/dev/null; then
    # Non azzerare: Trash deve restare (Cestino solo sul Desktop).
    sed -i 's/^DesktopShortcuts=.*/DesktopShortcuts=Trash/' "${PCMANFM_CONF}"
    log "disattivato DesktopShortcuts=Home (tenuto Trash)"
  fi
  log "QuickExec=true in pcmanfm-qt settings"
}

wait_session() {
  local end=$((SECONDS + 90))
  while ((SECONDS < end)); do
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "/run/user/$(id -u)/bus" ]]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    fi
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && pgrep -x pcmanfm-qt >/dev/null 2>&1; then
      # Lascia al desktop il tempo di caricare le icone.
      sleep 2
      return 0
    fi
    sleep 1
  done
  log "ATTENZIONE: timeout attesa D-Bus/pcmanfm-qt"
  return 1
}

trust_icon() {
  local f="$1"
  [[ -e "${f}" ]] || return 1
  chmod a+x "${f}" 2>/dev/null || true
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "/run/user/$(id -u)/bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  fi
  # Chiave LXQt verificata: metadata::trust (metadata::trusted non basta).
  # Richiede anche file NON world-writable (fmask=0022 sul mount QUELO-HOME).
  if gio set "${f}" metadata::trust true 2>/dev/null \
     || gio set -t string "${f}" "metadata::trust" "true" 2>/dev/null; then
    log "gio metadata::trust OK: ${f}"
    touch "${f}" 2>/dev/null || true
    return 0
  fi
  log "ATTENZIONE: gio metadata::trust fallito su ${f}"
  return 1
}

write_link_desktop() {
  local dest="$1"
  cat >"${dest}" <<EOF
[Desktop Entry]
Version=1.0
Type=Link
Name=HOME
Comment=Cartella home (QUELO-HOME)
Icon=user-home
URL=${HOME_URL}
EOF
  chmod a+x "${dest}" 2>/dev/null || true
}

write_app_desktop() {
  local dest="$1"
  cat >"${dest}" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=HOME
Comment=Cartella home
Exec=/usr/local/bin/quelo-filemanager
Icon=user-home
Terminal=false
StartupNotify=true
Categories=System;FileTools;FileManager;
EOF
  chmod a+x "${dest}" 2>/dev/null || true
}

place_icon() {
  local dir="$1"
  local dest="${dir}/HOME.desktop"
  mkdir -p "${dir}" 2>/dev/null || return 1
  rm -f "${dir}/user-home.desktop" "${dir}/Home.desktop" "${dir}/Home" 2>/dev/null || true
  if mountpoint -q "${HOME_MNT}" 2>/dev/null; then
    write_link_desktop "${dest}" || return 1
  else
    write_app_desktop "${dest}" || return 1
  fi
  [[ -f "${dest}" ]] || return 1
  return 0
}

ensure_quick_exec
wait_session || true

end=$((SECONDS + 90))
placed=0
while ((SECONDS < end)); do
  if mountpoint -q "${HOME_MNT}" 2>/dev/null \
     && [[ -L "${DESKTOP_DIR}" ]] \
     && [[ "$(readlink -f "${DESKTOP_DIR}" 2>/dev/null)" == "${HOME_MNT}/home/Desktop" ]]; then
    if place_icon "${DESKTOP_DIR}"; then
      placed=1
      trust_icon "${DESKTOP_LINK}" || true
      log "HOME.desktop su QUELO-HOME (Type=Link) + trust"
      break
    fi
  fi
  sleep 1
done

if [[ "${placed}" -eq 0 ]]; then
  if place_icon "${DESKTOP_DIR}"; then
    trust_icon "${DESKTOP_LINK}" || true
    log "HOME.desktop fallback ${DESKTOP_DIR}"
    placed=1
  else
    log "ERRORE: impossibile creare HOME.desktop"
  fi
fi

# Ricontrolli brevi (mount tardivo / gio non pronto al primo tentativo).
if [[ "${placed}" -eq 1 ]]; then
  for _ in 1 2 3 4 5; do
    sleep 3
    if [[ ! -e "${DESKTOP_LINK}" ]] && mountpoint -q "${HOME_MNT}" 2>/dev/null; then
      place_icon "${DESKTOP_DIR}" || true
      log "HOME.desktop ripristinato dopo race"
    fi
    trust_icon "${DESKTOP_LINK}" || true
    # Anche il Cestino (DesktopShortcuts=Trash → trash-can.desktop).
    trust_icon "${DESKTOP_DIR}/trash-can.desktop" || true
  done
fi

exit 0
