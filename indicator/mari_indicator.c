/* MariIndicator — индикатор активной раскладки в области уведомлений.
   Windows показывает на панели задач аббревиатуру ЯЗЫКА («РУС»), поэтому «Марийская» и «Русская»
   выглядят одинаково. Индикатор показывает «МАР» (малиновый значок), когда активна марийская раскладка,
   и аббревиатуру языка (серый значок) для остальных. Автор: Пирогов Михаил, pirogovlab.ru */
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>

#define WM_TRAY   (WM_APP + 1)
#define ID_TRAY   1
#define IDM_MAP   101
#define IDM_EXIT  102
#define TIMER_POLL 1
#define TIMER_CFG  2

static HWND g_hwnd; static UINT g_taskbarCreated;
static WORD g_mariDev = 0;           /* старшее слово HKL марийской раскладки: 0xF000 | Layout Id */
static wchar_t g_klid[16] = L"";
static DWORD g_lastKey = 0xFFFFFFFF; static HICON g_icon = NULL;
static NOTIFYICONDATAW g_nid;

static void LoadConfig(void) {
  HKEY k; wchar_t buf[32]; DWORD sz, type;
  g_mariDev = 0;
  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\MariKeyboard", 0, KEY_READ | KEY_WOW64_64KEY, &k) == ERROR_SUCCESS) {
    sz = sizeof(buf); if (RegQueryValueExW(k, L"KLID", NULL, &type, (BYTE*)buf, &sz) == ERROR_SUCCESS && type == REG_SZ) { buf[31] = 0; lstrcpynW(g_klid, buf, 16); }
    RegCloseKey(k);
  }
  if (g_klid[0]) {
    wchar_t path[128]; wsprintfW(path, L"SYSTEM\\CurrentControlSet\\Control\\Keyboard Layouts\\%s", g_klid);
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, path, 0, KEY_READ | KEY_WOW64_64KEY, &k) == ERROR_SUCCESS) {
      sz = sizeof(buf); if (RegQueryValueExW(k, L"Layout Id", NULL, &type, (BYTE*)buf, &sz) == ERROR_SUCCESS && type == REG_SZ) {
        buf[31] = 0; g_mariDev = (WORD)(0xF000 | (wcstoul(buf, NULL, 16) & 0x0FFF));
      }
      RegCloseKey(k);
    }
  }
}

static void LangAbbr(WORD lang, wchar_t *out) {
  if (PRIMARYLANGID(lang) == LANG_RUSSIAN) { lstrcpyW(out, L"РУС"); return; }
  if (PRIMARYLANGID(lang) == LANG_ENGLISH) { lstrcpyW(out, L"ENG"); return; }
  if (!GetLocaleInfoW(MAKELCID(lang, SORT_DEFAULT), LOCALE_SISO639LANGNAME2, out, 8)) lstrcpyW(out, L"???");
  CharUpperW(out);
}

/* пиксельный шрифт 7 строк: чёткие буквы на значке 16×16 */
typedef struct { wchar_t ch; int w; const char *rows[7]; } Glyph;
static const Glyph GLYPHS[] = {
  { L'М', 5, {"10001","11011","10101","10001","10001","10001","10001"} },
  { L'А', 4, {"0110","1001","1001","1111","1001","1001","1001"} },
  { L'Р', 4, {"1110","1001","1001","1110","1000","1000","1000"} },
  { L'У', 4, {"1001","1001","1001","0111","0001","0001","1110"} },
  { L'С', 4, {"0111","1000","1000","1000","1000","1000","0111"} },
  { L'E', 4, {"1111","1000","1000","1110","1000","1000","1111"} },
  { L'N', 4, {"1001","1101","1101","1011","1011","1001","1001"} },
  { L'G', 4, {"0111","1000","1000","1011","1001","1001","0111"} },
};
static const Glyph *FindGlyph(wchar_t c) {
  for (unsigned i = 0; i < sizeof(GLYPHS) / sizeof(GLYPHS[0]); i++) if (GLYPHS[i].ch == c) return &GLYPHS[i];
  return NULL;
}
/* рисует текст пиксельным шрифтом; 0 — если какой-то буквы нет (тогда рисуем шрифтом Windows) */
static int DrawPixelText(DWORD *px, int n, const wchar_t *t) {
  int len = lstrlenW(t), w = 0, i, s = n >= 32 ? 2 : 1;
  for (i = 0; i < len; i++) { const Glyph *g = FindGlyph(t[i]); if (!g) return 0; w += g->w + (i ? 1 : 0); }
  if (w * s > n - 1) return 0;
  int x0 = (n - w * s) / 2, y0 = (n - 7 * s) / 2, x = x0;
  for (i = 0; i < len; i++) {
    const Glyph *g = FindGlyph(t[i]);
    for (int r = 0; r < 7; r++) for (int c = 0; c < g->w; c++) if (g->rows[r][c] == '1')
      for (int dy = 0; dy < s; dy++) for (int dx = 0; dx < s; dx++) px[(y0 + r * s + dy) * n + x + c * s + dx] = 0x00FFFFFF;
    x += (g->w + 1) * s;
  }
  return 1;
}

static HICON MakeIcon(const wchar_t *text, COLORREF bg, COLORREF border) {
  int n = GetSystemMetrics(SM_CXSMICON); if (n < 16) n = 16;
  BITMAPINFO bi; ZeroMemory(&bi, sizeof(bi));
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER); bi.bmiHeader.biWidth = n; bi.bmiHeader.biHeight = -n;
  bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
  HDC scr = GetDC(NULL), dc = CreateCompatibleDC(scr); DWORD *px = NULL;
  HBITMAP col = CreateDIBSection(scr, &bi, DIB_RGB_COLORS, (void**)&px, NULL, 0);
  HGDIOBJ oldb = SelectObject(dc, col);
  int r = n / 6, x, y;
  for (y = 0; y < n; y++) for (x = 0; x < n; x++) {
    int edge = (x == 0 || y == 0 || x == n - 1 || y == n - 1);
    COLORREF c = edge ? border : bg;
    px[y * n + x] = (GetRValue(c) << 16) | (GetGValue(c) << 8) | GetBValue(c);
  }
  if (!DrawPixelText(px, n, text)) {
    /* текст: подбираем размер шрифта, чтобы 3 буквы влезли по ширине */
    int h = n * 70 / 100; HFONT f = NULL, oldf; SIZE ts;
    for (; h > 6; h--) {
      if (f) DeleteObject(f);
      f = CreateFontW(-h, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                      ANTIALIASED_QUALITY, DEFAULT_PITCH, L"Segoe UI");
      oldf = SelectObject(dc, f); GetTextExtentPoint32W(dc, text, lstrlenW(text), &ts); SelectObject(dc, oldf);
      if (ts.cx <= n - 2) break;
    }
    oldf = SelectObject(dc, f); SetBkMode(dc, TRANSPARENT); SetTextColor(dc, RGB(255, 255, 255));
    RECT rc = {0, 0, n, n}; DrawTextW(dc, text, -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    SelectObject(dc, oldf); DeleteObject(f); GdiFlush();
  }
  GdiFlush();
  for (y = 0; y < n; y++) for (x = 0; x < n; x++) {           /* непрозрачно, кроме скруглённых углов */
    int dx = x < r ? r - x : (x >= n - r ? x - (n - r - 1) : 0), dy = y < r ? r - y : (y >= n - r ? y - (n - r - 1) : 0);
    DWORD a = (dx * dx + dy * dy > r * r) ? 0 : 255;
    px[y * n + x] = (a << 24) | (px[y * n + x] & 0x00FFFFFF);
    if (!a) px[y * n + x] = 0;
  }
  HBITMAP mask = CreateBitmap(n, n, 1, 1, NULL);
  HDC mdc = CreateCompatibleDC(scr); HGDIOBJ om = SelectObject(mdc, mask); PatBlt(mdc, 0, 0, n, n, BLACKNESS); SelectObject(mdc, om); DeleteDC(mdc);
  ICONINFO ii = {TRUE, 0, 0, mask, col};
  SelectObject(dc, oldb); HICON ic = CreateIconIndirect(&ii);
  DeleteObject(col); DeleteObject(mask); DeleteDC(dc); ReleaseDC(NULL, scr);
  return ic;
}

static void Update(int force) {
  HWND fg = GetForegroundWindow();
  DWORD tid = fg ? GetWindowThreadProcessId(fg, NULL) : 0;
  HKL hkl = GetKeyboardLayout(tid);
  DWORD key = (DWORD)(ULONG_PTR)hkl;
  if (!fg || !hkl) return;                                   /* нет активного окна — оставляем как было */
  if (!force && key == g_lastKey) return;
  g_lastKey = key;
  WORD dev = HIWORD(key), lang = LOWORD(key);
  int mari = g_mariDev && dev == g_mariDev;
  wchar_t abbr[16];
  HICON ic;
  if (mari) { lstrcpyW(abbr, L"МАР"); ic = MakeIcon(abbr, RGB(155, 27, 48), RGB(155, 27, 48)); }
  else      { LangAbbr(lang, abbr);    ic = MakeIcon(abbr, RGB(72, 72, 78), RGB(110, 110, 118)); }
  g_nid.uFlags = NIF_ICON | NIF_TIP | NIF_SHOWTIP; g_nid.hIcon = ic;
  if (mari) lstrcpynW(g_nid.szTip, L"Сейчас: Марийская раскладка (AltGr + а, о, у, ы, н → ӓ ӧ ӱ ӹ ҥ)", 128);
  else { wchar_t t[128]; wsprintfW(t, L"Сейчас: не марийская раскладка (%s)", abbr); lstrcpynW(g_nid.szTip, t, 128); }
  Shell_NotifyIconW(NIM_MODIFY, &g_nid);
  if (g_icon) DestroyIcon(g_icon);
  g_icon = ic;
}

static void AddTray(void) {
  ZeroMemory(&g_nid, sizeof(g_nid));
  g_nid.cbSize = sizeof(g_nid); g_nid.hWnd = g_hwnd; g_nid.uID = ID_TRAY;
  g_nid.uFlags = NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP; g_nid.uCallbackMessage = WM_TRAY;
  lstrcpynW(g_nid.szTip, L"Индикатор марийской раскладки", 128);
  Shell_NotifyIconW(NIM_ADD, &g_nid);
  g_nid.uVersion = NOTIFYICON_VERSION_4; Shell_NotifyIconW(NIM_SETVERSION, &g_nid);
  g_lastKey = 0xFFFFFFFF; Update(1);
}

static void OpenKeymap(void) {
  wchar_t p[MAX_PATH]; GetModuleFileNameW(NULL, p, MAX_PATH);
  wchar_t *s = wcsrchr(p, L'\\'); if (s) lstrcpyW(s + 1, L"keymap.html");
  ShellExecuteW(NULL, L"open", p, NULL, NULL, SW_SHOWNORMAL);
}

static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
  if (m == g_taskbarCreated && m) { AddTray(); return 0; }
  switch (m) {
  case WM_TIMER:
    if (w == TIMER_POLL) Update(0); else { LoadConfig(); Update(1); }
    return 0;
  case WM_TRAY:
    if (LOWORD(l) == WM_CONTEXTMENU || LOWORD(l) == WM_RBUTTONUP) {
      HMENU mn = CreatePopupMenu(); POINT pt; GetCursorPos(&pt);
      AppendMenuW(mn, MF_STRING, IDM_MAP, L"Схема марийской раскладки");
      AppendMenuW(mn, MF_SEPARATOR, 0, NULL);
      AppendMenuW(mn, MF_STRING, IDM_EXIT, L"Закрыть индикатор");
      SetForegroundWindow(h);
      TrackPopupMenu(mn, TPM_RIGHTBUTTON, pt.x, pt.y, 0, h, NULL); DestroyMenu(mn);
    } else if (LOWORD(l) == WM_LBUTTONDBLCLK || LOWORD(l) == NIN_SELECT) OpenKeymap();
    return 0;
  case WM_COMMAND:
    if (LOWORD(w) == IDM_MAP) OpenKeymap();
    else if (LOWORD(w) == IDM_EXIT) DestroyWindow(h);
    return 0;
  case WM_DESTROY:
    Shell_NotifyIconW(NIM_DELETE, &g_nid); if (g_icon) DestroyIcon(g_icon); PostQuitMessage(0); return 0;
  }
  return DefWindowProcW(h, m, w, l);
}

int WINAPI wWinMain(HINSTANCE hi, HINSTANCE hp, LPWSTR cmd, int show) {
  (void)hp; (void)show;
  HANDLE mx = CreateMutexW(NULL, TRUE, L"Local\\MariKeyboardIndicator");
  if (cmd && wcsstr(cmd, L"/quit")) {                          /* закрыть запущенный индикатор (для удаления/обновления) */
    HWND o = FindWindowW(L"MariKeyboardIndicatorWnd", NULL); if (o) PostMessageW(o, WM_CLOSE, 0, 0); return 0;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;
  SetProcessDPIAware();
  WNDCLASSW wc; ZeroMemory(&wc, sizeof(wc)); wc.lpfnWndProc = WndProc; wc.hInstance = hi; wc.lpszClassName = L"MariKeyboardIndicatorWnd";
  RegisterClassW(&wc);
  g_hwnd = CreateWindowExW(0, wc.lpszClassName, L"MariKeyboardIndicator", 0, 0, 0, 0, 0, NULL, NULL, hi, NULL);
  g_taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
  LoadConfig(); AddTray();
  SetTimer(g_hwnd, TIMER_POLL, 200, NULL); SetTimer(g_hwnd, TIMER_CFG, 15000, NULL);
  MSG msg; while (GetMessageW(&msg, NULL, 0, 0) > 0) { TranslateMessage(&msg); DispatchMessageW(&msg); }
  if (mx) CloseHandle(mx);
  return 0;
}
