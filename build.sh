#!/bin/bash
# Сборка kbdmari.dll для x86 / WOW64 / x64 / ARM64 (clang + lld-link) и инсталлятора (NSIS).
# Автор раскладки: Михаил Пирогов
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/gen_layout.py
mkdir -p build dist
llvm-rc /nologo /C 65001 /FO build/kbdmari.res src/kbdmari.rc
CFLAGS="-O2 -ffreestanding -fno-builtin -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables -fms-extensions -Wall -Werror"
build() { # name target machine extra-cflags base extra-ldflags
  local n=$1 tgt=$2 mach=$3 cf=$4 base=$5 ld=$6
  mkdir -p build/$n
  clang --target=$tgt $CFLAGS $cf -c src/kbdmari.c -o build/$n/kbdmari.obj
  lld-link /nologo /DLL /NOENTRY /NODEFAULTLIB /MACHINE:$mach /SUBSYSTEM:NATIVE,5.01 /RELEASE \
    /DEF:src/kbdmari.def /BASE:$base /MERGE:.rdata=.data /MERGE:.text=.data /MERGE:.bss=.data \
    /SECTION:.data,RE /OPT:REF /INCREMENTAL:NO /IGNORE:4078 $ld \
    /OUT:build/$n/kbdmari.dll build/$n/kbdmari.obj build/kbdmari.res
  rm -f build/$n/kbdmari.lib build/$n/kbdmari.exp
}
build x86   i686-pc-windows-msvc    X86   ""             0x5FFF0000 "/DYNAMICBASE:NO /NXCOMPAT:NO /SAFESEH:NO"
build wow64 i686-pc-windows-msvc    X86   "-DKBD_WOW64"  0x5FFE0000 "/DYNAMICBASE:NO /NXCOMPAT:NO /SAFESEH:NO"
build x64   x86_64-pc-windows-msvc  X64   ""             0x5FFE0000 "/DYNAMICBASE:NO /NXCOMPAT:NO /HIGHENTROPYVA:NO"
build arm64 aarch64-pc-windows-msvc ARM64 ""             0x5FFE0000 ""
python3 tools/postlink.py build/*/kbdmari.dll
python3 tools/verify_dll.py | grep -v "^    {"
ls -la build/*/kbdmari.dll
# индикатор МАР/РУС для области уведомлений (32-битный: работает на x86, x64 и ARM64)
mkdir -p build/indicator
i686-w64-mingw32-windres -c 65001 indicator/mari_indicator.rc -O coff -o build/indicator/res.o
i686-w64-mingw32-gcc -municode -mwindows -Os -s -Wall -Wextra -Wno-unused-parameter -o build/indicator/MariIndicator.exe \
  indicator/mari_indicator.c build/indicator/res.o -lshell32 -luser32 -lgdi32 -ladvapi32 -static-libgcc
(cd installer && makensis -V2 mari-setup.nsi) && ls -la dist
