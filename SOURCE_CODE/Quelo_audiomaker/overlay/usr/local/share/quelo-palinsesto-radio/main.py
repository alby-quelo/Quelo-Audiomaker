# -*- coding: utf-8 -*-
"""Entry point Quelo-palinsesto-radio."""

from __future__ import annotations

import sys


def main(argv: list[str] | None = None) -> int:
    del argv  # reserved
    from ui import run_app

    return run_app()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
