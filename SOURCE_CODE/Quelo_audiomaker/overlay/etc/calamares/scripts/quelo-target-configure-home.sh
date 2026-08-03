#!/bin/bash
# Configura HOME exFAT (XDG) o lascia /home ext4 nativo.
# Legge /etc/quelo-install-choices.yaml copiato sul target (se presente).
set -euo pipefail

ROOT="${1:-/}"
CHOICES="${ROOT}/etc/quelo-install-choices.yaml"
log() { echo "quelo-target-configure-home: $*"; }

[[ -f "${CHOICES}" ]] || { log "nessun choices file, skip"; exit 0; }

separate="$(grep -E '^separateHome:' "${CHOICES}" | awk '{print $2}' | tr -d '"')"
fs="$(grep -E '^homeFilesystem:' "${CHOICES}" | awk '{print $2}' | tr -d '"')"
username="$(grep -E '^username:' "${CHOICES}" 2>/dev/null | awk '{print $2}' | tr -d '"' || true)"

# Username reale creato da Calamares (fallback da choices se presente)
if [[ -z "${username}" || "${username}" == "null" ]]; then
  username="$(awk -F: '$3>=1000 && $1!="nobody" {print $1; exit}' "${ROOT}/etc/passwd" || true)"
fi

log "separateHome=${separate} homeFilesystem=${fs} user=${username:-?}"

if [[ "${separate}" != "true" ]]; then
  log "layout unica /, niente setup HOME separata"
  exit 0
fi

if [[ "${fs}" != "exfat" ]]; then
  log "HOME ext4 su /home — ok nativo"
  exit 0
fi

write_home_desktop_link() {
  local dest="$1"
  mkdir -p "$(dirname "${dest}")"
  cat >"${dest}" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Link
Name=HOME
Comment=Partizione HOME (exFAT)
Icon=user-home
URL=file:///media/HOME
EOF
  chmod a+x "${dest}" 2>/dev/null || true
}

set_pcmanfm_trash_only() {
  local conf="$1"
  [[ -f "${conf}" ]] || return 0
  if grep -q '^DesktopShortcuts=' "${conf}"; then
    sed -i 's/^DesktopShortcuts=.*/DesktopShortcuts=Trash/' "${conf}"
  elif grep -q '^\[Desktop\]' "${conf}"; then
    sed -i '/^\[Desktop\]/a DesktopShortcuts=Trash' "${conf}"
  else
    printf '\n[Desktop]\nDesktopShortcuts=Trash\n' >>"${conf}"
  fi
}

# HOME exFAT montata in /media/HOME: home Unix piccola su /, XDG verso HOME.
mkdir -p "${ROOT}/media/HOME"
if [[ -n "${username}" && -d "${ROOT}/home/${username}" ]]; then
  USER_HOME="${ROOT}/home/${username}"
  mkdir -p "${USER_HOME}/.config" "${USER_HOME}/Desktop"
  # Link comodo
  ln -sfn /media/HOME "${USER_HOME}/HOME" 2>/dev/null || true

  # user-dirs: Documenti/Video/Immagini/Download → /media/HOME/...
  # Desktop resta su /home/utente/Desktop (icone .desktop).
  cat >"${USER_HOME}/.config/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="/media/HOME/Download"
XDG_TEMPLATES_DIR="$HOME/Models"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="/media/HOME/Documenti"
XDG_MUSIC_DIR="/media/HOME/Musica"
XDG_PICTURES_DIR="/media/HOME/Immagini"
XDG_VIDEOS_DIR="/media/HOME/Video"
EOF
  mkdir -p "${ROOT}/media/HOME"/{Documenti,Video,Immagini,Download,Musica}

  # Niente Home stock pcmanfm (aprirebbe /home/utente); icona Link → /media/HOME.
  set_pcmanfm_trash_only "${USER_HOME}/.config/pcmanfm-qt/lxqt/settings.conf"
  set_pcmanfm_trash_only "${ROOT}/etc/skel/.config/pcmanfm-qt/lxqt/settings.conf"
  set_pcmanfm_trash_only "${ROOT}/etc/xdg/pcmanfm-qt/lxqt/settings.conf"
  write_home_desktop_link "${USER_HOME}/Desktop/HOME.desktop"
  write_home_desktop_link "${ROOT}/etc/skel/Desktop/HOME.desktop"

  # File manager / menu: apre la partizione HOME, non /home/utente.
  cat >"${ROOT}/usr/local/bin/quelo-filemanager" <<'EOF'
#!/bin/bash
# Installato con HOME exFAT: apre /media/HOME.
exec pcmanfm-qt /media/HOME
EOF
  chmod 755 "${ROOT}/usr/local/bin/quelo-filemanager"

  if grep -q "^${username}:" "${ROOT}/etc/passwd"; then
    uid="$(awk -F: -v u="${username}" '$1==u{print $3}' "${ROOT}/etc/passwd")"
    gid="$(awk -F: -v u="${username}" '$1==u{print $4}' "${ROOT}/etc/passwd")"
    chown -R "${uid}:${gid}" "${USER_HOME}/.config" "${USER_HOME}/Desktop" 2>/dev/null || true
  fi
  log "HOME exFAT: Desktop Link → /media/HOME, XDG ok (${username})"
fi

# fstab: forzare fmask/dmask 0022 su /media/HOME (exFAT installata).
# Come live QUELO-HOME: NON 0000 → altrimenti world-writable e badge "!".
fix_home_exfat_fstab() {
  local fstab="${ROOT}/etc/fstab"
  local uid=1000 gid=1000 opts line
  [[ -f "${fstab}" ]] || { log "ERRORE: manca ${fstab}"; return 1; }

  if [[ -n "${username}" ]] && grep -q "^${username}:" "${ROOT}/etc/passwd"; then
    uid="$(awk -F: -v u="${username}" '$1==u{print $3}' "${ROOT}/etc/passwd")"
    gid="$(awk -F: -v u="${username}" '$1==u{print $4}' "${ROOT}/etc/passwd")"
  fi
  opts="uid=${uid},gid=${gid},fmask=0022,dmask=0022"

  if ! grep -E '[[:space:]]/media/HOME[[:space:]]' "${fstab}" >/dev/null 2>&1; then
    log "nota: /media/HOME non in fstab (verificare partizione HOME)"
    return 0
  fi

  # Riscrivi il campo options (4°) della riga /media/HOME.
  awk -v opts="${opts}" '
    BEGIN { OFS="\t" }
    /^[[:space:]]*#/ || NF < 4 { print; next }
    $2 == "/media/HOME" {
      $4 = opts
      print
      next
    }
    { print }
  ' "${fstab}" >"${fstab}.quelo-new" && mv "${fstab}.quelo-new" "${fstab}"

  line="$(grep -E '[[:space:]]/media/HOME[[:space:]]' "${fstab}" | head -1 || true)"
  log "fstab /media/HOME options → ${opts}"
  log "fstab riga: ${line}"
}

fix_home_exfat_fstab

log "ok"
exit 0
