#!/bin/bash
# Марийская раскладка — удаление / uninstall
DEST="$HOME/Library/Keyboard Layouts/Mari.bundle"
if [ -e "$DEST" ]; then rm -rf "$DEST"; echo "Удалено: $DEST"; else echo "Раскладка не найдена / not installed"; fi
echo "Выйдите из системы и войдите снова, чтобы она исчезла из меню. / Log out and back in."
read -n1 -p "Нажмите любую клавишу…"
