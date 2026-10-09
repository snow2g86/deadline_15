#!/usr/bin/env python3
"""개발용: 아이콘 일러스트 목록 → 프롬프트 문서 + 이모지 교체표

사용: python3 tools/icon-catalog.py
- docs/ICON_PROMPTS.md : 그림마다 파일 이름(키)과 생성 프롬프트 (Gemini 등에서 직접 생성)
- js/common/emoji-icons.js 의 EMOJI_ICON 표 : 화면의 이모지 → 아이콘 키 (그림이 있는 것만 자동 교체)
그림 넣는 법: image/icon/src/<키>.png|webp|jpg 로 저장 → python3 tools/import-icons.py
"""
import os, re, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 아이템 그림: 테두리·배경 없이 아이템만 (초록 단색 바탕 → tools/make-icon.py 가 지움).
# 등급 느낌은 게임이 겹쳐 그리는 등급 테두리(frame_*)가 담당: D 없음 · C 은장 · B 금장 · A 에메랄드 · S 루비
STYLE = ('Fantasy RPG game item icon art, painterly semi-realistic digital painting like a premium mobile RPG. '
         'A single item placed diagonally from the bottom-left to the top-right so it appears as large as possible, '
         'isolated on a plain flat solid bright green chroma-key background (#00FF00), evenly lit, no vignette, no frame, no border, no scenery, '
         'no cast shadow, strong readable silhouette, dramatic rim lighting. No text, no letters, no watermark. Subject: ')
FRAME_STYLE = ('Square fantasy RPG item slot background for a game inventory, painterly semi-realistic digital painting. '
               'A thick ornate square frame runs along all four edges, the center is an empty decorative background with no object in it. '
               'No item, no text, no letters, no watermark. Style: ')
RAR = {"wpn_warrior": "common", "wpn_knight": "common", "wpn_assassin": "common", "wpn_mage": "common", "wpn_archer": "common", "wpn_priest": "common", "wpn_novice": "common", "wpn_summoner": "common", "wpn_shaman": "common", "wpn_brawler": "common", "wpn_lancer": "common", "wpn_sapper": "common", "shield": "common", "tome": "common", "buckler": "common", "plate_helm": "common", "chain_helm": "common", "leather_cap": "common", "cloth_hood": "common", "plate_armor": "common", "chain_armor": "common", "leather_armor": "common", "cloth_robe": "common", "plate_boots": "common", "chain_boots": "common", "leather_boots": "common", "cloth_shoes": "common", "necklace_power": "common", "necklace_guard": "common", "necklace_swift": "common", "earring_power": "common", "earring_guard": "common", "earring_swift": "common", "ring_power": "common", "ring_guard": "common", "ring_swift": "common", "legend_blood_oath": "legendary", "legend_unyielding": "legendary", "legend_shadow_fang": "legendary", "legend_starfall": "legendary", "legend_whisper": "legendary", "legend_dawn": "legendary", "legend_first_blade": "legendary", "legend_pact_orb": "legendary", "legend_dead_totem": "legendary", "legend_iron_fist": "legendary", "legend_piercing_lance": "legendary", "legend_demolisher": "legendary", "legend_dragon_scale": "legendary", "legend_warden_chain": "legendary", "legend_windwalk": "legendary", "legend_sage_robe": "legendary", "legend_king_seal": "legendary", "legend_saint_tear": "legendary", "legend_time_earring": "legendary", "potion_heal": "uncommon", "potion_resource": "uncommon", "potion_atk_buff": "uncommon", "potion_def_buff": "uncommon", "potion_atk_debuff": "uncommon", "potion_def_debuff": "uncommon", "exp_s": "common", "exp_m": "uncommon", "exp_l": "epic", "siege_bomb": "common", "siege_bridge": "common", "mat_stone": "common", "mat_protect": "uncommon", "mat_shard": "legendary", "soul_stone": "epic", "class_scroll": "uncommon", "skillbook": "uncommon", "chest": "uncommon", "gold": "common", "rune_fire": "common", "rune_heat": "common", "rune_wind": "common", "rune_poison": "common", "rune_cold": "common", "rune_curse": "common", "rune_flame": "uncommon", "rune_frost": "uncommon", "rune_venom": "uncommon", "rune_thunder": "uncommon", "rune_vamp": "uncommon", "rune_sunder": "uncommon"}   # 아이템 그림의 기본 표시 등급 (장비는 실제 아이템 등급을 씀). 없는 키는 common
MAGENTA_BG = {'necklace_swift', 'earring_swift', 'ring_swift', 'rune_wind', 'rune_poison', 'rune_venom', 'legend_whisper', 'legend_dead_totem',
              'legend_saint_tear', 'legend_time_earring', 'exp_l', 'soul_stone', 'rune_curse', 'rune_frost', 'e_smoke'}   # 아이템이 초록이거나 투명·청록빛이라 초록 바탕에 물드는 것
# 스킬·효과·메뉴 아이콘(e_*): 스킬 아이콘과 같은 정사각 그림, 테두리 없음.
#  아이콘끼리 헷갈리지 않게 뜻에 맞춘 단색 배경(EFFECT_BG) 하나에 상징 뒤 은은한 빛만 (구름·불꽃 배경 금지)
EFFECT_STYLE = ('Square fantasy RPG skill icon, painterly semi-realistic digital painting like a premium mobile RPG skill icon. '
                'A single bold symbol centered and filling most of the square. '
                'Background: a plain flat {bg} background with only a soft radial glow behind the symbol, '
                'no clouds, no fire, no scenery, no other colors in the background. '
                'Strong readable silhouette, dramatic rim lighting. No border, no frame, no panel, no rounded corners, no text, no letters, no watermark. Subject: ')
BG_COLOR = {"red": "deep crimson red", "orange": "burnt orange", "gold": "warm golden amber", "green": "deep emerald green", "teal": "dark teal", "sky": "icy sky blue", "navy": "deep navy blue", "purple": "royal purple", "pink": "deep magenta pink", "grey": "dark slate grey", "brown": "warm parchment brown", "black": "near-black charcoal", "white": "pale silver white", "olive": "mossy olive green", "indigo": "midnight indigo"}
EFFECT_BG = {"e_lightning": "navy", "e_swords": "red", "e_sparkle": "gold", "e_fire": "orange", "e_target": "teal", "e_dagger": "red", "e_poison": "purple", "e_skull": "black", "e_frost": "sky", "e_rage": "red", "e_holy": "gold", "e_explosion": "orange", "e_crystal_ball": "indigo", "e_fortress": "grey", "e_star_burst": "navy", "e_gear": "brown", "e_trap": "olive", "e_flask": "teal", "e_disarm": "grey", "e_repeat": "navy", "e_root": "olive", "e_exalt": "pink", "e_tenacity": "orange", "e_wall": "navy", "e_empower": "purple", "e_commander": "navy", "e_water": "sky", "e_soul_burst": "indigo", "e_wave": "teal", "e_dove": "gold", "e_eye": "purple", "e_tornado": "grey", "e_switch": "teal", "e_rock": "brown", "e_golem": "grey", "e_charge": "orange", "e_repair": "brown", "e_regen": "green", "e_support": "gold", "e_painshare": "pink", "e_bandage": "white", "e_grit": "red", "e_pickaxe": "brown", "e_poison_cloud": "purple", "e_dynamite": "black", "e_capture": "grey", "e_cleave": "red", "e_assault": "sky", "e_tackle": "orange", "e_steelrain": "grey", "e_spirit": "indigo", "e_hourglass": "brown", "e_dash": "teal", "e_blood": "black", "e_footsteps": "grey", "e_backpack": "brown", "e_unlock": "teal", "e_shove": "sky", "e_forest": "green", "e_hill": "olive", "e_sun_heat": "orange", "e_meteor": "black", "e_mosquito": "olive", "e_candle": "purple", "e_galaxy": "indigo", "e_new_moon": "black", "e_boxing": "gold", "e_sprout": "green", "e_balance": "navy", "e_rainbow": "white", "e_mask": "brown", "e_beginner": "green", "e_graduate": "navy", "e_boss": "red", "e_detour": "olive", "e_shop": "brown", "e_box": "brown", "e_person": "grey", "e_party": "teal", "e_level_up": "green", "e_celebrate": "pink", "e_trophy": "navy", "e_medal": "red", "e_medal_silver": "navy", "e_medal_bronze": "teal", "e_heart": "pink", "e_mana": "indigo", "e_books": "brown", "e_chart": "white", "e_clipboard": "brown", "e_pin": "white", "e_idea": "navy", "e_ai": "teal", "e_map": "brown", "e_cards": "red", "e_briefcase": "brown", "e_game": "purple", "e_barrier": "orange", "e_academy": "navy", "e_forge": "black", "e_sanctuary": "gold", "e_alarm": "teal", "e_shuffle": "grey", "e_pencil": "white", "e_shout": "red", "e_smoke": "grey", "e_stealth": "indigo"}   # 키 → BG_COLOR 이름

def prompt_of(key, subj):
    if key.startswith('e_'): return EFFECT_STYLE.replace('{bg}', BG_COLOR[EFFECT_BG.get(key, 'navy')]) + subj
    if key.startswith('jab_'): return JAB_STYLE + subj
    if key.startswith('frame_'): return FRAME_STYLE + subj
    if key in MAGENTA_BG: return STYLE.replace('bright green chroma-key background (#00FF00)', 'bright magenta chroma-key background (#FF00FF)') + subj
    return STYLE + subj


# 직업 아이콘(image/icon/jab/*.png)은 기존 직업 아이콘과 같은 엠블럼 화풍 — 금테 없음
JAB_STYLE = ('Square fantasy RPG class emblem icon in the same style as the other class icons: glossy semi-realistic emblem art, '
             'thick dark outline, a single centered object on a glowing radial gradient background that fills the whole square, '
             'no border frame, no text, no letters, no watermark. Subject: ')

# (키, 한국어 이름, 영어 주제, [이 그림으로 바꿀 이모지들])  — 그룹 순서 = 작업 우선순위
#  키가 jab_ 로 시작하면 직업 아이콘: tools/import-icons.py 가 image/icon/jab/<직업>.png (64px)로 바로 교체
GROUPS = [
 ('0. 직업 아이콘 (엠블럼 화풍 — 위 "직업 아이콘 스타일" 사용)', [
  ('jab_commander', '지휘관 직업 아이콘 (음표 없이)', "a short thick ornate field marshal's baton (a short cylindrical rod with gold end caps, clearly not a sword, no blade) lying across a rolled battle map with a red wax seal, "
   'a gold star insignia above, deep navy blue and gold radial glow filling the whole square edge to edge, no rounded corners, no panel, no musical notes, no music symbols', []),
 ]),
 ('0. 등급 테두리 (아이템 뒤에 깔리는 바탕 — 위 "등급 테두리 스타일" 사용)', [
  ('frame_uncommon', 'C 고급 — 은장', 'polished engraved silver frame, a cool moonlit silver-blue background with soft light', []),
  ('frame_rare', 'B 희귀 — 금장', 'polished ornate gold frame, a warm golden background with soft glowing light and faint filigree', []),
  ('frame_epic', 'A 영웅 — 에메랄드', 'ornate gold frame set with large emerald gems, a rich magical emerald-green background with swirling arcane light and sparkles', []),
  ('frame_legendary', 'S 전설 — 루비', 'lavish ornate gold frame encrusted with large ruby gems, a spectacular crimson and gold background with radiant light rays, embers and glowing particles', []),
 ]),
 ('1. 장비 — 직업 무기', [
  ('wpn_warrior', '대검 (전사)', "a heavy two-handed iron greatsword with a notched blade and a worn leather grip", []),
  ('wpn_knight', '기사검 (기사)', "a steel knight longsword with a cross guard and a round iron pommel", []),
  ('wpn_assassin', '쌍단검 (암살자)', "a pair of curved black-steel twin daggers crossed together", ['🔪']),
  ('wpn_mage', '마법 지팡이 (마법사)', "a wooden mage staff with a small clouded blue crystal at the top", ['🪄']),
  ('wpn_archer', '장궁 (궁수)', "a wooden recurve longbow with a nocked arrow", ['🏹']),
  ('wpn_priest', '성표 (사제)', "a brass healer's scepter topped with a round sun emblem", []),
  ('wpn_novice', '훈련용 검 (견습생)', "a short training sword with a cloth-wrapped wooden hilt and a few chips in the blade", []),
  ('wpn_summoner', '계약의 오브 (소환사)', "a violet glass summoning orb held in an iron claw mount on a short rod, a faint spirit wisp inside", []),
  ('wpn_shaman', '토템 (주술사)', "a carved wooden tribal totem staff with feathers and bone beads", ['🪬']),
  ('wpn_brawler', '건틀릿 (격투가)', "a pair of studded iron fighting gauntlets", ['👊']),
  ('wpn_lancer', '장창 (창기사)', "a long iron cavalry lance with a small red cloth pennant", ['🔱']),
  ('wpn_sapper', '공병 망치 (공병)', "an engineer's iron war hammer with brass rivets and a small gear on the head", ['🔨']),
 ]),
 ('1. 장비 — 보조·방어구·장신구', [
  ('shield', '방패', "a kite shield painted deep blue with a white lion crest and a riveted iron rim, tilted diagonally", ['🛡️', '🛡']),
  ('tome', '마도서', "a thick closed brown leather-bound spell book with an iron clasp and a faint blue rune on the cover", ['📖']),
  ('buckler', '소형 방패', "a small round wooden buckler with a dark iron rim and a central iron boss, painted brown", []),
  ('plate_helm', '판금 투구', "a dark iron full plate knight helmet with a closed visor and a red plume, three-quarter view", ['⛑️']),
  ('chain_helm', '사슬 투구', "a chainmail coif worn under a dark iron nasal helmet with a brown leather strap, three-quarter view", ['🪖']),
  ('leather_cap', '가죽 모자', "a brown leather ranger cap with stitched seams and a small feather, three-quarter view", ['👒']),
  ('cloth_hood', '천 두건', "an empty dark blue cloth mage hood with silver trim, no face, three-quarter view", ['🧢']),
  ('plate_armor', '판금 갑옷', "a heavy dark iron plate breastplate armor with riveted pauldrons and a red cloth sash, three-quarter view, no person", []),
  ('chain_armor', '사슬 갑옷', "a dark steel chainmail hauberk shirt with a brown leather belt, three-quarter view, no person", ['⛓️', '🥋']),
  ('leather_armor', '가죽 갑옷', "a studded brown leather armor vest with buckles and shoulder straps, three-quarter view, no person", ['🧥', '🧵']),
  ('cloth_robe', '천 로브', "a folded purple cloth mage robe with gold trim and a rope belt, no person", ['👘', '👗']),
  ('plate_boots', '판금 장화', "a pair of heavy dark iron plate armored boots (sabatons), three-quarter view", ['👢']),
  ('chain_boots', '사슬 장화', "a pair of brown leather boots covered with chainmail and steel toe caps, three-quarter view", []),
  ('leather_boots', '가죽 장화', "a pair of tall light brown leather ranger boots with laces and a small feather tassel, three-quarter view", ['🥾']),
  ('cloth_shoes', '천 신발', "a pair of soft dark blue embroidered cloth mage shoes with curled toes, three-quarter view", ['👟']),
  ('necklace_power', '힘의 목걸이', "a bronze chain necklace with a red ruby pendant", ['💎', '📿']),
  ('necklace_guard', '수호의 목걸이', "a silver chain necklace with a shield-shaped blue sapphire pendant", ['🔗']),
  ('necklace_swift', '신속의 목걸이', "a leather cord necklace with a green emerald feather-shaped charm", []),
  ('earring_power', '힘의 귀걸이', "a pair of bronze drop earrings with red ruby gems", []),
  ('earring_guard', '수호의 귀걸이', "a pair of silver stud earrings with star-shaped blue sapphire gems", ['⭐']),
  ('earring_swift', '신속의 귀걸이', "a pair of green feather earrings with small emerald beads and silver hooks", []),
  ('ring_power', '힘의 반지', "a heavy bronze ring set with a large red ruby, three-quarter view", ['💍']),
  ('ring_guard', '수호의 반지', "a polished silver ring set with a deep blue sapphire, three-quarter view", ['🔷']),
  ('ring_swift', '신속의 반지', "a slender silver ring with a leaf-shaped band and a light green emerald gem, three-quarter view", ['🔹']),
 ]),
 ('1. 장비 — 전설 (S)', [
  ('legend_blood_oath', '피의 맹세 (전사)', "a legendary crimson two-handed greatsword with glowing blood-red runes stacked along the blade, an ornate blackened gold guard with a red gem, red energy dripping from the edge", []),
  ('legend_unyielding', '불굴의 성벽 (기사)', "a legendary holy knight longsword with a broad gold winged cross guard and a large blue sapphire pommel, the blade glowing with a soft golden protective light", []),
  ('legend_shadow_fang', '그림자 송곳니 (암살자)', "a legendary pair of crossed curved black fang-shaped daggers made of living shadow, glowing violet edges and purple shadow wisps trailing from the blades", []),
  ('legend_starfall', '별무리 지팡이 (마법사)', "a legendary tall arcane staff of dark wood and silver crowned with a swirling miniature purple-blue galaxy orb, tiny falling stars and blue mana streams around the head", []),
  ('legend_whisper', '바람의 속삭임 (궁수)', "a legendary curved recurve longbow with a taut bowstring, silver limbs carved like leaves with jade-green inlays, small white wind swirls around the limbs, no arrow", []),
  ('legend_dawn', '새벽의 성표 (사제)', "a legendary ornate golden holy scepter topped with a radiant sunburst disc and a white pearl, warm sunrise light rays and golden sparks around the head", []),
  ('legend_first_blade', '영웅의 첫 검 (견습생)', "a legendary humble short sword with a cloth-wrapped hilt and a few chips in the steel blade, the blade glowing with warm golden destiny light and small golden sparks rising from it", []),
  ('legend_pact_orb', '계약의 오브 (소환사)', "a legendary glowing violet crystal orb with a small bound guardian spirit inside, wrapped in golden chains of light, held in an ornate silver claw mount on a short rod", []),
  ('legend_dead_totem', '망자의 토템 (주술사)', "a legendary carved dark wood and bone totem staff topped with a horned skull, ghostly green souls swirling around the skull with dark smoke", []),
  ('legend_iron_fist', '철권 (격투가)', "a legendary massive black iron fighting gauntlet clenched into a fist, glowing orange cracks in the metal and a ring of impact shockwave bursting from the knuckles", []),
  ('legend_piercing_lance', '관통의 창 (창기사)', "a legendary polearm spear with a very long white-and-gold wrapped wooden shaft and a long narrow golden spearhead glowing at the point, a small red pennant tied below the spearhead, golden piercing light streak", []),
  ('legend_demolisher', '파괴 공학 (공병)', "a legendary heavy engineer's war hammer with brass gears on the head and a glowing orange explosive core set in its center, sparks and a small fiery blast burst around the hammer head", []),
  ('legend_dragon_scale', '용비늘 갑주', "a legendary red dragonscale plate breastplate armor made of overlapping crimson dragon scales with gold trim and dragon-horn pauldrons, small flames licking along its edges, three-quarter view, no person", []),
  ('legend_warden_chain', '수호자의 사슬', "a legendary silver chainmail hauberk with ornate blue-steel shoulder guards and a glowing blue shield rune on the chest emitting a soft blue protective aura, three-quarter view, no person", []),
  ('legend_windwalk', '바람걸음 장화', "a legendary pair of tall light tan leather boots with small white feathered wings at the ankles, swirling white wind and golden sand dust around the soles, three-quarter view", []),
  ('legend_sage_robe', '현자의 로브', "a legendary flowing midnight-blue mage robe embroidered with silver stars and glowing cyan arcane sigils, a high gold collar, faint mana wisps around it, no person", []),
  ('legend_king_seal', '왕의 인장', "a legendary heavy gold signet ring with a royal crown engraved on its flat oval face, small red rubies set on each side, a regal warm golden glow, three-quarter view", []),
  ('legend_saint_tear', '성자의 눈물', "a legendary large teardrop-shaped clear white diamond crystal pendant in a gold setting with small white angel wings, on a fine gold chain, shining with soft white holy light", []),
  ('legend_time_earring', '시간의 귀걸이', "a legendary gold drop earring with a tiny ornate golden clockwork hourglass charm filled with glowing blue sand, small brass gears around it", []),
 ]),
 ('1. 소모품·재료·룬', [
  ('potion_heal', '회복 물약', "a round glass potion flask with a cork stopper, filled with glowing red healing liquid, a small heart-shaped sparkle", ['💊']),
  ('potion_resource', '자원 물약', "a tall slim glass potion bottle with a cork stopper, filled with glowing blue-violet energy liquid crackling with small white lightning sparks", []),
  ('potion_atk_buff', '공격 강화 물약', "a square glass potion bottle with a cork stopper, filled with glowing orange liquid with small flames swirling inside the glass", []),
  ('potion_def_buff', '방어 강화 물약', "a sturdy glass potion bottle with a cork stopper, filled with steel-blue liquid, a silver shield emblem embossed on the front of the bottle", []),
  ('potion_atk_debuff', '공격 약화 물약', "a round glass throwing flask with a rag fuse, filled with murky dark purple liquid, a cracked broken sword symbol painted on the glass, purple weakening smoke leaking from the top", []),
  ('potion_def_debuff', '방어 약화 물약', "a round glass throwing flask with a rag fuse, filled with icy pale-blue liquid, a cracked broken shield symbol painted on the glass, frost crystals on the glass and cold white mist leaking from the top", []),
  ('exp_s', '소형 경험치 물약', "a small thin glass vial with a cork stopper, filled with glowing golden experience elixir", []),
  ('exp_m', '중형 경험치 물약', "a medium round-bottom alchemy flask with a brass neck ring and cork, filled with bright glowing golden elixir, golden sparkles rising out of the neck", ['⚗️']),
  ('exp_l', '대형 경험치 물약', "a large ornate opaque solid gold amphora jar with two curled handles and engraved patterns, overflowing at the mouth with radiant golden experience light and floating golden orbs", ['🏺']),
  ('siege_ladder', '사다리', 'a tall wooden siege ladder with thick rope-lashed rungs and two iron grappling hooks at the top', ['🪜']),
  ('siege_bomb', '폭탄', "a round black iron powder bomb with riveted bands and a short lit fuse throwing bright orange sparks", ['💣']),
  ('siege_bridge', '다리', "a short portable wooden siege bridge made of thick planks lashed together with rope, iron hooks at both ends, no water, no ground", ['🌉']),
  ('mat_stone', '강화석', "a faceted blue-silver magic enhancement stone glowing with an inner blue light, small orange forge sparks flying around it", ['🔩']),
  ('mat_protect', '보호 주문서', "a rolled parchment scroll tied with a gold ribbon, a glowing blue shield-shaped wax seal on the front", []),
  ('mat_shard', '전설 조각', "a jagged radiant golden crystal shard broken from a legendary relic, glowing warm gold from within with tiny sparkles", []),
  ('soul_stone', '영혼석', "a glowing cyan soul crystal, a smooth teardrop-shaped gem with a small swirling white spirit wisp trapped inside", ['💠']),
  ('class_scroll', '전직서', "an ornate royal decree scroll rolled on two golden end rods, tied with a red silk ribbon and a large red wax seal stamped with a star", ['📜']),
  ('skillbook', '스킬북', "a closed red leather spellbook with gold corner caps and a glowing orange skill rune emblem on the cover", ['📕']),
  ('chest', '보물상자', "an open wooden treasure chest with iron bands, overflowing with gold coins, red and blue gems and a small potion, three-quarter view", ['🎁']),
  ('gold', '골드', "a neat tall stack of shining gold coins with a few coins leaning against it, embossed crown on the coins", ['🪙', '💰']),
  ('rune_fire', '룬: 화염 저항', "a flat round grey carved stone ward rune tablet with a glowing red flame-and-shield symbol engraved in the center", []),
  ('rune_heat', '룬: 더위 저항', "a flat round grey carved stone ward rune tablet with a glowing golden-orange sun symbol engraved in the center", []),
  ('rune_wind', '룬: 돌풍 저항', "a flat round grey carved stone ward rune tablet with a glowing pale green wind spiral symbol engraved in the center", []),
  ('rune_poison', '룬: 독 저항', "a flat round grey carved stone ward rune tablet with a glowing green healing leaf symbol engraved in the center", []),
  ('rune_cold', '룬: 혹한 저항', "a flat round grey carved stone ward rune tablet with a glowing icy blue snowflake symbol engraved in the center, a little frost on the stone rim", []),
  ('rune_curse', '룬: 저주 저항', "a flat round grey carved stone ward rune tablet with a glowing warm golden holy eight-pointed star ward symbol inlaid in gold in the center", []),
  ('rune_flame', '룬: 화염 (공격)', "a sharp elongated red crystal attack rune with an engraved glowing rune mark, bursting with orange fire from its tip", []),
  ('rune_frost', '룬: 서리 (공격)', "a large faceted icy blue crystal gem rune with a glowing white engraved rune mark, encased in sharp jagged white ice spikes", ['🧊']),
  ('rune_venom', '룬: 맹독 (공격)', "a large faceted toxic green crystal gem rune with a glowing engraved rune mark, a small dark serpent coiled around it, green venom dripping from its tip", ['🐍']),
  ('rune_thunder', '룬: 번개 (공격)', "a large faceted bright yellow crystal gem rune with a glowing engraved rune mark, crackling with white and yellow lightning bolts around it", []),
  ('rune_vamp', '룬: 흡혈 (공격)', "a large faceted dark crimson crystal gem rune with a glowing blood droplet mark, small black bat wings spreading from its sides", ['🩸']),
  ('rune_sunder', '룬: 파쇄 (공격)', "a large faceted steel-grey crystal gem rune with a glowing orange engraved rune mark, its sharp tip cracking and shattering a small iron armor plate into flying shards", []),
 ]),
 ('2. 전투 — 스킬·버프·상태', [
  ('e_lightning', '번개·강타·회피', 'a crackling lightning bolt striking down', ['⚡']),
  ('e_swords', '공격', 'two crossed swords clashing with sparks', ['⚔️', '⚔']),
  ('e_sparkle', '빛·치유·정령', 'radiant golden sparkles of holy light', ['✨']),
  ('e_fire', '화염·공격 강화', 'roaring orange flames', ['🔥']),
  ('e_target', '저격·조준', 'an archery target with an arrow in the bullseye', ['🎯']),
  ('e_dagger', '치명타·출혈', 'a dagger with a drop of blood on its tip', ['🗡️']),
  ('e_poison', '독·저주', 'a skull wreathed in toxic green poison smoke', ['☠️']),
  ('e_skull', '죽음·보스·암살', 'an ominous black skull with glowing red eyes', ['💀']),
  ('e_frost', '빙결·방어 약화', 'a sharp glowing ice crystal snowflake', ['❄️']),
  ('e_rage', '분노·약점 포착', 'a burning red rage burst with a fierce aura', ['💢']),
  ('e_holy', '성역·신성', 'a glowing holy cross radiating light', ['✝️']),
  ('e_explosion', '폭발·파쇄·파손', 'a fiery explosion burst with flying debris', ['💥']),
  ('e_crystal_ball', '영매·룬', 'a mystic crystal ball with swirling purple mist', ['🔮']),
  ('e_fortress', '철벽·성채', 'a stone fortress tower with banners', ['🏰']),
  ('e_star_burst', '별빛·자원 환급', 'a bright four-pointed starburst of golden light', ['🌟']),
  ('e_gear', '장치·함정 강화', 'a bronze clockwork gear mechanism', ['⚙️']),
  ('e_trap', '함정', 'a spiked steel bear trap hidden in grass', ['⚠']),
  ('e_flask', '물약·독 저항', 'a glass alchemy flask with bubbling green liquid', ['🧪']),
  ('e_disarm', '무장 해제', 'a gauntleted fist knocking a sword out of a hand', ['🤛']),
  ('e_repeat', '다 카포·역습', 'two circular golden arrows of energy forming a loop', ['🔁']),
  ('e_root', '속박', 'thorny green vines binding feet to the ground', ['🌿']),
  ('e_exalt', '고양', 'a glowing red upward triangle rune with rising energy', ['🔺']),
  ('e_tenacity', '강인함', 'an armored arm flexing with a golden aura', ['💪']),
  ('e_wall', '그랜드 월·방어 태세', 'a magical brick wall barrier glowing blue', ['🧱']),
  ('e_empower', '소환 강화', 'a glowing upward arrow of power over a summoning circle', ['⬆️']),
  ('e_commander', '지휘관', "a short thick ornate field marshal's baton (a short cylindrical rod with gold end caps, clearly not a sword, no blade) lying across a rolled battle map", ['🎖️']),
  ('e_water', '정화·물·버팀', 'a glowing pure water droplet', ['💧']),
  ('e_soul_burst', '영혼 폭발', 'a burst of swirling spirit energy with stars', ['💫']),
  ('e_wave', '마나 쇄도·물결', 'a surging magical blue wave', ['🌊']),
  ('e_dove', '신의 은총', 'a white dove with glowing holy wings', ['🕊️']),
  ('e_eye', '경계·함정 감지', 'a watchful glowing eye', ['👁', '👁️']),
  ('e_tornado', '돌풍', 'a violent swirling tornado', ['🌪️']),
  ('e_switch', '스위치', 'two figures swapping places with circular arrows', ['🔄']),
  ('e_rock', '돌던지기·바위', 'a rough boulder', ['🪨']),
  ('e_golem', '골렘 소환', 'a hulking stone golem', ['🗿']),
  ('e_charge', '차징·돌격', 'a charging armored warhorse', ['🐎']),
  ('e_smoke', '연막', 'a small round black smoke bomb cracking open and bursting into a thick billowing cloud of dark grey smoke that fills most of the image', ['🌫️']),
  ('e_repair', '수리', 'a steel wrench and hammer crossed', ['🔧']),
  ('e_regen', '재생', 'a glowing green heart of regeneration', ['💚']),
  ('e_support', '연계 공격', 'two gauntleted hands clasping in alliance', ['🤝']),
  ('e_painshare', '고통 분담', 'a cracked heart bound by a chain of light', ['💔']),
  ('e_bandage', '응급처치', 'a rolled cloth bandage with a red cross', ['🩹']),
  ('e_grit', '근성', 'a clenched fist glowing with determination', ['✊']),
  ('e_pickaxe', '굴착', 'a mining pickaxe striking stone', ['⛏️']),
  ('e_poison_cloud', '독안개', 'a toxic green poison cloud', ['☁️']),
  ('e_dynamite', '폭파·공병', 'a bundle of dynamite with a lit fuse', ['🧨']),
  ('e_capture', '포획', 'a grappling hook with a chain', ['🪝']),
  ('e_cleave', '휘두르기', 'a sword sweeping in a full circular arc', ['🌀']),
  ('e_assault', '강습', 'a diving eagle with outstretched talons', ['🦅']),
  ('e_tackle', '몸통 박치기', 'a figure charging shoulder-first with dust', ['🏃']),
  ('e_steelrain', '강철비', "many steel arrows raining down diagonally", ['🌧️']),
  ('e_spirit', '영혼 쇄도', 'a ghostly spirit surging forward', ['👻']),
  ('e_stealth', '은신', 'a crescent moon over a shadowy hooded figure', ['🌙']),
  ('e_hourglass', '소환 지속 시간', 'an hourglass with glowing sand', ['⏳']),
  ('e_dash', '도약', 'a swift gust of wind with speed lines', ['💨']),
  ('e_blood', '피의 갈망·흡혈', 'a glowing crimson blood drop', []),
 ]),
 ('2. 전투 — 행동·지형·환경·조합 버프', [
  ('e_footsteps', '이동', 'glowing footprints on a stone path', ['👣']),
  ('e_backpack', '아이템', "an adventurer's leather backpack", ['🎒']),
  ('e_unlock', '해제', "an open golden padlock with its shackle swung open and a key beside it", ['🔓']),
  ('e_shove', '밀치기', 'a palm thrust pushing with a shockwave', ['🫸']),
  ('e_forest', '숲', 'a dense pine forest', ['🌲']),
  ('e_hill', '언덕', 'a grassy hill with a rocky peak', ['⛰️']),
  ('e_sun_heat', '더위 (사막)', 'a scorching sun over desert dunes', ['☀️']),
  ('e_meteor', '지옥불', 'a flaming meteor falling', ['☄️']),
  ('e_mosquito', '정글 독충', 'a giant venomous jungle mosquito', ['🦟']),
  ('e_candle', '저주 (유적)', 'a cursed black candle with a purple flame', ['🕯️']),
  ('e_galaxy', '대마도 (마법사 5인)', 'a swirling cosmic galaxy of arcane power', ['🌌']),
  ('e_new_moon', '야행 (암살자 5인)', 'a dark new moon with shadow wisps', ['🌑']),
  ('e_boxing', '투사 (격투가 5인)', 'a pair of red boxing gloves', ['🥊']),
  ('e_sprout', '신참 (견습생 5인)', 'a young green sprout in soil', ['🌱']),
  ('e_balance', '균형 진형', 'golden balance scales', ['⚖️']),
  ('e_rainbow', '만능 부대', 'a vibrant rainbow arch', ['🌈']),
  ('e_mask', '주술사', 'a carved tribal spirit mask', ['🎭']),
  ('e_beginner', '초보자', 'a green and yellow beginner leaf badge', ['🔰']),
  ('e_graduate', '노비스 (아카데미)', "a black scholar graduation cap with a gold tassel resting on a closed book, no person", ['🎓']),
  ('e_boss', '주요 적', "a fearsome horned warlord helmet with glowing red eyes", ['👹']),
  ('e_detour', '우회로', 'a winding dirt path with a wooden signpost', ['🛣️', '🛤️']),
  ('e_shop', '상점', 'a merchant cart with goods', ['🛒']),
  ('e_box', '상자', 'a sealed wooden supply crate', ['📦']),
  ('e_person', '장착자', "a single hooded adventurer bust silhouette", ['👤']),
  ('e_party', '파티', 'a group of three adventurer silhouettes', ['👥']),
  ('e_level_up', '레벨업·성장', 'a rising golden arrow over a glowing crest', ['📈']),
  ('e_celebrate', '첫 클리어', "bursting golden fireworks and falling confetti", ['🎉']),
  ('e_trophy', '승리', 'a golden trophy cup', ['🏆']),
  ('e_medal', '보상', 'a gold medal with a ribbon', ['🏅', '🥇']),
  ('e_medal_silver', '2위', 'a silver medal with a ribbon', ['🥈']),
  ('e_medal_bronze', '3위', 'a bronze medal with a ribbon', ['🥉']),
  ('e_heart', '체력', 'a glowing red heart', ['❤️']),
  ('e_mana', '마나', 'a glowing faceted purple mana crystal shaped like a heart, no person, no face', ['💜']),
 ]),
 ('3. 메뉴·안내 (가이드·도감)', [
  ('e_books', '가이드', 'a stack of old adventure books', ['📚']),
  ('e_chart', '자원·통계', 'a parchment with bar charts', ['📊']),
  ('e_clipboard', '목록·준비 중', 'a clipboard with a checklist', ['📋']),
  ('e_pin', '핵심', 'a red map pin', ['📍']),
  ('e_idea', '팁', 'a glowing magical lightbulb lantern', ['💡']),
  ('e_ai', 'AI 분석', 'a clockwork automaton head', ['🤖', '🧠']),
  ('e_map', '스테이지·지형', 'an old fantasy world map', ['🗺️', '🗺']),
  ('e_cards', '카드 보기·직업', 'a fanned hand of five ornate gilded tarot-style cards seen from the back, no person, no face', ['🎴']),
  ('e_briefcase', '직업 안내', 'a leather satchel with documents', ['💼']),
  ('e_game', '게임 기본', 'a game controller made of brass and wood', ['🎮']),
  ('e_barrier', '제압 구역', 'a wooden barricade with warning stripes', ['🚧']),
  ('e_academy', '아카데미', 'a grand academy building with a bell tower', ['🏫']),
  ('e_forge', '장비·강화', 'a blacksmith hammer and pick on an anvil', ['⚒️']),
  ('e_sanctuary', '성소', 'a small holy chapel with stained glass', ['⛪']),
  ('e_alarm', '특수 조건', 'an antique brass alarm clock', ['⏰']),
  ('e_shuffle', '혼합 스테이지', 'two crossing arrows of red and blue', ['🔀']),
  ('e_pencil', '이름 변경', 'a quill pen and ink', ['✏️']),
  ('e_shout', '창 (안내문)', 'a bronze war horn blasting visible sound waves', ['🗣️']),
 ]),
]

# UI 기호는 글자로 유지 (화살표·체크·닫기 등)
KEEP_TEXT = '→ ★ ✕ ↩ ↩️ ✓ ⏸ ⏸️ ← ↑ ⬆ ✦ ✚ ⚑ ⏭ ❓ ✅ ❌ ⚠️'.split()


def main():
    md = ['# 아이콘 일러스트 프롬프트', '',
          '> 생성: 아래 **스타일** + 각 줄의 **주제**를 이어 붙여 Firefly·Gemini 등에 넣는다 (1:1 정사각형). 등급 칸은 게임에서 기본으로 깔리는 테두리.',
          '> 저장: `image/icon/src/<파일 이름>.png` (webp·jpg도 됨). 그다음 `python3 tools/import-icons.py` 를 실행하면 게임에 바로 적용된다.',
          '> 화면의 이모지는 그림이 생긴 것만 자동으로 바뀌고, 없는 것은 이모지 그대로 남는다.', '',
          '## 아이템 그림 스타일', '', '아이템만 초록 단색 바탕에 그린다 (테두리·배경 없음). 등급 느낌은 게임이 등급 테두리를 겹쳐서 낸다: D 없음 · C 은장 · B 금장 · A 에메랄드 · S 루비.', '', '```', STYLE.strip(), '```', '',
          '## 등급 테두리 스타일 (frame_ 묶음만)', '', '```', FRAME_STYLE.strip(), '```', '',
          '## 직업 아이콘 스타일 (0번 묶음만)', '', '```', JAB_STYLE.strip(), '```', '']
    have = set(os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, 'image/icon/item'))) if os.path.isdir(os.path.join(ROOT, 'image/icon/item')) else set()
    total = done = 0
    emap = {}
    for title, rows in GROUPS:
        md += ['## ' + title, '', '| 완료 | 파일 이름 | 등급 | 대상 | 주제 (영어 프롬프트) |', '|---|---|---|---|---|']
        for key, ko, subj, emojis in rows:
            total += 1; ok = key in have; done += ok
            md.append('| %s | `%s` | %s | %s %s | %s |' % ('✓' if ok else '', key, 'jab' if key.startswith('jab_') else 'frame' if key.startswith('frame_') else RAR.get(key, 'common'), ko, ' '.join(emojis), subj))
            for e in emojis: emap[e] = key
        md.append('')
    md.insert(5, '> 진행: %d / %d' % (done, total))
    open(os.path.join(ROOT, 'docs/ICON_PROMPTS.md'), 'w').write('\n'.join(md) + '\n')

    js_path = os.path.join(ROOT, 'js/common/emoji-icons.js')
    src = open(js_path).read()
    table = 'var EMOJI_ICON = {' + ','.join("'%s':'%s'" % (e, k) for e, k in emap.items()) + '};'
    src = re.sub(r'var EMOJI_ICON = \{.*?\};', lambda m: table, src, flags=re.S)
    rar = 'var ICON_RARITY = ' + json.dumps({k: v for k, v in RAR.items() if v != 'common'}) + ';'
    src = re.sub(r'var ICON_RARITY = \{.*?\};', lambda m: rar, src, flags=re.S) if 'var ICON_RARITY' in src else src.replace(table, table + '\n' + rar)
    open(js_path, 'w').write(src)
    print('prompts: %d (done %d), emoji map: %d' % (total, done, len(emap)))


if __name__ == '__main__':
    main()
