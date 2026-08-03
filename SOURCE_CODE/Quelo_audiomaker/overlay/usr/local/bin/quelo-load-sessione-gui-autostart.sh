#!/bin/bash
# Avvio load GUI dopo i refresh trust del Desktop (in coda, non in parallelo).
# Solo LIVE (in LIVE l'autostart resta; sull'installata lo script post lo rimuove).
if [[ ! -d /run/live ]] && ! grep -Eq '(^|[[:space:]])boot=live([[:space:]]|$)' /proc/cmdline 2>/dev/null; then
  exit 0
fi
LOG="/tmp/quelo-load-gui-autostart.log"
exec 9>/tmp/quelo-load-sessione-gui.lock
flock -n 9 || exit 0
exec >>"${LOG}" 2>&1
echo "=== $(date -Iseconds) autostart load GUI pid=$$ ==="

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/root/.Xauthority}"

PERSIST_MNT="/media/quelo-persist"
TRUST_DONE="/tmp/quelo-trust-desktop-icons.done"

for _ in $(seq 1 120); do
  xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1 && break
  sleep 1
done

for _ in $(seq 1 120); do
  pgrep -x lxqt-panel >/dev/null 2>&1 && break
  sleep 1
done

for _ in $(seq 1 45); do
  mountpoint -q "${PERSIST_MNT}" 2>/dev/null && break
  sleep 1
done

# In coda ai cicli trust (+ sleep 1 già nello script trust prima del marker).
# Timeout 9 s: in live i cicli bastano 2–3 s; oltre è anomalia hardware.
echo "Attesa marker trust (${TRUST_DONE}), max 9s"
if [[ -f "${TRUST_DONE}" ]]; then
  echo "Marker trust già presente"
else
  waited=0
  while [[ "${waited}" -lt 9 ]]; do
    [[ -f "${TRUST_DONE}" ]] && break
    sleep 1
    waited=$((waited + 1))
  done
  if [[ -f "${TRUST_DONE}" ]]; then
    echo "Marker trust OK dopo ${waited}s"
  else
    echo "WARN: marker trust assente dopo 9s — avvio load GUI comunque"
  fi
fi

echo "Avvio load GUI DISPLAY=${DISPLAY}"
exec /usr/local/bin/quelo-load-sessione-gui.sh
