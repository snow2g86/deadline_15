"""시범 2차 A단계 — 동작 시트 모든 프레임에서 머리 기준점(위치·크기·기울기) 자동 추출
 방법: 첫 대기 프레임의 투구(깃털 제외) 조각을 템플릿으로, 프레임마다 (크기 × 기울기 × 위치) 전수 탐색.
       점수 = 마스크 안 RGB 평균제곱오차(작을수록 좋음)  →  SSD 를 FFT 합성곱으로 계산.
 출력: godot/assets/pilot/knight2/anchors.json
"""
import json, sys, os, math
import numpy as np
from PIL import Image
from scipy.signal import fftconvolve
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *

# 첫 대기 프레임에서 정한 머리 템플릿 (투구 + 얼굴). 깃털은 흔들려서 뺌
T_POLY = [(50, 24), (96, 24), (96, 76), (62, 76), (62, 60), (50, 58)]
T_BOX = (50, 24, 97, 77)          # x0 y0 x1 y1
T_CENTER = ((50 + 97) / 2.0, (24 + 77) / 2.0)
SCALES = [0.70, 0.76, 0.82, 0.88, 0.94, 1.0, 1.07, 1.14, 1.22, 1.30]
ROTS = [-30, -22, -15, -8, 0, 8, 15, 22, 30]


# 키프레임 템플릿: (시트, 칸, 상자, 다각형(없으면 상자 전체), 크기 보정)
#  - 대기 0번: 정면 투구.  공격 13번: 오른쪽을 향해 돌아선 3/4 옆모습 (공격 끝 구간 10~13) — 상자는 눈대중, 크기 0.85 로 가정
KEYFRAMES = [("idle", 0, T_BOX, T_POLY, 1.0), ("attack", 13, (101, 60, 142, 99), None, 0.85)]


def make_templates():
    from PIL import ImageDraw
    out = []
    for kind, idx, box, poly_pts, k in KEYFRAMES:
        fr, _ = load_frames(KEY, kind)
        x0, y0, x1, y1 = box
        crop = fr[idx][y0:y1, x0:x1].copy()
        poly = Image.new("L", (x1 - x0, y1 - y0), 255 if poly_pts is None else 0)
        if poly_pts is not None:
            ImageDraw.Draw(poly).polygon([(x - x0, y - y0) for x, y in poly_pts], fill=255)
        m = (np.array(poly) > 0) & (crop[..., 3] > 100) & (classify(crop) != RED)
        crop[~m] = 0
        if k != 1.0:
            im = Image.fromarray(crop); mk = Image.fromarray((m * 255).astype(np.uint8))
            nw, nh = int(round(im.width / k)), int(round(im.height / k))
            crop = np.array(im.resize((nw, nh), Image.BILINEAR)); m = np.array(mk.resize((nw, nh), Image.BILINEAR)) > 160
        out.append((crop, m))
    return out


def make_template():
    return make_templates()[0]


def warp_template(crop, m, s, r):
    rgb = Image.fromarray(crop[..., :3])
    mk = Image.fromarray((m * 255).astype(np.uint8))
    w, h = rgb.size
    nw, nh = max(4, int(round(w * s))), max(4, int(round(h * s)))
    rgb = rgb.resize((nw, nh), Image.BILINEAR); mk = mk.resize((nw, nh), Image.BILINEAR)
    rgb = rgb.rotate(r, Image.BILINEAR, expand=True); mk = mk.rotate(r, Image.BILINEAR, expand=True)
    return np.array(rgb).astype(np.float32), (np.array(mk) > 160)


def match_frame(frame, tmpl, tm, prior=None, radius=None):
    """frame RGBA [160,w,4] -> 최적 {cx,cy,s,r,err}"""
    a = (frame[..., 3] > 100).astype(np.float32)
    I = frame[..., :3].astype(np.float32) * a[..., None]
    H, W = a.shape
    best = None
    for s in SCALES:
        for r in ROTS:
            T, M = warp_template(tmpl, tm, s, r)
            Mf = M.astype(np.float32)
            n = Mf.sum()
            if n < 30:
                continue
            th, tw = M.shape
            # SSD(x,y) = sum M*(I-T)^2 = sum M*I^2 - 2 sum (M*T)*I + sum M*T^2
            ssd = np.zeros((H - th + 1, W - tw + 1), np.float32)
            for c in range(3):
                Ic = I[..., c]
                s1 = fftconvolve(Ic * Ic, Mf[::-1, ::-1], mode="valid")
                s2 = fftconvolve(Ic, (Mf * T[..., c])[::-1, ::-1], mode="valid")
                ssd += s1 - 2 * s2 + (Mf * T[..., c] ** 2).sum()
            # 틀 바깥(투명)과 겹치면 벌점: 마스크 안의 투명 칸 수
            cov = fftconvolve(a, Mf[::-1, ::-1], mode="valid")
            miss = (n - cov)
            err = np.sqrt(np.maximum(ssd, 0) / (3 * n)) + 255.0 * miss / n
            if prior is not None and radius is not None:
                yy, xx = np.mgrid[0:err.shape[0], 0:err.shape[1]]
                cxs = xx + tw / 2.0; cys = yy + th / 2.0
                err = err + 6.0 * np.maximum(0, np.hypot(cxs - prior[0], cys - prior[1]) - radius)
            iy, ix = np.unravel_index(np.argmin(err), err.shape)
            e = float(err[iy, ix])
            if best is None or e < best["err"]:
                best = {"cx": ix + tw / 2.0, "cy": iy + th / 2.0, "s": s, "r": r, "err": e}
    return best


def skin_centroid(frame, cx, cy, s):
    """독립 검산용 — 머리 구역 안 얼굴 살색 덩어리의 무게중심"""
    c = classify(frame)
    H, W = c.shape
    yy, xx = np.mgrid[0:H, 0:W]
    near = (np.abs(xx - cx) < 28 * s) & (np.abs(yy - cy) < 34 * s)
    sel = (c == SKIN) & near
    ys, xs = np.nonzero(sel)
    if len(xs) < 4:
        return None
    return float(xs.mean()), float(ys.mean()), int(len(xs))


# 템플릿 중심 → 얼굴 살색 중심의 위치 (첫 프레임 기준, 크기 1)
SKIN_OFF = None


def chained_template(frame, cx, cy, s):
    """이전 프레임에서 잘라 낸 머리 조각 (투구 폭·높이 × s) — 모양이 서서히 변하는 걸 따라가기 위함"""
    w = int(round((T_BOX[2] - T_BOX[0]) * s)); h = int(round((T_BOX[3] - T_BOX[1]) * s))
    x0 = int(round(cx - w / 2.0)); y0 = int(round(cy - h / 2.0))
    H, W = frame.shape[:2]
    crop = np.zeros((h, w, 4), np.uint8)
    xa, ya = max(0, x0), max(0, y0); xb, yb = min(W, x0 + w), min(H, y0 + h)
    crop[ya - y0:yb - y0, xa - x0:xb - x0] = frame[ya:yb, xa:xb]
    m = crop[..., 3] > 100
    m &= classify(crop) != RED
    return crop, m


def track_sheet(fr, tmpls):
    global SKIN_OFF
    rows = []
    prev = None
    for i in range(len(fr)):
        usep = prev is not None and prev["vis"] != "lost"
        cs = []
        for ti, (tmpl, tm) in enumerate(tmpls):
            b = match_frame(fr[i], tmpl, tm, prior=(prev["cx"], prev["cy"]) if usep else None, radius=12 if usep else None)
            b["src"] = "abs%d" % ti
            cs.append(b)
        a = min(cs, key=lambda q: q["err"])
        best = a
        if usep:
            # 이전 프레임 조각으로 따라가기 (크기 비율 0.9~1.1 은 템플릿 크기로 흉내)
            ct, cm = chained_template(fr[i - 1], prev["cx"], prev["cy"], 1.0)
            cands = []
            for sc in (0.92, 1.0, 1.08):
                global SCALES, ROTS
                sv, rv = SCALES, ROTS
                SCALES, ROTS = [sc], [0]
                b = match_frame(fr[i], ct, cm, prior=(prev["cx"], prev["cy"]), radius=10)
                SCALES, ROTS = sv, rv
                b["s"] = prev["s"] * sc; b["r"] = prev["r"]; b["src"] = "chain"
                cands.append(b)
            c = min(cands, key=lambda q: q["err"])
            # 이어 붙인 쪽이 오차가 작으면 그쪽 (조각이 최신이라 항상 작게 나오므로 4 더해 불리하게)
            if c["err"] + 4 < a["err"] and abs(c["cx"] - a["cx"]) + abs(c["cy"] - a["cy"]) < 18:
                best = c
        sk = skin_centroid(fr[i], best["cx"], best["cy"], best["s"])
        best["skin_n"] = sk[2] if sk else 0
        if sk:
            if SKIN_OFF is None and i == 0:
                SKIN_OFF = (sk[0] - best["cx"], sk[1] - best["cy"])
            best["skin_est"] = (sk[0] - SKIN_OFF[0] * best["s"], sk[1] - SKIN_OFF[1] * best["s"]) if SKIN_OFF else None
        else:
            best["skin_est"] = None
        best["vis"] = classify_vis(best)
        rows.append(best)
        prev = best
    return rows


def classify_vis(r):
    """ok: 템플릿이 잘 맞고 얼굴이 보임 / weak: 부분만 / lost: 머리가 가려졌거나 돌아서 믿을 수 없음"""
    if r["err"] < 38 and r["skin_n"] >= 40:
        return "ok"
    if (r["err"] < 50 and r["skin_n"] >= 20) or (r["err"] < 22 and r["skin_n"] >= 5):
        return "weak"
    return "lost"


def run():
    tmpls = make_templates()
    out = {"template": {"src_frame": "idle:0", "box": list(T_BOX), "center": list(T_CENTER), "poly": T_POLY}, "sheets": {}}
    for kind in KINDS:
        fr, sh = load_frames(KEY, kind)
        rows = track_sheet(fr, tmpls)
        for i, r in enumerate(rows):
            r["vis"] = classify_vis(r)
            # 얼굴 살색이 충분히 보이면 두 추정을 평균 (독립 신호 융합)
            if r["vis"] == "ok" and r["skin_est"]:
                r["fx"] = 0.5 * r["cx"] + 0.5 * r["skin_est"][0]
                r["fy"] = 0.5 * r["cy"] + 0.5 * r["skin_est"][1]
            else:
                r["fx"], r["fy"] = r["cx"], r["cy"]
        out["sheets"][kind] = rows
        print(kind, "".join({"ok": "o", "weak": "w", "lost": "X"}[r["vis"]] for r in rows),
              "max |tmpl-skin| =", round(max([max(abs(r["cx"] - r["skin_est"][0]), abs(r["cy"] - r["skin_est"][1])) for r in rows if r["skin_est"] and r["vis"] != "lost"] or [0]), 2))
    json.dump(out, open(os.path.join(os.environ["P2_WORK"], "anchors_raw.json"), "w"), indent=1, default=float)
    return out


if __name__ == "__main__":
    run()
