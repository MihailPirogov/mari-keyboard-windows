<#
  mari-layout.ps1 — регистрация марийской раскладки клавиатуры в Windows 10/11.

  -Action Register    (админ)  : записать раскладку в HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts
  -Action Unregister  (админ)  : удалить запись раскладки из HKLM
  -Action AddUser     (польз.) : добавить раскладку в список языков текущего пользователя
         -Mode ru   : (ПО УМОЛЧАНИЮ) раскладка РУССКОГО языка, первой в его списке (Марийская, затем обычная Русская);
                      порядок языков и горячие клавиши не меняются
         -Mode en   : раскладка английского языка (0409), английский первым, Ctrl+Shift -> русский
         -Mode mhr  : ЭКСПЕРИМЕНТ: отдельный язык mhr-Cyrl; Windows 10/11 может начать «Поиск языкового пакета»
  -Action RemoveUser  (польз.) : убрать раскладку из списка языков текущего пользователя
  -Action HideSysIndicator    (польз.) : скрыть системный индикатор языка (значения сохраняются)
  -Action RestoreSysIndicator (польз.) : вернуть сохранённые значения
  -Action Status               : показать состояние
  -Action Verify [-Show]       : проверка установки, отчёт в %TEMP%\MariKeyboard-check.txt
#>
param(
  [ValidateSet('Register','Unregister','AddUser','RemoveUser','Status','Verify','HideSysIndicator','RestoreSysIndicator')][string]$Action = 'Status',
  [ValidateSet('ru','en','mhr')][string]$Mode = 'ru',
  [string]$Klid = '',
  [switch]$Show
)
$ErrorActionPreference = 'Stop'
$DllName     = 'kbdmari.dll'
$LayoutText  = 'Марийская'
$LangTag     = 'mhr-Cyrl'
$LangName    = 'Марийский'
$ProductCode = '{6F0C6A41-3B1E-4C61-9D3B-4D41524921A0}'
$KL          = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'
$SwKey       = 'HKLM:\SOFTWARE\MariKeyboard'
$UserKey     = 'HKCU:\Software\MariKeyboard'
$UP          = 'HKCU:\Control Panel\International\User Profile'
$Transient   = 0x2000, 0x2400, 0x2800, 0x2C00
# Вывод читает установщик (nsExec), а он декодирует его в ANSI-кодировке системы (CP_ACP, для русской Windows — 1251).
# Поэтому пишем в stdout именно в ANSI ([Text.Encoding]::Default в Windows PowerShell 5.1), а не в UTF-8 — иначе «кракозябры».
try { [Console]::OutputEncoding = [Text.Encoding]::Default } catch {}
$LogFile = Join-Path $env:TEMP 'MariKeyboard-setup.log'
function Log($m) { $l = "[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Action, $m; Write-Output $l; Add-Content -Path $LogFile -Value $l -Encoding UTF8 }

function Get-OurKlid {
  if ($Klid) { return $Klid.ToUpper() }
  $k = (Get-ItemProperty -Path $SwKey -Name KLID -ErrorAction SilentlyContinue).KLID
  if ($k) { return $k.ToUpper() }
  foreach ($s in Get-ChildItem $KL) {
    $p = Get-ItemProperty $s.PSPath
    if ($p.'Layout File' -ieq $DllName) { return $s.PSChildName.ToUpper() }
  }
  return $null
}

function Do-Register {
  $sys = [Environment]::GetFolderPath('System')
  $klid = $null
  foreach ($s in Get-ChildItem $KL) { if ((Get-ItemProperty $s.PSPath).'Layout File' -ieq $DllName) { $klid = $s.PSChildName } }
  if (-not $klid) {
    for ($i = 1; $i -le 0xFF; $i++) {
      $cand = 'a0{0:x2}0419' -f $i
      if (-not (Test-Path (Join-Path $KL $cand))) { $klid = $cand; break }
    }
  }
  if (-not $klid) { throw 'Нет свободного идентификатора раскладки (KLID)' }
  $path = Join-Path $KL $klid
  $layoutId = (Get-ItemProperty $path -Name 'Layout Id' -ErrorAction SilentlyContinue).'Layout Id'
  if (-not $layoutId) {
    $used = @{}
    foreach ($s in Get-ChildItem $KL) { $v = (Get-ItemProperty $s.PSPath).'Layout Id'; if ($v) { $used[[Convert]::ToInt32($v, 16)] = 1 } }
    $n = 0xC0; while ($used.ContainsKey($n)) { $n++ }
    $layoutId = '{0:x4}' -f $n
  }
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  New-ItemProperty -Path $path -Name 'Layout File'         -Value $DllName -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $path -Name 'Layout Text'         -Value $LayoutText -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $path -Name 'Layout Display Name' -Value "@%SystemRoot%\system32\$DllName,-1000" -PropertyType ExpandString -Force | Out-Null
  New-ItemProperty -Path $path -Name 'Layout Id'           -Value $layoutId -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $path -Name 'Layout Product Code' -Value $ProductCode -PropertyType String -Force | Out-Null
  if (-not (Test-Path $SwKey)) { New-Item -Path $SwKey -Force | Out-Null }
  New-ItemProperty -Path $SwKey -Name KLID -Value $klid.ToUpper() -PropertyType String -Force | Out-Null
  Log "Раскладка зарегистрирована: KLID=$klid, Layout Id=$layoutId, файл $sys\$DllName"
  if (-not (Test-Path (Join-Path $sys $DllName))) { Log "ВНИМАНИЕ: $DllName не найден в $sys" }
  Write-Output "KLID=$($klid.ToUpper())"
}

function Do-Unregister {
  $klid = Get-OurKlid
  if ($klid -and (Test-Path (Join-Path $KL $klid))) {
    $p = Get-ItemProperty (Join-Path $KL $klid)
    if ($p.'Layout File' -ieq $DllName) { Remove-Item (Join-Path $KL $klid) -Recurse -Force; Log "Удалена регистрация $klid" }
  }
  if (Test-Path $SwKey) { Remove-Item $SwKey -Recurse -Force }
}

function Get-TransientMap {
  $map = @{}
  if (Test-Path $UP) {
    foreach ($k in Get-ChildItem $UP) {
      $t = $k.GetValue('TransientLangId', $null)
      if ($t -ne $null) { $map[$k.PSChildName] = [int]$t }
    }
  }
  return $map
}

function Invoke-Fresh([string]$cmd) {
  # Командлеты *-WinUserLanguageList кэшируют данные в процессе — проверяем в новом процессе.
  $ps = (Get-Process -Id $PID).Path
  $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
  return (& $ps -NoProfile -NonInteractive -EncodedCommand $enc) -join ''
}

function Get-OurTips([string]$klid) {
  return Invoke-Fresh ("(Get-WinUserLanguageList | ForEach-Object {{ `$_ }} | ForEach-Object {{ `$t=`$_.LanguageTag; `$_.InputMethodTips | Where-Object {{ `$_ -like '*:{0}' }} | ForEach-Object {{ `$t + '=' + `$_ }} }}) -join ';'" -f $klid)
}

function Remove-FromList($list, [string]$klid) {
  foreach ($l in @($list)) {
    foreach ($t in @($l.InputMethodTips)) { if ($t -like "*:$klid") { [void]$l.InputMethodTips.Remove($t) } }
  }
  foreach ($l in @($list)) {
    if ($l.LanguageTag -like 'mhr*' -and $l.InputMethodTips.Count -eq 0 -and $list.Count -gt 1) { [void]$list.Remove($l) }
  }
}

function Get-SubstId([string]$klid, [string]$lang = '') { if ($lang) { return ('D0' + $klid.Substring(2,2) + $lang).ToUpper() }; return ('D0' + $klid.Substring(2)).ToUpper() }

function Add-Preload([string]$klid, [string]$lang = '') {
  # Классический способ (как в Windows 7): HKCU\Keyboard Layout\Preload + Substitutes
  try {
    $pre = 'HKCU:\Keyboard Layout\Preload'; $sub = 'HKCU:\Keyboard Layout\Substitutes'
    foreach ($k in $pre, $sub) { if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null } }
    $sid = Get-SubstId $klid $lang
    New-ItemProperty -Path $sub -Name $sid -Value $klid -PropertyType String -Force | Out-Null
    $p = Get-ItemProperty $pre; $vals = @(); $max = 0
    foreach ($n in $p.PSObject.Properties) { if ($n.Name -match '^\d+$') { $vals += [string]$n.Value; if ([int]$n.Name -gt $max) { $max = [int]$n.Name } } }
    if ($vals -notcontains $sid -and $vals -notcontains $klid) { New-ItemProperty -Path $pre -Name ([string]($max + 1)) -Value $sid -PropertyType String -Force | Out-Null }
    Log "Preload/Substitutes: $sid -> $klid"
    return $true
  } catch { Log ('Preload: ' + $_.Exception.Message); return $false }
}

function Activate-Layout([string]$klid) {
  # Загружаем раскладку в текущий сеанс, чтобы она сразу была доступна (Win+Пробел) без выхода из системы
  try {
    if (-not ('MariKbd.Native' -as [type])) {
      Add-Type -Namespace MariKbd -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadKeyboardLayout(string id, uint flags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SendNotifyMessage(IntPtr hWnd, uint msg, UIntPtr w, IntPtr l);
'@
    }
    $h = [MariKbd.Native]::LoadKeyboardLayout($klid, 0x00000002)  # KLF_SUBSTITUTE_OK
    # WM_SETTINGCHANGE (0x1A) — оповещаем оболочку об изменении настроек ввода
    [void][MariKbd.Native]::SendNotifyMessage([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, [IntPtr]::Zero)
    Log ("LoadKeyboardLayout({0}) = 0x{1:X}" -f $klid, [int64]$h)
  } catch { Log ('Активация: ' + $_.Exception.Message) }
}

function Do-Verify {
  $r = New-Object System.Collections.Generic.List[string]
  $bad = 0
  $r.Add(("Проверка марийской раскладки — {0:yyyy-MM-dd HH:mm}, пользователь {1}, Windows {2}" -f (Get-Date), $env:USERNAME, [Environment]::OSVersion.Version))
  $s32 = if (Test-Path "$env:WINDIR\Sysnative") { "$env:WINDIR\Sysnative" } else { "$env:WINDIR\System32" }
  $d = Test-Path (Join-Path $s32 $DllName); $r.Add("[{0}] {1}\{2}" -f ($(if ($d) {'OK'} else {'НЕТ'}), 'System32', $DllName)); if (-not $d) { $bad++ }
  if ([Environment]::Is64BitOperatingSystem) { $d = Test-Path "$env:WINDIR\SysWOW64\$DllName"; $r.Add("[{0}] SysWOW64\{1}" -f ($(if ($d) {'OK'} else {'НЕТ'}), $DllName)); if (-not $d) { $bad++ } }
  $klid = Get-OurKlid
  if ($klid -and (Test-Path (Join-Path $KL $klid))) {
    $p = Get-ItemProperty (Join-Path $KL $klid)
    $r.Add("[OK] Реестр: Keyboard Layouts\$klid  Layout File=$($p.'Layout File')  Layout Id=$($p.'Layout Id')  Text=$($p.'Layout Text')")
    $t = Get-OurTips $klid.ToUpper()
    if ($t) { $r.Add("[OK] В списке языков пользователя: $t") }
    else {
      $sid = Get-SubstId $klid; $pre = (Get-ItemProperty 'HKCU:\Keyboard Layout\Preload' -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Value -eq $sid }
      if ($pre) { $r.Add("[~~] Нет в списке языков, но есть в Preload ($sid) — выйдите из системы и войдите снова") } else { $r.Add('[НЕТ] Раскладки нет в списке языков пользователя'); $bad++ }
    }
  } else { $r.Add('[НЕТ] Раскладка не зарегистрирована в HKLM\...\Keyboard Layouts'); $bad++ }
  $ll = Get-WinUserLanguageList
  $mhr = $ll | Where-Object { $_.LanguageTag -like 'mhr*' }
  if ($mhr) { $r.Add('[!!] В списке есть язык ' + (($mhr | ForEach-Object { $_.LanguageTag }) -join ', ') + ' — из-за него Windows может искать языковой пакет') }
  $r.Add('')
  $r.Add('Языки пользователя:')
  foreach ($l in $ll) { $r.Add(('  {0,-10} {1,-25} {2}' -f $l.LanguageTag, $l.LocalizedName, ($l.InputMethodTips -join ' '))) }
  $r.Add('')
  $r.Add($(if ($bad -eq 0) { 'ИТОГ: OK. «Марийская» — первая раскладка русского языка; проверьте AltGr+а → ӓ' } else { "ИТОГ: ПРОБЛЕМА ($bad). Пришлите этот файл разработчику." }))
  $out = Join-Path $env:TEMP 'MariKeyboard-check.txt'
  $r | Set-Content -Path $out -Encoding UTF8
  $r | Write-Output
  if ($Show) { Start-Process notepad.exe $out }
}

function Set-CtrlShift {
  # Переключение ЯЗЫКОВ — Ctrl+Shift, переключение раскладок внутри языка — отключено (чтобы не конфликтовало).
  # Значения: 1 = Alt+Shift, 2 = Ctrl+Shift, 3 = не назначено, 4 = Ё (`).
  try {
    $tg = 'HKCU:\Keyboard Layout\Toggle'
    if (-not (Test-Path $tg)) { New-Item -Path $tg -Force | Out-Null }
    New-ItemProperty -Path $tg -Name 'Language Hotkey' -Value '2' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $tg -Name 'Hotkey'          -Value '2' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $tg -Name 'Layout Hotkey'   -Value '3' -PropertyType String -Force | Out-Null
    if (-not ('MariKbd.Spi' -as [type])) {
      Add-Type -Namespace MariKbd -Name Spi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint a, uint b, IntPtr c, uint d);'
    }
    $r = [MariKbd.Spi]::SystemParametersInfo(0x005B, 0, [IntPtr]::Zero, 0x2)   # SPI_SETLANGTOGGLE, SPIF_SENDCHANGE — применить сразу
    Log "Горячая клавиша переключения языков: Ctrl+Shift (применено: $r)"
  } catch { Log ('Ctrl+Shift: ' + $_.Exception.Message) }
}

function Repair-AfterEnMode([string]$klid) {
  # Если раньше стоял режим «под английским»: вернуть метод ввода по умолчанию и переключение раскладок
  try {
    $ov = Get-WinDefaultInputMethodOverride
    if ($ov -and [string]$ov.InputMethodTip -like "0409:$klid") {
      $first = Invoke-Fresh "(Get-WinUserLanguageList | ForEach-Object { `$_ } | Select-Object -First 1).InputMethodTips[0]"
      if ($first) { Set-WinDefaultInputMethodOverride -InputTip $first; Log "Метод ввода по умолчанию возвращён: $first" }
    }
  } catch {}   # переопределение не задано — ничего делать не нужно
  try {
    $tg = 'HKCU:\Keyboard Layout\Toggle'
    $p = Get-ItemProperty $tg -ErrorAction SilentlyContinue
    if ($p -and [string]$p.'Language Hotkey' -eq '2' -and [string]$p.'Layout Hotkey' -eq '3') {
      # именно так настраивал режим «под английским»: язык — Ctrl+Shift, раскладка — нет. Возвращаем переключение раскладок Alt+Shift.
      New-ItemProperty -Path $tg -Name 'Layout Hotkey' -Value '1' -PropertyType String -Force | Out-Null
      if (-not ('MariKbd.Spi' -as [type])) { Add-Type -Namespace MariKbd -Name Spi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint a, uint b, IntPtr c, uint d);' }
      [void][MariKbd.Spi]::SystemParametersInfo(0x005B, 0, [IntPtr]::Zero, 0x2)
      Log 'Переключение раскладок внутри языка: Alt+Shift (языки — Ctrl+Shift, без изменений)'
    }
  } catch { Log ('Горячие клавиши: ' + $_.Exception.Message) }
}

function Do-AddUser {
  $klid = Get-OurKlid
  if (-not $klid) { throw 'Раскладка не зарегистрирована (сначала Register)' }
  $klid = $klid.ToUpper()
  $list = Get-WinUserLanguageList
  Remove-FromList $list $klid
  $ok = $false
  if ($Mode -eq 'mhr') {
    $lang = $list | Where-Object { $_.LanguageTag -like 'mhr*' } | Select-Object -First 1
    if (-not $lang) { $list.Add($LangTag); $lang = $list | Where-Object { $_.LanguageTag -like 'mhr*' } | Select-Object -First 1 }
    $tag = $lang.LanguageTag
    $map = Get-TransientMap
    if ($map.ContainsKey($tag)) { $tid = $map[$tag] }
    else {
      $usedIds = @($map.Values)
      $tid = $Transient | Where-Object { $usedIds -notcontains $_ } | Select-Object -First 1
    }
    if (-not $tid) { Log 'Все 4 временных LCID (0x2000..0x2C00) заняты — переходим к режиму «русская раскладка»'; $Mode = 'ru' }
    else {
      $lang.InputMethodTips.Clear()
      $lang.InputMethodTips.Add(('{0:X4}:{1}' -f $tid, $klid))
      Set-WinUserLanguageList -LanguageList $list -Force
      $res = Get-OurTips $klid
      if (-not $res) {
        # Windows мог назначить другой временный LCID — читаем его и повторяем
        $map = Get-TransientMap
        $real = $map.Keys | Where-Object { $_ -like 'mhr*' } | Select-Object -First 1
        if ($real) {
          $tid = $map[$real]
          $list = Get-WinUserLanguageList
          Remove-FromList $list $klid
          $lang = $list | Where-Object { $_.LanguageTag -like 'mhr*' } | Select-Object -First 1
          if (-not $lang) { $list.Add($LangTag); $lang = $list | Where-Object { $_.LanguageTag -like 'mhr*' } | Select-Object -First 1 }
          $lang.InputMethodTips.Clear(); $lang.InputMethodTips.Add(('{0:X4}:{1}' -f $tid, $klid))
          Set-WinUserLanguageList -LanguageList $list -Force
          $res = Get-OurTips $klid
        }
      }
      if ($res) {
        $ok = $true
        Log "Добавлен язык $tag с раскладкой ($res)"
        $sub = Join-Path $UP $tag
        if (Test-Path $sub) { try { New-ItemProperty -Path $sub -Name CachedLanguageName -Value $LangName -PropertyType String -Force | Out-Null } catch {} }
      } else {
        Log 'Windows не принял раскладку для языка mhr — переходим к режиму «русская раскладка»'
        $list = Get-WinUserLanguageList; Remove-FromList $list $klid; Set-WinUserLanguageList -LanguageList $list -Force
        $Mode = 'ru'
      }
    }
  }
  if ($Mode -eq 'en') {
    # ПО УМОЛЧАНИЮ: «Марийская» — раскладка АНГЛИЙСКОГО языка (0409), английский — первым в списке,
    # переключение языков Ctrl+Shift (Марийская <-> Русский). Языковые пакеты не скачиваются: en-US и ru уже есть.
    $list = Get-WinUserLanguageList
    Remove-FromList $list $klid
    foreach ($l in @($list)) {
      if ($l.LanguageTag -like 'mhr*' -and $list.Count -gt 1) { [void]$list.Remove($l); Log "Удалён язык $($l.LanguageTag) (остался от режима «отдельный язык»)" }
    }
    $en = $list | Where-Object { $_.LanguageTag -eq 'en-US' } | Select-Object -First 1
    if (-not $en) { $en = $list | Where-Object { $_.LanguageTag -like 'en*' } | Select-Object -First 1 }
    if (-not $en) {
      Log 'Английский язык не найден в списке — добавляем en-US'
      $list.Add('en-US'); $en = $list | Where-Object { $_.LanguageTag -eq 'en-US' } | Select-Object -First 1
    }
    $tip = "0409:$klid"
    $old = @($en.InputMethodTips)
    $en.InputMethodTips.Clear(); $en.InputMethodTips.Add($tip)
    foreach ($t in $old) { if ($t -ne $tip) { $en.InputMethodTips.Add($t) } }   # US-раскладка остаётся второй (Win+Пробел)
    [void]$list.Remove($en); $list.Insert(0, $en)                                  # английский (Марийская) — первым
    Set-WinUserLanguageList -LanguageList $list -Force
    $res = Get-OurTips $klid
    $ok = [bool]$res
    if ($ok) {
      Log "Режим «раскладка английского языка»: $res; порядок: $((Invoke-Fresh '(Get-WinUserLanguageList | ForEach-Object { $_ } | ForEach-Object { $_.LanguageTag }) -join '','''))"
      try { Set-WinDefaultInputMethodOverride -InputTip $tip; Log "Метод ввода по умолчанию: $tip" } catch { Log ('Метод ввода по умолчанию: ' + $_.Exception.Message) }
    } else { Log 'Set-WinUserLanguageList не принял раскладку — запасной способ через Preload/Substitutes'; $ok = Add-Preload $klid '0409' }
    Set-CtrlShift
  }
  if ($Mode -eq 'ru') {
    $list = Get-WinUserLanguageList
    Remove-FromList $list $klid
    # Убираем языки mhr*, оставшиеся от режима «отдельный язык» (из-за них Windows ищет языковой пакет)
    foreach ($l in @($list)) {
      if ($l.LanguageTag -like 'mhr*' -and $list.Count -gt 1) { [void]$list.Remove($l); Log "Удалён язык $($l.LanguageTag) (остался от режима «отдельный язык»)" }
    }
    $ru = $list | Where-Object { $_.LanguageTag -eq 'ru' -or $_.LanguageTag -eq 'ru-RU' } | Select-Object -First 1
    if (-not $ru) { $ru = $list | Where-Object { $_.LanguageTag -like 'ru*' } | Select-Object -First 1 }
    if (-not $ru) {
      Log 'Русский язык не найден в списке — добавляем ru-RU'
      $list.Add('ru-RU'); $ru = $list | Where-Object { $_.LanguageTag -like 'ru*' } | Select-Object -First 1; $ru.InputMethodTips.Clear(); $ru.InputMethodTips.Add('0419:00000419')
    }
    # Марийская — ПЕРВОЙ раскладкой русского языка, обычная «Русская» (00000419) — второй. Порядок языков не трогаем.
    $tip = "0419:$klid"
    $old = @($ru.InputMethodTips)
    $ru.InputMethodTips.Clear(); $ru.InputMethodTips.Add($tip)
    if ($old -notcontains '0419:00000419') { $ru.InputMethodTips.Add('0419:00000419') }
    foreach ($t in $old) { if ($t -ne $tip) { $ru.InputMethodTips.Add($t) } }
    Set-WinUserLanguageList -LanguageList $list -Force
    $res = Get-OurTips $klid
    $ok = [bool]$res
    if ($ok) {
      $ruTips = Invoke-Fresh "(Get-WinUserLanguageList | ForEach-Object { `$_ } | Where-Object { `$_.LanguageTag -like 'ru*' } | ForEach-Object { `$_.InputMethodTips }) -join ','"
      Log "Режим «русская раскладка»: $res; раскладки русского: $ruTips"
    }
    else { Log 'Set-WinUserLanguageList не принял раскладку — запасной способ через Preload/Substitutes'; $ok = Add-Preload $klid }
    Repair-AfterEnMode $klid
    if ($ok) { Activate-Layout $klid }
  }
  if (-not (Test-Path $UserKey)) { New-Item -Path $UserKey -Force | Out-Null }
  New-ItemProperty -Path $UserKey -Name Mode -Value $Mode -PropertyType String -Force | Out-Null
  if (-not $ok) { Log 'ОШИБКА: не удалось добавить раскладку в список языков'; exit 2 }
  Write-Output "MODE=$Mode"
}

function Do-RemoveUser {
  $klid = Get-OurKlid
  if (-not $klid) { Log 'Раскладка не найдена'; return }
  $list = Get-WinUserLanguageList
  Remove-FromList $list $klid.ToUpper()
  Set-WinUserLanguageList -LanguageList $list -Force
  $sid = Get-SubstId $klid
  $sid2 = Get-SubstId $klid '0409'
  $pre = 'HKCU:\Keyboard Layout\Preload'
  if (Test-Path $pre) { foreach ($n in (Get-ItemProperty $pre).PSObject.Properties) { if ($n.Name -match '^\d+$' -and ([string]$n.Value -ieq $sid -or [string]$n.Value -ieq $sid2 -or [string]$n.Value -ieq $klid)) { Remove-ItemProperty -Path $pre -Name $n.Name -ErrorAction SilentlyContinue } } }
  foreach ($x in $sid, $sid2) { Remove-ItemProperty -Path 'HKCU:\Keyboard Layout\Substitutes' -Name $x -ErrorAction SilentlyContinue }
  if (Test-Path $UserKey) { Remove-Item $UserKey -Recurse -Force }
  Log "Раскладка $klid убрана из списка языков пользователя $env:USERNAME"
}

# --- Системный индикатор языка (HKCU текущего пользователя) ---
# Windows 10/11: «Использовать языковую панель рабочего стола» (Set-WinLanguageBarOption -UseLegacyLanguageBar)
# убирает индикатор ввода с панели задач, а HKCU\Software\Microsoft\CTF\LangBar ShowStatus=3 скрывает саму языковую панель.
$SysSave = 'HKCU:\Software\MariKeyboard\SysIndicator'
$LangBar = 'HKCU:\Software\Microsoft\CTF\LangBar'
function Kick-Ctf { try { Get-Process ctfmon -ErrorAction SilentlyContinue | Out-Null; Start-Process "$env:WINDIR\System32\ctfmon.exe" -ErrorAction SilentlyContinue } catch {} }
function Do-HideSys {
  if (-not (Test-Path $SysSave)) {
    New-Item $SysSave -Force | Out-Null
    $o = Get-WinLanguageBarOption
    $ss = (Get-ItemProperty $LangBar -Name ShowStatus -ErrorAction SilentlyContinue).ShowStatus
    Set-ItemProperty $SysSave -Name UseLegacyLanguageBar -Value ([int][bool]$o.UseLegacyLanguageBar) -Type DWord
    Set-ItemProperty $SysSave -Name UseLegacySwitchMode -Value ([int][bool]$o.UseLegacySwitchMode) -Type DWord
    if ($null -ne $ss) { Set-ItemProperty $SysSave -Name ShowStatus -Value ([int]$ss) -Type DWord } else { Set-ItemProperty $SysSave -Name ShowStatus -Value -1 -Type DWord }
  }
  $o = Get-WinLanguageBarOption
  Set-WinLanguageBarOption -UseLegacyLanguageBar -UseLegacySwitchMode:([bool]$o.UseLegacySwitchMode)
  if (-not (Test-Path $LangBar)) { New-Item $LangBar -Force | Out-Null }
  Set-ItemProperty $LangBar -Name ShowStatus -Value 3 -Type DWord
  Kick-Ctf
  Log "Системный индикатор языка скрыт для $env:USERNAME (полностью — после повторного входа)"
}
function Do-RestoreSys {
  if (-not (Test-Path $SysSave)) { Log "Сохранённых значений нет — системный индикатор не менялся"; return }
  $v = Get-ItemProperty $SysSave
  Set-WinLanguageBarOption -UseLegacyLanguageBar:([bool]$v.UseLegacyLanguageBar) -UseLegacySwitchMode:([bool]$v.UseLegacySwitchMode)
  if ([int]$v.ShowStatus -lt 0) { Remove-ItemProperty $LangBar -Name ShowStatus -ErrorAction SilentlyContinue }
  else { Set-ItemProperty $LangBar -Name ShowStatus -Value ([int]$v.ShowStatus) -Type DWord }
  Remove-Item $SysSave -Recurse -Force
  Remove-Item 'HKCU:\Software\MariKeyboard' -ErrorAction SilentlyContinue
  Kick-Ctf
  Log "Системный индикатор языка возвращён для $env:USERNAME"
}

try {
  switch ($Action) {
    'Register'   { Do-Register }
    'Unregister' { Do-Unregister }
    'AddUser'    { Do-AddUser }
    'RemoveUser' { Do-RemoveUser }
    'Verify'     { Do-Verify }
    'HideSysIndicator'    { Do-HideSys }
    'RestoreSysIndicator' { Do-RestoreSys }
    default {
      $klid = Get-OurKlid
      Write-Output "KLID: $klid"
      if ($klid) { Get-ItemProperty (Join-Path $KL $klid) | Select-Object 'Layout*' | Format-List | Out-String | Write-Output; Write-Output ('Tips: ' + (Get-OurTips $klid.ToUpper())) }
      Get-WinUserLanguageList | Format-Table LanguageTag, LocalizedName, EnglishName, InputMethodTips -AutoSize | Out-String -Width 200 | Write-Output
    }
  }
} catch { Log ("ОШИБКА: " + $_.Exception.Message); exit 1 }
