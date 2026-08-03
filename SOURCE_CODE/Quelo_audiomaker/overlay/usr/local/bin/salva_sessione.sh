#!/bin/bash
# Salva lo stato sessione su partizione "persistence".
#
# Uso:
#   salva_sessione                         # terminale, tutte le voci + admin
#   salva_sessione --gui --only network,display
set -o pipefail

QUELO_SESSION_VERSION="v17"
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SESSION_NAME="salva_sessione"
TOTAL_STEPS=12
STEP=0
SAVE_GUI=0
SAVE_KEEP_MOUNT=0
SAVE_NO_FINALIZE=0
SAVE_FINALIZE_ONLY=0
declare -a SAVE_STEPS=()

declare -a SUMMARY_OK=()
declare -a SUMMARY_SKIP=()
declare -a SUMMARY_ERR=()

. "${_SCRIPT_DIR}/quelo-session-common.sh"

usage() {
  cat <<'EOF'
Uso: salva_sessione [opzioni]

  --gui              modalita' GUI (log su file, persistence resta montata)
  --only ID[,ID...]  salva solo le voci indicate (senza prompt)
  --no-finalize      salva senza timestamp/sync (uso GUI, step singolo)
  --finalize-only    solo finalizzazione (timestamp + sync)
  --help             questo messaggio

ID: network cups bluetooth config audio display firefox audacity audacious mixxx ardour reaper butt ffado powermanagement
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gui)
        SAVE_GUI=1
        SAVE_KEEP_MOUNT=1
        shift
        ;;
      --only)
        IFS=',' read -ra SAVE_STEPS <<< "${2:-}"
        shift 2
        ;;
      --no-finalize)
        SAVE_NO_FINALIZE=1
        shift
        ;;
      --finalize-only)
        SAVE_FINALIZE_ONLY=1
        SAVE_GUI=1
        SAVE_KEEP_MOUNT=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Opzione sconosciuta: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

step_enabled() {
  local id="$1" s
  for s in "${SAVE_STEPS[@]}"; do
    [[ "${s}" == "${id}" ]] && return 0
  done
  return 1
}

verbose() {
  session_log "$*"
}

step_begin() {
  STEP=$((STEP + 1))
  if [[ "${SAVE_GUI}" -eq 0 ]]; then
    echo ""
    echo "============================================================"
    printf " PASSO %s/%s — %s\n" "${STEP}" "${TOTAL_STEPS}" "$1"
    echo "============================================================"
  fi
  session_debug "=== PASSO ${STEP}/${TOTAL_STEPS}: $1 ==="
}

step_ok() {
  verbose "  [OK] $*"
  SUMMARY_OK+=("$*")
}

step_skip() {
  verbose "  [SALTO] $*"
  SUMMARY_SKIP+=("$*")
}

step_err() {
  verbose "  [ERRORE] $*"
  SUMMARY_ERR+=("$*")
}

dir_stats() {
  local path="$1" n size
  if [[ ! -e "${path}" ]]; then
    echo "0 file, 0"
    return 0
  fi
  n="$(find "${path}" -type f 2>/dev/null | wc -l | tr -d ' ')"
  size="$(du -sh "${path}" 2>/dev/null | cut -f1)"
  echo "${n} file, ${size:-?}"
}

mirror_dir() {
  local label="$1" src="$2" dst="$3"
  verbose "  Copio: ${src} -> ${dst}"
  if session_mirror_dir "${label}" "${src}" "${dst}"; then
    step_ok "${label} ($(dir_stats "${dst}"))"
    return 0
  fi
  step_skip "${label} (sorgente assente o errore copia)"
  return 1
}

save_xrandr() {
  step_begin "Schermo (xrandr / lxrandr)"
  session_debug "schermo: INIZIO save_xrandr ${QUELO_SESSION_VERSION}"
  local dst saved=0 n_cmds restore_script
  dst="${STORE}/display"
  restore_script="${dst}/xrandr-restore.sh"
  mkdir -p "${dst}"

  if ! command -v xrandr >/dev/null 2>&1; then
    step_skip "schermo (xrandr non installato)"
    return 0
  fi

  if [[ "${SAVE_GUI}" -eq 0 ]]; then
    echo "  Cattura layout schermo (${QUELO_SESSION_VERSION})..."
  fi
  session_ensure_x11
  session_debug "schermo: DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY}"
  session_debug "schermo: avvio xrandr --current --nograb (timeout -k 3 8)"
  if ! session_xrandr_to_file "${dst}/xrandr-query.txt" "${dst}/xrandr.err.txt"; then
    step_err "schermo (xrandr non risponde su ${DISPLAY})"
    if [[ -f "${dst}/xrandr.err.txt" ]]; then
      session_debug "schermo: stderr=$(tr '\n' ' ' <"${dst}/xrandr.err.txt")"
    fi
    [[ "${SAVE_GUI}" -eq 0 ]] && echo "  xrandr non risponde: layout NON salvato (continuo col resto)."
    return 0
  fi
  session_debug_path "xrandr-dump" "${dst}/xrandr-query.txt" 1

  session_debug "schermo: restore_script=${restore_script}"
  if session_debug_cmd "display-capture" \
       "${_SCRIPT_DIR}/quelo-display-capture.sh" "${restore_script}" "${dst}/xrandr-query.txt"; then
    n_cmds="$(grep -c '^xrandr ' "${restore_script}" 2>/dev/null || true)"
    n_cmds="${n_cmds:-0}"
    session_debug_path "xrandr-script" "${restore_script}" 2
    if [[ "${n_cmds}" -gt 0 ]]; then
      step_ok "xrandr-restore.sh (${n_cmds} comandi xrandr)"
      saved=1
    else
      step_err "xrandr-restore.sh senza comandi utili"
    fi
  else
    step_err "cattura schermo fallita"
  fi

  if [[ -d /root/.config/lxrandr ]]; then
    mirror_dir "lxrandr" /root/.config/lxrandr "${dst}/lxrandr" && saved=1
  else
    step_skip "lxrandr"
  fi

  if [[ -f /root/.config/autostart/lxrandr-autostart.desktop ]]; then
    session_copy_file "lxrandr-autostart" \
      /root/.config/autostart/lxrandr-autostart.desktop \
      "${dst}/autostart/lxrandr-autostart.desktop" && step_ok "lxrandr-autostart.desktop" && saved=1
  fi
  [[ "${saved}" -eq 0 ]] && step_skip "schermo (nessun dato)"
}

save_firefox() {
  step_begin "Firefox (~/.mozilla completo)"
  local dst="${STORE}/firefox"
  local archive="${dst}/mozilla-backup.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -d /root/.mozilla ]]; then
    step_skip "firefox (~/.mozilla assente — avvia Firefox almeno una volta)"
    session_debug_cmd "firefox-ls" ls -la /root/.mozilla 2>/dev/null || true
    return 2
  fi

  if session_backup_mozilla_home "${archive}"; then
    step_ok "mozilla-backup.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "firefox (tar ~/.mozilla fallito)"
  return 1
}

save_audacity() {
  step_begin "Configurazione Audacity"
  local dst="${STORE}/audacity"
  local archive="${dst}/audacity-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -d /root/.config/audacity && ! -d /root/.local/share/audacity && ! -d /root/.audacity-data ]]; then
    step_skip "audacity (config assente — avvia Audacity almeno una volta)"
    session_debug_cmd "audacity-ls" ls -la /root/.config /root/.local/share /root/.audacity-data 2>/dev/null || true
    return 2
  fi

  if session_backup_audacity_config "${archive}"; then
    step_ok "audacity-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "audacity (tar config fallito)"
  return 1
}

save_audacious() {
  step_begin "Configurazione Audacious (~/.config/audacious)"
  local dst="${STORE}/audacious"
  local archive="${dst}/audacious-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -d /root/.config/audacious ]]; then
    step_skip "audacious (cartella assente — avvia Audacious almeno una volta)"
    session_debug_cmd "audacious-ls" ls -la /root/.config 2>/dev/null || true
    return 2
  fi

  if session_backup_audacious_config "${archive}"; then
    step_ok "audacious-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "audacious (tar config fallito)"
  return 1
}

save_mixxx() {
  step_begin "Configurazione Mixxx (~/.mixxx)"
  local dst="${STORE}/mixxx"
  local archive="${dst}/mixxx-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -d /root/.mixxx ]]; then
    step_skip "mixxx (cartella assente — avvia Mixxx almeno una volta)"
    session_debug_cmd "mixxx-ls" ls -la /root 2>/dev/null || true
    return 2
  fi

  if session_backup_mixxx_config "${archive}"; then
    step_ok "mixxx-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "mixxx (tar config fallito)"
  return 1
}

save_ardour() {
  step_begin "Configurazione Ardour (~/.config/ardour*)"
  local dst="${STORE}/ardour"
  local archive="${dst}/ardour-config.tar.gz"
  mkdir -p "${dst}"

  if [[ -z "$(session_ardour_paths | head -1)" ]]; then
    step_skip "ardour (config assente — avvia Ardour almeno una volta)"
    session_debug_cmd "ardour-ls" ls -la /root/.config /root/.local/share 2>/dev/null || true
    return 2
  fi

  if session_backup_ardour_config "${archive}"; then
    step_ok "ardour-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "ardour (tar config fallito)"
  return 1
}

save_reaper() {
  step_begin "Configurazione REAPER (~/.config/REAPER)"
  local dst="${STORE}/reaper"
  local archive="${dst}/reaper-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -d /root/.config/REAPER ]]; then
    step_skip "reaper (cartella assente — avvia REAPER almeno una volta)"
    session_debug_cmd "reaper-ls" ls -la /root/.config 2>/dev/null || true
    return 2
  fi

  if session_backup_reaper_config "${archive}"; then
    step_ok "reaper-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "reaper (tar config fallito)"
  return 1
}

save_butt() {
  step_begin "Configurazione BUTT (~/.buttrc)"
  local dst="${STORE}/butt"
  local archive="${dst}/butt-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -f /root/.buttrc ]]; then
    step_skip "butt (file assente — avvia STREAMING LIVE / BUTT almeno una volta)"
    session_debug_cmd "butt-ls" ls -la /root/.buttrc /root 2>/dev/null || true
    return 2
  fi

  if session_backup_butt_config "${archive}"; then
    step_ok "butt-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "butt (tar config fallito)"
  return 1
}

save_ffado() {
  step_begin "Configurazione FireWire FFADO (~/.ffado)"
  local dst="${STORE}/ffado"
  local archive="${dst}/ffado-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -d /root/.ffado ]]; then
    step_skip "ffado (cartella assente — usa Mixer FireWire almeno una volta)"
    session_debug_cmd "ffado-ls" ls -la /root 2>/dev/null || true
    return 2
  fi

  if session_backup_ffado_config "${archive}"; then
    step_ok "ffado-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "ffado (tar config fallito)"
  return 1
}

save_powermanagement() {
  step_begin "Gestione energia (~/.config/lxqt/lxqt-powermanagement.conf)"
  local dst="${STORE}/powermanagement"
  local archive="${dst}/powermanagement-config.tar.gz"
  mkdir -p "${dst}"

  if [[ ! -f /root/.config/lxqt/lxqt-powermanagement.conf ]]; then
    step_skip "powermanagement (file assente)"
    session_debug_cmd "powermanagement-ls" ls -la /root/.config/lxqt 2>/dev/null || true
    return 2
  fi

  if session_backup_powermanagement_config "${archive}"; then
    step_ok "powermanagement-config.tar.gz ($(du -h "${archive}" | cut -f1))"
    return 0
  fi

  step_err "powermanagement (tar config fallito)"
  return 1
}

save_audio() {
  step_begin "Audio (PulseAudio + ALSA)"
  local dst="${STORE}/audio" saved=0
  mkdir -p "${dst}"

  if [[ -d /root/.config/pulse ]]; then
    mirror_dir "PulseAudio" /root/.config/pulse "${dst}/pulse" && saved=1
  else
    step_skip "PulseAudio (~/.config/pulse)"
  fi

  if command -v alsactl >/dev/null 2>&1; then
    if session_debug_cmd "alsactl-store" alsactl -f "${dst}/asound.state" store; then
      step_ok "ALSA asound.state"
      saved=1
    else
      step_err "alsactl store"
    fi
  else
    step_skip "alsactl"
  fi

  if command -v pactl >/dev/null 2>&1; then
    session_debug_cmd "pactl-info" pactl info || true
    if pactl info >/dev/null 2>&1; then
      session_debug_cmd "pactl-sinks" pactl list sinks
      session_debug_cmd "pactl-default-sink" pactl get-default-sink
      session_debug_cmd "pactl-volume" pactl get-sink-volume @DEFAULT_SINK@
      pactl list sinks >"${dst}/pactl-sinks.txt" 2>/dev/null || true
      pactl list sink-inputs >"${dst}/pactl-sink-inputs.txt" 2>/dev/null || true
      pactl get-default-sink >"${dst}/default-sink.txt" 2>/dev/null || true
      pactl get-sink-volume @DEFAULT_SINK@ >"${dst}/default-sink-volume.txt" 2>/dev/null || true
      step_ok "dump pactl (4 file)"
      saved=1
    else
      step_skip "pactl (PulseAudio non attivo)"
    fi
  fi
  [[ "${saved}" -eq 0 ]] && step_skip "audio (nulla salvato)"
}

save_config() {
  step_begin "Configurazioni (~/.config)"
  mirror_dir "config" /root/.config "${STORE}/config"
}

save_bluetooth() {
  step_begin "Bluetooth"
  mirror_dir "bluetooth" /var/lib/bluetooth "${STORE}/bluetooth"
}

save_network() {
  step_begin "Rete (NetworkManager)"
  mirror_dir "etc/NetworkManager/system-connections" \
    /etc/NetworkManager/system-connections \
    "${STORE}/etc/NetworkManager/system-connections" || true
  mirror_dir "etc/NetworkManager/conf.d" \
    /etc/NetworkManager/conf.d \
    "${STORE}/etc/NetworkManager/conf.d" || true
}

save_cups() {
  step_begin "Stampanti (CUPS)"
  mirror_dir "etc/cups" /etc/cups "${STORE}/etc/cups"
}

save_etc_admin() {
  step_begin "Sistema (/etc admin)"
  mirror_dir "etc/apt/sources.list.d" /etc/apt/sources.list.d "${STORE}/etc/apt/sources.list.d" || true
  if session_copy_file "hostname" /etc/hostname "${STORE}/etc/hostname"; then
    step_ok "hostname ($(cat /etc/hostname))"
  else
    step_skip "hostname"
  fi
  if session_copy_file "machine-id" /etc/machine-id "${STORE}/etc/machine-id"; then
    step_ok "machine-id"
  else
    step_skip "machine-id"
  fi
}

run_batch_step() {
  local id="$1" rc=0
  shift
  if step_enabled "${id}"; then
    "$@" || rc=$?
    return "${rc}"
  fi
  session_debug "SKIP batch: ${id} (non selezionato)"
  return 2
}

save_step_exit_code() {
  if ((${#SUMMARY_ERR[@]} > 0)); then
    return 1
  fi
  if ((${#SUMMARY_OK[@]} > 0)); then
    return 0
  fi
  return 2
}

save_finalize() {
  step_begin "Finalizzazione"
  session_debug_cmd "timestamp" date -Iseconds
  date -Iseconds >"${STORE}/.quelo-last-save"
  echo "manual" >"${STORE}/.quelo-save-mode"
  session_debug_cmd "sync" sync
  step_ok "sync disco"
  session_debug_store_tree
}

print_summary() {
  local i
  [[ "${SAVE_GUI}" -eq 1 ]] && return 0
  echo ""
  echo "============================================================"
  echo " RIEPILOGO SALVATAGGIO"
  echo "============================================================"
  ((${#SUMMARY_OK[@]})) && { echo "OK (${#SUMMARY_OK[@]}):"; for i in "${!SUMMARY_OK[@]}"; do printf "  [OK] %s\n" "${SUMMARY_OK[$i]}"; done; echo ""; }
  ((${#SUMMARY_SKIP[@]})) && { echo "SALTATI (${#SUMMARY_SKIP[@]}):"; for i in "${!SUMMARY_SKIP[@]}"; do printf "  [--] %s\n" "${SUMMARY_SKIP[$i]}"; done; echo ""; }
  ((${#SUMMARY_ERR[@]})) && { echo "ERRORI (${#SUMMARY_ERR[@]}):"; for i in "${!SUMMARY_ERR[@]}"; do printf "  [!!] %s\n" "${SUMMARY_ERR[$i]}"; done; echo ""; }
  [[ -d "${STORE}" ]] && echo "Store: $(du -sh "${STORE}" | cut -f1) — ${STORE}"
  echo ""
  ((${#SUMMARY_ERR[@]})) && echo "ATTENZIONE: ERRORI RILEVATI." || echo "SALVATAGGIO COMPLETATO."
  echo "Log:      ${LOGFILE}"
  echo "Debug:    ${DEBUGLOG}"
  echo "============================================================"
}

session_umount_on_exit() {
  sync 2>/dev/null || true
  session_debug "sync completato (trap EXIT)"
  session_debug_store_tree || true
  session_debug "========== FINE DEBUG SISTEMA =========="
  if [[ "${SAVE_KEEP_MOUNT}" -eq 1 ]]; then
    session_debug "SAVE_KEEP_MOUNT=1: persistence resta montata"
    return 0
  fi
  if mountpoint -q "${PERSIST_MNT}" 2>/dev/null; then
    session_debug_cmd "umount" umount "${PERSIST_MNT}" || session_debug_cmd "umount-lazy" umount -l "${PERSIST_MNT}" || true
  fi
}

# --- main ---

parse_args "$@"

if [[ "${SAVE_GUI}" -eq 0 ]]; then
  echo ""
  echo "Quelo Audiomaker — salva_sessione ${QUELO_SESSION_VERSION} (verbose + debug completo)"
  echo "========================================================"
fi

session_debug "VERSIONE SCRIPT: ${QUELO_SESSION_VERSION} dir=${_SCRIPT_DIR} gui=${SAVE_GUI}"
session_debug_header

if ! session_mount_persistence; then
  echo "ERRORE: impossibile montare '${PERSIST_LABEL}'." >&2
  session_debug "FATAL: mount fallito"
  exit 1
fi

trap session_umount_on_exit EXIT
trap 'echo ""; echo "INTERROTTO — salvataggio incompleto."; session_debug "INTERRUPT: salvataggio interrotto dall utente"' INT TERM

mkdir -p "${STORE}"/{config,bluetooth,firefox,audacity,audacious,mixxx,ardour,reaper,butt,ffado,powermanagement,display,audio,etc}
session_debug_store_tree

session_log "=== INIZIO salvataggio sessione (gui=${SAVE_GUI}) ==="

if [[ "${SAVE_FINALIZE_ONLY}" -eq 1 ]]; then
  save_finalize
  session_log "=== FINE salvataggio sessione (finalize-only) ==="
  exit 0
fi

if [[ ${#SAVE_STEPS[@]} -gt 0 ]]; then
  run_batch_step network save_network || true
  run_batch_step cups save_cups || true
  run_batch_step bluetooth save_bluetooth || true
  run_batch_step config save_config || true
  run_batch_step audio save_audio || true
  run_batch_step display save_xrandr || true
  run_batch_step firefox save_firefox || true
  run_batch_step audacity save_audacity || true
  run_batch_step audacious save_audacious || true
  run_batch_step mixxx save_mixxx || true
  run_batch_step ardour save_ardour || true
  run_batch_step reaper save_reaper || true
  run_batch_step butt save_butt || true
  run_batch_step ffado save_ffado || true
  run_batch_step powermanagement save_powermanagement || true
else
  save_xrandr || session_debug "WARN: save_xrandr terminato con errori, continuo"
  save_firefox || session_debug "WARN: save_firefox terminato con errori, continuo"
  save_audacity || session_debug "WARN: save_audacity terminato con errori, continuo"
  save_audacious || session_debug "WARN: save_audacious terminato con errori, continuo"
  save_mixxx || session_debug "WARN: save_mixxx terminato con errori, continuo"
  save_ardour || session_debug "WARN: save_ardour terminato con errori, continuo"
  save_reaper || session_debug "WARN: save_reaper terminato con errori, continuo"
  save_butt || session_debug "WARN: save_butt terminato con errori, continuo"
  save_ffado || session_debug "WARN: save_ffado terminato con errori, continuo"
  save_powermanagement || session_debug "WARN: save_powermanagement terminato con errori, continuo"
  save_audio || session_debug "WARN: save_audio terminato con errori, continuo"
  save_config || session_debug "WARN: save_config terminato con errori, continuo"
  save_bluetooth || session_debug "WARN: save_bluetooth terminato con errori, continuo"
  save_network || session_debug "WARN: save_network terminato con errori, continuo"
  save_cups || session_debug "WARN: save_cups terminato con errori, continuo"
  save_etc_admin || session_debug "WARN: save_etc_admin terminato con errori, continuo"
fi

if [[ "${SAVE_NO_FINALIZE}" -eq 1 ]]; then
  session_log "=== FINE step singolo (no-finalize) ==="
  save_step_exit_code
  exit $?
fi

save_finalize

session_log "=== FINE salvataggio sessione ==="
STORE_FILES="$(find "${STORE}" -type f 2>/dev/null | wc -l | tr -d ' ')"
session_debug "store file totali=${STORE_FILES:-0}"
if [[ "${STORE_FILES:-0}" -eq 0 ]]; then
  [[ "${SAVE_GUI}" -eq 0 ]] && echo "" && echo "ATTENZIONE: lo store e' VUOTO — nessun dato salvato su persistence."
  step_err "store vuoto (salvataggio non riuscito)"
fi
print_summary

((${#SUMMARY_ERR[@]})) && exit 1
exit 0
