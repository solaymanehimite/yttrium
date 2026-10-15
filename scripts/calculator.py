#!/usr/bin/env python3
"""Small calculator adapter for the launcher.

Prefer libqalculate when installed. It handles units, conversions, dates, and
rich mathematical syntax. Fall back to numexpr or bc so basic arithmetic still
works on a minimal install.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys


def run(command: list[str], *, input_text: str = "") -> str:
    result = subprocess.run(
        command,
        input=input_text,
        text=True,
        capture_output=True,
        timeout=2,
        check=False,
    )
    if result.returncode != 0:
        return ""
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return lines[-1] if lines else ""


def qalc(expression: str) -> str:
    if not shutil.which("qalc"):
        return ""
    return run(["qalc", "-t", expression])


def numexpr(expression: str) -> str:
    try:
        import numexpr  # type: ignore

        value = numexpr.evaluate(expression)
        if getattr(value, "size", 1) != 1:
            return ""
        return str(value.item())
    except Exception:
        return ""


def bc(expression: str) -> str:
    # Keep the fallback arithmetic-only. qalc is the backend for richer input.
    if not re.fullmatch(r"[0-9a-zA-Z_+*/%().,^\s-]+", expression):
        return ""
    return run(["bc", "-l"], input_text=expression + "\n")


def main() -> int:
    expression = " ".join(sys.argv[1:]).strip()
    if not expression or len(expression) > 240:
        return 1

    value = qalc(expression) or numexpr(expression) or bc(expression)
    if not value:
        return 1

    print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
