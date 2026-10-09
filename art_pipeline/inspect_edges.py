"""Edge-quality report for extracted character PNGs.

Usage: tools/artenv/Scripts/python art_pipeline/inspect_edges.py <asset_dir> [--preview out.png] [--paper R,G,B]

For every PNG: the share of boundary pixels (alpha > 0 and next to transparency) whose colour is close to
the original paper colour (a light halo), the share of light opaque pixels on the boundary, and
partially transparent pixels. Writes zoomed crops of hair, hand and shoe edges on dark purple and
bright green for visual review.
"""
from __future__ import annotations

import argparse
import glob
import os

import numpy as np
from PIL import Image
from scipy import ndimage


def report(path: str, paper: np.ndarray) -> dict:
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    rgb, a = im[..., :3], im[..., 3] / 255.0
    solid = a > 0.02
    boundary = solid & ndimage.binary_dilation(~solid, iterations=2)
    dist = np.linalg.norm(rgb - paper, axis=2)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    halo = boundary & (dist < 40)
    light = boundary & (lum > 190) & (sat < 30)
    return {
        "file": os.path.basename(path),
        "boundary": int(boundary.sum()),
        "halo_pct": round(100.0 * halo.sum() / max(boundary.sum(), 1), 2),
        "light_pct": round(100.0 * light.sum() / max(boundary.sum(), 1), 2),
        "partial_pct": round(100.0 * ((a > 0.02) & (a < 0.98)).sum() / max(solid.sum(), 1), 2),
    }


def preview(paths: list[str], out: str) -> None:
    tiles = []
    for path in paths:
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        # Hair (upper left), waist/hand (middle right) and feet (bottom) edges.
        boxes = [(0, int(h * 0.08), w // 2, int(h * 0.38)), (w // 2, int(h * 0.35), w, int(h * 0.6)), (0, int(h * 0.82), w, h)]
        for box in boxes:
            crop = im.crop(box)
            crop = crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST)
            for colour in ((40, 18, 52, 255), (40, 220, 90, 255)):
                tile = Image.new("RGBA", crop.size, colour)
                tile.alpha_composite(crop)
                tiles.append(tile.resize((260, max(1, int(260 * tile.height / tile.width))), Image.NEAREST))
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    row_h = [max(t.height for t in tiles[r * cols:(r + 1) * cols]) for r in range(rows)]
    sheet = Image.new("RGBA", (cols * 264, sum(row_h) + rows * 4), (255, 255, 255, 255))
    y = 0
    for r in range(rows):
        for c, tile in enumerate(tiles[r * cols:(r + 1) * cols]):
            sheet.alpha_composite(tile, (c * 264, y))
        y += row_h[r] + 4
    sheet.save(out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("asset_dir")
    parser.add_argument("--preview")
    parser.add_argument("--paper", default="229,220,214")
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    paper = np.array([float(v) for v in args.paper.split(",")])
    paths = sorted(p for p in glob.glob(os.path.join(args.asset_dir, "**", "*.png"), recursive=True)
                   if "masks" not in p.replace(os.sep, "/").split("/"))
    if args.only:
        paths = [p for p in paths if any(o in p.replace(os.sep, "/") for o in args.only.split(","))]
    for path in paths:
        r = report(path, paper)
        print(f"{os.path.relpath(path, args.asset_dir):32s} boundary {r['boundary']:6d}  halo {r['halo_pct']:5.2f}%  light {r['light_pct']:5.2f}%  partial {r['partial_pct']:5.2f}%")
    if args.preview:
        preview(paths, args.preview)
