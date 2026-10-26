#!/usr/bin/env python3
"""Draw the README images from dotfiles.conf: banner.png and palette.png next to this file.

    assets/readme/render.py

Colors and font come from `dotfiles list` (the resolved dotfiles.conf), so after changing
the palette or the accent, run this again and the README follows the theme. GitHub shows
images without the reader's fonts: the text is drawn here with the real Nerd Font, at
twice the display size so it stays sharp. Needs python3-Pillow and fontconfig (fc-match).
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.realpath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
S = 2          # image pixels per CSS pixel
WIDTH = 830    # the README column on GitHub (CSS pixels)

# Nerd Font glyphs (escapes: Private Use characters get lost in some editors)
MUSIC, WIFI, SHIELD, BT = "\U000F0387", "\U000F05A9", "\U000F099D", "\U000F00AF"
VOLUME, BRIGHT, CPU, MEM = "\U000F057E", "\U000F00E0", "\uF4BC", "\uEFC5"
BATTERY, BRANCH = "\U000F0082", "\uE0A0"


def theme():
    out = subprocess.run([os.path.join(REPO, "scripts", "dotfiles"), "list"],
                         capture_output=True, text=True, check=True).stdout
    vals = {}
    for line in out.splitlines():
        key, _, val = line.partition(" ")
        vals[key] = val.strip()
    return vals


def font_file(family, style):
    r = subprocess.run(["fc-match", "-f", "%{file}", f"{family}:style={style}"],
                       capture_output=True, text=True, check=False)
    path = r.stdout.strip()
    if r.returncode != 0 or not path.lower().endswith((".ttf", ".otf")):
        sys.exit(f"render.py: font {family} {style} not found (fc-match)")
    return path


class Fonts:
    def __init__(self, family):
        self.regular = font_file(family, "Regular")
        self.bold = font_file(family, "Bold")
        if self.bold == self.regular and family.endswith(" Nerd Font"):
            # often only the Regular Nerd Font is installed: bold text (no icons) can use
            # the plain family, e.g. JetBrains Mono Bold
            plain = font_file(family[:-len(" Nerd Font")], "Bold")
            if "bold" in os.path.basename(plain).lower():
                self.bold = plain

    def get(self, size, bold=False):
        return ImageFont.truetype(self.bold if bold else self.regular, round(size * S))


def run(d, x, y, h, parts, font, bold=None):
    """Draw text runs on a monospace grid: [(text, fg, bg or None[, bold])]. Returns the end x.
    Every character takes one cell (Nerd Font icons too, they are only drawn wider)."""
    cw = font.getlength("M")
    asc, desc = font.getmetrics()
    for part in parts:
        text, fg, bg = part[:3]
        f = bold if (len(part) > 3 and part[3] and bold) else font
        w = cw * len(text)
        if bg:
            d.rectangle([round(x), y, round(x + w) - 1, y + h - 1], fill=bg)
        if text.startswith("\u258c"):
            # the accent bar: the left half of the cell, full height (as in the terminal)
            d.rectangle([round(x), y, round(x + cw / 2) - 1, y + h - 1], fill=fg)
            text, x, w = " " + text[1:], x, w
        d.text((x, y + (h - asc - desc) / 2), text, font=f, fill=fg)
        x += w
    return x


def banner(t, fonts):
    W, H = WIDTH * S, 262 * S
    img = Image.new("RGB", (W, H), t["bg"])
    d = ImageDraw.Draw(img)

    # ── polybar: workspaces left, capsules right, the clock as accent block ──
    bar_h, bar_font = 28 * S, fonts.get(11.5)
    run(d, 0, 0, bar_h, [("  1  ", t["on_accent"], t["accent"]),
                         ("  2  ", t["muted"], None), ("  3  ", t["muted"], None)], bar_font)
    gap = (" ", t["bg"], None)
    sf = t["surface"]
    right = [
        (" ", None, sf), (MUSIC + " ", t["accent"], sf), ("Golden Brown ", t["fg"], sf), gap,
        (" ", None, sf), (WIFI + "  ", t["aqua_hi"], sf), ("Unimatrix ", t["fg"], sf),
        (" ", None, sf), (SHIELD + "  ", t["green_hi"], sf), ("home ", t["fg"], sf),
        (" ", None, sf), (BT + " ", t["muted"], sf), gap,
        (" ", None, sf), (VOLUME + "  ", t["blue_hi"], sf), ("55% ", t["fg"], sf),
        (" ", None, sf), (BRIGHT + "  ", t["yellow_hi"], sf), ("80% ", t["fg"], sf), gap,
        (" ", None, sf), (CPU + "  ", t["aqua_hi"], sf), ("12% ", t["fg"], sf),
        (" ", None, sf), (MEM + "  ", t["purple_hi"], sf), ("31% ", t["fg"], sf), gap,
        (" ", None, sf), (BATTERY + " ", t["yellow_hi"], sf), ("87% ", t["fg"], sf), gap,
        ("  20:15  ", t["on_accent"], t["accent"]),
    ]
    cw = bar_font.getlength("M")
    width = cw * sum(len(p[0]) for p in right)
    run(d, W - width, 0, bar_h, right, bar_font)

    # ── title ──
    x0 = 36 * S
    title = fonts.get(44, bold=True)
    ty = 62 * S
    asc, desc = title.getmetrics()
    d.rectangle([x0, ty + 8 * S, x0 + 7 * S - 1, ty + asc + desc - 8 * S], fill=t["accent"])
    d.text((x0 + 20 * S, ty), "dotfiles", font=title, fill=t["fg"])
    sub = fonts.get(13.5)
    d.text((x0 + 22 * S, ty + 62 * S), "i3  ·  polybar  ·  rofi  ·  dunst  ·  alacritty  ·  neovim  ·  tmux",
           font=sub, fill=t["subtle"])
    d.text((x0 + 22 * S, ty + 84 * S), "one palette, one accent, sharp corners, a Nerd Font everywhere",
           font=fonts.get(12), fill=t["muted"])

    # ── a notification as dunst draws it (normal urgency frame) ──
    nw, nh = 196 * S, 70 * S
    nx, ny = W - nw - 12 * S, bar_h + 12 * S
    bw = 2 * S
    d.rectangle([nx, ny, nx + nw - 1, ny + nh - 1], fill=t["blue"])
    d.rectangle([nx + bw, ny + bw, nx + nw - 1 - bw, ny + nh - 1 - bw], fill=t["bg"])
    pad = 10 * S
    d.text((nx + pad, ny + 8 * S), SHIELD + "  vpn", font=fonts.get(10.5), fill=t["green_hi"])
    d.text((nx + pad, ny + 25 * S), "Connected", font=fonts.get(12.5, bold=True), fill=t["fg"])
    d.text((nx + pad, ny + 44 * S), "home", font=fonts.get(12.5), fill=t["fg"])

    # ── the shell prompt: user@host bar, directory block, git capsule, mode bar ──
    pf, pb = fonts.get(13.5), fonts.get(13.5, bold=True)
    lh = 23 * S
    py = H - 2 * lh - 22 * S
    run(d, x0, py, lh, [
        ("\u258c", t["accent"], sf), (" floppyist", t["fg"], sf), ("@", t["muted"], sf),
        ("void ", t["subtle"], sf), (" ", None, None),
        (" ~/workspace/", t["on_accent"], t["accent"]), ("dotfiles", t["on_accent"], t["accent"], True),
        (" ", None, t["accent"]), (" ", None, None),
        (" ", None, sf), (BRANCH + " ", t["green_hi"], sf), ("main ", t["fg"], sf),
    ], pf, pb)
    end = run(d, x0, py + lh, lh, [("\u258c", t["accent"], None), (" dotfiles apply", t["fg"], None)], pf)
    d.rectangle([round(end) + 1 * S, py + lh + 3 * S, round(end) + 3 * S - 1, py + 2 * lh - 3 * S],
                fill=t["fg"])   # the insert-mode bar cursor
    return img


def palette(t, fonts):
    rows = [["bg", "surface", "overlay", "fg", "subtle", "muted", "accent", "accent_text"],
            ["red_hi", "orange_hi", "yellow_hi", "green_hi", "aqua_hi", "blue_hi", "purple_hi", "gray"]]
    margin, gap, sw_h = 20 * S, 10 * S, 40 * S
    cols = len(rows[0])
    sw_w = (WIDTH * S - 2 * margin - (cols - 1) * gap) / cols
    row_h = sw_h + 60 * S
    img = Image.new("RGB", (WIDTH * S, 2 * margin + (len(rows) - 1) * row_h + sw_h + 40 * S), t["bg"])
    d = ImageDraw.Draw(img)
    name_f, hex_f = fonts.get(12), fonts.get(11)
    for r, keys in enumerate(rows):
        for c, key in enumerate(keys):
            x = round(margin + c * (sw_w + gap))
            y = margin + r * row_h
            box = [x, y, round(x + sw_w) - 1, y + sw_h - 1]
            d.rectangle(box, fill=t[key], outline=t["overlay"] if key in ("bg", "surface") else None,
                        width=S)
            d.text((x, y + sw_h + 7 * S), key, font=name_f, fill=t["fg"])
            d.text((x, y + sw_h + 24 * S), t[key], font=hex_f, fill=t["muted"])
    return img


def main():
    t = theme()
    fonts = Fonts(t["font"])
    for name, draw in (("banner.png", banner), ("palette.png", palette)):
        path = os.path.join(HERE, name)
        draw(t, fonts).save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    main()
