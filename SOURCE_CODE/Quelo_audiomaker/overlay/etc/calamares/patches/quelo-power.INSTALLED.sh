#!/bin/sh
# Versione INSTALLATA: spegni/riavvia SENZA salva_sessione (solo live).
kdialog --title "Quelo Audiomaker" \
  --yes-label "Riavvia" --no-label "Spegni" --cancel-label "Annulla" \
  --warningyesnocancel "Cosa vuoi fare?"

case $? in
  0)
    systemctl reboot
    ;;
  1)
    systemctl poweroff
    ;;
  *)
    exit 0
    ;;
esac
