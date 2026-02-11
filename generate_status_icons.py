#!/usr/bin/env python3
"""
Tactical Clarity Status Icons Generator
Generates 64×64px PNG icons for RPG game status effects
"""

from PIL import Image, ImageDraw
import math
import os
from pathlib import Path

# Configuration
ICON_SIZE = 64
ACTIVE_AREA = 48  # Excludes 8px margin
MARGIN = (ICON_SIZE - ACTIVE_AREA) // 2  # 8px
STROKE = 2
CENTER = ICON_SIZE // 2

# Output directory
OUTPUT_DIR = Path(__file__).parent / "image" / "icon" / "status"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def create_icon(name, draw_func, primary_color, secondary_color):
    """Create and save an icon PNG"""
    img = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_func(draw, primary_color, secondary_color)
    output_path = OUTPUT_DIR / f"{name}.png"
    img.save(output_path)
    print(f"✓ Created: {output_path}")

def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple"""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

# ════════════════════════════════════════════
# BUFF ICONS (17)
# ════════════════════════════════════════════

def draw_fury_max(draw, primary, secondary):
    """Fire/Energy - Jagged flame shape"""
    cx, cy = CENTER, CENTER
    points = [
        (cx, MARGIN+2),        # top point
        (cx+6, MARGIN+6),      # upper right
        (cx+6, cy),            # right
        (cx+8, cy),            # far right
        (cx+4, cy+8),          # bottom right
        (cx+2, cy+12),         # very bottom
        (cx-2, cy+12),         # very bottom left
        (cx-4, cy+8),          # bottom left
        (cx-8, cy),            # far left
        (cx-6, cy),            # left
        (cx-6, MARGIN+6),      # upper left
    ]
    draw.polygon(points, fill=primary)

def draw_warrior_fury(draw, primary, secondary):
    """Warrior Rage - Angry expression"""
    cx, cy = CENTER, CENTER
    # Angry eyebrows
    draw.line([(cx-7, cy-5), (cx-2, cy-1)], fill=primary, width=STROKE)
    draw.line([(cx+7, cy-5), (cx+2, cy-1)], fill=primary, width=STROKE)
    # Mouth/jaw
    draw.line([(cx-4, cy+4), (cx+4, cy+4)], fill=primary, width=STROKE)
    # Spiky aura
    for angle in [0, 45, 90, 135, 180, 225, 270, 315]:
        x = cx + math.cos(math.radians(angle)) * 10
        y = cy + math.sin(math.radians(angle)) * 10
        draw.line([(cx + math.cos(math.radians(angle))*5, cy + math.sin(math.radians(angle))*5), (x, y)], fill=primary, width=1)

def draw_shield_buff(draw, primary, secondary):
    """Shield - Classic shield outline"""
    cx, cy = CENTER, CENTER
    points = [
        (cx-6, cy-8),   # top left
        (cx+6, cy-8),   # top right
        (cx+8, cy-2),   # right curve
        (cx+6, cy+10),  # bottom right
        (cx, cy+12),    # bottom center
        (cx-6, cy+10),  # bottom left
        (cx-8, cy-2),   # left curve
    ]
    draw.polygon(points, outline=primary, width=STROKE)

def draw_pain_share(draw, primary, secondary):
    """Shared Pain - Linked circles"""
    cx, cy = CENTER, CENTER
    draw.ellipse([(cx-7, cy-4), (cx-1, cy+4)], outline=primary, width=STROKE)
    draw.ellipse([(cx+1, cy-4), (cx+7, cy+4)], outline=primary, width=STROKE)
    draw.line([(cx-1, cy), (cx+1, cy)], fill=primary, width=STROKE)

def draw_tenacity(draw, primary, secondary):
    """Tenacity - Strength/Defense"""
    cx, cy = CENTER, CENTER
    # Strong arc
    draw.arc([(cx-6, cy-8), (cx+6, cy)], 0, 180, fill=primary, width=STROKE)
    draw.line([(cx-6, cy), (cx+6, cy)], fill=primary, width=STROKE)
    draw.ellipse([(cx-2, cy-2), (cx+2, cy+2)], fill=primary)

def draw_bloodthirst(draw, primary, secondary):
    """Bloodthirst - Blood droplet"""
    cx, cy = CENTER, CENTER
    draw.ellipse([(cx-4, cy-6), (cx+4, cy+2)], fill=primary)
    points = [(cx-4, cy+2), (cx, cy+10), (cx+4, cy+2)]
    draw.polygon(points, fill=primary)

def draw_sanctuary(draw, primary, secondary):
    """Sanctuary - Healing cross"""
    cx, cy = CENTER, CENTER
    draw.line([(cx, cy-7), (cx, cy+7)], fill=primary, width=STROKE)
    draw.line([(cx-7, cy), (cx+7, cy)], fill=primary, width=STROKE)
    draw.ellipse([(cx-8, cy-8), (cx+8, cy+8)], outline=secondary, width=1)

def draw_summon_duration(draw, primary, secondary):
    """Summon Duration - Hourglass"""
    cx, cy = CENTER, CENTER
    draw.line([(cx-5, cy-8), (cx+5, cy-8)], fill=primary, width=STROKE)
    draw.line([(cx+5, cy-8), (cx+2, cy), (cx+5, cy+8)], fill=primary, width=STROKE)
    draw.line([(cx-5, cy-8), (cx-2, cy), (cx-5, cy+8)], fill=primary, width=STROKE)
    draw.line([(cx-5, cy+8), (cx+5, cy+8)], fill=primary, width=STROKE)

def draw_exalt(draw, primary, secondary):
    """Exalt - Upward triangle"""
    cx, cy = CENTER, CENTER
    points = [(cx, cy-10), (cx-8, cy+8), (cx+8, cy+8)]
    draw.polygon(points, fill=primary)
    draw.ellipse([(cx-2, cy-6), (cx+2, cy-2)], fill=secondary)

def draw_spearwall(draw, primary, secondary):
    """Spear Wall - Phalanx formation"""
    cx, cy = CENTER, CENTER
    for offset in [-4, 0, 4]:
        draw.line([(cx+offset, cy-8), (cx+offset, cy+8)], fill=primary, width=STROKE)
    draw.line([(cx-6, cy+6), (cx+6, cy+6)], fill=primary, width=STROKE)

def draw_counter(draw, primary, secondary):
    """Counter - Circular arrows"""
    cx, cy = CENTER, CENTER
    for angle in [0, 120, 240]:
        rad = math.radians(angle)
        x1 = cx + math.cos(rad) * 6
        y1 = cy + math.sin(rad) * 6
        draw.ellipse([(x1-2, y1-2), (x1+2, y1+2)], fill=primary)

def draw_medium(draw, primary, secondary):
    """Medium - Crystal ball"""
    cx, cy = CENTER, CENTER
    draw.ellipse([(cx-7, cy-7), (cx+7, cy+7)], outline=primary, width=STROKE)
    draw.ellipse([(cx-4, cy-4), (cx+4, cy+4)], outline=secondary, width=1)
    draw.ellipse([(cx-1, cy-1), (cx+1, cy+1)], fill=primary)

def draw_enhanced_trap(draw, primary, secondary):
    """Enhanced Trap - Gear"""
    cx, cy = CENTER, CENTER
    draw.ellipse([(cx-6, cy-6), (cx+6, cy+6)], outline=primary, width=STROKE)
    for angle in range(0, 360, 45):
        x = cx + math.cos(math.radians(angle)) * 8
        y = cy + math.sin(math.radians(angle)) * 8
        draw.line([(cx+math.cos(math.radians(angle))*6, cy+math.sin(math.radians(angle))*6), (x, y)], fill=primary, width=1)
    draw.ellipse([(cx-2, cy-2), (cx+2, cy+2)], fill=primary)

def draw_mana_surge(draw, primary, secondary):
    """Mana Surge - Wave"""
    cx, cy = CENTER, CENTER
    points = [(cx-8, cy), (cx-4, cy-4), (cx, cy), (cx+4, cy-4), (cx+8, cy)]
    draw.line(points, fill=primary, width=STROKE)
    points2 = [(cx-8, cy+4), (cx-4, cy), (cx, cy+4), (cx+4, cy), (cx+8, cy+4)]
    draw.line(points2, fill=secondary, width=1)

def draw_divine_grace(draw, primary, secondary):
    """Divine Grace - Dove/Halo"""
    cx, cy = CENTER, CENTER
    draw.ellipse([(cx-7, cy-3), (cx+7, cy+3)], outline=primary, width=STROKE)
    draw.ellipse([(cx-3, cy-2), (cx+3, cy+4)], fill=primary)
    draw.ellipse([(cx-1, cy-4), (cx+3, cy-1)], fill=primary)

def draw_iron_phalanx(draw, primary, secondary):
    """Iron Phalanx - Fortress blocks"""
    cx, cy = CENTER, CENTER
    for i in range(3):
        for j in range(3):
            x = cx - 4 + i * 4
            y = cy - 4 + j * 4
            draw.rectangle([(x, y), (x+3, y+3)], fill=primary, outline=secondary)

def draw_empower(draw, primary, secondary):
    """Empower - Upward arrow"""
    cx, cy = CENTER, CENTER
    points = [(cx, cy-8), (cx+6, cy+2), (cx+2, cy+2), (cx+2, cy+8), (cx-2, cy+8), (cx-2, cy+2), (cx-6, cy+2)]
    draw.polygon(points, fill=primary)

# ════════════════════════════════════════════
# DEBUFF ICONS (6)
# ════════════════════════════════════════════

def draw_disarmed(draw, primary, secondary):
    """Disarmed - Crossed swords"""
    cx, cy = CENTER, CENTER
    draw.line([(cx-7, cy-7), (cx+7, cy+7)], fill=primary, width=STROKE)
    draw.line([(cx+7, cy-7), (cx-7, cy+7)], fill=primary, width=STROKE)
    draw.ellipse([(cx-8, cy-8), (cx+8, cy+8)], outline=primary, width=1)

def draw_curse(draw, primary, secondary):
    """Curse - Skull"""
    cx, cy = CENTER, CENTER
    draw.ellipse([(cx-6, cy-7), (cx+6, cy-1)], outline=primary, width=STROKE)
    draw.ellipse([(cx-2, cy-2), (cx+2, cy+2)], outline=primary, width=1)
    draw.ellipse([(cx+2, cy-2), (cx+6, cy+2)], outline=primary, width=1)
    draw.line([(cx-4, cy+6), (cx+4, cy+6)], fill=primary, width=STROKE)

def draw_bleed(draw, primary, secondary):
    """Bleed - Wound with blood drops"""
    cx, cy = CENTER, CENTER
    draw.line([(cx-8, cy-2), (cx+8, cy+4)], fill=primary, width=STROKE)
    for offset in [-4, 0, 4]:
        draw.ellipse([(cx+offset-1, cy+8), (cx+offset+1, cy+10)], fill=primary)
        draw.polygon([(cx+offset-1, cy+10), (cx+offset, cy+12), (cx+offset+1, cy+10)], fill=primary)

def draw_stun(draw, primary, secondary):
    """Stun - Lightning bolt"""
    cx, cy = CENTER, CENTER
    points = [
        (cx, cy-10),    # top
        (cx+4, cy-2),   # right upper
        (cx+2, cy-2),   # inner right
        (cx+6, cy+10),  # bottom right
        (cx-2, cy+2),   # inner left
        (cx-4, cy-2),   # left upper
    ]
    draw.polygon(points, fill=primary)

def draw_frozen(draw, primary, secondary):
    """Frozen - Snowflake"""
    cx, cy = CENTER, CENTER
    for angle in [0, 60, 120, 180, 240, 300]:
        rad = math.radians(angle)
        x = cx + math.cos(rad) * 8
        y = cy + math.sin(rad) * 8
        draw.line([(cx, cy), (x, y)], fill=primary, width=STROKE)
        rad2 = math.radians(angle + 20)
        x2 = cx + math.cos(rad) * 6 + math.cos(rad2) * 3
        y2 = cy + math.sin(rad) * 6 + math.sin(rad2) * 3
        draw.line([(cx + math.cos(rad) * 6, cy + math.sin(rad) * 6), (x2, y2)], fill=primary, width=1)

def draw_rooted(draw, primary, secondary):
    """Rooted - Plant with roots"""
    cx, cy = CENTER, CENTER
    draw.line([(cx, cy-8), (cx, cy+8)], fill=primary, width=STROKE)
    draw.line([(cx, cy+8), (cx-6, cy+10)], fill=primary, width=STROKE)
    draw.line([(cx, cy+8), (cx+6, cy+10)], fill=primary, width=STROKE)
    draw.line([(cx, cy+4), (cx-4, cy+6)], fill=primary, width=STROKE)
    draw.line([(cx, cy+4), (cx+4, cy+6)], fill=primary, width=STROKE)
    draw.ellipse([(cx-6, cy-4), (cx-2, cy)], fill=secondary)
    draw.ellipse([(cx+2, cy-4), (cx+6, cy)], fill=secondary)

# ════════════════════════════════════════════
# ICON DEFINITIONS
# ════════════════════════════════════════════

ICONS_BUFF = [
    ("fury-max", draw_fury_max, "#FF6B35", "#FFA500"),
    ("warrior-fury", draw_warrior_fury, "#DC143C", "#8B0000"),
    ("shield-buff", draw_shield_buff, "#4169E1", "#87CEEB"),
    ("pain-share", draw_pain_share, "#FF69B4", "#FFB6C1"),
    ("tenacity", draw_tenacity, "#FFD700", "#FFA500"),
    ("bloodthirst", draw_bloodthirst, "#8B0000", "#FF0000"),
    ("sanctuary", draw_sanctuary, "#FFD700", "#FFF8DC"),
    ("summon-duration", draw_summon_duration, "#708090", "#A9A9A9"),
    ("exalt", draw_exalt, "#32CD32", "#90EE90"),
    ("spearwall", draw_spearwall, "#4169E1", "#1E90FF"),
    ("counter", draw_counter, "#FF8C00", "#FF4500"),
    ("medium", draw_medium, "#9370DB", "#DDA0DD"),
    ("enhanced-trap", draw_enhanced_trap, "#696969", "#808080"),
    ("mana-surge", draw_mana_surge, "#1E90FF", "#00BFFF"),
    ("divine-grace", draw_divine_grace, "#FFD700", "#FFFACD"),
    ("iron-phalanx", draw_iron_phalanx, "#696969", "#2F4F4F"),
    ("empower", draw_empower, "#FF6347", "#FFB6C1"),
]

ICONS_DEBUFF = [
    ("disarmed", draw_disarmed, "#808080", "#A9A9A9"),
    ("curse", draw_curse, "#2F4F4F", "#000000"),
    ("bleed", draw_bleed, "#8B0000", "#DC143C"),
    ("stun", draw_stun, "#FFD700", "#FFA500"),
    ("frozen", draw_frozen, "#00BFFF", "#00CED1"),
    ("rooted", draw_rooted, "#228B22", "#32CD32"),
]

# ════════════════════════════════════════════
# GENERATE ALL ICONS
# ════════════════════════════════════════════

if __name__ == "__main__":
    print("\n🎨 Generating Tactical Clarity Status Icons...\n")

    for name, draw_func, primary, secondary in ICONS_BUFF:
        create_icon(name, draw_func, hex_to_rgb(primary), hex_to_rgb(secondary))

    for name, draw_func, primary, secondary in ICONS_DEBUFF:
        create_icon(name, draw_func, hex_to_rgb(primary), hex_to_rgb(secondary))

    print(f"\n✅ Successfully created {len(ICONS_BUFF) + len(ICONS_DEBUFF)} icons!")
    print(f"📁 Location: {OUTPUT_DIR.absolute()}\n")
