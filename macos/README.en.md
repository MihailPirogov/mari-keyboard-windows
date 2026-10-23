# Mari keyboard layout 3.1 for macOS
© Mikhail Pirogov, [PirogovLab](https://pirogovlab.ru/en/mariyskaya-raskladka-klaviatury/)

Russian ЙЦУКЕН plus Mari letters on the **Option** key (like AltGr on Windows). Shift+Option gives capitals. Cmd shortcuts keep Latin positions.

## Install
1. Unzip `MariKeyboard-3.1-macOS.zip`.
2. Right-click `install.command` → Open → Open (Gatekeeper asks because it was downloaded).
3. The script copies `Mari.bundle` to `~/Library/Keyboard Layouts`, removes quarantine and enables the layout (needs swift from Xcode Command Line Tools; otherwise see step 4).
4. If «Марийская» is not in the menu bar: log out and back in, then System Settings → Keyboard → Input Sources → Edit… → + → **Others** → «Марийская» → Add. (It is not listed under Russian — macOS has no Mari language.)

## Mari letters
| Option + | Буква / Letter |
|---|---|
| У | ӱ Ӱ |
| О | ӧ Ӧ |
| А | ӓ Ӓ |
| Ы | ӹ Ӹ |
| Н | ҥ Ҥ |
| В | ү Ү |
| Й | ӥ Ӥ |
| Э | ө Ө |
| Ж | ӝ Ӝ |
| З | ӟ Ӟ |
| Ч | ӵ Ӵ |
| Ф | һ Һ |
| Ш | ј Ј |
| И | і І |
| К | ә Ә |
| Е | ё Ё |

## Uninstall
Run `uninstall.command` (or delete `~/Library/Keyboard Layouts/Mari.bundle`) and log out/in.
