# Calamares — Quelo Audiomaker (SOURCE_CODE)

## Flusso runtime (sicurezza disco)

1. **Configurazioni → Installa Quelo Audiomaker sul PC** (icona Desktop dopo ~8 s)
2. Wizard layout: disco destinazione + `/` o `/`+HOME + dimensioni
3. **Conferma GRUB**: disco install (fisso) + disco GRUB (modificabile)
4. **Riepilogo**: schema partizioni *prima/dopo*, nome disco, dove va GRUB → OK
5. Calamares: Welcome → Locale → Tastiera → Utente → **Riepilogo (stesso schema)** → Installa  
   *(niente pagina Partizioni Calamares: evita selezione disco sbagliato)*
6. Exec: `quelo-partition-disk` (wipefs + GPT + EFI/root/HOME solo sul disco scelto)
   poi mount / unpack / bootloader / post-install

## File principali

| Path | Ruolo |
|------|--------|
| `usr/local/bin/quelo-install` | entry: layout → GRUB → riepilogo → calamares |
| `usr/local/bin/quelo-calamares-disk-layout` | wizard organizzazione disco |
| `usr/local/bin/quelo-calamares-grub-confirm` | conferma disco + GRUB |
| `usr/local/bin/quelo-calamares-riepilogo` | riepilogo visivo + genera QML notesqml |
| `usr/lib/calamares/modules/quelo-partition-disk/` | partizionamento + GlobalStorage |
| `etc/calamares/settings.conf` | sequenza senza modulo `partition` UI; notesqml@quelo-riepilogo |

## Note

- Minimo `/` 40 GiB, default 80 (`quelo-sizes.conf`)
- HOME exFAT → `/media/HOME`; ext4 → `/home`
- `bootloader` stock richiede `partition`: hook 0470 lo reindirizza a `quelo-partition-disk`
- Icona Desktop: scritta anche da `quelo-usb-mount-home` + ritentativi su QUELO-HOME
- Live: pacchetto `squashfs-tools` obbligatorio (Calamares `unpackfs` → `unsquashfs`)
- Live: pacchetto `sudo` obbligatorio (Calamares users → `/etc/sudoers.d/10-installer`)
- Live: pacchetti `grub-efi*` / `efibootmgr` in squashfs (UEFI offline)
- Live: `grub-pc*` solo in pool ISO (`packages/grub-bios.list.binary`) per BIOS offline
- `calamares-sources-media` Quelo: suite = codename immagine (sid), non trixie
- Slideshow: immagine a tutto spazio + testo su fascia scura leggibile
- Installato: LightDM + autologin LXQt (niente SDDM); live resta getty+startx
- Salva/ripristino sessione: solo LIVE (autostart e GUI); rimossi/bloccati sull'installata
- Look desktop (sfondo pcmanfm + lxqt): seed su skel e home utente in post-install
- Installata HOME exFAT: fstab `fmask=0022,dmask=0022` (+ uid/gid utente) su `/media/HOME`
- Installata GRUB: gfxmode ≤1600x900, splash logo Quelo, timeout 2s (live ISO invariata)
- Schermo: live = persistence Quelo (`salva_sessione`/`load_sessione`);
  installata = lxrandr nativo (come Debian), niente salvataggio Quelo dedicato
