#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Partiziona SOLO il disco scelto nel wizard e riempie GlobalStorage per mount/bootloader.

Sostituisce il modulo partition di Calamares in show/exec (blocco disco + EFI affidabile).
"""

from __future__ import annotations

import os
import re
import subprocess
import time
from pathlib import Path

import libcalamares

import gettext

_ = gettext.translation(
    "calamares-python",
    localedir=libcalamares.utils.gettext_path(),
    languages=libcalamares.utils.gettext_languages(),
    fallback=True,
).gettext

CHOICES = Path("/etc/quelo-install-choices.yaml")


def pretty_name():
    return _("Quelo: partizionamento disco di destinazione")


def _load_choices() -> dict:
    data = {}
    path = CHOICES if CHOICES.is_file() else Path("/etc/calamares/quelo-install-choices.yaml")
    if not path.is_file():
        return data
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line == "---" or ":" not in line:
            continue
        k, v = line.split(":", 1)
        data[k.strip()] = v.strip().strip('"')
    return data


def _run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    libcalamares.utils.debug("quelo-partition: " + " ".join(cmd))
    return subprocess.run(cmd, check=check, text=True, capture_output=True)


def _part_node(disk: str, index: int) -> str:
    base = disk
    if re.search(r"(nvme|mmcblk|loop)\d", disk) or disk[-1].isdigit():
        return f"{disk}p{index}"
    return f"{disk}{index}"


def _blkid(device: str, key: str) -> str:
    try:
        out = subprocess.check_output(["blkid", "-s", key, "-o", "value", device], text=True)
        return out.strip()
    except subprocess.CalledProcessError:
        return ""


def _is_uefi() -> bool:
    return Path("/sys/firmware/efi").is_dir()


def _wait_node(path: str, seconds: float = 15.0) -> bool:
    end = time.time() + seconds
    while time.time() < end:
        if Path(path).exists():
            return True
        time.sleep(0.2)
    return Path(path).exists()


def run():
    data = _load_choices()
    disk = data.get("targetDevice", "")
    grub = data.get("grubDevice") or disk
    if not disk.startswith("/dev/"):
        return (
            _("Disco di destinazione non valido"),
            _("Esegui di nuovo l'installer e scegli il disco."),
        )
    if not Path(disk).exists():
        return (_("Disco non trovato"), disk)

    separate = str(data.get("separateHome", "false")).lower() == "true"
    home_fs = data.get("homeFilesystem", "exfat")
    root_raw = str(data.get("rootGiB", "80")).strip().lower()

    # Sicurezza: unica / (rootGiB: rest) ⇒ MAI HOME/exFAT, anche se il yaml è incoerente.
    if root_raw in ("rest", "100%", "all", "entire"):
        separate = False
        home_fs = "none"

    # Unica / → sempre tutto il disco (ext4). HOME separata → / a rootGiB GiB, HOME = resto.
    if not separate:
        root_entire = True
        root_gib = 0
        home_fs = "none"
    else:
        root_entire = False
        try:
            root_gib = int(float(root_raw)) if root_raw not in ("rest", "100%", "all", "entire") else 80
        except ValueError:
            root_gib = 80
        if root_gib < 1:
            root_gib = 80
        if home_fs not in ("exfat", "ext4"):
            return (
                _("Formato HOME non valido"),
                _("Scegli exFAT o ext4 nel wizard layout disco."),
            )

    # --- wipe + GPT ---
    _run(["swapoff", "-a"], check=False)
    # Smonta eventuali partizioni del disco target
    try:
        ls = subprocess.check_output(["lsblk", "-ln", "-o", "NAME,MOUNTPOINT", disk], text=True)
        for line in ls.splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2 and parts[1].strip() and parts[1].strip() != "[SWAP]":
                _run(["umount", "-l", parts[1].strip()], check=False)
    except subprocess.CalledProcessError:
        pass

    _run(["wipefs", "-af", disk], check=False)
    _run(["sgdisk", "--zap-all", disk], check=False)
    _run(["sgdisk", "-o", disk], check=False)  # nuova GPT pulita
    _run(["udevadm", "settle"], check=False)
    time.sleep(1)

    uefi = _is_uefi()
    partitions_gs = []
    next_idx = 1

    cmds = ["sgdisk"]
    if uefi:
        cmds += ["-n", f"{next_idx}:0:+512M", "-t", f"{next_idx}:ef00", "-c", f"{next_idx}:EFI"]
        efi_idx = next_idx
        next_idx += 1
    else:
        cmds += ["-n", f"{next_idx}:0:+1M", "-t", f"{next_idx}:ef02", "-c", f"{next_idx}:biosgrub"]
        bios_idx = next_idx
        next_idx += 1
        efi_idx = None

    root_idx = next_idx
    if root_entire:
        # Unica / (o rootGiB: rest): fino a fine disco.
        cmds += ["-n", f"{root_idx}:0:0", "-t", f"{root_idx}:8300", "-c", f"{root_idx}:root"]
        next_idx += 1
        home_idx = None
    else:
        cmds += ["-n", f"{root_idx}:0:+{root_gib}G", "-t", f"{root_idx}:8300", "-c", f"{root_idx}:root"]
        next_idx += 1
        home_idx = next_idx
        ptype = "0700" if home_fs == "exfat" else "8300"
        cmds += ["-n", f"{home_idx}:0:0", "-t", f"{home_idx}:{ptype}", "-c", f"{home_idx}:HOME"]
        next_idx += 1

    cmds.append(disk)
    try:
        _run(cmds, check=True)
    except subprocess.CalledProcessError as exc:
        return (
            _("Creazione tabella partizioni fallita"),
            (exc.stderr or exc.stdout or str(exc))[:2000],
        )

    _run(["partprobe", disk], check=False)
    _run(["udevadm", "settle"], check=False)
    time.sleep(1)

    # --- filesystems ---
    try:
        if uefi and efi_idx is not None:
            efi_dev = _part_node(disk, efi_idx)
            if not _wait_node(efi_dev):
                return (_("Partizione EFI non apparsa"), efi_dev)
            _run(["mkfs.vfat", "-F", "32", "-n", "EFI", efi_dev], check=True)

        root_dev = _part_node(disk, root_idx)
        if not _wait_node(root_dev):
            return (_("Partizione root non apparsa"), root_dev)
        # / è SEMPRE ext4 (mai exFAT).
        _run(["mkfs.ext4", "-F", "-L", "root", root_dev], check=True)

        home_dev = None
        if separate:
            if home_idx is None:
                return (
                    _("HOME separata richiesta ma non creata"),
                    _("Riavvia l'installer e ripeti il wizard layout disco."),
                )
            home_dev = _part_node(disk, home_idx)
            if not _wait_node(home_dev):
                return (
                    _("Partizione HOME non apparsa sul disco"),
                    _(
                        "Atteso {dev}. Installazione interrotta: nessuna HOME creata."
                    ).format(dev=home_dev),
                )
            # exFAT consentito SOLO sulla partizione HOME separata.
            if home_fs == "exfat":
                _run(["mkfs.exfat", "-n", "HOME", home_dev], check=True)
            else:
                _run(["mkfs.ext4", "-F", "-L", "HOME", home_dev], check=True)
        elif home_idx is not None:
            return (
                _("Layout incoerente"),
                _("Unica / non deve creare HOME. Ripeti il wizard layout disco."),
            )
    except subprocess.CalledProcessError as exc:
        return (
            _("Formattazione partizione fallita"),
            (exc.stderr or exc.stdout or str(exc))[:2000],
        )

    _run(["udevadm", "settle"], check=False)

    # --- GlobalStorage ---
    gs = libcalamares.globalstorage

    def add_part(device: str, mp: str, fs: str, label: str, options: str = "") -> None:
        entry = {
            "device": device,
            "mountPoint": mp,
            "fs": fs,
            "fsName": fs,
            "uuid": _blkid(device, "UUID"),
            "partuuid": _blkid(device, "PARTUUID"),
            "partlabel": label,
            "claimed": True,
            "features": {},
        }
        # Mount options fstab (Calamares modulo fstab).
        if options:
            entry["options"] = options
        partitions_gs.append(entry)

    if uefi and efi_idx is not None:
        add_part(_part_node(disk, efi_idx), "/boot/efi", "fat32", "EFI")
        gs.insert("efiSystemPartition", "/boot/efi")

    add_part(root_dev, "/", "ext4", "root")
    if separate and home_dev:
        mp = "/media/HOME" if home_fs == "exfat" else "/home"
        # exFAT installata: fmask/dmask 0022 (NON 0000) — file non world-writable
        # (stesso criterio della live QUELO-HOME). uid/gid li rifinisce configure-home.
        home_opts = (
            "uid=1000,gid=1000,fmask=0022,dmask=0022"
            if home_fs == "exfat"
            else ""
        )
        add_part(
            home_dev,
            mp,
            "exfat" if home_fs == "exfat" else "ext4",
            "HOME",
            home_opts,
        )

    gs.insert("partitions", partitions_gs)
    gs.insert("bootLoader", {"installPath": grub})
    # Richiesto dal modulo bootloader (di solito lo scrive "partition").
    gs.insert("firmwareType", "efi" if uefi else "bios")
    gs.insert("queloTargetDevice", disk)
    gs.insert("queloGrubDevice", grub)
    gs.insert("queloSeparateHome", separate)
    gs.insert("queloHomeFilesystem", home_fs if separate else "none")
    gs.insert("queloRootGiB", "rest" if root_entire else root_gib)
    if separate:
        summary = f"{disk} · GRUB {grub} · /={root_gib}G · HOME {home_fs} (resto)"
    else:
        summary = f"{disk} · GRUB {grub} · / = tutto il disco"
    gs.insert("queloDiskSummary", summary)

    # filesystem_use hints (best-effort)
    fs_use = {}
    for p in partitions_gs:
        fs_use[p["fs"]] = 2
    gs.insert("filesystem_use", fs_use)

    # Fail-fast: HOME separata deve comparire in GlobalStorage
    if separate and not any(p.get("partlabel") == "HOME" for p in partitions_gs):
        return (
            _("HOME separata non registrata"),
            _("Il partizionamento non ha prodotto la partizione HOME. Installazione interrotta."),
        )

    libcalamares.utils.debug(f"quelo-partition-disk OK: {gs.value('queloDiskSummary')}")
    return None
