#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Carica le scelte del wizard layout disco in GlobalStorage (per log/riepilogo)."""

import libcalamares
from pathlib import Path

import gettext

_ = gettext.translation(
    "calamares-python",
    localedir=libcalamares.utils.gettext_path(),
    languages=libcalamares.utils.gettext_languages(),
    fallback=True,
).gettext

CHOICES = Path("/etc/quelo-install-choices.yaml")


def pretty_name():
    return _("Quelo disk layout choices")


def run():
    gs = libcalamares.globalstorage
    if not CHOICES.is_file():
        libcalamares.utils.warning("quelo-apply-layout: missing choices file")
        return None

    text = CHOICES.read_text(encoding="utf-8", errors="replace")
    data = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line == "---":
            continue
        if ":" not in line:
            continue
        key, val = line.split(":", 1)
        data[key.strip()] = val.strip().strip('"')

    separate = data.get("separateHome", "false").lower() == "true"
    gs.insert("queloSeparateHome", separate)
    gs.insert("queloHomeFilesystem", data.get("homeFilesystem", "none"))
    root_raw = str(data.get("rootGiB", "80")).strip().lower()
    if not separate or root_raw in ("rest", "100%", "all", "entire"):
        gs.insert("queloRootGiB", "rest")
    else:
        try:
            gs.insert("queloRootGiB", int(float(root_raw)))
        except ValueError:
            gs.insert("queloRootGiB", 80)
    gs.insert("queloTargetDevice", data.get("targetDevice", ""))
    gs.insert("queloMinRootGiB", int(data.get("minRootGiB", "40") or 40))
    gs.insert("queloRecommendedRootGiB", int(data.get("recommendedRootGiB", "80") or 80))

    # Testo chiaro per eventuali consumer / debug
    if separate:
        org = f"Sistema e HOME separate · HOME {data.get('homeFilesystem', '?')}"
        root_s = data.get("rootGiB", "?")
    else:
        org = "Unica partizione / (tutto il disco)"
        root_s = "rest"
    gs.insert(
        "queloDiskSummary",
        f"{data.get('targetDevice', '?')} · {org} · / = {root_s}"
        + (" GiB" if separate else ""),
    )
    libcalamares.utils.debug(f"quelo-apply-layout: {gs.value('queloDiskSummary')}")
    return None
