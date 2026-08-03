#!/bin/bash
# Funzioni condivise GUI salva/load sessione (zenity).
[[ -n "${QUELO_SESSION_GUI_LIB_LOADED:-}" ]] && return 0
QUELO_SESSION_GUI_LIB_LOADED=1

quelo_session_step_label() {
  case "$1" in
    network)   printf '%s' "Rete Wi-Fi / Ethernet" ;;
    cups)      printf '%s' "Stampanti" ;;
    bluetooth) printf '%s' "Bluetooth" ;;
    config)    printf '%s' "Desktop" ;;
    audio)     printf '%s' "Audio" ;;
    display)   printf '%s' "Schermo e risoluzione" ;;
    firefox)   printf '%s' "Firefox" ;;
    audacity)  printf '%s' "Configurazione Audacity" ;;
    audacious) printf '%s' "Configurazione Audacious" ;;
    mixxx)     printf '%s' "Configurazione Mixxx" ;;
    ardour)    printf '%s' "Configurazione Ardour" ;;
    reaper)    printf '%s' "Configurazione REAPER" ;;
    butt)      printf '%s' "Configurazione BUTT (streaming)" ;;
    ffado)     printf '%s' "Configurazione FireWire (FFADO)" ;;
    powermanagement) printf '%s' "Gestione energia (batteria)" ;;
    *)         printf '%s' "$1" ;;
  esac
}

quelo_session_step_store_path() {
  local id="$1"
  case "$id" in
    network)   printf '%s' "${STORE}/etc/NetworkManager" ;;
    cups)      printf '%s' "${STORE}/etc/cups" ;;
    bluetooth) printf '%s' "${STORE}/bluetooth" ;;
    config)    printf '%s' "${STORE}/config" ;;
    audio)     printf '%s' "${STORE}/audio" ;;
    display)   printf '%s' "${STORE}/display" ;;
    firefox)   printf '%s' "${STORE}/firefox/mozilla-backup.tar.gz" ;;
    audacity)  printf '%s' "${STORE}/audacity/audacity-config.tar.gz" ;;
    audacious) printf '%s' "${STORE}/audacious/audacious-config.tar.gz" ;;
    mixxx)     printf '%s' "${STORE}/mixxx/mixxx-config.tar.gz" ;;
    ardour)    printf '%s' "${STORE}/ardour/ardour-config.tar.gz" ;;
    reaper)    printf '%s' "${STORE}/reaper/reaper-config.tar.gz" ;;
    butt)      printf '%s' "${STORE}/butt/butt-config.tar.gz" ;;
    ffado)     printf '%s' "${STORE}/ffado/ffado-config.tar.gz" ;;
    powermanagement) printf '%s' "${STORE}/powermanagement/powermanagement-config.tar.gz" ;;
    *)         printf '%s' "${STORE}/${id}" ;;
  esac
}

quelo_session_gui_mark() {
  case "$1" in
    ok)   printf '%s' "OK" ;;
    err)  printf '%s' "ERR" ;;
    skip) printf '%s' "-" ;;
    *)    printf '%s' "?" ;;
  esac
}

quelo_session_gui_power_label() {
  case "${1:-}" in
    reboot)   printf '%s' "Ok, riavvia" ;;
    poweroff) printf '%s' "Ok, spegni" ;;
    *)        printf '%s' "Fatto!" ;;
  esac
}

# zenity --checklist restituisce gli ID separati da "|" su UNA riga.
quelo_session_gui_parse_selected() {
  local selected="$1"
  local -n _out=$2
  local normalized item
  _out=()
  normalized="${selected//$'\n'/|}"
  IFS='|' read -ra _out <<< "${normalized}"
  local -a cleaned=()
  for item in "${_out[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -n "${item}" ]] && cleaned+=("${item}")
  done
  _out=("${cleaned[@]}")
}

quelo_session_gui_wait_persist() {
  local waited=0
  while [[ "${waited}" -lt 45 ]]; do
    if mountpoint -q "${PERSIST_MNT}" 2>/dev/null; then
      return 0
    fi
    if blkid -L "${PERSIST_LABEL}" >/dev/null 2>&1; then
      mkdir -p "${PERSIST_MNT}"
      mount -L "${PERSIST_LABEL}" "${PERSIST_MNT}" 2>/dev/null && return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

# Riempie QUELO_GUI_ROWS: ogni elemento = "mark<TAB>label<TAB>path"
quelo_session_gui_run_steps() {
  local script="$1" mode="$2" report="/tmp/quelo-session-gui-$$.report"
  shift 2
  local -a ids=("$@") n=${#ids[@]} i=0 id label pct rc mark path
  QUELO_GUI_ROWS=()
  : >"${report}"

  if [[ "${n}" -eq 0 ]]; then
    return 0
  fi

  (
    while [[ "${i}" -lt "${n}" ]]; do
      id="${ids[$i]}"
      label="$(quelo_session_step_label "${id}")"
      path="$(quelo_session_step_store_path "${id}")"
      pct=$(( (i * 90) / n ))
      if [[ "${mode}" == save ]]; then
        echo "# Salvataggio: ${label}..."
      else
        echo "# Ripristino: ${label}..."
      fi
      echo "${pct}"
      mark="err"
      if "${script}" --gui --only "${id}" --no-finalize; then
        mark="ok"
      else
        rc=$?
        [[ "${rc}" -eq 2 ]] && mark="skip"
      fi
      printf '%s\t%s\t%s\t%s\n' "${mark}" "${id}" "${label}" "${path}" >>"${report}"
      i=$((i + 1))
    done
    if [[ "${mode}" == save ]]; then
      echo "# Finalizzazione..."
    else
      echo "# Completamento..."
    fi
    echo "95"
    "${script}" --gui --finalize-only || true
    echo "100"
  ) | zenity --progress \
      --title="$([[ "${mode}" == save ]] && echo "Salvataggio in corso..." || echo "Ripristino in corso...")" \
      --auto-close --no-cancel --width=420 2>/dev/null || true

  while IFS=$'\t' read -r mark id label path; do
    [[ -n "${mark}" && -n "${id}" ]] || continue
    QUELO_GUI_ROWS+=("${mark}|${label}|${path}")
  done <"${report}"
  rm -f "${report}"
}

quelo_session_gui_format_results_text() {
  local row mark label path out=""
  for row in "${QUELO_GUI_ROWS[@]}"; do
    IFS='|' read -r mark label path <<< "${row}"
    out+="$(quelo_session_gui_mark "${mark}")  ${label}
  ${path}

"
  done
  printf '%s' "${out}"
}

quelo_session_gui_show_results() {
  local title="$1" ok_label="${2:-Fatto!}" cancel_label="${3:-}"
  local row mark label path
  local -a args=() zenity_args=()

  for row in "${QUELO_GUI_ROWS[@]}"; do
    IFS='|' read -r mark label path <<< "${row}"
    args+=("$(quelo_session_gui_mark "${mark}")")
    args+=("${label}")
    args+=("${path}")
  done

  if [[ ${#args[@]} -eq 0 ]]; then
    if [[ -n "${cancel_label}" ]]; then
      zenity --question --title="${title}" \
        --text="Nessuna voce elaborata." \
        --ok-label="${ok_label}" --cancel-label="${cancel_label}" \
        --width=360 2>/dev/null
      return $?
    fi
    zenity --info --title="${title}" --text="Nessuna voce elaborata." \
      --ok-label="${ok_label}" --width=320 2>/dev/null
    return $?
  fi

  # Sempre --list (altezza fissa + scroll): con tante voci un --question
  # esce dallo schermo e nasconde i pulsanti (es. salvataggio pre-spegnimento).
  # OK = continua (spegni/riavvia); Annulla = torna al desktop.
  zenity_args=(
    --list
    --title="${title}"
    --text="Riepilogo:"
    --column=" " --column="Voce" --column="Percorso"
    --ok-label="${ok_label}"
    --height=440 --width=720
  )
  if [[ -n "${cancel_label}" ]]; then
    zenity_args+=(--cancel-label="${cancel_label}")
  fi
  zenity "${zenity_args[@]}" "${args[@]}" 2>/dev/null
  return $?
}

quelo_session_gui_confirm_power_no_save() {
  local action="$1"
  zenity --question \
    --title="Salva sessione" \
    --text="Nessun salvataggio effettuato.\nProcedere comunque?" \
    --ok-label="$(quelo_session_gui_power_label "${action}")" \
    --cancel-label="Torna indietro" \
    --width=400 2>/dev/null
}

quelo_session_gui_standard_checklist() {
  QUELO_GUI_CHECKLIST=(
    TRUE  network   "Rete Wi-Fi / Ethernet"
    TRUE  cups      "Stampanti"
    TRUE  bluetooth "Bluetooth"
    TRUE  config    "Desktop"
    TRUE  audio     "Audio"
    TRUE  display   "Schermo e risoluzione"
    TRUE  firefox   "Firefox"
    TRUE  audacity  "Configurazione Audacity"
    TRUE  audacious "Configurazione Audacious"
    TRUE  mixxx     "Configurazione Mixxx"
    TRUE  ardour    "Configurazione Ardour"
    TRUE  reaper    "Configurazione REAPER"
    TRUE  butt      "Configurazione BUTT (streaming)"
    TRUE  ffado     "Configurazione FireWire (FFADO)"
    TRUE  powermanagement "Gestione energia (batteria)"
  )
}
