# Quelo Audiomaker

**Italiano** · [English](README.en.md)

**Quelo Audiomaker** è una distribuzione Linux **live e installabile** pensata per girare da chiavetta USB: un piccolo studio di produzione audio portatile, in italiano, pronto all’uso su quasi qualsiasi PC.

Ispirata al personaggio «Quelo» di Corrado Guzzanti e derivata dal progetto **Quelo Office**, unisce la solidità di **Debian GNU/Linux** a un ambiente grafico leggero (**LXQt + Openbox**), con strumenti per registrazione, editing, DJ set, podcast, streaming e produzione DAW.

**Release:** **[0.13-alpha](https://github.com/alby-quelo/Quelo-Audiomaker/releases/tag/0.13-alpha)**  
**ISO intera (mirror):** [https://click2all.org/iso/Quelo-Audiomaker-0.13-alpha.iso](https://click2all.org/iso/Quelo-Audiomaker-0.13-alpha.iso)  
**Sito web:** [https://alby-quelo.github.io/Quelo-Audiomaker/](https://alby-quelo.github.io/Quelo-Audiomaker/)  
**Changelog:** [`CHANGELOG.md`](CHANGELOG.md)


## In evidenza

### Live **e** installabile — salvataggio / ripristino sessione

- **Live da USB:** avvio immediato senza toccare i dischi interni; ogni boot riparte dall’**immagine ISO pulita** (cache e temp in RAM).
- **Salvataggio selettivo della sessione** (solo live): allo spegnimento puoi scegliere **cosa** conservare (rete, stampanti, Bluetooth, desktop, audio, schermo, Firefox, Audacity, Audacious, Mixxx, Ardour, REAPER, BUTT, FFADO, gestione energia…) — senza trasformare la live in un sistema opaco.
- **Installabile su disco** con **Calamares** (interno o esterno): sistema stabile con LightDM; live e installata restano separate.
- Dati e media sulla partizione **QUELO-HOME** (**exFAT**), leggibile anche da Windows e macOS.

### REAPER (Cockos)

Nella distro è incluso **REAPER** (menu **REAPER - Editor Audio Pro**). Si può usare **anche senza acquistare subito la licenza** (modalità di valutazione Cockos): dopo circa 60 giorni compare un **avviso**, ma il programma **continua a funzionare al 100%** — è solo un reminder, non un blocco.

Si invita comunque a **sostenere il progetto Cockos** acquistando una licenza ufficiale:  
→ [https://www.reaper.fm/](https://www.reaper.fm/)

### Quelo-palinsesto-radio

Applicazione inclusa (**menu PALINSESTO RADIO**) per programmare e mandare in onda un palinsesto radio settimanale — pensata per emittenti web, community radio e studio portatile.

- **Calendario settimanale** (lunedì–domenica), colonne giorno × 24 ore; **zoom verticale** della timeline; etichetta **24:00**.
- Tipi di slot: **file audio**, **PLAYLIST** (m3u/pls), fasce **LIVE** (ingresso microfono/linea via Pulse) e **LINK** (stream http/https).
- **ANTI BIANCO**: playlist filler nei “buchi” di palinsesto e in failover (LINK offline o silence-gate); **ripresa** dalla posizione interrotta.
- **Silence-gate**: se la sorgente in onda scende sotto soglia (anche cavo staccato) → ANTI BIANCO, poi ripresa automatica. Soglie per FILE / LINK / LIVE in **SETTING**.
- **SETTING**: silence-gate + aspetto font dei blocchi timeline.
- Import file: peak-normalize verso 0 dB di picco; titolo/descrizione da tag (o modifica manuale).
- Timeline a blocchi colorati (altezza ∝ durata); **Start** avvia lo scheduler in tempo reale (VU 0 dBFS + volume).
- Persistenza: un solo DB SQLite `.palinsesto.db` su **QUELO-HOME** (live) o `$HOME` (installata) — **non** passa dal salva-sessione.
- **Manuale:** [scarica il PDF](https://github.com/alby-quelo/Quelo-Audiomaker/raw/main/docs/manuale_palinsesto.pdf)


## A cosa serve

- portare con sé un **kit audio** (DAW, editor, mixer DJ/podcast, player, codec, plugin, streaming, palinsesto);
- lavorare su **più PC** con la stessa chiavetta;
- avere **file personali leggibili anche da Windows e macOS**;
- **installare** Quelo Audiomaker su disco quando serve un sistema fisso.


## Novità nella 0.13-alpha (da 0.12)

Dettaglio: [`CHANGELOG.md`](CHANGELOG.md).

- Pannello LXQt: lo spazio **Home** (usata / libera / totale) compare anche sul
  sistema **installato** (non solo in live) — stesso schema di Videomaker.


## Caratteristiche principali

### Sistema e desktop

- **Debian sid** (live-build), locale **italiano**, fuso **Europe/Rome**.
- **Live:** autologin → desktop (**startx**, **LXQt** + **Openbox**).
- **Installata:** **LightDM** + greeter GTK.
- Due pannelli LXQt (versione / RAM+ZRAM / home / orologio; menu, taskbar, rete, Bluetooth, batteria, volume, spegnimento).
- Icone Desktop: **HOME**, **Mixer Dj / Podcast**, **MANUALE PALINSESTO**.
- Guida menu: [`HOW-TO-menu-config.txt`](HOW-TO-menu-config.txt).

### Installer (Calamares)

- Disco di destinazione; `/` solo (tutto il disco) oppure `/` + HOME; HOME **exFAT** (default) o **ext4**.
- Riepilogo partizioni/GRUB in Calamares; conferma prima dell’installazione.

### Applicazioni incluse

| Area | Software |
|------|----------|
| DAW | Ardour, REAPER (Editor Audio Pro) — **ALSA in esclusiva** |
| DJ / podcast | Mixxx |
| Streaming live | **BUTT** (Icecast/Shoutcast/WebRTC) — **STREAMING LIVE** |
| Analisi file | **MediaInfo** |
| Convertitore | **CONVERTITORE AUDIO** |
| Palinsesto radio | **quelo-palinsesto-radio** — **PALINSESTO RADIO** |
| Editing | Audacity |
| Player | Audacious |
| Codec | FFmpeg extra, GStreamer, LAME, FDK AAC, FLAC, Opus, SoX… |
| Plugin | LSP, Calf, x42, Zam, Dragonfly, SWH, MDA, DPF, synth/sampler, Guitarix, FluidSynth+GM… |
| Interfacce | Focusrite Scarlett/Clarett; FFADO FireWire; RME HDSP; Envy24; fxload / dfu-util |
| Web / utilità | Firefox ESR, Mousepad, Zathura, pcmanfm-qt, CUPS, Blueman… |

**Ardour e REAPER** usano **ALSA** in esclusiva (PulseAudio sospeso mentre sono aperti). Per l’ascolto quotidiano chiudere la DAW.

Stack desktop: **PulseAudio** (niente JACK/PipeWire in questa release).


## Requisiti consigliati

| Uso / software | RAM minima | RAM ottimale |
|----------------|------------|--------------|
| Desktop LXQt | 2 GB | 4 GB |
| PALINSESTO RADIO | 2–4 GB | 4–8 GB |
| Mixxx | 4 GB | 8 GB |
| Ardour / REAPER | 4–8 GB | 8–16 GB |

**Chiavetta:** USB 3+, **64 GB+** consigliati. ZRAM (~50% RAM, lz4) aiuta le macchine con poca RAM.


## Layout della chiavetta USB

Dopo `prepare-usb` (stesso schema di Quelo Office / Videomaker):

```
┌─────────────────────────────────────────────────────────┐
│  Partizione 1–2  │  ISO live (sola lettura al boot)     │
├──────────────────┼──────────────────────────────────────┤
│  Partizione 3    │  ext4 «persistence» — config Linux   │
│                  │  (invisibile a Windows/macOS)        │
├──────────────────┼──────────────────────────────────────┤
│  Partizione 4    │  exFAT «QUELO-HOME» — i tuoi file    │
│                  │  (leggibile ovunque)                 │
└─────────────────────────────────────────────────────────┘
```


## Come si usa

### 1. Scarica l’ISO

**Consigliato — file unico (~2,5 GB):**  
[https://click2all.org/iso/Quelo-Audiomaker-0.13-alpha.iso](https://click2all.org/iso/Quelo-Audiomaker-0.13-alpha.iso)

(Sul mirror restano anche la **0.12**; la **0.08** non è più sul mirror — resta scaricabile a pezzi dalla [release GitHub 0.08-alpha](https://github.com/alby-quelo/Quelo-Audiomaker/releases/tag/0.08-alpha).)

**Oppure da GitHub** (ISO spezzata, limite 2 GB/file) — release **[0.13-alpha](https://github.com/alby-quelo/Quelo-Audiomaker/releases/tag/0.13-alpha)**:

- `Quelo-Audiomaker-0.13-alpha.iso.part00`
- `Quelo-Audiomaker-0.13-alpha.iso.part01`
- `Quelo-Audiomaker-0.13-alpha.iso.sha256` (opzionale)
- script JOIN: [`docs/JOIN-ISO-0.13-alpha.sh`](docs/JOIN-ISO-0.13-alpha.sh) / [`docs/JOIN-ISO-0.13-alpha.bat`](docs/JOIN-ISO-0.13-alpha.bat)  
  istruzioni complete: [`docs/README-ISO-0.13-alpha.txt`](docs/README-ISO-0.13-alpha.txt)

**Unisci le parti** (nella stessa cartella dei file scaricati):

Windows — Prompt dei comandi:

```bat
copy /b Quelo-Audiomaker-0.13-alpha.iso.part00 + Quelo-Audiomaker-0.13-alpha.iso.part01 Quelo-Audiomaker-0.13-alpha.iso
```

Linux / macOS:

```bash
cat Quelo-Audiomaker-0.13-alpha.iso.part* > Quelo-Audiomaker-0.13-alpha.iso
```

In alternativa: doppio clic su `JOIN-ISO-0.13-alpha.bat` (Windows) oppure `bash JOIN-ISO-0.13-alpha.sh` (Linux) — dettagli in [`README-ISO-0.13-alpha.txt`](docs/README-ISO-0.13-alpha.txt).

### 2. Prepara la chiavetta USB

**Importante:** prepara la USB **dal PC host**, **mai** dalla live avviata sulla stessa chiavetta.

**Linux — GUI** (dal repo):

```bash
cd USB_SOURCE_CODE/Quelo_prepare_usb
./prepare-usb-gui.sh
```

Prerequisiti host (Debian/Ubuntu):  
`sudo apt install python3 python3-tk e2fsprogs exfatprogs util-linux polkit-1`

**Windows — GUI** (32/64 bit, offline; stesso layout di partizioni, da Quelo Office 0.71 — già adatto a questa ISO):

- [ZIP](https://github.com/alby-quelo/quelo-office/releases/download/0.71-alpha/Quelo-prepare_usb_windows.zip)
- [RAR](https://github.com/alby-quelo/quelo-office/releases/download/0.71-alpha/Quelo-prepare_usb_windows.rar)
- [TAR](https://github.com/alby-quelo/quelo-office/releases/download/0.71-alpha/Quelo-prepare_usb_windows.tar)

Estrai, avvia la GUI come amministratore, scegli `Quelo-Audiomaker-0.13-alpha.iso` e conferma con `SI SCRIVI`.

### 3. Avvia dal BIOS/UEFI

Seleziona avvio da USB. Sul Desktop: **HOME**, **Mixer Dj / Podcast**, **MANUALE PALINSESTO**.

### 4. (Opzionale) Installa su disco

Menu: **Configurazioni → Installa Quelo Audiomaker sul PC**.

### 5. Spegnimento e sessione (solo live)

Dal pulsante **Spegni** puoi salvare in modo selettivo le configurazioni prima di uscire.


## Sviluppo e sorgenti

| Cartella | Contenuto |
|----------|-----------|
| `SOURCE_CODE/Quelo_audiomaker/` | Build ISO (live-build, overlay, hooks) |
| `USB_SOURCE_CODE/Quelo_prepare_usb/` | prepare-usb Linux (CLI + GUI) |
| `ISO/` | Immagini generate in locale (non nel git) |

```bash
sudo SOURCE_CODE/Quelo_audiomaker/build.sh
```

Documenti: **`LICENSE.TXT`**, **`CREDITS.TXT`**, **`CHANGELOG.md`**, **`HOW-TO-menu-config.txt`**.


## Avvertenza

> **Avvertenza.** Quelo Audiomaker è distribuito «così com'è», senza garanzie di alcun tipo, espresse o implicite. È realizzato a **scopo didattico e sperimentale**: non sostituisce l'assistenza professionale né garantisce il corretto funzionamento su ogni hardware o l'esito delle operazioni su dischi, sistemi o reti. L'uso è a proprio rischio; l'autore non risponde di danni diretti o indiretti derivanti dall'uso dell'ISO, degli script o delle istruzioni pubblicate.


## Licenza

Il lavoro originale Quelo Audiomaker è rilasciato sotto **Creative Commons BY-NC 4.0**. Uso didattico e non commerciale consentito con attribuzione; uso commerciale solo con autorizzazione scritta di **Alberto Frosio** (`alby@gnumerica.org`).

I software inclusi nell’ISO restano soggetti alle rispettive licenze — vedi `LICENSE.TXT` e `CREDITS.TXT`. REAPER è software proprietario Cockos (dopo ~60 giorni compare un avviso di valutazione, ma continua a funzionare al 100%); si invita a [acquistare una licenza](https://www.reaper.fm/) per sostenere gli autori.
