#!/bin/bash
# Марийская раскладка 3.1 для macOS — установка. © Михаил Пирогов, PirogovLab
cd "$(dirname "$0")" || exit 1
DEST="$HOME/Library/Keyboard Layouts"
echo "Установка марийской раскладки / Installing Mari keyboard layout…"
mkdir -p "$DEST"
rm -rf "$DEST/Mari.bundle"
cp -R "Mari.bundle" "$DEST/" || { echo "Ошибка копирования / copy failed"; read -n1; exit 1; }
xattr -dr com.apple.quarantine "$DEST/Mari.bundle" 2>/dev/null
touch "$DEST"
echo "Скопировано в $DEST"
ENABLED=0
if xcrun -f swift >/dev/null 2>&1 || [ -x /usr/bin/swift ]; then
  TMP=$(mktemp -t mari).swift
  cat > "$TMP" <<'SW'
import Carbon
let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Keyboard Layouts/Mari.bundle") as CFURL
TISRegisterInputSource(url)
let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
var ok = false
for s in list {
  guard let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { continue }
  let id = Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
  if id.lowercased().contains("pirogov") || id.lowercased().contains("mari") {
    if TISEnableInputSource(s) == noErr { print("Включено / enabled: \(id)"); ok = true }
  }
}
exit(ok ? 0 : 1)
SW
  swift "$TMP" 2>/dev/null && ENABLED=1
  rm -f "$TMP"
fi
echo
if [ $ENABLED = 1 ]; then
  echo "Готово! «Марийская» добавлена в меню ввода (флажок в строке меню)."
  echo "Если её не видно — выйдите из системы и войдите снова."
else
  echo "Раскладка скопирована. Выйдите из системы и войдите снова, затем:"
  echo "Системные настройки → Клавиатура → Источники ввода → Изменить… → «+» → «Другие» → «Марийская»."
  echo "(Чтобы включалась автоматически, установите Xcode Command Line Tools: xcode-select --install, и запустите install.command ещё раз.)"
fi
echo; echo "Марийские буквы: Option + У Н О Ы А В Й … (с Shift — заглавные)."
read -n1 -p "Нажмите любую клавишу / press any key…"
