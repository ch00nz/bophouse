"""Background removal and matting for flat-background character sheets.

Works on illustrations drawn on a near-uniform light "paper" background (the reference sheets in
assets/characters/<id>/references). Never modifies the source files.

Approach (v2, milestone 5C):
  1. Background = paper-coloured pixels, the lighter paper-hued rim that AI art leaves hugging its
     outlines, and warm-grey floor shadows, flood-filled from the image border; plus enclosed
     paper pockets (gaps between hair strands, between an arm and the body).
     Everything is gated on the paper's *hue*, so white eyes, sneakers, teeth, silver earrings and
     skin highlights (neutral, cool or saturated) are never treated as background.
  2. Trimap: sure background, sure foreground (3 px inside), and an unknown edge band.
  3. Closed-form matting in the band: each pixel is unmixed between its nearest sure-foreground
     colour F and the local background colour B (paper or shadow), alpha = projection of C-B on F-B.
  4. Colour decontamination (C - (1 - a) B) / a, then a light subpixel smoothing of the alpha edge.
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage

BAND = 3


def load_rgb(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32)


def background_colour(rgb: np.ndarray) -> np.ndarray:
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3),
                             rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
    return np.median(border, axis=0)


def _paper_like(rgb: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Pixels with the paper's warm hue that are as light as the paper or lighter (the paper itself
    and the light rim AI art paints around outlines)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    rg, gb = r - g, g - b
    bg_rg, bg_gb = float(bg[0] - bg[1]), float(bg[1] - bg[2])
    lum = rgb.mean(axis=2)
    hue = (np.abs(rg - bg_rg) <= 6.0) & (np.abs(gb - bg_gb) <= 5.0) & (b < g + 1)
    return hue & (lum > float(bg.mean()) - 10.0)


def background_mask(rgb: np.ndarray, bg: np.ndarray, tolerance: float = 14.0, rim: int = 3,
                    big_pocket: int = 60, min_pocket: int = 3, hair_ring: float = 0.6,
                    max_half_width: float = 3.2) -> np.ndarray:
    dist = np.linalg.norm(rgb - bg, axis=2)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    paper = (dist < tolerance) & (b <= g + 1)
    # Floor shadows: warm greys darker than the paper (blue lowest). Cool or neutral greys (white
    # sneakers' shading, fabric) are never shadows.
    warm = (b < g) & (g <= r + 2) & (r - b >= 6)
    shadow = warm & (sat < 26) & (lum > 120) & (lum < float(bg.mean()) + 6)
    labels, _ = ndimage.label(paper | shadow)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    mask = np.isin(labels, edge_labels[edge_labels > 0])
    # The light paper-hued rim AI art paints around outlines: background only within a few pixels
    # of real background, so large light areas (white soles, fabric) are never eaten.
    light = _paper_like(rgb, bg)
    mask |= light & ndimage.binary_dilation(mask, iterations=rim)
    # Enclosed pockets: big exact-paper gaps (between an arm and the body) always; small ones only
    # when ringed by dark hair (gaps between strands), which keeps teeth, eye whites and highlights.
    hairish = (lum < 115) & (sat < 95) & (r >= g - 2) & (g >= b - 4)
    # Near-white painted strokes (neutral or slightly pink) also qualify, but only as thin strips
    # (checked below), so eye whites and teeth, which are thicker blobs, always survive.
    near_white = (lum > 205) & (sat < 32) & (b <= g + 3)
    pockets = (paper | light | near_white) & ~mask
    plabels, count = ndimage.label(pockets)
    if count:
        sizes = ndimage.sum(pockets, plabels, index=np.arange(1, count + 1))
        median_dist = ndimage.median(dist, plabels, index=np.arange(1, count + 1))
        remove = np.zeros(count + 1, dtype=bool)
        for i, box in enumerate(ndimage.find_objects(plabels), start=1):
            if sizes[i - 1] < min_pocket:
                continue
            if sizes[i - 1] >= big_pocket and median_dist[i - 1] < 10.0:
                remove[i] = True
                continue
            ys = slice(max(box[0].start - 3, 0), box[0].stop + 3)
            xs = slice(max(box[1].start - 3, 0), box[1].stop + 3)
            blob = plabels[ys, xs] == i
            # Judge the ring by its non-background pixels: a light strip between hair and the
            # background (a painted rim on a hair lock) counts as hair-bounded too.
            ring = ndimage.binary_dilation(blob, iterations=2) & ~blob & ~mask[ys, xs]
            # Thick light areas qualify only on the outer edge (touching the background): painted
            # rim strokes on hair locks. Eye whites and teeth never touch the background.
            touches_bg = (ndimage.binary_dilation(blob, iterations=1) & mask[ys, xs]).any()
            thin = touches_bg or ndimage.distance_transform_edt(blob).max() <= max_half_width
            if thin and ring.any() and hairish[ys, xs][ring].mean() >= hair_ring:
                remove[i] = True
        mask |= remove[plabels]
    return mask


def local_background(rgb: np.ndarray, background: np.ndarray, sigma: float = 3.0) -> np.ndarray:
    """Background colour everywhere (paper, or the shadow under the feet), from nearby background pixels."""
    w = ndimage.gaussian_filter(background.astype(np.float32), sigma)
    out = np.stack([ndimage.gaussian_filter(rgb[..., c] * background, sigma) for c in range(3)], axis=2)
    out /= np.maximum(w, 1e-4)[..., None]
    far = w < 1e-3
    if far.any():
        # Far from any background pixel: use the nearest background pixel's colour.
        _, (iy, ix) = ndimage.distance_transform_edt(~background, return_indices=True)
        out[far] = rgb[iy[far], ix[far]]
    return out


def alpha_matte(rgb: np.ndarray, bg: np.ndarray, background: np.ndarray, band: int = BAND,
                ramp: float = 45.0) -> tuple[np.ndarray, np.ndarray]:
    """Soft, decontaminated alpha. Returns (colour, alpha)."""
    sure_fg = ~ndimage.binary_dilation(background, iterations=band)
    unknown = ~background & ~sure_fg
    alpha = np.where(background, 0.0, 1.0).astype(np.float32)
    out = rgb.copy()
    if unknown.any() and sure_fg.any():
        B = local_background(rgb, background)
        _, (iy, ix) = ndimage.distance_transform_edt(~sure_fg, return_indices=True)
        F = rgb[iy, ix]
        C = rgb
        fb = F - B
        denom = (fb * fb).sum(axis=2)
        proj = ((C - B) * fb).sum(axis=2) / np.maximum(denom, 1e-3)
        # Where foreground and background colours are too alike, fall back to colour distance.
        dist_alpha = np.linalg.norm(C - B, axis=2) / ramp
        a = np.where(denom > 25.0 ** 2, proj, dist_alpha)
        a = np.clip(a, 0.0, 1.0)
        alpha[unknown] = a[unknown]
        safe = np.maximum(alpha, 1e-3)[..., None]
        unblended = np.clip((C - (1.0 - safe) * B) / safe, 0, 255)
        out[unknown] = unblended[unknown]
    # Subpixel smoothing of the edge (removes stair-steps left by the binary background mask),
    # never lowering the solid interior.
    edge = ndimage.binary_dilation(background, iterations=band + 1) & ~background | unknown
    soft = ndimage.gaussian_filter(alpha, 0.6)
    alpha[edge] = np.minimum(alpha[edge], np.maximum(soft[edge], alpha[edge] * 0.5))
    alpha[alpha < 0.04] = 0.0
    # Fully transparent pixels take the nearest visible colour, so filtering/mipmaps never bleed paper.
    hidden = alpha <= 0.0
    if hidden.any() and (~hidden).any():
        _, (iy, ix) = ndimage.distance_transform_edt(hidden, return_indices=True)
        out[hidden] = out[iy[hidden], ix[hidden]]
    return out, alpha


def figures(alpha: np.ndarray, min_fraction: float = 0.01) -> list[tuple[int, int, int, int, int]]:
    """Large foreground blobs as (x0, y0, x1, y1, area), left to right."""
    solid = alpha > 0.5
    labels, count = ndimage.label(solid)
    if not count:
        return []
    areas = ndimage.sum(solid, labels, index=np.arange(1, count + 1))
    boxes = ndimage.find_objects(labels)
    result = []
    for i, box in enumerate(boxes):
        if areas[i] < min_fraction * solid.size:
            continue
        ys, xs = box
        result.append((xs.start, ys.start, xs.stop, ys.stop, int(areas[i])))
    return sorted(result, key=lambda b: (b[1] // 300, b[0]))


def rgba(rgb: np.ndarray, alpha: np.ndarray) -> Image.Image:
    data = np.dstack([rgb, alpha * 255.0]).round().clip(0, 255).astype(np.uint8)
    return Image.fromarray(data, "RGBA")
