"""시범 2차 공용 — 동작 시트 불러오기, 색 분류 (기사 knight_02)"""
import json, os
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.path.join(ROOT, "godot")
SPR = json.load(open(os.path.join(GODOT, "data", "sprites.json")))
OUT = os.path.join(GODOT, "assets", "pilot", "knight2")
KEY = "knight_02"
KINDS = ["idle", "combat", "run", "attack", "hit"]


def sheet_info(key, kind):
    return SPR["SPRITE_SHEETS"][key][kind]


def load_frames(key, kind):
    """-> (RGBA uint8 배열 [n,160,w,4], info)"""
    sh = sheet_info(key, kind)
    im = np.array(Image.open(os.path.join(GODOT, "assets", sh["src"])).convert("RGBA"))
    w, n = sh["w"], sh["frames"]
    return np.stack([im[:, i * w:(i + 1) * w] for i in range(n)]), sh


def hsv(rgb):
    """rgb uint8 [...,3] -> h(0..360), s, v"""
    x = rgb.astype(np.float32) / 255.0
    mx = x.max(-1); mn = x.min(-1); d = mx - mn
    r, g, b = x[..., 0], x[..., 1], x[..., 2]
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = m & (mx == r); gc = m & (mx == g) & ~rc; bc = m & ~rc & ~gc
    h[rc] = ((g - b)[rc] / d[rc]) % 6
    h[gc] = (b - r)[gc] / d[gc] + 2
    h[bc] = (r - g)[bc] / d[bc] + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h * 60.0, s, mx


# 영역 번호
BG, METAL, RED, SKIN, LEATHER, DARK = 0, 1, 2, 3, 4, 5


def classify(rgba):
    """프레임 [...,4] -> 영역 번호 배열"""
    h, s, v = hsv(rgba[..., :3])
    a = rgba[..., 3] > 100
    cls = np.full(a.shape, METAL, np.uint8)
    red = ((h < 14) | (h > 335)) & (s > 0.38) & (v > 0.18)
    skin = (h >= 8) & (h < 48) & (s > 0.32) & (v > 0.55)
    leather = (h >= 8) & (h < 55) & (s > 0.25) & (v <= 0.55) & (v > 0.12)
    dark = v < 0.22
    cls[dark] = DARK
    cls[leather] = LEATHER
    cls[red] = RED
    cls[skin & ~red] = SKIN
    cls[~a] = BG
    return cls


PAL = np.array([[0, 0, 0, 0], [150, 150, 170, 255], [220, 30, 30, 255], [255, 190, 120, 255],
                [130, 80, 40, 255], [30, 30, 30, 255]], np.uint8)
