#!/bin/sh
# XDG_RUNTIME_DIR: normalmente creata/esportata da pam_systemd o elogind
# al login. Qui l'autologin passa da getty+startx, senza un gestore di
# sessione PAM dedicato, quindi resterebbe sempre non impostata. Molte
# app moderne la richiedono per funzionare bene (PulseAudio incluso: e'
# una causa nota di comportamenti "rotti" senza errori espliciti, come
# l'icona del volume che resta sulla "x" rossa nel pannello).
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Audio in BACKGROUND: su Audiomaker lo stack ALSA/firmware/FFADO è pesante
# (alsactl init + pulseaudio --start sincroni bloccavano startlxqt → schermo
# nero senza mouse, USB ferma). Il desktop parte subito; volume al 60% arriva
# un attimo dopo (il pannello di solito lo vede già pronto).
(
  /usr/local/bin/quelo-audio-default.sh
  pulseaudio --start 2>/dev/null
  /usr/local/bin/quelo-audio-default.sh --pulse
) &

# Avvia la sessione LXQt (Openbox come window manager, vedi
# etc/xdg/lxqt/session.conf) esattamente come faceva SDDM con
# "Session=lxqt.desktop", ma lanciata direttamente da startx.
exec startlxqt
