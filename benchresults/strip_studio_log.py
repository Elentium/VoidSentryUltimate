#!/usr/bin/env python3
"""Strip Roblox Studio Output prefixes/suffixes from pasted bench logs.

Removes:
  HH:MM:SS.mmm  ...  -  Server - Comparator:123
  HH:MM:SS.mmm  ...  -  Client - SomeScript:45
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TIMESTAMP = re.compile(r"^\d{1,2}:\d{2}:\d{2}(?:\.\d+)?\s+")
STUDIO_SOURCE = re.compile(
    r"\s+[-–]\s+(?:Server|Client)\s+[-–]\s+\S+:\d+\s*$",
    re.UNICODE,
)


def strip_line(line: str) -> str:
    text = line.rstrip("\n\r")
    text = TIMESTAMP.sub("", text, count=1)
    text = STUDIO_SOURCE.sub("", text, count=1)
    return text.rstrip()


def strip_text(raw: str) -> str:
    lines = [strip_line(line) for line in raw.splitlines()]
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines) + ("\n" if lines else "")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Strip Studio timestamps and Server/Client script suffixes from bench logs.",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="Log files to strip. Reads stdin if omitted.",
    )
    parser.add_argument(
        "-i",
        "--in-place",
        action="store_true",
        help="Overwrite each file instead of printing to stdout.",
    )
    args = parser.parse_args()

    if not args.paths:
        if args.in_place:
            parser.error("--in-place requires at least one file path")
        sys.stdout.write(strip_text(sys.stdin.read()))
        return 0

    for path in args.paths:
        cleaned = strip_text(path.read_text(encoding="utf-8"))
        if args.in_place:
            path.write_text(cleaned, encoding="utf-8")
        else:
            sys.stdout.write(cleaned)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
