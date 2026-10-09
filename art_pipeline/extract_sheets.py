"""Extract game-ready character art from illustrated reference sheets.

Usage (from the repo root, with the art venv):
    tools/artenv/Scripts/python art_pipeline/extract_sheets.py art_pipeline/ava_sheets.json [--preview out.png]

For every item in the manifest it:
  1. repaints any listed patches (e.g. removes a real brand logo) on an in-memory copy,
  2. removes the flat paper background and floor shadows with soft, decontaminated edges,
  3. isolates the figure in its box (largest blob plus nearby hair strands and earrings),
  4. trims it with a little padding and records the feet anchor and a shared per-sheet scale,
  5. writes full-resolution PNGs (hero/portrait use) and downscaled sprites (house use),
  6. writes illustrated.json describing every asset for the game (IllustratedArt).
Source sheets are only read, never written.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from cutout import alpha_matte, background_colour, background_mask, load_rgb, rgba  # noqa: E402
from masks import hair_mask, luminance_range, save_mask  # noqa: E402

PAD = 6


def apply_patches(rgb: np.ndarray, patches: list) -> np.ndarray:
    out = rgb.copy()
    for patch in patches:
        x0, y0, x1, y1 = patch["box"]
        region = out[y0:y1, x0:x1]
        lum = region.mean(axis=2)
        if patch.get("mode") == "fill_dark":
            # Find the light mark on dark fabric, then inpaint it from the surrounding fabric with a
            # normalised blur (keeps the fabric's soft shading instead of a flat patch).
            dark_level = np.percentile(lum, 35)
            mark = ndimage.binary_dilation(lum > dark_level + 14.0, iterations=2)
            pad = 10
            ys, xs = max(y0 - pad, 0), max(x0 - pad, 0)
            area = out[ys:y1 + pad, xs:x1 + pad]
            known = np.ones(area.shape[:2], dtype=np.float32)
            known[y0 - ys:y1 - ys, x0 - xs:x1 - xs][mark] = 0.0
            weight = ndimage.gaussian_filter(known, 3.0)
            filled = np.stack([ndimage.gaussian_filter(area[..., ch] * known, 3.0) for ch in range(3)], axis=2)
            filled /= np.maximum(weight, 1e-3)[..., None]
            target = area[y0 - ys:y1 - ys, x0 - xs:x1 - xs]
            target[mark] = filled[y0 - ys:y1 - ys, x0 - xs:x1 - xs][mark]
    return out


def isolate(alpha: np.ndarray, kind: str) -> np.ndarray:
    if kind == "lying":
        kind = "full_body"
    """Keep the main figure in a box: the largest blob, plus smaller blobs touching its bounds."""
    solid = alpha > 0.5
    labels, count = ndimage.label(solid)
    if count == 0:
        return alpha
    areas = ndimage.sum(solid, labels, index=np.arange(1, count + 1))
    main = int(np.argmax(areas)) + 1
    boxes = ndimage.find_objects(labels)
    my, mx = boxes[main - 1]
    keep = np.zeros(count + 1, dtype=bool)
    keep[main] = True
    for i, box in enumerate(boxes, start=1):
        if i == main:
            continue
        ys, xs = box
        overlaps = xs.start < mx.stop + 8 and xs.stop > mx.start - 8 and ys.start < my.stop + 8 and ys.stop > my.start - 8
        # A neighbouring figure's part cut off by the box edge (a stray shoe or hand) is dropped.
        clipped = xs.start == 0 or xs.stop == alpha.shape[1]
        # Scenes keep their props; figures keep strands/earrings but drop distant marks (labels).
        if kind == "scene" or (overlaps and not clipped and areas[i - 1] >= 12):
            keep[i] = True
    figure = keep[labels]
    # Soft edge pixels belong to the figure if they touch a kept blob.
    near = ndimage.binary_dilation(figure, iterations=3)
    return np.where(near, alpha, 0.0).astype(np.float32)


def sheer(rgb: np.ndarray, raw: np.ndarray, alpha: np.ndarray, bg: np.ndarray, regions: list) -> tuple[np.ndarray, np.ndarray]:
    """Translucent fabric (e.g. a beach cover-up) painted over the paper. Inside each region's closed
    silhouette, every pixel is unmixed between white fabric and the paper, so the sheer cloth keeps
    its painted folds as varying opacity instead of turning into holes (with a minimum opacity)."""
    for region in regions:
        x0, y0, x1, y1 = region["box"]
        a = alpha[y0:y1, x0:x1]
        c = rgb[y0:y1, x0:x1]
        raw_c = raw[y0:y1, x0:x1]
        solid = a > 0.5
        n = int(region.get("close", 10))
        padded = np.pad(solid, n + 1, mode="edge")
        closed = ndimage.binary_closing(padded, iterations=n)[n + 1:-n - 1, n + 1:-n - 1]
        closed = ndimage.binary_fill_holes(closed)
        # Gaps, plus painted fabric pixels that are really paper seen through the sheer cloth.
        near_paper = np.linalg.norm(raw[y0:y1, x0:x1] - bg, axis=2) < 26.0
        gaps = closed & ((a < 0.95) | near_paper)
        fabric = np.array(region.get("tint", [253, 251, 249]), dtype=np.float32)
        fb = fabric - bg
        sheer_a = np.clip(((raw_c - bg) * fb).sum(axis=2) / max(float((fb * fb).sum()), 1e-3), 0.0, 1.0)
        sheer_a = np.maximum(sheer_a, float(region.get("opacity", 0.45)))
        new_a = np.maximum(a, sheer_a)
        # Fabric colour: white cloth, keeping a little of the painted fold shading.
        unmixed = np.clip((raw_c - (1.0 - new_a[..., None]) * bg) / np.maximum(new_a[..., None], 1e-3), 0, 255)
        # Fold shading is kept as neutral grey: the painting's beige came from the paper behind it.
        shade = float(region.get("shading", 0.35))
        neutral = np.repeat(unmixed.mean(axis=2, keepdims=True), 3, axis=2) * np.array([0.98, 0.99, 1.0])
        c[gaps] = fabric * (1.0 - shade) + neutral[gaps] * shade
        a[gaps] = new_a[gaps]
    return rgb, alpha


def strip_white_props(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Removes painted props in neutral white (pillows, sheets) that touch the transparent area.
    Only for items that have no large white parts of their own (e.g. the sleeping pose)."""
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    white = (alpha > 0.02) & (lum > 195) & (sat < 34)
    labels, count = ndimage.label(white)
    if count:
        outside = ndimage.binary_dilation(alpha < 0.05, iterations=2)
        touching = np.unique(labels[outside & white])
        drop = np.isin(labels, touching[touching > 0])
        drop = ndimage.binary_dilation(drop, iterations=1) & (lum > 170) & (sat < 40)
        alpha = np.where(drop, 0.0, alpha).astype(np.float32)
    return isolate(alpha, "full_body")


def trim(img_rgb: np.ndarray, alpha: np.ndarray) -> tuple[np.ndarray, np.ndarray, tuple[int, int]]:
    ys, xs = np.nonzero(alpha > 0.02)
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, alpha.shape[0])
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, alpha.shape[1])
    return img_rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1], (x0, y0)


def feet_anchor(alpha: np.ndarray) -> tuple[float, float, float]:
    """(x, y) where the figure stands (centre of the lowest rows) and the figure height in px."""
    solid = alpha > 0.5
    ys, xs = np.nonzero(solid)
    top, bottom = ys.min(), ys.max()
    height = float(bottom - top + 1)
    band = ys >= bottom - 0.035 * height
    return float(xs[band].mean()), float(bottom + 1), height


def downscale(image: Image.Image, factor: float) -> Image.Image:
    size = (max(1, round(image.width * factor)), max(1, round(image.height * factor)))
    # Resample premultiplied so transparent edges don't pick up dark or light fringes.
    return image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def run(manifest_path: str, preview: str | None) -> None:
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    out_dir = manifest["out_dir"]
    for sub in ("full", "sprite", "portrait", "reference", "masks/full", "masks/sprite", "masks/portrait"):
        os.makedirs(os.path.join(out_dir, sub), exist_ok=True)
    figure_units = float(manifest["figure_units"])
    sprite_height = float(manifest["sprite_height_px"])
    assets: dict = {}
    previews: list[Image.Image] = []

    for sheet in manifest["sheets"]:
        path = os.path.join(manifest["source_dir"], sheet["file"])
        rgb = apply_patches(load_rgb(path), sheet.get("patches", []))
        bg = background_colour(rgb)
        clean, alpha = alpha_matte(rgb, bg, background_mask(rgb, bg))
        extracted = {}
        for item in sheet["items"]:
            x0, y0, x1, y1 = item["box"]
            a = isolate(alpha[y0:y1, x0:x1], item["kind"])
            c = clean[y0:y1, x0:x1].copy()
            if item.get("strip_white_props"):
                a = strip_white_props(c, a)
            if item.get("sheer"):
                c, a = sheer(c, rgb[y0:y1, x0:x1], a, bg, item["sheer"])
            c, a, offset = trim(c, a)
            extracted[item["name"]] = (item, c, a, (offset[0] + x0, offset[1] + y0))
        ref_height = None
        if sheet.get("scale_ref"):
            ref_height = feet_anchor(extracted[sheet["scale_ref"]][2])[2]
        for name, (item, c, a, origin) in extracted.items():
            image = rgba(c, a)
            kind = item["kind"]
            if item.get("rotate"):
                # Turn a figure (e.g. a top-down sleeper) to lie along the bed; optionally mirrored.
                image = image.convert("RGBa").rotate(float(item["rotate"]), resample=Image.BICUBIC, expand=True).convert("RGBA")
                if item.get("mirror"):
                    image = image.transpose(Image.FLIP_LEFT_RIGHT)
                image = image.crop(image.getchannel("A").point(lambda v: 255 if v > 5 else 0).getbbox())
                a = np.asarray(image.getchannel("A")).astype(np.float32) / 255.0
            entry = {k: v for k, v in item.items() if k not in ("box", "name")}
            entry["source"] = {"sheet": sheet["file"], "rect": [int(origin[0]), int(origin[1]), image.width, image.height]}
            folder = {"full_body": "full", "lying": "full", "bust": "portrait", "scene": "reference"}[kind]
            file_path = os.path.join(out_dir, folder, name + ".png")
            image.save(file_path, optimize=True)
            entry["file"] = "res://" + file_path.replace(os.sep, "/")
            entry["size"] = [image.width, image.height]
            if kind == "lying" and ref_height:
                # Rests on its lowest edge; the game fits its length to the bed.
                ys, xs = np.nonzero(a > 0.5)
                ax, ay = float(xs.min() + xs.max()) * 0.5, float(ys.max() + 1)
                factor = sprite_height / ref_height
                entry["anchor"] = [round(ax, 1), round(ay, 1)]
                entry["length_px"] = int(xs.max() - xs.min() + 1)
                entry["units_per_px"] = round(figure_units / ref_height, 6)
                sprite = downscale(image, factor)
                sprite_path = os.path.join(out_dir, "sprite", name + ".png")
                sprite.save(sprite_path, optimize=True)
                entry["sprite"] = {"file": "res://" + sprite_path.replace(os.sep, "/"), "size": [sprite.width, sprite.height],
                    "anchor": [round(ax * factor, 1), round(ay * factor, 1)], "units_per_px": round(figure_units / sprite_height, 6)}
            if kind == "full_body" and ref_height:
                ax, ay, height = feet_anchor(a)
                entry["anchor"] = [round(ax, 1), round(ay, 1)]
                entry["figure_height_px"] = round(height, 1)
                entry["units_per_px"] = round(figure_units / ref_height, 6)
                factor = sprite_height / ref_height
                sprite = downscale(image, factor)
                sprite_path = os.path.join(out_dir, "sprite", name + ".png")
                sprite.save(sprite_path, optimize=True)
                entry["sprite"] = {
                    "file": "res://" + sprite_path.replace(os.sep, "/"),
                    "size": [sprite.width, sprite.height],
                    "anchor": [round(ax * factor, 1), round(ay * factor, 1)],
                    "units_per_px": round(figure_units / sprite_height, 6),
                }
            if kind != "scene":
                _write_masks(entry, image, out_dir, folder, name, item)
            assets[name] = entry
            previews.append(image)
            print(f"  {name:16s} {kind:9s} {image.width}x{image.height}")

    meta = {
        "_comment": "Generated by art_pipeline/extract_sheets.py from " + manifest_path.replace(os.sep, "/") + ". Do not edit by hand; re-run the pipeline.",
        "character": manifest["character"],
        "figure_units": figure_units,
        "assets": assets,
    }
    with open(os.path.join(out_dir, "illustrated.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    print("wrote", os.path.join(out_dir, "illustrated.json"))
    if preview:
        contact_sheet(previews).save(preview)
        print("preview", preview)


def _write_masks(entry: dict, image: Image.Image, out_dir: str, folder: str, name: str, item: dict) -> None:
    """Recolour masks (hair) for the full image and its sprite, plus the hair's luminance range."""
    pixels = np.asarray(image.convert("RGBA"))
    mask = hair_mask(pixels, crown_side=str(item.get("crown", "top")))
    if mask.max() < 0.5:
        return
    path = os.path.join(out_dir, "masks", folder, name + "_hair.png")
    mask_image = save_mask(mask, path)
    entry["masks"] = {"hair": "res://" + path.replace(os.sep, "/")}
    entry["hair_lum"] = luminance_range(pixels, mask)
    if "sprite" in entry:
        size = tuple(entry["sprite"]["size"])
        sprite_path = os.path.join(out_dir, "masks", "sprite", name + "_hair.png")
        mask_image.resize(size, Image.LANCZOS).save(sprite_path, optimize=True)
        entry["sprite"]["masks"] = {"hair": "res://" + sprite_path.replace(os.sep, "/")}


def contact_sheet(images: list[Image.Image]) -> Image.Image:
    """Every cutout on a checkerboard (top) and on dark and pink backdrops (bottom) to judge edges."""
    thumb_h = 300
    thumbs = [im.resize((max(1, round(im.width * thumb_h / im.height)), thumb_h), Image.LANCZOS) for im in images]
    width = sum(t.width + 8 for t in thumbs) + 8
    sheet = Image.new("RGBA", (width, thumb_h * 2 + 24), (40, 20, 50, 255))
    x = 8
    for t in thumbs:
        checker = Image.new("RGBA", t.size, (255, 255, 255, 255))
        for cy in range(0, t.height, 12):
            for cx in range(0, t.width, 12):
                if (cx // 12 + cy // 12) % 2:
                    checker.paste((200, 200, 200, 255), (cx, cy, cx + 12, cy + 12))
        sheet.alpha_composite(checker, (x, 8))
        sheet.alpha_composite(t, (x, 8))
        dark = Image.new("RGBA", t.size, (36, 18, 46, 255) if (x // 50) % 2 else (230, 90, 150, 255))
        sheet.alpha_composite(dark, (x, thumb_h + 16))
        sheet.alpha_composite(t, (x, thumb_h + 16))
        x += t.width + 8
    return sheet


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("manifest")
    parser.add_argument("--preview", help="write a contact sheet PNG for review")
    args = parser.parse_args()
    run(args.manifest, args.preview)
