"""기준점 추출 정확도 검증 — 정답을 아는 합성 시험
 대기 프레임을 임의로 이동·확대·회전하고 잡음을 더한 뒤 추출기가 되찾는 오차를 잰다 (정답: 이동량)"""
import sys, os, json, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *
import p2_anchors as A

rng = np.random.default_rng(7)
fr, sh = load_frames(KEY, "idle")
tm = A.make_templates()[:1]
errs = []; serr = []; rerr = []
for t in range(48):
    base = Image.fromarray(fr[int(rng.integers(0, 12))])
    s = float(rng.uniform(0.85, 1.2)); r = float(rng.uniform(-14, 14))
    dx, dy = float(rng.uniform(-12, 12)), float(rng.uniform(-10, 10))
    W, H = base.size
    c = np.array([73.5, 50.5])    # 머리 중심 (대기 0번 기준; 다른 프레임은 몸이 흔들려서 정답이 조금 다름 → 프레임 자체의 추출값을 기준으로 삼음)
    # 기준: 변형 안 한 같은 프레임의 추출값
    ref = A.match_frame(np.array(base), *tm[0])
    # 변형: 머리 중심을 축으로 확대·회전한 뒤 이동
    big = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0)); big.paste(base, (W // 2, H // 2))
    cx, cy = ref["cx"] + W // 2, ref["cy"] + H // 2
    im2 = big.rotate(r, Image.BILINEAR, center=(cx, cy))
    nw, nh = int(big.width * s), int(big.height * s)
    im2 = im2.resize((nw, nh), Image.BILINEAR)
    ncx, ncy = cx * s, cy * s
    ox, oy = int(round(W / 2 + dx - (ncx - W / 2) + (ncx - W / 2) - 0)), 0
    # 새 프레임 W×H 에서 머리 중심이 (ref+delta) 에 오도록 잘라 낸다
    tx, ty = ref["cx"] + dx, ref["cy"] + dy
    left, top = int(round(ncx - tx)), int(round(ncy - ty))
    out = im2.crop((left, top, left + W, top + H))
    a = np.array(out).astype(np.float32)
    a[..., :3] += rng.normal(0, 4, a[..., :3].shape)      # 잡음
    a = np.clip(a, 0, 255).astype(np.uint8)
    res = A.match_frame(a, *tm[0])
    errs.append(math.hypot(res["cx"] - tx, res["cy"] - ty))
    serr.append(res["s"] / (s * ref["s"]) - 1.0)
    rerr.append(res["r"] - r)
errs = np.array(errs)
print("위치 오차(시트 픽셀): 평균 %.2f  중앙 %.2f  90%% %.2f  최대 %.2f" % (errs.mean(), np.median(errs), np.percentile(errs, 90), errs.max()))
print("크기 오차: 평균절대 %.1f%%  최대 %.1f%%" % (100 * np.abs(serr).mean(), 100 * np.abs(serr).max()))
print("기울기 오차(도): 평균절대 %.1f  최대 %.1f" % (np.abs(rerr).mean(), np.abs(rerr).max()))
json.dump({"pos_mean": errs.mean(), "pos_median": float(np.median(errs)), "pos_p90": float(np.percentile(errs, 90)), "pos_max": errs.max(),
           "scale_mae": float(np.abs(serr).mean()), "rot_mae": float(np.abs(rerr).mean()), "n": len(errs)},
          open(os.path.join(os.environ["P2_WORK"], "synthetic_test.json"), "w"))
