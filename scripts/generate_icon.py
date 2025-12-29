#!/usr/bin/env python3
"""
MixTerm Icon Generator v3
Clean, modern terminal icon
"""

from PIL import Image, ImageDraw, ImageFilter
import os

def create_rounded_rect_mask(size, padding, radius):
    """Create a mask for rounded rectangle."""
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)

    x1, y1 = padding, padding
    x2, y2 = size[0] - padding, size[1] - padding

    # Main rectangles
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=255)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=255)

    # Corners
    draw.ellipse([x1, y1, x1 + 2*radius, y1 + 2*radius], fill=255)
    draw.ellipse([x2 - 2*radius, y1, x2, y1 + 2*radius], fill=255)
    draw.ellipse([x1, y2 - 2*radius, x1 + 2*radius, y2], fill=255)
    draw.ellipse([x2 - 2*radius, y2 - 2*radius, x2, y2], fill=255)

    return mask


def create_mixterm_icon(size=1024, rounded=True):
    """
    Create a clean MixTerm icon.
    rounded: If True, applies rounded corners (Linux). If False, full square (macOS).
    """

    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dimensions
    padding = int(size * 0.05)
    radius = int(size * 0.18)

    # Colors
    bg_color = (24, 29, 37)
    surface_color = (15, 19, 25)
    title_bar = (32, 38, 46)
    teal = (45, 212, 191)
    cyan = (103, 232, 249)
    red = (255, 95, 86)
    yellow = (255, 189, 46)
    green = (39, 201, 63)

    # === Background ===
    bg_layer = Image.new('RGBA', (size, size), (*bg_color, 255))
    
    if rounded:
        mask = create_rounded_rect_mask((size, size), padding, radius)
        bg_masked = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        bg_masked.paste(bg_layer, mask=mask)
        img = Image.alpha_composite(img, bg_masked)
        
        # === Subtle border (Only for rounded icons) ===
        border_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        border_draw = ImageDraw.Draw(border_layer)

        # Draw border using arc approximation
        bx1, by1 = padding, padding
        bx2, by2 = size - padding, size - padding

        border_draw.rounded_rectangle([bx1, by1, bx2, by2], radius=radius,
                                      outline=(*teal, 40), width=3)
        img = Image.alpha_composite(img, border_layer)
        draw = ImageDraw.Draw(img)
    else:
        # Full bleed for macOS
        img.paste(bg_layer)
        # Re-initialize draw object for subsequent operations
        draw = ImageDraw.Draw(img)


    # === Inner terminal window ===
    term_pad = int(size * 0.12)
    tx1, ty1 = term_pad, term_pad
    tx2, ty2 = size - term_pad, size - term_pad
    term_radius = int(size * 0.10)

    # Terminal background
    draw.rounded_rectangle([tx1, ty1, tx2, ty2], radius=term_radius,
                          fill=surface_color)

    # === Title bar ===
    title_h = int(size * 0.10)

    # Title bar background (needs manual corners since rounded_rectangle
    # doesn't support partial rounding)
    title_y2 = ty1 + title_h

    # Fill title area
    draw.rectangle([tx1, ty1 + term_radius, tx2, title_y2], fill=title_bar)
    draw.rectangle([tx1 + term_radius, ty1, tx2 - term_radius, title_y2], fill=title_bar)

    # Top-left corner
    draw.ellipse([tx1, ty1, tx1 + term_radius*2, ty1 + term_radius*2], fill=title_bar)
    # Top-right corner
    draw.ellipse([tx2 - term_radius*2, ty1, tx2, ty1 + term_radius*2], fill=title_bar)

    # === Window buttons ===
    btn_r = int(size * 0.020)
    btn_y = ty1 + title_h // 2
    btn_spacing = int(size * 0.052)
    btn_x = tx1 + int(size * 0.065)

    for i, color in enumerate([red, yellow, green]):
        cx = btn_x + i * btn_spacing
        draw.ellipse([cx - btn_r, btn_y - btn_r, cx + btn_r, btn_y + btn_r], fill=color)

    # === Lock icon (SSH security) ===
    lock_x = tx2 - int(size * 0.08)
    lock_y = btn_y
    lock_w = int(size * 0.028)
    lock_h = int(size * 0.024)

    # Lock body
    draw.rectangle([lock_x - lock_w//2, lock_y - lock_h//4,
                   lock_x + lock_w//2, lock_y + lock_h//2], fill=teal)

    # Lock shackle
    shackle_w = int(lock_w * 0.65)
    draw.arc([lock_x - shackle_w//2, lock_y - lock_h,
             lock_x + shackle_w//2, lock_y],
            0, 180, fill=teal, width=int(size * 0.01))

    # === Terminal Prompt (>_) ===
    prompt_x = tx1 + int(size * 0.10)
    prompt_y = title_y2 + int(size * 0.15)

    # Chevron dimensions
    chev_len = int(size * 0.16)
    chev_half = chev_len // 2
    line_width = int(size * 0.038)

    # Draw chevron with glow
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Glow layers
    for g in range(20, 0, -2):
        alpha = int(25 * (20 - g) / 20)
        offset = g

        # Upper line glow
        glow_draw.line([(prompt_x - offset, prompt_y - offset),
                       (prompt_x + chev_len + offset, prompt_y + chev_half)],
                      fill=(*teal, alpha), width=line_width + g)
        # Lower line glow
        glow_draw.line([(prompt_x - offset, prompt_y + chev_len + offset),
                       (prompt_x + chev_len + offset, prompt_y + chev_half)],
                      fill=(*teal, alpha), width=line_width + g)

    glow = glow.filter(ImageFilter.GaussianBlur(radius=10))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Main chevron lines
    draw.line([(prompt_x, prompt_y), (prompt_x + chev_len, prompt_y + chev_half)],
             fill=teal, width=line_width)
    draw.line([(prompt_x, prompt_y + chev_len), (prompt_x + chev_len, prompt_y + chev_half)],
             fill=teal, width=line_width)

    # Highlight on top edge
    draw.line([(prompt_x + 3, prompt_y + 3),
              (prompt_x + chev_len - 8, prompt_y + chev_half - 3)],
             fill=cyan, width=int(line_width * 0.5))

    # === Cursor ===
    cursor_x = prompt_x + chev_len + int(size * 0.07)
    cursor_y = prompt_y + chev_len - int(size * 0.035)
    cursor_w = int(size * 0.12)
    cursor_h = int(size * 0.035)

    # Cursor glow
    cursor_glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cg_draw = ImageDraw.Draw(cursor_glow)

    for g in range(12, 0, -1):
        alpha = int(60 * (12 - g) / 12)
        cg_draw.rectangle([cursor_x - g, cursor_y - g,
                          cursor_x + cursor_w + g, cursor_y + cursor_h + g],
                         fill=(*cyan, alpha))

    cursor_glow = cursor_glow.filter(ImageFilter.GaussianBlur(radius=5))
    img = Image.alpha_composite(img, cursor_glow)
    draw = ImageDraw.Draw(img)

    # Main cursor
    draw.rectangle([cursor_x, cursor_y, cursor_x + cursor_w, cursor_y + cursor_h],
                  fill=cyan)

    # === Network indicator ===
    net_x = tx2 - int(size * 0.15)
    net_y = ty2 - int(size * 0.14)

    # Signal arcs
    for i in range(3):
        arc_r = int(size * 0.035) + i * int(size * 0.022)
        alpha = 220 - i * 60
        arc_w = int(size * 0.010)

        draw.arc([net_x - arc_r, net_y - arc_r, net_x + arc_r, net_y + arc_r],
                225, 315, fill=(*teal, alpha), width=arc_w)

    # Center dot
    dot_r = int(size * 0.018)
    draw.ellipse([net_x - dot_r, net_y - dot_r, net_x + dot_r, net_y + dot_r],
                fill=cyan)

    return img


def save_all_sizes(output_dir):
    """Save icon in all required sizes and update native project files."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.join(script_dir, '..')
    
    # Native directories
    macos_native_dir = os.path.join(project_root, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    linux_native_file = os.path.join(project_root, 'linux', 'runner', 'mixterm.png')

    macos_sizes = [16, 32, 64, 128, 256, 512, 1024]
    linux_sizes = [16, 24, 32, 48, 64, 128, 256, 512]

    macos_dir = os.path.join(output_dir, 'macos')
    linux_dir = os.path.join(output_dir, 'linux')
    os.makedirs(macos_dir, exist_ok=True)
    os.makedirs(linux_dir, exist_ok=True)

    # === Create macOS icons (Square / Full Bleed) ===
    print("Generating macOS icons (Full Bleed)...")
    icon_macos = create_mixterm_icon(1024, rounded=False)
    
    print("\nmacOS icons:")
    for s in macos_sizes:
        resized = icon_macos.resize((s, s), Image.Resampling.LANCZOS)
        # Save to assets
        resized.save(os.path.join(macos_dir, f'app_icon_{s}.png'))
        # Save to native macOS project
        if os.path.exists(macos_native_dir):
            resized.save(os.path.join(macos_native_dir, f'app_icon_{s}.png'))
            print(f"  {s}x{s} px -> Native & Assets")
        else:
            print(f"  {s}x{s} px -> Assets only (Native dir not found)")

    # === Create Linux icons (Rounded) ===
    print("\nGenerating Linux icons (Rounded)...")
    icon_linux = create_mixterm_icon(1024, rounded=True)

    print("\nLinux icons:")
    for s in linux_sizes:
        resized = icon_linux.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(linux_dir, f'mixterm_{s}.png'))
        print(f"  {s}x{s} px")
        
        # Update Linux native icon (using 512px version as standard)
        if s == 512:
             if os.path.exists(os.path.dirname(linux_native_file)):
                resized.save(linux_native_file)
                print(f"  -> Updated linux/runner/mixterm.png")

    # Save Master Icon (Rounded)
    icon_linux.save(os.path.join(output_dir, 'icon_master.png'))
    print("\nMaster icon (1024x1024) saved")


def main():
    print("=" * 45)
    print("   MixTerm Icon Generator")
    print("=" * 45)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, '..', 'assets', 'icons')
    os.makedirs(output_dir, exist_ok=True)

    save_all_sizes(output_dir)

    print("\n" + "=" * 45)
    print("   Done!")
    print("=" * 45)


if __name__ == '__main__':
    main()
