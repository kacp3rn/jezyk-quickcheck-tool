# Jezyk - narzedzie do sprawdzania stanu kont w Active Directory.
# TA LINIA MUSI POZOSTAC ZWYKLYM KOMENTARZEM. Kopiowanie pliku dokłada czasem drugi
# znacznik BOM; pierwszy PowerShell zdejmuje, drugi psuje pierwsza instrukcje. Gdy jest
# nia komentarz, uszkodzenie nie ma czego zepsuc. Blok <# #> tej ochrony NIE daje.

<#
.SYNOPSIS
    Plik wejsciowy: dolacza cztery pozostale czesci programu i uruchamia okno.

.DESCRIPTION
    Kolejnosc dolaczania wynika z zaleznosci:
      Jezyk-1-Srodowisko  WinForms i $Script:Config - potrzebne wszystkim pozostalym
      Jezyk-2-Logika      odpytanie AD i SCCM
      Jezyk-3-Widok       wypelnianie kontrolek; wola funkcje logiki
      Jezyk-4-Okno        budowa okna; wola funkcje widoku

    Czesci sa dolaczane KROPKA, nie uruchamiane - dzieki temu ich funkcje i zmienne
    skryptowe zyja we wspolnym zakresie.

    Awaria przed zbudowaniem okna trafia do %TEMP%\Jezyk-blad.txt.
#>

# Bez "#Requires" i bez "param" - obie konstrukcje wymagaja, zeby pierwsza instrukcja
# stala na swoim miejscu, wiec zdublowany znacznik BOM je psuje. Wersji PowerShella
# pilnuje launcher, wskazujac powershell.exe.

# Po zwolnieniu konsoli (nizej) kazda proba pisania do hosta konczy sie bledem 0x6.
# Te dwie preferencje jako jedyne stoja domyslnie na "Continue", czyli tylko one moga
# cos napisac same z siebie - pasek postepu polecen AD wlacznie.
$ProgressPreference = 'SilentlyContinue'
$WarningPreference  = 'SilentlyContinue'

# Siatka bezpieczenstwa na caly plik: konsola jest w trakcie startu ukrywana, wiec bez
# tego awaria nie mialaby gdzie sie pokazac.
#
# "continue", nie "break" - trap ma zapisac slad i oddac sterowanie dalej. Konczenie
# skryptu zamienialoby uszkodzenie jednej linii w awarie calego uruchomienia.
# Zapisujemy tylko PIERWSZY blad; kolejne bywaja jego nastepstwem.
#
# Trap jest samowystarczalny - nie wola zadnej funkcji z tego pliku, bo w chwili, gdy
# blad moze wystapic, zadna nie jest jeszcze zdefiniowana.
$Script:PierwszyBladZapisany = $false
$Script:PierwszyBladTresc    = ''

trap {
    if (-not $Script:PierwszyBladZapisany) {
        $Script:PierwszyBladZapisany = $true

        # Tresc zapamietana takze w pamieci: okno pokazuje potem prawdziwy blad.
        $Script:PierwszyBladTresc = '{0} (linia {1})' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber

        try {
            $opis = @"
Jeżyk nie mógł się uruchomić (awaria przed zbudowaniem okna).

Błąd : $($_.Exception.Message)
Typ  : $($_.Exception.GetType().FullName)
Plik : $($_.InvocationInfo.ScriptName)
Linia: $($_.InvocationInfo.ScriptLineNumber)

Ślad wywołań:
$($_.ScriptStackTrace)
"@
            Set-Content -LiteralPath (Join-Path $env:TEMP 'Jezyk-blad.txt') `
                        -Value $opis -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch { }
    }
    continue
}

# $PSScriptRoot bywa puste, gdy plik nie jest uruchamiany jako pelnoprawny skrypt.
$Script:KatalogSkryptu = $PSScriptRoot
if (-not $Script:KatalogSkryptu -and $MyInvocation.MyCommand.Path) {
    $Script:KatalogSkryptu = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $Script:KatalogSkryptu) { $Script:KatalogSkryptu = (Get-Location).Path }

$Script:CzesciProgramu = 'Jezyk-1-Srodowisko', 'Jezyk-2-Logika', 'Jezyk-3-Widok', 'Jezyk-4-Okno'

# Czesci, ktorych nie znaleziono. Brak pliku nie przerywa petli - zbieramy CALA liste,
# zeby pokazac ja w jednym komunikacie.
$Script:BrakujaceCzesci = @()


<#
.SYNOPSIS
    Zapisuje pierwszy blad, ktory padl w dolaczanej czesci programu.

.DESCRIPTION
    Tresc zapisujemy NAJPIERW, najprostszym wyrazeniem. Ta funkcja jest obsluga bledu
    i nie ma prawa sama sie wywrocic - gdy to zrobi, ginie informacja, po ktora sie do
    niej siega. Nazwa pliku jest dodatkiem pod wlasnym try: dla czesci wczytanej ze
    scriptbloku ScriptName jest pusty, a Split-Path rzuca wtedy wyjatkiem.
#>
function Register-JezykBladCzesci {
    param($Blad)

    if ($Script:PierwszyBladZapisany) { return }
    $Script:PierwszyBladZapisany = $true

    $Script:PierwszyBladTresc = [string]$Blad.Exception.Message

    try {
        $sciezka = [string]$Blad.InvocationInfo.ScriptName
        $plik    = if ($sciezka) { Split-Path -Leaf $sciezka } else { 'część wczytana z pominięciem znaczników' }
        $Script:PierwszyBladTresc = '{0} ({1}, linia {2})' -f
            $Blad.Exception.Message, $plik, $Blad.InvocationInfo.ScriptLineNumber
    }
    catch { }

    try {
        $opis = @"
Jeżyk nie mógł się uruchomić (awaria przy ładowaniu części programu).

Błąd : $($Blad.Exception.Message)
Typ  : $($Blad.Exception.GetType().FullName)
Plik : $($Blad.InvocationInfo.ScriptName)
Linia: $($Blad.InvocationInfo.ScriptLineNumber)

Ślad wywołań:
$($Blad.ScriptStackTrace)
"@
        Set-Content -LiteralPath (Join-Path $env:TEMP 'Jezyk-blad.txt') `
                    -Value $opis -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch { }
}


# Pliki o nietypowej liczbie znacznikow BOM - zero albo dwa i wiecej. Obie skrajnosci
# traktujemy tak samo, bo obie naprawia ta sama sciezka awaryjna przy dolaczaniu.
# Sprawdzamy KOMPLET plikow, nie tylko ten: kazdy kopiuje sie osobno, wiec kazdy jest
# osobna okazja do pomylki.
$Script:PlikiNietypowe = @()

<#
.SYNOPSIS
    Liczy znaczniki BOM na poczatku pliku. Zwraca -1, gdy pliku nie da sie przeczytac.

.DESCRIPTION
    Liczymy, bo bledne sa OBIE skrajnosci i objawiaja sie inaczej:
      0        Windows PowerShell 5.1 czyta plik jako Windows-1250 - polskie znaki
               zamieniaja sie w krzaki, a napis w apostrofach potrafi rozsypac skladnie
      1        stan poprawny
      2 i wiecej  pierwszy znacznik PowerShell zdejmuje, kolejne zostaja jako niewidoczne
               znaki przed pierwsza instrukcja i ja psuja
#>
function Get-JezykLiczbaBom {
    param([string]$Sciezka)

    if (-not $Sciezka -or -not (Test-Path -LiteralPath $Sciezka)) { return -1 }
    try {
        $bajty = [System.IO.File]::ReadAllBytes($Sciezka)
        $ile = 0
        $od  = 0
        while ($bajty.Length -ge $od + 3 -and
               $bajty[$od] -eq 0xEF -and $bajty[$od + 1] -eq 0xBB -and $bajty[$od + 2] -eq 0xBF) {
            $ile++
            $od += 3
        }
        return $ile
    }
    catch { return -1 }
}

<#
.SYNOPSIS
    Zwraca tresc pliku z pominieciem wszystkich znacznikow BOM, dekodujac ja jako UTF-8.

.DESCRIPTION
    Dekodowanie JAWNE ratuje polskie znaki w pliku bez znacznika; petla zamiast jednego
    odjecia trzech bajtow, bo znacznikow bywa wiecej niz dwa. Plik na dysku zostaje
    nietkniety.
#>
function Get-JezykTrescBezBom {
    param([string]$Sciezka)

    $bajty = [System.IO.File]::ReadAllBytes($Sciezka)
    $od = 0
    while ($bajty.Length -ge $od + 3 -and
           $bajty[$od] -eq 0xEF -and $bajty[$od + 1] -eq 0xBB -and $bajty[$od + 2] -eq 0xBF) {
        $od += 3
    }
    [System.Text.Encoding]::UTF8.GetString($bajty, $od, $bajty.Length - $od)
}

# Skan calego kompletu. Wynik sluzy WYLACZNIE do wyboru drogi dolaczania nizej - stan
# znacznika nie jest nigdzie pokazywany, bo program radzi sobie z kazdym i nie ma o czym
# informowac. Liczbe znacznikow w kopii sprawdza sie skryptem z README.
try {
    $doSprawdzenia = @($PSCommandPath)
    foreach ($czesc in $Script:CzesciProgramu) {
        $doSprawdzenia += (Join-Path $Script:KatalogSkryptu ($czesc + '.ps1'))
    }

    foreach ($plik in $doSprawdzenia) {
        $ile = Get-JezykLiczbaBom $plik
        if ($ile -eq 0 -or $ile -ge 2) { $Script:PlikiNietypowe += (Split-Path -Leaf $plik) }
    }
}
catch { }


# Dolaczenie czesci. KAZDA WE WLASNYM try/catch: bez tego blad skladni w jednej konczyl
# ladowanie calej reszty, bo trap wznawia prace w swoim zakresie, czyli ZA petla.
foreach ($czesc in $Script:CzesciProgramu) {
    $nazwaPliku    = $czesc + '.ps1'
    $sciezkaCzesci = Join-Path $Script:KatalogSkryptu $nazwaPliku

    if (-not (Test-Path -LiteralPath $sciezkaCzesci)) {
        $Script:BrakujaceCzesci += $nazwaPliku
        continue
    }

    if ($Script:PlikiNietypowe -contains $nazwaPliku) {
        # Sciezka awaryjna dla kopii o zlym znaczniku - w obie strony. Czytamy bajty sami
        # i dekodujemy jawnie jako UTF-8, zamiast pozwolic PowerShellowi zgadywac.
        # Cena: bledy z takiej czesci nie niosa nazwy pliku, bo PowerShell zna ja tylko
        # dla kodu wczytanego z dysku. Dlatego to droga wylacznie dla plikow juz
        # rozpoznanych jako nietypowe.
        try   { . ([scriptblock]::Create((Get-JezykTrescBezBom $sciezkaCzesci))) }
        catch { Register-JezykBladCzesci $_ }
        continue
    }

    try   { . $sciezkaCzesci }
    catch { Register-JezykBladCzesci $_ }
}

# Sam fakt, ze plik istnieje, niczego nie dowodzi: pusty plik dolacza sie bez bledu,
# a urwana kopia jest przechwytywana przez trap, ktory wznawia prace. Sprawdzamy wiec,
# czy kazda czesc naprawde dostarczyla swoje funkcje - kontrolna wybrana z KONCA kazdego
# pliku, bo urwana kopia traci wlasnie koniec.
$Script:CzesciNiekompletne = @()
foreach ($para in @(
        @{ Czesc = 'Jezyk-1-Srodowisko'; Funkcja = 'Get-JezykOpisKonfiguracji' },
        @{ Czesc = 'Jezyk-2-Logika';     Funkcja = 'Get-JezykComputerStatus' },
        @{ Czesc = 'Jezyk-3-Widok';      Funkcja = 'Update-JezykKomputerWTle' },
        @{ Czesc = 'Jezyk-4-Okno';       Funkcja = 'New-JezykForm' })) {

    if (($Script:BrakujaceCzesci -notcontains ($para.Czesc + '.ps1')) -and
        -not (Get-Command $para.Funkcja -ErrorAction SilentlyContinue)) {
        $Script:CzesciNiekompletne += ($para.Czesc + '.ps1')
    }
}


#region START

<#
.SYNOPSIS
    Pokazuje szczegoly bledu, ktory uniemozliwil start, i zapisuje je do pliku.

.DESCRIPTION
    Dwie drogi celowo: okno dociera od razu, a plik zostaje wtedy, gdy okna pokazac sie
    nie da - na przyklad przy awarii ladowania WinForms. Plik trafia do katalogu
    tymczasowego, bo katalog skryptu bywa udostepniony tylko do odczytu.
#>
function Show-JezykBladStartu {
    param($Blad)

    $linia = ''
    if ($Blad.InvocationInfo) {
        $linia = "`nPlik  : {0}`nLinia : {1}" -f $Blad.InvocationInfo.ScriptName, $Blad.InvocationInfo.ScriptLineNumber
    }

    $opis = @"
Jeżyk nie mógł się uruchomić.

Błąd : $($Blad.Exception.Message)
Typ  : $($Blad.Exception.GetType().FullName)$linia

Ślad wywołań:
$($Blad.ScriptStackTrace)
"@

    # Zapis PRZED proba pokazania okna - gdyby okno zawiodlo, slad juz jest.
    try {
        $plikLogu = Join-Path $env:TEMP 'Jezyk-blad.txt'
        Set-Content -LiteralPath $plikLogu -Value $opis -Encoding UTF8 -ErrorAction Stop
        $opis += "`n`nTen opis zapisano też w pliku:`n$plikLogu"
    }
    catch { }

    try {
        [void][System.Windows.Forms.MessageBox]::Show(
            $opis, 'Jeżyk - błąd uruchomienia',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    catch {
        # Write-Error pod wlasnym try: po zwolnieniu konsoli pisanie do hosta rzuca bledem,
        # a droga "wszystko inne zawiodlo" nie moze wybuchac sama z siebie.
        try { Write-Error $opis } catch { }
    }
}

<#
.SYNOPSIS
    Kasuje slad po poprzedniej awarii - wywolywane, gdy start sie powiodl.

.DESCRIPTION
    Obecnosc pliku ma byc informacja, wiec po udanym starcie nie ma go byc. Kasujemy
    wylacznie wtedy, gdy przy tym uruchomieniu nic nie padlo - inaczej plik zostaje,
    bo to jedyna kopia opisu.
#>
function Remove-JezykSladBledu {
    try {
        if ($Script:PierwszyBladZapisany -or -not $env:TEMP) { return }
        $sciezka = Join-Path $env:TEMP 'Jezyk-blad.txt'
        if (Test-Path -LiteralPath $sciezka) {
            Remove-Item -LiteralPath $sciezka -Force -ErrorAction Stop
        }
    }
    catch { }
}

try {
    # Komplet plikow sprawdzamy PRZED wszystkim innym: bez ktorejs czesci nie ma ani
    # funkcji sprawdzajacych, ani okna, a kazdy pozniejszy komunikat mowilby o nieznanym
    # poleceniu zamiast o brakujacym pliku. MessageBox pod try, bo WinForms laduje czesc
    # pierwsza - gdy to ona jest brakujaca, zostaje sam plik w katalogu tymczasowym.
    if ($Script:BrakujaceCzesci.Count -gt 0 -or $Script:CzesciNiekompletne.Count -gt 0) {
        $powody = @()
        if ($Script:BrakujaceCzesci.Count -gt 0) {
            $powody += 'Brakuje plików programu: {0}' -f ($Script:BrakujaceCzesci -join ', ')
        }
        if ($Script:CzesciNiekompletne.Count -gt 0) {
            $powody += 'Pliki wczytane, ale niekompletne: {0}' -f ($Script:CzesciNiekompletne -join ', ')
        }
        if ($Script:PierwszyBladTresc) { $powody += '', $Script:PierwszyBladTresc }

        $braki = $powody -join [Environment]::NewLine
        try {
            Set-Content -LiteralPath (Join-Path $env:TEMP 'Jezyk-blad.txt') `
                        -Value $braki -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch { }
        try {
            Invoke-JezykZwolnienieKonsoli
            [void][System.Windows.Forms.MessageBox]::Show(
                $braki, 'Jeżyk',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        catch { }
        exit 1
    }

    # Konfiguracja wyznacza ADRESY polaczen - domene do parametru -Server, serwer lokacji
    # SCCM i kontrolery do sciezki LDAP. Wartosc o zlym ksztalcie albo wskazujaca poza
    # skonfigurowane domeny ma zatrzymac start, a nie skierowac uwierzytelnione polaczenie
    # operatora gdzie indziej. Sprawdzenie stoi tutaj, bo funkcje sprawdzajace mieszkaja
    # w czesci drugiej. @() wokol wywolania: jedno zastrzezenie wrocitoby jako napis.
    $bledyUstawien = @(Confirm-JezykUstawienia)
    if ($bledyUstawien.Count -gt 0) {
        Invoke-JezykZwolnienieKonsoli
        $naglowek = 'Błędna konfiguracja w pliku Jezyk-1-Srodowisko.ps1:'
        $tresc    = (@($naglowek, '') + $bledyUstawien) -join [Environment]::NewLine
        [void][System.Windows.Forms.MessageBox]::Show(
            $tresc,
            $Script:Config.TytulOkna,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        exit 1
    }

    # Modul AD sprawdzamy, ale go NIE instalujemy. Obecnosc i ladowanie to dwa osobne
    # pytania i dwie rozne sytuacje po stronie uzytkownika: wczesniej jeden catch zamienial
    # dowolny wyjatek w "nie ma RSAT" i uzytkownik z dzialajacym RSAT dostawal komunikat,
    # ze go nie ma.
    $modulAD = Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue

    if (-not $modulAD) {
        Invoke-JezykZwolnienieKonsoli
        [void][System.Windows.Forms.MessageBox]::Show(
            'Na tym komputerze nie ma modułu ActiveDirectory (RSAT). Bez niego Jeżyk nie ma jak odpytać domeny.',
            $Script:Config.TytulOkna,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }

    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        Invoke-JezykZwolnienieKonsoli
        $komunikat = @"
Moduł ActiveDirectory (RSAT) jest na tym komputerze zainstalowany, ale nie udało się
go załadować.

To NIE jest brak RSAT - modułu nie trzeba doinstalowywać. Problem leży w samym
ładowaniu i szczegóły poniżej powinny wystarczyć osobom odpowiedzialnym za stację.

Szczegóły techniczne: $($_.Exception.Message)
"@
        [void][System.Windows.Forms.MessageBox]::Show(
            $komunikat,
            $Script:Config.TytulOkna,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }

    # DOPIERO TERAZ znika konsola. Modul jest juz zaladowany, wiec nie ma komu pisac do
    # hosta, ktorego zaraz zabraknie. Kolejnosc tych dwoch krokow jest czescia dzialania.
    Invoke-JezykZwolnienieKonsoli

    $form = New-JezykForm

    # Stan poczatkowy idzie ta sama droga co kazdy pozniejszy wynik, wiec startowy wyglad
    # nie moze rozjechac sie z tym, co robi renderer.
    Set-JezykWidok
    $powitanie = 'Wybierz tryb, wpisz szukaną wartość i kliknij "Szukaj".'

    # O stanie znacznika BOM NIE INFORMUJEMY. Program radzi sobie z kazdym - zero, jeden
    # albo wiecej - wiec komunikat opisywalby stan, ktory nie ma zadnego skutku, i tylko
    # wypieralby powitanie z pola Status. Liczbe znacznikow sprawdza sie skryptem z README.
    #
    # Zostaje wylacznie zgloszenie bledu, ktory NAPRAWDE padl przy ladowaniu: sprawne
    # uruchomienie nie zapisuje zadnego, wiec kazdy zapis tutaj znaczy uszkodzona kopie.
    if ($Script:PierwszyBladZapisany) {
        $powitanie = 'Błąd przy ładowaniu programu: {0}' -f $Script:PierwszyBladTresc
    }

    Set-JezykResult -Result (New-JezykResult -Login '' -Status 'Empty' -Message $powitanie)

    # Okno stoi, nic nie padlo - stary opis awarii jest juz tylko mylaca pamiatka.
    Remove-JezykSladBledu

    # ShowDialog zatrzymuje skrypt do czasu zamkniecia okna; od tej chwili wszystko dzieje
    # sie w procedurach obslugi zdarzen.
    [void]$form.ShowDialog()

    $form.Dispose()
}
catch {
    Show-JezykBladStartu -Blad $_
    exit 1
}

#endregion
