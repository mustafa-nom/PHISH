#!/usr/bin/env python3
"""Poll Roblox's thumbnails API for the moderation state of every avatar in
upload_results.json. Prints a Pending/Completed/Blocked summary.

Usage:
    python3 tools/check_avatar_moderation.py
    python3 tools/check_avatar_moderation.py --watch   # re-poll every 30s
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
RESULTS_PATH = ROOT / "assets" / "email_avatars" / "upload_results.json"
THUMB_URL = "https://thumbnails.roblox.com/v1/assets"


def collect_ids() -> dict[int, str]:
    if not RESULTS_PATH.exists():
        sys.exit(f"missing {RESULTS_PATH}; run upload_email_avatars.py first")
    results = json.loads(RESULTS_PATH.read_text(encoding="utf-8"))
    out: dict[int, str] = {}
    for card_id, entry in results.items():
        asset_id = entry.get("asset_id")
        if asset_id:
            out[int(asset_id)] = card_id
    return out


def poll_once(ids: dict[int, str]) -> Counter:
    counts: Counter = Counter()
    pending: list[str] = []
    blocked: list[str] = []
    # Roblox limits the request to 100 ids per call; we have 34 so one batch is fine.
    chunk = list(ids.keys())
    r = requests.get(
        THUMB_URL,
        params={"assetIds": ",".join(str(i) for i in chunk),
                "size": "420x420", "format": "Png"},
        timeout=30,
    )
    r.raise_for_status()
    data = r.json().get("data", [])
    for entry in data:
        state = entry.get("state", "Unknown")
        counts[state] += 1
        card_id = ids.get(entry["targetId"], str(entry["targetId"]))
        if state == "Pending":
            pending.append(card_id)
        elif state in ("Blocked", "Error"):
            blocked.append(f"{card_id} ({state})")
    print(f"  Completed: {counts['Completed']:>3}  "
          f"Pending: {counts['Pending']:>3}  "
          f"Blocked: {counts['Blocked']:>3}  "
          f"Other: {sum(v for k, v in counts.items() if k not in ('Completed','Pending','Blocked')):>3}")
    if blocked:
        print("  blocked:", ", ".join(blocked))
    if pending and len(pending) <= 8:
        print("  pending:", ", ".join(pending))
    return counts


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--watch", action="store_true", help="re-poll every 30s")
    args = p.parse_args()

    ids = collect_ids()
    print(f"checking {len(ids)} asset(s)")
    while True:
        counts = poll_once(ids)
        if not args.watch:
            return 0 if counts.get("Pending", 0) == 0 and counts.get("Blocked", 0) == 0 else 1
        if counts.get("Pending", 0) == 0:
            print("all settled.")
            return 0
        time.sleep(30)


if __name__ == "__main__":
    sys.exit(main())
