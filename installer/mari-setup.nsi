; Установщик марийской раскладки клавиатуры для Windows 10/11
Unicode true
ManifestDPIAware true
ManifestSupportedOS all
SetCompressor /SOLID lzma

!define PRODUCT     "Марийская раскладка клавиатуры"
!define VERSION     "3.1.0"
!define VERSION4    "3.1.0.0"
!define AUTHOR      "Михаил Пирогов"
!define PUBLISHER   "Пирогов Михаил"
!define COPYRIGHT   "© Михаил Пирогов"
!define UNKEY       "Software\Microsoft\Windows\CurrentVersion\Uninstall\MariKeyboard"
!define SMDIR       "$SMPROGRAMS\Марийская раскладка"
!define SRC         ".."
!define HOMEPAGE    "https://pirogovlab.ru"

!include MUI2.nsh
!include x64.nsh
!include LogicLib.nsh
!include nsDialogs.nsh
!include FileFunc.nsh
!include WinVer.nsh

Name "${PRODUCT}"
Caption "${PRODUCT} 3.1"
UninstallCaption "Удаление: ${PRODUCT}"
OutFile "${SRC}\dist\MariKeyboard-Setup-3.1.exe"
RequestExecutionLevel admin
InstallDir "$PROGRAMFILES64\MariKeyboard"
BrandingText "${PRODUCT} 3.1"
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "${VERSION4}"
VIFileVersion "${VERSION4}"

Var Mode        ; mhr | ru
Var PS          ; путь к powershell.exe (родной разрядности) для nsExec
Var PSLink      ; путь к powershell.exe для ярлыков
Var OldLayout
Var RadioMhr
Var RadioRu
Var RadioEn
Var Indicator   ; 1 — ставить индикатор МАР/РУС в автозагрузку
Var ChkInd
Var HideSys    ; 1 — скрыть системный индикатор языка
Var ChkHide

!define MUI_ICON   "${SRC}\res\mari_flag.ico"
!define MUI_UNICON "${SRC}\res\mari_flag.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP   "${SRC}\res\welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "${SRC}\res\welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP   "${SRC}\res\header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "${SRC}\res\header.bmp"
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TITLE "Марийская раскладка клавиатуры 3.1"
!define MUI_WELCOMEPAGE_TEXT "Программа установит марийскую раскладку клавиатуры для Windows 10 и Windows 11 (x86, x64, ARM64).$\r$\n$\r$\nМарийские буквы вводятся с правым Alt (AltGr):$\r$\nAltGr + а, о, у, ы, н  →  ӓ, ӧ, ӱ, ӹ, ҥ$\r$\nAltGr + Shift + …  →  Ӓ, Ӧ, Ӱ, Ӹ, Ҥ$\r$\n$\r$\nВерсия 3.1 — продолжение проекта «Марий клавиатур» 3.0.$\r$\nФайл из проекта pirogovlab.ru.$\r$\n$\r$\nНажмите «Далее» для продолжения."
!insertmacro MUI_PAGE_WELCOME
Page custom ModePage ModePageLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "Установка завершена"
!define MUI_FINISHPAGE_TEXT_LARGE
!define MUI_FINISHPAGE_TEXT "«Марийская» — первая раскладка русского языка, «Русская» — вторая.$\r$\nAltGr + а/о/у/ы/н → ӓ ӧ ӱ ӹ ҥ.$\r$\n$\r$\nЗначок у часов: «МАР» — марийская, «РУС» — другая. Скрыт под ^ — перетащите на панель задач.$\r$\n$\r$\nНе видно раскладки — выйдите и войдите снова.$\r$\n$\r$\nАвтор — ${AUTHOR}. Файл из проекта pirogovlab.ru."
!define MUI_FINISHPAGE_LINK "Сайт проекта: pirogovlab.ru"
!define MUI_FINISHPAGE_LINK_LOCATION "${HOMEPAGE}"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Russian"

VIAddVersionKey /LANG=${LANG_RUSSIAN} "ProductName"     "${PRODUCT}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "LegalCopyright"  "${COPYRIGHT}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileDescription" "Установка марийской раскладки клавиатуры"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileVersion"     "${VERSION}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "ProductVersion"  "${VERSION}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "Comments" "Файл из проекта pirogovlab.ru — ${HOMEPAGE}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "URL" "${HOMEPAGE}"

!macro SetupPaths
  ${If} ${RunningX64}
    StrCpy $PS "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  ${Else}
    StrCpy $PS "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe"
  ${EndIf}
  StrCpy $PSLink "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
!macroend

Function .onInit
  ${IfNot} ${AtLeastWin7}
    MessageBox MB_ICONSTOP "Требуется Windows 7 или новее (рекомендуется Windows 10/11)."
    Abort
  ${EndIf}
  ${If} ${RunningX64}
    SetRegView 64
  ${Else}
    StrCpy $INSTDIR "$PROGRAMFILES\MariKeyboard"
  ${EndIf}
  !insertmacro SetupPaths
  ; По умолчанию — «Марийская» ПЕРВОЙ раскладкой РУССКОГО языка (затем обычная «Русская»); языки и горячие клавиши не меняются.
  ; (отдельный язык mhr заставляет Windows 10/11 искать языковой пакет — только по явному выбору)
  StrCpy $Mode "ru"
  ; Параметр командной строки: /MODE=en, /MODE=ru или /MODE=mhr (для тихой установки /S)
  ${GetParameters} $0
  ClearErrors
  StrCpy $Indicator "1"
  ClearErrors
  ${GetOptions} $0 "/NOINDICATOR" $1
  ${IfNot} ${Errors}
    StrCpy $Indicator "0"
  ${EndIf}
  ClearErrors
  StrCpy $HideSys $Indicator
  ClearErrors
  ${GetOptions} $0 "/KEEPSYSINDICATOR" $1
  ${IfNot} ${Errors}
    StrCpy $HideSys "0"
  ${EndIf}
  ClearErrors
  ${GetOptions} $0 "/MODE=" $1
  ${IfNot} ${Errors}
    ${If} $1 == "ru"
      StrCpy $Mode "ru"
    ${ElseIf} $1 == "en"
      StrCpy $Mode "en"
    ${ElseIf} $1 == "mhr"
      StrCpy $Mode "mhr"
    ${EndIf}
  ${EndIf}
  ; старая раскладка Windows 7 (mari1.dll, FU-Lab) — не трогаем, только сообщаем
  StrCpy $OldLayout ""
  ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000419" "Layout File"
  ${If} $0 == "mari1.dll"
    StrCpy $OldLayout "1"
  ${EndIf}
FunctionEnd

Function ModePage
  !insertmacro MUI_HEADER_TEXT "Как подключить раскладку" "Выберите, к какому языку привязать марийскую раскладку"
  nsDialogs::Create 1018
  Pop $0
  ${NSD_CreateRadioButton} 0 0 100% 12u "Раскладка русского языка — первой (рекомендуется)"
  Pop $RadioRu
  ${NSD_CreateLabel} 12u 13u -12u 26u "«Марийская» становится первой раскладкой русского языка, обычная «Русская» — второй. На панели задач «РУС»; языки и их порядок не меняются. Языковые пакеты не скачиваются."
  Pop $0
  ${NSD_CreateRadioButton} 0 42u 100% 12u "Раскладка английского языка (английский — первым)"
  Pop $RadioEn
  ${NSD_CreateLabel} 12u 55u -12u 18u "«Марийская» под английским (ENG), Ctrl+Shift переключает на русский."
  Pop $0
  ${NSD_CreateRadioButton} 0 76u 100% 12u "Отдельный язык «Марийский» (экспериментально, не рекомендуется)"
  Pop $RadioMhr
  ${NSD_CreateLabel} 12u 89u -12u 18u "Windows 10/11 не знает марийский язык и может показывать «Поиск языкового пакета»."
  Pop $0
  ${If} $OldLayout == "1"
    ${NSD_CreateLabel} 0 137u 100% 16u "Найдена старая раскладка mari1.dll (FU-Lab) — она не изменяется; удалить её можно в «Программы и компоненты»."
    Pop $0
  ${EndIf}
  ${NSD_CreateCheckbox} 0 110u 100% 12u "Показывать значок «МАР» / «РУС» возле часов — видно, какая раскладка включена"
  Pop $ChkInd
  ${If} $Indicator == "1"
    ${NSD_Check} $ChkInd
  ${EndIf}
  ${NSD_CreateCheckbox} 0 123u 100% 12u "Скрыть системный индикатор языка (останется только «МАР» / «РУС»)"
  Pop $ChkHide
  ${If} $HideSys == "1"
    ${NSD_Check} $ChkHide
  ${EndIf}
  ${IfNot} ${AtLeastWin8}
    EnableWindow $RadioMhr 0
  ${EndIf}
  ${If} $Mode == "en"
    ${NSD_Check} $RadioEn
  ${ElseIf} $Mode == "mhr"
    ${NSD_Check} $RadioMhr
  ${Else}
    ${NSD_Check} $RadioRu
  ${EndIf}
  nsDialogs::Show
FunctionEnd

Function ModePageLeave
  ${NSD_GetState} $ChkInd $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $Indicator "1"
  ${Else}
    StrCpy $Indicator "0"
  ${EndIf}
  ${NSD_GetState} $ChkHide $0
  StrCpy $HideSys "0"
  ${If} $0 == ${BST_CHECKED}
  ${AndIf} $Indicator == "1"
    StrCpy $HideSys "1"
  ${EndIf}
  StrCpy $Mode "ru"
  ${NSD_GetState} $RadioEn $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $Mode "en"
  ${EndIf}
  ${NSD_GetState} $RadioMhr $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $Mode "mhr"
  ${EndIf}
FunctionEnd

; Копирование DLL с переименованием занятого старого файла
!macro PutDll SRCFILE
  IfFileExists "$SYSDIR\kbdmari.dll" 0 +4
    Delete "$SYSDIR\kbdmari.dll.old"
    Rename "$SYSDIR\kbdmari.dll" "$SYSDIR\kbdmari.dll.old"
    Delete /REBOOTOK "$SYSDIR\kbdmari.dll.old"
  File "/oname=$SYSDIR\kbdmari.dll" "${SRCFILE}"
!macroend

Section "Install"
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  ; индикатор мог быть запущен (обновление) — закрываем, чтобы заменить файл
  IfFileExists "$INSTDIR\MariIndicator.exe" 0 +4
    nsExec::Exec '"$INSTDIR\MariIndicator.exe" /quit'
    Pop $0
    Sleep 700
  nsExec::Exec 'taskkill /F /IM MariIndicator.exe'
  Pop $0
  File "mari-layout.ps1"
  File "${SRC}\build\indicator\MariIndicator.exe"
  File "readme.txt"
  File "keymap.html"
  File "${SRC}\src\kbdmari.klc"
  File "${SRC}\res\mari_flag.ico"

  DetailPrint "Копирование kbdmari.dll…"
  ${If} ${IsNativeAMD64}
    ${DisableX64FSRedirection}
    !insertmacro PutDll "${SRC}\build\x64\kbdmari.dll"
    ${EnableX64FSRedirection}
    !insertmacro PutDll "${SRC}\build\wow64\kbdmari.dll"
  ${ElseIf} ${IsNativeARM64}
    ${DisableX64FSRedirection}
    !insertmacro PutDll "${SRC}\build\arm64\kbdmari.dll"
    ${EnableX64FSRedirection}
    !insertmacro PutDll "${SRC}\build\wow64\kbdmari.dll"
  ${Else}
    !insertmacro PutDll "${SRC}\build\x86\kbdmari.dll"
  ${EndIf}

  ; Удаление через «Программы и компоненты»
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${UNKEY}" "DisplayName"     "${PRODUCT}"
  WriteRegStr HKLM "${UNKEY}" "DisplayVersion"  "${VERSION}"
  WriteRegStr HKLM "${UNKEY}" "Publisher"       "${PUBLISHER}"
  WriteRegStr HKLM "${UNKEY}" "URLInfoAbout" "${HOMEPAGE}"
  WriteRegStr HKLM "${UNKEY}" "HelpLink" "${HOMEPAGE}"
  WriteRegStr HKLM "${UNKEY}" "URLUpdateInfo" "${HOMEPAGE}/mariyskaya-raskladka-klaviatury/"
  WriteRegStr HKLM "${UNKEY}" "DisplayIcon"     "$INSTDIR\mari_flag.ico"
  WriteRegStr HKLM "${UNKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNKEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${UNKEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNKEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntOp $0 $0 + 20
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${UNKEY}" "EstimatedSize" "$0"

  DetailPrint "Регистрация раскладки…"
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action Register'
  Pop $0
  ${If} $0 != "0"
    MessageBox MB_ICONSTOP "Не удалось зарегистрировать раскладку (код $0). Подробности: $TEMP\MariKeyboard-setup.log" /SD IDOK
    !ifndef PREVIEW
    Abort
    !endif
  ${EndIf}

  DetailPrint "Добавление раскладки в список языков пользователя ($Mode)…"
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action AddUser -Mode $Mode'
  Pop $0
  ${If} $0 != "0"
    MessageBox MB_ICONEXCLAMATION "Раскладка установлена, но не добавлена в список языков (код $0).$\r$\nДобавьте её вручную: Параметры → Время и язык → Язык → Русский → Параметры → Добавить клавиатуру → «Марийская»,$\r$\nили через меню «Пуск» → «Марийская раскладка»." /SD IDOK
  ${EndIf}

  ${If} $Indicator == "1"
    DetailPrint "Индикатор «МАР / РУС»: автозапуск и запуск…"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "MariKeyboardIndicator" '"$INSTDIR\MariIndicator.exe"'
    ; запуск без прав администратора — через Проводник текущего пользователя
    Exec '"$WINDIR\explorer.exe" "$INSTDIR\MariIndicator.exe"'
  ${Else}
    DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "MariKeyboardIndicator"
  ${EndIf}

  ${If} $HideSys == "1"
  ${AndIf} $Indicator == "1"
    DetailPrint "Скрытие системного индикатора языка…"
    nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action HideSysIndicator'
    Pop $0
  ${EndIf}

  DetailPrint "Проверка установки…"
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action Verify'
  Pop $0

  ; Ярлыки
  CreateDirectory "${SMDIR}"
  CreateShortcut "${SMDIR}\Индикатор МАР-РУС.lnk" "$INSTDIR\MariIndicator.exe" "" "$INSTDIR\MariIndicator.exe"
  CreateShortcut "${SMDIR}\Схема раскладки.lnk" "$INSTDIR\keymap.html" "" "$INSTDIR\mari_flag.ico"
  CreateShortcut "${SMDIR}\Включить как раскладку английского языка.lnk" "$PSLink" '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\mari-layout.ps1" -Action AddUser -Mode en' "$INSTDIR\mari_flag.ico"
  CreateShortcut "${SMDIR}\Включить как раскладку русского языка (по умолчанию).lnk" "$PSLink" '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\mari-layout.ps1" -Action AddUser -Mode ru' "$INSTDIR\mari_flag.ico"
  CreateShortcut "${SMDIR}\Проверить установку.lnk" "$PSLink" '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\mari-layout.ps1" -Action Verify -Show' "$INSTDIR\mari_flag.ico"
  CreateShortcut "${SMDIR}\Отключить для текущего пользователя.lnk" "$PSLink" '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\mari-layout.ps1" -Action RemoveUser' "$INSTDIR\mari_flag.ico"
  CreateShortcut "${SMDIR}\Удалить марийскую раскладку.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\mari_flag.ico"

SectionEnd

Function un.onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
  !insertmacro SetupPaths
FunctionEnd

Section "Uninstall"
  SetShellVarContext all
  DetailPrint "Закрытие индикатора «МАР / РУС»…"
  nsExec::Exec '"$INSTDIR\MariIndicator.exe" /quit'
  Pop $0
  Sleep 700
  nsExec::Exec 'taskkill /F /IM MariIndicator.exe'
  Pop $0
  DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "MariKeyboardIndicator"
  DetailPrint "Возврат системного индикатора языка…"
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action RestoreSysIndicator'
  Pop $0
  DetailPrint "Удаление раскладки из списка языков пользователя…"
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action RemoveUser'
  Pop $0
  DetailPrint "Удаление регистрации раскладки…"
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\mari-layout.ps1" -Action Unregister'
  Pop $0

  ${If} ${RunningX64}
    ${DisableX64FSRedirection}
    Delete /REBOOTOK "$SYSDIR\kbdmari.dll"
    Delete /REBOOTOK "$SYSDIR\kbdmari.dll.old"
    ${EnableX64FSRedirection}
  ${EndIf}
  Delete /REBOOTOK "$SYSDIR\kbdmari.dll"
  Delete /REBOOTOK "$SYSDIR\kbdmari.dll.old"

  Delete "${SMDIR}\*.lnk"
  RMDir "${SMDIR}"
  Delete "$INSTDIR\mari-layout.ps1"
  Delete /REBOOTOK "$INSTDIR\MariIndicator.exe"
  Delete "$INSTDIR\readme.txt"
  Delete "$INSTDIR\keymap.html"
  Delete "$INSTDIR\kbdmari.klc"
  Delete "$INSTDIR\mari_flag.ico"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "${UNKEY}"
  IfRebootFlag 0 +2
    MessageBox MB_ICONINFORMATION "Файл раскладки ещё используется и будет удалён после перезагрузки." /SD IDOK
SectionEnd
