#!/usr/bin/env python3
"""Pre-compute pywal palettes for every wallpaper, without applying them.

Uses the same backend and scheme cache as ~/.config/scripts/setwall.sh
(colorz, ~/.cache/wal/schemes), so the preview matches what applying gives.
pywal.colors.get() only reads/writes scheme files; it never touches
~/.cache/wal/colors.json, which is what the shell watches.
Writes {file name: {"bg", "fg", "colors": [16]}} to the output JSON, or
{"error": ...} when the backend can't run (e.g. colorz missing).

usage: wal-palettes.py <wallpaper dir> <output json>
"""
import json, logging, os, sys

import pywal

logging.getLogger().setLevel(logging.ERROR)

src, out = sys.argv[1], sys.argv[2]
exts = (".jpg", ".jpeg", ".png", ".webp", ".gif")

try:
    with open(out) as f:
        result = json.load(f)
except (OSError, ValueError):
    result = {}

files = sorted(f for f in os.listdir(src) if f.lower().endswith(exts))
for name in files:
    if name in result and "error" not in result[name]:
        continue
    # colorz like setwall.sh; it gives up on near-greyscale images, and then
    # setwall.sh falls back to wal's default (imagemagick) backend, so do the same
    c, err = None, None
    for backend in ("colorz", "wal"):
        try:
            c = pywal.colors.get(os.path.join(src, name), backend=backend, sat=None)  # sat=None like the wal CLI, so its cache is hit
            break
        except BaseException as e:  # pywal sys.exit()s when a backend fails
            err = f"{backend} backend failed" if isinstance(e, SystemExit) else str(e)
    if c is None:
        result[name] = {"error": err}
        continue
    result[name] = {
        "bg": c["special"]["background"],
        "fg": c["special"]["foreground"],
        "colors": [c["colors"][f"color{i}"] for i in range(16)],
    }
    # write after each image so the picker can show palettes as they arrive
    tmp = out + ".tmp"
    with open(tmp, "w") as f:
        json.dump(result, f)
    os.replace(tmp, out)

# drop entries for deleted wallpapers
result = {k: v for k, v in result.items() if k in files}
with open(out + ".tmp", "w") as f:
    json.dump(result, f)
os.replace(out + ".tmp", out)
