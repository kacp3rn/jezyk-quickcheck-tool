# Jezyk - plik wejsciowy: dolacza cztery czesci programu i uruchamia okno (README: Kod > Kod-Jezyk.ps1).
# Zabraniam modyfikacji i dalszego rozwoju skryptu bez:
# - Wcześniejszego pozwolenia na modyfikację kodu przez osobę trzecią.
# - Uwzględnienia mnie (X) jako głównego autora skryptu.

# Uwaga: bez "#Requires" i "param" - obie wymagaja nietknietej pierwszej instrukcji.

# Po zwolnieniu konsoli pisanie do hosta konczy sie bledem - Warning i Progress wyciszone tutaj,
# bledy (tez domyslnie "Continue") zbiera blok okna na dole pliku.
$ProgressPreference = 'SilentlyContinue'
$WarningPreference  = 'SilentlyContinue'

# Siatka bezpieczenstwa na caly plik: zapisuje PIERWSZY blad i wznawia prace ("continue").
# Nie wola zadnej funkcji - w chwili bledu zadna nie musi jeszcze istniec.
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

# Brakujace czesci - cala lista trafia do jednego komunikatu.
$Script:BrakujaceCzesci = @()


# Zapisuje pierwszy blad dolaczanej czesci: tresc najpierw, nazwa pliku pod wlasnym try.
function Register-JezykBladCzesci {
    param($Blad)

    if ($Script:PierwszyBladZapisany) { return }
    $Script:PierwszyBladZapisany = $true

    $Script:PierwszyBladTresc = [string]$Blad.Exception.Message

    try {
        $sciezka = [string]$Blad.InvocationInfo.ScriptName
        $plik    = if ($sciezka) { Split-Path -Leaf $sciezka } else { 'nieznany plik' }
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


# Tresc pliku bez wszystkich znacznikow BOM, dekodowana jawnie jako UTF-8.
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

# Blok skryptu czesci podpisany sama nazwa pliku - kod zyje w pamieci, bez powiazania z katalogiem wdrozenia.
# Uwaga: blok z pelna sciezka pyta o plik przy kazdej pierwszej kompilacji (README: Pulapki).
function Get-JezykBlokCzesci {
    param([string]$Sciezka, [string]$Nazwa)

    $tokeny = $null
    $bledy  = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        (Get-JezykTrescBezBom $Sciezka), $Nazwa, [ref]$tokeny, [ref]$bledy)

    # Blad skladni odrzuca cala czesc - tak samo jak przy dolaczaniu pliku z dysku.
    if ($bledy.Count -gt 0) { throw [System.Management.Automation.ParseException]::new($bledy) }
    $ast.GetScriptBlock()
}


# Dolaczenie czesci - kazda we wlasnym try/catch, bo trap wznowilby prace dopiero za petla.
# Kropka stoi tutaj, na poziomie skryptu: postawiona w funkcji zamknelaby czesc w jej zakresie.
foreach ($czesc in $Script:CzesciProgramu) {
    $nazwaPliku    = $czesc + '.ps1'
    $sciezkaCzesci = Join-Path $Script:KatalogSkryptu $nazwaPliku

    if (-not (Test-Path -LiteralPath $sciezkaCzesci)) {
        $Script:BrakujaceCzesci += $nazwaPliku
        continue
    }

    try   { . (Get-JezykBlokCzesci $sciezkaCzesci $nazwaPliku) }
    catch { Register-JezykBladCzesci $_ }
}

# Kontrola kompletnosci: funkcja z KONCA kazdej czesci, bo urwana kopia traci wlasnie koniec.
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

# Pokazuje blad startu w oknie i zapisuje go do %TEMP%\Jezyk-blad.txt.
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
        # Po zwolnieniu konsoli Write-Error tez rzuca - wlasny try.
        try { Write-Error $opis } catch { }
    }
}

# Kasuje %TEMP%\Jezyk-blad.txt po udanym starcie - chyba ze przy tym uruchomieniu cos padlo.
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
    # Najpierw komplet plikow; MessageBox pod try, bo WinForms laduje dopiero czesc 1.
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

    # Bledna konfiguracja zatrzymuje start. @() - pojedyncze zastrzezenie wrociloby jako napis.
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

    # Modul AD: sprawdzamy, nie instalujemy; brak i nieudane ladowanie to dwa rozne komunikaty.
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

    # Konsola znika dopiero teraz - pasek postepu modulu AD mial jeszcze gdzie pisac.
    Invoke-JezykZwolnienieKonsoli

    # Uwaga: bez konsoli rzuca KAZDY zapis do hosta, takze blad nieterminujacy procedury zdarzenia -
    # wszystkie strumienie okna ida do Add-JezykBladOkna (README: Pulapki).
    & {
        $form = New-JezykForm

        # Stan poczatkowy idzie ta sama droga co kazdy wynik.
        Set-JezykWidok
        $powitanie = 'Wybierz tryb, wpisz szukaną wartość i kliknij "Szukaj".'

        # Stanu BOM nie zglaszamy - powitanie zastepuje wylacznie blad, ktory naprawde padl.
        if ($Script:PierwszyBladZapisany) {
            $powitanie = 'Błąd przy ładowaniu programu: {0}' -f $Script:PierwszyBladTresc
        }

        Set-JezykResult -Result (New-JezykResult -Login '' -Status 'Empty' -Message $powitanie)

        # Okno stoi, nic nie padlo - stary opis awarii jest juz tylko mylaca pamiatka.
        Remove-JezykSladBledu

        # ShowDialog wstrzymuje skrypt do zamkniecia okna; dalej dzialaja procedury zdarzen.
        [void]$form.ShowDialog()

        $form.Dispose()
    } *>&1 | Add-JezykBladOknaZPotoku
}
catch {
    Show-JezykBladStartu -Blad $_
    exit 1
}

#endregion
