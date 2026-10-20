"""기준점 상자 사진 — 프레임마다 머리 상자(위치·크기·기울기)를 그려서 정확도를 눈으로 확인"""
import sys, os, json, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *


def box_poly(a, box_w=47, box_h=53):
    cx, cy = a.get("fx", a.get("x", a.get("cx"))), a.get("fy", a.get("y", a.get("cy")))
    s, r = a["s"], math.radians(a["r"])
    pts = []
    for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = dx * box_w * s / 2, dy * box_h * s / 2
        # PIL rotate(r) 은 반시계 — 화면 좌표(y 아래)에서 반시계는 부호 반대
        xr = x * math.cos(r) + y * math.sin(r); yr = -x * math.sin(r) + y * math.cos(r)
        pts.append((cx + xr, cy + yr))
    return pts


def draw_sheet(anch, kind, z=3, cols=7, path=None):
    fr, sh = load_frames(KEY, kind)
    n = len(fr); w = sh["w"]
    rows = (n + cols - 1) // cols
    sheet = Image.new("RGBA", (w * z * cols, 160 * z * rows), (70, 70, 80, 255))
    d = ImageDraw.Draw(sheet)
    for i in range(n):
        ox, oy = (i % cols) * w * z, (i // cols) * 160 * z
        bg = Image.new("RGBA", (w, 160), (120, 120, 130, 255)); bg.alpha_composite(Image.fromarray(fr[i]))
        sheet.alpha_composite(bg.resize((w * z, 160 * z), Image.NEAREST), (ox, oy))
        sk = anch["sheets"][kind]
        a = (sk["head"] if isinstance(sk, dict) else sk)[i]
        ta = sk["torso"][i] if isinstance(sk, dict) else None
        col = {"ok": (0, 255, 0, 255), "weak": (255, 220, 0, 255), "lost": (255, 0, 0, 255)}[a["vis"]]
        if ta is not None:
            tcol = (60, 140, 255, 255) if ta["vis"] in ("ok", "weak") else (200, 80, 255, 255)
            tp = [(ox + x * z, oy + y * z) for x, y in box_poly({"x": ta["x"], "y": ta["y"], "s": ta["s"], "r": 0}, 35, 55)]
            d.line(tp + [tp[0]], fill=tcol, width=1)
        pts = [(ox + x * z, oy + y * z) for x, y in box_poly(a)]
        d.line(pts + [pts[0]], fill=col, width=2)
        if a.get("skin_est"):
            sx, sy = a["skin_est"]
            d.line([(ox + sx * z - 5, oy + sy * z), (ox + sx * z + 5, oy + sy * z)], fill=(0, 200, 255, 255))
            d.line([(ox + sx * z, oy + sy * z - 5), (ox + sx * z, oy + sy * z + 5)], fill=(0, 200, 255, 255))
        d.text((ox + 4, oy + 4), f"{kind} f{i}  err {a['err']:.0f}  {a['vis']}", fill=(255, 255, 255, 255))
    if path:
        sheet.convert("RGB").save(path)
    return sheet


if __name__ == "__main__":
    anch = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    pre = sys.argv[3] if len(sys.argv) > 3 else "boxes_"
    for k in KINDS:
        draw_sheet(anch, k, path=os.path.join(out, f"{pre}{k}.png"), z=2)
