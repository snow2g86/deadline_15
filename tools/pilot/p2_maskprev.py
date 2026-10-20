import sys, os, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from p2_common import *
def prev(kind, idxs, out, z=2):
    fr, sh = load_frames(KEY, kind)
    m = np.array(Image.open(os.path.join(OUT, f"mask_{kind}.png")))
    w = sh["w"]
    tiles = []
    for i in idxs:
        f = fr[i].copy(); mm = m[:, i * w:(i + 1) * w]
        bg = np.zeros_like(f); bg[...] = (120, 120, 130, 255)
        base = bg.copy(); a = f[..., 3:4] > 100; base[:, :, :3] = np.where(a, f[..., :3], bg[..., :3])
        o = base.astype(np.float32)
        g = mm[..., 1] > 0; b = mm[..., 2] > 0
        o[g, 0] = o[g, 0] * 0.4 + 255 * 0.6
        o[b, 2] = o[b, 2] * 0.4 + 255 * 0.6
        tiles.append(np.concatenate([base, o.astype(np.uint8)], 0))
    im = Image.fromarray(np.concatenate(tiles, 1)); im = im.resize((im.width * z, im.height * z), Image.NEAREST); im.save(out)
if __name__ == "__main__":
    W = os.environ["P2_WORK"]
    prev("idle", [0, 4, 8], W + "/mp_idle.png"); prev("run", [2, 5, 9, 11], W + "/mp_run.png"); prev("attack", [0, 3, 6, 10, 13], W + "/mp_att.png")
