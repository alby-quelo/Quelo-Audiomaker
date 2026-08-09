# Changelog — Quelo Audiomaker

Changelog della distro **Quelo Audiomaker** (progetto distinto da Quelo Videomaker / Quelo Office).


## [0.12-alpha] — 2026-08-09

Rispetto a **0.08-alpha** (unica release pubblica precedente):

### Desktop / USB
- **Safe eject notify** + pacchetto **`eject`**; **CAMBIO ETICHETTA USB**;
  **POWER MANAGEMENT** in CONFIGURAZIONI.
- **Automount ON** + apre Gestione file (`quelo-automount-open`).
- **QUELO-HOME** (exFAT) **visibile** a udisks; nascosti `persistence` e volumi
  ISO `QUELO-AUDIOMAKER*` / `VIDEOMAKER*` / `OFFICE*` (niente montaggio squashfs
  al posto dell’exFAT).
- Mount QUELO-HOME: `fmask/dmask=0022`; MIME audio/playlist → **Audacious**.
- **SCHEDE AUDIO** (QasTools) in CONFIGURAZIONI.
- Avvio live più snello (icone/trust come Videomaker); audio in **background**
  in `.xinitrc` + timeout `alsactl` (meno schermo nero senza mouse).

### Installer Calamares
- Wizard allineati a Videomaker (finestre nello schermo, GRUB, riepilogo);
  partizionamento Quelo (`rootGiB: rest` se `/` unico).
- Pagina **Riepilogo**: moduli **Qt6 QML** espliciti (fix «Caricamento fallito»).


## [0.08-alpha] — 2026-08-03

- **Quelo-palinsesto-radio** (evoluzione rispetto a 0.03):
  - Slot **LINK** (stream http/https via `curlhttpsrc`, `ssl-strict=False`); anteprima volume + VU in AGGIUNGI/MODIFICA; failover se lo stream muore.
  - Slot **PLAYLIST** (`.m3u` / `.m3u8` / `.pls`, solo file locali; loop in onda fino a fine fascia).
  - **ANTI BIANCO**: playlist filler nei buchi di palinsesto; ripresa dalla posizione interrotta.
  - **Silence-gate**: se la sorgente in onda è sotto soglia (file/playlist/LINK/LIVE, anche cavo staccato) → ANTI BIANCO; ripresa automatica. Parametri per tipo in **SETTING**.
  - **SETTING** (barra): silence-gate + aspetto font clip; **Zoom** verticale timeline (− / px/ora / +), persistente in SQLite.
  - Timeline: etichetta **24:00** nel gutter ore; VU 0 dBFS a fondo scala.
  - Mixer ingressi: porte Pulse, Attiva, VU grezzo; LIVE con AGC verso 0 dB.
- Desktop live: icona **MANUALE PALINSESTO** (PDF + icona dedicata) anche su **QUELO-HOME** (stesso schema di install/Mixxx: applications + mount-home + autostart trust).
- Menu Openbox: voci tutte **MAIUSCOLO** e font menu in **grassetto**.
- Dipendenze stream: `gstreamer1.0-plugins-bad` (`curlhttpsrc`), `glib-networking`.


## [0.03-alpha] — 2026-08

- Limiti PAM audio: `/etc/security/limits.d/99-quelo-audio.conf` (`memlock` unlimited, `rtprio` 95, `nice` -19 per `@audio` e `root`) — elimina l’avviso Ardour sulla memoria bloccata.
- Ardour e REAPER: **ALSA** di default via `quelo-ardour` / `quelo-reaper` (`pasuspender` sospende Pulse per la sessione DAW; scheda in esclusiva). Pulse resta per desktop/Audacious/BT a DAW chiusa.
- Live: dialog ripristino sessione **dopo** i refresh trust del Desktop (marker + 1 s; timeout 9 s).
- **BUTT** (Broadcast Using This Tool): AppImage upstream da danielnoethen.de (non il .deb Debian); voce menu **STREAMING LIVE**; wrapper con fallback extract se FUSE non è usabile (utente installato Calamares).
- Sessione: salva/ripristina anche **config BUTT** (`~/.buttrc`; voce «Configurazione BUTT (streaming)»).
- **MediaInfo** (`mediainfo` + `mediainfo-gui`): voce menu **ANALISI FILE AUDIO - MEDIAINFO**.
- **Quelo Audio Converter** (`quelo-audio-converter`): GUI PyQt6 — input audio/video, export **solo audio** (FFmpeg); voce menu **CONVERTITORE AUDIO**.
- **Quelo-palinsesto-radio** (`quelo-palinsesto-radio`, menu **PALINSESTO RADIO**):
  - Calendario settimanale **lun–dom** (settimana corrente, frecce ±7 giorni; etichette giorno + data).
  - Timeline a colonne (24 h verticali): blocchi **altezza proporzionale alla durata**; testo titolo / file|LIVE / «dalle…alle…»; colore sfondo **scegliibile**.
  - File audio schedulati (anti-overlap, spill oltre mezzanotte); peak-normalize a 0 dB di picco all’import (FFmpeg); titolo/descrizione da **tag** o modifica manuale.
  - Slot **ingresso LIVE** (fascia oraria → riproduzione da ingresso Pulse scelto in elenco + Aggiorna).
  - Player **Start/Stop**, VU meter, volume; seek se si parte a metà pezzo (GStreamer / PyGObject).
  - Click su blocco → popup dettaglio (titolo, descrizione, file/percorso o ingresso, giorno, orari; **MODIFICA** / **ELIMINA** / **OK**).
  - Finestra **massimizzata** di default (pannelli LXQt visibili); ridimensionabile.
  - Tutto in SQLite `.palinsesto.db` (palinsesto + preferenze: volume, geometria, ingresso LIVE) — `/media/quelo-home/` se montato, altrimenti `$HOME`; **niente** voce in `salva_sessione`.


## [0.02-alpha] — 2026-08

- **DAW:** Ardour e REAPER (Cockos) nel menu come «… - Editor Audio Pro»; REAPER da tarball ufficiale in `/opt/REAPER`.
- **Codec audio** (main + non-free Debian): FFmpeg extra, GStreamer (base/good/bad/ugly/libav/fdkaac), LAME/TwoLAME, FDK AAC / FAAC / FAAD, FLAC, Vorbis, Opus, WavPack, MusePack, SoX.
- **Plugin** LV2/LADSPA/VST/VST3/CLAP: LSP, Calf, x42, Zam, Dragonfly Reverb, SWH, MDA, DPF, EQ10Q, Rubber Band, Invada (`.deb` trixie: non più in sid); synth/sampler (synthv1, samplv1, drumkv1, padthv1, amsynth, hexter), Guitarix, AVLDrums, DrumGizmo; FluidSynth + SoundFont GM.
- **Hardware / interfacce audio esterne:**
  - Focusrite Scarlett/Clarett: `alsa-scarlett-gui` (voce menu Configurazioni).
  - Utilità ALSA: `alsa-tools` / `alsa-tools-gui` — mixer/config RME Hammerfall HDSP (`hdspmixer`, `hdspconf`), mixer ICE1712/Envy24 (`envy24control`).
  - Loader firmware USB/PCI e blob free: `fxload`, `dfu-util`, `firmware-linux-free` (schede legacy / DFU generico).
  - FireWire audio (FFADO, senza JACK): `libffado2`, `ffado-tools`, `ffado-dbus-server`, `ffado-mixer-qt4` — voce menu «Mixer FireWire (FFADO)».
  - Niente JACK/PipeWire in questa release (stack PulseAudio).
- Mixxx: icona Desktop dopo il refresh trust; libreria live su `QUELO-HOME/home/Musica`.
- Sessione: salva/ripristina anche **Ardour**, **REAPER** e **config FireWire FFADO** (`~/.ffado`; voce «Configurazione FireWire (FFADO)» — Scarlett non ha config utente stabile da persistire). Dialog all’avvio e allo spegnimento (solo live).


## [0.01-alpha] — 2026-08

Prima release pubblica di Quelo Audiomaker.

- Live studio: Mixxx (DJ/podcast), Audacity, Audacious, FFmpeg, PulseAudio.
- Firmware audio (SOF, Intel sound, Cirrus, UCM, loader USB dedicati).
- Installer Calamares; sistema installato con LightDM.
- Desktop: HOME, Mixer Dj / Podcast, cestino; menu Openbox fisso.
- Sessione selettiva (rete, stampanti, Bluetooth, desktop, audio, schermo, Firefox, Audacity, Audacious, Mixxx, energia).
