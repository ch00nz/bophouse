"""Recolour masks for painted characters (milestone 5D).

hair_mask(rgba) finds the hair in a flattened painting so the game can recolour it with a shader
(see src/art/shaders/painted_recolor.gdshader) without touching skin, eyes, lips or clothing:

  1. Colour: hair is a desaturated red-brown (green ~ blue, red above both, darkish). Skin has green
     well above blue, lips have blue above green, denim is blue, black sportswear is neutral.
  2. Shape: thin strokes of the same colour (line art, lashes, brows) are removed by a morphological
     opening; only big masses survive.
  3. Topology: the hair is the mass connected to the top of the head, so the kept components are the
     ones that reach the crown band (plus big masses touching them, e.g. long hair over a shoulder).
  4. Detail: lighter highlights and fine strands next to the mass are grown back geodesically (only
     through hair-coloured pixels, a few pixels at a time), then the edge is feathered.
The mask is a soft 0..1 image the size of the painting. Hand-painted masks can replace it any time
(same file name), which is the production-quality path.
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage


def hair_colour(rgb: np.ndarray, lum_max: float = 150.0) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = rgb.mean(axis=2)
    return (lum < lum_max) & (r > g + 6) & (np.abs(g - b) < 14) & (r - b < 120)


def hair_mask(rgba: np.ndarray, crown_band: float = 0.12, open_radius: int = 3, grow: int = 6,
              min_fraction: float = 0.004, region: tuple[float, float] | None = None,
              crown_side: str = "top", near_px: float = 45.0) -> np.ndarray:
    """Soft hair mask (float32 0..1). `region` optionally limits it to a vertical span (fractions of
    the figure height), e.g. (0, 0.75) for standing figures whose hair never reaches the knees."""
    rgb = rgba[..., :3].astype(np.float32)
    alpha = rgba[..., 3].astype(np.float32) / 255.0
    visible = alpha > 0.3
    core = hair_colour(rgb, 95.0) & visible
    loose = hair_colour(rgb, 150.0) & visible
    ys, xs = np.nonzero(visible)
    if ys.size == 0:
        return np.zeros(alpha.shape, np.float32)
    top, bottom = ys.min(), ys.max()
    height = bottom - top + 1
    if region is not None:
        allowed = np.zeros_like(core)
        allowed[top + int(region[0] * height): top + int(region[1] * height) + 1] = True
        core &= allowed
        loose &= allowed
    structure = ndimage.generate_binary_structure(2, 1)
    opened = ndimage.binary_opening(core, structure, iterations=open_radius)
    labels, count = ndimage.label(opened)
    if count == 0:
        return np.zeros(alpha.shape, np.float32)
    sizes = ndimage.sum(opened, labels, index=np.arange(1, count + 1))
    big = np.flatnonzero(sizes >= min_fraction * visible.sum()) + 1
    if crown_side == "left": # lying figures: the head is at the left end
        left = xs.min()
        width = xs.max() - left + 1
        band = (slice(None), slice(left, left + max(int(crown_band * width), 1)))
    else:
        band = (slice(top, top + max(int(crown_band * height), 1)), slice(None))
    crown_labels = set(np.unique(labels[band][opened[band]]).tolist()) & set(big.tolist())
    if not crown_labels:
        # No head top in view (e.g. a cropped bust): take the largest masses.
        crown_labels = set(big.tolist())
    keep = np.isin(labels, list(crown_labels))
    # Big masses near the crown hair: hair falling past the face or over a shoulder, and the locks
    # hanging behind the body that an arm separates from the crown. Dark clothing never qualifies
    # (it fails the hair colour test), and the mass must start in the upper body.
    distance = ndimage.distance_transform_edt(~keep)
    boxes = ndimage.find_objects(labels)
    upper_limit = top + 0.6 * height if crown_side == "top" else None
    for lab in big:
        if lab in crown_labels:
            continue
        ys_box = boxes[lab - 1][0]
        if upper_limit is not None and ys_box.start > upper_limit:
            continue
        if distance[labels == lab].min() <= near_px:
            keep |= labels == lab
    # Grow back fine strands, the outline of the hair and lighter highlights.
    mask = ndimage.binary_dilation(keep, iterations=open_radius) & core
    mask = ndimage.binary_dilation(mask, structure, iterations=grow, mask=loose | mask)
    mask = ndimage.binary_fill_holes(mask) & (loose | core)
    soft = ndimage.gaussian_filter(mask.astype(np.float32), 0.8)
    return np.clip(np.maximum(soft, mask * 0.85), 0.0, 1.0) * np.clip(alpha * 1.5, 0.0, 1.0)


def save_mask(mask: np.ndarray, path: str) -> Image.Image:
    image = Image.fromarray((mask * 255.0).round().astype(np.uint8), "L")
    image.save(path, optimize=True)
    return image


def luminance_range(rgba: np.ndarray, mask: np.ndarray) -> list[float]:
    """5th..95th percentile of hair luminance (0..1), so the shader can map the painted shading."""
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    lum = rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114
    sel = lum[mask > 0.5]
    if sel.size < 10:
        return [0.05, 0.45]
    return [round(float(np.percentile(sel, 5)), 4), round(float(np.percentile(sel, 95)), 4)]


def overlay(rgba: np.ndarray, mask: np.ndarray, colour=(255, 0, 200)) -> Image.Image:
    """Review image: the painting with the mask tinted."""
    out = rgba.astype(np.float32).copy()
    m = mask[..., None] * 0.65
    out[..., :3] = out[..., :3] * (1 - m) + np.array(colour, np.float32) * m
    bg = np.zeros_like(out)
    bg[..., :3] = (40, 18, 52)
    bg[..., 3] = 255
    a = out[..., 3:4] / 255.0
    bg[..., :3] = bg[..., :3] * (1 - a) + out[..., :3] * a
    return Image.fromarray(bg.round().clip(0, 255).astype(np.uint8), "RGBA")
