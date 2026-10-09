"""Background removal and figure detection for flat-background character sheets.

Works on illustrations drawn on a near-uniform light background (the reference sheets in
assets/characters/<id>/references). Never modifies the source files.
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage


def load_rgb(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32)


def background_colour(rgb: np.ndarray) -> np.ndarray:
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3),
                             rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
    return np.median(border, axis=0)


def background_mask(rgb: np.ndarray, bg: np.ndarray, tolerance: float = 26.0,
                    enclosed_tolerance: float = 9.0, min_enclosed: int = 60) -> np.ndarray:
    """True where the pixel is background: the flat paper colour or its soft grey cast shadows,
    connected to the image border, plus enclosed pockets (between an arm and the body) that are
    almost exactly the paper colour."""
    dist = np.linalg.norm(rgb - bg, axis=2)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    bg_lum = float(bg.mean())
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # The paper and its floor shadows are warm greys (blue lowest). White sneakers, white fabric
    # and their grey shading are neutral-to-cool (blue >= green), so they are never treated as paper.
    warm = (b < g) & (g <= r + 2) & (r - b >= 6)
    shadow = warm & (sat < 26) & (lum > 120) & (lum < bg_lum + 6)
    candidate = ((dist < tolerance) & (b <= g + 1)) | shadow
    labels, _ = ndimage.label(candidate)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    edge_labels = edge_labels[edge_labels > 0]
    mask = np.isin(labels, edge_labels)
    # Enclosed pockets of paper colour.
    pockets = (dist < enclosed_tolerance) & ~mask
    plabels, count = ndimage.label(pockets)
    if count:
        sizes = ndimage.sum(pockets, plabels, index=np.arange(1, count + 1))
        keep = np.flatnonzero(sizes >= min_enclosed) + 1
        mask |= np.isin(plabels, keep)
    return mask


def alpha_matte(rgb: np.ndarray, bg: np.ndarray, background: np.ndarray, band: int = 2,
                ramp: float = 70.0) -> tuple[np.ndarray, np.ndarray]:
    """Alpha with soft, decontaminated edges: pixels within `band` px of the background get alpha
    from their colour distance to the paper, and the paper colour is un-blended out of them."""
    alpha = np.where(background, 0.0, 1.0).astype(np.float32)
    near = ndimage.binary_dilation(background, iterations=band) & ~background
    dist = np.linalg.norm(rgb - bg, axis=2)
    edge_alpha = np.clip(dist / ramp, 0.0, 1.0)
    alpha[near] = edge_alpha[near]
    out = rgb.copy()
    a = np.clip(alpha, 1e-3, 1.0)[..., None]
    unblended = (rgb - (1.0 - a) * bg) / a
    out[near] = np.clip(unblended[near], 0, 255)
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
