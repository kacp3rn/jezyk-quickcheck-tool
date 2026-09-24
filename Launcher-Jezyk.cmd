@echo off
REM ===========================================================================
REM  Jezyk - launcher.
REM
REM  Osobny plik .cmd jest potrzebny z trzech powodow:
REM    - dwuklik na pliku .ps1 otwiera go w Notatniku, a nie uruchamia,
REM    - WinForms wymaga trybu STA, ktorego nie da sie wlaczyc z wnetrza
REM      juz uruchomionego skryptu,
REM    - uruchomienie nie ma zalezec od ustawien PowerShella na stacji.
REM ===========================================================================

REM  Rozwijanie opoznione jest KONIECZNE: zmienna zmieniana wewnatrz petli "for"
REM  odczytuje sie wylacznie przez wykrzykniki. Bez tej linii "!JEZYK_BRAKI!"
REM  bylby zwyklym tekstem i sprawdzenie po cichu nie robiloby nic.
setlocal EnableDelayedExpansion

REM  ---------------------------------------------------------------------------
REM  SPRAWDZENIE KOMPLETU PLIKOW PRZED URUCHOMIENIEM.
REM
REM  powershell.exe -File ze wskazaniem na nieistniejacy plik konczy sie bledem
REM  wypisanym do konsoli, a konsola jest tu UKRYTA. Efekt dla uzytkownika: klika
REM  i NIE DZIEJE SIE NIC. Ten blok zamienia cisze w komunikat.
REM
REM  Zbieramy CALA liste brakow, a nie tylko pierwszy - kto kopiuje pliki recznie,
REM  woli zobaczyc od razu, ilu brakuje.
REM  ---------------------------------------------------------------------------
set "JEZYK_BRAKI="
for %%P in (Kod-Jezyk.ps1 Jezyk-1-Srodowisko.ps1 Jezyk-2-Logika.ps1 Jezyk-3-Widok.ps1 Jezyk-4-Okno.ps1) do (
    if not exist "%~dp0%%P" set "JEZYK_BRAKI=!JEZYK_BRAKI! %%P"
)

REM  NAWIASY W TRESCI "echo" WEWNATRZ BLOKU MUSZA BYC OSLONIETE DASZKIEM ^( ^).
REM  cmd.exe traktuje "(" jako otwarcie bloku tylko tam, gdzie spodziewa sie
REM  polecenia, ale nawiasu ")" szuka ZAWSZE - wiec ")" w komunikacie konczy blok
REM  w tym miejscu, a reszta linii wypada poza warunek i wykonuje sie zawsze.
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

REM  PELNA SCIEZKA DO POWERSHELLA, a nie sama nazwa. Przy nazwie bez sciezki
REM  zarowno "start", jak i CreateProcess przeszukuja KATALOG BIEZACY, zanim
REM  zajrza do System32 - a katalogiem biezacym przy dwukliku jest katalog
REM  wdrozenia. Plik "powershell.exe" podlozony obok Jezyka dostawalby wtedy
REM  sterowanie zamiast systemowego.
set "JEZYK_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%JEZYK_PS%" (
    echo.
    echo   BLAD: nie znaleziono Windows PowerShella pod sciezka:
    echo   %JEZYK_PS%
    echo.
    pause
    exit /b 1
)

REM  ---------------------------------------------------------------------------
REM  URUCHOMIENIE.
REM
REM  conhost.exe wymusza KLASYCZNY host konsoli. Bez tego na Windows 11 konsole
REM  potrafi przejac Windows Terminal, a wtedy GetConsoleWindow zwraca skryptowi
REM  uchwyt UKRYTEGO okna pomocniczego - skrypt chowa okno, ktorego nikt nie widzi,
REM  a widoczne nalezy do WindowsTerminal.exe. Brak conhost.exe nie moze zablokowac
REM  uruchomienia, stad galaz zapasowa.
REM
REM  "start /b" NIE tworzy nowego okna i NIE CZEKA na zakonczenie programu, wiec
REM  cmd.exe konczy sie natychmiast i oddaje konsole skryptowi. Od tej chwili
REM  PowerShell jest na niej jedynym procesem - i dopiero wtedy wolno mu ja zwolnic
REM  (skrypt sam liczy procesy konsoli, nie dostaje zadnego sygnalu). Stary launcher
REM  czekal, wiec trzymal konsole przez caly czas pracy programu i jej ikona
REM  zostawala na pasku zadan obok ikony Jezyka.
REM
REM  Uwaga: samo "start" bez /b tworzy DRUGIE, widoczne okno konsoli. Flaga /b jest
REM  konieczna, nie ozdobna.
REM
REM  Przelaczniki PowerShella:
REM    -NoProfile           pomija profil uzytkownika: szybszy start i brak wplywu
REM                         prywatnych ustawien na dzialanie narzedzia.
REM    -ExecutionPolicy     pozwala uruchomic skrypt bez trwalej zmiany polityki
REM      Bypass             wykonywania - dotyczy tylko tego procesu.
REM    -STA                 model watkowy wymagany przez WinForms.
REM    -WindowStyle Hidden  skraca migniecie konsoli przy starcie.
REM    -File                uruchamia wskazany plik skryptu.
REM
REM  "%~dp0" to katalog TEGO pliku, wiec Kod-Jezyk.ps1 jest szukany obok launchera,
REM  a nie w katalogu biezacym - skrot mozna umiescic gdziekolwiek. Cudzyslowy
REM  zabezpieczaja sciezki ze spacjami.
REM
REM  "cd /d %SystemRoot%" PRZED "start" - LAUNCHER OPUSZCZA KATALOG WDROZENIA, ZANIM
REM  URUCHOMI COKOLWIEK. Przy dwukliku katalogiem biezacym launchera jest folder, w ktorym
REM  lezy Jezyk, a Windows trzyma otwarty uchwyt katalogu biezacego kazdego procesu - i ten
REM  uchwyt jest DZIEDZICZONY. cmd.exe uruchamia procesy z dziedziczeniem uchwytow,
REM  conhost.exe tak samo, wiec powershell.exe dostawal kopie uchwytu do folderu wdrozenia
REM  i trzymal ja do zamkniecia okna. Objaw: pliki z folderu dalo sie usunac (program
REM  wczytuje je przy starcie i od razu zamyka), a samego folderu nie - ani usunac, ani
REM  przemianowac - dopoki ktokolwiek mial otwartego Jezyka.
REM
REM  SAMO "start /d" TEGO NIE NAPRAWIA i juz raz nie naprawilo: zmienia katalog biezacy
REM  procesu potomnego, ale odziedziczonego uchwytu mu nie zabiera. Dopiero "cd" zamyka
REM  uchwyt w samym launcherze, wiec procesom potomnym nie ma juz czego przekazac.
REM  Program katalogu biezacego nie uzywa wcale: pliki szuka przez $PSScriptRoot, czyli
REM  obok Kod-Jezyk.ps1.
REM
REM  Sciezka skryptu zapamietana PRZED "cd": "%~dp0" launchera wywolanego sciezka wzgledna
REM  liczy sie od katalogu biezacego, wiec po zmianie katalogu moglby wskazac %SystemRoot%.
REM  Od linii "cd" w dol "%~dp0" nie pada juz ani razu.
REM
REM  Gdy okno programu sie nie pojawia: launcher nie czeka, wiec blad nie zdazy
REM  pokazac sie w konsoli. Opis trafia do %TEMP%\Jezyk-blad.txt; mozna tez uruchomic
REM  skrypt wprost w otwartym oknie PowerShella - wtedy skrypt nie tknie tej konsoli,
REM  bo widzi, ze nie jest na niej sam, i komunikat zostanie na ekranie.
REM  ---------------------------------------------------------------------------
set "JEZYK_SKRYPT=%~dp0Kod-Jezyk.ps1"
cd /d "%SystemRoot%"

if exist "%SystemRoot%\System32\conhost.exe" (
    start "" /b "%SystemRoot%\System32\conhost.exe" "%JEZYK_PS%" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%JEZYK_SKRYPT%"
) else (
    start "" /b "%JEZYK_PS%" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%JEZYK_SKRYPT%"
)
