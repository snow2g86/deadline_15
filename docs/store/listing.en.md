# DEADLINE 15 — Store Listing Text (English)

> Written 2026-10-23 for game version 0.4.2. Draft. Character counts are checked at the bottom of this file.
> Terms match `godot/data/lang/en.json` (clan member, Commander, Soul Stone, Daily Dungeon, Sanctuary, Rune, gold).
> `[확인 필요]` (= "needs confirmation") marks values I could not confirm from the code or docs.

## 1. App name (max 30 characters)

```
DEADLINE 15: Tactics Defense
```

- Usable as both the Google Play and App Store name. App Store rejects names already taken [확인 필요: name availability].
- Home-screen icon label: `DEADLINE 15` (`config/name` in project.godot).

## 2. Short description (max 80 characters, Google Play)

```
Turn-based pixel-art defense RPG. Lead 5 clan members and hold the gate.
```

## 3. App Store only

- Subtitle (max 30): `Turn-based castle defense RPG`
- Promotional text (max 170): `Lead five clan members to defend the castle. Use terrain, flanking and cover, raise 12 classes, clear daily dungeons and enhance gear. No account needed.`
- Keywords (max 100, comma-separated, no spaces):

```
turn-based,strategy,defense,tactics,RPG,pixel,isometric,SRPG,clan,dungeon,fantasy,tower defense
```

## 4. Full description (max 4000 characters)

```
Hold the line before the gate falls.

DEADLINE 15 is a turn-based tactical defense RPG. Build a party of five clan members and defend your castle on isometric pixel-art maps, moving one tile at a time to stop the enemy from breaking through. You play as the Commander, who leads the clan from the rear and does not fight.

HOW IT PLAYS
- Turn-based tactics: choose a move, attack or skill for each clan member, one turn at a time.
- If too many enemies get past the wall ("breakthroughs"), you lose. Block the gate with a Knight and support from behind with ranged allies.
- 100 stages across 10 episodes, with a boss every 10 stages.
- Follow the story of the Commander and the clan.

BATTLE
- Use the terrain: forests give a chance to dodge normal attacks, ranged units on hills shoot farther and harder, and enemies standing in shallows take extra damage.
- Positional tactics: rear and flank attacks, pincer attacks, cover and knockback.
- Each map type has its own environmental debuff (heat, cold, poison, curses and more) that the right enchantment rune can block.
- Party synergy buffs depend on the classes you bring.
- Siege items, treasure chests on the map and potions to use in battle.
- Enemies keep getting stronger. Levels alone are not enough: use promotion, skills, gear, synergies and tactics together.

12 CLASSES TO RAISE
Warrior, Knight, Assassin, Mage, Archer, Priest, Novice, Summoner, Shaman, Brawler, Lancer and Sapper. Novices can change class at the Academy.
- Level up and strengthen skills with skill books.
- Raise a clan member's grade (C > B > A > S) at the Sanctuary by sacrificing clan members of the same class. B to A and A to S promotions also need Soul Stones.
- Fallen clan members can be revived at the Sanctuary for gold.

PROGRESSION
- Daily Dungeons: each weekday opens different classes and drops their Soul Shards. Combine shards into Soul Stones.
- Equipment: class-specific weapons, shared armor, Legendary gear from bosses and dungeons, and class sets.
- Enhancement +1 to +10: a failure can lower the level or break the item. A protection scroll prevents breakage.
- Enchanting: use Runes to add environment resistance and attack effects (Flame, Frost, Venom, Thunder, Vampiric, Sunder).

ALSO
- 6 languages: Korean, English, Spanish, Japanese, Simplified Chinese, Traditional Chinese
- Start playing without creating an account
- In-game codex and strategy guide

ITEM DROP RATES (RANDOM ITEMS)
This game contains random items.
- Equipment draw (shop): rates differ by grade, with a pity system (the 100th draw without a Legendary guarantees one).
- Enchanting rune draw (Sanctuary): all 12 runes have the same chance.
- Equipment enhancement: each level has success, failure and breakage rates.
The full table is in the shop and enhancement screens ("Drop Rates") and at the address below.
Drop rates: [rates page URL -- the published address of docs/store/probabilities.en.md [확인 필요]]

PAID ITEMS AND ADS
- Gold packages (in-app purchase, consumable): 500 / 1,200 / 3,000 / 6,500 gold. Gold is spent in game on recruiting mercenaries, revives, equipment draws, enhancement and more. You can also earn gold by playing.
- Rewarded ads: watch an ad to the end to receive 100 gold (up to 3 times a day). The game can be played without watching ads.
- Ads are provided by Google AdMob. Depending on your region, an ad privacy consent dialog may appear; you can change your choice later in Settings.
- On iOS you may be asked for permission to track using your device identifier. The game plays exactly the same if you decline.
- To verify purchases, a randomly generated install ID and purchase receipt information are sent to our purchase verification server. See the Privacy Policy for details.

Privacy Policy: [privacy policy URL [확인 필요]]
Contact: [support email [확인 필요]]
```

### Changes for the PC (STOVE) listing

- Remove the "Rewarded ads" line and the "Google AdMob" and "iOS tracking" lines (the PC edition has no ads).
- Use the STOVE-registered prices for the gold packages (see the checklist).
- Keep the random-item notice (STOVE also requires drop-rate disclosure).

## 5. Feature list

- Isometric pixel-art turn-based defense battles (100 stages, 10 episodes)
- 12 classes of clan members, with grade promotion (C > B > A > S)
- Terrain, rear/flank attacks, cover and knockback tactics
- Daily Dungeons and Soul Stones, equipment draws, enhancement to +10, enchanting runes
- Party synergy buffs, map environment debuffs and defensive runes
- Story of the Commander and the clan, codex and strategy guide
- 6 languages (Korean, English, Spanish, Japanese, Simplified Chinese, Traditional Chinese)
- No account needed / rewarded ads on mobile (3 per day) / no ads in the PC edition

## 6. Release notes (first version)

Google Play "What's new" (max 500 characters):

```
Welcome to DEADLINE 15.
- 100 stages of turn-based defense battles
- Raise and promote 12 classes of clan members
- Daily Dungeons, equipment draws and enhancement, enchanting runes
- Korean, English, Spanish, Japanese, Simplified and Traditional Chinese
- Gold packages (in-app purchase) and rewarded ads (3 per day)
```

Version number for the first store release: [확인 필요] (the internal game version is 0.4.2).

## 7. Drop-rate notice (where the link goes)

| Where | Text |
|---|---|
| Full description, "ITEM DROP RATES" paragraph | The text above plus the rates page URL [확인 필요] |
| Last line of the Google Play description | `Drop rates for random items (equipment draw, enchanting rune draw, enhancement): [rates page URL]` |
| Last line of the App Store description and the Support URL page | Same sentence. The App Store description does not make URLs tappable, so write the address as plain text and also put the rates table on the Support URL page. |
| In game | "Drop Rates" in the shop and enhancement screens (already implemented; same content as `docs/store/probabilities.en.md`) |

## 8. Paid items and ads (store form values)

| Item | Value |
|---|---|
| Contains in-app purchases | Yes (4 gold packages, consumable) |
| In-app product price range (Play) | KRW 1,200 - 12,000 (South Korea base price) |
| Contains ads | Yes (mobile only, rewarded ads) |
| App Store: ads and tracking | In-app ads: yes / tracking permission request (ATT): yes |

## 9. Age-rating questionnaire guide

See `age_rating_notes.md` for the full explanation. Draft answers:

| Question | Answer | Basis |
|---|---|---|
| Violence | Yes, fantasy combat with pixel-art characters | Characters attack and fall in battle. A "Bleed" status effect exists as text. Whether blood is drawn on screen: [확인 필요: check in the running game] |
| Fear / horror | None [확인 필요] | |
| Sexual content / nudity | None | |
| Profanity | None [확인 필요: review all-language dialogue] | |
| Drugs, alcohol, tobacco | None [확인 필요] | |
| Gambling | No real-money gambling. There are random items bought with premium currency (gold): equipment draw, rune draw, enhancement | Answer "yes" if the form asks about random items or loot boxes |
| In-app purchases | Yes (gold packages, consumable) | |
| Ads | Yes (mobile rewarded ads, Google AdMob) | Not directed at children |
| User interaction / user-generated content | None (only renaming a character; not shown to other players) [확인 필요] | |
| Location sharing / personal info sharing | None | |
| Directed at children | No | `child_directed=false` in iap.json |

## 10. Character count check

(The table below was computed with a script after writing.)

| Item | Characters | Limit | Result |
|---|---|---|---|
| App name | 28 | 30 | OK |
| Short description | 72 | 80 | OK |
| Keywords (App Store) | 95 | 100 | OK |
| Full description | 3823 | 4000 | OK |
| Release notes (Play) | 317 | 500 | OK |
| Subtitle (App Store) | 29 | 30 | OK |
| Promotional text | 153 | 170 | OK |
