#!/bin/bash
# Adatta path root→generici, look desktop utente, versioni INSTALLED.
set -euo pipefail

ROOT="${1:-/}"
PATCHES="${QUELO_INSTALL_PATCHES:-/etc/calamares/patches}"

log() { echo "quelo-target-adapt-user-paths: $*"; }

install_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  [[ -f "${src}" ]] || { log "SKIP manca ${src}"; return 0; }
  mkdir -p "$(dirname "${ROOT}${dest}")"
  cp -a "${src}" "${ROOT}${dest}"
  chmod "${mode}" "${ROOT}${dest}"
  log "installed ${dest}"
}

chown_user_tree() {
  local home_path="$1" user="$2"
  local uid gid
  uid="$(awk -F: -v u="${user}" '$1==u{print $3}' "${ROOT}/etc/passwd" 2>/dev/null || true)"
  gid="$(awk -F: -v u="${user}" '$1==u{print $4}' "${ROOT}/etc/passwd" 2>/dev/null || true)"
  if [[ -n "${uid}" && -n "${gid}" ]]; then
    chown -R "${uid}:${gid}" "${home_path}/.config" 2>/dev/null || true
  fi
}

# Copia look live (sfondo pcmanfm + lxqt) in skel e nelle home utenti.
seed_desktop_look() {
  local src_pcmanfm="${ROOT}/root/.config/pcmanfm-qt"
  local src_lxqt="${ROOT}/root/.config/lxqt"
  local skel_cfg="${ROOT}/etc/skel/.config"
  local openbox_inst="${PATCHES}/openbox-autostart.INSTALLED"

  mkdir -p "${skel_cfg}"

  if [[ -d "${src_pcmanfm}" ]]; then
    mkdir -p "${skel_cfg}/pcmanfm-qt"
    cp -a "${src_pcmanfm}/." "${skel_cfg}/pcmanfm-qt/"
    # Default di sistema (nuovi utenti / fallback)
    mkdir -p "${ROOT}/etc/xdg/pcmanfm-qt/lxqt"
    if [[ -f "${src_pcmanfm}/lxqt/settings.conf" ]]; then
      cp -a "${src_pcmanfm}/lxqt/settings.conf" \
        "${ROOT}/etc/xdg/pcmanfm-qt/lxqt/settings.conf"
    fi
    log "seed pcmanfm-qt → skel + /etc/xdg"
  else
    log "SKIP seed pcmanfm-qt (manca ${src_pcmanfm})"
  fi

  if [[ -d "${src_lxqt}" ]]; then
    mkdir -p "${skel_cfg}/lxqt"
    cp -a "${src_lxqt}/." "${skel_cfg}/lxqt/"
    log "seed lxqt → skel"
  fi

  if [[ -f "${openbox_inst}" ]]; then
    mkdir -p "${skel_cfg}/openbox"
    cp -a "${openbox_inst}" "${skel_cfg}/openbox/autostart"
    chmod 755 "${skel_cfg}/openbox/autostart"
  fi

  shopt -s nullglob
  for home in "${ROOT}/home"/*; do
    [[ -d "${home}" ]] || continue
    local user
    user="$(basename "${home}")"
    [[ "${user}" == "lost+found" ]] && continue
    mkdir -p "${home}/.config"
    if [[ -d "${src_pcmanfm}" ]]; then
      mkdir -p "${home}/.config/pcmanfm-qt"
      cp -a "${src_pcmanfm}/." "${home}/.config/pcmanfm-qt/"
    fi
    if [[ -d "${src_lxqt}" ]]; then
      mkdir -p "${home}/.config/lxqt"
      cp -a "${src_lxqt}/." "${home}/.config/lxqt/"
    fi
    if [[ -f "${openbox_inst}" ]]; then
      mkdir -p "${home}/.config/openbox"
      cp -a "${openbox_inst}" "${home}/.config/openbox/autostart"
      chmod 755 "${home}/.config/openbox/autostart"
    fi
    chown_user_tree "${home}" "${user}"
    log "seed desktop → /home/${user}"
  done
  shopt -u nullglob
}

# Installata: shortcut Home di sistema SOLO se la home Unix è quella "vera"
# (disco unico o HOME ext4). Con HOME exFAT → solo Trash + icona Link (vedi configure-home).
enable_desktop_home_shortcut() {
  local conf shortcuts="Home,Trash" choices="${ROOT}/etc/quelo-install-choices.yaml"
  local separate="" fs=""

  if [[ -f "${choices}" ]]; then
    separate="$(grep -E '^separateHome:' "${choices}" | awk '{print $2}' | tr -d '"' || true)"
    fs="$(grep -E '^homeFilesystem:' "${choices}" | awk '{print $2}' | tr -d '"' || true)"
    if [[ "${separate}" == "true" && "${fs}" == "exfat" ]]; then
      shortcuts="Trash"
    fi
  fi

  set_one() {
    conf="$1"
    [[ -f "${conf}" ]] || return 0
    if grep -q '^DesktopShortcuts=' "${conf}"; then
      sed -i "s/^DesktopShortcuts=.*/DesktopShortcuts=${shortcuts}/" "${conf}"
    else
      if grep -q '^\[Desktop\]' "${conf}"; then
        sed -i "/^\[Desktop\]/a DesktopShortcuts=${shortcuts}" "${conf}"
      else
        printf '\n[Desktop]\nDesktopShortcuts=%s\n' "${shortcuts}" >>"${conf}"
      fi
    fi
  }

  set_one "${ROOT}/etc/skel/.config/pcmanfm-qt/lxqt/settings.conf"
  set_one "${ROOT}/etc/xdg/pcmanfm-qt/lxqt/settings.conf"
  shopt -s nullglob
  for conf in "${ROOT}/home"/*/.config/pcmanfm-qt/lxqt/settings.conf; do
    set_one "${conf}"
  done
  shopt -u nullglob
  log "DesktopShortcuts=${shortcuts} (installata)"
}

install_file "${PATCHES}/quelo-power.INSTALLED.sh" /usr/local/bin/quelo-power 0755
install_file "${PATCHES}/openbox-autostart.INSTALLED" /etc/skel/.config/openbox/autostart 0755

seed_desktop_look
enable_desktop_home_shortcut

if grep -q '/root/Immagini' "${ROOT}/usr/local/bin/quelo-screenshot" 2>/dev/null; then
  sed -i 's|SAVE_DIR="/root/Immagini"|SAVE_DIR="${XDG_PICTURES_DIR:-${HOME}/Immagini}"|' \
    "${ROOT}/usr/local/bin/quelo-screenshot"
  log "patched quelo-screenshot"
fi

if [[ -f "${ROOT}/usr/local/bin/quelo-filemanager" ]]; then
  cat >"${ROOT}/usr/local/bin/quelo-filemanager" <<'EOF'
#!/bin/bash
# Installato: apre la home utente (niente QUELO-HOME obbligatorio).
exec pcmanfm-qt "${HOME:-/}"
EOF
  chmod 755 "${ROOT}/usr/local/bin/quelo-filemanager"
  log "replaced quelo-filemanager"
fi

# Rimuovi launcher installer dalla home/skel dell'installato.
rm -f "${ROOT}/usr/share/applications/quelo-install.desktop" 2>/dev/null || true
rm -f "${ROOT}/usr/local/bin/quelo-install" 2>/dev/null || true
rm -f "${ROOT}/usr/local/bin/quelo-calamares-disk-layout" 2>/dev/null || true
rm -f "${ROOT}/usr/local/bin/quelo-calamares-grub-confirm" 2>/dev/null || true
rm -f "${ROOT}/usr/local/bin/quelo-calamares-riepilogo" 2>/dev/null || true
rm -f "${ROOT}/usr/local/bin/quelo-desktop-install-icon.sh" 2>/dev/null || true
rm -f "${ROOT}/etc/skel/Desktop/quelo-install.desktop" 2>/dev/null || true
find "${ROOT}/home" -maxdepth 3 -name 'quelo-install.desktop' -delete 2>/dev/null || true

log "ok"
exit 0
