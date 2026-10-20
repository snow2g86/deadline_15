"""시범 2차 C단계 — 지금 캐릭터 그림에서 머리를 잘라 기사 동작 시트와 같은 크기의 조각으로 만들기
 크기: 그림(962x1087) → 동작 시트 픽셀 배율 = (50/(발끝-머리끝)) / 기사 시트 배율 ... 로 실제 게임 안의 상대 크기를 보존한 뒤, 머리 폭을 TARGET_W 근처로 맞춤
 영역 마스크(R): 3=피부 6=머리카락/두건 0=그대로(눈·윤곽선 등)"""
import os, sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *

CH = GODOT + "/assets/image/character/"
# id: (그림, 자를 상자 x0 y0 x1 y1 (원본 그림 좌표), 목표 폭(시트 픽셀), 이름)
HEADS = {
    "mage":     ("mage_01",     (225, 85, 605, 472), 54, "노인 마법사 (흰 머리·수염)"),
    "archer":   ("archer_02",   (190, 65, 595, 470), 56, "엘프 궁수 (금발 장발)"),
    "priest":   ("priest_02",   (165, 35, 565, 452), 56, "사제 (금발 풍성)"),
    "assassin": ("assassin_01", (335, 115, 705, 485), 50, "암살자 (두건)"),
    "brawler":  ("brawler_01",  (340, 112, 645, 442), 46, "무투가 (민머리)"),
    "lancer":   ("lancer_02",   (150, 108, 612, 516), 58, "창병 (붉은 말총머리)"),
    "dancer":   ("brawler_02",  (340, 125, 655, 482), 48, "무투가 여 (검은 긴머리)"),
    "novice":   ("novice_01",   (320, 52, 762, 490), 58, "수련생 (뾰족한 갈색 머리)"),
}
# 머리 위 장식 (투구·모자) — 머리 조각 위에 얹는 별도 조각. 마스크는 전부 머리카락(240) 자리로 두어 색 바꾸기에 쓰임
HATS = {
    "hardhat": ("sapper_02", (150, 50, 552, 302), 58, "공병 안전모"),
}
KNIGHT_FACE_CENTER = (73.5, 50.5)    # 앵커(투구 상자 중심)


def build_head(hid):
    src, box, tw, name = HEADS[hid]
    im = Image.open(CH + src + ".png").convert("RGBA").crop(box)
    k = tw / im.width
    w, h = int(round(im.width * k)), int(round(im.height * k))
    im = im.resize((w, h), Image.LANCZOS)
    a = np.array(im)
    # 가장자리 반투명 정리 — 동작 시트처럼 단단한 가장자리
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    a[a[..., 3] == 0] = 0
    # 마스크
    cls = classify(a)
    hh, ss, vv = hsv(a[..., :3])
    fg = a[..., 3] > 0
    # 피부(주황, 색상 5~33)와 금발(색상 36 이상 노랑)을 가르기 위해 머리 조각 전용 규칙으로 다시 분류
    skin2 = fg & (hh >= 5) & (hh < 34) & (ss > 0.22) & (vv > 0.5)
    cls = np.where(fg, np.where(skin2, SKIN, np.where(vv < 0.2, DARK, METAL)), BG).astype(np.uint8)
    # 머리카락: 피부·어두운 윤곽 이외 색 덩어리 중 큰 것 (눈 흰자 같은 작은 조각은 제외)
    other = (cls != BG) & (cls != SKIN) & (cls != DARK)
    lab, n = ndi.label(other)
    mask = np.zeros(a.shape[:2], np.uint8)
    mask[cls == SKIN] = 3
    if n:
        sizes = ndi.sum(other, lab, range(1, n + 1))
        keep = [i + 1 for i, s_ in enumerate(sizes) if s_ >= 0.04 * (a[..., 3] > 0).sum()]
        mask[np.isin(lab, keep)] = 6
    # 목: 턱 아랫선(가장 아래) 근처가 잘려 있으면 아래 2줄을 피부색으로 늘려 몸 목가리개와 이어지게 하지는 않음 (몸 쪽 목가리개가 있음)
    return a, mask, {"name": name, "w": w, "h": h, "k": k, "src": src, "box": list(box)}


def build_hat(hid):
    src, box, tw, name = HATS[hid]
    im = Image.open(CH + src + ".png").convert("RGBA").crop(box)
    k = tw / im.width
    im = im.resize((int(round(im.width * k)), int(round(im.height * k))), Image.LANCZOS)
    a = np.array(im); a[..., 3] = np.where(a[..., 3] > 110, 255, 0); a[a[..., 3] == 0] = 0
    mask = np.where(a[..., 3] > 0, 6, 0).astype(np.uint8)
    return a, mask, {"name": name, "w": a.shape[1], "h": a.shape[0]}


def build_all(outdir):
    os.makedirs(outdir, exist_ok=True)
    meta = {}
    for hid in HEADS:
        a, mask, m = build_head(hid)
        Image.fromarray(a).save(os.path.join(outdir, f"head_{hid}.png"), optimize=True)
        mi = np.zeros(a.shape[:2] + (4,), np.uint8)
        mi[..., 0] = mask * 40; mi[..., 3] = 255
        Image.fromarray(mi).save(os.path.join(outdir, f"head_{hid}_m.png"), optimize=True)
        # 기준 명도 (색 바꾸기에서 명도를 보존하며 곱할 때 나눌 값)
        lum = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255.0
        m["hair_lum"] = float(np.median(lum[mask == 6])) if (mask == 6).any() else 0.5
        m["skin_lum"] = float(np.median(lum[mask == 3])) if (mask == 3).any() else 0.7
        m["hair_px"] = int((mask == 6).sum()); m["skin_px"] = int((mask == 3).sum())
        meta[hid] = m
    for hid in HATS:
        a, mask, m = build_hat(hid)
        Image.fromarray(a).save(os.path.join(outdir, f"hat_{hid}.png"), optimize=True)
        mi = np.zeros(a.shape[:2] + (4,), np.uint8); mi[..., 0] = mask * 40; mi[..., 3] = 255
        Image.fromarray(mi).save(os.path.join(outdir, f"hat_{hid}_m.png"), optimize=True)
        lum = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255.0
        m["ref_lum"] = float(np.median(lum[mask == 6]))
        meta["hat_" + hid] = m
    return meta


if __name__ == "__main__":
    out = sys.argv[1]
    meta = build_all(out)
    print(json.dumps(meta, ensure_ascii=False, indent=1))
    # 미리보기
    ims = []
    for hid in HEADS:
        a = np.array(Image.open(os.path.join(out, f"head_{hid}.png"))); m = np.array(Image.open(os.path.join(out, f"head_{hid}_m.png")))[..., 0]
        vis = a.copy(); vis[m == 240] = [255, 0, 255, 255]; vis[m == 120] = [0, 255, 0, 255]
        ims.append(np.concatenate([a, vis], 0))
    H = max(i.shape[0] for i in ims)
    row = Image.new("RGBA", (sum(i.shape[1] for i in ims) + 10 * len(ims), H), (120, 120, 130, 255)); x = 0
    for i in ims:
        row.alpha_composite(Image.fromarray(i), (x, 0)); x += i.shape[1] + 10
    row = row.resize((row.width * 4, row.height * 4), Image.NEAREST); row.save(os.environ["P2_WORK"] + "/heads_prev.png")
