"""시범 2차 — 에셋 한 번에 만들기
   입력: 기사 동작 시트(원본 그대로) + 다른 캐릭터 그림
   출력(godot/assets/pilot/knight2/): anchors.json, mask_<동작>.png, head_*.png(+_m), cos_*.png, parts.json
"""
import os, sys, json, math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *
import p2_anchors as A
import p2_heads as H

OUTD = OUT
TORSO_BOX = (62, 77, 97, 132)                 # 대기 0번의 가슴판 + 앞치마
TORSO_CENTER = ((62 + 97) / 2.0, (77 + 132) / 2.0)
HEAD_TO_TORSO = (TORSO_CENTER[0] - A.T_CENTER[0], TORSO_CENTER[1] - A.T_CENTER[1])   # 머리 중심 → 몸통 중심 (크기 1)

# 머리 지우는 영역 (템플릿 좌표) — 투구 윤곽 바깥을 조금 넉넉히, 왼쪽 아래 어깨는 남김
ERASE_POLY = [(45, 17), (101, 17), (101, 79), (61, 79), (59, 63), (45, 60)]

# 의상(몸통 조각): id → (그림, 상자, 이름)
COSTUMES = {
    "robe":   ("mage_01",     (290, 610, 510, 950), "마법사 로브(띠)"),
    "tunic":  ("archer_02",   (330, 520, 560, 860), "궁수 가죽 튜닉"),
    "tabard": ("priest_02",   (340, 500, 560, 840), "사제 흰 예복(금띠)"),
    "wrap":   ("assassin_01", (330, 500, 550, 840), "암살자 검은 겉옷"),
    "gi":     ("brawler_01",  (380, 470, 600, 810), "무투가 주황 도복"),
}
COS_W, COS_H = 40, 62


def lum(a):
    return (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255.0


def affine_pts(poly, c0, s, rot_deg, c1):
    r = math.radians(rot_deg)
    out = []
    for x, y in poly:
        x -= c0[0]; y -= c0[1]
        x *= s; y *= s
        xr = x * math.cos(r) + y * math.sin(r); yr = -x * math.sin(r) + y * math.cos(r)
        out.append((c1[0] + xr, c1[1] + yr))
    return out


def raster(poly, W, Hh):
    im = Image.new("L", (W, Hh), 0)
    ImageDraw.Draw(im).polygon(poly, fill=255)
    return np.array(im) > 0


def head_pass():
    data = A.run()
    for kind, rows in data["sheets"].items():
        for r in rows:
            if r["vis"] == "ok" and abs(r["r"]) <= 8:
                r["r"] = 0
        # 틈 메우기: 잃은 프레임이 최대 2칸이고 앞뒤가 믿을 만하며 그 위치가 앞뒤 사이 직선에서 8px 이내면 약함(weak)으로 되살림
        n = len(rows)
        for i, r in enumerate(rows):
            if r["vis"] != "lost" or r["err"] >= 60:
                continue
            a = i - 1
            while a >= 0 and rows[a]["vis"] == "lost" and i - a <= 2: a -= 1
            b = i + 1
            while b < n and rows[b]["vis"] == "lost" and b - i <= 2: b += 1
            if a < 0 or b >= n or rows[a]["vis"] == "lost" or rows[b]["vis"] == "lost" or b - a > 3:
                continue
            t = (i - a) / float(b - a)
            ex = rows[a]["fx"] * (1 - t) + rows[b]["fx"] * t; ey = rows[a]["fy"] * (1 - t) + rows[b]["fy"] * t
            if abs(r["fx"] - ex) <= 8 and abs(r["fy"] - ey) <= 8:
                r["vis"] = "weak"; r["gapfill"] = True
    return data


def torso_pass(data):
    fr0, _ = load_frames(KEY, "idle")
    x0, y0, x1, y1 = TORSO_BOX
    crop = fr0[0][y0:y1, x0:x1].copy(); m0 = crop[..., 3] > 100; crop[~m0] = 0
    res = {}
    A.SCALES = [0.9, 1.0, 1.1]
    A.ROTS = [0]
    for kind in KINDS:
        fr, sh = load_frames(KEY, kind)
        rows = []
        for i in range(len(fr)):
            h = data["sheets"][kind][i]
            if h["vis"] == "lost":
                rows.append({"vis": "lost"}); continue
            s0 = h["s"]
            px = h["fx"] + HEAD_TO_TORSO[0] * s0; py = h["fy"] + HEAD_TO_TORSO[1] * s0
            best = None
            for k in (0.92, 1.0, 1.08):
                A.SCALES = [s0 * k]
                b = A.match_frame(fr[i], crop, m0, prior=(px, py), radius=5)
                if best is None or b["err"] < best["err"]:
                    best = b
            vis = "ok" if best["err"] < 34 else ("weak" if best["err"] < 48 else "forced")
            if vis == "forced":
                best = {"cx": px, "cy": py, "s": s0, "err": best["err"]}
            rows.append({"cx": best["cx"], "cy": best["cy"], "s": best["s"], "err": best["err"], "vis": vis,
                         "pred": [px, py]})
        res[kind] = rows
    return res, crop, m0


def make_masks(data, torso, tcrop, tm0):
    """영역 번호(R) · 머리 지움(G) · 몸통 덮기(B)"""
    stats = {}
    for kind in KINDS:
        fr, sh = load_frames(KEY, kind)
        n, Hh, W = fr.shape[0], fr.shape[1], fr.shape[2]
        sheet = np.zeros((Hh, W * n, 4), np.uint8)
        for i in range(n):
            f = fr[i]
            cls = classify(f)
            g = np.zeros((Hh, W), bool); b = np.zeros((Hh, W), bool)
            h = data["sheets"][kind][i]
            if h["vis"] != "lost":
                s, r = h["s"], h["r"]
                poly = affine_pts(ERASE_POLY, A.T_CENTER, s, r, (h["fx"], h["fy"]))
                anyp = f[..., 3] > 0                       # 반투명 가장자리 픽셀까지 포함 (그렇지 않으면 깃털 끝 부스러기가 남음)
                g = raster(poly, W, Hh) & anyp
                # 깃털: 투구 상자 왼쪽·위의 빨강(+윤곽) 덩어리
                yy, xx = np.mgrid[0:Hh, 0:W]
                rx, ry = (xx - h["fx"]) / s, (yy - h["fy"]) / s
                plume_box = (rx > -52) & (rx < 24) & (ry > -52) & (ry < 8)
                red = (cls == RED) & plume_box
                near = ndi.binary_dilation(red, iterations=3) & plume_box & anyp & ~((cls == METAL) & (f[..., 3] >= 200))
                g |= near
            t = torso[kind][i]
            if t["vis"] in ("ok", "weak"):   # forced(예측 위치만 믿는 칸)는 방패·다리 위에 얹혀서 시험 결과 쓰지 않기로 함
                s = t["s"]
                th, tw = tcrop.shape[:2]
                tt = Image.fromarray(tcrop[..., :3]).resize((max(4, int(round(tw * s))), max(4, int(round(th * s)))), Image.BILINEAR)
                tmm = Image.fromarray((tm0 * 255).astype(np.uint8)).resize(tt.size, Image.BILINEAR)
                T = np.array(tt).astype(np.int16); M = np.array(tmm) > 128
                ox = int(round(t["cx"] - tt.width / 2.0)); oy = int(round(t["cy"] - tt.height / 2.0))
                canvas = np.zeros((Hh, W), bool); diff = np.zeros((Hh, W), np.int16)
                xa, ya = max(0, ox), max(0, oy); xb, yb = min(W, ox + tt.width), min(Hh, oy + tt.height)
                if xb > xa and yb > ya:
                    sub = (slice(ya - oy, yb - oy), slice(xa - ox, xb - ox))
                    canvas[ya:yb, xa:xb] = M[sub]
                    diff[ya:yb, xa:xb] = np.abs(f[ya:yb, xa:xb, :3].astype(np.int16) - T[sub]).sum(-1)
                occ = ndi.uniform_filter(diff.astype(np.float32), 3) > 120
                if t["vis"] == "forced":
                    occ = np.zeros_like(occ)      # 모양이 안 맞으니 차이로 가림을 가릴 수 없음 — 상자 전체를 덮되 안쪽만
                    canvas = ndi.binary_erosion(canvas, iterations=2)
                lab, nn = ndi.label(occ)
                if nn:
                    sizes = ndi.sum(occ, lab, range(1, nn + 1))
                    occ = np.isin(lab, [j + 1 for j, z in enumerate(sizes) if z >= 14])
                occ = ndi.binary_dilation(occ, iterations=1)
                b = canvas & (cls != BG) & ~occ & ~g
                b = ndi.binary_opening(b, iterations=1)
            blk = sheet[:, i * W:(i + 1) * W]
            blk[..., 0] = cls * 40; blk[..., 1] = g * 255; blk[..., 2] = b * 255; blk[..., 3] = 255
        Image.fromarray(sheet).save(os.path.join(OUTD, f"mask_{kind}.png"), optimize=True)


def build_costumes():
    meta = {}
    for cid, (src, box, name) in COSTUMES.items():
        im = Image.open(H.CH + src + ".png").convert("RGBA").crop(box).resize((COS_W, COS_H), Image.LANCZOS)
        a = np.array(im); a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        Image.fromarray(a).save(os.path.join(OUTD, f"cos_{cid}.png"), optimize=True)
        meta[cid] = {"name": name, "w": COS_W, "h": COS_H}
    return meta


def main():
    os.makedirs(OUTD, exist_ok=True)
    data = head_pass()
    torso, tcrop, tm0 = torso_pass(data)
    for kind in KINDS:
        print("torso", kind, "".join({"ok": "o", "weak": "w", "lost": "X", "forced": "f"}[r["vis"]] for r in torso[kind]))
    make_masks(data, torso, tcrop, tm0)
    hm = H.build_all(OUTD)
    cm = build_costumes()
    # 시트 정보(게임의 시트 설명 그대로) + 앵커
    anchors = {"template": data["template"], "torso_box": list(TORSO_BOX), "torso_center": list(TORSO_CENTER), "sheets": {}}
    for kind in KINDS:
        sh = sheet_info(KEY, kind)
        hr = []
        for r in data["sheets"][kind]:
            hr.append({"x": round(r["fx"], 2), "y": round(r["fy"], 2), "s": round(r["s"], 3), "r": r["r"], "vis": r["vis"], "err": round(r["err"], 1), "skin": r["skin_n"]})
        tr = []
        last = [TORSO_CENTER[0], TORSO_CENTER[1], 1.0]
        for i, r in enumerate(torso[kind]):
            hh = data["sheets"][kind][i]
            if r["vis"] != "lost":
                last = [r["cx"], r["cy"], r["s"]]
                tr.append({"x": round(r["cx"], 2), "y": round(r["cy"], 2), "s": round(r["s"], 3), "vis": r["vis"], "err": round(r["err"], 1)})
            else:
                if hh["vis"] != "lost":
                    last = [hh["fx"] + HEAD_TO_TORSO[0] * hh["s"], hh["fy"] + HEAD_TO_TORSO[1] * hh["s"], hh["s"]]
                tr.append({"x": round(last[0], 2), "y": round(last[1], 2), "s": round(last[2], 3), "vis": "lost"})
        anchors["sheets"][kind] = {"frames": sh["frames"], "w": sh["w"], "h": sh["h"], "head": hr, "torso": tr}
    json.dump(anchors, open(os.path.join(OUTD, "anchors.json"), "w"), indent=1)
    # 클래스별 기준 명도 (색 바꾸기: 명도 보존 곱셈에 사용)
    ref = {}
    acc = {c: [] for c in (METAL, RED, SKIN, LEATHER)}
    for kind in KINDS:
        fr, _ = load_frames(KEY, kind)
        for i in range(len(fr)):
            c = classify(fr[i]); L = lum(fr[i])
            for k in acc:
                v = L[c == k]
                if v.size: acc[k].append(np.median(v))
    ref = {"metal": float(np.mean(acc[METAL])), "red": float(np.mean(acc[RED])), "skin": float(np.mean(acc[SKIN])), "leather": float(np.mean(acc[LEATHER]))}
    json.dump({"heads": hm, "costumes": cm, "class_ref_lum": ref, "erase_poly": ERASE_POLY, "head_center": list(A.T_CENTER)},
              open(os.path.join(OUTD, "parts.json"), "w"), ensure_ascii=False, indent=1)
    print("done", ref)


if __name__ == "__main__":
    main()
