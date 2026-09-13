# Jezyk-1-Srodowisko - konsola, biblioteki interfejsu, konfiguracja narzedzia.
# TA LINIA MUSI POZOSTAC ZWYKLYM KOMENTARZEM - oslania pierwsza instrukcje przed
# zdublowanym znacznikiem BOM. Powod opisany w Kod-Jezyk.ps1.

# WLASNY TRAP W KAZDEJ CZESCI. Trap wznawia wykonanie w zakresie, w ktorym zostal
# ZDEFINIOWANY - gdyby ta czesc polegala na trapie z Kod-Jezyk.ps1, blad w jej linii 1
# wznowilby prace w pliku wolajacym, czyli porzucil cala reszte tego pliku.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 1 - SRODOWISKO I KONFIGURACJA

# --- KONSOLA -------------------------------------------------------------------------
# powershell.exe jest aplikacja konsolowa, wiec Windows zawsze przydziela mu konsole.
# Pozbywamy sie jej w dwoch fazach:
#   1. ukrycie okna (tutaj, na dole sekcji) - usuwa przycisk z paska zadan, ale NIE
#      niszczy konsoli, wiec pasek postepu z Import-Module ma gdzie pisac,
#   2. FreeConsole (w Kod-Jezyk.ps1, po zaladowaniu modulu AD) - po nim proces nie ma
#      konsoli i kazda proba pisania do hosta konczy sie bledem 0x6.
#
# Obie fazy chroni ten sam warunek: dzialamy tylko wtedy, gdy jestesmy na konsoli
# JEDYNYM procesem. Uruchomienie z otwartego okna PowerShella nie moze zabrac
# uzytkownikowi okna, w ktorym pracuje.
#
# SetCurrentProcessExplicitAppUserModelID odlacza okno od powershell.exe, dzieki czemu
# pasek zadan uzywa ikony Jezyka, a nie ikony PowerShella. Musi paść przed pierwszym oknem.
#
# Calosc pod try, bo to wylacznie kosmetyka: gdyby kompilacja C# byla na stacji
# zablokowana, narzedzie ma dalej dzialac - z widoczna konsola, ale sprawne.

# Opis awarii trafia do %TEMP%\Jezyk-konsola.txt WYLACZNIE gdy cos poszlo nie tak;
# przy poprawnym uruchomieniu plik jest kasowany. Jego obecnosc jest wiec informacja.
$Script:BladKonsoli   = $null
$Script:UchwytKonsoli = [IntPtr]::Zero
$Script:OknoUkryte    = $false
$Script:KonsolaZwolniona = $false

try {
    # Warunek chroni przed bledem "typ juz istnieje" przy ponownym uruchomieniu skryptu
    # w tej samej sesji PowerShella.
    if (-not ('Jezyk.Native' -as [type])) {
        Add-Type -Namespace 'Jezyk' -Name 'Native' -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
public static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);

[DllImport("kernel32.dll")]
public static extern uint GetConsoleProcessList(uint[] lpdwProcessList, uint dwProcessCount);

[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("kernel32.dll", SetLastError = true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool FreeConsole();

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

[DllImport("user32.dll", SetLastError = true)]
public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

[DllImport("user32.dll", SetLastError = true)]
public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

[DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);

[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
public static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndAfter, int x, int y,
                                       int cx, int cy, uint flags);
'@
    }

    [void][Jezyk.Native]::SetCurrentProcessExplicitAppUserModelID('Skrypt.Jezyk.StatusKontaAD')
}
catch {
    $Script:BladKonsoli = "Przygotowanie funkcji systemowych: $($_.Exception.Message)"
}

<#
.SYNOPSIS
    Czy konsola nalezy wylacznie do nas? Rozstrzyga liczba przypietych do niej procesow.

.DESCRIPTION
    1 = konsola jest nasza, wolno przy niej dzialac. Wiecej = siedzi na niej ktos jeszcze.
    Odpowiedz "nie wiem" brzmi $false, bo nieruszanie cudzej konsoli jest bezpiecznym
    zachowaniem domyslnym.
#>
function Test-JezykKonsolaNasza {
    if (-not ('Jezyk.Native' -as [type])) { return $false }

    try {
        $buforPid = [uint32[]]::new(8)
        return ([Jezyk.Native]::GetConsoleProcessList($buforPid, 8) -eq 1)
    }
    catch {
        $Script:BladKonsoli = "Liczenie procesów konsoli: $($_.Exception.Message)"
        return $false
    }
}

# Ukrywa okno konsoli - to ono usuwa ikone z paska zadan.
function Hide-JezykOknoKonsoli {

    if ($Script:OknoUkryte -or -not (Test-JezykKonsolaNasza)) { return }

    try {
        $Script:UchwytKonsoli = [Jezyk.Native]::GetConsoleWindow()
        if ($Script:UchwytKonsoli -eq [IntPtr]::Zero) { return }

        # 0 = SW_HIDE. Najpierw chowamy, potem zmieniamy styl - na oknie juz ukrytym
        # zmiana dziala pewniej.
        [void][Jezyk.Native]::ShowWindow($Script:UchwytKonsoli, 0)

        # GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80. Suma bitowa, zeby nie skasowac
        # pozostalych stylow. Okno narzedziowe nigdy nie dostaje przycisku na pasku zadan.
        $styl = [Jezyk.Native]::GetWindowLong($Script:UchwytKonsoli, -20)
        [void][Jezyk.Native]::SetWindowLong($Script:UchwytKonsoli, -20, ($styl -bor 0x80))
        [void][Jezyk.Native]::ShowWindow($Script:UchwytKonsoli, 0)

        $Script:OknoUkryte = $true
    }
    catch {
        $Script:BladKonsoli = "Ukrywanie okna konsoli: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Przelacza pasek tytulu okna na ciemny albo jasny.

.DESCRIPTION
    JEDYNA CZESC MOTYWU, KTOREJ WINFORMS NIE UMIE. Pasek tytulu lezy poza obszarem klienta
    i rysuje go menedzer okien, wiec nie ma kontrolki, ktorej mozna by ustawic BackColor -
    bez tego wywolania nad ciemnym oknem zostaje biala belka.

    ATRYBUT MA DWA NUMERY. W Windows 11 i w nowszych kompilacjach Windows 10 to 20
    (DWMWA_USE_IMMERSIVE_DARK_MODE); w kompilacjach 1809-1909 ten sam atrybut mial numer 19
    i pod dwudziestka nie dziala. Probujemy obu - DWM nie zna atrybutu po cichu, oddajac
    niezerowy HRESULT, a nie rzucajac wyjatkiem.

    NIEPOWODZENIE JEST DOPUSZCZALNE: zostaje jasny pasek nad ciemnym oknem. To brzydkie,
    ale dziala, wiec funkcja nie ma prawa zatrzymac programu. Blok catch lapie w praktyce
    jeden przypadek - zablokowana na stacji kompilacje C#, przez ktora nie powstal caly typ
    Jezyk.Native. Ten sam powod jest juz zapisany do $Script:BladKonsoli przy Add-Type
    i stamtad trafia do pliku diagnostycznego, wiec nie zakladamy tu drugiego kanalu.
#>
function Set-JezykCiemnyPasekTytulu {
    param([IntPtr]$Uchwyt, [switch]$Ciemny)

    if ($Uchwyt -eq [IntPtr]::Zero)      { return }
    if (-not ('Jezyk.Native' -as [type])) { return }

    try {
        $wartosc = if ($Ciemny) { 1 } else { 0 }

        $wynik = [Jezyk.Native]::DwmSetWindowAttribute($Uchwyt, 20, [ref]$wartosc, 4)
        if ($wynik -ne 0) {
            $wynik = [Jezyk.Native]::DwmSetWindowAttribute($Uchwyt, 19, [ref]$wartosc, 4)
        }
        if ($wynik -ne 0) { return }

        # Belka tytulu nie nalezy do obszaru klienta, wiec Invalidate jej nie dotyczy.
        # Bez ponizszego okno przemalowuje ja dopiero przy pierwszym przesunieciu - czyli
        # klikniecie ikonki wygladaloby na wykonane do polowy.
        # SWP_NOSIZE 0x1 | SWP_NOMOVE 0x2 | SWP_NOZORDER 0x4 | SWP_FRAMECHANGED 0x20
        [void][Jezyk.Native]::SetWindowPos($Uchwyt, [IntPtr]::Zero, 0, 0, 0, 0, 0x27)
    }
    catch {
        $Script:BladKonsoli = "Ciemny pasek tytulu: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Przelacza paski przewijania kontrolki na ciemne albo jasne.

.DESCRIPTION
    Paski przewijania rysuje motyw systemu, nie WinForms - lista grup w ciemnym oknie
    zostalaby z jasnym paskiem po prawej. SetWindowTheme nadaje kontrolce klase wygladu:
    "DarkMode_Explorer" istnieje w Windows 10 od kompilacji 1809 i w Windows 11, a na
    starszych po prostu nie zostaje rozpoznana - i wtedy pasek zostaje jasny.

    Powrot to "Explorer", a nie pusta nazwa: pusta zdejmuje klase razem z wygladem
    systemowym i kontrolka przestaje wygladac jak reszta okna.
#>
function Set-JezykCiemnyPasekPrzewijania {
    param([IntPtr]$Uchwyt, [switch]$Ciemny)

    if ($Uchwyt -eq [IntPtr]::Zero)      { return }
    if (-not ('Jezyk.Native' -as [type])) { return }

    try {
        $klasa = if ($Ciemny) { 'DarkMode_Explorer' } else { 'Explorer' }
        # [NullString]::Value, a nie $null: pusty napis znaczylby "pusta lista
        # identyfikatorow", a chodzi o "uzyj domyslnych".
        [void][Jezyk.Native]::SetWindowTheme($Uchwyt, $klasa, [NullString]::Value)
    }
    catch {
        $Script:BladKonsoli = "Ciemne paski przewijania: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Zwalnia konsole. Wywolywane POZNO - dopiero po zaladowaniu modulu AD.

.DESCRIPTION
    Kolejnosc jest czescia dzialania: Import-Module ActiveDirectory rysuje pasek postepu,
    czyli pisze do hosta, a po FreeConsole taki zapis konczy sie bledem 0x6.
#>
function Invoke-JezykZwolnienieKonsoli {

    if ($Script:KonsolaZwolniona) { return }
    $Script:KonsolaZwolniona = $true

    try {
        Hide-JezykOknoKonsoli
        if (-not (Test-JezykKonsolaNasza)) { return }
        [void][Jezyk.Native]::FreeConsole()
    }
    catch {
        $Script:BladKonsoli = "Zwalnianie konsoli: $($_.Exception.Message)"
    }

    Write-JezykBladKonsoli
}

# Zapisuje opis awarii konsoli - a przy jej braku kasuje stary plik.
function Write-JezykBladKonsoli {
    try {
        if (-not $env:TEMP) { return }
        $sciezka = Join-Path $env:TEMP 'Jezyk-konsola.txt'

        if ($Script:BladKonsoli) {
            Set-Content -LiteralPath $sciezka -Encoding UTF8 -ErrorAction Stop -Value @"
$($Script:BladKonsoli)

Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
        }
        elseif (Test-Path -LiteralPath $sciezka) {
            Remove-Item -LiteralPath $sciezka -Force -ErrorAction Stop
        }
    }
    catch { }
}

# Ukrycie okna TERAZ - najwczesniej jak sie da, zeby ikona zniknela z paska zadan
# w ulamku sekundy. Konsola nadal istnieje; zwolnimy ja po zaladowaniu modulu AD.
Hide-JezykOknoKonsoli

# WinForms i System.Drawing nie sa ladowane automatycznie. Musi to nastapic, zanim padnie
# pierwsze odwolanie do typu z tych bibliotek - czyli zanim zbudujemy $Script:Config.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Wlacza style wizualne systemu. Musi paść PRZED pierwszym oknem - takze przed oknem
# bledu; wywolane pozniej nie zadziala wstecz.
[System.Windows.Forms.Application]::EnableVisualStyles()


# --- KONFIGURACJA --------------------------------------------------------------------
# JEDYNE MIEJSCE, KTORE SIE WYPELNIA. Wartosci siedza w kodzie, a nie w osobnym pliku,
# bo wyznaczaja ADRESY polaczen: domene do parametru -Server, serwer lokacji SCCM i
# kontrolery do sciezki LDAP. W osobnym pliku obok skryptu byly chronione slabiej niz
# kod i nikt ich nie ogladal przy przegladzie.
#
# Zadnego zgadywania: nie ma tu zmiennych srodowiskowych, odczytow rejestru ani wartosci
# zapasowych. Czego nie ma na liscie ponizej, o to Jezyk nie pyta.
# Poprawnosc sprawdza Confirm-JezykUstawienia przy starcie.
$Script:Ustawienia = @{

    # Domeny w liscie rozwijanej. PIERWSZA jest wybrana po starcie; pusta lista = Jezyk
    # nie wystartuje.
    Domeny = @(
        'jezyk.pl'
        'zolw.pl'
        'wydra.pl'
    )

    # Domeny, w ktorych przycisk "Odblokuj konto" ma byc czynny - jedyna operacja ZAPISU
    # w calym narzedziu. Pusta lista = nieczynny wszedzie i to jest wartosc domyslna.
    DomenyZOdblokowaniem = @(
        'zolw.pl'
    )

    # Ogranicza obejscie kontrolerow do wypisanych maszyn. Pusta lista = Jezyk pyta o nie
    # samo AD. Kazda nazwa musi nalezec do jednej z domen wyzej.
    Kontrolery = @()

    # PODDRZEWO, OD KTOREGO ZACZYNA SIE PRZESZUKANIE PO NUMERZE TELEFONU (-SearchBase).
    # PUSTE = od korzenia domeny, czyli tak, jak dziala Jezyk bez tego ustawienia.
    #
    # Po co: telephoneNumber i mobile NIE SA w AD indeksowane, a filtr numeru ma gwiazdke
    # na poczatku wartosci, wiec kontroler przeglada konto po koncie. Wskazanie poddrzewa
    # skraca to przegladanie proporcjonalnie do tego, ile obiektow z niego wypada - i jest
    # JEDYNYM sposobem na skrocenie samego zapytania. (Drugi srodek, czyli przeniesienie go
    # w tlo, zapytania nie skraca - sprawia tylko, ze okno na nie nie czeka.)
    #
    # CENA: konto SPOZA tego poddrzewa przestaje byc znajdowane po numerze i NIKT SIE O TYM
    # NIE DOWIE - ani operator, ani Jezyk. Wpisuj tu wylacznie kontener obejmujacy WSZYSTKIE
    # konta ludzi; przy kontach rozsianych po wielu galeziach zostaw pusto.
    #
    # KLUCZ TO DOMENA, bo nazwa wyrozniajaca konczy sie skladnikami DC tej jednej domeny -
    # jedna wartosc dla wszystkich trzech domen bylaby poprawna najwyzej dla jednej,
    # a w pozostalych wywracalaby wyszukiwanie. Domena bez wpisu = przeszukanie od korzenia.
    # Przyklad: @{ 'jezyk.pl' = 'OU=Ludzie,DC=jezyk,DC=pl' }
    SzukajOd = @{}

    # SccmSerwer to SERWER LOKACJI (rola SMS Provider), nie punkt zarzadzania: przestrzen
    # root\sms\site_XXX mieszka wylacznie na nim. Puste = pole "Ostatnio uzywany komputer"
    # mowi o braku konfiguracji i z niczym sie nie laczy.
    SccmSerwer     = ''
    SccmKodLokacji = ''
    SccmProtokol   = 'Dcom'

    # Gdy polaczenie protokolem wyzej nie dochodzi do skutku (zamkniety port, milczacy
    # serwer), sprobowac TEGO DRUGIEGO: Dcom <-> Wsman. Oba prowadza do tego samego
    # serwera z konfiguracji - zapasowy jest protokol, nie adres. Sensowne, bo prawo
    # wstepu bywa nadane tylko jednej z dwoch drog: rola w ConfigMgr daje zdalna
    # aktywacje DCOM, a wejscie przez WinRM wymaga osobnego czlonkostwa na serwerze.
    # $false = probujemy wylacznie protokolu z SccmProtokol.
    SccmProtokolZapasowy = $true

    # PELNA sciezka do CmRcViewer.exe - zdalnej konsoli z ConfigMgr. Uruchamia ja przycisk
    # "Polacz", ktory pojawia sie nad "Pinguj" wtedy i tylko wtedy, gdy SCCM podal nazwe
    # maszyny, A TA SCIEZKA JEST WYPELNIONA. PUSTE = przycisku nie ma i to jest wartosc
    # domyslna - dokladnie ta sama zasada, co przy pustym SccmSerwer.
    #
    # SCIEZKA MUSI BYC PELNA, od litery dysku albo \\serwera. Sama nazwa pliku bylaby
    # szukana po PATH, czyli na maszynie operatora - a Jezyk niczego tam nie wykrywa
    # (twarda zasada nr 1). Z tego samego powodu nie ma tu wartosci zapasowej: katalog
    # konsoli bywa inny w kazdym wdrozeniu i zgadywanie go konczyloby sie uruchomieniem
    # nie tego programu, co trzeba.
    #
    # Przyklad: 'C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\i386\CmRcViewer.exe'
    SciezkaRemoteControl = ''
}

# Normalizacja obu list: male litery i bez spacji na brzegach. Od tego zalezy porownanie
# w Test-JezykWolnoOdblokowac - bez niej wpis "ZOLW.PL" nie zgadzalby sie z domena wybrana
# w oknie i przycisk odblokowania po cichu przestalby dzialac.
$Script:Domeny = @($Script:Ustawienia.Domeny |
                   ForEach-Object { ([string]$_).Trim().ToLower() } |
                   Where-Object { $_ })

$Script:DomenyZOdblokowaniem = @($Script:Ustawienia.DomenyZOdblokowaniem |
                                 ForEach-Object { ([string]$_).Trim().ToLower() } |
                                 Where-Object { $_ })

# Zadnej wartosci zapasowej: brak listy jest brakiem listy i konczy sie komunikatem.
$Script:DomenaAD = if ($Script:Domeny.Count) { $Script:Domeny[0] } else { '' }

# Klucze na male litery i bez spacji, tak samo jak obie listy domen wyzej - bez tego wpis
# "JEZYK.PL" nie zgadzalby sie z domena wybrana w oknie i poddrzewo po cichu przestaloby
# obowiazywac. Cicha utrata poddrzewa jest lagodniejsza niz cicha jego zamiana, ale nadal
# znaczylaby, ze ustawienie robi co innego, niz mowi.
$Script:SzukajOd = @{}
if ($Script:Ustawienia.SzukajOd -is [hashtable]) {
    foreach ($klucz in $Script:Ustawienia.SzukajOd.Keys) {
        $domena = ([string]$klucz).Trim().ToLower()
        $baza   = ([string]$Script:Ustawienia.SzukajOd[$klucz]).Trim()
        if ($domena -and $baza) { $Script:SzukajOd[$domena] = $baza }
    }
}

# Ustawienia wygladu i stale programu. Etykiety trybow sluza jednoczesnie za pozycje listy
# rozwijanej i za identyfikatory trybu w kodzie - jedno miejsce, zeby nazwy sie nie rozjechaly.
$Script:Config = @{
    Domena        = $Script:DomenaAD
    TytulOkna     = 'Jeżyk - Twój mały pomocnik'

    # Ile trafien pokazujemy przy wyszukiwaniu czesciowym. Powyzej tej liczby okno prosi
    # o doprecyzowanie, zamiast po cichu uciac wynik.
    LimitWynikow  = 50

    # ILE TRAFIEN PO NUMERZE TELEFONU MA JESZCZE SENS. Numer nalezy niemal zawsze do jednej
    # osoby; kilkadziesiat kont z tym samym numerem to numer infolinii albo wspolny numer
    # dzialu i lista takich osob nie odpowiada na zadne pytanie - okno prosi wtedy o inna
    # wartosc, tak samo jak przy niepelnym nazwisku.
    #
    # TA LICZBA IDZIE TEZ NA ROZMIAR STRONY (-ResultPageSize), i to ona konczy prace
    # KONTROLERA, a nie tylko ucina odpowiedz. Filtr numeru ma gwiazdke NA POCZATKU wartosci,
    # wiec nie korzysta z indeksow; przy domyslnej stronie 256 wierszy numer uzywany przez
    # kilkadziesiat osob nigdy jej nie zapelnia i kontroler przegladal cala domene - stad
    # zatrzymania okna. Przy stronie rownej limitowi konczy szukanie po jedenastym trafieniu.
    #
    # Osobne od LimitWynikow, bo tamten dotyczy zapytan po nazwie, ktore indeksy
    # wykorzystuja i moga oddac wiecej bez tego kosztu.
    LimitNumeru   = 10

    TrybNazwa     = 'dane AD użytkownika'
    TrybKomputer  = 'nazwę komputera'

    # --- PALETA ----------------------------------------------------------------------
    # WSZYSTKIE KLUCZE Kolor* PONIZEJ SA ZMIENNE, nie stale: przelaczenie motywu
    # przepisuje je z $Script:MotywJasny albo $Script:MotywCiemny (zaraz pod tym blokiem).
    # Dzieki temu kazde miejsce czytajace $Script:Config.Kolor* dostaje wlasciwy odcien
    # samo z siebie i dolozenie pola nie wymaga drugiej listy do poprawienia.
    #
    # WARTOSCI TUTAJ TO MOTYW JASNY. SystemColors zostaja tam, gdzie byly od poczatku:
    # jasny motyw ma isc za ustawieniami Windows, a nie za liczbami wpisanymi w kodzie.
    KolorOkna     = [System.Drawing.SystemColors]::Control
    KolorTla      = [System.Drawing.SystemColors]::Window
    KolorTekstu   = [System.Drawing.SystemColors]::WindowText

    KolorProblem  = [System.Drawing.Color]::Red
    KolorOk       = [System.Drawing.Color]::Green      # 0,128,0 - czytelny na bialym tle
    KolorNieznany = [System.Drawing.Color]::DimGray

    # Odcien ciemniejszy od domyslnego tla okna (SystemColors.Control to okolo 240,240,240).
    KolorKontrolki = [System.Drawing.Color]::FromArgb(224, 224, 224)
    KolorObramowki = [System.Drawing.Color]::FromArgb(180, 180, 180)

    # Tlo przycisku "!" - jasny czerwony odcien, zeby wykrzyknik nie zlewal sie z reszta
    # szarego interfejsu. Sam wykrzyknik pokazuje sie wylacznie przy realnej usterce,
    # wiec ma sygnalizowac problem tak samo stanowczo jak KolorProblem na werdykcie.
    KolorProblemTlo = [System.Drawing.Color]::FromArgb(255, 232, 232)

    # Drugi, NIEBIESKI wariant przycisku "!" - nie usterka, tylko realna niejednoznacznosc
    # danych (komputer wspoldzielony przez kilku uzytkownikow). Czerwony i zielony sa juz
    # zajete w tym samym wierszu (blad/ok przy dostepnosci maszyny), wiec kolejny stan
    # dostaje wlasny, dotad nieuzywany odcien.
    KolorInfo     = [System.Drawing.Color]::FromArgb(0, 90, 200)
    KolorInfoTlo  = [System.Drawing.Color]::FromArgb(224, 236, 255)

    Autor         = 'XYZ'

    # Numer wersji pokazywany w prawym dolnym rogu okna. PODBIJANY RECZNIE - Jezyk niczego
    # nie wykrywa sam na maszynie operatora, a gita tam nie ma. Nie jest to $Script:Ustawienia:
    # to napis w oknie, nie adres polaczenia, wiec Confirm-JezykUstawienia nie ma go czego
    # sprawdzac. Zaslepka do wpisania przed wdrozeniem, tak samo jak Autor wyzej.
    Wersja        = 'X'

    # OD KTOREGO MOTYWU ZACZYNA OKNO. Podbijane recznie, tak samo jak Wersja i Autor:
    # Jezyk niczego nie wykrywa sam na maszynie operatora, wiec ani nie zaglada do
    # rejestru Windows po ustawienie motywu systemu, ani nie zapisuje wyboru operatora
    # nigdzie poza pamiecia procesu. Klikniecie ksiezyca dziala do zamkniecia okna.
    MotywStartowy = 'Jasny'
}

# --- MOTYWY ---------------------------------------------------------------------------
# DWA KOMPLETY TYCH SAMYCH KLUCZY. Set-JezykMotyw przepisuje jeden z nich do
# $Script:Config, a reszta programu czyta juz tylko $Script:Config.
#
# JASNEGO NIE PRZEPISUJEMY RECZNIE - jest zdjeciem tego, z czym $Script:Config sie rodzi.
# Druga kopia tych samych jedenastu wartosci rozjechalaby sie przy pierwszej zmianie
# odcienia, a rozjazd widac dopiero po powrocie z ciemnego motywu.
$Script:MotywJasny = @{}
foreach ($klucz in @($Script:Config.Keys | Where-Object { $_ -like 'Kolor*' })) {
    $Script:MotywJasny[$klucz] = $Script:Config[$klucz]
}

# Odcienie z palety Fluent, ktora Windows 11 sam naklada na okna w motywie ciemnym:
# tlo okna #202020, tlo kontrolek #2D2D2D, tekst bialy.
#
# KOLORY ZNACZACE MAJA WLASNE ODCIENIE, a nie te same, co w jasnym. Zielen 0,128,0 jest
# dobrana pod biale tlo i na #202020 przestaje byc czytelna - a to ona niesie werdykt
# "konto sprawne". Tak samo DimGray (105,105,105) na ciemnym tle prawie znika.
$Script:MotywCiemny = @{
    KolorOkna       = [System.Drawing.Color]::FromArgb(32, 32, 32)
    KolorTla        = [System.Drawing.Color]::FromArgb(45, 45, 45)
    KolorTekstu     = [System.Drawing.Color]::FromArgb(255, 255, 255)

    KolorProblem    = [System.Drawing.Color]::FromArgb(255, 120, 120)
    KolorOk         = [System.Drawing.Color]::FromArgb(108, 203, 95)
    KolorNieznany   = [System.Drawing.Color]::FromArgb(160, 160, 160)

    KolorKontrolki  = [System.Drawing.Color]::FromArgb(45, 45, 45)
    KolorObramowki  = [System.Drawing.Color]::FromArgb(72, 72, 72)

    KolorProblemTlo = [System.Drawing.Color]::FromArgb(62, 32, 32)
    KolorInfo       = [System.Drawing.Color]::FromArgb(100, 170, 255)
    KolorInfoTlo    = [System.Drawing.Color]::FromArgb(28, 44, 66)
}

# Motyw pokazywany w tej chwili. Zmienia go wylacznie Set-JezykMotyw.
$Script:Motyw = $Script:Config.MotywStartowy

# Rejestr kontrolek GUI: wypelniany w SEKCJI 4, odczytywany w SEKCJI 3.
# To warunek dzialania, nie porzadek. Procedury obslugi zdarzen uruchamiaja sie dlugo po
# tym, jak funkcja budujaca okno sie zakonczyla, a scriptblocki w PowerShellu nie sa
# domknieciami - szukaja zmiennych dopiero przy wywolaniu. Kontrolki musza wiec trafic
# do zmiennej o zasiegu skryptu i tylko stamtad sa odczytywane.
$Script:Kontrolki = @{}

# Role WYGLADU kontrolek: klucz to sama kontrolka, wartosc - nazwa roli ("Okno", "Pole",
# "Przycisk"...). Zaklada je Set-JezykWyglad -Rejestruj przy budowie okna, czyta
# Set-JezykMotyw przy przelaczaniu palety. Tablica, a nie lista na role: rejestracja tej
# samej kontrolki drugi raz ma ZASTAPIC role, a nie dopisac ja obok. Cztery przyciski "!"
# rodza sie czerwone i zaraz potem staja sie niebieskie - w liscie zostalyby w obu.
$Script:KontrolkiMotywu = @{}

# Role kolorow pol: klucz to sama kontrolka, wartosc - CO jej kolor znaczy ("Ok",
# "Problem", "Nieznany", "Tekstu"). Zaklada je Set-JezykKolorPola, czyta Set-JezykMotyw
# przy przelaczaniu palety. Bez tego rejestru przelaczenie motywu musialoby albo zostawic
# na polu odcien z poprzedniej palety, albo pomalowac wszystko neutralnie - czyli zdjac
# czerwien z werdyktu i sklamac o stanie konta.
$Script:RoleKolorow = @{}

# Tresci pod przyciskami "!" - klucz pola, wartosc do pokazania. Trzymane OSOBNO od
# kontrolek, bo przycisk niesie tylko widocznosc; caly tekst siedzi tutaj i przezywa
# kazde przerysowanie okna.
$Script:Informacje = @{}

# Tytuly okien informacyjnych. Jedno miejsce, zeby przycisk i okno mowily o tym samym polu.
# Kazdy klucz tutaj pokazuje sie WYLACZNIE warunkowo - nigdy jako stale, zawsze widoczne
# wyjasnienie. Odpadly kolejno: Domena i Ostatnie logowanie (stale wyjasnienia bez zwiazku
# z awaria) oraz Odblokuj (powody wylaczenia przycisku sa normalnymi stanami, nie bledami).
# Wiekszosc kluczy oznacza realna usterke (czerwony przycisk) - KomputerWspoldzielony jest
# drugi, niebieski rodzaj: nie usterka, tylko realna niejednoznacznosc konkretnego wyniku
# (komputer, z ktorego korzysta wiecej niz jedna osoba wedlug SCCM). Warunkowosc jest tu
# tym, co odroznia go od trzech usunietych - pokazuje sie tylko wtedy, gdy dane wyszukanie
# to faktycznie wykryje, a nie zawsze.
$Script:TytulyInformacji = @{
    Status                = 'Status'
    Komputer              = 'Ostatnio używany komputer'
    Uzytkownik            = 'Ostatnio zalogowany użytkownik'
    KomputerWspoldzielony = 'Komputer współdzielony'
    Tworca                = 'Dodany do AD przez'
    Mac                   = 'Adres MAC'
    # Widok komputera ma wlasne kontrolki, wiec i wlasne klucze - przycisk "!" to JEDNA
    # kontrolka, a dwa panele istnieja naraz (widoczny jest zawsze tylko jeden). Tytuly
    # celowo brzmia tak samo, jak po stronie konta: okno ma nazywac pole, nie panel.
    MacMaszyny            = 'Adres MAC'
    StatusMaszyny         = 'Status'
}

<#
.SYNOPSIS
    Opisuje slowami konfiguracje, ktora jest faktycznie w mocy. Trafia pod przycisk "!"
    przy liscie domen.

.DESCRIPTION
    Narzedzie laczy sie z kontrolerem domeny, serwerem lokacji SCCM i kontrolerami z listy,
    a w wybranych domenach wolno mu ZAPISAC do katalogu. Bez tego opisu zadnego z tych
    faktow nie dalo sie zobaczyc z okna.

    Stoi na koncu pliku celowo: Kod-Jezyk.ps1 po tej funkcji poznaje, ze czesc wczytala sie
    w calosci, bo urwana kopia traci wlasnie koniec.
#>
function Get-JezykOpisKonfiguracji {
    param([string]$DomenaBiezaca = '')

    $wiersze = @()

    if ($DomenaBiezaca) { $wiersze += 'Domena: {0}' -f $DomenaBiezaca }
    $wiersze += 'Dostępne domeny: {0}' -f (@($Script:Domeny) -join ', ')

    $wiersze += if (@($Script:DomenyZOdblokowaniem).Count) {
        'Odblokowanie konta dozwolone w: {0}' -f (@($Script:DomenyZOdblokowaniem) -join ', ')
    } else {
        'Odblokowanie konta: wyłączone we wszystkich domenach'
    }

    $wiersze += if (@($Script:Ustawienia.Kontrolery).Count) {
        'Kontrolery z konfiguracji: {0}' -f (@($Script:Ustawienia.Kontrolery) -join ', ')
    } else {
        'Kontrolery: rozpoznawane z Active Directory'
    }

    $wiersze += if ($Script:SzukajOd.Count) {
        'Przeszukanie po numerze ograniczone do: {0}' -f
            ((@($Script:SzukajOd.Keys | Sort-Object | ForEach-Object { '{0} -> {1}' -f $_, $Script:SzukajOd[$_] })) -join '; ')
    } else {
        'Przeszukanie po numerze: od korzenia domeny'
    }

    $wiersze += if ($Script:Ustawienia.SccmSerwer -and $Script:Ustawienia.SccmKodLokacji) {
        'SCCM: {0}, przestrzeń root\sms\site_{1}, protokół {2}{3}' -f
            $Script:Ustawienia.SccmSerwer, $Script:Ustawienia.SccmKodLokacji,
            $Script:Ustawienia.SccmProtokol,
            $(if ($Script:Ustawienia.SccmProtokolZapasowy) { ' (przy braku połączenia próbuje drugiego protokołu)' } else { '' })
    } else {
        'SCCM: nieskonfigurowany - pole "Ostatnio używany komputer" pozostaje puste'
    }

    $wiersze += if ($Script:Ustawienia.SciezkaRemoteControl) {
        'Zdalna konsola: {0}' -f $Script:Ustawienia.SciezkaRemoteControl
    } else {
        'Zdalna konsola: nieskonfigurowana - przycisk "Połącz" się nie pojawia'
    }

    $wiersze -join [Environment]::NewLine
}

#endregion
