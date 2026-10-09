#!/usr/bin/env python3
"""개발용: 스토리 등장인물 초상화 프롬프트 (docs/CAST.md 의 특성을 그림으로)

사용: python3 tools/portrait-catalog.py  → 키와 프롬프트를 출력
그림 넣는 법: image/character/story/src/<키>.jpg 로 저장 → python3 tools/make-portrait.py
"""
# 게임의 다른 캐릭터 그림과 같은 픽셀 화풍 (큰 머리 · 작은 몸, 진한 외곽선), 전신, 오른쪽을 봄
STYLE = ('Pixel art fantasy RPG character sprite, 16-bit SNES style, cute chibi proportions about three heads tall, '
         'clean dark outlines, simple cel shading, full body standing pose, three-quarter view facing to the right, centered, '
         'isolated on a plain flat solid bright green chroma-key background (#00FF00), evenly lit, no vignette, no shadow on the ground, '
         'no scenery, no frame, no text, no letters, no watermark. Character: ')
MAGENTA_BG = {'boss_30'}   # 초록 이끼·독이 많은 인물은 자홍 바탕

BATON = ('one hand raised pointing forward while holding a tiny silver pointer stick about the length of a hand (the commander baton), '
         'the other hand holding a rolled battle map, unarmed, no sword, no spear, no blade')   # "baton"이라고 쓰면 칼·창으로 그려져서 이렇게 씀
CAST = [
 ('commander_m', 'a young male army commander and strategist, neat dark hair, confident calm eyes, a deep navy-blue military officer\'s tailcoat uniform '
                 'with gold epaulettes and gold buttons, a short dark cape, white gloves, ' + BATON),
 ('commander_f', 'a young alluring female army commander and strategist, long glossy black hair, confident seductive eyes, red lips, a fitted deep navy-blue '
                 'military officer\'s tailcoat uniform with gold epaulettes and gold buttons, a short dark cape, white gloves, ' + BATON),
 ('bram', 'a grizzled old knight in his sixties, short grey hair and a thick grey beard, an old scar across his cheek, '
          'worn but well-kept steel knight armor with a faded navy-blue royal knight tabard, a longsword at his side, no helmet, stern but warm eyes'),
 ('sera', 'a gentle young female healer, warm auburn hair in a side braid, kind face, white and gold priest robes, '
          'a bandage satchel across her shoulder, holding a small healing staff topped with a sun emblem'),
 ('bark', 'a big burly muscular former bandit brawler, short messy black hair and stubble, a scar across the bridge of his nose, '
          'a patched brown leather vest, fists wrapped in cloth, a big toothy cheerful grin'),
 ('kasha', 'a sharp confident female mercenary captain, high black ponytail with one red streak, a short black cloak trimmed with black feathers, '
           'dark leather armor, twin daggers in her hands, a smug smirk'),
 ('ordin', 'a tall elderly royal archmage, long swept-back silver hair and a neat silver beard, elegant purple and gold royal robes, '
           'a staff topped with a glowing blue crystal orb, a gentle smile with cold calculating eyes'),
 ('boss_10', 'a hulking bandit chief, an eye patch, a rough fur mantle over his shoulders, a huge battle axe, a cruel grin'),
 ('boss_20', 'a frozen undead royal knight, frost-covered blue steel knight armor with icicles, pale glowing icy blue eyes, an ice longsword, no helmet, a grim face'),
 ('boss_30', 'a swamp plague sorcerer lord covered in moss and vines, purple poisonous glowing hands, a staff topped with a skull, a hooded rotting robe'),
 ('boss_40', 'a tyrant fire emperor, a burning golden crown, crimson imperial robes with gold trim, flames blazing from his raised hand, an arrogant face'),
 ('boss_45', 'an abyssal knight made of living shadow, jet black armor, empty helmet with glowing violet eyes inside, a shadowy sword'),
 ('boss_50', 'a towering abyssal warrior, dark crimson armor, a horned helmet, a huge bloodstained greatsword'),
 ('boss_60', 'a giant gatekeeper knight of the hell gate, heavy armor wrapped in iron chains, a huge obsidian tower shield'),
 ('boss_70', 'a demon sorcerer of illusions, a purple demon wearing an ornate porcelain mask, purple illusion smoke rising from his hands'),
 ('boss_80', 'the same elderly royal archmage with silver hair and purple and gold robes, but half of his body is being swallowed and cracked apart by blinding white holy light, '
             'glowing white eyes, divine light rays'),
 ('boss_90', 'a war general demon giant in steel armor, tattered war banners strapped to his back, a massive war hammer'),
 ('boss_92', 'a noble demon knight who was once human, an old human knight armor with demon horns growing through the helmet, a longsword held in a formal knightly salute'),
 ('boss_93', 'a cold calculating demon magician, a monocle, floating rings of glowing magic numbers and runes around him, a dark tailcoat robe'),
 ('boss_94', 'a demon summoner with four arms, summoning circle runes glowing on his body, small shadow soldiers rising behind him'),
 ('boss_95', 'a forbidden demon knight whose face is half demon and half human, cracked horns, sad eyes, dark knight armor'),
 ('boss_99', 'a horned demon warrior holding a gigantic demonic tower shield, heavy black and red armor'),
 ('boss_100', 'the demon lord, a towering demon king with a black jagged crown and burning eyes, a long dark throne cape, huge horns, an imposing pose'),
]


def prompt_of(key, subj):
    st = STYLE
    if key in MAGENTA_BG:
        st = st.replace('bright green chroma-key background (#00FF00)', 'bright magenta chroma-key background (#FF00FF)')
    return st + subj


if __name__ == '__main__':
    for k, s in CAST:
        print(k, '|', prompt_of(k, s))
