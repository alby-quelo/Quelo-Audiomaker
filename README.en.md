# Quelo Audiomaker

[Italiano](README.md) · **English**

**Quelo Audiomaker** is a **live and installable** Linux distribution designed to run from a USB stick: a small, portable audio production studio in Italian, ready to use on almost any PC.

Inspired by Corrado Guzzanti’s «Quelo» character and derived from **Quelo Office**, it combines the reliability of **Debian GNU/Linux** with a lightweight desktop (**LXQt + Openbox**) and tools for recording, editing, DJ sets, podcasts, streaming and DAW production.

**Release:** **[0.12-alpha](https://github.com/alby-quelo/Quelo-Audiomaker/releases/tag/0.12-alpha)**  
**Full ISO (mirror):** [https://click2all.org/iso/Quelo-Audiomaker-0.12-alpha.iso](https://click2all.org/iso/Quelo-Audiomaker-0.12-alpha.iso)  
**Website:** [https://alby-quelo.github.io/Quelo-Audiomaker/en/](https://alby-quelo.github.io/Quelo-Audiomaker/en/)  
**Changelog:** [`CHANGELOG.md`](CHANGELOG.md)


## Highlights

### Live **and** installable — selective session save / restore

- **Live from USB:** boot without touching internal disks; every boot starts from a **clean ISO image** (caches/temp in RAM).
- **Selective session save** (live only): on shutdown you choose **what** to keep (network, printers, Bluetooth, desktop, audio, display, Firefox, Audacity, Audacious, Mixxx, Ardour, REAPER, BUTT, FFADO, power management…) — without turning the live system into an opaque install.
- **Installable to disk** with **Calamares** (internal or external): stable system with LightDM; live and installed remain separate.
- User data on **QUELO-HOME** (**exFAT**), readable on Windows and macOS too.

### REAPER (Cockos)

The distro includes **REAPER** (menu **REAPER - Editor Audio Pro**). You can use it **without buying a license immediately** (Cockos evaluation mode): after about 60 days a **nag dialog** appears, but the program **keeps working at 100%** — it is only a reminder, not a lockout.

You are still **encouraged to support Cockos** by purchasing an official license:  
→ [https://www.reaper.fm/](https://www.reaper.fm/)

### Quelo-palinsesto-radio

Bundled app (**PALINSESTO RADIO** menu) to schedule and play a weekly radio schedule — for web radio, community stations and a portable studio.

- **Weekly calendar** (Monday–Sunday), day columns × 24 hours; **vertical zoom**; **24:00** label.
- Slot types: **audio files**, **PLAYLIST** (m3u/pls), **LIVE** windows (Pulse mic/line input), and **LINK** streams (http/https).
- **ANTI BIANCO**: filler playlist for schedule gaps and failover (offline LINK or silence-gate); **resume** from the interrupted position.
- **Silence-gate**: if the on-air source drops below threshold (including a disconnected cable) → ANTI BIANCO, then automatic resume. Thresholds per FILE / LINK / LIVE in **SETTING**.
- **SETTING**: silence-gate + clip font appearance on the timeline.
- File import: peak-normalize toward 0 dB peak; title/description from tags (or manual edit).
- Coloured timeline blocks (height ∝ duration); **Start** runs the real-time scheduler (0 dBFS VU + volume).
- Persistence: one SQLite DB `.palinsesto.db` on **QUELO-HOME** (live) or `$HOME` (installed) — **not** via session save.
- **Manual:** [download PDF](https://github.com/alby-quelo/Quelo-Audiomaker/raw/main/docs/manuale_palinsesto.pdf)


## What it is for

- carry an **audio toolkit** (DAWs, editor, DJ/podcast mixer, player, codecs, plugins, streaming, radio schedule);
- work on **multiple PCs** with the same stick;
- keep **personal files readable on Windows and macOS**;
- **install** Quelo Audiomaker to disk when you need a fixed system.


## What’s new in 0.12-alpha (since 0.08)

Full detail: [`CHANGELOG.md`](CHANGELOG.md).

- Desktop/USB: safe eject, USB label, Power Management, QUELO-HOME automount
  (exFAT), QasTools, faster desktop start.
- Calamares: wizards/summary aligned with Videomaker; Qt6 QML fix for failed summary load.


## Main features

### System and desktop

- **Debian sid** (live-build), **Italian** locale, **Europe/Rome** timezone.
- **Live:** autologin → desktop (**startx**, **LXQt** + **Openbox**).
- **Installed:** **LightDM** + GTK greeter.
- Two LXQt panels; Desktop icons **HOME**, **Mixer Dj / Podcast**, **MANUALE PALINSESTO**.
- Menu how-to: [`HOW-TO-menu-config.txt`](HOW-TO-menu-config.txt).

### Installer (Calamares)

- Target disk; `/` only (whole disk) or `/` + HOME; HOME **exFAT** (default) or **ext4**.
- Partition/GRUB summary in Calamares before install.

### Included applications

| Area | Software |
|------|----------|
| DAW | Ardour, REAPER (Editor Audio Pro) — **exclusive ALSA** |
| DJ / podcast | Mixxx |
| Live streaming | **BUTT** — **STREAMING LIVE** |
| File analysis | **MediaInfo** |
| Converter | **CONVERTITORE AUDIO** |
| Radio schedule | **quelo-palinsesto-radio** — **PALINSESTO RADIO** |
| Editing | Audacity |
| Player | Audacious |
| Codecs / plugins / interfaces | FFmpeg, GStreamer, LV2/VST stacks, Focusrite, FFADO, RME HDSP… |
| Web / utilities | Firefox ESR, Mousepad, Zathura, pcmanfm-qt, CUPS, Blueman… |

**Ardour and REAPER** use exclusive **ALSA** (PulseAudio suspended while open). Desktop stack: **PulseAudio** (no JACK/PipeWire in this release).


## Recommended requirements

| Use / software | Min RAM | Optimal RAM |
|----------------|---------|-------------|
| LXQt desktop | 2 GB | 4 GB |
| PALINSESTO RADIO | 2–4 GB | 4–8 GB |
| Mixxx | 4 GB | 8 GB |
| Ardour / REAPER | 4–8 GB | 8–16 GB |

**USB stick:** USB 3+, **64 GB+** recommended. ZRAM (~50% of RAM, lz4) helps low-RAM machines.


## USB stick layout

After `prepare-usb` (same scheme as Quelo Office / Videomaker):

```
┌─────────────────────────────────────────────────────────┐
│  Partitions 1–2  │  Live ISO (read-only at boot)        │
├──────────────────┼──────────────────────────────────────┤
│  Partition 3     │  ext4 «persistence» — Linux configs  │
│                  │  (hidden from Windows/macOS)         │
├──────────────────┼──────────────────────────────────────┤
│  Partition 4     │  exFAT «QUELO-HOME» — your files     │
│                  │  (readable everywhere)               │
└─────────────────────────────────────────────────────────┘
```


## How to use

### 1. Download the ISO

**Recommended — single file (~2.5 GB):**  
[https://click2all.org/iso/Quelo-Audiomaker-0.12-alpha.iso](https://click2all.org/iso/Quelo-Audiomaker-0.12-alpha.iso)

**Or from GitHub** (split ISO, 2 GB/file limit) — release **[0.12-alpha](https://github.com/alby-quelo/Quelo-Audiomaker/releases/tag/0.12-alpha)**:

- `Quelo-Audiomaker-0.12-alpha.iso.part00`
- `Quelo-Audiomaker-0.12-alpha.iso.part01`
- `Quelo-Audiomaker-0.12-alpha.iso.sha256` (optional)
- JOIN scripts: [`docs/JOIN-ISO-0.12-alpha.sh`](docs/JOIN-ISO-0.12-alpha.sh) / [`docs/JOIN-ISO-0.12-alpha.bat`](docs/JOIN-ISO-0.12-alpha.bat)  
  full instructions: [`docs/README-ISO-0.12-alpha.txt`](docs/README-ISO-0.12-alpha.txt)

**Join the parts** (in the same folder as the downloaded files):

Windows — Command Prompt:

```bat
copy /b Quelo-Audiomaker-0.12-alpha.iso.part00 + Quelo-Audiomaker-0.12-alpha.iso.part01 Quelo-Audiomaker-0.12-alpha.iso
```

Linux / macOS:

```bash
cat Quelo-Audiomaker-0.12-alpha.iso.part* > Quelo-Audiomaker-0.12-alpha.iso
```

Alternatively: double-click `JOIN-ISO-0.12-alpha.bat` (Windows) or `bash JOIN-ISO-0.12-alpha.sh` (Linux) — details in [`README-ISO-0.12-alpha.txt`](docs/README-ISO-0.12-alpha.txt).

### 2. Prepare the USB stick

**Important:** prepare the USB **from the host PC**, **never** from the live system booted from the same stick.

**Linux — GUI** (from the repo):

```bash
cd USB_SOURCE_CODE/Quelo_prepare_usb
./prepare-usb-gui.sh
```

Host prerequisites (Debian/Ubuntu):  
`sudo apt install python3 python3-tk e2fsprogs exfatprogs util-linux polkit-1`

**Windows — GUI** (32/64-bit, offline; same partition layout, from Quelo Office 0.71 — already suitable for this ISO):

- [ZIP](https://github.com/alby-quelo/quelo-office/releases/download/0.71-alpha/Quelo-prepare_usb_windows.zip)
- [RAR](https://github.com/alby-quelo/quelo-office/releases/download/0.71-alpha/Quelo-prepare_usb_windows.rar)
- [TAR](https://github.com/alby-quelo/quelo-office/releases/download/0.71-alpha/Quelo-prepare_usb_windows.tar)

Extract, run the GUI as administrator, choose `Quelo-Audiomaker-0.12-alpha.iso`, confirm with `SI SCRIVI`.

### 3. Boot from BIOS/UEFI

Select USB boot. Desktop: **HOME**, **Mixer Dj / Podcast**, **MANUALE PALINSESTO**.

### 4. (Optional) Install to disk

Menu: **Configurazioni → Installa Quelo Audiomaker sul PC**.

### 5. Shutdown and session (live only)

From **Power off** you can selectively save settings before exiting.


## Development and sources

| Folder | Contents |
|--------|----------|
| `SOURCE_CODE/Quelo_audiomaker/` | ISO build (live-build, overlay, hooks) |
| `USB_SOURCE_CODE/Quelo_prepare_usb/` | Linux prepare-usb (CLI + GUI) |
| `ISO/` | Locally built images (not in git) |

```bash
sudo SOURCE_CODE/Quelo_audiomaker/build.sh
```

Docs: **`LICENSE.TXT`**, **`CREDITS.TXT`**, **`CHANGELOG.md`**, **`HOW-TO-menu-config.txt`**.


## Disclaimer

> **Disclaimer.** Quelo Audiomaker is provided “as is”, without warranties of any kind, express or implied. It is built for **educational and experimental** purposes: it does not replace professional support and does not guarantee correct behaviour on every hardware or the outcome of operations on disks, systems or networks. Use at your own risk; the author is not liable for direct or indirect damages arising from use of the ISO, scripts or published instructions.


## License

Original Quelo Audiomaker work is released under **Creative Commons BY-NC 4.0**. Educational and non-commercial use allowed with attribution; commercial use only with written permission from **Alberto Frosio** (`alby@gnumerica.org`).

Software included in the ISO remains under its respective licenses — see `LICENSE.TXT` and `CREDITS.TXT`. REAPER is proprietary Cockos software (after ~60 days an evaluation nag appears, but it keeps working at 100%); please consider [buying a license](https://www.reaper.fm/) to support the authors.
