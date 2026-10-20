"""시범 2차 E단계 — 몸통(가슴) 기준점 추출. 머리와 같은 방식(템플릿 전수 탐색)이며 템플릿은 대기 0번의 가슴판"""
import sys, os, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *
import p2_anchors as A

BOX = (62, 77, 97, 109)      # 가슴판 (대기 0번)


def template():
    fr, _ = load_frames(KEY, "idle")
    x0, y0, x1, y1 = BOX
    crop = fr[0][y0:y1, x0:x1].copy()
    m = crop[..., 3] > 100
    crop[~m] = 0
    return crop, m


def run(headrows=None):
    t, m = template()
    out = {"box": list(BOX), "center": [(BOX[0] + BOX[2]) / 2.0, (BOX[1] + BOX[3]) / 2.0], "sheets": {}}
    A.SCALES = [0.7, 0.78, 0.86, 0.93, 1.0, 1.08, 1.16, 1.26]
    A.ROTS = [-24, -16, -8, 0, 8, 16, 24]
    for kind in KINDS:
        fr, sh = load_frames(KEY, kind)
        rows = []
        prev = None
        for i in range(len(fr)):
            usep = prev is not None and prev["tvis"] != "lost"
            b = A.match_frame(fr[i], t, m, prior=(prev["cx"], prev["cy"]) if usep else None, radius=14 if usep else None)
            b["tvis"] = "ok" if b["err"] < 32 else ("weak" if b["err"] < 45 else "lost")
            rows.append(b); prev = b
        out["sheets"][kind] = rows
        print(kind, "".join({"ok": "o", "weak": "w", "lost": "X"}[r["tvis"]] for r in rows), [round(r["err"]) for r in rows])
    return out


if __name__ == "__main__":
    o = run()
    json.dump(o, open(os.path.join(os.environ["P2_WORK"], "torso_raw.json"), "w"), indent=1, default=float)
