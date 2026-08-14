#!/bin/bash
# Quelo Audiomaker — ricomposizione ISO 0.13-alpha
set -euo pipefail
cd "$(dirname "$0")"
OUT="Quelo-Audiomaker-0.13-alpha.iso"
PARTS=(
  Quelo-Audiomaker-0.13-alpha.iso.part00
  Quelo-Audiomaker-0.13-alpha.iso.part01
)
SUM="Quelo-Audiomaker-0.13-alpha.iso.sha256"
echo "Quelo Audiomaker — ricomposizione ISO 0.13-alpha"
echo "Cartella: $(pwd)"
echo
missing=0
for f in "${PARTS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERRORE: manca $f"
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo
  echo "Scarica le 2 parti nella stessa cartella di questo script, poi rilancia."
  exit 1
fi
echo "Unione in corso (può richiedere alcuni minuti)..."
cat "${PARTS[@]}" > "$OUT"
echo "OK: creato $OUT"
echo
if [[ -f "$SUM" ]]; then
  echo "Verifica checksum..."
  if sha256sum -c "$SUM"; then
    echo "Checksum OK."
  else
    echo "ATTENZIONE: checksum non corrispondente. Riscarica le parti."
    exit 1
  fi
else
  echo "Nota: file $SUM non trovato — verifica saltata (opzionale)."
fi
