# Схема раскладки (HTML)
import json, os, html
L = json.load(open('src/layout_original.json', encoding='utf-8'))
rows5 = {r[0]: r[2] for t in L['tables'] if t['nmod'] == 5 for r in t['rows']}
MARI = set('ӓӒӧӦӱӰӹӸҥҤ')
kb = [[0xC0,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x30,0xBD,0xBB],
      [0x51,0x57,0x45,0x52,0x54,0x59,0x55,0x49,0x4F,0x50,0xDB,0xDD,0xDC],
      [0x41,0x53,0x44,0x46,0x47,0x48,0x4A,0x4B,0x4C,0xBA,0xDE],
      [0x5A,0x58,0x43,0x56,0x42,0x4E,0x4D,0xBC,0xBE,0xBF]]
def ch(w): return '' if w >= 0xF000 or w < 0x20 else html.escape(chr(w))
out = ['<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8"><title>Марийская раскладка клавиатуры</title><style>',
       'body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#222}.row{display:flex;gap:4px;margin:4px 0}',
       '.k{width:58px;height:58px;border:1px solid #999;border-radius:6px;position:relative;background:#fafafa}',
       '.k span{position:absolute;font-size:15px}.b{left:6px;bottom:4px;font-size:20px!important}.s{left:6px;top:3px;color:#777}',
       '.a{right:6px;bottom:4px;color:#0050b0;font-weight:bold}.as{right:6px;top:3px;color:#0050b0}.m{background:#ffe9a8!important}',
       'table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:4px 10px}</style></head><body>',
       '<h1>Марийская раскладка клавиатуры</h1>',
       '<p>Основа — стандартная русская раскладка (ЙЦУКЕН). Дополнительные буквы вводятся с <b>AltGr</b> (правый Alt или Ctrl+Alt); с Shift — заглавные. Caps Lock действует и на дополнительные буквы.</p>',
       '<p>В углах клавиши: слева — обычный символ и с Shift, справа <span style="color:#0050b0">синим</span> — AltGr и AltGr+Shift. Жёлтым отмечены марийские буквы.</p>']
for i, r in enumerate(kb):
    out.append('<div class="row" style="margin-left:%dpx">' % (i * 22))
    for vk in r:
        w = rows5[vk]; m = ' m' if (chr(w[3]) in MARI) else ''
        out.append('<div class="k%s"><span class="s">%s</span><span class="b">%s</span><span class="as">%s</span><span class="a">%s</span></div>' % (m, ch(w[1]) if ch(w[1]).lower()!=ch(w[0]) else '', ch(w[0]), ch(w[4]) if ch(w[4]).lower()!=ch(w[3]) else '', ch(w[3])))
    out.append('</div>')
out.append('<h2>Марийские буквы</h2><table><tr><th>Буква</th><th>Клавиши</th></tr>')
for vk, w in rows5.items():
    if chr(w[3]) in MARI:
        out.append('<tr><td style="font-size:20px">%s %s</td><td>AltGr + %s (заглавная: AltGr + Shift + %s)</td></tr>' % (ch(w[3]), ch(w[4]), ch(w[0]), ch(w[0])))
out.append('</table><h2>Все дополнительные символы (AltGr)</h2><table><tr><th>Клавиша</th><th>AltGr</th><th>AltGr+Shift</th><th>Unicode</th></tr>')
for vk, w in rows5.items():
    if w[3] < 0xF000 and w[3] != w[0]:
        out.append('<tr><td>%s</td><td style="font-size:18px">%s</td><td style="font-size:18px">%s</td><td>U+%04X / U+%04X</td></tr>' % (ch(w[0]), ch(w[3]), ch(w[4]), w[3], w[4]))
out.append('</table><p style="color:#777;margin-top:24px">Марийская раскладка клавиатуры 3.1 для Windows 10/11. © Михаил Пирогов</p></body></html>')
open('installer/keymap.html', 'w', encoding='utf-8').write('\n'.join(out))
print('html ok')
