@echo off
REM Jezyk - launcher: sprawdza komplet plikow i uruchamia Kod-Jezyk.ps1 (README: Kod > Launcher-Jezyk.cmd).
REM Zabraniam modyfikacji i dalszego rozwoju skryptu bez:
REM - Wcześniejszego pozwolenia na modyfikację kodu przez osobę trzecią.
REM - Uwzględnienia mnie (X) jako głównego autora skryptu.

REM Rozwijanie opoznione: bez niego !JEZYK_BRAKI! w petli "for" jest zwyklym tekstem.
setlocal EnableDelayedExpansion

REM Komplet plikow przed startem - konsola jest ukryta, wiec brak pliku bylby cisza.
set "JEZYK_BRAKI="
for %%P in (Kod-Jezyk.ps1 Jezyk-1-Srodowisko.ps1 Jezyk-2-Logika.ps1 Jezyk-3-Widok.ps1 Jezyk-4-Okno.ps1) do (
    if not exist "%~dp0%%P" set "JEZYK_BRAKI=!JEZYK_BRAKI! %%P"
)

REM Uwaga: nawiasy w "echo" wewnatrz bloku oslaniamy daszkiem ^( ^) - ")" zamyka blok.
if defined JEZYK_BRAKI (
    echo.
    echo   BLAD: w tym katalogu brakuje plikow programu.
    echo.
    echo   Katalog: %~dp0
    echo.
    echo   Brakuje:!JEZYK_BRAKI!
    echo.
    echo   W katalogu maja lezec razem:
    echo     Kod-Jezyk.ps1            plik wejsciowy - ten uruchamia launcher
    echo     Jezyk-1-Srodowisko.ps1   konsola, biblioteki, konfiguracja
    echo     Jezyk-2-Logika.ps1       odpytanie AD i SCCM
    echo     Jezyk-3-Widok.ps1        wypelnianie okna
    echo     Jezyk-4-Okno.ps1         budowa okna
    echo     Launcher-Jezyk.cmd
    echo     Ikona-Jezyk.ico          ^(opcjonalna^)
    echo.
    echo   Domeny i ustawienia SCCM siedza w Jezyk-1-Srodowisko.ps1 -
    echo   osobnego pliku konfiguracyjnego nie ma.
    echo.
    pause
    exit /b 1
)

REM Pelna sciezka: sama nazwa powershell.exe bylaby szukana najpierw w katalogu wdrozenia.
set "JEZYK_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%JEZYK_PS%" (
    echo.
    echo   BLAD: nie znaleziono Windows PowerShella pod sciezka:
    echo   %JEZYK_PS%
    echo.
    pause
    exit /b 1
)

REM Start przez conhost.exe (klasyczna konsola) i "start /b" (bez nowego okna, bez czekania).
REM Uwaga: "cd /d" przed "start" zwalnia uchwyt folderu wdrozenia; za "cd" nie uzywac %~dp0.
REM Gdy okno sie nie pojawia, opis bledu jest w %TEMP%\Jezyk-blad.txt.
set "JEZYK_SKRYPT=%~dp0Kod-Jezyk.ps1"
cd /d "%SystemRoot%"

if exist "%SystemRoot%\System32\conhost.exe" (
    start "" /b "%SystemRoot%\System32\conhost.exe" "%JEZYK_PS%" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%JEZYK_SKRYPT%"
) else (
    start "" /b "%JEZYK_PS%" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%JEZYK_SKRYPT%"
)
