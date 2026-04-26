#!/usr/bin/env python3
"""Generate email avatar PNGs from docs/EMAIL_AVATAR_PROMPTS.md via Replicate."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import sys
import time
from io import BytesIO
from pathlib import Path
from typing import Any

import requests
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PROMPT_MANIFEST = ROOT / "docs" / "EMAIL_AVATAR_PROMPTS.md"
OUT_DIR = ROOT / "assets" / "email_avatars"
MODEL = "black-forest-labs/flux-schnell"
REPLICATE_API = f"https://api.replicate.com/v1/models/{MODEL}/predictions"


BASE_PROMPT = """Create a square 512x512 profile avatar icon for an email sender in a cozy retro-tropical blocky toy-game cyber-safety fishing game.

The image will appear as a small circular email profile picture in-game, so it must be simple, readable at 48x48 pixels, high contrast, centered, and not busy.

Style:
- playful 3D/cartoon icon
- soft rounded shapes
- warm game UI colors
- clean studio lighting
- no realistic humans
- no real brand logos
- no readable text
- absolutely no typography: no letters, numbers, words, signatures, labels, watermark, seal lettering, at-signs, currency symbols, QR codes, or text-like document lines
- no scary horror imagery
- no tiny details that disappear at small size

Visual tone:
{concept}

Specific visual idea:
{idea}

Composition:
Centered icon on a simple circular or soft-gradient background. The subject should fill most of the frame with generous padding around the edges so it crops well into a circle.

Output:
A single square avatar image, no text, no logo, no border."""


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def parse_rows(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 5:
            continue
        card_id = cells[0].strip("`")
        rows.append(
            {
                "card_id": card_id,
                "sender": cells[1],
                "email": cells[2],
                "legitimacy": cells[3],
                "idea": cells[4],
                "filename": f"{card_id}__{slugify(cells[1])}.png",
            }
        )
    return rows


def build_prompt(row: dict[str, str]) -> str:
    concept = (
        "Make the avatar feel trustworthy, clean, calm, and professional."
        if row["legitimacy"] == "LEGITIMATE"
        else "Make the avatar look like a fake or suspicious profile image: slightly off-brand colors, disguise elements, bait/lure imagery, cracked badge, fake verification mark, suspicious sparkle, fishing hook, mask, glitchy sticker, or too-good-to-be-true prize styling. It should be creative and kid-friendly, not frightening."
    )
    return BASE_PROMPT.format(
        concept=concept,
        idea=row["idea"],
    )


def api_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "wait=5",
    }


def create_prediction(token: str, prompt: str) -> dict[str, Any]:
    response = requests.post(
        REPLICATE_API,
        headers=api_headers(token),
        json={
            "input": {
                "prompt": prompt,
                "go_fast": True,
                "num_outputs": 1,
                "aspect_ratio": "1:1",
                "megapixels": "0.25",
                "num_inference_steps": 4,
                "output_format": "png",
                "disable_safety_checker": False,
            }
        },
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


def wait_for_prediction(token: str, prediction: dict[str, Any]) -> dict[str, Any]:
    get_url = prediction["urls"]["get"]
    while prediction["status"] in {"starting", "processing"}:
        time.sleep(1.0)
        response = requests.get(get_url, headers=api_headers(token), timeout=30)
        response.raise_for_status()
        prediction = response.json()
    if prediction["status"] != "succeeded":
        raise RuntimeError(f"prediction {prediction.get('id')} {prediction['status']}: {prediction.get('error')}")
    return prediction


def output_url(prediction: dict[str, Any]) -> str:
    output = prediction.get("output")
    if isinstance(output, list) and output:
        return str(output[0])
    if isinstance(output, str):
        return output
    raise RuntimeError(f"prediction {prediction.get('id')} returned no output URL")


def download_image(url: str) -> Image.Image:
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    return Image.open(BytesIO(response.content)).convert("RGBA")


def normalize_square(image: Image.Image) -> Image.Image:
    width, height = image.size
    side = min(width, height)
    left = (width - side) // 2
    top = (height - side) // 2
    cropped = image.crop((left, top, left + side, top + side))
    return cropped.resize((512, 512), Image.Resampling.LANCZOS)


def generate_one(token: str, row: dict[str, str], force: bool) -> dict[str, Any]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / row["filename"]
    if out_path.exists() and not force:
        return {**row, "path": str(out_path.relative_to(ROOT)), "status": "skipped"}

    prompt = build_prompt(row)
    prediction = wait_for_prediction(token, create_prediction(token, prompt))
    image = normalize_square(download_image(output_url(prediction)))
    image.save(out_path, "PNG", optimize=True)
    return {
        **row,
        "path": str(out_path.relative_to(ROOT)),
        "status": "generated",
        "prediction_id": prediction.get("id"),
        "model": MODEL,
        "prompt": prompt,
    }


def write_manifest(results: list[dict[str, Any]]) -> None:
    manifest_path = OUT_DIR / "manifest.json"
    kept: list[dict[str, Any]] = []
    for result in results:
        kept.append(
            {
                "card_id": result["card_id"],
                "sender": result["sender"],
                "email": result["email"],
                "legitimacy": result["legitimacy"],
                "path": result["path"],
                "status": result["status"],
                "model": result.get("model", MODEL),
                "prediction_id": result.get("prediction_id"),
            }
        )
    manifest_path.write_text(json.dumps(kept, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0, help="Generate only the first N rows.")
    parser.add_argument("--ids", default="", help="Comma-separated card ids to generate.")
    parser.add_argument("--workers", type=int, default=4, help="Concurrent Replicate predictions.")
    parser.add_argument("--force", action="store_true", help="Regenerate existing PNGs.")
    args = parser.parse_args()

    load_dotenv(ROOT / ".env")
    token = os.environ.get("REPLICATE_API_TOKEN")
    if not token:
        print("REPLICATE_API_TOKEN is not set", file=sys.stderr)
        return 1

    rows = parse_rows(PROMPT_MANIFEST)
    if args.ids:
        wanted = {card_id.strip() for card_id in args.ids.split(",") if card_id.strip()}
        rows = [row for row in rows if row["card_id"] in wanted]
    if args.limit:
        rows = rows[: args.limit]
    if not rows:
        print(f"No rows found in {PROMPT_MANIFEST}", file=sys.stderr)
        return 1

    results: list[dict[str, Any]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as executor:
        future_map = {executor.submit(generate_one, token, row, args.force): row for row in rows}
        for future in concurrent.futures.as_completed(future_map):
            row = future_map[future]
            try:
                result = future.result()
            except Exception as exc:
                result = {**row, "path": str((OUT_DIR / row["filename"]).relative_to(ROOT)), "status": "failed", "error": str(exc)}
            results.append(result)
            print(f"{result['status']}: {result['card_id']} -> {result['path']}")

    results.sort(key=lambda item: [row["card_id"] for row in rows].index(item["card_id"]))
    write_manifest(results)
    failed = [result for result in results if result["status"] == "failed"]
    if failed:
        print(f"{len(failed)} generation(s) failed; rerun to retry skipped/missing assets.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
