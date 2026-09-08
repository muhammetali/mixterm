#!/usr/bin/env python3
"""Draws the application icon.

Kept in the repository because the icon is generated, not painted: every
value below comes from a rule, and the next person to change one needs to
see which rule they are trading against.

The rules, and what the previous icon measured against them:

* **One hero, everything else flat.** The old icon drew a whole terminal
  window — title bar, three traffic lights, a wi-fi glyph, a cursor — none
  of which survives being 32 pixels wide in a Dock. It now draws one thing,
  the prompt, large enough to read at any size.
* **Light is a hero, not a texture.** Old icon: 1.05% of pixels above 200
  brightness, mean brightness 29/255. That is not restraint, it is an empty
  frame. There is now a single light source, behind the glyph, and nothing
  else glows.
* **Never pure black.** The old icon bottomed out at 0. Pure black reads as
  a hole rather than a shadow, and is one of the more reliable tells of an
  icon nobody measured.
* **Value carries the hierarchy.** Ground, plate and glyph separate by
  luminance, so the icon still reads with hue stripped out.
* **Readable at 48px.** The constraint that kills detail for its own sake.
  The old icon scored 2.6 on a 48px round-trip against a ceiling of 6 —
  it had headroom it never spent, which is why it looked bare rather than
  busy.
* **Full-bleed, no alpha.** macOS 26 composites any transparent region of
  an icon over its own light backing plate, so a transparent corner shows
  up as a white rim. The canvas is opaque edge to edge and the system
  applies its own rounding.

Run: python3 tool/generate_icon.py
"""

import colorsys
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024

# The interface's own identity hue, sampled from the palette in
# lib/utils/design_tokens.dart so the icon and the app agree.
ACCENT_HUE = 170 / 360
# The neutral family the app's surfaces are built from.
GROUND_HUE = 214 / 360


def tone(hue: float, sat: float, light: float) -> tuple[int, int, int]:
    r, g, b = colorsys.hls_to_rgb(hue, light, sat)
    return round(r * 255), round(g * 255), round(b * 255)


def radial_ground(size: int) -> Image.Image:
    """A lit stage rather than a flat fill.

    A single colour behind the subject is what makes an icon look printed
    on rather than lit. The pool is off-centre and above, so the light has
    a direction — the same reason a photographed object looks solid and a
    flat-shaded one does not.
    """
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy = size * 0.5, size * 0.36
    # Reaches past the corner so the falloff never bands inside the canvas.
    far = math.hypot(size * 0.5, size * 0.64)

    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / far
            d = min(1.0, d)
            # Smoothstep: a linear ramp reads as a gradient, this reads as
            # light.
            t = d * d * (3 - 2 * d)
            # 17% down to 7% lightness. Never 0 — see the module docstring.
            light = 0.17 - 0.10 * t
            sat = 0.30 - 0.06 * t
            px[x, y] = tone(GROUND_HUE, sat, light)
    return img


def add_glow(base: Image.Image, mask: Image.Image, colour, spread: int, strength: float):
    """The icon's one light source.

    Budgeted deliberately: this is called once. A glow on every element is
    what makes an icon look like a template — light means something only
    where it is scarce.
    """
    glow = Image.new("RGB", base.size, colour)
    blurred = mask.filter(ImageFilter.GaussianBlur(spread))
    blurred = blurred.point(lambda v: int(v * strength))
    base.paste(glow, (0, 0), blurred)


def draw_prompt(size: int) -> tuple[Image.Image, Image.Image]:
    """The hero: a chevron and an underscore, drawn as geometry.

    Not text — a font would put the icon at the mercy of whatever is
    installed, and hinting would soften the strokes at exactly the sizes
    that matter.
    """
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)

    # Sized so the mark occupies about 58% of the canvas. The first
    # attempt filled 40% and measured as a small shape adrift in a large
    # frame — the icon looked timid rather than restrained.
    stroke = size * 0.105
    arm = size * 0.185
    # The underscore sits close and runs long. At 32px the first version's
    # short, distant bar read as a dot rather than a cursor, so the mark
    # said "chevron and a dot" instead of "prompt".
    gap = size * 0.035
    under_len = size * 0.26

    # The group is laid out from its own left edge and then centred by
    # measurement, rather than by eyeballing offsets. The first version
    # hardcoded positions and landed with its ink centred at x=55.9%,
    # visibly right of the frame.
    group_w = arm + gap + under_len + stroke
    left = (size - group_w) / 2
    apex_x = left + arm + stroke / 2
    mid_y = size * 0.47

    d.line(
        [(apex_x - arm, mid_y - arm), (apex_x, mid_y), (apex_x - arm, mid_y + arm)],
        fill=255,
        width=int(stroke),
        joint="curve",
    )
    # Round the chevron's ends: a cut-off stroke looks broken at small
    # sizes, where the join is only a few pixels across.
    r = stroke / 2
    for cx, cy in [(apex_x - arm, mid_y - arm), (apex_x - arm, mid_y + arm), (apex_x, mid_y)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    # The underscore: the cursor, and the thing that says "prompt" rather
    # than "greater than".
    ux0 = apex_x + gap
    ux1 = ux0 + under_len
    # On the same baseline as the chevron's lower arm, which is where an
    # underscore sits after a `>` in any terminal.
    uy = mid_y + arm
    d.rounded_rectangle([ux0, uy - stroke / 2, ux1, uy + stroke / 2], radius=r, fill=255)

    return mask, mask


def build() -> Image.Image:
    # Supersample: the strokes are diagonal and the difference between a
    # crisp icon and a soft one is entirely in how they are resolved.
    s = SIZE * 2
    img = radial_ground(s)
    mask, _ = draw_prompt(s)

    # One glow, behind the glyph, in the accent hue.
    # Softer and wider than the first attempt, which read as a neon tube
    # rather than a lit object. A glow should say where the light is, not
    # become the subject.
    add_glow(img, mask, tone(ACCENT_HUE, 0.70, 0.42), spread=int(s * 0.055), strength=0.40)

    # The glyph, then a brighter core inside it. Without the core the
    # image has no peak: the first version put 0.48% of pixels above 200
    # brightness — dimmer than the icon it replaced, while claiming light
    # as the hero.
    glyph = Image.new("RGB", (s, s), tone(ACCENT_HUE, 0.70, 0.58))
    img.paste(glyph, (0, 0), mask)

    core = mask.filter(ImageFilter.GaussianBlur(s * 0.012))
    core = core.point(lambda v: 255 if v > 245 else 0)
    img.paste(Image.new("RGB", (s, s), tone(ACCENT_HUE, 0.55, 0.86)), (0, 0),
              core.filter(ImageFilter.GaussianBlur(s * 0.006)))

    # A highlight along the upper-left of each stroke, where the light is
    # coming from. This is the difference between a shape and an object.
    lit = mask.filter(ImageFilter.GaussianBlur(s * 0.004))
    shifted = Image.new("L", (s, s), 0)
    shifted.paste(lit, (-int(s * 0.006), -int(s * 0.006)))
    edge = Image.new("L", (s, s), 0)
    edge.paste(shifted, (0, 0))
    highlight = Image.eval(edge, lambda v: v)
    inner = Image.new("RGB", (s, s), tone(ACCENT_HUE, 0.55, 0.80))
    # Only where the shifted copy overlaps the glyph: a rim, not a second
    # glyph.
    rim = Image.new("L", (s, s), 0)
    rim_px, m_px, h_px = rim.load(), mask.load(), highlight.load()
    for y in range(0, s, 1):
        for x in range(0, s, 1):
            if m_px[x, y] > 128 and h_px[x, y] < 128:
                rim_px[x, y] = 200
    img.paste(inner, (0, 0), rim.filter(ImageFilter.GaussianBlur(s * 0.002)))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    icon = build()

    # Every place a packaged icon lives. Leaving one out does not fail
    # anything: the file stays where it was, the build picks it up, and the
    # only symptom is one platform quietly showing the previous design.
    #
    # That happened. The redesign wrote only the macOS targets, so Linux kept
    # the old icon through six releases — measurably so, with a darkest point
    # of 0 where the redesign had removed pure black, and 0.12% of pixels
    # bright against 4.67%. Nobody saw it until the snap's launcher started
    # working and showed the wrong picture.
    #
    # The sizes are the ones each packaging actually installs: see the
    # `for size in ...` loops in scripts/build_deb.sh and snap/snapcraft.yaml.
    targets = {
        "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_%d.png": [
            16, 32, 64, 128, 256, 512, 1024
        ],
        "assets/icons/macos/app_icon_%d.png": [16, 32, 64, 128, 256, 512],
        "assets/icons/linux/mixterm_%d.png": [
            16, 24, 32, 48, 64, 128, 256, 512
        ],
    }
    for pattern, sizes in targets.items():
        for size in sizes:
            out = ROOT / (pattern % size)
            out.parent.mkdir(parents=True, exist_ok=True)
            icon.resize((size, size), Image.LANCZOS).save(out)

    (ROOT / "assets/icons/icon_master.png").parent.mkdir(parents=True, exist_ok=True)
    icon.save(ROOT / "assets/icons/icon_master.png")
    print(f"wrote icon at {SIZE}px and every packaged size")


if __name__ == "__main__":
    main()
