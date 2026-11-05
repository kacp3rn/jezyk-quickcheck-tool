@echo off
REM Jezyk - kompilator: sklada piec czesci programu i ikone w jeden Jezyk.exe (README: Kod > Jezyk-Kompilator.cmd).
REM Zabraniam modyfikacji i dalszego rozwoju skryptu bez:
REM - Wczesniejszego pozwolenia na modyfikacje kodu przez osobe trzecia.
REM - Uwzglednienia mnie (kacp3rn) jako glownego autora skryptu.

REM pushd zamiast cd: przyjmuje tez sciezke udzialu - na czas pracy mapuje ja na litere dysku.
REM Stoi przed "setlocal": przy rozwijaniu opoznionym znak "!" w sciezce by zniknal.
pushd "%~dp0"
if errorlevel 1 (
    echo.
    echo   BLAD: nie udalo sie otworzyc katalogu z plikami programu.
    echo.
    pause
    exit /b 1
)

REM Rozwijanie opoznione: bez niego !JEZYK_BRAKI! w petli "for" jest zwyklym tekstem.
setlocal EnableDelayedExpansion

REM Pliki wkompilowane w exe - pod tymi nazwami Jezyk.exe je rozpakuje.
set "JEZYK_PLIKI=Kod-Jezyk.ps1 Jezyk-1-Srodowisko.ps1 Jezyk-2-Logika.ps1 Jezyk-3-Widok.ps1 Jezyk-4-Okno.ps1 Ikona-Jezyk.ico"

REM Komplet przed kompilacja - cala lista brakow w jednym komunikacie.
set "JEZYK_BRAKI="
for %%P in (%JEZYK_PLIKI% Jezyk-Exe.cs) do (
    if not exist "%%P" set "JEZYK_BRAKI=!JEZYK_BRAKI! %%P"
)

if defined JEZYK_BRAKI (
    echo.
    echo   BLAD: w katalogu kompilatora brakuje plikow programu.
    echo.
    echo   Brakuje:!JEZYK_BRAKI!
    echo.
    echo   W katalogu maja lezec razem:
    echo     Kod-Jezyk.ps1            plik wejsciowy
    echo     Jezyk-1-Srodowisko.ps1   konsola, biblioteki, konfiguracja
    echo     Jezyk-2-Logika.ps1       odpytanie AD i SCCM
    echo     Jezyk-3-Widok.ps1        wypelnianie okna
    echo     Jezyk-4-Okno.ps1         budowa okna
    echo     Ikona-Jezyk.ico          ikona exe i okna
    echo     Jezyk-Exe.cs             kod Jezyk.exe
    echo     Jezyk-Kompilator.cmd
    echo.
    echo   Domeny i ustawienia SCCM siedza w Jezyk-1-Srodowisko.ps1 -
    echo   kompilator wklada je do exe razem z kodem.
    echo.
    goto :blad
)

REM Kompilator C# z .NET Framework 4.x - jest w kazdym Windows 10 i 11, nic nie instalujemy.
set "JEZYK_CSC=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%JEZYK_CSC%" set "JEZYK_CSC=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%JEZYK_CSC%" (
    echo.
    echo   BLAD: nie znaleziono kompilatora C# z .NET Framework 4.x:
    echo   %SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
    echo.
    goto :blad
)

REM Kazdy plik jako zasob o nazwie pliku.
set "JEZYK_ZASOBY="
for %%P in (%JEZYK_PLIKI%) do set "JEZYK_ZASOBY=!JEZYK_ZASOBY! /resource:%%P,%%P"

REM winexe - bez okna konsoli; anycpu - proces 64-bitowy w systemie 64-bitowym; 65001 - plik .cs w UTF-8.
echo.
echo   Kompilowanie Jezyk.exe...
echo.
"%JEZYK_CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /win32icon:Ikona-Jezyk.ico /out:Jezyk.exe!JEZYK_ZASOBY! Jezyk-Exe.cs

if errorlevel 1 (
    echo.
    echo   BLAD: kompilacja sie nie udala - opis powyzej.
    echo   Gdy csc nie moze zapisac Jezyk.exe, ten plik wlasnie startuje - sprobuj ponownie za chwile.
    echo.
    goto :blad
)

echo   Gotowe: %~dp0Jezyk.exe
echo.
echo   Skrot SHA-256 - przyda sie do wyjatku w antywirusie:
certutil -hashfile Jezyk.exe SHA256
echo.
echo   Exe niesie kopie plikow .ps1 - po kazdej ich zmianie uruchom kompilator ponownie.
echo   Aktualizacja dla operatorow: podnies Wersja w Jezyk-1-Srodowisko.ps1,
echo   skompiluj i skopiuj Jezyk.exe do folderu z ustawienia FolderAktualizacji.
echo.
popd
pause
exit /b 0

:blad
popd
pause
exit /b 1
