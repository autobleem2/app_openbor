#!/usr/bin/env python3
"""The branding the App's OpenBOR shows.

    tools/make_branding.py <openbor engine dir>   embed the two pictures in the engine (ci/build.sh runs it on the
                                                  build's copy of the source; the standard library only)
    tools/make_branding.py --art                  draw the checked-in pictures again (needs Pillow)

The pictures, in resources/:
- branding/AutoBleem_Menu_480x272.png is the 2019 PlayStation Classic port's menu background (the OpenBOR and
  AutoBleem logos on an abstract backdrop) - kept as it was.
- branding/AutoBleem_Logo_480x272.png, the start-up logo, is drawn by --art: OpenBOR's own logo
  (engine/resources/OpenBOR_Logo_480x272.png, the engine's BSD-licensed art) with the AutoBleem logo, cut from the
  menu background, in its lower right corner. The 2019 logo is not used: it was a collage of commercial
  fighting-game characters (the owner's decision, 2026-09-25).
- app/icon.png (256x219, what the launcher's Apps set shows) is drawn by --art too: the flame and the "Open Beats
  of Rage" lettering, the left of OpenBOR's own logo, cut to the icon's shape.

The embedding writes the two branding pictures into the engine's resources/ as C headers in the layout of its own
makeheader.pl - `static const struct { size_t size; unsigned char data[N]; } <name> = { N, { ... } };` - where
patches/openbor/0002-autobleem-branding.patch includes them.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BRANDING = os.path.join(ROOT, "resources", "branding")
MENU = os.path.join(BRANDING, "AutoBleem_Menu_480x272.png")
LOGO = os.path.join(BRANDING, "AutoBleem_Logo_480x272.png")
UPSTREAM_LOGO = os.path.join(ROOT, "upstream", "openbor", "engine", "resources", "OpenBOR_Logo_480x272.png")
AUTOBLEEM_BOX = (366, 101, 449, 157)  # the AutoBleem logo in the menu background


def header(name, data):
    lines = ["#ifndef _%s_H_" % name.upper(), "#define _%s_H_" % name.upper(), "",
             "static const struct {", "\tsize_t size;", "\tunsigned char data[%d];" % len(data),
             "} %s = {" % name, "\t%d," % len(data), "\t{"]
    for i in range(0, len(data), 24):
        lines.append("\t\t" + ",".join("0x%02x" % b for b in data[i:i + 24]) + ",")
    lines += ["\t}", "};", "", "#endif", ""]
    return "\n".join(lines)


def embed(engine):
    out_dir = os.path.join(engine, "resources")
    for name, path in (("autobleem_logo_480x272_png", LOGO), ("autobleem_menu_480x272_png", MENU)):
        with open(path, "rb") as f:
            data = f.read()
        out = os.path.join(out_dir, name.replace("_png", ".png") + ".h")
        with open(out, "w", encoding="ascii") as f:
            f.write(header(name, data))
        print(out, len(data), "bytes")


def art():
    from PIL import Image

    base = Image.open(UPSTREAM_LOGO).convert("RGBA")
    logo = base.copy()
    mark = Image.open(MENU).convert("RGBA").crop(AUTOBLEEM_BOX)
    mark = mark.resize((mark.width * 5 // 4, mark.height * 5 // 4), Image.LANCZOS)
    x, y = logo.width - mark.width - 10, logo.height - mark.height - 10
    # a soft plate under it, so it reads on the light sky of OpenBOR's picture
    plate = Image.new("RGBA", (mark.width + 8, mark.height + 8), (20, 40, 90, 170))
    logo.alpha_composite(plate, (x - 4, y - 4))
    logo.alpha_composite(mark, (x, y))
    logo.save(LOGO, optimize=True)
    print(LOGO)

    width = round(base.height * 256 / 219)
    icon = os.path.join(ROOT, "resources", "app", "icon.png")
    base.crop((0, 0, width, base.height)).resize((256, 219), Image.LANCZOS).save(icon, optimize=True)
    print(icon)


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    if argv[1] == "--art":
        art()
    else:
        embed(argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
