"""Build an ORIGINAL, unsigned preview font. Never reads/writes Windows fonts or EFI.

Dependencies: fontTools, Pillow, freetype-py. Output is a design prototype, not an installable
replacement: it has neither the original font metrics nor Microsoft's signature.
"""
import hashlib
import json
import math
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw
import freetype

OUT = Path(__file__).resolve().parent / "experimental" / "build" / "boot-indicator"
FIRST, COUNT = 0xE052, 122


def polygon(pen, points):
    pen.moveTo(tuple(round(v) for v in points[0]))
    for point in points[1:]:
        pen.lineTo(tuple(round(v) for v in point))
    pen.closePath()


def circle(pen, x, y, radius):
    polygon(pen, [(x + radius * math.cos(i * math.tau / 24),
                   y + radius * math.sin(i * math.tau / 24)) for i in range(24)])


def line(pen, a, b, width):
    dx, dy = b[0] - a[0], b[1] - a[1]
    scale = width / (2 * math.hypot(dx, dy))
    nx, ny = -dy * scale, dx * scale
    polygon(pen, [(a[0]+nx, a[1]+ny), (a[0]-nx, a[1]-ny),
                  (b[0]-nx, b[1]-ny), (b[0]+nx, b[1]+ny)])


def emblem():
    pen = TTGlyphPen(None)
    # Fixed corner brackets keep every glyph's bounds identical.
    for x, y, dx, dy in [(50, 50, 1, 1), (950, 50, -1, 1),
                          (50, 950, 1, -1), (950, 950, -1, -1)]:
        polygon(pen, [(x,y),(x+dx*70,y),(x+dx*70,y+dy*14),
                      (x+dx*14,y+dy*14),(x+dx*14,y+dy*70),(x,y+dy*70)])
    # The same three-branch emblem geometry used by the existing Arasaka art.
    for a, b in [((500, 265), (500, 660)), ((500, 430), (325, 565)),
                 ((500, 430), (675, 565))]:
        line(pen, a, b, 42)
    for x, y in [(500, 705), (285, 600), (715, 600)]:
        circle(pen, x, y, 62)
    return pen.glyph()


def orbit(index):
    pen = TTGlyphPen(None)
    # Moving segmented sweep, represented entirely by monochrome glyph outlines.
    for trail in range(5):
        angle = math.tau * (index / COUNT - trail / 36) + math.pi / 2
        x, y = 500 + 400 * math.cos(angle), 500 + 400 * math.sin(angle)
        circle(pen, x, y, 23 - trail * 3)
    return pen.glyph()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names = [f"frame{i:03d}" for i in range(COUNT)]
    fb = FontBuilder(1000, isTTF=True)
    orbit_names = [f"orbit{i:03d}" for i in range(COUNT)]
    order = [".notdef", "emblem"] + orbit_names + names
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({FIRST+i: name for i, name in enumerate(names)})
    glyphs = {".notdef": TTGlyphPen(None).glyph(), "emblem": emblem(),
              **{name: orbit(i) for i, name in enumerate(orbit_names)}}
    for i, name in enumerate(names):
        pen = TTGlyphPen(glyphs)
        pen.addComponent("emblem", (1, 0, 0, 1, 0, 0))
        pen.addComponent(orbit_names[i], (1, 0, 0, 1, 0, 0))
        glyphs[name] = pen.glyph()
    fb.setupGlyf(glyphs)
    # FreeType positions the leftmost outline at the LSB. A fixed zero LSB
    # moved the entire emblem whenever the orbit changed the glyph's xMin.
    fb.setupHorizontalMetrics({name: (1000, getattr(fb.font["glyf"][name], "xMin", 0))
                               for name in order})
    fb.setupHorizontalHeader(ascent=1000, descent=0)
    fb.setupNameTable({"familyName": "Arasaka Indicator Prototype", "styleName": "Regular",
                       "uniqueFontIdentifier": "ArasakaIndicatorPrototype-1",
                       "fullName": "Arasaka Indicator Prototype", "psName": "ArasakaIndicatorPrototype"})
    fb.setupOS2(sTypoAscender=1000, sTypoDescender=0, usWinAscent=1000, usWinDescent=0)
    fb.setupPost()
    target = OUT / "arasaka-indicator-PROTOTYPE.ttf"
    fb.save(target)
    font = TTFont(target, checkChecksums=2)
    assert set(font.getBestCmap()) == set(range(FIRST, FIRST+COUNT))
    assert "DSIG" not in font
    for name in names:
        glyph = font["glyf"][name]
        assert 0 <= glyph.xMin < glyph.xMax <= 1000
        assert 0 <= glyph.yMin < glyph.yMax <= 1000
    render_font = freetype.Face(str(target))
    render_font.set_pixel_sizes(0, 150)
    frames = []
    for i in range(COUNT):
        image = Image.new("RGB", (320, 240), "black")
        draw = ImageDraw.Draw(image)
        # Explicit no-hinting avoids FreeType's per-glyph automatic fitting.
        # This verifies the artwork, not the behavior of Windows' boot renderer.
        render_font.load_char(chr(FIRST+i), freetype.FT_LOAD_RENDER | freetype.FT_LOAD_NO_HINTING)
        slot = render_font.glyph
        bitmap = slot.bitmap
        mask = Image.frombytes("L", (bitmap.width, bitmap.rows), bytes(bitmap.buffer), "raw", "L", bitmap.pitch)
        image.paste("white", (85+slot.bitmap_left, 195-slot.bitmap_top), mask)
        draw.text((55, 12), "ARASAKA // INDICATOR STUDY", fill="#ED2438")
        draw.text((65, 220), "PROTOTYPE - NOT INSTALLED", fill="#ED2438")
        frames.append(image)
    hashes = {hashlib.sha256(image.tobytes()).hexdigest() for image in frames}
    assert len(hashes) == COUNT, "Every frame must show a distinct sweep position"
    # This crop covers the stationary trunk/branches, never the moving orbit.
    core_hashes = {hashlib.sha256(image.crop((130, 95, 190, 155)).tobytes()).hexdigest()
                   for image in frames}
    assert len(core_hashes) == 1, "The stationary emblem must not move between frames"
    palette = Image.new("P", (1, 1))
    palette.putpalette([v for i in range(255) for v in (i, i, i)] + [237, 36, 56])
    encoded = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in frames]
    preview = OUT / "indicator-preview-stable.gif"
    encoded[0].save(preview, save_all=True, append_images=encoded[1:],
                    duration=30, loop=0, disposal=2, optimize=False)
    decoded = Image.open(preview)
    decoded_core = set()
    for i in range(decoded.n_frames):
        decoded.seek(i)
        decoded_core.add(hashlib.sha256(decoded.convert("RGB").crop((130, 95, 190, 155)).tobytes()).hexdigest())
    assert decoded.n_frames == COUNT and len(decoded_core) == 1
    report = {"frames": COUNT, "range": "U+E052-U+E0CB", "unique_rendered_frames": len(hashes),
              "installed": False, "signed": False, "preview_timing_only_ms": 30,
              "stationary_core_variants": len(core_hashes), "decoded_gif_core_variants": len(decoded_core),
              "note": "Original standalone font; not a replacement for any Windows font."}
    (OUT / "validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
