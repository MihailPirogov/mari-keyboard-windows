# Рисует HTML для картинок сайта (клавиатура, OG-картинка); рендер — headless Chrome
import json, html, base64
L = json.load(open('src/layout_original.json', encoding='utf-8'))
rows5 = {r[0]: r[2] for t in L['tables'] if t['nmod'] == 5 for r in t['rows']}
MARI = set('ӓӒӧӦӱӰӹӸҥҤ')
kb = [[0xC0,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x30,0xBD,0xBB,'Backspace'],
      ['Tab',0x51,0x57,0x45,0x52,0x54,0x59,0x55,0x49,0x4F,0x50,0xDB,0xDD,0xDC],
      ['Caps Lock',0x41,0x53,0x44,0x46,0x47,0x48,0x4A,0x4B,0x4C,0xBA,0xDE,'Enter'],
      ['Shift',0x5A,0x58,0x43,0x56,0x42,0x4E,0x4D,0xBC,0xBE,0xBF,'Shift '],
      ['Ctrl','Win','Alt','SPACE','AltGr','Win ','Ctrl ']]
WIDE = {'Backspace':2.0,'Tab':1.5,0xDC:1.5,'Caps Lock':1.8,'Enter':2.2,'Shift':2.3,'Shift ':2.7,
        'Ctrl':1.4,'Win':1.2,'Alt':1.2,'SPACE':6.6,'AltGr':1.4,'Win ':1.2,'Ctrl ':1.4}
def ch(w): return '' if w >= 0xF000 or w < 0x20 else html.escape(chr(w))
flag = base64.b64encode(open('res/flag960.png','rb').read()).decode()
CSS = '''*{box-sizing:border-box}body{margin:0;font-family:"DejaVu Sans","Segoe UI",sans-serif;color:#e6e8ee;background:#0d0f14;
background-image:radial-gradient(60rem 40rem at 15% 10%,rgba(88,101,242,.22),transparent 60%),radial-gradient(50rem 35rem at 90% 90%,rgba(0,190,170,.18),transparent 60%)}
.kb{display:inline-block;padding:22px;border-radius:22px;background:rgba(255,255,255,.035);border:1px solid rgba(255,255,255,.09)}
.row{display:flex;gap:8px;margin-bottom:8px}.k{height:78px;border-radius:11px;background:#1a1e29;border:1px solid #2a3040;position:relative;box-shadow:0 3px 0 #0a0c11}
.k span{position:absolute}.b{left:10px;bottom:6px;font-size:30px;color:#f1f3f8}.s{left:10px;top:5px;font-size:17px;color:#8b93a7}
.a{right:10px;bottom:8px;font-size:22px;color:#7fe9dc}.as{right:10px;top:6px;font-size:17px;color:#5fbfb4}
.m{background:linear-gradient(135deg,#3b44b8,#008f80);border-color:#7fe9dc;box-shadow:0 0 18px rgba(0,190,170,.45),0 3px 0 #05332e}
.m .a{color:#fff;font-size:30px;font-weight:bold}.m .as{color:#d8fff9}.m .b{color:#e6e8ee}
.f{display:flex;align-items:center;justify-content:center;font-size:17px;color:#8b93a7}.f.g{color:#7fe9dc;font-weight:bold;border-color:#00beaa}'''
def keyboard(unit=78):
    o = ['<div class="kb">']
    for r in kb:
        o.append('<div class="row">')
        for k in r:
            w = int(unit * WIDE.get(k, 1.0) + 8 * (WIDE.get(k, 1.0) - 1))
            if isinstance(k, str):
                lab = '' if k == 'SPACE' else k.strip()
                o.append('<div class="k f%s" style="width:%dpx">%s</div>' % (' g' if k == 'AltGr' else '', w, lab))
            else:
                v = rows5[k]; m = ' m' if chr(v[3]) in MARI else ''
                s = ch(v[1]) if ch(v[1]).lower() != ch(v[0]) else ''
                a = ch(v[3]) if v[3] != v[0] else ''
                as_ = ch(v[4]) if (v[4] != v[1] and ch(v[4]).lower() != ch(v[3])) else ''
                o.append('<div class="k%s" style="width:%dpx"><span class="s">%s</span><span class="b">%s</span><span class="as">%s</span><span class="a">%s</span></div>' % (m, w, s, ch(v[0]).upper() if ch(v[0]).isalpha() else ch(v[0]), as_, a))
        o.append('</div>')
    o.append('</div>'); return ''.join(o)
page = lambda body, extra='': '<!DOCTYPE html><html><head><meta charset="utf-8"><style>%s%s</style></head><body>%s</body></html>' % (CSS, extra, body)
# 1) клавиатура
open('site/render/keyboard.html','w',encoding='utf-8').write(page(
  '<div style="padding:34px 40px"><div style="font-size:30px;font-weight:bold;margin-bottom:6px">Марийская раскладка клавиатуры</div>'
  '<div style="font-size:19px;color:#aab1c3;margin-bottom:22px">Русская основа ЙЦУКЕН · марийские буквы — <b style="color:#7fe9dc">AltGr</b> (правый Alt) + клавиша, заглавные — AltGr + Shift</div>'
  + keyboard() + '<div style="margin-top:18px;font-size:19px;color:#aab1c3"><span style="display:inline-block;width:18px;height:18px;border-radius:5px;background:linear-gradient(135deg,#3b44b8,#008f80);vertical-align:-3px"></span>&nbsp; ӓ ӧ ӱ ӹ ҥ — марийские буквы &nbsp;&nbsp; <span style="color:#7fe9dc">бирюзовым</span> — символ с AltGr</div></div>'))
# 2) крупно: 5 марийских букв
cells = ''.join('<div style="width:200px;height:220px;border-radius:24px;background:linear-gradient(135deg,#3b44b8,#008f80);display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 0 30px rgba(0,190,170,.35)"><div style="font-size:96px;font-weight:bold;color:#fff">%s</div><div style="font-size:24px;color:#d8fff9">AltGr + %s</div></div>' % (a, b) for a, b in zip('ӓӧӱӹҥ', 'аоуын'))
open('site/render/letters.html','w',encoding='utf-8').write(page('<div style="padding:50px;display:flex;gap:28px">%s</div>' % cells))
# 3) OG 1200x630
open('site/render/og.html','w',encoding='utf-8').write(page(
 '<div style="width:1200px;height:630px;padding:60px 70px;position:relative;overflow:hidden">'
 '<img src="data:image/png;base64,%s" style="width:210px;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.5)">'
 '<div style="font-size:66px;font-weight:bold;line-height:1.05;margin-top:34px;background:linear-gradient(90deg,#fff,#b9c0ff 55%%,#7fe9dc);-webkit-background-clip:text;color:transparent">Марийская раскладка<br>клавиатуры 3.1</div>'
 '<div style="font-size:30px;color:#aab1c3;margin-top:20px">Windows 10 и 11 · бесплатно · ӓ ӧ ӱ ӹ ҥ через AltGr</div>'
 '<div style="position:absolute;right:70px;bottom:24px;font-size:96px;font-weight:bold;color:#7fe9dc;opacity:.9;letter-spacing:10px">ӓӧӱӹҥ</div>'
 '<div style="position:absolute;left:70px;bottom:40px;font-size:24px;color:#6d7488">pirogovlab.ru</div></div>' % flag))
print('ok')
