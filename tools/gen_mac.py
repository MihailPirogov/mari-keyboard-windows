#!/usr/bin/env python3
"""Генератор марийской раскладки 3.1 для macOS из src/kbdmari.klc.
Создаёт macos/build/Mari.bundle (.keylayout, .icns, Info.plist, InfoPlist.strings),
macos/dist/MariKeyboard-3.1-macOS.zip (bundle + install.command + README) и .pkg, если есть pkgbuild."""
import os, re, io, struct, shutil, subprocess, zipfile, html
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAC = os.path.join(ROOT, "macos")
NAME = "Mari"            # имя файлов
TITLE = "Марийская"      # видимое имя
VERSION = "3.1"
KB_ID = -31310           # уникальный отрицательный id (диапазон -2..-32768)
CRIMSON = (155, 27, 48)  # как в indicator/mari_indicator.c

# Windows scancode -> Mac virtual keycode (ANSI/ISO)
SC2MAC = {0x02:18,0x03:19,0x04:20,0x05:21,0x06:23,0x07:22,0x08:26,0x09:28,0x0a:25,0x0b:29,
 0x0c:27,0x0d:24,0x10:12,0x11:13,0x12:14,0x13:15,0x14:17,0x15:16,0x16:32,0x17:34,0x18:31,
 0x19:35,0x1a:33,0x1b:30,0x1e:0,0x1f:1,0x20:2,0x21:3,0x22:5,0x23:4,0x24:38,0x25:40,0x26:37,
 0x27:41,0x28:39,0x29:50,0x2b:42,0x2c:6,0x2d:7,0x2e:8,0x2f:9,0x30:11,0x31:45,0x32:46,
 0x33:43,0x34:47,0x35:44,0x39:49,0x53:65,0x56:10}
# US QWERTY для слоя Command (чтобы работали Cmd+C/V и т.п.)
US = {18:"1!",19:"2@",20:"3#",21:"4$",23:"5%",22:"6^",26:"7&",28:"8*",25:"9(",29:"0)",27:"-_",24:"=+",
 12:"qQ",13:"wW",14:"eE",15:"rR",17:"tT",16:"yY",32:"uU",34:"iI",31:"oO",35:"pP",33:"[{",30:"]}",
 0:"aA",1:"sS",2:"dD",3:"fF",5:"gG",4:"hH",38:"jJ",40:"kK",37:"lL",41:";:",39:"'\"",50:"`~",42:"\\|",
 6:"zZ",7:"xX",8:"cC",9:"vV",11:"bB",45:"nN",46:"mM",43:",<",47:".>",44:"/?",49:"  ",65:"..",10:"\\|"}
# служебные клавиши (одинаковы во всех слоях)
FIXED = {36:"\r",48:"\t",51:"\x08",53:"\x1b",76:"\x03",117:"\x7f",123:"\x1c",124:"\x1d",125:"\x1f",
 126:"\x1e",115:"\x01",119:"\x04",116:"\x0b",121:"\x0c",114:"\x05",71:"\x1b",
 96:"\x10",97:"\x10",98:"\x10",99:"\x10",100:"\x10",101:"\x10",103:"\x10",105:"\x10",107:"\x10",
 109:"\x10",111:"\x10",113:"\x10",106:"\x10",64:"\x10",79:"\x10",80:"\x10",118:"\x10",120:"\x10",122:"\x10",
 82:"0",83:"1",84:"2",85:"3",86:"4",87:"5",88:"6",89:"7",91:"8",92:"9",67:"*",69:"+",78:"-",75:"/",81:"="}

def parse_klc(path):
    raw = open(path, "rb").read()
    txt = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode("utf-8-sig")
    rows, inlayout = [], False
    for line in txt.splitlines():
        s = line.split("//")[0].strip()
        if s.startswith("LAYOUT"): inlayout = True; continue
        if inlayout:
            if not s: continue
            if re.match(r"^[A-Z_]+$", s): break
            f = s.split()
            if len(f) < 8: continue
            def ch(v):
                if v == "-1": return None
                if v.endswith("@"): raise SystemExit("dead key found: not supported yet: " + v)
                return v if len(v) == 1 else chr(int(v, 16))
            rows.append(dict(sc=int(f[0], 16), vk=f[1], cap=int(f[2]),
                             n=ch(f[3]), s=ch(f[4]), ctl=ch(f[5]), a=ch(f[6]), sa=ch(f[7])))
    return rows

def esc(c):
    if c is None: return None
    o = ord(c)
    if o < 0x20 or o == 0x7f or c in "<>&\"'" : return "&#x%04X;" % o
    return c

def build_maps(rows):
    maps = {i: dict() for i in range(10)}
    for r in rows:
        k = SC2MAC[r["sc"]]
        n, s = r["n"], r["s"]
        a = r["a"] if r["a"] is not None else n   # -1 в слое AltGr -> базовый символ
        sa = r["sa"] if r["sa"] is not None else (r["a"] if r["a"] is not None else s)
        capb = r["cap"] & 1; capa = r["cap"] & 4
        maps[0][k] = n; maps[1][k] = s
        maps[2][k] = s if capb else n; maps[3][k] = n if capb else s
        maps[4][k] = a; maps[5][k] = sa
        maps[6][k] = sa if capa else a; maps[7][k] = a if capa else sa
        us = US[k]; maps[8][k] = us[0]
        c = us[0]
        maps[9][k] = chr(ord(c.upper()) - 64) if c.isalpha() else (r["ctl"] or n)
    for m in maps.values():
        for k, v in FIXED.items(): m.setdefault(k, v)
    return maps

MODMAP = [  # index -> keyMapSelect
 [""], ["anyShift"], ["caps"], ["anyShift caps"],
 ["anyOption"], ["anyShift anyOption"], ["caps anyOption"], ["anyShift caps anyOption"],
 ["command anyShift? caps? anyOption? anyControl?"],
 ["anyControl anyShift? caps? anyOption?"],
]

def keylayout(maps):
    out = ['<?xml version="1.1" encoding="UTF-8"?>',
           '<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">',
           f'<!-- Марийская (луговомарийская) раскладка {VERSION}, (c) Михаил Пирогов. Сгенерировано tools/gen_mac.py -->',
           f'<keyboard group="7" id="{KB_ID}" name="{TITLE}" maxout="1">',
           '  <layouts><layout first="0" last="255" modifiers="mods" mapSet="maps"/></layouts>',
           '  <modifierMap id="mods" defaultIndex="0">']
    for i in range(10):
        out.append(f'    <keyMapSelect mapIndex="{i}">')
        for m in MODMAP[i]: out.append(f'      <modifier keys="{m}"/>')
        out.append('    </keyMapSelect>')
    out.append('  </modifierMap>')
    out.append('  <keyMapSet id="maps">')
    for i in range(10):
        out.append(f'    <keyMap index="{i}">')
        for k in sorted(maps[i]):
            out.append(f'      <key code="{k}" output="{esc(maps[i][k])}"/>')
        out.append('    </keyMap>')
    out += ['  </keyMapSet>', '</keyboard>', '']
    return "\n".join(out)

def icon_png(size):
    sc = 8; S = size * sc
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, int(S*.12), S-1, int(S*.88)], radius=int(S*.16), fill=CRIMSON + (255,))
    font = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf", int(S*.42))
    t = "МАР"; b = d.textbbox((0, 0), t, font=font)
    d.text(((S-(b[2]-b[0]))/2 - b[0], (S-(b[3]-b[1]))/2 - b[1]), t, font=font, fill="white")
    im = im.resize((size, size), Image.LANCZOS)
    bio = io.BytesIO(); im.save(bio, "PNG"); return bio.getvalue(), im

def make_icns(path):
    chunks = b""
    for typ, sz in [(b"icp4", 16), (b"icp5", 32), (b"ic07", 128), (b"ic08", 256), (b"ic09", 512), (b"ic11", 32), (b"ic12", 64)]:
        data, _ = icon_png(sz); chunks += typ + struct.pack(">I", len(data) + 8) + data
    open(path, "wb").write(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)
    icon_png(256)[1].save(os.path.join(MAC, "build", "icon-preview.png"))

INFO = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>ru.pirogov.keyboardlayout.mari</string>
  <key>CFBundleName</key><string>{NAME}</string>
  <key>CFBundleShortVersionString</key><string>{VERSION}</string>
  <key>CFBundleVersion</key><string>{VERSION}</string>
  <key>CFBundleDevelopmentRegion</key><string>ru</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
  <key>KLInfo_{TITLE}</key>
  <dict>
    <key>TISInputSourceID</key><string>ru.pirogov.keyboardlayout.mari.{NAME.lower()}</string>
    <key>TISIntendedLanguage</key><string>mhr</string>
  </dict>
</dict>
</plist>
'''
STRINGS = f'"{TITLE}" = "{TITLE}";\n"CFBundleName" = "{TITLE}";\n'

INSTALL = '''#!/bin/bash
# Установка марийской раскладки 3.1 для текущего пользователя
cd "$(dirname "$0")"
DEST="$HOME/Library/Keyboard Layouts"
mkdir -p "$DEST"
rm -rf "$DEST/Mari.bundle"
cp -R "Mari.bundle" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/Mari.bundle" 2>/dev/null
echo "Готово. Выйдите из системы и войдите снова, затем добавьте раскладку:"
echo "Системные настройки > Клавиатура > Источники ввода > Изменить > + > Другие > Марийская"
'''
UNINSTALL = '''#!/bin/bash
rm -rf "$HOME/Library/Keyboard Layouts/Mari.bundle"
echo "Раскладка удалена. Выйдите из системы и войдите снова."
'''

def main():
    rows = parse_klc(os.path.join(ROOT, "src", "kbdmari.klc"))
    maps = build_maps(rows)
    b = os.path.join(MAC, "build"); shutil.rmtree(b, ignore_errors=True)
    res = os.path.join(b, f"{NAME}.bundle", "Contents", "Resources")
    os.makedirs(os.path.join(res, "ru.lproj")); os.makedirs(os.path.join(res, "en.lproj"))
    open(os.path.join(res, f"{TITLE}.keylayout"), "w", encoding="utf-8").write(keylayout(maps))
    make_icns(os.path.join(res, f"{TITLE}.icns"))
    open(os.path.join(b, f"{NAME}.bundle", "Contents", "Info.plist"), "w", encoding="utf-8").write(INFO)
    for l in ("ru.lproj", "en.lproj"):
        open(os.path.join(res, l, "InfoPlist.strings"), "w", encoding="utf-16").write(STRINGS)
    # дистрибутив
    dist = os.path.join(MAC, "dist"); os.makedirs(dist, exist_ok=True)
    z = os.path.join(dist, f"MariKeyboard-{VERSION}-macOS.zip")
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for dp, _, fs in os.walk(os.path.join(b, f"{NAME}.bundle")):
            for f in fs:
                p = os.path.join(dp, f); zf.write(p, "MariKeyboard/" + os.path.relpath(p, b))
        for nm, body in (("install.command", INSTALL), ("uninstall.command", UNINSTALL)):
            zi = zipfile.ZipInfo("MariKeyboard/" + nm); zi.external_attr = 0o100755 << 16
            zf.writestr(zi, body)
        zf.write(os.path.join(MAC, "README.ru.md"), "MariKeyboard/README.ru.md")
    if shutil.which("pkgbuild"):
        subprocess.check_call(["pkgbuild", "--root", b, "--filter", "icon-preview", "--install-location",
            "/Library/Keyboard Layouts", "--identifier", "ru.pirogov.keyboardlayout.mari", "--version", VERSION,
            os.path.join(dist, f"MariKeyboard-{VERSION}.pkg")])
    print("keys:", len(rows), "->", z)

if __name__ == "__main__":
    main()
