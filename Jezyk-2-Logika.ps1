# Jezyk-2-Logika - odpytanie AD i SCCM, sprawdzanie wartosci, zapis do AD. Zero kodu interfejsu.
# Zabraniam modyfikacji i dalszego rozwoju skryptu bez:
# - Wcześniejszego pozwolenia na modyfikację kodu przez osobę trzecią.
# - Uwzględnienia mnie (X) jako głównego autora skryptu.

# Wlasny trap kazdej czesci - trap wznawia prace w zakresie, w ktorym go zdefiniowano.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 2 - LOGIKA

# --- SPRAWDZANIE WARTOSCI, KTORE STAJA SIE TOZSAMOSCIA ALBO ADRESEM -------------------
# Biale listy znakow tam, gdzie tekst staje sie nazwa konta, serwera albo sciezka LDAP.

# Nazwa konta albo komputera: bez znakow skladniowych LDAP i WQL, bez myslnika na poczatku.
function Test-JezykNazwaKonta {
    param([string]$Nazwa)

    if ([string]::IsNullOrWhiteSpace($Nazwa)) { return $false }
    # 256 - duzo powyzej limitu AD; odcina absurdalnie dlugi tekst.
    if ($Nazwa.Length -gt 256) { return $false }
    return ($Nazwa -match '^[A-Za-z0-9_][A-Za-z0-9._$-]*$')
}

# Nazwa hosta albo domeny (etykiety DNS) - trafia do -Server i do sciezki LDAP.
function Test-JezykNazwaHosta {
    param([string]$Nazwa)

    if ([string]::IsNullOrWhiteSpace($Nazwa)) { return $false }
    if ($Nazwa.Length -gt 253) { return $false }
    return ($Nazwa -match '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$')
}

# Czy tekst wyglada jak DN (bez znakow sterujacych) - bez pelnej skladni RFC 4514.
function Test-JezykDn {
    param([string]$Dn)

    if ([string]::IsNullOrWhiteSpace($Dn)) { return $false }
    if ($Dn.Length -gt 2048) { return $false }
    if ($Dn -match '[\x00-\x1F]') { return $false }
    return ($Dn -match '^[A-Za-z]+=..*' -and $Dn -match '(?i)DC=')
}

# Czy sciezka dla "Polacz" to pelna sciezka windowsowa do .exe.
# Wlasny wzorzec, nie IsPathRooted - README: Kod > Jezyk-2-Logika.
function Test-JezykSciezkaProgramu {
    param([string]$Sciezka)

    if ([string]::IsNullOrWhiteSpace($Sciezka)) { return $false }
    if ($Sciezka.Length -gt 260) { return $false }
    # Cudzyslow ma znaczenie w wierszu polecen procesu.
    if ($Sciezka -match '["\x00-\x1F]') { return $false }
    if (-not $Sciezka.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) { return $false }

    # Litera dysku albo UNC.
    return ($Sciezka -match '^(?:[A-Za-z]:\\|\\\\[^\\])')
}

# Poddrzewo przeszukania po numerze dla wybranej domeny (liczone przy kazdym wywolaniu) albo puste.
function Get-JezykSzukajOd {
    param([string]$Domena)

    $klucz = ([string]$Domena).Trim().ToLower()
    if (-not $klucz) { return '' }
    if ($Script:SzukajOd -isnot [hashtable]) { return '' }
    if ($Script:SzukajOd.ContainsKey($klucz)) { return [string]$Script:SzukajOd[$klucz] }
    return ''
}

# Czy nazwa hosta nalezy do ktorejs z domen - sprawdzenie pochodzenia, czysto tekstowe.
function Test-JezykNazwaWDomenach {
    param([string]$Nazwa, [string[]]$Domeny)

    if (-not (Test-JezykNazwaHosta $Nazwa)) { return $false }

    $mala = $Nazwa.Trim().ToLower()
    foreach ($domena in @($Domeny)) {
        if (-not $domena) { continue }
        $d = ([string]$domena).Trim().ToLower()
        if (-not $d) { continue }
        # Uwaga: kropka przed sufiksem i porownanie Ordinal (README: Konfiguracja > Sprawdzenie przy starcie).
        if ($mala -eq $d -or $mala.EndsWith('.' + $d, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

# Zostawia z tekstu same cyfry - podstawa porownywania numerow telefonu.
# Klasa [^0-9], nie \D - \d w .NET obejmuje tez cyfry spoza alfabetu lacinskiego.
function Get-JezykCyfry {
    param([string]$Tekst)

    if ($null -eq $Tekst) { return '' }
    return ($Tekst -replace '[^0-9]', '')
}

# Czy wpis to numer telefonu (6-15 cyfr, znaki rozdzielajace) - waska, bo wlacza drogie zapytanie.
function Test-JezykWygladaNaTelefon {
    param([string]$Tekst)

    if ($null -eq $Tekst) { return $false }
    # Jedna pisownia - $tekst i $Tekst to dla PowerShella ta sama zmienna.
    $Tekst = $Tekst.Trim()
    if (-not $Tekst) { return $false }

    if ($Tekst -notmatch '^[0-9+()\s./-]+$') { return $false }

    $cyfry = Get-JezykCyfry $Tekst
    return ($cyfry.Length -ge 6 -and $cyfry.Length -le 15)
}

# Czy dwa numery to ten sam telefon: zgodne koncowe cyfry (dlugosc krotszego, min. 6).
# Swiadoma cena: dluzszy numer o tej samej koncowce tez przejdzie (README: Rdzen numeru).
function Test-JezykNumerPasuje {
    param([string]$Szukane, [string]$Numer)

    $a = Get-JezykCyfry $Szukane
    $b = Get-JezykCyfry $Numer
    if (-not $a -or -not $b) { return $false }

    $dlugosc = [math]::Min($a.Length, $b.Length)
    if ($dlugosc -lt 6) { return $false }

    return ($a.Substring($a.Length - $dlugosc) -eq $b.Substring($b.Length - $dlugosc))
}

# Sprawdza ustawienia z czesci 1; oddaje liste wszystkich zastrzezen (pusta = dobrze).
function Confirm-JezykUstawienia {

    $bledy = @()
    $domeny = @($Script:Domeny)

    if ($domeny.Count -eq 0) {
        return @('Lista Domeny jest pusta - Jeżyk nie ma czego odpytać.')
    }

    foreach ($domena in $domeny) {
        if (-not (Test-JezykNazwaHosta $domena)) {
            $bledy += 'Domeny: "{0}" nie jest poprawną nazwą domeny.' -f $domena
        }
    }

    # Lista zapisu spoza Domeny - ktos zamierzal wlaczyc zapis gdzie indziej, niz sadzi.
    foreach ($domena in @($Script:DomenyZOdblokowaniem)) {
        if ($domeny -notcontains $domena) {
            $bledy += 'DomenyZOdblokowaniem: "{0}" nie ma na liście Domeny - odblokowanie nie zadziała.' -f $domena
        }
    }

    foreach ($domena in @($Script:DomenyZZarzadzaniemGrupami)) {
        if ($domeny -notcontains $domena) {
            $bledy += 'DomenyZZarzadzaniemGrupami: "{0}" nie ma na liście Domeny - zarządzanie grupami nie zadziała.' -f $domena
        }
    }

    foreach ($domena in @($Script:DomenyZSccm)) {
        if ($domeny -notcontains $domena) {
            $bledy += 'DomenyZSccm: "{0}" nie ma na liście Domeny - pola SCCM nie pojawią się w niej nigdy.' -f $domena
        }
    }

    foreach ($kontroler in @($Script:Ustawienia.Kontrolery)) {
        if (-not $kontroler) { continue }
        if (-not (Test-JezykNazwaWDomenach $kontroler $domeny)) {
            $bledy += 'Kontrolery: "{0}" nie należy do żadnej z domen z listy Domeny.' -f $kontroler
        }
    }

    # Poddrzewo opcjonalne; bledny DN wywracalby kazde zapytanie o numer.
    if ($Script:Ustawienia.SzukajOd -isnot [hashtable]) {
        $bledy += 'SzukajOd: ma być tablicą skrótów (@{}), a nie listą ani napisem.'
    }
    else {
        foreach ($klucz in $Script:Ustawienia.SzukajOd.Keys) {
            $domena = ([string]$klucz).Trim().ToLower()
            $baza   = ([string]$Script:Ustawienia.SzukajOd[$klucz]).Trim()

            if ($domeny -notcontains $domena) {
                $bledy += 'SzukajOd: "{0}" nie ma na liście Domeny - to poddrzewo nigdy nie zostanie użyte.' -f $klucz
            }
            if ($baza -and -not (Test-JezykDn $baza)) {
                $bledy += 'SzukajOd["{0}"]: "{1}" nie jest poprawną nazwą wyróżniającą (DN).' -f $klucz, $baza
            }
        }
    }

    # SCCM jest opcjonalny: pusty serwer to poprawny stan "pole zostaje puste".
    $serwerSccm = [string]$Script:Ustawienia.SccmSerwer
    if ($serwerSccm) {
        if (-not (Test-JezykNazwaWDomenach $serwerSccm $domeny)) {
            $bledy += 'SccmSerwer: "{0}" nie należy do żadnej z domen z listy Domeny.' -f $serwerSccm
        }
        if ([string]$Script:Ustawienia.SccmKodLokacji -notmatch '^[A-Za-z0-9]{3}$') {
            $bledy += 'SccmKodLokacji: "{0}" nie jest trzyznakowym kodem lokacji (np. P01).' -f $Script:Ustawienia.SccmKodLokacji
        }
        if ([string]$Script:Ustawienia.SccmProtokol -notin 'Dcom', 'Wsman') {
            $bledy += 'SccmProtokol: "{0}" - dozwolone wartości to Dcom albo Wsman.' -f $Script:Ustawienia.SccmProtokol
        }
        # Wartosc nielogiczna dzialalaby po cichu jak $true.
        if ($Script:Ustawienia.SccmProtokolZapasowy -isnot [bool]) {
            $bledy += 'SccmProtokolZapasowy: ma być $true albo $false.'
        }
    }

    # Zdalna konsola opcjonalna; bledna sciezka dawalaby przycisk, ktory zawsze zawodzi.
    $sciezkaRc = ([string]$Script:Ustawienia.SciezkaRemoteControl).Trim()
    if ($sciezkaRc -and -not (Test-JezykSciezkaProgramu $sciezkaRc)) {
        $bledy += 'SciezkaRemoteControl: "{0}" nie jest pełną ścieżką do pliku .exe (wymagana litera dysku albo \\serwer).' -f $sciezkaRc
    }

    return @($bledy)
}

# Rozbiera wyjatek: pierwsza linia do pola Status, pelna tresc z typem pod "!".
function Get-JezykOpisBledu {
    param($Wyjatek, [string]$Czynnosc = 'Operacja')

    $tresc = if ($Wyjatek -and $Wyjatek.Exception) { [string]$Wyjatek.Exception.Message } else { [string]$Wyjatek }
    $typ   = if ($Wyjatek -and $Wyjatek.Exception) { $Wyjatek.Exception.GetType().FullName } else { '' }

    $tresc = ([string]$tresc).Trim()
    if (-not $tresc) { $tresc = 'brak treści błędu' }

    $pierwsza = $tresc -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1
    if (-not $pierwsza) { $pierwsza = $tresc }

    $szczegoly = if ($typ) { '{0}{1}{1}{2}' -f $tresc, [Environment]::NewLine, $typ } else { $tresc }

    [pscustomobject]@{ Krotki = ('{0}: {1}' -f $Czynnosc, $pierwsza.Trim()); Szczegoly = $szczegoly }
}

# Katalog z CanonicalName ("jezyk.pl/Uzytkownicy/Dzial IT/Jan Kowalski" bez ostatniego czlonu).
function Get-JezykKatalogZeSciezki {
    param([string]$Kanoniczna)

    if ([string]::IsNullOrWhiteSpace($Kanoniczna)) { return '' }
    $ostatniUkosnik = $Kanoniczna.LastIndexOf('/')
    if ($ostatniUkosnik -le 0) { return '' }
    return $Kanoniczna.Substring(0, $ostatniUkosnik)
}

# Polska odmiana po liczbie: 1 konto, 2 konta, 5 kont (nastki 12-14 jak 5).
function Get-JezykOdmiana {
    param([int]$Ile, [string]$Jeden, [string]$Kilka, [string]$Wiele)

    if ($Ile -eq 1) { return $Jeden }

    $ostatnia = $Ile % 10
    $dwieOstatnie = $Ile % 100
    if ($ostatnia -ge 2 -and $ostatnia -le 4 -and ($dwieOstatnie -lt 12 -or $dwieOstatnie -gt 14)) {
        return $Kilka
    }
    return $Wiele
}

# Imie i nazwisko do pokazania: DisplayName, a gdy puste - imie i nazwisko (lista i widok konta).
function Get-JezykOsoba {
    param([string]$Wyswietlana, [string]$Imie, [string]$Nazwisko)

    if ($Wyswietlana) { return $Wyswietlana }
    return (('{0} {1}' -f $Imie, $Nazwisko).Trim())
}

# Buduje obiekt wyniku - jedyne miejsce, ktore definiuje jego ksztalt (README: Budowa i rozbudowa).
# LockedOut i Enabled bez typu: [bool] zamienilby $null ("nie wiadomo") na $false.
function New-JezykResult {
    param(
        [string]$Login,
        [string]$Status,
        $LockedOut   = $null,
        $Enabled     = $null,
        [string]$DisplayName = '',
        $LockoutTime = $null,
        [string]$Message = '',

        [string]$Imie = '',
        [string]$Nazwisko = '',
        [string]$Email = '',
        [string]$TelefonGlowny = '',
        [string]$TelefonKomorkowy = '',
        [string]$Menedzer = '',

        # Grupy: pary "nazwa + DN" albo same nazwy - normalizacja tutaj, z niej oba pola wyniku.
        [object[]]$Grupy = @(),

        [string]$Lokalizacja = '',
        $ZmianaHaslaWymuszona = $null,
        $HasloWygasa          = $null,
        $HasloNigdyNieWygasa  = $null,
        $OstatniaZmianaHasla  = $null,
        $KontoWygasa          = $null,
        $KontoUtworzono       = $null,

        $OstatnieLogowaniePrzyblizone = $null,
        [string]$Dn = '',

        # Nazwa obiektu (cn) - dla kontaktow, ktore nie maja loginu.
        [string]$NazwaObiektu = '',

        [string]$Szczegoly = ''
    )

    # Jedno wejscie, dwa widoki: nazwy i DN liczone raz.
    $grupyPelne = @(Get-JezykParyGrup $Grupy)

    [pscustomobject]@{
        Login       = $Login
        Status      = $Status
        LockedOut   = $LockedOut
        Enabled     = $Enabled
        DisplayName = $DisplayName
        LockoutTime = $LockoutTime
        Message     = $Message

        Imie     = $Imie
        Nazwisko = $Nazwisko
        Email    = $Email

        # Numery surowo (sklejenie nalezy do widoku); przelozony juz rozwiazany - to osobne zapytanie.
        TelefonGlowny    = $TelefonGlowny
        TelefonKomorkowy = $TelefonKomorkowy

        Menedzer = $Menedzer

        # Zakladka "Czlonek grupy" z konsoli AD: bez grupy podstawowej i bez czlonkostw zagniezdzonych.
        # Puste pozycje odsiane (@($null) ma jeden element) - Count to liczba grup.
        Grupy = @($grupyPelne | ForEach-Object { $_.Nazwa })

        # DN grup do zapisu - Remove-ADGroupMember nie przyjmuje zwyklej nazwy (CN).
        GrupyPelne = $grupyPelne

        Lokalizacja = $Lokalizacja

        # $true = uzytkownik musi zmienic haslo przy najblizszym logowaniu (pwdLastSet = 0).
        ZmianaHaslaWymuszona = $ZmianaHaslaWymuszona

        HasloWygasa         = $HasloWygasa
        HasloNigdyNieWygasa = $HasloNigdyNieWygasa

        OstatniaZmianaHasla = $OstatniaZmianaHasla

        # $null znaczy tu "konto nigdy nie wygasa" - tak AD zwraca konto bez daty waznosci.
        KontoWygasa = $KontoWygasa

        KontoUtworzono = $KontoUtworzono

        # lastLogonTimestamp - widoczny od razu; zadanie w tle go uscisla.
        OstatnieLogowaniePrzyblizone = $OstatnieLogowaniePrzyblizone

        # DN oszczedza zadaniu w tle rozwiazywania konta na kazdym kontrolerze.
        Dn = $Dn

        NazwaObiektu = $NazwaObiektu

        Szczegoly = $Szczegoly
    }
}

# lastLogon z jednego kontrolera modulem AD - ta sama droga co reszta programu (README: Ostatnie logowanie).
# Wartosc: $null - brak odpowiedzi, 0 - nigdy, wiecej - FILETIME; Powod - krotka nazwa przyczyny.
function Get-JezykLastLogonZKontrolera {
    param([string]$Kontroler, [string]$Dn = '', [string]$Login = '')

    $wynik = [pscustomobject]@{ Kontroler = $Kontroler; Wartosc = $null; Powod = ''; Ms = 0 }

    # Sprawdzenie przed pierwszym uzyciem - nazwa trafia do -Server.
    if (-not (Test-JezykNazwaHosta $Kontroler)) {
        $wynik.Powod = 'nieprawidłowa nazwa kontrolera'
        return $wynik
    }

    # DN oszczedza kontrolerowi rozwiazywania konta; login to droga zapasowa.
    $tozsamosc = ''
    if ($Dn -and (Test-JezykDn $Dn))  { $tozsamosc = $Dn }
    elseif (Test-JezykNazwaKonta $Login) { $tozsamosc = $Login }
    if (-not $tozsamosc) {
        $wynik.Powod = 'brak poprawnego DN i loginu'
        return $wynik
    }

    $zegar = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $konto = Get-ADUser -Identity $tozsamosc -Server $Kontroler -Properties lastLogon -ErrorAction Stop
        $wynik.Wartosc = if ($null -eq $konto.lastLogon) { 0L } else { [int64]$konto.lastLogon }
    }
    catch {
        # Uwaga: typ wyjatku po nazwie, nie "catch [Typ]" - bez RSAT plik nie przeszedlby parsowania.
        $typ = $_.Exception.GetType().Name
        # Tresc odczytana przed switch - w nim $_ to juz nazwa typu, nie wyjatek.
        $pierwsza = [string]$_.Exception.Message -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1
        switch ($typ) {
            # Kontroler bez tego konta nie mogl go uwierzytelnic - to odpowiedz "nigdy", nie cisza.
            'ADIdentityNotFoundException' { $wynik.Wartosc = 0L; $wynik.Powod = 'konto jeszcze tu nie dotarło' }
            'ADServerDownException'       { $wynik.Powod = 'usługa ADWS nie odpowiada' }
            'UnauthorizedAccessException' { $wynik.Powod = 'odmowa dostępu' }
            'AuthenticationException'     { $wynik.Powod = 'nieudane uwierzytelnienie' }
            'TimeoutException'            { $wynik.Powod = 'przekroczony czas odpowiedzi' }
            'CommandNotFoundException'    { $wynik.Powod = 'brak modułu ActiveDirectory' }
            default                       { $wynik.Powod = ('{0}: {1}' -f $typ, $pierwsza).Trim().TrimEnd(':') }
        }
    }
    $wynik.Ms = $zegar.ElapsedMilliseconds

    return $wynik
}

# Dokladna data logowania: najpozniejszy lastLogon ze wszystkich kontrolerow, modulem AD (tylko w tle).
# Pelna tylko przy komplecie odpowiedzi; lastLogonTimestamp jest podloga (README: Ostatnie logowanie).
function Get-JezykOstatnieLogowanie {
    param([string]$Login, [string]$Domena, [string]$Dn = '',
          [string[]]$Kontrolery = @(),
          # lastLogonTimestamp z glownego zapytania - prawdziwe logowanie nie jest od niego starsze.
          $Przyblizona = $null,
          [int]$Port = 9389, [int]$LimitSondyMs = 1500, [int]$LimitMsLacznie = 20000)

    # DataKontrolerow - samo maksimum lastLogon; Data - to, co pokazac (z podloga).
    $wynik = [pscustomobject]@{ Data = $null; DataKontrolerow = $null; ZKontrolera = ''
                                Odpytane = 0; Wszystkie = 0; Kontrolery = @(); Odrzucone = @()
                                Przebieg = @(); Czasy = ''; Pelna = $false; ZTimestampu = $false; Blad = '' }

    $zegar = [System.Diagnostics.Stopwatch]::StartNew()

    # Bez modulu kazdy kontroler "milczalby" z tego samego powodu - jedna przyczyna zamiast listy.
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        $wynik.Blad = 'Brak modułu ActiveDirectory (RSAT) w zadaniu w tle.'
        return $wynik
    }

    $lista = @($Kontrolery | Where-Object { $_ })
    if ($lista.Count -eq 0) {
        try {
            $lista = @(Get-ADDomainController -Filter * -Server $Domena -ErrorAction Stop |
                       Select-Object -ExpandProperty HostName)
        }
        catch {
            # Powod zapisany - bez niego pole pokazaloby sama date przyblizona jak wynik.
            $wynik.Blad = 'Nie udało się pobrać listy kontrolerów domeny {0}: {1}' -f $Domena, $_.Exception.Message
            return $wynik
        }
    }
    $msListy = $zegar.ElapsedMilliseconds

    # Nazwy kontrolerow sprawdzane tutaj - odrzucone osobno od milczacych.
    $wynik.Odrzucone  = @($lista | Where-Object { -not (Test-JezykNazwaHosta $_) })
    $lista            = @($lista | Where-Object { Test-JezykNazwaHosta $_ })
    $wynik.Kontrolery = $lista
    $wynik.Wszystkie  = $lista.Count
    if ($lista.Count -eq 0) {
        $wynik.Blad = 'Domena {0} nie podała żadnego kontrolera o poprawnej nazwie.' -f $Domena
        return $wynik
    }

    # Uwaga: sonda wszystkich naraz przed odczytem - zablokowany port trzymalby odczyt okolo 21 s (README: Pulapki).
    $porty   = Get-JezykSondaPortow -Serwery $lista -Port $Port -LimitMs $LimitSondyMs
    $msSondy = $zegar.ElapsedMilliseconds - $msListy

    # Kolejno, nie rownolegle: kazda przestrzen w puli musialaby importowac modul AD od nowa.
    $najnowsze = 0L
    $przebieg  = @()
    foreach ($kontroler in $lista) {
        $powodPortu = if ($porty.ContainsKey($kontroler)) { [string]$porty[$kontroler] } else { 'sonda nie oddała odpowiedzi' }
        if ($powodPortu) {
            $przebieg += '{0} - {1}' -f $kontroler, $powodPortu
            continue
        }

        # Termin sprawdzany przed kazdym kontrolerem - zaczete zapytanie konczy sie samo.
        if ($zegar.ElapsedMilliseconds -gt $LimitMsLacznie) {
            $przebieg += '{0} - pominięty: minął termin {1} s' -f $kontroler, [int]($LimitMsLacznie / 1000)
            continue
        }

        $odpowiedz = Get-JezykLastLogonZKontrolera -Kontroler $kontroler -Dn $Dn -Login $Login
        $czas      = '{0:0.0} s' -f ($odpowiedz.Ms / 1000)
        if ($null -eq $odpowiedz.Wartosc) {
            $przebieg += '{0} - {1} ({2})' -f $kontroler, $odpowiedz.Powod, $czas
            continue
        }

        $wynik.Odpytane++
        $wartosc = [int64]$odpowiedz.Wartosc
        if ($wartosc -le 0) {
            $opis = if ($odpowiedz.Powod) { 'nigdy - {0}' -f $odpowiedz.Powod } else { 'nigdy' }
            $przebieg += '{0} - {1} ({2})' -f $kontroler, $opis, $czas
            continue
        }

        $kiedy = $null
        try { $kiedy = [datetime]::FromFileTime($wartosc) } catch { }
        $przebieg += '{0} - {1:yyyy-MM-dd HH:mm} ({2})' -f $kontroler, $kiedy, $czas
        if ($wartosc -gt $najnowsze) {
            $najnowsze         = $wartosc
            $wynik.ZKontrolera = $kontroler
        }
    }
    $wynik.Przebieg = $przebieg
    $wynik.Czasy    = 'lista kontrolerów {0:0.0} s, sonda portu {1:0.0} s, odczyt {2:0.0} s' -f
                      ($msListy / 1000), ($msSondy / 1000), (($zegar.ElapsedMilliseconds - $msListy - $msSondy) / 1000)

    if ($najnowsze -gt 0) {
        try   { $wynik.DataKontrolerow = [datetime]::FromFileTime($najnowsze) }
        catch { $wynik.DataKontrolerow = $null }
    }
    $wynik.Data = $wynik.DataKontrolerow

    # Podloga: lastLogonTimestamp zapisal kontroler przy logowaniu; minuta tolerancji na zapis.
    if ($Przyblizona -is [datetime] -and
        ($null -eq $wynik.DataKontrolerow -or $Przyblizona -gt $wynik.DataKontrolerow.AddMinutes(1))) {
        $wynik.Data        = $Przyblizona
        $wynik.ZTimestampu = $true
    }

    if ($wynik.Odpytane -eq 0) {
        $wynik.Blad = 'Żaden z kontrolerów domeny {0} nie odpowiedział.' -f $Domena
    }

    $wynik.Pelna = (-not $wynik.Blad -and $wynik.Odpytane -eq $wynik.Wszystkie -and
                    @($wynik.Odrzucone).Count -eq 0 -and -not $wynik.ZTimestampu)

    return $wynik
}

# Czy port na hoscie odpowiada (termin 1,5 s) - sonda przed kazda sesja WMI (README: Pulapki).
# DNS rozwiazywany osobno, w tym samym terminie - BeginConnect z nazwa rozwiazuje ja synchronicznie.
function Test-JezykPortOtwarty {
    param([string]$Serwer, [int]$Port, [int]$LimitMs = 1500)

    if (-not (Test-JezykNazwaHosta $Serwer)) { return $false }

    $zegar = [System.Diagnostics.Stopwatch]::StartNew()

    $adresy = $null
    try {
        $uchwytDns = [System.Net.Dns]::BeginGetHostAddresses($Serwer, $null, $null)
        if (-not $uchwytDns.AsyncWaitHandle.WaitOne($LimitMs, $false)) { return $false }
        $adresy = [System.Net.Dns]::EndGetHostAddresses($uchwytDns)
    }
    catch { return $false }

    if (-not $adresy -or @($adresy).Count -eq 0) { return $false }

    $pozostalo = $LimitMs - $zegar.ElapsedMilliseconds
    if ($pozostalo -le 0) { return $false }

    $klient = $null
    try {
        $klient = New-Object System.Net.Sockets.TcpClient

        # Adresy, nie nazwa - juz rozwiazana.
        $uchwyt = $klient.BeginConnect($adresy, $Port, $null, $null)

        # WaitOne z terminem - samo EndConnect czekaloby tyle, ile zechce stos TCP.
        if (-not $uchwyt.AsyncWaitHandle.WaitOne([int]$pozostalo, $false)) { return $false }

        $klient.EndConnect($uchwyt)
        return $true
    }
    catch { return $false }
    finally { if ($klient) { try { $klient.Close() } catch { } } }
}

# Ten sam port na wielu hostach naraz, z jednym terminem na calosc - bez przestrzeni w tle.
# Nazwa -> '' (port odpowiada) albo krotki powod; DNS osobno, jak w Test-JezykPortOtwarty.
function Get-JezykSondaPortow {
    param([string[]]$Serwery, [int]$Port, [int]$LimitMs = 1500)

    $wynik = @{}
    $zegar = [System.Diagnostics.Stopwatch]::StartNew()

    # Zapytania DNS wszystkich hostow ruszaja od razu.
    $dns = [ordered]@{}
    foreach ($serwer in @($Serwery)) {
        if (-not $serwer -or $wynik.ContainsKey($serwer) -or $dns.Contains($serwer)) { continue }
        if (-not (Test-JezykNazwaHosta $serwer)) { $wynik[$serwer] = 'nieprawidłowa nazwa'; continue }
        try   { $dns[$serwer] = [System.Net.Dns]::BeginGetHostAddresses($serwer, $null, $null) }
        catch { $wynik[$serwer] = 'nie rozwiązano nazwy w DNS' }
    }

    # Polaczenie rusza, gdy tylko nazwa sie rozwiaze - czekanie na kolejne idzie w tym samym terminie.
    $polaczenia = [ordered]@{}
    foreach ($serwer in @($dns.Keys)) {
        $uchwytDns = $dns[$serwer]
        $pozostalo = [int]($LimitMs - $zegar.ElapsedMilliseconds)
        if (-not $uchwytDns.IsCompleted -and ($pozostalo -le 0 -or -not $uchwytDns.AsyncWaitHandle.WaitOne($pozostalo, $false))) {
            $wynik[$serwer] = 'DNS nie odpowiedział w {0} ms' -f $LimitMs
            continue
        }

        $adresy = $null
        try   { $adresy = [System.Net.Dns]::EndGetHostAddresses($uchwytDns) } catch { }
        if (-not $adresy -or @($adresy).Count -eq 0) { $wynik[$serwer] = 'nie rozwiązano nazwy w DNS'; continue }

        $klient = New-Object System.Net.Sockets.TcpClient
        try {
            $polaczenia[$serwer] = [pscustomobject]@{ Klient = $klient; Uchwyt = $klient.BeginConnect($adresy, $Port, $null, $null) }
        }
        catch {
            $wynik[$serwer] = 'port {0} nie przyjął połączenia' -f $Port
            try { $klient.Close() } catch { }
        }
    }

    foreach ($serwer in @($polaczenia.Keys)) {
        $polaczenie = $polaczenia[$serwer]
        $pozostalo  = [int]($LimitMs - $zegar.ElapsedMilliseconds)
        try {
            if (-not $polaczenie.Uchwyt.IsCompleted -and
                ($pozostalo -le 0 -or -not $polaczenie.Uchwyt.AsyncWaitHandle.WaitOne($pozostalo, $false))) {
                $wynik[$serwer] = 'port {0} nie odpowiedział w {1} ms' -f $Port, $LimitMs
                continue
            }
            $polaczenie.Klient.EndConnect($polaczenie.Uchwyt)
            $wynik[$serwer] = ''
        }
        catch { $wynik[$serwer] = 'port {0} odrzucił połączenie' -f $Port }
        finally { try { $polaczenie.Klient.Close() } catch { } }
    }

    return $wynik
}

# Nazywa przyczyne bledu WMI i podaje naprawe; rozpoznaje najpierw po kodzie bledu, potem po tresci.
function Get-JezykOpisBleduWmi {
    param($Wyjatek, [string]$Serwer = '', [string]$Przestrzen = '', [string]$Protokol = '',
          [ValidateSet('', 'Polaczenie', 'Zapytanie')][string]$Etap = '')

    $tresc = if ($Wyjatek -and $Wyjatek.Exception) { [string]$Wyjatek.Exception.Message } else { [string]$Wyjatek }
    $tresc = ([string]$tresc).Trim()
    if (-not $tresc) { $tresc = 'brak treści błędu' }

    # NativeErrorCode - wyliczenie CIM niezalezne od jezyka systemu; nie kazdy wyjatek go ma.
    $kodCim = ''
    try {
        if ($Wyjatek.Exception -and $Wyjatek.Exception.PSObject.Properties['NativeErrorCode']) {
            $kodCim = [string]$Wyjatek.Exception.NativeErrorCode
        }
    }
    catch { }

    # 0x80131500 (COR_E_EXCEPTION) to szum .NET, nie kod bledu WMI - nie pokazujemy go.
    $kodHex = ''
    try {
        $hresult = [int]$Wyjatek.Exception.HResult
        if ($hresult -ne 0 -and $hresult -ne 0x80131500) { $kodHex = '0x{0:X8}' -f $hresult }
    }
    catch { }

    if     ($Protokol -eq 'Wsman') { $port = '5985 (WinRM)' }
    elseif ($Protokol)             { $port = '135 (DCOM/RPC)' }
    else                           { $port = '' }

    if (($kodCim -eq 'InvalidNamespace') -or ($kodHex -eq '0x8004100E') -or
        ($tresc -match 'Invalid namespace|Nieprawid.owa przestrze')) {

        $krotki  = 'zła przestrzeń nazw SCCM'
        $naprawa = 'Przestrzeni "{0}" NIE MA na serwerze {1}. Dwie możliwe przyczyny: SccmKodLokacji jest inny niż faktyczny kod lokacji, albo ten serwer nie pełni roli SMS Provider - przestrzeń root\sms\site_XXX mieszka wyłącznie na serwerze lokacji, nie na punkcie zarządzania.' -f $Przestrzen, $Serwer
    }
    elseif (($kodCim -eq 'AccessDenied') -or ($kodHex -eq '0x80070005') -or
            ($tresc -match 'Access is denied|Access denied|Odmowa dost.pu|Odmowa dost')) {

        $krotki  = 'brak uprawnień do SCCM'

        # Odmowa przy polaczeniu (prawo DCOM) i przy zapytaniu (przestrzen WMI) to dwie rozne bramki.
        if ($Etap -eq 'Polaczenie') {
            $naprawa = 'Serwer {0} ODMÓWIŁ już przy nawiązywaniu połączenia - zanim padło jakiekolwiek zapytanie o dane SCCM. To wskazuje na brak prawa zdalnej aktywacji DCOM dla tego konta na tym serwerze (Component Services → Computers → Mój komputer → DCOM Config → "Windows Management and Instrumentation" → Security → Launch and Activation Permissions), a nie na brak roli w konsoli ConfigMgr.' -f $Serwer
        }
        elseif ($Etap -eq 'Zapytanie') {
            $naprawa = 'Serwer {0} przyjął połączenie, ale ODMÓWIŁ dostępu konkretnie do przestrzeni "{1}". To zabezpieczenie NA POZIOMIE SAMEJ PRZESTRZENI NAZW WMI (wmimgmt.msc → root\sms\site_XXX → Właściwości → Zabezpieczenia), oddzielne od ról w konsoli ConfigMgr - samo członkostwo w grupie "SMS Admins" nie zawsze automatycznie nadaje to prawo na poziomie WMI.' -f $Serwer, $Przestrzen
        }
        else {
            $naprawa = 'Serwer {0} odpowiedział i ODMÓWIŁ. Do odczytu SMS Provider konto potrzebuje prawa w samym providerze (zwykle członkostwo w grupie "SMS Admins" na serwerze lokacji) oraz prawa zdalnej aktywacji DCOM. Rola w konsoli ConfigMgr nadaje te prawa tylko wtedy, gdy została kontu faktycznie przypisana.' -f $Serwer
        }
    }
    elseif (($kodHex -eq '0x800706BA') -or ($tresc -match 'RPC server is unavailable|Serwer RPC jest niedost')) {

        $krotki  = 'serwer SCCM nie odpowiada'
        $naprawa = 'Serwer {0} nie przyjął połączenia na porcie {1}. Zwykle zapora między stacją a serwerem lokacji albo wyłączony DCOM. Warto sprawdzić drugi protokół - ustaw SccmProtokol na "{2}" w Jezyk-1-Srodowisko.ps1.' -f
                   $Serwer, $port, $(if ($Protokol -eq 'Wsman') { 'Dcom' } else { 'Wsman' })
    }
    elseif (($kodCim -eq 'InvalidClass') -or ($kodHex -eq '0x80041010') -or
            ($tresc -match 'Invalid class|Nieprawid.owa klasa')) {

        $krotki  = 'brak klasy w SCCM'
        $naprawa = 'Przestrzeń "{0}" istnieje, ale nie ma w niej pytanej klasy. Zwykle znaczy to inną wersję ConfigMgr albo wyłączoną inwentaryzację sprzętu.' -f $Przestrzen
    }
    elseif ($tresc -match 'WinRM|WS-Management|WSMan') {

        $krotki  = 'WinRM odrzucił połączenie'
        $naprawa = 'Protokół Wsman idzie przez WinRM, a wstęp tam wymaga członkostwa w grupie Administrators albo Remote Management Users na serwerze {0} - rola w ConfigMgr go nie daje. Ustaw SccmProtokol na "Dcom" w Jezyk-1-Srodowisko.ps1.' -f $Serwer
    }
    else {
        $krotki  = 'błąd zapytania do SCCM'
        $naprawa = 'Przyczyny nie dało się rozpoznać po kodzie błędu - pełna treść poniżej.'
    }

    $techniczne = @()
    if ($Serwer)     { $techniczne += 'serwer: {0}'    -f $Serwer }
    if ($Przestrzen) { $techniczne += 'przestrzeń: {0}' -f $Przestrzen }
    if ($Protokol)   { $techniczne += 'protokół: {0}'   -f $Protokol }
    if ($kodCim)     { $techniczne += 'kod CIM: {0}'    -f $kodCim }
    if ($kodHex)     { $techniczne += 'HRESULT: {0}'    -f $kodHex }

    $szczegoly = @($naprawa, '', $tresc)
    if ($techniczne.Count) { $szczegoly += @('', ($techniczne -join '; ')) }

    [pscustomobject]@{ Krotki = $krotki; Szczegoly = ($szczegoly -join [Environment]::NewLine) }
}

# Jedna sesja WMI do serwera lokacji na cale zadanie; przed kazda proba sonda portu.
# Protokol zapasowy probuje tego samego serwera - takze po odmowie dostepu na pierwszym.
function Open-JezykSesjaSccm {
    param([string]$Serwer, [string]$Protokol = 'Dcom', [bool]$Zapasowy = $false,
          [int]$LimitSek = 15, [int]$LimitSondyMs = 1500)

    $wynik = [pscustomobject]@{ Sesja = $null; Protokol = ''; Blad = ''; Szczegoly = '' }

    # Sprawdzenie nazwy przed pierwszym uzyciem - takze przed sonda.
    if (-not (Test-JezykNazwaHosta $Serwer)) {
        $wynik.Blad      = 'zła nazwa serwera SCCM'
        $wynik.Szczegoly = 'SccmSerwer "{0}" nie jest poprawną nazwą hosta.' -f $Serwer
        return $wynik
    }

    if ($Protokol -notin 'Dcom', 'Wsman') { $Protokol = 'Dcom' }

    $kolejnosc = @($Protokol)
    if ($Zapasowy) { $kolejnosc += $(if ($Protokol -eq 'Wsman') { 'Dcom' } else { 'Wsman' }) }

    $powody      = @()
    $ostatniOpis = ''

    # Odmowa uprawnien zapamietana osobno - ma pierwszenstwo w koncowym komunikacie.
    $bladOdmowy = $null

    foreach ($proba in $kolejnosc) {
        $port = if ($proba -eq 'Wsman') { 5985 } else { 135 }

        if (-not (Test-JezykPortOtwarty -Serwer $Serwer -Port $port -LimitMs $LimitSondyMs)) {
            $powody += '{0}: port {1} nie odpowiedział w {2} ms' -f $proba, $port, $LimitSondyMs
            continue
        }

        try {
            # Uwaga: bez -SkipTestConnection domyslny test pyta root\cimv2 zamiast root\sms i dostaje odmowe
            # (README: -SkipTestConnection jest warunkiem dzialania).
            $wynik.Sesja = New-CimSession -ComputerName $Serwer `
                                          -SessionOption (New-CimSessionOption -Protocol $proba) `
                                          -OperationTimeoutSec $LimitSek `
                                          -SkipTestConnection `
                                          -ErrorAction Stop
            $wynik.Protokol = $proba
            if ($powody.Count) {
                $wynik.Szczegoly = 'połączono protokołem {0}, wcześniej nie wyszło: {1}' -f $proba, ($powody -join '; ')
            }
            return $wynik
        }
        catch {
            # Etap 'Polaczenie': odmowa przed dotknieciem root\sms - naprawa to prawo aktywacji DCOM.
            $opis        = Get-JezykOpisBleduWmi $_ -Serwer $Serwer -Protokol $proba -Etap 'Polaczenie'
            $powody     += '{0}: {1}' -f $proba, $opis.Krotki
            $ostatniOpis = $opis.Szczegoly

            if ($opis.Krotki -eq 'brak uprawnień do SCCM') { $bladOdmowy = $opis }
        }
    }

    # Odmowa na ktorymkolwiek protokole zostaje wynikiem - mowi najwiecej.
    if ($bladOdmowy) {
        $wynik.Blad      = $bladOdmowy.Krotki
        $wynik.Szczegoly = if ($kolejnosc.Count -gt 1) {
            '{0}{1}{1}(wypróbowano też: {2})' -f $bladOdmowy.Szczegoly, [Environment]::NewLine, ($powody -join '; ')
        } else { $bladOdmowy.Szczegoly }
        return $wynik
    }

    # Sonda odrzucila wszystko - zaden port nie odpowiedzial.
    if (-not $ostatniOpis) {
        $ostatniOpis = 'Żaden port nie odpowiedział, więc żadna sesja nie została nawet zestawiona. Zwykle znaczy to zaporę między stacją a serwerem lokacji albo złą nazwę serwera w SccmSerwer.'
    }

    $wynik.Blad      = 'brak połączenia z SCCM'
    $wynik.Szczegoly = @(('Żadna droga do serwera {0} nie doszła do skutku: {1}.' -f $Serwer, ($powody -join '; ')),
                         '', $ostatniOpis) -join [Environment]::NewLine
    return $wynik
}

# Jedno zapytanie na gotowej sesji, z terminem; wyjatek zostawia wolajacemu.
function Invoke-JezykZapytanieWmi {
    param($Sesja, [string]$Przestrzen, [string]$Zapytanie, [int]$LimitSek = 15)

    Get-CimInstance -CimSession $Sesja -Namespace $Przestrzen -Query $Zapytanie `
                    -OperationTimeoutSec $LimitSek -ErrorAction Stop
}

# To samo zapytanie starym stosem WMI (jak konsola ConfigMgr) - bez terminu, tylko po odmowie CIM.
function Invoke-JezykZapytanieWmiStare {
    param([string]$Serwer, [string]$Przestrzen, [string]$Zapytanie)

    Get-WmiObject -ComputerName $Serwer -Namespace $Przestrzen -Query $Zapytanie -ErrorAction Stop
}

# Zapytanie do SCCM: stos CIM, a po ODMOWIE uprawnien - stary stos WMI (README: Dwa stosy WMI).
function Invoke-JezykZapytanieSccm {
    param($Sesja, [string]$Serwer, [string]$Przestrzen, [string]$Zapytanie,
          [string]$Protokol = 'Dcom', [int]$LimitSek = 15)

    $wynik = [pscustomobject]@{ Wiersze = @(); Blad = $null; Stos = 'CIM' }

    try {
        $wynik.Wiersze = @(Invoke-JezykZapytanieWmi -Sesja $Sesja -Przestrzen $Przestrzen `
                               -Zapytanie $Zapytanie -LimitSek $LimitSek)
        return $wynik
    }
    catch {
        # Etap 'Zapytanie': odmowa dotyczy konkretnej przestrzeni nazw.
        $wynik.Blad = Get-JezykOpisBleduWmi $_ -Serwer $Serwer -Przestrzen $Przestrzen `
                                              -Protokol $Protokol -Etap 'Zapytanie'
        if ($wynik.Blad.Krotki -ne 'brak uprawnień do SCCM') { return $wynik }
    }

    try {
        $wynik.Wiersze = @(Invoke-JezykZapytanieWmiStare -Serwer $Serwer -Przestrzen $Przestrzen `
                               -Zapytanie $Zapytanie)
        $wynik.Blad = $null
        $wynik.Stos = 'WMI'
    }
    catch { }

    return $wynik
}

# Ustawienia SCCM z konfiguracji, bez rozpoznawania: kod lokacji 3 znaki, serwer z bialej listy.
function Get-JezykSccmPolaczenie {
    param([string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom')

    $wynik = [pscustomobject]@{ Serwer = ''; KodLokacji = ''; Protokol = 'Dcom'; Blad = '' }

    $brakujace = @()
    if (-not $Serwer)     { $brakujace += 'SccmSerwer' }
    if (-not $KodLokacji) { $brakujace += 'SccmKodLokacji' }
    if ($brakujace.Count) {
        $wynik.Blad = 'uzupełnij {0} w Jezyk-1-Srodowisko.ps1' -f ($brakujace -join ' i ')
        return $wynik
    }

    if ($KodLokacji -notmatch '^[A-Za-z0-9]{3}$') {
        $wynik.Blad = 'SccmKodLokacji ma być trzyznakowym kodem lokacji, np. P01 (jest: "{0}")' -f $KodLokacji
        return $wynik
    }

    if (-not (Test-JezykNazwaHosta $Serwer)) {
        $wynik.Blad = 'SccmSerwer ma nieprawidłową nazwę (jest: "{0}")' -f $Serwer
        return $wynik
    }

    if ($Protokol -notin 'Dcom', 'Wsman') { $Protokol = 'Dcom' }

    $wynik.Serwer     = $Serwer
    $wynik.KodLokacji = $KodLokacji
    $wynik.Protokol   = $Protokol
    return $wynik
}

# Znacznik czasu z SCCM (UTC) na czas lokalny: Kind Utc, Local, Unspecified (jak UTC) i lancuch DMTF.
# Nie rzuca - wartosc nie do odczytania to $null (README: Data przychodzi w UTC).
function ConvertTo-JezykCzasLokalny {
    param($Wartosc)

    if ($null -eq $Wartosc) { return $null }

    if ($Wartosc -isnot [datetime]) {
        $tekst = ([string]$Wartosc).Trim()
        if (-not $tekst) { return $null }

        # DMTF niesie wlasne przesuniecie strefy (minuty od UTC); "***" - bez strefy, SCCM zapisuje tak UTC.
        if ($tekst -match '^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\.(\d{6})([+-])(\d{3}|\*{3})$') {
            try {
                # Mikrosekundy na takty: jeden takt to 100 nanosekund.
                $utc = [datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3],
                                       [int]$Matches[4], [int]$Matches[5], [int]$Matches[6],
                                       [System.DateTimeKind]::Utc).AddTicks([long]$Matches[7] * 10)

                # Zapis to czas lokalny serwera - do UTC idziemy w strone przeciwna do znaku.
                $minuty = if ($Matches[9] -eq '***') { 0 } else { [int]$Matches[9] }
                if ($Matches[8] -eq '+') { $minuty = -$minuty }

                return $utc.AddMinutes($minuty).ToLocalTime()
            }
            catch { return $null }
        }

        try   { $Wartosc = [datetime]$tekst }
        catch { return $null }
    }

    $data = [datetime]$Wartosc

    if ($data.Kind -eq [System.DateTimeKind]::Local) { return $data }
    if ($data.Kind -eq [System.DateTimeKind]::Utc)   { return $data.ToLocalTime() }

    return ([datetime]::SpecifyKind($data, [System.DateTimeKind]::Utc)).ToLocalTime()
}

# Nazwy kont z jednego pola SCCM, bez przedrostka domeny (pole bywa lista po przecinku).
function Get-JezykKontaZPola {
    param([string]$Wartosc)

    $konta = New-Object System.Collections.Generic.List[string]

    foreach ($wpis in ([string]$Wartosc) -split ',') {
        $czysty = $wpis.Trim()
        if (-not $czysty) { continue }

        # Ostatni czlon, a nie pierwszy: "DOMENA\konto" ma oddac "konto".
        $konta.Add(($czysty -split '\\')[-1])
    }

    # Przecinek wymuszony - patrz Get-JezykKontaMaszyny nizej.
    return ,$konta.ToArray()
}

# Odrebne konta na maszynie (Current/LastLogonUser, PrimaryUser); wiecej niz jedno = wspoldzielona.
function Get-JezykKontaMaszyny {
    param($Wiersz)

    $konta    = New-Object System.Collections.Generic.List[string]
    $widziane = @{}
    $surowe   = (Get-JezykKontaZPola ([string]$Wiersz.CurrentLogonUser)) +
                (Get-JezykKontaZPola ([string]$Wiersz.LastLogonUser)) +
                (Get-JezykKontaZPola ([string]$Wiersz.PrimaryUser))

    foreach ($bezDomeny in $surowe) {
        $klucz = $bezDomeny.ToLowerInvariant()
        if ($widziane.ContainsKey($klucz)) { continue }

        $widziane[$klucz] = $true
        $konta.Add($bezDomeny)
    }

    # Przecinek wymuszony - bez niego tablica 0/1-elementowa rozwinelaby sie przy zwrocie.
    return ,$konta.ToArray()
}

# Adres MAC karty z dokladnie tym adresem IP (cala tablica IPAddress); brak trafienia = pusty napis.
function Get-JezykMacDlaAdresu {
    param($Karty, [string]$Adres)

    if (-not $Adres) { return '' }

    $szukany = $Adres.Trim()

    foreach ($karta in @($Karty)) {
        if (-not $karta) { continue }
        if (-not $karta.MACAddress) { continue }

        # Ksztaltu IPAddress nie zakladamy - bywa tablica albo jeden napis "10.0.0.5, fe80::1".
        $adresyKarty = New-Object System.Collections.Generic.List[string]
        foreach ($wpis in @($karta.IPAddress)) {
            foreach ($czesc in ([string]$wpis) -split '[,;]') {
                $czysta = $czesc.Trim()
                if ($czysta) { $adresyKarty.Add($czysta) }
            }
        }

        if ($adresyKarty -contains $szukany) { return [string]$karta.MACAddress }
    }

    return ''
}

# Rozbiera wartosc z inwentaryzacji na wpisy, zachowujac pozycje (IPSubnet paruje sie po indeksie).
# Uwaga: bez przecinka przy return - wolajacy owija wynik w @() (README: Kod > Jezyk-2-Logika).
function Get-JezykRozbiteWpisy {
    param($Wartosc)

    $wpisy = New-Object System.Collections.Generic.List[string]
    foreach ($element in @($Wartosc)) {
        foreach ($czesc in ([string]$element) -split '[,;]') {
            $wpisy.Add($czesc.Trim())
        }
    }

    return $wpisy.ToArray()
}

# Bajty adresu IPv4 albo $null. Adres musi wrocic tym samym napisem, bo TryParse przyjmuje
# takze "64", "10.0.0" i "010.20.30.44" (osemkowo). Przecinek przy return celowy.
function Get-JezykBajtyIPv4 {
    param([string]$Tekst)

    $czysty = ([string]$Tekst).Trim()
    if (-not $czysty) { return $null }

    $odczytany = $null
    if (-not [System.Net.IPAddress]::TryParse($czysty, [ref]$odczytany)) { return $null }
    if ($odczytany.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $null }
    if ($odczytany.ToString() -ne $czysty) { return $null }

    return ,$odczytany.GetAddressBytes()
}

# Czy napis jest maska IPv4: ciag jedynek, potem zera, nie /0 (w IPSubnet bywa adres podsieci).
function Test-JezykMaskaIPv4 {
    param([string]$Maska)

    $bajty = Get-JezykBajtyIPv4 $Maska
    if (-not $bajty) { return $false }

    $dozwolone   = @(0, 128, 192, 224, 240, 248, 252, 254, 255)
    $bylaPrzerwa = $false
    $sumaBajtow  = 0
    foreach ($bajt in $bajty) {
        $wartosc     = [int]$bajt
        $sumaBajtow += $wartosc
        if ($dozwolone -notcontains $wartosc) { return $false }
        if ($bylaPrzerwa -and $wartosc -ne 0) { return $false }
        if ($wartosc -ne 255) { $bylaPrzerwa = $true }
    }

    return ($sumaBajtow -gt 0)
}

# Czy adres z sondy i adres karty leza w tej samej podsieci - bajt po bajcie, bez try.
function Test-JezykTaSamaPodsiec {
    param([string]$Sonda, [string]$Karta, [string]$Maska)

    if (-not (Test-JezykMaskaIPv4 $Maska)) { return $false }

    $bajtySondy = Get-JezykBajtyIPv4 $Sonda
    $bajtyKarty = Get-JezykBajtyIPv4 $Karta
    $bajtyMaski = Get-JezykBajtyIPv4 $Maska
    if (-not $bajtySondy -or -not $bajtyKarty) { return $false }

    for ($i = 0; $i -lt 4; $i++) {
        if (($bajtySondy[$i] -band $bajtyMaski[$i]) -ne ($bajtyKarty[$i] -band $bajtyMaski[$i])) {
            return $false
        }
    }

    return $true
}

# Karty z adresem IPv4; maska po indeksie pelnej listy, MaskaZSccm - czy maska jest z inwentaryzacji.
# Uwaga: bez przecinka przy return - wolajacy owija wynik w @().
function Get-JezykKartySieciowe {
    param($Wiersze)

    $karty = New-Object System.Collections.Generic.List[object]

    foreach ($wiersz in @($Wiersze)) {
        if (-not $wiersz) { continue }
        if (-not $wiersz.MACAddress) { continue }

        $maskiWiersza = @()
        if ($wiersz.PSObject.Properties['IPSubnet']) {
            $maskiWiersza = @(Get-JezykRozbiteWpisy $wiersz.IPSubnet)
        }
        $opisWiersza = ''
        if ($wiersz.PSObject.Properties['Description']) {
            $opisWiersza = ([string]$wiersz.Description).Trim()
        }

        $adresyKarty = @(Get-JezykRozbiteWpisy $wiersz.IPAddress)
        $czytelne    = New-Object System.Collections.Generic.List[object]

        for ($i = 0; $i -lt $adresyKarty.Count; $i++) {
            if (-not (Get-JezykBajtyIPv4 $adresyKarty[$i])) { continue }

            $maskaWpisu = if ($i -lt $maskiWiersza.Count) { [string]$maskiWiersza[$i] } else { '' }
            $zSccm      = Test-JezykMaskaIPv4 $maskaWpisu
            if (-not $zSccm) { $maskaWpisu = '255.255.255.0' }

            $czytelne.Add([pscustomobject]@{ Adres      = [string]$adresyKarty[$i]
                                             Maska      = $maskaWpisu
                                             MaskaZSccm = [bool]$zSccm })
        }

        if ($czytelne.Count -eq 0) { continue }

        $karty.Add([pscustomobject]@{ Mac    = [string]$wiersz.MACAddress
                                      Opis   = $opisWiersza
                                      Adresy = $czytelne.ToArray() })
    }

    return $karty.ToArray()
}

# Ktora karta odpowiada pod adresem sondy i na jakiej podstawie: Adres, Podsiec, Wiele, Brak albo ''.
# Trzeciego szczebla ("jedyna karta z adresem") swiadomie nie ma; karta liczy sie raz.
function Get-JezykDopasowanieMac {
    param($Wiersze, [string]$Adres)

    $dopasowanie = [pscustomobject]@{ Mac = ''; Podstawa = ''; Karta = $null
                                      Karty = @(); Wpisow = 0 }

    # @() wokol potoku - @($null).Count to 1.
    $zWierszy = @(@($Wiersze) | Where-Object { $_ })
    $dopasowanie.Wpisow = $zWierszy.Count
    $dopasowanie.Karty  = @(Get-JezykKartySieciowe -Wiersze $zWierszy)

    if (-not $Adres) { return $dopasowanie }

    $dokladny = Get-JezykMacDlaAdresu -Karty $zWierszy -Adres $Adres
    if ($dokladny) {
        $dopasowanie.Mac      = $dokladny
        $dopasowanie.Podstawa = 'Adres'
        return $dopasowanie
    }

    $trafione = New-Object System.Collections.Generic.List[object]
    foreach ($karta in $dopasowanie.Karty) {
        foreach ($wpis in @($karta.Adresy)) {
            if (Test-JezykTaSamaPodsiec -Sonda $Adres -Karta $wpis.Adres -Maska $wpis.Maska) {
                $trafione.Add([pscustomobject]@{ Mac        = [string]$karta.Mac
                                                 Opis       = [string]$karta.Opis
                                                 Adres      = [string]$wpis.Adres
                                                 Maska      = [string]$wpis.Maska
                                                 MaskaZSccm = [bool]$wpis.MaskaZSccm })
                break
            }
        }
    }

    if ($trafione.Count -eq 1) {
        $dopasowanie.Mac      = [string]$trafione[0].Mac
        $dopasowanie.Karta    = $trafione[0]
        $dopasowanie.Podstawa = 'Podsiec'
    }
    elseif ($trafione.Count -gt 1) { $dopasowanie.Podstawa = 'Wiele' }
    else                           { $dopasowanie.Podstawa = 'Brak' }

    return $dopasowanie
}

# Dopisuje do wyniku MAC karty dopasowanej do adresu IP (obie drogi: od loginu i od maszyny).
# SELECT *, bo IPSubnet i Description bywaja wylaczone w inwentaryzacji; brak trafienia to nie awaria.
function Set-JezykMacWWyniku {
    param($Wynik, $ResourceID, $Sesja, [string]$Przestrzen, [int]$LimitSek)

    if (-not $Wynik.Adres) {
        $Wynik.MacSzczegoly = 'Nie ustalono adresu IP maszyny, więc nie ma do czego dopasować karty sieciowej.'
        return
    }

    if (-not $ResourceID) {
        $Wynik.MacSzczegoly = 'Źródło, które podało tę maszynę, nie niesie identyfikatora zasobu (ResourceID), a bez niego nie ma jak zapytać o jej karty sieciowe.'
        return
    }

    try {
        $idKarty = [int]$ResourceID
        $wiersze = @(Invoke-JezykZapytanieWmi -Sesja $Sesja -Przestrzen $Przestrzen -LimitSek $LimitSek `
                         -Zapytanie (
            "SELECT * FROM SMS_G_System_NETWORK_ADAPTER_CONFIGURATION WHERE ResourceId = $idKarty"))

        $dopasowanie = Get-JezykDopasowanieMac -Wiersze $wiersze -Adres $Wynik.Adres

        $Wynik.Mac         = [string]$dopasowanie.Mac
        $Wynik.MacPodstawa = [string]$dopasowanie.Podstawa
        $Wynik.MacKarta    = $dopasowanie.Karta
        $Wynik.MacKarty    = @($dopasowanie.Karty)
        $Wynik.MacWpisow   = [int]$dopasowanie.Wpisow
    }
    catch {
        # Powod zapisany - pusty catch zrobilby z bledu "brak danych".
        $Wynik.MacSzczegoly = 'Odczyt kart sieciowych z SCCM zawiódł: {0}' -f $_.Exception.Message
    }
}

# Wybiera z wierszy SCCM maszyne loginu: dokladne dopasowanie konta (wzorzec WQL to tylko przesiew),
# stopien pola (Current, Last, Primary) przed data, bez wzgledu na wielkosc liter.
function Select-JezykMaszyneDlaLoginu {
    param($Wiersze, [string]$Login,
          $Pola = @('CurrentLogonUser', 'LastLogonUser', 'PrimaryUser'))

    $wynik = [pscustomobject]@{ Wiersz = $null; Pole = ''; Data = $null; Ile = 0 }
    if (-not $Login) { return $wynik }

    $nazwyPol = @($Pola)
    $najlepszy = $nazwyPol.Count

    foreach ($wiersz in @($Wiersze)) {
        if (-not $wiersz) { continue }
        if (-not ($wiersz.Name -or $wiersz.NetbiosName)) { continue }

        $stopien = -1
        for ($i = 0; $i -lt $nazwyPol.Count; $i++) {
            $nazwaPola = $nazwyPol[$i]
            if ((Get-JezykKontaZPola ([string]$wiersz.$nazwaPola)) -contains $Login) {
                $stopien = $i
                break
            }
        }
        if ($stopien -lt 0) { continue }

        $wynik.Ile++
        $kiedy = ConvertTo-JezykCzasLokalny $wiersz.LastActiveTime

        # Nizszy stopien bije kazda date; data rozstrzyga tylko w obrebie tego samego.
        $lepszy = ($null -eq $wynik.Wiersz) -or ($stopien -lt $najlepszy) -or
                  ($stopien -eq $najlepszy -and $null -ne $kiedy -and
                   ($null -eq $wynik.Data -or $kiedy -gt $wynik.Data))
        if (-not $lepszy) { continue }

        $wynik.Wiersz = $wiersz
        $wynik.Pole   = $nazwyPol[$stopien]
        $wynik.Data   = $kiedy
        $najlepszy    = $stopien
    }

    return $wynik
}

# Wiersze wpuszczone przez przesiew WQL, a odrzucone przez dopasowanie loginu: maszyna i niepuste pola kont.
# Uwaga: bez przecinka przy return - wolajacy owija wynik w @() (README: Kod > Jezyk-2-Logika).
function Get-JezykPodobneZapisy {
    param($Wiersze, $Pola)

    $opisy = New-Object System.Collections.Generic.List[string]

    foreach ($wiersz in @($Wiersze)) {
        if (-not $wiersz) { continue }

        # NetbiosName jest tylko w SMS_R_System; pozostale klasy oddaja samo Name.
        $nazwa = [string]$wiersz.NetbiosName
        if (-not $nazwa) { $nazwa = [string]$wiersz.Name }
        if (-not $nazwa) { continue }

        $wpisy = New-Object System.Collections.Generic.List[string]
        foreach ($nazwaPola in @($Pola)) {
            $wartosc = ([string]$wiersz.$nazwaPola).Trim()
            if (-not $wartosc) { continue }
            $wpis = '{0}: {1}' -f $nazwaPola, $wartosc
            $wpisy.Add($wpis)
        }

        # Pusty komplet to osobny sygnal: przesiew wiersz wpuscil, a pole nie przyszlo.
        $tresc = if ($wpisy.Count) { $wpisy -join '; ' } else { 'pola kont puste w odpowiedzi' }
        $opis  = '{0} - {1}' -f $nazwa, $tresc
        $opisy.Add($opis)
    }

    return $opisy.ToArray()
}

# Czy sesja z CurrentLogonUser trwa: CNIsOnline tej jednej maszyny, osobnym zapytaniem z wlasnym try.
# Uwaga: nieznana kolumna w glownym SELECT wywrocilaby cale szukanie (README: Ostatnio uzywany komputer).
function Get-JezykStanSesji {
    param($Sesja, [string]$Przestrzen, $ResourceID, [int]$LimitSek = 15)

    $wynik = [pscustomobject]@{ Trwa = $false; Opis = '' }

    # Do zapytania ida same liczby.
    $id = 0
    if (-not [int]::TryParse([string]$ResourceID, [ref]$id) -or $id -le 0) {
        $wynik.Opis = 'stanu klienta nie sprawdzono - brak identyfikatora maszyny w SCCM'
        return $wynik
    }

    try {
        foreach ($stan in @(Invoke-JezykZapytanieWmi -Sesja $Sesja -Przestrzen $Przestrzen -LimitSek $LimitSek `
                                -Zapytanie "SELECT ResourceId, CNIsOnline FROM SMS_CombinedDeviceResources WHERE ResourceId = $id")) {
            if ($stan -and $stan.CNIsOnline -eq $true) { $wynik.Trwa = $true }
        }
        if (-not $wynik.Trwa) {
            $wynik.Opis = 'konto jest w CurrentLogonUser, ale klient nie jest teraz online (CNIsOnline) - pokazana data ostatniej aktywności'
        }
    }
    catch { $wynik.Opis = 'stanu połączenia klienta (CNIsOnline) nie udało się odczytać: {0}' -f $_.Exception.Message }

    return $wynik
}

# Ostatnio uzywany komputer konta - z inwentaryzacji SCCM (AD nie wie, GDZIE), z sonda i adresem MAC.
function Get-JezykOstatnioUzywanyKomputer {
    param([string]$Login, [string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom',
          [bool]$ProtokolZapasowy = $false, [int]$LimitSek = 15)

    # Odpowiada i Adres wypelnia sonda na koncu, MAC po niej; $null w Odpowiada = nie wiadomo.
    # MacKarty to karty z adresem IPv4, MacWpisow - wszystkie wiersze (jedno nie wynika z drugiego).
    # ZalogowanyTeraz - SCCM widzi sesje konta na maszynie, ktora jest w tej chwili online.
    $wynik = [pscustomobject]@{ Nazwa = ''; Data = $null; Odpowiada = $null; Adres = ''
                                Blad = ''; Szczegoly = ''; ZalogowanyTeraz = $false
                                Wspoldzielony = $false; SzczegolyWspoldzielenia = ''
                                Mac = ''; MacSzczegoly = ''; MacPodstawa = ''
                                MacKarta = $null; MacKarty = @(); MacWpisow = 0 }

    # Zapytanie budowane z tekstu - login sprawdzany zawsze.
    if (-not (Test-JezykNazwaKonta $Login)) {
        $wynik.Blad      = 'nieprawidłowy login'
        $wynik.Szczegoly = 'Login "{0}" zawiera znaki spoza dozwolonego zestawu.' -f $Login
        return $wynik
    }

    $polaczenie = Get-JezykSccmPolaczenie -Serwer $Serwer -KodLokacji $KodLokacji -Protokol $Protokol
    if ($polaczenie.Blad) {
        $wynik.Blad      = 'brak ustawień SCCM'
        $wynik.Szczegoly = $polaczenie.Blad
        return $wynik
    }

    $przestrzen = 'root\sms\site_{0}' -f $polaczenie.KodLokacji

    # Apostrofy podwajamy mimo bialej listy wyzej - dwie niezalezne zapory zamiast jednej.
    $bezpieczny = $Login -replace "'", "''"

    $sesja = Open-JezykSesjaSccm -Serwer   $polaczenie.Serwer `
                                 -Protokol $polaczenie.Protokol `
                                 -Zapasowy $ProtokolZapasowy `
                                 -LimitSek $LimitSek
    if (-not $sesja.Sesja) {
        $wynik.Blad      = $sesja.Blad
        $wynik.Szczegoly = $sesja.Szczegoly
        return $wynik
    }

    # Jedna sesja na wszystko ponizej; finally ja zamyka - takze przy porzuceniu zadania.
    try {
        # Trzy zrodla, od najblizszego widokowi "Devices" w konsoli (README: Pytamy o to samo).
        # Wzorzec to tylko przesiew (bez ukosnika); login rozstrzyga Select-JezykMaszyneDlaLoginu.
        # Pole przesiewu musi byc w SELECT, inaczej dopasowanie nie ma czego czytac.
        $zrodla = @(
            @{ Nazwa = 'SMS_CombinedDeviceResources (widok "Devices" w konsoli)'
               Wql   = "SELECT ResourceID, Name, LastActiveTime, CurrentLogonUser, LastLogonUser, PrimaryUser " +
                       "FROM SMS_CombinedDeviceResources " +
                       "WHERE CurrentLogonUser LIKE '%$bezpieczny%' " +
                       "OR LastLogonUser LIKE '%$bezpieczny%' " +
                       "OR PrimaryUser LIKE '%$bezpieczny%'"
               Pola  = @('CurrentLogonUser', 'LastLogonUser', 'PrimaryUser') }

            @{ Nazwa = 'SMS_R_System.LastLogonUserName'
               Wql   = "SELECT ResourceId, Name, NetbiosName, LastLogonUserName FROM SMS_R_System " +
                       "WHERE LastLogonUserName LIKE '%$bezpieczny%'"
               Pola  = @('LastLogonUserName') }

            @{ Nazwa = 'SMS_G_System_COMPUTER_SYSTEM.UserName'
               Wql   = "SELECT ResourceID, Name, UserName FROM SMS_G_System_COMPUTER_SYSTEM " +
                       "WHERE UserName LIKE '%$bezpieczny%'"
               Pola  = @('UserName') }
        )

        $najlepsza     = $null
        $najData       = $null
        $poleTrafienia = ''
        $ileMaszyn     = 0
        $zrodlo        = ''
        $stos          = 'CIM'
        $odmowa        = $null
        $niedostepne   = @()
        $podobne       = @()

        foreach ($z in $zrodla) {
            $odp = Invoke-JezykZapytanieSccm -Sesja $sesja.Sesja -Serwer $polaczenie.Serwer `
                                             -Przestrzen $przestrzen -Zapytanie $z.Wql `
                                             -Protokol $sesja.Protokol -LimitSek $LimitSek

            if ($odp.Blad) {
                # Tylko brak klasy dotyczy jednego zrodla - wtedy szukamy dalej.
                if ($odp.Blad.Krotki -eq 'brak klasy w SCCM') {
                    $niedostepne += '{0}: {1}' -f $z.Nazwa, $odp.Blad.Krotki
                    continue
                }

                # Inny blad dotyczy calej przestrzeni albo sesji - dalsze zrodla odbilyby sie tak samo.
                $odmowa = $odp.Blad
                break
            }

            # Zrodlo trafione dopiero, gdy dopasowanie oddalo wiersz (przesiew jest szerszy od odpowiedzi).
            $trafienie = Select-JezykMaszyneDlaLoginu -Wiersze $odp.Wiersze -Login $Login -Pola $z.Pola
            if ($trafienie.Wiersz) {
                $najlepsza     = $trafienie.Wiersz
                $najData       = $trafienie.Data
                $poleTrafienia = $trafienie.Pole
                $ileMaszyn     = $trafienie.Ile
                $zrodlo        = $z.Nazwa
                $stos          = $odp.Stos
                break
            }

            # Bez trafienia kazdy zwrocony wiersz odpadl w dopasowaniu - pokazemy je pod "!".
            $podobne += @(Get-JezykPodobneZapisy -Wiersze $odp.Wiersze -Pola $z.Pola)
        }

        if ($odmowa) {
            $wynik.Blad      = $odmowa.Krotki
            $wynik.Szczegoly = $odmowa.Szczegoly
            return $wynik
        }

        if (-not $najlepsza) {
            $wynik.Blad      = 'brak w inwentaryzacji SCCM'
            $szczegolyBraku  = @(
                ('Połączenie z {0} działa (protokół {1}), przestrzeń {2} odpowiedziała - żadna maszyna nie raportuje loginu "{3}".' -f
                    $polaczenie.Serwer, $sesja.Protokol, $przestrzen, $Login),
                '',
                'Sprawdzone zostały: CurrentLogonUser, LastLogonUser i PrimaryUser w SMS_CombinedDeviceResources (to ta sama klasa, którą pokazuje węzeł "Devices" w konsoli), LastLogonUserName w SMS_R_System oraz UserName w SMS_G_System_COMPUTER_SYSTEM - każde z nich w obu zapisach, "konto" i "DOMENA\konto", oraz jako pozycja listy rozdzielonej przecinkami.'
            )
            if ($niedostepne.Count) {
                $szczegolyBraku += @('', ('Klasy, które nie odpowiedziały: {0}.' -f ($niedostepne -join '; ')))
            }

            # Co przesiew znalazl zamiast loginu - odroznia inne konto od maszyny, ktorej SCCM nie pokazuje.
            if ($podobne.Count) {
                $szczegolyBraku += @('', ('Przesiew znalazł zapisy podobne do "{0}", ale żaden nie jest tym kontem:' -f $Login))
                $szczegolyBraku += @($podobne | Select-Object -First 5 | ForEach-Object { '  ' + $_ })
                if ($podobne.Count -gt 5) { $szczegolyBraku += '  …i jeszcze {0}.' -f ($podobne.Count - 5) }
                $szczegolyBraku += @('', 'Jeśli któreś z tych kont należy do tej osoby (np. konto administracyjne), to nim loguje się ona na komputerze.')
            }
            else {
                $szczegolyBraku += @('',
                    ('Nawet przesiew (fragment "{0}" w dowolnym miejscu pola) nie znalazł żadnego rekordu. Możliwe przyczyny:' -f $Login),
                    ('- komputer tej osoby nie jest klientem lokacji {0} albo leży poza zakresem uprawnień operatora w ConfigMgr (takich rekordów SCCM nie pokazuje i nie zgłasza przy tym błędu),' -f $polaczenie.KodLokacji),
                    '- ta osoba pracuje na komputerze pod innym kontem niż wyszukane,',
                    '- po niej zalogował się na tym komputerze ktoś inny, a SCCM nie ma jej jako użytkownika głównego (PrimaryUser).')
            }
            $szczegolyBraku += @('', 'Kogo SCCM ma zapisanego na konkretnym komputerze, pokaże wyszukanie po nazwie komputera - pole "Ostatnio zalogowany użytkownik:".')

            $wynik.Szczegoly = $szczegolyBraku -join [Environment]::NewLine
            return $wynik
        }

        # Data aktywnosci jest dodatkiem: zrodla 2 i 3 jej nie znaja, wiec pytamy o jeden ResourceId.
        if ($null -eq $najData -and $najlepsza.ResourceID) {
            try {
                # ResourceId przez [int] - do zapytania trafiaja same liczby.
                $idAktywnosci = [int]$najlepsza.ResourceID
                if ($idAktywnosci -gt 0) {
                    foreach ($wpis in @(Invoke-JezykZapytanieWmi -Sesja $sesja.Sesja -Przestrzen $przestrzen -LimitSek $LimitSek `
                                            -Zapytanie (
                        "SELECT ResourceId, LastActiveTime FROM SMS_CombinedDeviceResources WHERE ResourceId = $idAktywnosci"))) {
                        $kiedy = ConvertTo-JezykCzasLokalny $wpis.LastActiveTime
                        if ($null -ne $kiedy) { $najData = $kiedy }
                    }
                }
            }
            catch { }
        }

        # NetbiosName jest tylko w SMS_R_System; droga zapasowa oddaje samo Name.
        $nazwa = $najlepsza.NetbiosName
        if (-not $nazwa) { $nazwa = $najlepsza.Name }
        $wynik.Nazwa = [string]$nazwa
        $wynik.Data  = $najData

        # Wspoldzielenie tylko dla pierwszego zrodla - tylko ono niesie pola kont.
        if ($zrodlo -eq $zrodla[0].Nazwa) {
            $konta = Get-JezykKontaMaszyny -Wiersz $najlepsza
            if ($konta.Count -gt 1) {
                $wynik.Wspoldzielony = $true
                $wynik.SzczegolyWspoldzielenia =
                    'SCCM zna na tej maszynie więcej niż jedno konto ({0}) - pokazana data i nazwa mogą dotyczyć innej osoby niż {1}.' -f
                        ($konta -join ', '), $Login
            }
        }

        # Sesja teraz: trafienie przez CurrentLogonUser i klient online - zamiast daty aktywnosci.
        $opisSesji = ''
        if ($poleTrafienia -eq 'CurrentLogonUser') {
            $stanSesji = Get-JezykStanSesji -Sesja $sesja.Sesja -Przestrzen $przestrzen `
                                            -ResourceID $najlepsza.ResourceID -LimitSek $LimitSek
            $wynik.ZalogowanyTeraz = $stanSesji.Trwa
            $opisSesji             = $stanSesji.Opis
        }

        # Sonda ICMP tutaj, w tle - na watku interfejsu zamrozilaby okno; wlasny try, bo to dodatek.
        $opisPingu = ''
        try {
            $ping = Get-JezykPingKomputera -Nazwa $wynik.Nazwa
            $wynik.Odpowiada = $ping.Odpowiada
            $wynik.Adres     = [string]$ping.Adres
            $opisPingu       = [string]$ping.Szczegoly
        }
        catch { $opisPingu = 'Sprawdzenie dostępności zawiodło: {0}' -f $_.Exception.Message }

        # Karta sieciowa po sondzie - dopasowanie potrzebuje adresu.
        Set-JezykMacWWyniku -Wynik $wynik -ResourceID $najlepsza.ResourceID -Sesja $sesja.Sesja `
                            -Przestrzen $przestrzen -LimitSek $LimitSek

        $opisWyniku = @('źródło: {0}; protokół: {1}; stos: {2}; serwer: {3}' -f
                        $zrodlo, $sesja.Protokol, $stos, $polaczenie.Serwer)
        if ($opisPingu) { $opisWyniku += $opisPingu }
        if ($opisSesji) { $opisWyniku += $opisSesji }
        if ($ileMaszyn -gt 1) {
            $opisWyniku += 'dopasowanych maszyn: {0}; pokazana ta z najświeższym śladem logowania (pole {1})' -f $ileMaszyn, $poleTrafienia
        }
        if ($niedostepne.Count) {
            $opisWyniku += 'klasy, które nie odpowiedziały: {0}' -f ($niedostepne -join '; ')
        }
        if ($null -eq $najData) {
            $opisWyniku += 'bez daty aktywności - klasa SMS_CombinedDeviceResources nie odpowiedziała albo nie ma do niej prawa'
        }
        $wynik.Szczegoly = $opisWyniku -join [Environment]::NewLine

        return $wynik
    }
    finally {
        try { Remove-CimSession -CimSession $sesja.Sesja -ErrorAction SilentlyContinue } catch { }
    }
}

# Droga odwrotna: kto ostatnio korzystal z maszyny (te same zrodla i sesja, filtr po nazwie maszyny).
# Uzytkownik tak, jak zapisal go SCCM; te same pola sondy i MAC co w drodze od loginu.
function Get-JezykUzytkownikKomputera {
    param([string]$Netbios, [string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom',
          [bool]$ProtokolZapasowy = $false, [int]$LimitSek = 15)

    # Pola MAC i stan sesji takie same jak po drugiej stronie okna - jedna sciezka wyswietlania.
    $wynik = [pscustomobject]@{ Uzytkownik = ''; Data = $null; Blad = ''; Szczegoly = ''
                                ZalogowanyTeraz = $false
                                Odpowiada = $null; Adres = ''; Mac = ''; MacSzczegoly = ''
                                MacPodstawa = ''; MacKarta = $null; MacKarty = @()
                                MacWpisow = 0 }

    # Zapytanie budowane z tekstu - nazwa sprawdzana zawsze.
    if (-not (Test-JezykNazwaKonta $Netbios)) {
        $wynik.Blad      = 'nieprawidłowa nazwa komputera'
        $wynik.Szczegoly = 'Nazwa "{0}" zawiera znaki spoza dozwolonego zestawu.' -f $Netbios
        return $wynik
    }

    # Sonda PRZED zapytaniem do SCCM - dostepnosc jest odpowiedzia w kazdej z pieciu drog powrotu.
    # Wlasny try: sonda jest dodatkiem.
    $opisPingu = ''
    try {
        $ping = Get-JezykPingKomputera -Nazwa $Netbios
        $wynik.Odpowiada = $ping.Odpowiada
        $wynik.Adres     = [string]$ping.Adres
        $opisPingu       = [string]$ping.Szczegoly
    }
    catch { $opisPingu = 'Sprawdzenie dostępności zawiodło: {0}' -f $_.Exception.Message }

    $polaczenie = Get-JezykSccmPolaczenie -Serwer $Serwer -KodLokacji $KodLokacji -Protokol $Protokol
    if ($polaczenie.Blad) {
        $wynik.Blad      = 'brak ustawień SCCM'
        $wynik.Szczegoly = $polaczenie.Blad
        return $wynik
    }

    $przestrzen = 'root\sms\site_{0}' -f $polaczenie.KodLokacji

    # Apostrofy podwajamy mimo bialej listy wyzej - dwie niezalezne zapory zamiast jednej.
    $bezpieczny = $Netbios -replace "'", "''"

    $sesja = Open-JezykSesjaSccm -Serwer   $polaczenie.Serwer `
                                 -Protokol $polaczenie.Protokol `
                                 -Zapasowy $ProtokolZapasowy `
                                 -LimitSek $LimitSek
    if (-not $sesja.Sesja) {
        $wynik.Blad      = $sesja.Blad
        $wynik.Szczegoly = $sesja.Szczegoly
        return $wynik
    }

    try {
        # Kolejnosc zrodel jak w drodze od loginu; pola od najswiezszego (sesja, ostatnie logowanie, przypisanie).
        $zrodla = @(
            @{ Nazwa = 'SMS_CombinedDeviceResources (widok "Devices" w konsoli)'
               Wql   = "SELECT ResourceID, Name, CurrentLogonUser, LastLogonUser, PrimaryUser, LastActiveTime " +
                       "FROM SMS_CombinedDeviceResources WHERE Name = '$bezpieczny'"
               Pola  = @('CurrentLogonUser', 'LastLogonUser', 'PrimaryUser') }

            @{ Nazwa = 'SMS_R_System.LastLogonUserName'
               Wql   = "SELECT ResourceID, Name, NetbiosName, LastLogonUserName FROM SMS_R_System " +
                       "WHERE NetbiosName = '$bezpieczny' OR Name = '$bezpieczny'"
               Pola  = @('LastLogonUserName') }

            @{ Nazwa = 'SMS_G_System_COMPUTER_SYSTEM.UserName'
               Wql   = "SELECT ResourceID, Name, UserName FROM SMS_G_System_COMPUTER_SYSTEM " +
                       "WHERE Name = '$bezpieczny'"
               Pola  = @('UserName') }
        )

        $uzytkownik  = ''
        $pole        = ''
        $zrodlo      = ''
        $stos        = 'CIM'
        $data        = $null
        $odmowa      = $null
        $niedostepne = @()
        $znaleziona  = $false
        # Wiersz tej maszyny - dla identyfikatora zasobu do zapytania o karty.
        $wierszMaszyny = $null
        # Wiersz, z ktorego wzieto uzytkownika - dla zapytania o stan sesji.
        $wierszUzytkownika = $null

        foreach ($z in $zrodla) {
            $odp = Invoke-JezykZapytanieSccm -Sesja $sesja.Sesja -Serwer $polaczenie.Serwer `
                                             -Przestrzen $przestrzen -Zapytanie $z.Wql `
                                             -Protokol $sesja.Protokol -LimitSek $LimitSek

            if ($odp.Blad) {
                # Tylko brak klasy dotyczy jednego zrodla.
                if ($odp.Blad.Krotki -eq 'brak klasy w SCCM') {
                    $niedostepne += '{0}: {1}' -f $z.Nazwa, $odp.Blad.Krotki
                    continue
                }
                $odmowa = $odp.Blad
                break
            }

            foreach ($wiersz in @($odp.Wiersze)) {
                if ($wiersz.Name -or $wiersz.NetbiosName) {
                    $znaleziona = $true
                    # Pierwszy wiersz maszyny - takze bez uzytkownika (karta sieciowa jest wtedy znana).
                    if (-not $wierszMaszyny) { $wierszMaszyny = $wiersz }
                }

                foreach ($nazwaPola in $z.Pola) {
                    $wartosc = ([string]$wiersz.$nazwaPola).Trim()
                    if ($wartosc) {
                        $uzytkownik = $wartosc
                        $pole       = $nazwaPola
                        break
                    }
                }

                if ($uzytkownik) {
                    $data              = ConvertTo-JezykCzasLokalny $wiersz.LastActiveTime
                    $wierszUzytkownika = $wiersz
                    break
                }
            }

            if ($uzytkownik) {
                $zrodlo = $z.Nazwa
                $stos   = $odp.Stos
                break
            }
        }

        if ($odmowa) {
            $wynik.Blad      = $odmowa.Krotki
            $wynik.Szczegoly = $odmowa.Szczegoly
            return $wynik
        }

        # Karta sieciowa: nie po odmowie (powtorzylaby ja), ale takze przy braku zapisanego uzytkownika.
        # Maszyna nieznana w SCCM zostaje bez dopasowania - pole mowi wtedy "nie sprawdzono".
        if ($wierszMaszyny) {
            Set-JezykMacWWyniku -Wynik $wynik -ResourceID $wierszMaszyny.ResourceID `
                                -Sesja $sesja.Sesja -Przestrzen $przestrzen -LimitSek $LimitSek
        }

        if (-not $uzytkownik) {
            # Maszyna bez zapisanego uzytkownika a maszyna nieznana - dwie rozne odpowiedzi.
            $wynik.Blad = if ($znaleziona) { 'brak zapisanego użytkownika' }
                          else             { 'brak w inwentaryzacji SCCM' }

            $szczegolyBraku = @(
                ('Połączenie z {0} działa (protokół {1}), przestrzeń {2} odpowiedziała.' -f
                    $polaczenie.Serwer, $sesja.Protokol, $przestrzen),
                '',
                $(if ($znaleziona) {
                    'Maszyna "{0}" jest w inwentaryzacji, ale żadne z pól CurrentLogonUser, LastLogonUser, PrimaryUser, LastLogonUserName ani UserName nie ma wartości - klient jeszcze nie zameldował logowania.' -f $Netbios
                } else {
                    'Żaden rekord nie opisuje maszyny o nazwie "{0}". Sprawdzone zostały SMS_CombinedDeviceResources (to ta sama klasa, którą pokazuje węzeł "Devices" w konsoli), SMS_R_System oraz SMS_G_System_COMPUTER_SYSTEM.' -f $Netbios
                })
            )
            if ($niedostepne.Count) {
                $szczegolyBraku += @('', ('Klasy, które nie odpowiedziały: {0}.' -f ($niedostepne -join '; ')))
            }
            # Wynik sondy bywa tu jedyna odpowiedzia - pelne zdanie trafia do szczegolow.
            if ($opisPingu) { $szczegolyBraku += @('', $opisPingu) }
            $wynik.Szczegoly = $szczegolyBraku -join [Environment]::NewLine
            return $wynik
        }

        $wynik.Uzytkownik = $uzytkownik
        $wynik.Data       = $data

        # Sesja teraz - tylko gdy uzytkownika dalo pole CurrentLogonUser.
        $opisSesji = ''
        if ($pole -eq 'CurrentLogonUser' -and $wierszUzytkownika) {
            $stanSesji = Get-JezykStanSesji -Sesja $sesja.Sesja -Przestrzen $przestrzen `
                                            -ResourceID $wierszUzytkownika.ResourceID -LimitSek $LimitSek
            $wynik.ZalogowanyTeraz = $stanSesji.Trwa
            $opisSesji             = $stanSesji.Opis
        }

        $opisWyniku = @('źródło: {0} (pole {1}); protokół: {2}; stos: {3}; serwer: {4}' -f
                        $zrodlo, $pole, $sesja.Protokol, $stos, $polaczenie.Serwer)
        if ($opisPingu) { $opisWyniku += $opisPingu }
        if ($opisSesji) { $opisWyniku += $opisSesji }
        if ($niedostepne.Count) {
            $opisWyniku += 'klasy, które nie odpowiedziały: {0}' -f ($niedostepne -join '; ')
        }
        $wynik.Szczegoly = $opisWyniku -join [Environment]::NewLine

        return $wynik
    }
    finally {
        try { Remove-CimSession -CimSession $sesja.Sesja -ErrorAction SilentlyContinue } catch { }
    }
}

# Login z okna logowania z jawna domena: bez domeny - domena odblokowania (inaczej wybiera ja Windows).
# DOMENA\login i login@domena bez zmian; pusty albo niepelny - pusty napis.
function ConvertTo-JezykLoginZDomena {
    param([string]$Login, [string]$Domena)

    # Wiodacy ukosnik w zapisie DOMENA\login znaczy "bez domeny".
    $tekst = ([string]$Login).Trim().TrimStart('\').Trim()
    if (-not $tekst) { return '' }
    if ($tekst -match '[\x00-\x1F]') { return '' }

    if ($tekst -match '^[^\\@]+$') {
        if (-not $Domena) { return $tekst }
        return ('{0}\{1}' -f $Domena, $tekst)
    }
    if ($tekst -match '^[^\\@]+\\[^\\@]+$' -or $tekst -match '^[^\\@]+@[^\\@]+$') { return $tekst }
    return ''
}

# Kod Windows odmowy logowania kontem z okna (1326 zle haslo, 1909 blokada...) albo 0 - to inna awaria.
# Po typie i kodzie w calym lancuchu wyjatkow, nie po tresci - tresc zalezy od jezyka systemu.
function Get-JezykKodOdmowyLogowania {
    param($Wyjatek)

    # Win32, NTSTATUS i SEC_E_LOGON_DENIED sprowadzone do kodu, ktory okno logowania umie opisac.
    $odmowy = @{
        1326 = 1326; 1317 = 1326; 1909 = 1909; 1331 = 1331; 1330 = 1330; 1907 = 1907
        1793 = 1793; 1327 = 1327; 1328 = 1328; 1329 = 1329
        0x8009030C = 1326; 0xC000006D = 1326; 0xC000006A = 1326; 0xC0000064 = 1326
        0xC0000234 = 1909; 0xC0000072 = 1331; 0xC0000071 = 1330; 0xC0000224 = 1907
        0xC0000193 = 1793; 0xC000006E = 1327; 0xC000006F = 1328; 0xC0000070 = 1329
    }

    $biezacy   = if ($Wyjatek -and $Wyjatek.PSObject.Properties['Exception']) { $Wyjatek.Exception } else { $Wyjatek }
    $odmowa    = $false
    $glebokosc = 0
    while ($biezacy -is [System.Exception] -and $glebokosc -lt 16) {
        if ($biezacy.GetType().Name -in 'AuthenticationException', 'InvalidCredentialException') { $odmowa = $true }

        # Pola przez PSObject.Properties - typy wyjatkow modulu AD nie istnieja bez RSAT.
        foreach ($pole in 'NativeErrorCode', 'ErrorCode', 'HResult') {
            $wlasciwosc = $biezacy.PSObject.Properties[$pole]
            if (-not $wlasciwosc) { continue }
            $wartosc = $wlasciwosc.Value -as [int64]
            if ($null -eq $wartosc) { continue }
            # Kod 32-bitowy zapisany bez znaku - na int, tak jak trzyma go HResult.
            if ($wartosc -gt [int]::MaxValue) { $wartosc -= 4294967296 }
            if ($wartosc -lt [int]::MinValue) { continue }
            $kod = [int]$wartosc
            # HRESULT bledu Win32 (0x8007xxxx) niesie sam kod Win32.
            if (($kod -band 0xFFFF0000) -eq 0x80070000) { $kod = $kod -band 0xFFFF }
            if ($odmowy.ContainsKey($kod)) { return $odmowy[$kod] }
        }

        $biezacy = $biezacy.InnerException
        $glebokosc++
    }

    if ($odmowa) { return 1326 }
    return 0
}

# Stan konta z okna logowania po odmowie - odczyt kontem operatora, wiec bez kolejnej proby hasla.
# Tylko DOMENA\login z domeny odblokowania; inaczej Stan pusty i zostaje kod z wyjatku.
function Get-JezykStanKontaZOkna {
    param([string]$Login, [string]$Domena, [string]$Serwer)

    $wynik = [pscustomobject]@{ Domena = ''; Stan = ''; Opis = '' }

    $tekst = ([string]$Login).Trim()
    $nazwa = ''
    if ($tekst -match '^([^\\@]+)\\([^\\@]+)$')  { $wynik.Domena = $Matches[1]; $nazwa = $Matches[2] }
    elseif ($tekst -match '^[^\\@]+@([^\\@]+)$') { $wynik.Domena = $Matches[1] }

    # UPN, inna domena albo nazwa spoza bialej listy - tego konta nie ma u tego kontrolera pod ta nazwa.
    if (-not $nazwa -or $wynik.Domena -ne $Domena -or -not (Test-JezykNazwaKonta $nazwa)) { return $wynik }
    if (-not (Test-JezykNazwaHosta $Serwer)) { return $wynik }

    try {
        $konto = Get-ADUser -Identity $nazwa -Server $Serwer -Properties LockedOut, Enabled, badPwdCount `
                            -ErrorAction Stop

        if ($konto.LockedOut)              { $wynik.Stan = 'Zablokowane' }
        elseif ($konto.Enabled -eq $false) { $wynik.Stan = 'Wylaczone' }
        else                               { $wynik.Stan = 'Aktywne' }

        $proby  = if ($null -ne $konto.badPwdCount) { [string]$konto.badPwdCount } else { 'nieznana' }
        $blokada = if ($konto.LockedOut) { 'tak' } else { 'nie' }
        $wynik.Opis = 'Stan tego konta wg kontrolera {0} (odczyt kontem, na którym działa Jeżyk): nieudanych prób z rzędu: {1}; zablokowane: {2}.' -f
                      $Serwer, $proby, $blokada
    }
    catch {
        # Uwaga: typ wyjatku po nazwie, nie "catch [Typ]" - bez RSAT plik nie przeszedlby parsowania.
        if ($_.Exception.GetType().Name -eq 'ADIdentityNotFoundException') {
            $wynik.Stan = 'BrakKonta'
            $wynik.Opis = 'W domenie {0} nie ma konta o nazwie podanej w oknie logowania.' -f $Domena
        }
        else {
            $pierwsza = [string]$_.Exception.Message -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1
            $wynik.Opis = 'Stanu tego konta nie udało się odczytać: {0}' -f $pierwsza
        }
    }

    return $wynik
}

# Jedno zdanie do Status o odmowie logowania kontem z okna - z domena tego konta, bez loginu (README: Bezpieczenstwo).
function Get-JezykOpisOdmowyLogowania {
    param([int]$Kod, [string]$Stan = '', [string]$Domena = '', [string]$Konto = '')

    $skutek = 'konto "{0}" nie zostało odblokowane.' -f $Konto
    $ktore  = if ($Domena) { 'Konto z okna logowania (domena {0})' -f $Domena } else { 'Konto z okna logowania' }

    if ($Stan -eq 'BrakKonta') {
        return ('W domenie {0} nie ma konta o nazwie podanej w oknie logowania - {1}' -f $Domena, $skutek)
    }

    switch ($Kod) {
        1909 { return ('{0} jest zablokowane - {1}' -f $ktore, $skutek) }
        1331 { return ('{0} jest wyłączone - {1}' -f $ktore, $skutek) }
        1330 { return ('{0} ma wygasłe hasło - {1}' -f $ktore, $skutek) }
        1907 { return ('{0} musi najpierw zmienić hasło - {1}' -f $ktore, $skutek) }
        1793 { return ('{0} wygasło - {1}' -f $ktore, $skutek) }
        { $_ -in 1327, 1328, 1329 } {
            return ('{0} nie może się teraz zalogować (ograniczenie godzin, stacji albo zasad konta) - {1}' -f $ktore, $skutek)
        }
    }

    $gdzie = if ($Domena) { ' (domena {0})' -f $Domena } else { '' }
    return ('Nieprawidłowa nazwa użytkownika lub hasło w oknie logowania{0} - {1}' -f $gdzie, $skutek)
}

# Odblokowuje konto w AD - jedna z dwoch drog zapisu; uprawnienie sprawdzane takze tutaj.
# Nie rzuca: odmowa uprawnien to zwykla odpowiedz AD (README: Odblokowanie konta).
# Haslo z okna idzie do JEDNEGO uwierzytelnienia; odmowa logowania to KodLogowania, nigdy powtorka.
function Unlock-JezykKonto {
    param([string]$Login, [string]$Domena,
          [System.Management.Automation.PSCredential]$Poswiadczenia)

    # Serwer = kontroler, ktory przyjal zapis - wolajacy czyta z niego konto od nowa.
    # KodLogowania - kod Windows odmowy logowania kontem z okna (0 - nie dotyczy); okno pyta wtedy od nowa.
    $wynik = [pscustomobject]@{ Udane = $false; Komunikat = ''; Szczegoly = ''; Serwer = ''; KodLogowania = 0 }

    # Najpierw ksztalt danych, potem uprawnienie.
    if (-not (Test-JezykNazwaKonta $Login)) {
        $wynik.Komunikat = 'Nieprawidłowa nazwa konta - odblokowanie przerwane.'
        return $wynik
    }

    if (-not (Test-JezykNazwaHosta $Domena)) {
        $wynik.Komunikat = 'Nieprawidłowa nazwa domeny - odblokowanie przerwane.'
        return $wynik
    }

    if (-not (Test-JezykWolnoOdblokowac $Domena)) {
        $wynik.Komunikat = 'Odblokowanie nie jest dozwolone w domenie {0}.' -f $Domena
        return $wynik
    }

    # Puste haslo nie idzie do kontrolera - nieudana proba liczylaby sie do blokady konta z okna.
    if ($Poswiadczenia -and $Poswiadczenia.Password.Length -eq 0) {
        $wynik.KodLogowania = 1326
        $wynik.Komunikat    = 'Nie podano hasła - konto "{0}" nie zostało odblokowane.' -f $Login
        return $wynik
    }

    $parametry = $null
    $serwer    = $Domena
    try {
        # Emulator ustalany kontem operatora - haslo z okna nie idzie do zadnego innego wywolania.
        $serwer = Get-JezykSerwerDoZapisu -Domena $Domena

        # Poswiadczenia warunkowo - bez nich zapis idzie kontem, na ktorym dziala Jezyk.
        $parametry = @{ Identity = $Login; Server = $serwer; Confirm = $false; ErrorAction = 'Stop' }
        if ($Poswiadczenia) { $parametry['Credential'] = $Poswiadczenia }

        Unlock-ADAccount @parametry

        $wynik.Udane     = $true
        $wynik.Serwer    = $serwer
        $wynik.Komunikat = 'Konto "{0}" w domenie "{1}" zostało pomyślnie odblokowane.' -f $Login, $Domena
        $wynik.Szczegoly = 'Zapis przyjął kontroler: {0}{1}Po odblokowaniu widok został odczytany od nowa z tego samego kontrolera - dzięki temu nie pokazuje stanu sprzed zapisu.' -f
                           $serwer, ([Environment]::NewLine + [Environment]::NewLine)
    }
    catch {
        # Odmowa to spodziewana odpowiedz (prawo odblokowania jest osobne) - trafia do pola Status.
        $blad = $_
        $opis = Get-JezykOpisBledu $blad ('Odblokowanie konta {0}' -f $Login)
        $wynik.Komunikat = $opis.Krotki
        $wynik.Szczegoly = $opis.Szczegoly

        # Odmowa logowania kontem z okna: powod z wyjatku, uscislony stanem tego konta.
        $kod = if ($Poswiadczenia) { Get-JezykKodOdmowyLogowania $blad } else { 0 }
        if ($kod) {
            $stan = Get-JezykStanKontaZOkna -Login $Poswiadczenia.UserName -Domena $Domena -Serwer $serwer
            if ($stan.Stan -eq 'Zablokowane')   { $kod = 1909 }
            elseif ($stan.Stan -eq 'Wylaczone') { $kod = 1331 }

            $wynik.KodLogowania = $kod
            $wynik.Komunikat    = Get-JezykOpisOdmowyLogowania -Kod $kod -Stan $stan.Stan -Domena $stan.Domena -Konto $Login

            $linie = @('Kontroler odrzucił logowanie kontem podanym w oknie - nic nie zostało zapisane.',
                       'Każda nieudana próba liczy się do blokady tego konta w jego domenie.')
            if ($stan.Opis) { $linie += $stan.Opis }
            $linie += @('', $opis.Szczegoly)
            $wynik.Szczegoly = $linie -join [Environment]::NewLine
        }
    }
    finally {
        if ($parametry) { $parametry.Clear() }

        # Uwaga: $Error trzyma obiekt poswiadczen (BoundParameters) - czyscimy cala liste.
        $Error.Clear()
    }

    return $wynik
}

# Czy w tej domenie wolno odblokowywac (jedno miejsce decyzji; pusta lista = nigdzie).
function Test-JezykWolnoOdblokowac {
    param([string]$Domena)
    if (-not $Domena) { return $false }
    return (@($Script:DomenyZOdblokowaniem) -contains $Domena.ToLower())
}

# Czy w tej domenie wolno zarzadzac czlonkostwem grup (oba kierunki; lista osobna od odblokowania).
function Test-JezykWolnoZarzadzacGrupami {
    param([string]$Domena)
    if (-not $Domena) { return $false }
    return (@($Script:DomenyZZarzadzaniemGrupami) -contains $Domena.ToLower())
}

# Czy SCCM zna konta i komputery tej domeny - jedna decyzja dla zapytan i dla ukladu okna.
function Test-JezykDomenaZSccm {
    param([string]$Domena)
    if (-not $Domena) { return $false }
    return (@($Script:DomenyZSccm) -contains $Domena.ToLower())
}

# Kontroler dla zapisu (obu drog): emulator PDC - autorytet blokad i nigdy kontroler tylko do odczytu.
# Zawsze kontem operatora. Rozpoznanie opcjonalne: przy niepowodzeniu nazwa domeny (catch z nazwana wartoscia zapasowa).
function Get-JezykSerwerDoZapisu {
    param([string]$Domena)

    $odczyt = @{ Identity = $Domena; Server = $Domena; ErrorAction = 'Stop' }
    try {
        $emulator = (Get-ADDomain @odczyt).PDCEmulator
        if ($emulator -and (Test-JezykNazwaHosta $emulator)) { return $emulator }
    }
    catch { }
    finally { $odczyt.Clear() }

    return $Domena
}

# Oslona metaznakow RFC 4515 we frazie do filtra LDAP - odwrotny ukosnik PIERWSZY.
# Bez bialej listy (nazwy grup maja spacje i nawiasy) - zapis i tak idzie po DN z katalogu.
function Get-JezykFrazaLdap {
    param([string]$Tekst)

    $fraza = ([string]$Tekst).Trim()
    if (-not $fraza) { return '' }
    # 256 - duzo powyzej dlugosci nazwy grupy.
    if ($fraza.Length -gt 256) { return '' }
    if ($fraza -match '[\x00-\x1F]') { return '' }

    $fraza = $fraza.Replace('\', '\5c')
    $fraza = $fraza.Replace('*', '\2a')
    $fraza = $fraza.Replace('(', '\28')
    $fraza = $fraza.Replace(')', '\29')
    return $fraza
}

# "Sprawdz nazwy": (anr=...) po indeksie, a gdy pusto - (cn=*...*) dla fragmentu w srodku nazwy.
# Strone konczy -ResultPageSize = limit + 1; Przerwane i ZaDuzo osobno od pustego wyniku.
function Find-JezykGrupyPoNazwie {
    param([string]$Fraza, [int]$Limit, [string]$Serwer)

    $wynik = [pscustomobject]@{ Trafienia = @(); ZaDuzo = $false; Przerwane = $false; Powod = '' }

    $szukana = Get-JezykFrazaLdap $Fraza
    if (-not $szukana) { return $wynik }
    if ($Limit -lt 1)  { return $wynik }

    # Uwaga: napisy do zmiennych - w argumencie metody przecinek nalezy do metody, nie do -f.
    $filtrAnr = '(anr={0})' -f $szukana
    $filtrCn  = '(cn=*{0}*)' -f $szukana

    foreach ($filtr in @($filtrAnr, $filtrCn)) {
        # Limit + 1 odroznia "dokladnie tyle" od "wiecej".
        $zapytanie = @{ LDAPFilter = $filtr; Properties = 'Name'
                        ResultPageSize = ($Limit + 1); ResultSetSize = ($Limit + 1)
                        ErrorAction = 'Stop' }
        if ($Serwer) { $zapytanie['Server'] = $Serwer }

        try {
            $znalezione = @(Get-ADGroup @zapytanie)
        }
        catch {
            $opis = Get-JezykOpisBledu $_ 'Szukanie grupy w AD'
            $wynik.Przerwane = $true
            $wynik.Powod     = $opis.Krotki
            return $wynik
        }

        $pozycje = @()
        foreach ($grupa in $znalezione) {
            $nazwa = [string]$grupa.Name
            $dn    = [string]$grupa.DistinguishedName
            # Pozycja bez nazwy albo bez DN odpada (okno wyboru numeruje po Get-JezykParyGrup).
            if (-not $nazwa -or -not $dn) { continue }
            $pozycje += [pscustomobject]@{ Nazwa = $nazwa; Dn = $dn }
        }

        if ($pozycje.Count -eq 0) { continue }

        if ($pozycje.Count -gt $Limit) {
            $wynik.ZaDuzo = $true
            $pozycje      = @($pozycje[0..($Limit - 1)])
        }
        # Podpisy liczone na liscie po przycieciu - tej, ktora zobaczy operator.
        $wynik.Trafienia = @(Get-JezykPodpisyGrup $pozycje)
        return $wynik
    }

    return $wynik
}

# Dopisuje konto do grupy albo z niej usuwa - druga droga zapisu, jedna funkcja na oba kierunki.
# Grupe wskazuje DN z katalogu; zapis kontem operatora, uprawnienie sprawdzane takze tutaj.
function Set-JezykCzlonkostwoGrupy {
    param([string]$Login, [string]$Dn, [string]$GrupaDn, [string]$Domena,
          [ValidateSet('Dodaj', 'Usun')][string]$Akcja = 'Dodaj')

    # Ten sam ksztalt, co Unlock-JezykKonto - okno renderuje oba wyniki jedna droga.
    # KodLogowania zawsze 0: zapis idzie kontem operatora, bez okna logowania.
    $wynik = [pscustomobject]@{ Udane = $false; Komunikat = ''; Szczegoly = ''; Serwer = ''; KodLogowania = 0 }

    # Nazwa czynnosci skladana RAZ, zeby kazda galaz mowila o tej samej rzeczy.
    $czynnosc = if ($Akcja -eq 'Usun') { 'usunięcie z grupy' } else { 'dodanie do grupy' }

    # Najpierw ksztalt danych, potem uprawnienie.
    if (-not (Test-JezykNazwaKonta $Login)) {
        $wynik.Komunikat = 'Nieprawidłowa nazwa konta - {0} przerwane.' -f $czynnosc
        return $wynik
    }

    if (-not (Test-JezykNazwaHosta $Domena)) {
        $wynik.Komunikat = 'Nieprawidłowa nazwa domeny - {0} przerwane.' -f $czynnosc
        return $wynik
    }

    if (-not (Test-JezykDn $GrupaDn)) {
        $wynik.Komunikat = 'Nieprawidłowa nazwa wyróżniająca grupy - {0} przerwane.' -f $czynnosc
        return $wynik
    }

    if (-not (Test-JezykWolnoZarzadzacGrupami $Domena)) {
        $wynik.Komunikat = 'Zarządzanie grupami nie jest dozwolone w domenie {0}.' -f $Domena
        return $wynik
    }

    try {
        $serwer = Get-JezykSerwerDoZapisu -Domena $Domena

        # Konto po DN (jednoznaczny), a login jako droga zapasowa.
        $czlonek = if (Test-JezykDn $Dn) { $Dn } else { $Login }

        $parametry = @{ Identity = $GrupaDn; Members = $czlonek; Server = $serwer
                        Confirm = $false; ErrorAction = 'Stop' }

        if ($Akcja -eq 'Usun') { Remove-ADGroupMember @parametry }
        else                   { Add-ADGroupMember    @parametry }

        $wynik.Udane  = $true
        $wynik.Serwer = $serwer

        # Komunikat nazywa grupe z DN, ktory naprawde poszedl do zapisu (z folderem).
        $grupa  = '"{0}"' -f (Get-JezykNazwaZDn $GrupaDn)
        $folder = Get-JezykFolderAd $GrupaDn
        if ($folder) { $grupa = '{0} ({1})' -f $grupa, $folder }
        $wynik.Komunikat = if ($Akcja -eq 'Usun') {
            'Konto "{0}" zostało usunięte z grupy {1}.' -f $Login, $grupa
        } else {
            'Konto "{0}" zostało dodane do grupy {1}.' -f $Login, $grupa
        }
        $wynik.Szczegoly = 'Zapis przyjął kontroler: {0}' -f $serwer
    }
    catch {
        # Odmowa i "konto juz jest w grupie" to odpowiedzi, nie awarie.
        $czego = if ($Akcja -eq 'Usun') { 'Usunięcie konta {0} z grupy' } else { 'Dodanie konta {0} do grupy' }
        $opis  = Get-JezykOpisBledu $_ ($czego -f $Login)
        $wynik.Komunikat = $opis.Krotki
        $wynik.Szczegoly = $opis.Szczegoly
    }

    return $wynik
}

# Grupy konta (pary nazwa + DN) z kontrolera zapisu; nieudany odczyt nie uniewaznia zapisu.
function Get-JezykGrupyKonta {
    param([string]$Login, [string]$Serwer)

    $wynik = [pscustomobject]@{ Grupy = @(); Udane = $false; Szczegoly = '' }

    if (-not (Test-JezykNazwaKonta $Login)) {
        $wynik.Szczegoly = 'Nieprawidłowa nazwa konta - grup nie odczytano.'
        return $wynik
    }

    $zapytanie = @{ Identity = $Login; Properties = 'MemberOf'; ErrorAction = 'Stop' }
    if ($Serwer -and (Test-JezykNazwaHosta $Serwer)) { $zapytanie['Server'] = $Serwer }

    try {
        $konto = Get-ADUser @zapytanie
        $wynik.Grupy = @(Get-JezykCzlonkostwaGrup $konto.MemberOf)
        $wynik.Udane = $true
    }
    catch {
        $opis = Get-JezykOpisBledu $_ ('Odczyt grup konta {0}' -f $Login)
        $wynik.Szczegoly = $opis.Szczegoly
    }

    return $wynik
}

# Podpis przelozonego z DN: "Jan Kowalski (jkowalski)"; przy bledzie odczytu - CN z DN.
# Wlasny try: przelozony z innej domeny albo usuniety nie psuje odczytu konta.
function Get-JezykPodpisMenedzera {
    param([string]$Dn, [string]$Serwer = '')

    if ($null -eq $Dn) { $Dn = '' }
    $Dn = $Dn.Trim()
    if (-not $Dn) { return '' }

    # Zapasowy podpis przed zapytaniem - gotowy takze wtedy, gdy odczyt nie dojdzie do skutku.
    $zapasowy = ''
    if ($Dn -match '^\s*CN=((?:[^,\\]|\\.)+)') { $zapasowy = ($Matches[1] -replace '\\(.)', '$1').Trim() }

    # DN idzie do -Identity, wiec sprawdzamy go tak samo jak przed sklejeniem sciezki LDAP.
    if (-not (Test-JezykDn $Dn)) { return $zapasowy }

    try {
        $adres = if ($Serwer) { $Serwer } else { $Script:Config.Domena }

        $szef = Get-ADUser -Identity $Dn -Server $adres `
                           -Properties DisplayName, GivenName, Surname `
                           -ErrorAction Stop

        $nazwa = Get-JezykOsoba ([string]$szef.DisplayName) ([string]$szef.GivenName) ([string]$szef.Surname)
        $login = [string]$szef.SamAccountName

        # Bez nazwy wyswietlanej - sam login, bez pustych nawiasow.
        if (-not $nazwa) { return $login }
        if (-not $login) { return $nazwa }
        return '{0} ({1})' -f $nazwa, $login
    }
    catch { return $zapasowy }
}

# Nazwa obiektu z DN: pierwszy czlon bez "CN=" i bez oslon przecinkow; zapis bez CN= oddany w calosci.
function Get-JezykNazwaZDn {
    param([string]$Dn)

    $tekst = ([string]$Dn).Trim()
    if ($tekst -match '^\s*CN=((?:[^,\\]|\\.)+)') {
        return ($Matches[1] -replace '\\(.)', '$1').Trim()
    }
    return $tekst
}

# Folder obiektu z DN, jak w konsoli AD ("jezyk.pl/Warszawa/Grupy") - bez zapytania do AD.
function Get-JezykFolderAd {
    param([string]$Dn)

    $czlony = @([regex]::Matches(([string]$Dn).Trim(), '(?:[^,\\]|\\.)+') |
                ForEach-Object { $_.Value.Trim() })
    if ($czlony.Count -lt 2) { return '' }

    $domena  = @()
    $foldery = @()
    foreach ($czlon in $czlony[1..($czlony.Count - 1)]) {
        if ($czlon -notmatch '^([A-Za-z0-9.-]+)\s*=(.*)$') { return '' }
        $wartosc = ($Matches[2] -replace '\\(.)', '$1').Trim()
        if ($Matches[1] -eq 'DC') { $domena += $wartosc; continue }
        # Nazwa wyrozniajaca idzie od obiektu w gore, a folder - od gory w dol.
        $foldery = @($wartosc.Replace('/', '\/')) + $foldery
    }

    $czesci = @()
    if ($domena.Count -gt 0) { $czesci += ($domena -join '.') }
    $czesci += $foldery
    return ($czesci -join '/')
}

# Podpisy par grup: sama nazwa, a przy nazwie powtorzonej na liscie - nazwa z folderem AD.
# Liczone raz, na calej liscie z AD (nie po filtrze); porownanie bez wielkosci liter.
function Get-JezykPodpisyGrup {
    param([object[]]$Grupy)

    $ile = @{}
    foreach ($grupa in @($Grupy)) {
        if (-not $grupa) { continue }
        $klucz = ([string]$grupa.Nazwa).Trim()
        $ile[$klucz] = 1 + [int]$ile[$klucz]
    }

    $wynik = @()
    foreach ($grupa in @($Grupy)) {
        if (-not $grupa) { continue }
        $nazwa  = ([string]$grupa.Nazwa).Trim()
        $dn     = ([string]$grupa.Dn).Trim()
        $podpis = $nazwa
        if ($ile[$nazwa] -gt 1) {
            $folder = Get-JezykFolderAd $dn
            if ($folder) { $podpis = '{0} ({1})' -f $nazwa, $folder }
        }
        $wynik += [pscustomobject]@{ Nazwa = $nazwa; Dn = $dn; Podpis = $podpis }
    }

    # Wolajacy owija wynik w @() - PowerShell rozwija tablice oddawana z funkcji.
    return @($wynik)
}

# memberOf na pary "nazwa + DN" z podpisem, posortowane - bez zapytan do AD (nazwa siedzi w DN).
function Get-JezykCzlonkostwaGrup {
    param($Czlonkostwa)

    $pary = @()
    foreach ($dn in @($Czlonkostwa)) {
        $tekst = ([string]$dn).Trim()
        if (-not $tekst) { continue }

        # Nazwa z pierwszego czlonu DN - bez zapytania o kazda grupe.
        $nazwa = Get-JezykNazwaZDn $tekst
        if (-not $nazwa) { continue }

        $pary += [pscustomobject]@{ Nazwa = $nazwa; Dn = $tekst }
    }

    # Uwaga: odsiew powtorzen po DN, nie po nazwie - CN jest unikalny tylko w kontenerze
    # (README: Grupy o tej samej nazwie). Kolejnosc ustalana tylko tutaj; wolajacy owija wynik w @().
    $unikalne = @($pary | Sort-Object -Property Dn -Unique)
    return @(Get-JezykPodpisyGrup $unikalne | Sort-Object -Property Nazwa, Podpis)
}

# Sprowadza liste grup do par nazwa + DN + podpis (przyjmuje pary albo same nazwy); odsiewa puste.
# Podpis tylko jedzie - liczony tu zalezalby od filtra.
function Get-JezykParyGrup {
    param([object[]]$Grupy)

    $pary = @()
    foreach ($grupa in @($Grupy)) {
        if (-not $grupa) { continue }

        if ($grupa -is [string]) {
            $nazwa = ([string]$grupa).Trim()
            if ($nazwa) { $pary += [pscustomobject]@{ Nazwa = $nazwa; Dn = ''; Podpis = $nazwa } }
            continue
        }

        $nazwa = ([string]$grupa.Nazwa).Trim()
        if (-not $nazwa) { continue }
        $podpis = ([string]$grupa.Podpis).Trim()
        if (-not $podpis) { $podpis = $nazwa }
        $pary += [pscustomobject]@{ Nazwa = $nazwa; Dn = ([string]$grupa.Dn).Trim(); Podpis = $podpis }
    }

    return @($pary)
}

# Wlasciciel obiektu AD ("DOMENA\konto") jako podpis. Osoba: $true osoba, $false grupa albo SID,
# $null - wlasciciela nie bylo (deskryptor nieodczytany).
function Get-JezykPodpisWlasciciela {
    param([string]$Wlasciciel, [string]$Serwer = '')

    if ($null -eq $Wlasciciel) { $Wlasciciel = '' }
    $Wlasciciel = $Wlasciciel.Trim()
    if (-not $Wlasciciel) { return [pscustomobject]@{ Podpis = ''; Osoba = $null } }

    # Czesc za ostatnim ukosnikiem; goly SID idzie w calosci (AD przyjmuje SID jako tozsamosc).
    $login = $Wlasciciel.Substring($Wlasciciel.LastIndexOf('\') + 1)

    if (-not (Test-JezykNazwaKonta $login)) {
        return [pscustomobject]@{ Podpis = $Wlasciciel; Osoba = $false }
    }

    try {
        $adres = if ($Serwer) { $Serwer } else { $Script:Config.Domena }

        $konto = Get-ADUser -Identity $login -Server $adres `
                            -Properties DisplayName, GivenName, Surname `
                            -ErrorAction Stop

        $nazwa = Get-JezykOsoba ([string]$konto.DisplayName) ([string]$konto.GivenName) ([string]$konto.Surname)

        # Bez nazwy wyswietlanej - sam login.
        $podpis = if ($nazwa) { '{0} ({1})' -f $nazwa, $login } else { $login }
        return [pscustomobject]@{ Podpis = $podpis; Osoba = $true }
    }
    catch {
        # Grupa, konto komputera albo konto z innej domeny - wlasciciel pokazany w oryginalnym zapisie.
        return [pscustomobject]@{ Podpis = $Wlasciciel; Osoba = $false }
    }
}

# Stan konta w AD - nigdy nie rzuca, zawsze oddaje obiekt wyniku; -Serwer to kontroler po odblokowaniu.
function Get-JezykUserStatus {
    param([string]$Login, [string]$Serwer = '')

    # Login przepisywany z maila albo zgloszenia bardzo czesto ma doklejona spacje.
    if ($null -eq $Login) { $Login = '' }
    $Login = $Login.Trim()

    $adres = $Script:Config.Domena
    if ($Serwer -and (Test-JezykNazwaWDomenach $Serwer $Script:Domeny)) { $adres = $Serwer }

    # Pusty login to nie awaria - kontroler nie jest odpytywany.
    if ([string]::IsNullOrWhiteSpace($Login)) {
        return New-JezykResult -Login '' -Status 'Empty' -Message 'Wpisz login i kliknij "Szukaj".'
    }

    if (-not (Test-JezykNazwaKonta $Login)) {
        return New-JezykResult -Login $Login -Status 'NotFound' `
                               -Message ('Nazwa "{0}" nie jest poprawną nazwą konta.' -f $Login)
    }

    try {
        # -Identity, nie -Filter: tekst jest wartoscia, nie fragmentem zapytania.
        # -Properties konieczne; LockedOut modul wylicza po stronie kontrolera.
        $user = Get-ADUser -Identity $Login `
                           -Server $adres `
                           -Properties LockedOut, Enabled, LockoutTime, DisplayName,
                                       GivenName, Surname, EmailAddress,
                                       OfficePhone, MobilePhone, Manager, MemberOf,
                                       CanonicalName, pwdLastSet, PasswordLastSet,
                                       'msDS-UserPasswordExpiryTimeComputed',
                                       AccountExpirationDate, Created, LastLogonDate `
                           -ErrorAction Stop

        # LockoutTime to FILETIME (0 = nigdy); osobny try - nietypowa wartosc nie psuje odczytu.
        $czasBlokady = $null
        if ($user.LockoutTime -and $user.LockoutTime -gt 0) {
            try   { $czasBlokady = [datetime]::FromFileTime($user.LockoutTime) }
            catch { $czasBlokady = $null }
        }

        $lokalizacja = Get-JezykKatalogZeSciezki $user.CanonicalName

        # Oba numery osobno (telephoneNumber i mobile); brak obu to nie usterka.
        $telefonGlowny    = ([string]$user.OfficePhone).Trim()
        $telefonKomorkowy = ([string]$user.MobilePhone).Trim()

        # Przelozony z tego samego serwera; wlasny try ma Get-JezykPodpisMenedzera.
        $menedzer = Get-JezykPodpisMenedzera -Dn ([string]$user.Manager) -Serwer $adres

        # Grupy w tym samym zapytaniu (memberOf) - bez dodatkowej podrozy po sieci.
        $grupy = @(Get-JezykCzlonkostwaGrup $user.MemberOf)

        # pwdLastSet = 0 - "zmien haslo przy nastepnym logowaniu".
        $wymuszonaZmiana = $null
        if ($null -ne $user.pwdLastSet) { $wymuszonaZmiana = ($user.pwdLastSet -eq 0) }

        # msDS-UserPasswordExpiryTimeComputed ma dwie wartosci specjalne: 0 i maksimum Int64.
        $hasloWygasa    = $null
        $hasloBezTerminu = $null
        $terminHasla = $user.'msDS-UserPasswordExpiryTimeComputed'
        # Prog z ToFileTimeUtc - niezalezny od strefy czasowej stacji.
        $progNigdy = [datetime]::MaxValue.ToFileTimeUtc()
        if ($null -ne $terminHasla) {
            if ($terminHasla -le 0 -or $terminHasla -ge $progNigdy) {
                # Zero obsluguje juz wymuszona zmiana wyzej; tutaj liczy sie druga skrajnosc.
                $hasloBezTerminu = ($terminHasla -ge $progNigdy)
            } else {
                $hasloBezTerminu = $false
                try   { $hasloWygasa = [datetime]::FromFileTime($terminHasla) }
                catch { $hasloWygasa = $null }
            }
        }

        # Login z AD, w oryginalnej pisowni.
        return New-JezykResult -Login $user.SamAccountName -Status 'Ok' `
                               -LockedOut ([bool]$user.LockedOut) `
                               -Enabled ([bool]$user.Enabled) `
                               -DisplayName ([string]$user.DisplayName) `
                               -Imie ([string]$user.GivenName) `
                               -Nazwisko ([string]$user.Surname) `
                               -Email ([string]$user.EmailAddress) `
                               -TelefonGlowny $telefonGlowny `
                               -TelefonKomorkowy $telefonKomorkowy `
                               -Menedzer $menedzer `
                               -Grupy $grupy `
                               -LockoutTime $czasBlokady `
                               -Lokalizacja $lokalizacja `
                               -ZmianaHaslaWymuszona $wymuszonaZmiana `
                               -HasloWygasa $hasloWygasa `
                               -HasloNigdyNieWygasa $hasloBezTerminu `
                               -OstatniaZmianaHasla $user.PasswordLastSet `
                               -KontoWygasa $user.AccountExpirationDate `
                               -KontoUtworzono $user.Created `
                               -OstatnieLogowaniePrzyblizone $user.LastLogonDate `
                               -Dn ([string]$user.DistinguishedName) `
                               -Message ('Znaleziono w domenie {0}.' -f $Script:Config.Domena)
    }
    catch {
        # Uwaga: typ wyjatku po nazwie, nie "catch [Typ]" - bez RSAT plik nie przeszedlby parsowania.
        $typWyjatku = $_.Exception.GetType().Name

        if ($typWyjatku -in @('ADIdentityNotFoundException', 'ADIdentityResolutionException')) {
            return New-JezykResult -Login $Login -Status 'NotFound' `
                                   -Message ('Nie znaleziono konta "{0}" w domenie {1}.' -f $Login, $Script:Config.Domena)
        }

        $opis = Get-JezykOpisBledu $_ 'Odczyt konta'
        return New-JezykResult -Login $Login -Status 'Error' `
                               -Message $opis.Krotki -Szczegoly $opis.Szczegoly
    }
}

# Jedna pozycja listy wyboru z konta AD - wspolna dla szukania po nazwie i po numerze (w tle).
function New-JezykPozycjaKonta {
    param($Konto)

    $nazwa = Get-JezykOsoba ([string]$Konto.DisplayName) ([string]$Konto.GivenName) ([string]$Konto.Surname)
    # Bez nazwy wyswietlanej pokazujemy sam login, zamiast loginu z pustymi nawiasami.
    $opis = if ($nazwa) { '{0} - {1}' -f $Konto.SamAccountName, $nazwa } else { [string]$Konto.SamAccountName }

    [pscustomobject]@{
        Typ         = 'Konto'
        Login       = [string]$Konto.SamAccountName
        Dn          = [string]$Konto.DistinguishedName
        DisplayName = $nazwa
        Opis        = $opis
    }
}

# Konta po numerze telefonu: jeden filtr z gwiazdka miedzy cyframi (9 ostatnich), potem odsiew.
# -ResultPageSize = limit + 1 konczy prace kontrolera; wynik: Trafienia, ZaDuzo, Przerwane
# (README: Wyszukiwanie po numerze telefonu).
function Find-JezykUsersPoNumerze {
    param([string]$Cyfry, [int]$Limit = 10, [string]$Serwer = '', [string]$SzukajOd = '')

    $wynik = [pscustomobject]@{ Trafienia = @(); ZaDuzo = $false; Przerwane = $false; Powod = '' }

    # Brak serwera to przerwanie, nie pusta lista - w tle nie ma konfiguracji okna.
    if (-not $Serwer) {
        $wynik.Przerwane = $true
        $wynik.Powod     = 'Nie przeszukano numerów telefonu: nie podano domeny do zapytania.'
        return $wynik
    }

    # Druga zapora: do wzorca trafiaja same cyfry (6-15, jak E.164).
    $Cyfry = Get-JezykCyfry $Cyfry
    if ($Cyfry.Length -lt 6 -or $Cyfry.Length -gt 15) { return $wynik }

    # Limit bez sensu (np. 0 z braku klucza) zastepujemy domyslnym - zero znaczyloby "zawsze za duzo".
    if ($Limit -lt 1) { $Limit = 10 }

    $rdzen = if ($Cyfry.Length -gt 9) { $Cyfry.Substring($Cyfry.Length - 9) } else { $Cyfry }

    # Uwaga: apostrofy w filtrze celowe - $nr podstawia modul AD (analizator zglasza falszywy alarm).
    $nr = '*' + (($rdzen.ToCharArray()) -join '*') + '*'

    # OfficePhone i MobilePhone to przyjazne nazwy atrybutow telephoneNumber i mobile.
    $pola  = 'DisplayName', 'GivenName', 'Surname', 'OfficePhone', 'MobilePhone'
    $filtr = 'OfficePhone -like $nr -or MobilePhone -like $nr'

    # -SearchBase tylko gdy podane - pusta wartosc modul AD odrzuca bledem.
    $dodatkowe = @{}
    if ($SzukajOd) { $dodatkowe['SearchBase'] = $SzukajOd }

    try {
        # -ResultPageSize konczy SZUKANIE (ResultSetSize tylko czytanie) - ratuje infolinie, nie numer osoby.
        $trafienia = @(Get-ADUser -Filter $filtr -Server $Serwer -Properties $pola `
                                  -ResultPageSize ($Limit + 1) -ResultSetSize ($Limit + 1) `
                                  @dodatkowe -ErrorAction Stop)
    }
    catch {
        # "Nie udalo sie sprawdzic" to nie "nikogo nie ma" - powod pod "!".
        $wynik.Przerwane = $true
        $wynik.Powod     = 'Nie udało się przeszukać numerów telefonu w domenie "{0}": {1}' -f
                           $Serwer, $_.Exception.Message
        return $wynik
    }

    # Komplet wierszy = "bylo ich wiecej" - decyzja przed odsiewem po cyfrach.
    if ($trafienia.Count -gt $Limit) {
        $wynik.ZaDuzo = $true
        return $wynik
    }

    # Odsiew po samych cyfrach - gwiazdki wpuszczaja trafienia przypadkowe.
    $wynik.Trafienia = @($trafienia | Where-Object {
        (Test-JezykNumerPasuje $Cyfry ([string]$_.OfficePhone)) -or
        (Test-JezykNumerPasuje $Cyfry ([string]$_.MobilePhone))
    })

    return $wynik
}

# Wejscie zadania numeru: szuka i oddaje gotowe pozycje listy wyboru.
# Funkcja, a nie tekst w skrypcie tla - tylko tak wykonuje sie w zestawie weryfikacyjnym.
function Find-JezykPozycjePoNumerze {
    param([string]$Cyfry, [int]$Limit = 10, [string]$Serwer = '', [string]$SzukajOd = '')

    $odp = Find-JezykUsersPoNumerze -Cyfry $Cyfry -Limit $Limit -Serwer $Serwer -SzukajOd $SzukajOd

    [pscustomobject]@{
        Trafienia = @($odp.Trafienia | ForEach-Object { New-JezykPozycjaKonta $_ })
        ZaDuzo    = [bool]$odp.ZaDuzo
        Przerwane = [bool]$odp.Przerwane
        Powod     = [string]$odp.Powod
    }
}

# Szuka kont i kontaktow, ktorych dane zaczynaja sie od wpisu; oddaje lekka liste kandydatow.
# Wzorzec idzie do filtra jako zmienna (podstawia ja modul AD); kontakty pod kontami.
function Find-JezykUsers {
    param([string]$Fragment)

    if ($null -eq $Fragment) { $Fragment = '' }
    $Fragment = $Fragment.Trim()

    # Jeden ksztalt wyniku dla wszystkich stanow.
    $pusty = [pscustomobject]@{ Status = 'Empty'; Konta = @(); Szczegoly = ''
                                Message = 'Wpisz login, imię i nazwisko, e-mail, numer telefonu albo login@domena i kliknij "Szukaj".' }
    if ([string]::IsNullOrWhiteSpace($Fragment)) { return $pusty }

    $slowa = @($Fragment -split '\s+' | Where-Object { $_ })

    try {
        # Gwiazdka tylko na koncu - dopasowanie od poczatku korzysta z indeksow.
        $wzorzec = $Fragment + '*'

        # Pobieramy limit + 1, zeby wiedziec, ze bylo wiecej.
        $limit = $Script:Config.LimitWynikow

        # Uwaga: apostrofy celowe - $wzorzec podstawia modul AD; cudzyslowy otwieralyby droge do wstrzykniecia.
        # UserPrincipalName to osobny atrybut niz EmailAddress.
        $filtr = 'SamAccountName -like $wzorzec -or GivenName -like $wzorzec ' +
                 '-or Surname -like $wzorzec -or EmailAddress -like $wzorzec ' +
                 '-or UserPrincipalName -like $wzorzec -or DisplayName -like $wzorzec'

        # Dwa wyrazy: imie i nazwisko w obu kolejnosciach.
        if ($slowa.Count -eq 2) {
            $wzorzecA = $slowa[0] + '*'
            $wzorzecB = $slowa[1] + '*'
            $filtr += ' -or (GivenName -like $wzorzecA -and Surname -like $wzorzecB)' +
                      ' -or (GivenName -like $wzorzecB -and Surname -like $wzorzecA)'
        }

        $znalezione = @(Get-ADUser -Filter $filtr `
                                   -Server $Script:Config.Domena `
                                   -Properties DisplayName, GivenName, Surname `
                                   -ResultSetSize ($limit + 1) `
                                   -ErrorAction Stop)

        # Numeru telefonu ta funkcja nie szuka - robi to zadanie w tle (atrybuty bez indeksu).

        # Kontakty: nazwy atrybutow surowe (Get-ADObject nie zna przyjaznych); apostrofy jak wyzej.
        $filtrKontakt = 'objectClass -eq ''contact'' -and (name -like $wzorzec ' +
                        '-or displayName -like $wzorzec -or givenName -like $wzorzec ' +
                        '-or sn -like $wzorzec -or mail -like $wzorzec)'
        if ($slowa.Count -eq 2) {
            $filtrKontakt = 'objectClass -eq ''contact'' -and (name -like $wzorzec ' +
                            '-or displayName -like $wzorzec -or givenName -like $wzorzec ' +
                            '-or sn -like $wzorzec -or mail -like $wzorzec ' +
                            '-or (givenName -like $wzorzecA -and sn -like $wzorzecB) ' +
                            '-or (givenName -like $wzorzecB -and sn -like $wzorzecA))'
        }

        # Wlasny try: kontakty sa dodatkiem - blad nie przeslania kont.
        $kontakty = @()
        try {
            $kontakty = @(Get-ADObject -Filter $filtrKontakt `
                                       -Server $Script:Config.Domena `
                                       -Properties displayName, givenName, sn, mail `
                                       -ResultSetSize ($limit + 1) `
                                       -ErrorAction Stop)
        }
        catch { $kontakty = @() }

        # Limit od sumy kont i kontaktow.
        $lacznie = $znalezione.Count + $kontakty.Count

        if ($lacznie -eq 0) {
            # Mowimy tylko o nazwie - szukanie po numerze moze jeszcze trwac (Update-JezykNumerWTle).
            return [pscustomobject]@{
                Status    = 'NotFound'
                Konta     = @()
                Message   = ('Nie znaleziono konta ani kontaktu pasującego do "{0}" w domenie {1}.' -f $Fragment, $Script:Config.Domena)
                Szczegoly = ''
            }
        }

        if ($lacznie -gt $limit) {
            return [pscustomobject]@{
                Status    = 'TooMany'
                Konta     = @()
                Message   = ('Zbyt wiele trafień (ponad {0}). Doprecyzuj wpisaną wartość.' -f $limit)
                Szczegoly = ''
            }
        }

        $konta = @($znalezione | Sort-Object SamAccountName | ForEach-Object { New-JezykPozycjaKonta $_ })

        # Kontakt niesie DN zamiast loginu.
        $wpisy = @(foreach ($c in ($kontakty | Sort-Object Name)) {
            # Nazwa obiektu (cn) w nawiasie - po niej operator rozpoznaje kontakt.
            $nazwaObiektu = [string]$c.Name
            $nazwa = Get-JezykOsoba ([string]$c.displayName) ([string]$c.givenName) ([string]$c.sn)
            if (-not $nazwa) { $nazwa = $nazwaObiektu }

            # Nawias tylko wtedy, gdy niesie cos nowego.
            $podpis = if ($nazwaObiektu -and $nazwaObiektu -ne $nazwa) {
                '{0} ({1})' -f $nazwa, $nazwaObiektu
            } else { $nazwa }

            $opis = if ($c.mail) { '[Kontakt] {0} - {1}' -f $podpis, [string]$c.mail } else { '[Kontakt] {0}' -f $podpis }
            # Ten sam ksztalt pozycji co przy koncie; kontakt i tak czytany od nowa po DN.
            [pscustomobject]@{
                Typ         = 'Kontakt'
                Login       = ''
                Dn          = [string]$c.DistinguishedName
                DisplayName = $nazwa
                Opis        = $opis
            }
        })

        # Konta pierwsze - okno samo zaznacza pozycje zerowa.
        $pozycje = @($konta) + @($wpisy)

        $czesci = @()
        if ($konta.Count) { $czesci += '{0} {1}' -f $konta.Count, (Get-JezykOdmiana $konta.Count 'konto' 'konta' 'kont') }
        if ($wpisy.Count) { $czesci += '{0} {1}' -f $wpisy.Count, (Get-JezykOdmiana $wpisy.Count 'kontakt' 'kontakty' 'kontaktów') }

        [pscustomobject]@{
            Status    = 'Ok'
            Konta     = @($pozycje)
            Message   = ('Znaleziono {0}.' -f ($czesci -join ' i '))
            Szczegoly = ''
        }
    }
    catch {
        $opis = Get-JezykOpisBledu $_ 'Wyszukiwanie'
        [pscustomobject]@{ Status = 'Error'; Konta = @(); Message = $opis.Krotki
                           Szczegoly = $opis.Szczegoly }
    }
}

# Odczyt kontaktu po DN; wynik ze Statusem 'Kontakt' w tym samym ksztalcie (New-JezykResult).
function Get-JezykKontaktStatus {
    param([string]$Dn)

    if ($null -eq $Dn) { $Dn = '' }
    $Dn = $Dn.Trim()

    # DN idzie do -Identity, wiec sprawdzamy go tak samo jak przed sklejeniem sciezki LDAP.
    if (-not (Test-JezykDn $Dn)) {
        return New-JezykResult -Login '' -Status 'NotFound' `
                               -Message 'Ta pozycja nie niesie poprawnej nazwy wyróżniającej - nie ma czego odczytać.'
    }

    try {
        $kontakt = Get-ADObject -Identity $Dn `
                                -Server $Script:Config.Domena `
                                -Properties displayName, givenName, sn, mail,
                                            telephoneNumber, mobile, memberOf,
                                            CanonicalName, whenCreated `
                                -ErrorAction Stop

        $lokalizacja = Get-JezykKatalogZeSciezki ([string]$kontakt.CanonicalName)

        # Osobny try - nietypowa data nie psuje odczytu.
        $utworzono = $null
        if ($kontakt.whenCreated) {
            try   { $utworzono = [datetime]$kontakt.whenCreated }
            catch { $utworzono = $null }
        }

        $nazwa = Get-JezykOsoba ([string]$kontakt.displayName) ([string]$kontakt.givenName) ([string]$kontakt.sn)
        if (-not $nazwa) { $nazwa = [string]$kontakt.Name }

        # Oba numery osobno; nazwy atrybutow surowe.
        $telefonGlowny    = ([string]$kontakt.telephoneNumber).Trim()
        $telefonKomorkowy = ([string]$kontakt.mobile).Trim()

        # Bez Szczegolow - udany odczyt nie zapala "!".
        return New-JezykResult -Login '' -Status 'Kontakt' `
                               -NazwaObiektu ([string]$kontakt.Name) `
                               -DisplayName $nazwa `
                               -Imie ([string]$kontakt.givenName) `
                               -Nazwisko ([string]$kontakt.sn) `
                               -Email ([string]$kontakt.mail) `
                               -TelefonGlowny $telefonGlowny `
                               -TelefonKomorkowy $telefonKomorkowy `
                               -Grupy @(Get-JezykCzlonkostwaGrup $kontakt.memberOf) `
                               -Lokalizacja $lokalizacja `
                               -KontoUtworzono $utworzono `
                               -Dn ([string]$kontakt.DistinguishedName) `
                               -Message ('Kontakt w domenie {0}. To wpis książki adresowej, a nie konto - nie loguje się i nie da się go odblokować.' -f $Script:Config.Domena)
    }
    catch {
        # Typ po nazwie, nie przez "catch [Typ]" - z tego samego powodu co w Get-JezykUserStatus.
        $typWyjatku = $_.Exception.GetType().Name

        if ($typWyjatku -in @('ADIdentityNotFoundException', 'ADIdentityResolutionException')) {
            return New-JezykResult -Login '' -Status 'NotFound' `
                                   -Message ('Nie znaleziono już tego kontaktu w domenie {0}.' -f $Script:Config.Domena)
        }

        $opis = Get-JezykOpisBledu $_ 'Odczyt kontaktu'
        return New-JezykResult -Login '' -Status 'Error' `
                               -Message $opis.Krotki -Szczegoly $opis.Szczegoly
    }
}

# Adresy maszyny w kolejnosci sondowania: IPv4 najpierw, bez powtorzen, najwyzej $Ile.
# Nie "pierwszy z DNS" - kolejnosc rekordow nie jest ustalona, a MAC idzie za pokazanym adresem.
function Get-JezykAdresyDoSondy {
    param($Adresy, [int]$Ile = 4)

    $wybrane  = New-Object System.Collections.Generic.List[string]
    $widziane = @{}

    $czworka  = [System.Net.Sockets.AddressFamily]::InterNetwork
    $kolejnosc = @(@($Adresy) | Where-Object { $_ -and $_.AddressFamily -eq $czworka }) +
                 @(@($Adresy) | Where-Object { $_ -and $_.AddressFamily -ne $czworka })

    foreach ($adres in $kolejnosc) {
        if ($wybrane.Count -ge $Ile) { break }

        $tekst = ([string]$adres).Trim()
        if (-not $tekst) { continue }
        if ($widziane.ContainsKey($tekst)) { continue }

        $widziane[$tekst] = $true
        $wybrane.Add($tekst)
    }

    # Przecinek wymuszony - inaczej jeden adres wraca golym napisem, a zero jako $null.
    return ,$wybrane.ToArray()
}

# Sonda ICMP: Odpowiada ($true, $false, $null = nie wiadomo) i adres; DNS osobno, jeden termin.
# Milczenie na ping nie dowodzi, ze maszyna jest wylaczona - zapora czesto blokuje ICMP.
function Get-JezykPingKomputera {
    param([string]$Nazwa, [int]$LimitMs = 1500)

    $wynik = [pscustomobject]@{ Odpowiada = $null; Adres = ''; Blad = ''; Szczegoly = '' }

    # Sprawdzenie PRZED pierwszym uzyciem nazwy - idzie ona wprost do odpytania DNS.
    if (-not (Test-JezykNazwaHosta $Nazwa)) {
        $wynik.Blad      = 'nieprawidlowa nazwa'
        $wynik.Szczegoly = 'Nazwa "{0}" nie jest poprawną nazwą hosta - nie ma czego sprawdzać.' -f $Nazwa
        return $wynik
    }

    $zegar = [System.Diagnostics.Stopwatch]::StartNew()

    $adresy = $null
    try {
        $uchwytDns = [System.Net.Dns]::BeginGetHostAddresses($Nazwa, $null, $null)
        if (-not $uchwytDns.AsyncWaitHandle.WaitOne($LimitMs, $false)) {
            $wynik.Blad      = 'nazwa nierozpoznana'
            $wynik.Szczegoly = 'DNS nie odpowiedział na pytanie o "{0}" w {1} ms.' -f $Nazwa, $LimitMs
            return $wynik
        }
        $adresy = [System.Net.Dns]::EndGetHostAddresses($uchwytDns)
    }
    catch {
        $wynik.Blad      = 'nazwa nierozpoznana'
        $wynik.Szczegoly = 'DNS nie zna nazwy "{0}": {1}' -f $Nazwa, $_.Exception.Message
        return $wynik
    }

    # Kandydaci, a nie jeden adres z brzegu (Get-JezykAdresyDoSondy).
    $kandydaci = Get-JezykAdresyDoSondy -Adresy $adresy
    if (@($kandydaci).Count -eq 0) {
        $wynik.Blad      = 'nazwa nierozpoznana'
        $wynik.Szczegoly = 'DNS odpowiedział, ale nie podał żadnego adresu dla "{0}".' -f $Nazwa
        return $wynik
    }

    # Adres zapisany nawet bez odpowiedzi - DNS go zna; zastapi go adres, ktory odpowie.
    $wynik.Adres = $kandydaci[0]

    $pozostalo = $LimitMs - $zegar.ElapsedMilliseconds
    if ($pozostalo -le 0) {
        $wynik.Blad      = 'brak czasu na ping'
        $wynik.Szczegoly = 'Rozpoznanie nazwy "{0}" zajęło cały budżet {1} ms - na ping nie zostało nic.' -f $Nazwa, $LimitMs
        return $wynik
    }

    # Budzet dzielony na kandydatow; konczy pierwszy, ktory odpowie.
    $naAdres = [int][math]::Floor($pozostalo / @($kandydaci).Count)
    if ($naAdres -lt 1) { $naAdres = 1 }

    $ping    = $null
    $ostatni = $null
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping

        foreach ($kandydat in $kandydaci) {
            $odpowiedz = $ping.Send($kandydat, $naAdres)
            $ostatni   = $odpowiedz.Status

            if ($odpowiedz.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $wynik.Adres     = $kandydat
                $wynik.Odpowiada = $true
                $wynik.Szczegoly = '{0} ({1}) odpowiedział w {2} ms.' -f $Nazwa, $kandydat, $odpowiedz.RoundtripTime
                break
            }
        }

        # Petla przeszla bez odpowiedzi - maszyna milczy ($false, nie $null).
        if ($null -eq $wynik.Odpowiada) {
            $wynik.Odpowiada = $false
            $wynik.Szczegoly = if (@($kandydaci).Count -gt 1) {
                '{0} nie odpowiedział na ping pod żadnym ze swoich adresów ({1}); ostatni stan: {2}. To NIE jest dowód, że maszyna jest wyłączona - zapora często blokuje ICMP.' -f $Nazwa, ($kandydaci -join ', '), $ostatni
            } else {
                '{0} ({1}) nie odpowiedział na ping: {2}. To NIE jest dowód, że maszyna jest wyłączona - zapora często blokuje ICMP.' -f $Nazwa, $kandydaci[0], $ostatni
            }
        }
    }
    catch {
        # Odpowiada zostaje $null: sonda sie nie odbyla, wiec nie wiemy nic o maszynie.
        $wynik.Blad      = 'ping nie doszedł do skutku'
        $wynik.Szczegoly = 'Ping na {0} ({1}) zawiódł: {2}' -f $Nazwa, $wynik.Adres, $_.Exception.Message
    }
    finally {
        if ($ping) { try { $ping.Dispose() } catch { } }
    }

    return $wynik
}

# Uruchamia zdalna konsole ConfigMgr dla maszyny - jedyne miejsce, ktore startuje osobny proces.
# Sciezka z argumentu (z ustawien); nie rzuca; bez -Wait - okno nie czeka na koniec sesji.
function Start-JezykRemoteControl {
    param([string]$Netbios, [string]$Sciezka)

    if ($null -eq $Netbios) { $Netbios = '' }
    if ($null -eq $Sciezka) { $Sciezka = '' }
    $Netbios = $Netbios.Trim()
    $Sciezka = $Sciezka.Trim()

    $wynik = [pscustomobject]@{ Udane = $false; Komunikat = ''; Szczegoly = ''; Proces = $null }

    # Biala lista na nazwie maszyny - idzie argumentem tworzonego procesu.
    if (-not (Test-JezykNazwaKonta $Netbios)) {
        $wynik.Komunikat = 'Nie mam nazwy maszyny, z którą można się połączyć.'
        $wynik.Szczegoly = 'Wartość "{0}" nie wygląda na nazwę komputera, więc nie została nikomu podana.' -f $Netbios
        return $wynik
    }

    # Sciezka sprawdzana takze tutaj - funkcja wykonujaca operacje broni sie sama.
    if (-not $Sciezka) {
        $wynik.Komunikat = 'Nie ustawiono ścieżki do zdalnej konsoli.'
        $wynik.Szczegoly = 'Uzupełnij SciezkaRemoteControl w $Script:Ustawienia (plik Jezyk-1-Srodowisko.ps1) - pełną ścieżką do CmRcViewer.exe z konsoli ConfigMgr.'
        return $wynik
    }

    if (-not (Test-JezykSciezkaProgramu $Sciezka)) {
        $wynik.Komunikat = 'Ścieżka do zdalnej konsoli jest niepoprawna.'
        $wynik.Szczegoly = 'SciezkaRemoteControl ma być pełną ścieżką do pliku .exe - od litery dysku albo od \\serwera. Wpisano: "{0}"' -f $Sciezka
        return $wynik
    }

    try {
        # -ArgumentList tablica, nie sklejony napis; proces wraca do notki "Trwa laczenie".
        $wynik.Proces    = Start-Process -FilePath $Sciezka -ArgumentList @($Netbios) -PassThru -ErrorAction Stop
        $wynik.Udane     = $true
        $wynik.Komunikat = 'Uruchomiono zdalną konsolę dla maszyny {0}.' -f $Netbios
    }
    catch {
        # Brak pliku, odmowa, martwy udzial - rozroznia je pelna tresc wyjatku.
        $opis = Get-JezykOpisBledu $_ ('Uruchomienie zdalnej konsoli dla {0}' -f $Netbios)
        $wynik.Komunikat = $opis.Krotki
        $wynik.Szczegoly = '{0}{1}Ścieżka z konfiguracji: {2}' -f
                           $opis.Szczegoly, ([Environment]::NewLine + [Environment]::NewLine), $Sciezka
    }

    return $wynik
}

# Stan uruchomionej konsoli: Czeka (bez okna), Gotowa (okno albo nie ma na co czekac), Zamknieta.
# Komunikat to zawsze to, co pole ma pokazac, gdy czekanie konczy sie teraz; nie rzuca.
function Get-JezykStanKonsoli {
    param($Proces, [string]$Netbios, [string]$Sciezka)

    $wynik = [pscustomobject]@{
        Stan      = 'Gotowa'
        Komunikat = 'Uruchomiono zdalną konsolę dla maszyny {0}.' -f $Netbios
        Szczegoly = ''
    }
    if (-not $Proces) { return $wynik }

    try {
        # Proces zapamietuje stan z pierwszego odczytu - bez odswiezenia okno nie pojawi sie nigdy.
        $Proces.Refresh()

        if ($Proces.HasExited) {
            try { $kod = [string]$Proces.ExitCode } catch { $kod = 'nieczytelny' }
            $wynik.Stan      = 'Zamknieta'
            $wynik.Komunikat = 'Zdalna konsola zamknęła się, zanim pokazała okno.'
            $wynik.Szczegoly = 'Program zdalnej konsoli dla maszyny {0} zakończył pracę (kod wyjścia: {1}), nie pokazując żadnego okna.{2}Ścieżka z konfiguracji: {3}' -f
                               $Netbios, $kod, ([Environment]::NewLine + [Environment]::NewLine), $Sciezka
            return $wynik
        }

        if ([IntPtr]::Zero -eq $Proces.MainWindowHandle) { $wynik.Stan = 'Czeka' }
    }
    catch {
        # Nieczytelny stan procesu konczy czekanie - samo uruchomienie i tak sie udalo.
        $wynik.Stan = 'Gotowa'
    }

    return $wynik
}

# Sciezka udzialu administracyjnego (\\NAZWA\C$) albo odmowa z komunikatem - jedno miejsce obu zapor.
function Get-JezykSciezkaUdzialu {
    param([string]$Netbios, [string]$Litera)

    if ($null -eq $Netbios) { $Netbios = '' }
    if ($null -eq $Litera)  { $Litera  = '' }
    $Netbios = $Netbios.Trim()
    $Litera  = $Litera.Trim()

    $wynik = [pscustomobject]@{ Sciezka = ''; Komunikat = ''; Szczegoly = '' }

    # Ta sama biala lista co przy zdalnej konsoli - nazwa wchodzi w srodek sciezki.
    if (-not (Test-JezykNazwaKonta $Netbios)) {
        $wynik.Komunikat = 'Nie mam nazwy maszyny, której dyski można otworzyć.'
        $wynik.Szczegoly = 'Wartość "{0}" nie wygląda na nazwę komputera, więc nie została nikomu podana.' -f $Netbios
        return $wynik
    }

    # Dokladnie jedna litera - "C$" dalby "\\NAZWA\C$$".
    if ($Litera -notmatch '^[A-Za-z]$') {
        $wynik.Komunikat = 'To nie jest litera dysku.'
        $wynik.Szczegoly = 'Udział otwiera się po JEDNEJ literze dysku (np. C), a dostałem: "{0}"' -f $Litera
        return $wynik
    }

    # Uwaga: sciezka do zmiennej - w argumencie metody przecinek nalezy do metody, nie do -f.
    $wynik.Sciezka = '\\{0}\{1}$' -f $Netbios, $Litera.ToUpper()
    return $wynik
}

# Otwiera udzial w Eksploratorze: sama sciezka dla powloki, bez explorer.exe i bez -ArgumentList.
# Sesja stoi juz wczesniej (Connect-JezykUdzialDysku), wiec wywolanie wraca od razu (README: Przycisk "Dyski").
function Open-JezykUdzialDysku {
    param([string]$Netbios, [string]$Litera)

    $wynik = [pscustomobject]@{ Udane = $false; Komunikat = ''; Szczegoly = '' }

    # Obie zapory i sciezka z Get-JezykSciezkaUdzialu - ta sama, z ktora system sie polaczyl.
    $adres = Get-JezykSciezkaUdzialu -Netbios $Netbios -Litera $Litera
    if (-not $adres.Sciezka) {
        $wynik.Komunikat = $adres.Komunikat
        $wynik.Szczegoly = $adres.Szczegoly
        return $wynik
    }

    $sciezka = $adres.Sciezka

    try {
        Start-Process -FilePath $sciezka -ErrorAction Stop
        $wynik.Udane     = $true
        $wynik.Komunikat = 'Otwarto udział {0}.' -f $sciezka
    }
    catch {
        # Brak uprawnien, wylaczone udzialy, milczaca maszyna - pelna tresc wyjatku.
        $opis = Get-JezykOpisBledu $_ ('Otwarcie udziału {0}' -f $sciezka)
        $wynik.Komunikat = $opis.Krotki
        $wynik.Szczegoly = $opis.Szczegoly
    }

    return $wynik
}

# Kod z WNetAddConnection3 na stan: Ok, Poswiadczenia, Anulowano albo Blad - po kodzie, nie po tresci.
# 1219 to Blad: druga sesja do tego samego serwera na inne konto i tak nie powstanie.
function Get-JezykStanPolaczeniaUdzialu {
    param([int]$Kod)

    $wynik = [pscustomobject]@{ Stan = 'Blad'; Komunikat = ''; Szczegoly = '' }

    if ($Kod -eq 0) {
        $wynik.Stan = 'Ok'
        return $wynik
    }

    # 5, 86, 1326 - tym kontem nie wejdziesz (udzialy wymagaja administratora na maszynie).
    if ($Kod -in @(5, 86, 1326)) {
        $wynik.Stan      = 'Poswiadczenia'
        $wynik.Komunikat = 'Do tego udziału potrzeba konta z prawami administratora na tej maszynie.'
        $wynik.Szczegoly = 'System odmówił połączenia z udziałem (kod {0}).' -f $Kod
        return $wynik
    }

    # 1223 - operator zamknal okno poswiadczen; rezygnacja to nie blad.
    if ($Kod -eq 1223) {
        $wynik.Stan      = 'Anulowano'
        $wynik.Komunikat = 'Nie podano poświadczeń.'
        return $wynik
    }

    # 1219 - pytanie o konto tu nie pomoze.
    if ($Kod -eq 1219) {
        $wynik.Komunikat = 'Jest już połączenie z tą maszyną na inne konto.'
        $wynik.Szczegoly = 'Windows utrzymuje do jednego serwera tylko jedną sesję na jedno konto (kod 1219). ' +
                           'Zamknij otwarte okna Eksploratora i odłącz mapowane dyski tej maszyny, a potem spróbuj ponownie.'
        return $wynik
    }

    # 53, 67 - maszyna milczy albo udzialu nie ma (bywa wylaczony politykami).
    if ($Kod -in @(53, 67)) {
        $wynik.Komunikat = 'Nie znaleziono tej maszyny albo udziału w sieci.'
        $wynik.Szczegoly = 'Połączenie z udziałem zakończyło się kodem {0}. Maszyna może nie odpowiadać, ' -f $Kod
        $wynik.Szczegoly += 'a udziały administracyjne bywają wyłączone politykami.'
        return $wynik
    }

    if ($Kod -eq -1) {
        $wynik.Komunikat = 'Nie udało się sięgnąć do funkcji systemowych.'
        $wynik.Szczegoly = 'Połączenia z udziałem nie ma jak zamówić - nie powstały funkcje systemowe Jeżyka. ' +
                           'Opis przyczyny trafia do pliku %TEMP%\Jezyk-konsola.txt.'
        return $wynik
    }

    # Nieznany kod zostaje w tresci - to jedyne, co o awarii wiadomo.
    $wynik.Komunikat = 'Nie udało się połączyć z udziałem.'
    $wynik.Szczegoly = 'Połączenie z udziałem zakończyło się kodem systemowym {0}.' -f $Kod
    return $wynik
}

# Zestawia sesje z udzialem (bez litery dysku); nie otwiera go. Bez -Interaktywnie - w tle;
# z -Interaktywnie - okno poswiadczen, wylacznie z watku interfejsu i z uchwytem okna glownego.
function Connect-JezykUdzialDysku {
    param([string]$Netbios, [string]$Litera,
          [IntPtr]$Uchwyt = [IntPtr]::Zero, [switch]$Interaktywnie)

    # Maszyna i litera wracaja w wyniku - na wypadek drugiego pytania, juz z oknem poswiadczen.
    $maszyna = ([string]$Netbios).Trim()
    $dysk    = ([string]$Litera).Trim().ToUpper()

    $adres = Get-JezykSciezkaUdzialu -Netbios $Netbios -Litera $Litera
    if (-not $adres.Sciezka) {
        # Kod pusty, a nie -1: nikogo nie pytalismy, wiec zaden kod nie padl.
        return [pscustomobject]@{ Stan = 'Blad'; Kod = $null; Sciezka = ''
                                  Netbios = $maszyna; Litera = $dysk
                                  Komunikat = $adres.Komunikat; Szczegoly = $adres.Szczegoly }
    }

    # 0x08 CONNECT_INTERACTIVE + 0x10 CONNECT_PROMPT - pytaj takze mimo zapamietanych poswiadczen.
    $flagi = if ($Interaktywnie) { 0x18 } else { 0 }

    $kod  = Invoke-JezykPolaczenieUdzialu -Sciezka $adres.Sciezka -Uchwyt $Uchwyt -Flagi $flagi
    $opis = Get-JezykStanPolaczeniaUdzialu -Kod $kod

    [pscustomobject]@{ Stan = $opis.Stan; Kod = $kod; Sciezka = $adres.Sciezka
                       Netbios = $maszyna; Litera = $dysk
                       Komunikat = $opis.Komunikat; Szczegoly = $opis.Szczegoly }
}

# Komputer w AD po nazwie NetBIOS (bez wielkosci liter): katalog, wlasciciel obiektu, stan konta, data.
# Funkcja kontrolna - zostaje ostatnia w pliku.
function Get-JezykComputerStatus {
    param([string]$Netbios)

    if ($null -eq $Netbios) { $Netbios = '' }
    $Netbios = $Netbios.Trim()

    if ([string]::IsNullOrWhiteSpace($Netbios)) {
        return [pscustomobject]@{ Nazwa = ''; Status = 'Empty'; Lokalizacja = ''
                                  Message = 'Wpisz nazwę NetBIOS komputera i kliknij "Szukaj".' }
    }

    if (-not (Test-JezykNazwaKonta $Netbios)) {
        return [pscustomobject]@{ Nazwa = $Netbios; Status = 'NotFound'; Lokalizacja = ''
                                  Message = ('Nazwa "{0}" nie jest poprawną nazwą komputera.' -f $Netbios) }
    }

    try {
        $komputer = Get-ADComputer -Identity $Netbios `
                                   -Server $Script:Config.Domena `
                                   -Properties CanonicalName, nTSecurityDescriptor, whenCreated `
                                   -ErrorAction Stop

        $lokalizacja = Get-JezykKatalogZeSciezki $komputer.CanonicalName

        # Tworca = wlasciciel obiektu (nTSecurityDescriptor.Owner); przy administratorze AD wpisuje GRUPE.
        # Try obejmuje dokladnie jedno wyrazenie - ubezpieczenie na wypadek wyjatku w Windows PowerShell 5.1.
        $wlasciciel = ''
        try   { $wlasciciel = [string]$komputer.nTSecurityDescriptor.Owner }
        catch { $wlasciciel = '' }

        $podpis = Get-JezykPodpisWlasciciela -Wlasciciel $wlasciciel -Serwer $Script:Config.Domena

        # Stan konta komputera surowo: $null (nie przyszedl) to "nie wiadomo", nie "wylaczone".
        $wlaczone = $null
        if ($null -ne $komputer.Enabled) { $wlaczone = [bool]$komputer.Enabled }

        # Data surowa - formatuje ja widok, tak samo jak kazda inna date w tym programie.
        $utworzono = $null
        if ($komputer.whenCreated) {
            try { $utworzono = [datetime]$komputer.whenCreated } catch { $utworzono = $null }
        }

        [pscustomobject]@{
            Nazwa       = [string]$komputer.Name
            Status      = 'Ok'
            Lokalizacja = $lokalizacja
            Tworca      = $podpis.Podpis
            TworcaOsoba = $podpis.Osoba
            Wlaczone    = $wlaczone
            Utworzono   = $utworzono
            # Komunikat z nazwa z AD - AD dopasowuje bez wielkosci liter, pokazujemy jego pisownie.
            Message     = ('Znaleziono komputer {0} w domenie {1}.' -f $komputer.Name, $Script:Config.Domena)
        }
    }
    catch {
        # Typ po nazwie, nie przez "catch [Typ]" - z tego samego powodu co w Get-JezykUserStatus.
        $typWyjatku = $_.Exception.GetType().Name

        if ($typWyjatku -in @('ADIdentityNotFoundException', 'ADIdentityResolutionException')) {
            return [pscustomobject]@{
                Nazwa = $Netbios; Status = 'NotFound'; Lokalizacja = ''
                Message = ('Nie znaleziono komputera "{0}" w domenie {1}.' -f $Netbios, $Script:Config.Domena)
            }
        }

        $opis = Get-JezykOpisBledu $_ 'Odczyt komputera'
        [pscustomobject]@{ Nazwa = $Netbios; Status = 'Error'; Lokalizacja = ''
                           Message = $opis.Krotki; Szczegoly = $opis.Szczegoly }
    }
}

#endregion
