#!/bin/bash
# Branding GRUB sul sistema INSTALLATO (non tocca GRUB della live ISO).
# - gfxmode max 1600x900 (niente auto a risoluzione nativa più alta)
# - splash con logo Quelo (sempre)
# - timeout menu 2 secondi
# - voce default come live: "Quelo Audiomaker <ver> alpha"
set -euo pipefail

ROOT="${1:-/}"
log() { echo "quelo-target-grub-branding: $*"; }

run() {
  if [[ "${ROOT}" == "/" ]]; then
    "$@"
  else
    chroot "${ROOT}" "$@"
  fi
}

SPLASH_DST="${ROOT}/boot/grub/quelo-splash.png"
DEFAULT_GRUB="${ROOT}/etc/default/grub"
VERSION_FILE="${ROOT}/etc/quelo-audiomaker-version"
GRUB_W=1600
GRUB_H=900
PREBUILT_NAME="grub-splash-1600x900.png"

mkdir -p "${ROOT}/boot/grub"

quelo_version() {
  local v="0.01"
  if [[ -f "${VERSION_FILE}" ]]; then
    v="$(tr -d '[:space:]' <"${VERSION_FILE}")"
  fi
  [[ -n "${v}" ]] || v="0.01"
  echo "${v}"
}

# Stesso titolo della live (hooks/0500-quelo-boot.binary).
quelo_menu_title() {
  echo "Quelo Audiomaker $(quelo_version) alpha"
}

quelo_find_logo() {
  local c
  for c in \
    "${ROOT}/usr/share/quelo-audiomaker/logo.png" \
    "${ROOT}/etc/calamares/branding/quelo/logo.png" \
    "/usr/share/quelo-audiomaker/logo.png" \
    "/etc/calamares/branding/quelo/logo.png"
  do
    if [[ -f "${c}" ]]; then
      echo "${c}"
      return 0
    fi
  done
  return 1
}

quelo_find_prebuilt_splash() {
  local c
  for c in \
    "${ROOT}/usr/share/quelo-audiomaker/${PREBUILT_NAME}" \
    "/usr/share/quelo-audiomaker/${PREBUILT_NAME}"
  do
    if [[ -f "${c}" ]]; then
      echo "${c}"
      return 0
    fi
  done
  return 1
}

quelo_make_splash() {
  local prebuilt logo

  if prebuilt="$(quelo_find_prebuilt_splash)"; then
    cp -f "${prebuilt}" "${SPLASH_DST}"
    log "splash copiato da prebuilt ${prebuilt} → ${SPLASH_DST}"
    return 0
  fi

  if ! logo="$(quelo_find_logo)"; then
    log "ERRORE: manca logo Quelo (nessun path trovato)"
    return 1
  fi
  log "logo trovato: ${logo}"

  if python3 - "${logo}" "${SPLASH_DST}" "${GRUB_W}" "${GRUB_H}" <<'PY'
import sys
from PIL import Image

logo_path, splash_path, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
bg = Image.new("RGB", (w, h), (46, 52, 54))
logo = Image.open(logo_path).convert("RGBA")
logo.thumbnail((280, 280), Image.LANCZOS)
x = (w - logo.width) // 2
y = 100
bg.paste(logo, (x, y), logo)
bg.save(splash_path, format="PNG")
print("ok")
PY
  then
    log "splash generato (PIL) ${GRUB_W}x${GRUB_H} → ${SPLASH_DST}"
    return 0
  fi

  if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
    local conv=convert
    command -v magick >/dev/null 2>&1 && conv="magick"
    ${conv} -size "${GRUB_W}x${GRUB_H}" xc:'#2e3436' \
      \( "${logo}" -resize 280x280 -background none \) \
      -gravity north -geometry +0+100 -compose Over -composite \
      -type TrueColor -depth 8 PNG24:"${SPLASH_DST}"
    log "splash generato (convert) ${GRUB_W}x${GRUB_H}"
    return 0
  fi

  log "ERRORE: impossibile generare splash (né prebuilt, né PIL, né convert)"
  return 1
}

quelo_set_grub_kv() {
  local key="$1" val="$2" file="$3"
  if grep -qE "^#?${key}=" "${file}" 2>/dev/null; then
    sed -i -E "s|^#?${key}=.*|${key}=${val}|" "${file}"
  else
    printf '%s=%s\n' "${key}" "${val}" >>"${file}"
  fi
}

quelo_patch_default_grub() {
  local title
  title="$(quelo_menu_title)"

  [[ -f "${DEFAULT_GRUB}" ]] || {
    cat >"${DEFAULT_GRUB}" <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR="${title}"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
EOF
  }

  # Titolo menu: stringa fissa (NO backtick / os-release — altrimenti compare il comando grezzo).
  quelo_set_grub_kv GRUB_DISTRIBUTOR "\"${title}\"" "${DEFAULT_GRUB}"
  quelo_set_grub_kv GRUB_TIMEOUT 2 "${DEFAULT_GRUB}"
  quelo_set_grub_kv GRUB_TIMEOUT_STYLE menu "${DEFAULT_GRUB}"
  quelo_set_grub_kv GRUB_RECORDFAIL_TIMEOUT 2 "${DEFAULT_GRUB}"
  quelo_set_grub_kv GRUB_GFXMODE '"1600x900,1440x900,1366x768,1280x720,1024x768,800x600"' \
    "${DEFAULT_GRUB}"
  quelo_set_grub_kv GRUB_GFXPAYLOAD_LINUX keep "${DEFAULT_GRUB}"

  if [[ -f "${SPLASH_DST}" ]]; then
    quelo_set_grub_kv GRUB_BACKGROUND /boot/grub/quelo-splash.png "${DEFAULT_GRUB}"
  else
    log "ATTENZIONE: splash assente, GRUB_BACKGROUND non impostato"
  fi

  # Tema desktop-base / altri: spegni, altrimenti mangiano lo sfondo Quelo.
  if grep -qE '^GRUB_THEME=' "${DEFAULT_GRUB}" 2>/dev/null; then
    sed -i -E 's|^GRUB_THEME=|#GRUB_THEME=|' "${DEFAULT_GRUB}"
  fi
  log "patchato ${DEFAULT_GRUB} (distributor=${title})"
}

# chroot + "command -v" non funziona (builtin). Prova i path reali.
quelo_regen_grub_cfg() {
  if [[ ! -d "${ROOT}/boot/grub" ]] && [[ ! -d "${ROOT}/boot/efi" ]]; then
    log "ATTENZIONE: /boot/grub assente sul target"
    return 1
  fi

  if run /usr/sbin/update-grub; then
    log "update-grub ok"
    return 0
  fi
  if run update-grub; then
    log "update-grub ok (PATH)"
    return 0
  fi
  if run /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg; then
    log "grub-mkconfig ok"
    return 0
  fi
  if run grub-mkconfig -o /boot/grub/grub.cfg; then
    log "grub-mkconfig ok (PATH)"
    return 0
  fi
  log "ATTENZIONE: update-grub/grub-mkconfig falliti"
  return 1
}

quelo_fix_menu_titles() {
  local cfg="$1"
  local title ver
  title="$(quelo_menu_title)"
  ver="$(quelo_version)"

  # Replace letterale (niente sed -E: i backtick di Calamares non matchano in modo affidabile).
  if python3 - "$cfg" "$title" "$ver" <<'PY'
import sys
from pathlib import Path

cfg_path, title, ver = sys.argv[1], sys.argv[2], sys.argv[3]
text = Path(cfg_path).read_text(encoding="utf-8", errors="replace")
garbage = "`( . /etc/os-release && echo ${NAME} )` GNU/Linux"
text = text.replace(garbage, title)
# 10_linux aggiunge " GNU/Linux" al distributor: allinea alla live.
text = text.replace(
    f"Quelo Audiomaker {ver} alpha GNU/Linux",
    f"Quelo Audiomaker {ver} alpha",
)
Path(cfg_path).write_text(text, encoding="utf-8")
print("ok")
PY
  then
    log "titoli menu → ${title} (python)"
  else
    # Fallback grezzo se python manca sul target.
    sed -i "s/\`( \. \/etc\/os-release && echo \${NAME} )\` GNU\/Linux/${title}/g" "${cfg}" || true
    sed -i "s/Quelo Audiomaker ${ver} alpha GNU\/Linux/Quelo Audiomaker ${ver} alpha/g" "${cfg}" || true
    log "titoli menu → ${title} (sed fallback)"
  fi
}

quelo_ensure_splash_in_cfg() {
  local cfg="$1"
  local rel="/boot/grub/quelo-splash.png"

  [[ -f "${SPLASH_DST}" ]] || {
    log "ATTENZIONE: splash file mancante, niente background in grub.cfg"
    return 1
  }

  # Se 05_debian_theme ha già un background_image funzionante verso quelo-splash, ok.
  if grep -qE 'background_image[[:space:]]+".*quelo-splash\.png"' "${cfg}" \
    || grep -qE "background_image[[:space:]]+'.*quelo-splash\.png'" "${cfg}" \
    || grep -qE 'background_image[[:space:]]+.*quelo-splash\.png' "${cfg}"; then
    # Ma non prima di load_video: se l'unica occorrenza è nel blocco rotto pre-gfxterm, ripara.
    if grep -qE 'background_image.*quelo-splash' "${cfg}"; then
      # Rimuovi SOLO il blocco iniettato male (commento Quelo + 2 righe), non tutta la theme.
      sed -i '/# Quelo GRUB splash/,+2d' "${cfg}" || true
    fi
  fi

  # Se dopo update-grub c'è già background verso quelo-splash in 05_debian_theme, fine.
  if awk '
    /### BEGIN \/etc\/grub.d\/05_debian_theme ###/ {in05=1}
    /### END \/etc\/grub.d\/05_debian_theme ###/ {in05=0}
    in05 && /background_image/ && /quelo-splash/ {found=1}
    END {exit found?0:1}
  ' "${cfg}"; then
    log "splash già in 05_debian_theme"
    return 0
  fi

  # Altrimenti inietta DOPO gfxterm (altrimenti GRUB ignora l'immagine).
  sed -i '/# Quelo GRUB splash/,+2d' "${cfg}" || true
  if grep -qE '^[[:space:]]*terminal_output[[:space:]]+gfxterm' "${cfg}"; then
    sed -i \
      '/^[[:space:]]*terminal_output[[:space:]]\+gfxterm/a\
# Quelo GRUB splash\
insmod png\
background_image '"${rel}"'
' "${cfg}"
    log "forzato splash dopo gfxterm → ${rel}"
  else
    sed -i '1i\
# Quelo GRUB splash\
insmod png\
background_image '"${rel}"'
' "${cfg}"
    log "forzato splash in cima a ${cfg}"
  fi
}

quelo_force_grub_cfg() {
  local cfg="${ROOT}/boot/grub/grub.cfg"
  [[ -f "${cfg}" ]] || {
    log "ATTENZIONE: manca ${cfg}"
    return 1
  }

  if grep -qE '^[[:space:]]*set timeout=' "${cfg}"; then
    sed -i -E 's/^([[:space:]]*set timeout=).*/\12/' "${cfg}"
  else
    sed -i '1iset timeout=2' "${cfg}"
  fi
  if grep -qE '^[[:space:]]*set timeout_style=' "${cfg}"; then
    sed -i -E 's/^([[:space:]]*set timeout_style=).*/\1menu/' "${cfg}"
  else
    sed -i '1iset timeout_style=menu' "${cfg}"
  fi
  if grep -qE '^[[:space:]]*set gfxmode=' "${cfg}"; then
    sed -i -E \
      's|^([[:space:]]*set gfxmode=).*|\11600x900,1440x900,1366x768,1280x720,1024x768,800x600|' \
      "${cfg}"
  else
    sed -i '1iset gfxmode=1600x900,1440x900,1366x768,1280x720,1024x768,800x600' "${cfg}"
  fi
  sed -i -E 's/(set gfxmode=[^[:space:]]*),auto/\1/g' "${cfg}"

  quelo_fix_menu_titles "${cfg}"
  quelo_ensure_splash_in_cfg "${cfg}" || true

  log "forzato timeout=2 e gfxmode≤1600x900 in ${cfg}"
}

if ! quelo_make_splash; then
  log "ERRORE: splash logo non creato"
fi
quelo_patch_default_grub
quelo_regen_grub_cfg || true
quelo_force_grub_cfg || true

if [[ -f "${SPLASH_DST}" ]]; then
  log "splash presente: $(ls -lh "${SPLASH_DST}" | awk '{print $5}')"
else
  log "ERRORE FINALE: ${SPLASH_DST} assente"
fi

log "ok"
exit 0
