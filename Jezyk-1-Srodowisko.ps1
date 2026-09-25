# Jezyk-1-Srodowisko - konsola, biblioteki interfejsu, konfiguracja, paleta motywu i rejestry.
# Linia 1 musi zostac zwyklym komentarzem - oslania pierwsza instrukcje przed zdublowanym BOM.

# Wlasny trap kazdej czesci - trap wznawia prace w zakresie, w ktorym go zdefiniowano.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 1 - SRODOWISKO I KONFIGURACJA

# --- KONSOLA -------------------------------------------------------------------------
# Konsola znika w dwoch fazach: ukrycie okna tutaj, FreeConsole po zaladowaniu modulu AD -
# obie tylko wtedy, gdy jestesmy na niej jedynym procesem (README: Kod > Jezyk-1-Srodowisko).

# Opis awarii konsoli trafia do %TEMP%\Jezyk-konsola.txt wylacznie przy niepowodzeniu.
$Script:BladKonsoli   = $null
$Script:UchwytKonsoli = [IntPtr]::Zero
$Script:OknoUkryte    = $false
$Script:KonsolaZwolniona = $false

try {
    # Pod try: nieudana kompilacja zostawia widoczna konsole, ale nie zatrzymuje programu.
    # Warunek chroni przed bledem "typ juz istnieje" przy ponownym uruchomieniu w tej sesji.
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

// --- POLACZENIE Z UDZIALEM SIECIOWYM (WNetAddConnection3, ta sama droga co "net use") ---
// Strukture wypelnia metoda ponizej - z PowerShella ida tylko sciezka i flagi.
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
private struct NETRESOURCE
{
    public int dwScope;
    public int dwType;
    public int dwDisplayType;
    public int dwUsage;
    public string lpLocalName;
    public string lpRemoteName;
    public string lpComment;
    public string lpProvider;
}

[DllImport("mpr.dll", CharSet = CharSet.Unicode)]
private static extern int WNetAddConnection3(IntPtr hwndOwner, ref NETRESOURCE lpNetResource,
                                             string lpPassword, string lpUserName, int dwFlags);

public static int PolaczUdzial(IntPtr hwndOwner, string sciezka, int flagi)
{
    NETRESOURCE zasob = new NETRESOURCE();
    zasob.dwType = 1;                        // RESOURCETYPE_DISK
    zasob.lpRemoteName = sciezka;            // lpLocalName zostaje null: polaczenie BEZ litery
    return WNetAddConnection3(hwndOwner, ref zasob, null, null, flagi);
}
'@
    }

    [void][Jezyk.Native]::SetCurrentProcessExplicitAppUserModelID('Skrypt.Jezyk.StatusKontaAD')
}
catch {
    $Script:BladKonsoli = "Przygotowanie funkcji systemowych: $($_.Exception.Message)"
}

# Czy konsola nalezy wylacznie do nas (jeden przypiety proces)? "Nie wiem" = $false.
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

        # 0 = SW_HIDE; styl zmieniamy na oknie juz ukrytym - dziala pewniej.
        [void][Jezyk.Native]::ShowWindow($Script:UchwytKonsoli, 0)

        # GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80 (suma bitowa) - okno bez przycisku na pasku zadan.
        $styl = [Jezyk.Native]::GetWindowLong($Script:UchwytKonsoli, -20)
        [void][Jezyk.Native]::SetWindowLong($Script:UchwytKonsoli, -20, ($styl -bor 0x80))
        [void][Jezyk.Native]::ShowWindow($Script:UchwytKonsoli, 0)

        $Script:OknoUkryte = $true
    }
    catch {
        $Script:BladKonsoli = "Ukrywanie okna konsoli: $($_.Exception.Message)"
    }
}

# Przelacza pasek tytulu okna na ciemny albo jasny (atrybut DWM 20, w starszych kompilacjach 19).
# Niepowodzenie zostawia jasny pasek - kosmetyka, nie zatrzymuje programu.
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

        # Belka jest poza obszarem klienta - bez tego przemaluje sie dopiero po ruchu okna.
        # 0x27 = SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED
        [void][Jezyk.Native]::SetWindowPos($Uchwyt, [IntPtr]::Zero, 0, 0, 0, 0, 0x27)
    }
    catch {
        $Script:BladKonsoli = "Ciemny pasek tytulu: $($_.Exception.Message)"
    }
}

# Przelacza paski przewijania kontrolki na ciemne ("DarkMode_Explorer") albo jasne.
# Powrot to "Explorer", nie pusta nazwa - ta zdejmuje caly wyglad systemowy.
function Set-JezykCiemnyPasekPrzewijania {
    param([IntPtr]$Uchwyt, [switch]$Ciemny)

    if ($Uchwyt -eq [IntPtr]::Zero)      { return }
    if (-not ('Jezyk.Native' -as [type])) { return }

    try {
        $klasa = if ($Ciemny) { 'DarkMode_Explorer' } else { 'Explorer' }
        # [NullString]::Value = "uzyj domyslnych"; pusty napis znaczylby pusta liste identyfikatorow.
        [void][Jezyk.Native]::SetWindowTheme($Uchwyt, $klasa, [NullString]::Value)
    }
    catch {
        $Script:BladKonsoli = "Ciemne paski przewijania: $($_.Exception.Message)"
    }
}

# Styk z systemem: laczy z udzialem (WNetAddConnection3). Kod systemowy albo -1 = brak funkcji natywnych.
# Flagi: 0 - proba cicha (wolno w tle); 0x18 - okno poswiadczen, wylacznie z watku interfejsu.
function Invoke-JezykPolaczenieUdzialu {
    param([string]$Sciezka, [IntPtr]$Uchwyt = [IntPtr]::Zero, [int]$Flagi = 0)

    if (-not ('Jezyk.Native' -as [type])) { return -1 }

    try { return [Jezyk.Native]::PolaczUdzial($Uchwyt, $Sciezka, $Flagi) }
    catch {
        # Wyjatek to awaria tej drogi, nie odpowiedz serwera - oddajemy -1, a nie "odmowa dostepu".
        $Script:BladKonsoli = "Polaczenie z udzialem: $($_.Exception.Message)"
        return -1
    }
}

# Zwalnia konsole - dopiero po zaladowaniu modulu AD (jego pasek postepu pisze do hosta).
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

# Ukrycie okna konsoli jak najwczesniej - ikona znika z paska zadan od razu.
Hide-JezykOknoKonsoli

# WinForms i System.Drawing przed pierwszym uzyciem ich typow, czyli przed zbudowaniem Config.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Style wizualne - przed pierwszym oknem (takze oknem bledu); pozniej nie dzialaja wstecz.
[System.Windows.Forms.Application]::EnableVisualStyles()


# --- KONFIGURACJA --------------------------------------------------------------------
# JEDYNE MIEJSCE DO WYPELNIENIA przy wdrozeniu. Zadnego wykrywania ani wartosci zapasowych;
# poprawnosc sprawdza Confirm-JezykUstawienia przy starcie (README: Konfiguracja).
$Script:Ustawienia = @{

    # Domeny w liscie rozwijanej; pierwsza wybrana po starcie. Pusta lista = Jezyk nie wystartuje.
    Domeny = @(
        'jezyk.pl'
        'zolw.pl'
        'wydra.pl'
    )

    # Domeny z czynnym "Odblokuj konto" (zapis do AD). Pusta lista = nigdzie.
    DomenyZOdblokowaniem = @(
        'zolw.pl'
    )

    # Domeny, w ktorych okno "Grupy AD" dopisuje i usuwa czlonkostwo (zapis do AD). Pusta = nigdzie.
    # Jedna lista na oba kierunki, osobna od DomenyZOdblokowaniem - to dwie niezalezne delegacje.
    DomenyZZarzadzaniemGrupami = @(
        'jezyk.pl'
    )

    # Ogranicza obejscie kontrolerow do wypisanych maszyn. Pusta lista = lista z AD.
    Kontrolery = @()

    # Poddrzewo (-SearchBase) przeszukania po numerze telefonu, per domena. Puste = od korzenia.
    # Uwaga: konto spoza poddrzewa przestaje byc znajdowane po numerze - bez ostrzezenia.
    # Przyklad: @{ 'jezyk.pl' = 'OU=Ludzie,DC=jezyk,DC=pl' }
    SzukajOd = @{}

    # Serwer lokacji SCCM (SMS Provider, nie punkt zarzadzania), kod lokacji i protokol Dcom/Wsman.
    # Pusty serwer = pola SCCM mowia o braku konfiguracji i z niczym sie nie lacza.
    SccmSerwer     = ''
    SccmKodLokacji = ''
    SccmProtokol   = 'Dcom'

    # $true = gdy protokol wyzej nie laczy, probujemy drugiego (Dcom <-> Wsman) do tego samego serwera.
    SccmProtokolZapasowy = $true

    # Domeny znane serwerowi SCCM. Poza nimi okno chowa pola SCCM, adresy IP i MAC oraz przyciski
    # "Pinguj", "Polacz" i "Dyski". Pusta lista = pol SCCM nie ma nigdzie.
    DomenyZSccm = @(
        'jezyk.pl'
    )

    # PELNA sciezka do CmRcViewer.exe dla przycisku "Polacz" (od litery dysku albo \\serwera).
    # Puste = przycisku nie ma. Przyklad:
    # 'C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\i386\CmRcViewer.exe'
    SciezkaRemoteControl = ''
}

# Listy domen znormalizowane (male litery, bez spacji) - porownuje sie je z domena wybrana w oknie.
$Script:Domeny = @($Script:Ustawienia.Domeny |
                   ForEach-Object { ([string]$_).Trim().ToLower() } |
                   Where-Object { $_ })

$Script:DomenyZOdblokowaniem = @($Script:Ustawienia.DomenyZOdblokowaniem |
                                 ForEach-Object { ([string]$_).Trim().ToLower() } |
                                 Where-Object { $_ })

$Script:DomenyZZarzadzaniemGrupami = @($Script:Ustawienia.DomenyZZarzadzaniemGrupami |
                                       ForEach-Object { ([string]$_).Trim().ToLower() } |
                                       Where-Object { $_ })

$Script:DomenyZSccm = @($Script:Ustawienia.DomenyZSccm |
                        ForEach-Object { ([string]$_).Trim().ToLower() } |
                        Where-Object { $_ })

# Zadnej wartosci zapasowej: brak listy jest brakiem listy i konczy sie komunikatem.
$Script:DomenaAD = if ($Script:Domeny.Count) { $Script:Domeny[0] } else { '' }

# Klucze SzukajOd znormalizowane tak samo jak listy domen.
$Script:SzukajOd = @{}
if ($Script:Ustawienia.SzukajOd -is [hashtable]) {
    foreach ($klucz in $Script:Ustawienia.SzukajOd.Keys) {
        $domena = ([string]$klucz).Trim().ToLower()
        $baza   = ([string]$Script:Ustawienia.SzukajOd[$klucz]).Trim()
        if ($domena -and $baza) { $Script:SzukajOd[$domena] = $baza }
    }
}

# Wyglad i stale programu. Etykiety trybow sa zarazem pozycjami listy i identyfikatorami trybu.
$Script:Config = @{
    Domena        = $Script:DomenaAD
    TytulOkna     = 'Jeżyk - Twój mały pomocnik'

    # Ile trafien pokazuje lista wyboru; powyzej okno prosi o doprecyzowanie.
    LimitWynikow  = 50

    # Ile trafien po numerze telefonu ma sens; powyzej okno prosi o inna wartosc.
    # Idzie tez na -ResultPageSize - konczy prace kontrolera (README: Wyszukiwanie po numerze telefonu).
    LimitNumeru   = 10

    # Ile nazw grup oddaje "Sprawdz nazwy"; tez rozmiar strony zapytania (konczy prace kontrolera).
    LimitPodpowiedziGrup = 20

    TrybNazwa     = 'dane AD użytkownika'
    TrybKomputer  = 'nazwę komputera'

    # --- PALETA ----------------------------------------------------------------------
    # Klucze Kolor* to biezaca paleta (przepisuje ja Set-JezykMotyw); wartosci tutaj = motyw jasny.
    KolorOkna     = [System.Drawing.SystemColors]::Control
    KolorTla      = [System.Drawing.SystemColors]::Window
    KolorTekstu   = [System.Drawing.SystemColors]::WindowText

    # Styl ramki pol - zmienia sie z motywem (ramki nie da sie pomalowac, tylko wybrac styl).
    RamkaPola     = [System.Windows.Forms.BorderStyle]::Fixed3D

    # Grubosc tej ramki w px (Fixed3D = 2, FixedSingle = 1) - dla Set-JezykWyrownaniePol.
    WciecieRamkiPola = 2


    KolorProblem  = [System.Drawing.Color]::Red
    # Kolor NAPISU werdyktu "Konto aktywne" (werdykt niesie znaczenie literami, pola - tlem).
    KolorOk       = [System.Drawing.Color]::Green      # 0,128,0 - czytelny na jasnym tle okna
    KolorNieznany = [System.Drawing.Color]::DimGray

    # Tla pol niosacych znaczenie: nasycone, z kontrastem czarnego napisu >= 4,5:1 (README: Ciemny motyw).
    KolorPolaOk      = [System.Drawing.Color]::FromArgb(74, 222, 128)
    KolorPolaProblem = [System.Drawing.Color]::FromArgb(248, 113, 113)

    # Napis wylaczonego przycisku - domalowywany samodzielnie (WinForms nie pozwala go ustawic).
    KolorNieczynny = [System.Drawing.SystemColors]::GrayText

    # Odcien ciemniejszy od domyslnego tla okna (SystemColors.Control to okolo 240,240,240).
    KolorKontrolki = [System.Drawing.Color]::FromArgb(224, 224, 224)
    KolorObramowki = [System.Drawing.Color]::FromArgb(180, 180, 180)

    # Kwadrat ze strzalka listy rozwijanej - domalowywany samodzielnie; w jasnym motywie systemowy.
    KolorPrzyciskuListy = [System.Drawing.SystemColors]::Control

    # Ile pikseli obciac z krawedzi listy rozwijanej (jej bialej ramki nie da sie pomalowac).
    ObciecieListy = 0

    # Tlo czerwonego "!" (usterka).
    KolorProblemTlo = [System.Drawing.Color]::FromArgb(255, 232, 232)

    # Niebieski "!" - nie usterka, tylko niejednoznacznosc danych (komputer wspoldzielony).
    KolorInfo     = [System.Drawing.Color]::FromArgb(0, 90, 200)
    KolorInfoTlo  = [System.Drawing.Color]::FromArgb(224, 236, 255)

    Autor         = 'XYZ'

    # Numer wersji w prawym dolnym rogu okna - podbijany recznie przed wdrozeniem.
    Wersja        = 'X'

    # Motyw na starcie ('Jasny' albo 'Ciemny'); wybor operatora nie jest nigdzie zapisywany.
    MotywStartowy = 'Jasny'
}

# --- MOTYWY ---------------------------------------------------------------------------
# Ciemna paleta wyznacza komplet kluczy motywu; jasna to zdjecie tych kluczy ze startowego Config.
# Odcienie Fluent (tlo #202020, kontrolki #2D2D2D); kolory znaczace maja wlasne odcienie.
$Script:MotywCiemny = @{
    KolorOkna       = [System.Drawing.Color]::FromArgb(32, 32, 32)
    KolorTla        = [System.Drawing.Color]::FromArgb(45, 45, 45)
    KolorTekstu     = [System.Drawing.Color]::FromArgb(255, 255, 255)

    KolorProblem    = [System.Drawing.Color]::FromArgb(255, 120, 120)
    KolorOk         = [System.Drawing.Color]::FromArgb(108, 203, 95)
    KolorNieznany   = [System.Drawing.Color]::FromArgb(160, 160, 160)

    # Tla pol ciemne, bo napis jest bialy (kontrast 5:1 i 6,5:1).
    KolorPolaOk      = [System.Drawing.Color]::FromArgb(21, 128, 61)
    KolorPolaProblem = [System.Drawing.Color]::FromArgb(185, 28, 28)
    KolorNieczynny  = [System.Drawing.Color]::FromArgb(130, 130, 130)

    KolorKontrolki  = [System.Drawing.Color]::FromArgb(45, 45, 45)
    KolorObramowki  = [System.Drawing.Color]::FromArgb(72, 72, 72)

    # Kwadrat ze strzalka jasniejszy od pola - inaczej nie widac, gdzie kliknac.
    KolorPrzyciskuListy = [System.Drawing.Color]::FromArgb(58, 58, 58)
    ObciecieListy       = 1

    # FixedSingle - 1 px z kazdej strony.
    WciecieRamkiPola    = 1

    KolorProblemTlo = [System.Drawing.Color]::FromArgb(62, 32, 32)
    KolorInfo       = [System.Drawing.Color]::FromArgb(100, 170, 255)
    KolorInfoTlo    = [System.Drawing.Color]::FromArgb(28, 44, 66)

    RamkaPola       = [System.Windows.Forms.BorderStyle]::FixedSingle
}

$Script:MotywJasny = @{}
foreach ($klucz in @($Script:MotywCiemny.Keys)) {
    $Script:MotywJasny[$klucz] = $Script:Config[$klucz]
}

# Motyw pokazywany w tej chwili. Zmienia go wylacznie Set-JezykMotyw.
$Script:Motyw = $Script:Config.MotywStartowy

# Wciecie ramki nalozone TERAZ na pola - licznik, bez ktorego przelaczanie motywu sumowaloby poprawke.
$Script:WciecieNalozone = $Script:Config.WciecieRamkiPola

# Rejestr kontrolek (zaklada New-JezykForm, czyta widok) - procedury zdarzen nie sa domknieciami.
$Script:Kontrolki = @{}

# Role wygladu kontrolek (kontrolka -> rola); ponowna rejestracja ZASTEPUJE role.
$Script:KontrolkiMotywu = @{}

# Role kolorow niosacych znaczenie (kontrolka -> "Ok", "Problem"...) - przezywaja zmiane motywu.
$Script:RoleKolorow = @{}

# Tresci pod przyciskami "!" (klucz pola -> tekst), trzymane osobno od kontrolek.
$Script:Informacje = @{}

# Tytuly okien "!" - kazdy klucz pokazuje sie wylacznie warunkowo (README: Przycisk "!").
$Script:TytulyInformacji = @{
    Status                = 'Status'
    Logowanie             = 'Ostatnie logowanie'
    Komputer              = 'Ostatnio używany komputer'
    Uzytkownik            = 'Ostatnio zalogowany użytkownik'
    KomputerWspoldzielony = 'Komputer współdzielony'
    Tworca                = 'Dodany do AD przez'
    Mac                   = 'Adres MAC'
    # Widok komputera ma wlasne klucze (osobne kontrolki); tytuly celowo te same - nazywaja pole.
    MacMaszyny            = 'Adres MAC'
    StatusMaszyny         = 'Status'
}

# Opis konfiguracji w mocy (dzis nic jej nie wola). Funkcja kontrolna - zostaje ostatnia w pliku.
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

    $wiersze += if (@($Script:DomenyZZarzadzaniemGrupami).Count) {
        'Zarządzanie grupami AD dozwolone w: {0}' -f (@($Script:DomenyZZarzadzaniemGrupami) -join ', ')
    } else {
        'Zarządzanie grupami AD: wyłączone we wszystkich domenach'
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

    $wiersze += if (@($Script:DomenyZSccm).Count) {
        'Pola SCCM i adresy maszyny widoczne w: {0}' -f (@($Script:DomenyZSccm) -join ', ')
    } else {
        'Pola SCCM i adresy maszyny: ukryte we wszystkich domenach'
    }

    $wiersze += if ($Script:Ustawienia.SciezkaRemoteControl) {
        'Zdalna konsola: {0}' -f $Script:Ustawienia.SciezkaRemoteControl
    } else {
        'Zdalna konsola: nieskonfigurowana - przycisk "Połącz" się nie pojawia'
    }

    $wiersze -join [Environment]::NewLine
}

#endregion
