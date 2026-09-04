# Jezyk-2-Logika - odpytanie Active Directory i SCCM. Zero kodu interfejsu.
# TA LINIA MUSI POZOSTAC ZWYKLYM KOMENTARZEM - oslania pierwsza instrukcje przed
# zdublowanym znacznikiem BOM. Powod opisany w Kod-Jezyk.ps1.

# Wlasny trap w kazdej czesci: trap wznawia prace w zakresie, w ktorym go zdefiniowano,
# wiec bez tego blad w linii 1 porzucilby caly ten plik.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 2 - LOGIKA

# --- SPRAWDZANIE WARTOSCI, KTORE STAJA SIE TOZSAMOSCIA ALBO ADRESEM -------------------
# Biala lista, nie czarna: wypisujemy znaki DOZWOLONE, bo ich lista jest krotka
# i zamknieta, a lista niebezpiecznych nigdy nie jest kompletna. Sprawdzamy kazda granice,
# na ktorej tekst przestaje byc tekstem i staje sie nazwa konta, nazwa serwera albo
# sciezka LDAP.
#
# Poza tymi regulami jest CELOWO pole wyszukiwania - wpisuje sie w nie imiona i nazwiska,
# wiec spacje i polskie znaki sa tam normalne. Tamta sciezka broni sie inaczej, patrz
# Find-JezykUsers.

# Nazwa konta albo komputera (sAMAccountName). Znaki o znaczeniu skladniowym w LDAP
# ( * ( ) \ ) i w WQL ( ' " % ) nie mieszcza sie w tym zestawie. Pierwszy znak osobno:
# wartosc zaczynajaca sie od myslnika wyglada jak przelacznik, a AD i tak takiej nazwy
# nie utworzy.
function Test-JezykNazwaKonta {
    param([string]$Nazwa)

    if ([string]::IsNullOrWhiteSpace($Nazwa)) { return $false }
    # 256 to duzo powyzej limitu AD; chodzi o to, zeby absurdalnie dlugi tekst nie wedrowal dalej.
    if ($Nazwa.Length -gt 256) { return $false }
    return ($Nazwa -match '^[A-Za-z0-9_][A-Za-z0-9._$-]*$')
}

# Nazwa hosta albo domeny - trafia do parametru -Server oraz do sciezki LDAP://serwer/...
# Etykiety oddzielone kropkami, bez myslnika na brzegach.
function Test-JezykNazwaHosta {
    param([string]$Nazwa)

    if ([string]::IsNullOrWhiteSpace($Nazwa)) { return $false }
    if ($Nazwa.Length -gt 253) { return $false }
    return ($Nazwa -match '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$')
}

# DistinguishedName - doklejany do sciezki LDAP://kontroler/DN. Nie sprawdzamy pelnej
# skladni RFC 4514, tylko czy w ogole wyglada jak DN i czy nie niesie znakow sterujacych.
function Test-JezykDn {
    param([string]$Dn)

    if ([string]::IsNullOrWhiteSpace($Dn)) { return $false }
    if ($Dn.Length -gt 2048) { return $false }
    if ($Dn -match '[\x00-\x1F]') { return $false }
    return ($Dn -match '^[A-Za-z]+=..*' -and $Dn -match '(?i)DC=')
}

<#
.SYNOPSIS
    Poddrzewo przeszukania po numerze dla WYBRANEJ domeny - puste, gdy jej nie wymieniono.

.DESCRIPTION
    Osobna funkcja, a nie wartosc policzona raz przy starcie: domena zmienia sie w trakcie
    pracy okna, a nazwa wyrozniajaca konczy sie skladnikami DC tej jednej domeny. Wartosc
    zapamietana przy starcie obowiazywalaby po przelaczeniu domeny nadal - i wskazywalaby
    poddrzewo, ktorego w nowej domenie nie ma.

    Normalizacja kluczy siedzi w Jezyk-1-Srodowisko.ps1, przy $Script:SzukajOd - tak samo
    jak przy obu listach domen, ktorych uzywa Test-JezykWolnoOdblokowac.
#>
function Get-JezykSzukajOd {
    param([string]$Domena)

    $klucz = ([string]$Domena).Trim().ToLower()
    if (-not $klucz) { return '' }
    if ($Script:SzukajOd -isnot [hashtable]) { return '' }
    if ($Script:SzukajOd.ContainsKey($klucz)) { return [string]$Script:SzukajOd[$klucz] }
    return ''
}

<#
.SYNOPSIS
    Czy nazwa hosta nalezy do ktorejs ze wskazanych domen?

.DESCRIPTION
    Sam ksztalt nazwy nie wystarcza: "obcy.host.example" wyglada nienagannie, a trafialby
    do -ComputerName sesji WMI albo do sciezki LDAP. Tutaj pytamy o POCHODZENIE.
    Sprawdzenie jest czysto tekstowe - zadnego odpytywania sieci.
#>
function Test-JezykNazwaWDomenach {
    param([string]$Nazwa, [string[]]$Domeny)

    if (-not (Test-JezykNazwaHosta $Nazwa)) { return $false }

    $mala = $Nazwa.Trim().ToLower()
    foreach ($domena in @($Domeny)) {
        if (-not $domena) { continue }
        $d = ([string]$domena).Trim().ToLower()
        if (-not $d) { continue }
        # Kropka przed sufiksem jest konieczna, bez niej "zlyjezyk.pl" przeszloby jako
        # nalezace do "jezyk.pl". ORDINAL, a nie porownanie domyslne: porownanie wedlug
        # kultury pomija niektore znaki jako nieistotne (choćby miekki dywiz), wiec nazwa
        # spreparowana z takim znakiem moglaby dopasowac sie do obcego sufiksu.
        if ($mala -eq $d -or $mala.EndsWith('.' + $d, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

<#
.SYNOPSIS
    Zostawia z tekstu SAME CYFRY. Podstawa calego porownywania numerow telefonu.

.DESCRIPTION
    Numery sa w AD zapisane, jak kto lubi: "+48123456789", "123456789", "+48 12 345 67 89",
    "12-345-67-89". LDAP nie umie ich znormalizowac przed porownaniem, wiec robimy to sami
    - po obu stronach, i dopiero wtedy porownujemy.

    Klasa [^0-9], a nie \D: \d w .NET obejmuje takze cyfry spoza alfabetu lacinskiego,
    wiec \D przepuscilaby je do wzorca zapytania.
#>
function Get-JezykCyfry {
    param([string]$Tekst)

    if ($null -eq $Tekst) { return '' }
    return ($Tekst -replace '[^0-9]', '')
}

<#
.SYNOPSIS
    Czy wpisany tekst to numer telefonu, a nie login ani nazwisko?

.DESCRIPTION
    Od tej odpowiedzi zalezy, czy do wyszukiwania dolozy sie zapytanie po numerze. Musi
    wiec byc WASKA: gdyby przepuszczala zwykle wpisy, kazde wyszukanie po nazwisku
    ciagneloby za soba dodatkowe, kosztowne przeszukanie katalogu bez indeksu.

    Poza cyframi dopuszczamy WYLACZNIE znaki, ktorymi ludzie rozdzielaja numer. Login,
    nazwisko i adres e-mail maja litery, wiec odpadaja od razu.

    Dolna granica szesciu cyfr odsiewa numery wewnetrzne i przypadkowe ciagi ("2024"),
    gorna pietnastu jest granica z normy E.164 - dluzszy ciag numerem juz nie jest.
#>
function Test-JezykWygladaNaTelefon {
    param([string]$Tekst)

    if ($null -eq $Tekst) { return $false }
    $tekst = $Tekst.Trim()
    if (-not $tekst) { return $false }

    if ($tekst -notmatch '^[0-9+()\s./-]+$') { return $false }

    $cyfry = Get-JezykCyfry $tekst
    return ($cyfry.Length -ge 6 -and $cyfry.Length -le 15)
}

<#
.SYNOPSIS
    Czy dwa numery opisuja ten sam telefon, mimo innego zapisu?

.DESCRIPTION
    Porownujemy SAME CYFRY i tylko tyle koncowych, ile ma krotszy z numerow. Dzieki temu
    kod kraju przestaje przeszkadzac i dziala to w OBIE strony: szukane "123456789" trafia
    w zapisane "+48 123 456 789", a szukane "+48123456789" trafia w zapisane "123456789".

    SWIADOMA CENA: dluzszy numer konczacy sie tymi samymi cyframi przejdzie. Rozroznienie
    prawdziwego kodu kraju od przypadkowego przedrostka wymagaloby tablicy kodow, ktorej
    tu nie ma. Kosztem falszywego trafienia jest JEDEN dodatkowy wiersz na liscie wyboru,
    podpisany imieniem i nazwiskiem; kosztem trafienia przeoczonego jest cale wyszukiwanie,
    ktore nie znalazlo szukanej osoby. Wybieramy tansza pomylke.

    Prog szesciu cyfr jest ten sam co w Test-JezykWygladaNaTelefon: krotsze ciagi zgadzaja
    sie zbyt czesto przypadkiem.
#>
function Test-JezykNumerPasuje {
    param([string]$Szukane, [string]$Numer)

    $a = Get-JezykCyfry $Szukane
    $b = Get-JezykCyfry $Numer
    if (-not $a -or -not $b) { return $false }

    $dlugosc = [math]::Min($a.Length, $b.Length)
    if ($dlugosc -lt 6) { return $false }

    return ($a.Substring($a.Length - $dlugosc) -eq $b.Substring($b.Length - $dlugosc))
}

<#
.SYNOPSIS
    Sprawdza konfiguracje z SEKCJI 1. Zwraca liste zastrzezen - pusta, gdy jest dobrze.

.DESCRIPTION
    Sprawdzamy wartosci wyznaczajace ADRESY polaczen: domeny ida do parametru -Server,
    serwer lokacji do sesji WMI, kontrolery do sciezki LDAP. Zwracamy LISTE, a nie pierwszy
    blad - kto poprawia konfiguracje, woli zobaczyc wszystkie literowki naraz.
#>
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

    # Wpis wskazujacy domene spoza listy znaczy, ze ktos zamierzal wlaczyc zapis gdzie
    # indziej, niz sadzi. Przy jedynej operacji zapisu nie ma miejsca na domysly.
    foreach ($domena in @($Script:DomenyZOdblokowaniem)) {
        if ($domeny -notcontains $domena) {
            $bledy += 'DomenyZOdblokowaniem: "{0}" nie ma na liście Domeny - odblokowanie nie zadziała.' -f $domena
        }
    }

    foreach ($kontroler in @($Script:Ustawienia.Kontrolery)) {
        if (-not $kontroler) { continue }
        if (-not (Test-JezykNazwaWDomenach $kontroler $domeny)) {
            $bledy += 'Kontrolery: "{0}" nie należy do żadnej z domen z listy Domeny.' -f $kontroler
        }
    }

    # Poddrzewo jest opcjonalne: brak wpisu to poprawny stan "szukaj od korzenia domeny".
    # Wpis BLEDNY juz nie: -SearchBase z niepoprawna nazwa wyrozniajaca wywraca zapytanie,
    # a jedynym objawem bylaby notka "przeszukanie numerow sie nie powiodlo" przy KAZDYM
    # numerze - czyli usterka wygladajaca na awarie sieci.
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
        # Wartosc inna niz logiczna zachowywalaby sie jak $true po cichu, a wlacza droge
        # sieciowa, ktorej nikt nie zamawial.
        if ($Script:Ustawienia.SccmProtokolZapasowy -isnot [bool]) {
            $bledy += 'SccmProtokolZapasowy: ma być $true albo $false.'
        }
    }

    return @($bledy)
}

# Rozbiera wyjatek na jednowierszowy komunikat do pola Status i pelna tresc pod przycisk "!".
# Do pola bierzemy PIERWSZA linie, bo wyjatki AD potrafia miec kilka zdan, a pole ma
# jeden wiersz. Typ wyjatku zostaje w szczegolach - bywa potrzebny, gdy komunikat systemowy
# jest niejednoznaczny.
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

# CanonicalName ma postac "jezyk.pl/Uzytkownicy/Dzial IT/Jan Kowalski". Obcinamy ostatni
# czlon i zostaje sam katalog - forma czytelna dla czlowieka, nie tylko dla LDAP-a.
function Get-JezykKatalogZeSciezki {
    param([string]$Kanoniczna)

    if ([string]::IsNullOrWhiteSpace($Kanoniczna)) { return '' }
    $ostatniUkosnik = $Kanoniczna.LastIndexOf('/')
    if ($ostatniUkosnik -le 0) { return '' }
    return $Kanoniczna.Substring(0, $ostatniUkosnik)
}

# Polska odmiana rzeczownika po liczbie: 1 konto, 2 konta, 5 kont. Nastki (12-14) ida jak
# 5 i wiecej, mimo ze koncza sie cyfra z przedzialu 2-4 - stad drugi warunek.
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

# Imie i nazwisko do pokazania. DisplayName bywa puste, choc imie i nazwisko w AD sa -
# wtedy skladamy je sami. Jedna funkcja, bo ta sama regula obowiazuje na liscie wyboru
# i w widoku konta, a dwie kopie moglyby pokazac co innego.
function Get-JezykOsoba {
    param([string]$Wyswietlana, [string]$Imie, [string]$Nazwisko)

    if ($Wyswietlana) { return $Wyswietlana }
    return (('{0} {1}' -f $Imie, $Nazwisko).Trim())
}

<#
.SYNOPSIS
    Buduje obiekt wyniku. Jedyne miejsce, ktore definiuje jego ksztalt.

.DESCRIPTION
    Wszystkie sciezki - konto znalezione, nieznalezione, pusty login, blad lacznosci -
    przechodza przez ta funkcje, wiec warstwa renderujaca zawsze dostaje te same pola.

    LockedOut i Enabled sa CELOWO bez typu: [bool] zamienilby $null na $false, gubiac
    stan "nie wiadomo". Logika oddaje surowe dane, formatowanie zostaje po stronie GUI -
    stad osobne pola HasloWygasa i HasloNigdyNieWygasa zamiast jednego.
#>
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

        [string]$Lokalizacja = '',
        $ZmianaHaslaWymuszona = $null,
        $HasloWygasa          = $null,
        $HasloNigdyNieWygasa  = $null,
        $OstatniaZmianaHasla  = $null,
        $KontoWygasa          = $null,
        $KontoUtworzono       = $null,

        $OstatnieLogowaniePrzyblizone = $null,
        [string]$Dn = '',

        # Nazwa obiektu w AD (atrybut Name, czyli cn). Wypelniana dla kontaktow, ktore nie
        # maja loginu - okno pokazuje ja wtedy w polu przemianowanym z "Login" na "Nazwa".
        [string]$NazwaObiektu = '',

        [string]$Szczegoly = ''
    )

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

        # OBA NUMERY OSOBNO, SUROWO. Sklejenie ich w jeden napis nalezy do widoku - to
        # czysta decyzja o wygladzie i nie wymaga pytania do katalogu. Przelozony jest tu
        # inaczej: przychodzi jako nazwa wyrozniajaca, a jej rozwiazanie na czytelny podpis
        # to OSOBNE zapytanie do AD, wiec musi zapasc tutaj i schodzi nizej juz gotowe.
        TelefonGlowny    = $TelefonGlowny
        TelefonKomorkowy = $TelefonKomorkowy

        Menedzer = $Menedzer

        Lokalizacja = $Lokalizacja

        # $true = uzytkownik musi zmienic haslo przy najblizszym logowaniu (pwdLastSet = 0).
        ZmianaHaslaWymuszona = $ZmianaHaslaWymuszona

        HasloWygasa         = $HasloWygasa
        HasloNigdyNieWygasa = $HasloNigdyNieWygasa

        OstatniaZmianaHasla = $OstatniaZmianaHasla

        # $null znaczy tu "konto nigdy nie wygasa" - tak AD zwraca konto bez daty waznosci.
        KontoWygasa = $KontoWygasa

        KontoUtworzono = $KontoUtworzono

        # lastLogonTimestamp - przychodzi w tym samym zapytaniu co reszta konta, wiec jest
        # widoczny natychmiast. Zadanie w tle tylko go uscisla.
        OstatnieLogowaniePrzyblizone = $OstatnieLogowaniePrzyblizone

        # DistinguishedName oszczedza zadaniu w tle rozwiazywania nazwy konta na kazdym
        # kontrolerze z osobna.
        Dn = $Dn

        NazwaObiektu = $NazwaObiektu

        Szczegoly = $Szczegoly
    }
}

<#
.SYNOPSIS
    Odczyt atrybutu lastLogon z JEDNEGO kontrolera domeny.

.DESCRIPTION
    Surowy odczyt LDAP zamiast Get-ADUser: majac DistinguishedName z pierwszego zapytania
    wiemy dokladnie, co czytac - wystarczy odczyt o zakresie Base po jeden atrybut.

    Wynik rozroznia trzy rzeczy: $null = kontroler nie odpowiedzial, 0 = odpowiedzial, ale
    nigdy nie obsluzyl logowania tego konta, > 0 = znacznik czasu FILETIME.
#>
function Get-JezykLastLogonZKontrolera {
    param([string]$Kontroler, [string]$Dn = '', [string]$Login = '', [int]$LimitMs = 2500)

    # Sprawdzenie PRZED pierwszym uzyciem wartosci - takze przed droga zapasowa nizej,
    # ktora oddaje nazwe wprost do parametru -Server.
    if (-not (Test-JezykNazwaHosta $Kontroler)) { return $null }

    # Bez DN zostaje droga zapasowa przez modul AD: wolniejsza, ale dziala wtedy, gdy
    # pierwsze zapytanie nie oddalo DistinguishedName.
    if (-not $Dn) {
        try {
            $konto = Get-ADUser -Identity $Login -Server $Kontroler -Properties lastLogon -ErrorAction Stop
            if ($null -eq $konto.lastLogon) { return 0L }
            return [int64]$konto.lastLogon
        }
        catch { return $null }
    }

    if (-not (Test-JezykDn $Dn)) { return $null }

    $wejscie = $null
    $szukacz = $null
    try {
        # Ukosnik w DN (nazwy typu "Kowalski/Nowak") rozdzielilby sciezke ADsPath w zlym
        # miejscu, wiec go poprzedzamy odwrotnym.
        $sciezka = 'LDAP://{0}/{1}' -f $Kontroler, ($Dn -replace '/', '\/')

        # Zadamy podpisania i zaszyfrowania kanalu. Bez tego atrybut i pelna nazwa
        # wyrozniajaca ida po porcie 389 jawnym tekstem, a na kontrolerach z wymuszonym
        # podpisywaniem LDAP bind bywa odrzucany - i odmowa wyglada jak milczacy kontroler.
        $uwierzytelnienie = [System.DirectoryServices.AuthenticationTypes]::Secure -bor
                            [System.DirectoryServices.AuthenticationTypes]::Sealing -bor
                            [System.DirectoryServices.AuthenticationTypes]::Signing

        # Puste poswiadczenia = kontekst zalogowanego uzytkownika. Poswiadczenia z okna
        # logowania nie trafiaja tu nigdy.
        $wejscie = New-Object System.DirectoryServices.DirectoryEntry(
                       $sciezka, $null, $null, $uwierzytelnienie)
        $szukacz = New-Object System.DirectoryServices.DirectorySearcher($wejscie)
        $szukacz.SearchScope   = [System.DirectoryServices.SearchScope]::Base
        $szukacz.Filter        = '(objectClass=*)'
        $szukacz.ClientTimeout = [timespan]::FromMilliseconds($LimitMs)
        [void]$szukacz.PropertiesToLoad.Add('lastLogon')

        $trafienie = $szukacz.FindOne()
        if (-not $trafienie) { return $null }

        $wartosci = $trafienie.Properties['lastlogon']
        if (-not $wartosci -or $wartosci.Count -eq 0) { return 0L }

        # Zwykle wraca Int64, ale przy niektorych dostawcach obiekt COM IADsLargeInteger,
        # ktorego nie da sie rzutowac. Wtedy skladamy liczbe z dwoch polowek; dolna jest
        # bez znaku, stad rzutowanie przez UInt32 - bez niego polowa dat wychodzi ujemna.
        $surowa = $wartosci[0]
        if ($surowa -is [int64]) { return $surowa }
        try { return [int64]$surowa } catch { }
        try {
            $typ    = $surowa.GetType()
            $wysoka = $typ.InvokeMember('HighPart', 'GetProperty', $null, $surowa, $null)
            $niska  = $typ.InvokeMember('LowPart',  'GetProperty', $null, $surowa, $null)
            return ([int64]$wysoka -shl 32) + [int64][uint32]$niska
        }
        catch { return $null }
    }
    catch { return $null }
    finally {
        if ($szukacz) { try { $szukacz.Dispose() } catch { } }
        if ($wejscie) { try { $wejscie.Dispose() } catch { } }
    }
}

<#
.SYNOPSIS
    Wywoluje jedna funkcje dla wielu wartosci ROWNOLEGLE, z terminem na calosc.

.DESCRIPTION
    Przestrzenie w puli startuja PUSTE i nie widza funkcji z naszej sesji - wstrzykujemy
    je jako tekst. Wolajacy podaje KOMPLET funkcji, ktorych zadanie potrzebuje: pominiecie
    ktorejkolwiek konczy zadanie wyjatkiem "nie rozpoznano nazwy polecenia" WEWNATRZ
    przestrzeni, a wolajacy widzi to jako brak odpowiedzi. Objawem jest cisza, nie blad.

    Termin dotyczy CALOSCI - jeden martwy kontroler nie moze zatrzymac pozostalych.
#>
function Invoke-JezykRownolegle {
    param(
        [string[]]$Wartosci,
        [string[]]$Funkcje,
        [string]$Wywolanie,
        [object[]]$Argumenty = @(),
        [int]$LimitMs = 6000,
        [int]$LimitRownoleglosci = 12
    )

    $wyniki = @{}
    if (@($Wartosci).Count -eq 0) { return $wyniki }

    $definicja = ''
    foreach ($nazwa in @($Funkcje)) {
        $definicja += "function $nazwa {`r`n" + (Get-Command $nazwa).Definition + "`r`n}`r`n"
    }
    $tresc = $definicja + $Wywolanie

    $pula = [runspacefactory]::CreateRunspacePool(1, [math]::Max(1, [math]::Min(@($Wartosci).Count, $LimitRownoleglosci)))
    $pula.Open()

    $zadania = @()
    try {
        foreach ($wartosc in $Wartosci) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pula
            # Wartosci ida przez AddArgument, nie do tekstu skryptu - to jedyne miejsce
            # w narzedziu, gdzie kod powstaje z lancucha znakow.
            [void]$ps.AddScript($tresc).AddArgument($wartosc)
            foreach ($arg in $Argumenty) { [void]$ps.AddArgument($arg) }
            $zadania += [pscustomobject]@{ Wartosc = $wartosc; Ps = $ps; Uchwyt = $ps.BeginInvoke() }
        }

        $zegar = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($zadanie in $zadania) {
            $pozostalo = $LimitMs - $zegar.ElapsedMilliseconds
            if ($pozostalo -gt 0 -and -not $zadanie.Uchwyt.IsCompleted) {
                [void]$zadanie.Uchwyt.AsyncWaitHandle.WaitOne([int]$pozostalo, $false)
            }
            if (-not $zadanie.Uchwyt.IsCompleted) { continue }
            try   { $wyniki[$zadanie.Wartosc] = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))[0] }
            catch { }
        }
    }
    finally {
        foreach ($zadanie in $zadania) { try { $zadanie.Ps.Dispose() } catch { } }
        try { $pula.Close(); $pula.Dispose() } catch { }
    }

    return $wyniki
}

<#
.SYNOPSIS
    Dokladna data ostatniego logowania - najpozniejsza wartosc ze wszystkich kontrolerow.

.DESCRIPTION
    lastLogonTimestamp jest replikowany, ale odswiezany celowo co 9-14 dni. lastLogon jest
    dokladny co do sekundy, ale NIE replikowany - kazdy kontroler zna tylko te logowania,
    ktore sam obsluzyl. Prawdziwa data to najpozniejszy lastLogon ze wszystkich.

    Lista kontrolerow przychodzi z zewnatrz, bo ich rozpoznanie kosztuje osobne zapytanie,
    a zmieniaja sie raz na wiele miesiecy. Uruchamiane w tle, nigdy na watku interfejsu.
#>
function Get-JezykOstatnieLogowanie {
    param([string]$Login, [string]$Domena, [string]$Dn = '',
          [string[]]$Kontrolery = @(), [int]$LimitMsLacznie = 6000,
          # 1 = po kolei; testy logiki ustawiaja 1, zeby sprawdzac WYBOR najpozniejszej daty.
          [int]$LimitRownoleglosci = 12)

    $wynik = [pscustomobject]@{ Data = $null; Odpytane = 0; Wszystkie = 0
                                Kontrolery = @(); Odrzucone = @() }

    $lista = @($Kontrolery | Where-Object { $_ })
    if ($lista.Count -eq 0) {
        try {
            $lista = @(Get-ADDomainController -Filter * -Server $Domena -ErrorAction Stop |
                       Select-Object -ExpandProperty HostName)
        }
        catch { return $wynik }
    }

    # Sprawdzenie ksztaltu RAZ, tutaj, zanim cokolwiek pojdzie do przestrzeni w tle.
    # Nazwa odrzucona w tle bylaby nieodroznialna od kontrolera, ktory nie odpowiedzial,
    # a to zupelnie inne sytuacje - odrzucone trafiaja wiec do osobnego pola.
    $odrzucone = @($lista | Where-Object { -not (Test-JezykNazwaHosta $_) })
    $lista     = @($lista | Where-Object { Test-JezykNazwaHosta $_ })

    $wynik.Odrzucone  = $odrzucone
    $wynik.Kontrolery = $lista
    $wynik.Wszystkie  = $lista.Count
    if ($lista.Count -eq 0) { return $wynik }

    $najnowsze = 0L

    # Rownolegle: czas przestaje rosnac z liczba kontrolerow i schodzi do czasu
    # najwolniejszego z nich.
    if ($lista.Count -gt 1 -and $LimitRownoleglosci -gt 1) {
        # KOMPLET funkcji, ktorych potrzebuje Get-JezykLastLogonZKontrolera. Pominiecie
        # ktorejkolwiek nie daje bledu przy starcie, tylko ciszy - patrz Invoke-JezykRownolegle.
        $odpowiedzi = Invoke-JezykRownolegle -Wartosci $lista `
                          -Funkcje   'Test-JezykNazwaHosta', 'Test-JezykDn', 'Get-JezykLastLogonZKontrolera' `
                          -Wywolanie 'Get-JezykLastLogonZKontrolera -Kontroler $args[0] -Dn $args[1] -Login $args[2]' `
                          -Argumenty @($Dn, $Login) `
                          -LimitMs   $LimitMsLacznie `
                          -LimitRownoleglosci $LimitRownoleglosci

        foreach ($kontroler in $lista) {
            if (-not $odpowiedzi.ContainsKey($kontroler)) { continue }
            $wartosc = $odpowiedzi[$kontroler]
            if ($null -eq $wartosc) { continue }
            $wynik.Odpytane++
            if ($wartosc -gt $najnowsze) { $najnowsze = [int64]$wartosc }
        }
    }
    else {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($kontroler in $lista) {
            if ($zegar.ElapsedMilliseconds -gt $LimitMsLacznie) { break }

            $wartosc = Get-JezykLastLogonZKontrolera -Kontroler $kontroler -Dn $Dn -Login $Login
            if ($null -eq $wartosc) { continue }

            $wynik.Odpytane++
            if ($wartosc -gt $najnowsze) { $najnowsze = [int64]$wartosc }
        }
    }

    if ($najnowsze -gt 0) {
        try   { $wynik.Data = [datetime]::FromFileTime($najnowsze) }
        catch { $wynik.Data = $null }
    }

    return $wynik
}

<#
.SYNOPSIS
    Czy na wskazanym hoscie odpowiada port, ktorym pojdzie zapytanie?

.DESCRIPTION
    NAJWAZNIEJSZA ZAPORA CZASOWA W CALYM NARZEDZIU. Polaczenie DCOM z milczacym hostem
    wisi w RPC dziesiatki sekund do kilku minut i NIE DA SIE GO PRZERWAC: -OperationTimeoutSec
    dotyczy operacji, a nie zestawiania sesji, a zatrzymanie zadania w tle dochodzi do
    skutku dopiero wtedy, gdy RPC samo odpusci. Kilkanascie takich zwisow naraz wyczerpuje
    pule watkow procesu i okno przestaje odpowiadac.

    Sonda zamyka to pytanie w poltorej sekundy. Sam fakt otwartego portu niczego nie
    obiecuje - odpowiedz "nie" jest jednak pewna i tylko o nia tu chodzi.

    ROZWIAZANIE NAZWY IDZIE OSOBNO I MA WLASNY TERMIN. BeginConnect z NAZWA hosta rozwiazuje
    ja SYNCHRONICZNIE, zanim w ogole zacznie laczenie - termin nalozony na polaczenie nie
    obejmuje wiec ani jednej milisekundy odpytania DNS. Ta sama pulapka zamrozila juz raz
    okno Jezyka i jest opisana w README, rozdzial "Pulapki, ktore psuly ten kod".

    Termin jest LACZNY dla obu krokow, bo wolajacego obchodzi calkowity czas sondy,
    a nie to, ktory z krokow go zjadl.
#>
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

        # ADRESY, nie nazwa: nazwa jest juz rozwiazana i nie ma czego rozwiazywac drugi raz.
        $uchwyt = $klient.BeginConnect($adresy, $Port, $null, $null)

        # WaitOne z terminem, a nie EndConnect wprost: samo EndConnect czekaloby tyle,
        # ile zechce stos TCP.
        if (-not $uchwyt.AsyncWaitHandle.WaitOne([int]$pozostalo, $false)) { return $false }

        $klient.EndConnect($uchwyt)
        return $true
    }
    catch { return $false }
    finally { if ($klient) { try { $klient.Close() } catch { } } }
}

<#
.SYNOPSIS
    Nazywa przyczyne bledu WMI i podaje wykonalna naprawe.

.DESCRIPTION
    Wczesniej cztery zupelnie rozne sytuacje - zla przestrzen nazw, brak uprawnien,
    zablokowany DCOM i nieosiagalny host - konczyly sie tym samym napisem "brak dostepu
    do SCCM". Z takiego komunikatu nie da sie wyczytac, co poprawic.

    Rozpoznajemy NAJPIERW po kodzie bledu, a dopiero potem po tresci: kody nie zaleza od
    jezyka systemu, a tresc na polskim Windowsie brzmi inaczej niz na angielskim.
#>
function Get-JezykOpisBleduWmi {
    param($Wyjatek, [string]$Serwer = '', [string]$Przestrzen = '', [string]$Protokol = '',
          [ValidateSet('', 'Polaczenie', 'Zapytanie')][string]$Etap = '')

    $tresc = if ($Wyjatek -and $Wyjatek.Exception) { [string]$Wyjatek.Exception.Message } else { [string]$Wyjatek }
    $tresc = ([string]$tresc).Trim()
    if (-not $tresc) { $tresc = 'brak treści błędu' }

    # NativeErrorCode jest wyliczeniem CIM, nie tekstem - nie zalezy od jezyka systemu.
    # Pod wlasnym try, bo niosa je tylko wyjatki CIM, a tutaj trafiaja rowniez inne.
    $kodCim = ''
    try {
        if ($Wyjatek.Exception -and $Wyjatek.Exception.PSObject.Properties['NativeErrorCode']) {
            $kodCim = [string]$Wyjatek.Exception.NativeErrorCode
        }
    }
    catch { }

    # 0x80131500 to COR_E_EXCEPTION - generyczna wartosc .NET nadawana kazdemu wyjatkowi,
    # ktory nie ustawil wlasnego HResult. CimException zostawia ja czesto bez zmian, wiec
    # ten konkretny kod NIE OPISUJE bledu WMI - jest szumem obok prawdziwej przyczyny
    # (ktora niesie kodCim). Pokazanie go wygladaloby na trop, a byloby pusta wydmuszka.
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

        # Odmowa przy SAMYM POLACZENIU (przed dotknieciem root\sms) i odmowa przy
        # ZAPYTANIU o konkretna przestrzen to DWIE ROZNE bramki zabezpieczen - pierwsza
        # zalezy od transportu (DCOM vs WinRM), druga jest wlasnoscia samej przestrzeni
        # nazw i taka sama dla obu protokolow. Bez rozroznienia rada byla ogolnikowa
        # i wskazywala dwa miejsca naraz, choc winne jest zwykle tylko jedno.
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

<#
.SYNOPSIS
    Zestawia JEDNA sesje WMI do serwera lokacji SCCM. Zwraca sesje albo opis porazki.

.DESCRIPTION
    Sesja jest jedna na cale zadanie. Wczesniej kazde zapytanie otwieralo wlasna, wiec
    najdrozszy krok - zestawienie polaczenia - byl placony tyle razy, ile bylo zapytan.

    Przed kazda proba idzie sonda portu; powod opisany przy Test-JezykPortOtwarty.

    Protokol zapasowy probuje TEJ SAMEJ nazwy serwera druga droga - zapasowy jest protokol,
    NIGDY adres. Ma to sens, bo prawo wstepu bywa nadane tylko jednej z dwoch drog: rola
    w ConfigMgr daje zdalna aktywacje DCOM, a wejscie przez WinRM wymaga osobnego
    czlonkostwa na serwerze lokacji.

    PROBUJEMY KAZDEGO PROTOKOLU, TAKZE PO ODMOWIE DOSTEPU NA PIERWSZYM. Odmowa przy
    zestawianiu polaczenia (brak prawa aktywacji DCOM) i odmowa zabezpieczen SAMEJ
    PRZESTRZENI NAZW to dwie osobne bramki - pierwsza zalezy od transportu, druga nie.
    Kod nie ma jak z gory rozstrzygnac, na ktora trafil, wiec zgadywanie i rezygnacja
    z drugiej proby bylyby zwyklym zalozeniem, nie faktem.
#>
function Open-JezykSesjaSccm {
    param([string]$Serwer, [string]$Protokol = 'Dcom', [bool]$Zapasowy = $false,
          [int]$LimitSek = 15, [int]$LimitSondyMs = 1500)

    $wynik = [pscustomobject]@{ Sesja = $null; Protokol = ''; Blad = ''; Szczegoly = '' }

    # Sprawdzenie PRZED pierwszym uzyciem nazwy - takze przed sonda, ktora oddaje ja
    # wprost do gniazda TCP.
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

    # Odmowa uprawnien zapamietywana OSOBNO od ostatniego opisu: to najbardziej konkretna
    # ze wszystkich mozliwych porazek (polaczenie doszlo do skutku, tylko dostep zostal
    # odrzucony), wiec ma pierwszenstwo przy koncowym komunikacie - nawet jesli druga proba
    # zawiedzie z zupelnie innego, mniej informatywnego powodu.
    $bladOdmowy = $null

    foreach ($proba in $kolejnosc) {
        $port = if ($proba -eq 'Wsman') { 5985 } else { 135 }

        if (-not (Test-JezykPortOtwarty -Serwer $Serwer -Port $port -LimitMs $LimitSondyMs)) {
            $powody += '{0}: port {1} nie odpowiedział w {2} ms' -f $proba, $port, $LimitSondyMs
            continue
        }

        try {
            # -SkipTestConnection JEST TU WARUNKIEM DZIALANIA, nie oszczednoscia czasu.
            # New-CimSession domyslnie weryfikuje polaczenie, ale ten test NIE idzie do
            # root\sms\site_XXX - idzie do domyslnej przestrzeni maszyny (root\cimv2).
            # W zamknietych srodowiskach to czesta asymetria: instalator SCCM nadaje prawa
            # grupie SMS Admins WPROST na root\sms, a nikt nie nadaje im praw do root\cimv2
            # ani ogolnej zdalnej aktywacji DCOM. Test przechodzil wiec przez bramke, ktorej
            # prawdziwe zapytanie nigdy by nie dotknelo - i to ON zwracal "Odmowa dostepu",
            # mimo ze konsola ConfigMgr z tego samego konta czytala dane bez problemu.
            # Konsola nie robi takiego testu: laczy sie prosto do root\sms i my teraz tez.
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
            # Etap 'Polaczenie': ta odmowa pada PRZED dotknieciem root\sms, wiec jesli to
            # ona, naprawa wskazuje prawo aktywacji DCOM, nie zabezpieczenia przestrzeni.
            $opis        = Get-JezykOpisBleduWmi $_ -Serwer $Serwer -Protokol $proba -Etap 'Polaczenie'
            $powody     += '{0}: {1}' -f $proba, $opis.Krotki
            $ostatniOpis = $opis.Szczegoly

            if ($opis.Krotki -eq 'brak uprawnień do SCCM') { $bladOdmowy = $opis }
        }
    }

    # Odmowa uprawnien na KTORYMKOLWIEK protokole jest bardziej wartosciowa niz ogolnikowe
    # "zadna droga nie dziala" - mowi wprost, ze polaczenie dziala i tylko dostep zostal
    # zablokowany, wiec zostaje ostatecznym wynikiem, choc druga proba mogla zawiesc inaczej.
    if ($bladOdmowy) {
        $wynik.Blad      = $bladOdmowy.Krotki
        $wynik.Szczegoly = if ($kolejnosc.Count -gt 1) {
            '{0}{1}{1}(wypróbowano też: {2})' -f $bladOdmowy.Szczegoly, [Environment]::NewLine, ($powody -join '; ')
        } else { $bladOdmowy.Szczegoly }
        return $wynik
    }

    # Sonda odrzucila wszystko: nie ma zadnego wyjatku do opisania, jest za to pewna
    # wiedza, ze zaden port nie odpowiedzial.
    if (-not $ostatniOpis) {
        $ostatniOpis = 'Żaden port nie odpowiedział, więc żadna sesja nie została nawet zestawiona. Zwykle znaczy to zaporę między stacją a serwerem lokacji albo złą nazwę serwera w SccmSerwer.'
    }

    $wynik.Blad      = 'brak połączenia z SCCM'
    $wynik.Szczegoly = @(('Żadna droga do serwera {0} nie doszła do skutku: {1}.' -f $Serwer, ($powody -join '; ')),
                         '', $ostatniOpis) -join [Environment]::NewLine
    return $wynik
}

# Jedno zapytanie na GOTOWEJ sesji. Termin nalozony takze tutaj, bo zawiesic sie potrafi
# samo zapytanie, nie tylko zestawienie sesji.
# Funkcja celowo nie lapie wyjatku: o tym, czy blad jest do pokazania, decyduje wolajacy.
function Invoke-JezykZapytanieWmi {
    param($Sesja, [string]$Przestrzen, [string]$Zapytanie, [int]$LimitSek = 15)

    Get-CimInstance -CimSession $Sesja -Namespace $Przestrzen -Query $Zapytanie `
                    -OperationTimeoutSec $LimitSek -ErrorAction Stop
}

<#
.SYNOPSIS
    To samo zapytanie, ale STARYM stosem WMI. Droga zapasowa po odmowie z CIM.

.DESCRIPTION
    To NIE jest "ten sam protokol jeszcze raz". Get-CimInstance idzie przez stos MI,
    a Get-WmiObject przez klasyczny COM/DCOM - ten sam, ktorego uzywa konsola ConfigMgr
    i wszystkie skrypty SCCM sprzed ery CIM. Bywa, ze jedno przechodzi, a drugie nie,
    bo autoryzacja i sciezka wywolania sa w obu zupelnie inne.

    BEZ TERMINU, i to jest swiadoma cena: Get-WmiObject nie ma odpowiednika
    -OperationTimeoutSec. Wolajacy odpala te droge WYLACZNIE po szybkiej, definitywnej
    odmowie z CIM - serwer jest wtedy znany jako odpowiadajacy, wiec zwis jest malo
    prawdopodobny, a gdyby jednak nastapil, zadanie w tle ma wlasna machinerie porzucania.

    Funkcja celowo nie lapie wyjatku: o tym, czy blad jest do pokazania, decyduje wolajacy.
#>
function Invoke-JezykZapytanieWmiStare {
    param([string]$Serwer, [string]$Przestrzen, [string]$Zapytanie)

    Get-WmiObject -ComputerName $Serwer -Namespace $Przestrzen -Query $Zapytanie -ErrorAction Stop
}

<#
.SYNOPSIS
    Jedno zapytanie do SCCM: najpierw stosem CIM, a po ODMOWIE - starym stosem WMI.

.DESCRIPTION
    Dwie drogi, bo autoryzacja w obu przebiega inaczej i jedna potrafi przejsc tam, gdzie
    druga odbija sie od odmowy. Stary stos jest tym, ktorego uzywa konsola ConfigMgr -
    a operator widzi w niej dane, ktorych Jezyk nie potrafil odczytac.

    Droga zapasowa odpala sie WYLACZNIE po odmowie uprawnien. Kazdy inny blad (zla
    przestrzen nazw, brak klasy, zerwane polaczenie) powtorzylby sie identycznie na drugim
    stosie, wiec druga proba byloby tylko marnowaniem czasu operatora.

    Gdy zawioda obie, wraca opis z PIERWSZEJ proby: to on niesie rozpoznana przyczyne.
#>
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
        # Etap 'Zapytanie': polaczenie juz stoi, wiec odmowa dotyczy KONKRETNIE tej
        # przestrzeni nazw, a nie prawa aktywacji DCOM.
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

# Ustawienia polaczenia z SCCM przepisane z konfiguracji, bez zadnego rozpoznawania.
# Kod lokacji trafia do NAZWY PRZESTRZENI NAZW, wiec musi byc dokladnie trzyznakowy;
# nazwa serwera przechodzi te sama biala liste co kazda inna nazwa hosta, zeby literowka
# dala komunikat o literowce, a nie o nieosiagalnym serwerze.
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

<#
.SYNOPSIS
    Sprowadza znacznik czasu z SCCM do czasu LOKALNEGO stacji.

.DESCRIPTION
    SCCM trzyma znaczniki aktywnosci w UTC, a Jezyk pokazywal je bez przeliczenia - stad
    zgloszenie "zalogowalem sie o 6:20, a w polu jest 4:56". Roznica nie byla przypadkowa:
    4:56 UTC to 6:56 czasu lokalnego, czyli puls klienta 36 minut po zalogowaniu. Wartosc
    byla wiec poprawna, tylko podana w cudzej strefie.

    CZTERY KSZTALTY, w jakich ta sama data potrafi przyjsc, i kazdy wymaga czego innego:
      - [datetime] Kind = Utc          (Get-CimInstance)  -> przeliczamy na lokalny,
      - [datetime] Kind = Local        (juz przeliczony)  -> zostawiamy,
      - [datetime] Kind = Unspecified  (czesc instalacji) -> TRAKTUJEMY JAK UTC, bo tak
        SCCM te pola przechowuje; brak znacznika strefy nie znaczy "czas lokalny",
      - lancuch DMTF "20260827065600.000000+120" (droga zapasowa przez Get-WmiObject).

    Ostatni kszalt naprawia DRUGA, dotad niewidoczna usterke: rzutowanie [datetime] na
    lancuchu DMTF wywalalo sie do catch i data po prostu znikala. Lancuch rozkladamy
    SAMI, zamiast przez ManagementDateTimeConverter: przestrzen w tle startuje pusta,
    wiec typ z System.Management moze sie w niej nie rozwiazac, a wtedy data znikalaby
    tak samo cicho jak przedtem.

    Nie rzuca wyjatkiem: wartosc nie do odczytania to $null, czyli "bez daty" - a to stan,
    ktory wolajacy juz obsluguje.
#>
function ConvertTo-JezykCzasLokalny {
    param($Wartosc)

    if ($null -eq $Wartosc) { return $null }

    if ($Wartosc -isnot [datetime]) {
        $tekst = ([string]$Wartosc).Trim()
        if (-not $tekst) { return $null }

        # DMTF niesie WLASNE przesuniecie strefy (ostatnie trzy cyfry to minuty od UTC),
        # wiec rozwiazuje sie w calosci tutaj i nie przechodzi przez galaz Kind nizej.
        if ($tekst -match '^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\.(\d{6})([+-])(\d{3})$') {
            try {
                # Mikrosekundy na takty: jeden takt to 100 nanosekund.
                $utc = [datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3],
                                       [int]$Matches[4], [int]$Matches[5], [int]$Matches[6],
                                       [System.DateTimeKind]::Utc).AddTicks([long]$Matches[7] * 10)

                # Zapis jest czasem LOKALNYM serwera, wiec do UTC idziemy w DRUGA strone
                # niz mowi znak przesuniecia.
                $minuty = [int]$Matches[9]
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

<#
.SYNOPSIS
    Odrebne konta widoczne na maszynie wg CurrentLogonUser/LastLogonUser/PrimaryUser.

.DESCRIPTION
    Trzy pola bywaja zapisane raz jako "konto", raz jako "DOMENA\konto", a PrimaryUser
    dodatkowo bywa LISTA kont oddzielonych przecinkami - porownanie idzie wiec po nazwie
    konta bez przedrostka domeny i bez wzgledu na wielkosc liter. Wiecej niz jedno odrebne
    konto znaczy, ze maszyna jest wspoldzielona: pokazana data aktywnosci moze wtedy
    dotyczyc zupelnie innej osoby niz ta, ktorej szukamy.

    Czysta funkcja bez zaleznosci od SCCM/CIM - latwa do przetestowania bez atrapowania
    calej sesji.
#>
function Get-JezykKontaMaszyny {
    param($Wiersz)

    $konta    = New-Object System.Collections.Generic.List[string]
    $widziane = @{}
    $surowe   = @([string]$Wiersz.CurrentLogonUser, [string]$Wiersz.LastLogonUser) +
                @(([string]$Wiersz.PrimaryUser) -split ',')

    foreach ($wpis in $surowe) {
        $czysty = $wpis.Trim()
        if (-not $czysty) { continue }

        $bezDomeny = ($czysty -split '\\')[-1]
        $klucz     = $bezDomeny.ToLowerInvariant()
        if ($widziane.ContainsKey($klucz)) { continue }

        $widziane[$klucz] = $true
        $konta.Add($bezDomeny)
    }

    # Przecinek wymuszony: bez niego PowerShell rozpakowuje tablice 0/1-elementowa przy
    # zwrocie z funkcji, a wolajacy dostaje $null albo goly string zamiast tablicy.
    return ,$konta.ToArray()
}

<#
.SYNOPSIS
    Ostatnio uzywany komputer - z inwentaryzacji SCCM, bo AD tego nie przechowuje.

.DESCRIPTION
    W AD nie ma takiego atrybutu: lastLogon mowi KIEDY, nigdy GDZIE. SCCM ma to wprost -
    kazdy komputer raportuje LastLogonUserName. Stad nazwa pola "ostatnio uzywany",
    a nie "zalogowany": to ostatni uzytkownik maszyny wedlug inwentaryzacji.

    Data pochodzi z LastActiveTime w SMS_CombinedDeviceResources, a NIE z
    SMS_R_System.LastLogonTimestamp - tamto pole to moment uwierzytelnienia konta
    komputera w domenie i pod nazwa komputera wygladaloby jak data pracy uzytkownika.

    Wspoldzielony/SzczegolyWspoldzielenia dziala wylacznie, gdy trafilo pierwsze zrodlo
    (SMS_CombinedDeviceResources) - tylko ono niesie CurrentLogonUser/LastLogonUser/
    PrimaryUser w wierszu wyniku, patrz Get-JezykKontaMaszyny.
#>
function Get-JezykOstatnioUzywanyKomputer {
    param([string]$Login, [string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom',
          [bool]$ProtokolZapasowy = $false, [int]$LimitSek = 15)

    # Odpowiada i Adres wypelnia sonda ICMP na samym koncu, po ustaleniu nazwy maszyny.
    # $null w Odpowiada znaczy "nie sprawdzono albo nie wiadomo" i tak ma zostac na kazdej
    # sciezce bledu - patrz Get-JezykPingKomputera.
    $wynik = [pscustomobject]@{ Nazwa = ''; Data = $null; Odpowiada = $null; Adres = ''
                                Blad = ''; Szczegoly = ''
                                Wspoldzielony = $false; SzczegolyWspoldzielenia = '' }

    # Login pochodzi z AD, wiec jest bezpieczny - ale zapytanie budowane z tekstu sprawdza
    # sie ZAWSZE, a nie tylko wtedy, gdy wyglada to na potrzebne.
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

    # Wzorzec LIKE ma WLASNY zestaw znakow o znaczeniu skladniowym: \ jest znakiem ucieczki,
    # a % _ [ sa wieloznaczne. Podkreslenie PRZECHODZI biala liste nazw kont, wiec bez tego
    # "jan_k" pasowalby takze do "jan1k" i wynik potrafilby wskazac cudza maszyne.
    $doWzorca = $bezpieczny -replace '([\\%_\[])', '\$1'

    $sesja = Open-JezykSesjaSccm -Serwer   $polaczenie.Serwer `
                                 -Protokol $polaczenie.Protokol `
                                 -Zapasowy $ProtokolZapasowy `
                                 -LimitSek $LimitSek
    if (-not $sesja.Sesja) {
        $wynik.Blad      = $sesja.Blad
        $wynik.Szczegoly = $sesja.Szczegoly
        return $wynik
    }

    # Wszystko ponizej idzie na JEDNEJ sesji, a finally ja zamyka - takze przy porzuceniu
    # zadania w polowie.
    try {
        # TRZY ZRODLA, w kolejnosci od najblizszego temu, CO OPERATOR WIDZI W KONSOLI.
        #
        # SMS_CombinedDeviceResources jest pierwsza nie bez powodu: to wlasnie ta klasa
        # zasila wezel "Devices" w konsoli ConfigMgr. Operator wpisuje tam login i widzi
        # komputer - my dlugo pytalismy o SMS_R_System.LastLogonUserName, czyli o INNE POLE
        # Z INNEGO ZRODLA (rekord odkrycia, odswiezany rzadziej), i dlatego nie znajdowalismy
        # tego, co konsola pokazuje bez trudu. Ta klasa niesie od razu Name i LastActiveTime,
        # wiec przy trafieniu nie ma juz osobnego zapytania o date.
        #
        # Nazwy uzytkownika bywaja zapisane jako "konto" albo "DOMENA\konto", stad kazde
        # pole sprawdzane na oba sposoby. PrimaryUser potrafi byc LISTA kont oddzielonych
        # przecinkami - tam dopasowanie musi byc fragmentem.
        $zrodla = @(
            @{ Nazwa = 'SMS_CombinedDeviceResources (widok "Devices" w konsoli)'
               Wql   = "SELECT ResourceID, Name, LastActiveTime, CurrentLogonUser, LastLogonUser, PrimaryUser " +
                       "FROM SMS_CombinedDeviceResources " +
                       "WHERE CurrentLogonUser = '$bezpieczny' OR CurrentLogonUser LIKE '%\\$doWzorca' " +
                       "OR LastLogonUser = '$bezpieczny' OR LastLogonUser LIKE '%\\$doWzorca' " +
                       "OR PrimaryUser LIKE '%$doWzorca%'" }

            @{ Nazwa = 'SMS_R_System.LastLogonUserName'
               Wql   = "SELECT ResourceId, Name, NetbiosName FROM SMS_R_System " +
                       "WHERE LastLogonUserName = '$bezpieczny' OR LastLogonUserName LIKE '%\\$doWzorca'" }

            @{ Nazwa = 'SMS_G_System_COMPUTER_SYSTEM.UserName'
               Wql   = "SELECT ResourceID, Name FROM SMS_G_System_COMPUTER_SYSTEM " +
                       "WHERE UserName LIKE '%\\$doWzorca'" }
        )

        $maszyny   = @()
        $zrodlo    = ''
        $stos      = 'CIM'
        $odmowa    = $null
        $niedostepne = @()

        foreach ($z in $zrodla) {
            $odp = Invoke-JezykZapytanieSccm -Sesja $sesja.Sesja -Serwer $polaczenie.Serwer `
                                             -Przestrzen $przestrzen -Zapytanie $z.Wql `
                                             -Protokol $sesja.Protokol -LimitSek $LimitSek

            if ($odp.Blad) {
                # TYLKO brak samej klasy jest problemem JEDNEGO zrodla - inna wersja
                # ConfigMgr albo wylaczona inwentaryzacja. Wtedy pozostale klasy maja sens
                # i szukamy dalej.
                if ($odp.Blad.Krotki -eq 'brak klasy w SCCM') {
                    $niedostepne += '{0}: {1}' -f $z.Nazwa, $odp.Blad.Krotki
                    continue
                }

                # Kazdy inny blad (brak uprawnien, zla przestrzen nazw, zerwane polaczenie)
                # dotyczy CALEJ przestrzeni albo sesji, wiec kolejne klasy odbija sie od
                # dokladnie tego samego. Isc dalej znaczyloby skonczyc z komunikatem "brak
                # w inwentaryzacji", ktory falszywie twierdzi, ze polaczenie i przestrzen
                # dzialaja - a to wlasnie one zawiodly.
                $odmowa = $odp.Blad
                break
            }

            # Zrodlo liczy sie za trafione dopiero wtedy, gdy oddalo wiersz Z NAZWA maszyny.
            # Sam niepusty wynik nie wystarcza: klasa, ktora zwrocila rekordy bez Name
            # i bez NetbiosName, nie ma czego pokazac w polu, a przerwalaby przeszukiwanie
            # pozostalych zrodel i zostawila puste pole zamiast odpowiedzi.
            $zNazwa = @($odp.Wiersze | Where-Object { $_.NetbiosName -or $_.Name })
            if ($zNazwa.Count -gt 0) {
                $maszyny = $zNazwa
                $zrodlo  = $z.Nazwa
                $stos    = $odp.Stos
                break
            }
        }

        if ($odmowa) {
            $wynik.Blad      = $odmowa.Krotki
            $wynik.Szczegoly = $odmowa.Szczegoly
            return $wynik
        }

        if ($maszyny.Count -eq 0) {
            $wynik.Blad      = 'brak w inwentaryzacji SCCM'
            $szczegolyBraku  = @(
                ('Połączenie z {0} działa (protokół {1}), przestrzeń {2} odpowiedziała - żadna maszyna nie raportuje loginu "{3}".' -f
                    $polaczenie.Serwer, $sesja.Protokol, $przestrzen, $Login),
                '',
                'Sprawdzone zostały: CurrentLogonUser, LastLogonUser i PrimaryUser w SMS_CombinedDeviceResources (to ta sama klasa, którą pokazuje węzeł "Devices" w konsoli), LastLogonUserName w SMS_R_System oraz UserName w SMS_G_System_COMPUTER_SYSTEM - każde dokładnie i z przedrostkiem domeny.'
            )
            if ($niedostepne.Count) {
                $szczegolyBraku += @('', ('Klasy, które nie odpowiedziały: {0}.' -f ($niedostepne -join '; ')))
            }
            $wynik.Szczegoly = $szczegolyBraku -join [Environment]::NewLine
            return $wynik
        }

        # Aktywnosc jest DODATKIEM: brak klasy albo brak prawa do niej zostawia same nazwy.
        # Gdy trafilo pierwsze zrodlo, daty sa juz w wierszach i nie ma o co pytac drugi raz.
        $aktywnosc = @{}
        foreach ($maszyna in $maszyny) {
            $kiedy = ConvertTo-JezykCzasLokalny $maszyna.LastActiveTime
            if ($null -ne $kiedy) { $aktywnosc[[string]$maszyna.ResourceID] = $kiedy }
        }

        if ($aktywnosc.Count -eq 0) {
            try {
                # ResourceId przez [int] - do zapytania trafiaja wtedy same liczby, niezaleznie
                # od tego, co oddal serwer.
                $idy = @($maszyny | ForEach-Object { [int]$_.ResourceID } | Where-Object { $_ -gt 0 }) -join ','
                if ($idy) {
                    foreach ($wpis in @(Invoke-JezykZapytanieWmi -Sesja $sesja.Sesja -Przestrzen $przestrzen -LimitSek $LimitSek `
                                            -Zapytanie (
                        "SELECT ResourceId, LastActiveTime FROM SMS_CombinedDeviceResources WHERE ResourceId IN ($idy)"))) {
                        $kiedy = ConvertTo-JezykCzasLokalny $wpis.LastActiveTime
                        if ($null -ne $kiedy) { $aktywnosc[[string]$wpis.ResourceID] = $kiedy }
                    }
                }
            }
            catch { }
        }

        # Przy kilku maszynach wygrywa ta o najpozniejszej aktywnosci; bez dat zostaje pierwsza.
        $najlepsza = $null
        $najData   = $null
        foreach ($maszyna in $maszyny) {
            $data = $aktywnosc[[string]$maszyna.ResourceID]
            if ($null -eq $najlepsza -or ($null -ne $data -and ($null -eq $najData -or $data -gt $najData))) {
                $najlepsza = $maszyna
                $najData   = $data
            }
        }

        # NetbiosName jest tylko w SMS_R_System; droga zapasowa oddaje samo Name.
        $nazwa = $najlepsza.NetbiosName
        if (-not $nazwa) { $nazwa = $najlepsza.Name }
        $wynik.Nazwa = [string]$nazwa
        $wynik.Data  = $najData

        # Wieloosobowosc sprawdzamy WYLACZNIE, gdy trafilo pierwsze zrodlo - tylko ono
        # niesie CurrentLogonUser/LastLogonUser/PrimaryUser w wierszu (zrodla 2 i 3 tych
        # pol w ogole nie znaja, wiec dla nich nie ma jak tego rozstrzygnac).
        if ($zrodlo -eq $zrodla[0].Nazwa) {
            $konta = Get-JezykKontaMaszyny -Wiersz $najlepsza
            if ($konta.Count -gt 1) {
                $wynik.Wspoldzielony = $true
                $wynik.SzczegolyWspoldzielenia =
                    'SCCM zna na tej maszynie więcej niż jedno konto ({0}) - pokazana data i nazwa mogą dotyczyć innej osoby niż {1}.' -f
                        ($konta -join ', '), $Login
            }
        }

        # SONDA ICMP TUTAJ, A NIE W OKNIE. Zapytanie idzie juz w przestrzeni uruchomieniowej
        # w tle, wiec ping nie kosztuje watku interfejsu ani jednej milisekundy - a policzony
        # przy odbiorze wyniku zamrozilby okno na czas rozwiazania nazwy i odpowiedzi.
        # Wlasny try: sonda jest DODATKIEM. Maszyna jest juz znaleziona i jej nazwa ma sie
        # pokazac takze wtedy, gdy sprawdzenie dostepnosci samo zawiedzie.
        $opisPingu = ''
        try {
            $ping = Get-JezykPingKomputera -Nazwa $wynik.Nazwa
            $wynik.Odpowiada = $ping.Odpowiada
            $wynik.Adres     = [string]$ping.Adres
            $opisPingu       = [string]$ping.Szczegoly
        }
        catch { $opisPingu = 'Sprawdzenie dostępności zawiodło: {0}' -f $_.Exception.Message }

        $opisWyniku = @('źródło: {0}; protokół: {1}; stos: {2}; serwer: {3}' -f
                        $zrodlo, $sesja.Protokol, $stos, $polaczenie.Serwer)
        if ($opisPingu) { $opisWyniku += $opisPingu }
        if ($maszyny.Count -gt 1) {
            $opisWyniku += 'dopasowanych maszyn: {0}; pokazana najpóźniej aktywna' -f $maszyny.Count
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

<#
.SYNOPSIS
    Droga ODWROTNA: kto ostatnio korzystal z podanej maszyny.

.DESCRIPTION
    Te same trzy warstwy klas i ta sama sesja co w Get-JezykOstatnioUzywanyKomputer, tylko
    filtr idzie po NAZWIE MASZYNY, a z wiersza bierzemy uzytkownika zamiast nazwy komputera.
    Osobna funkcja, a nie parametr tamtej: obie odpowiadaja na inne pytanie, wracaja innym
    ksztaltem i sa wolane z innych miejsc okna, wiec zlaczenie ich dalo by funkcje, ktorej
    polowa parametrow zawsze jest pusta.

    Nazwe uzytkownika oddajemy TAK, JAK ZAPISAL JA SCCM - razem z przedrostkiem domeny,
    jesli tam jest. Operator porownuje ja z tym, co widzi w konsoli, a "poprawiona" nazwa
    przestalaby sie z tamtym zgadzac.

    Maszyna ZNALEZIONA, ale bez zapisanego uzytkownika, to co innego niz maszyna nieznana
    w SCCM - pierwsze znaczy "klient nie zameldowal jeszcze logowania", drugie "tej maszyny
    tu nie ma". Komunikaty rozroznia te dwa przypadki, bo prowadza do zupelnie innych krokow.
#>
function Get-JezykUzytkownikKomputera {
    param([string]$Netbios, [string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom',
          [bool]$ProtokolZapasowy = $false, [int]$LimitSek = 15)

    $wynik = [pscustomobject]@{ Uzytkownik = ''; Data = $null; Blad = ''; Szczegoly = '' }

    # Nazwa pochodzi z AD, wiec jest bezpieczna - ale zapytanie budowane z tekstu sprawdza
    # sie ZAWSZE, a nie tylko wtedy, gdy wyglada to na potrzebne.
    if (-not (Test-JezykNazwaKonta $Netbios)) {
        $wynik.Blad      = 'nieprawidłowa nazwa komputera'
        $wynik.Szczegoly = 'Nazwa "{0}" zawiera znaki spoza dozwolonego zestawu.' -f $Netbios
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
        # Kolejnosc jak przy drodze odwrotnej: najpierw klasa, ktora zasila wezel "Devices"
        # w konsoli, bo to ona jest odswiezana najczesciej i niesie od razu date aktywnosci.
        # Pola w kazdym zrodle sa uporzadkowane OD NAJSWIEZSZEGO: trwajaca sesja przed
        # ostatnia zakonczona, a uzytkownik glowny na koncu, bo opisuje przypisanie, a nie
        # zdarzenie.
        $zrodla = @(
            @{ Nazwa = 'SMS_CombinedDeviceResources (widok "Devices" w konsoli)'
               Wql   = "SELECT Name, CurrentLogonUser, LastLogonUser, PrimaryUser, LastActiveTime " +
                       "FROM SMS_CombinedDeviceResources WHERE Name = '$bezpieczny'"
               Pola  = @('CurrentLogonUser', 'LastLogonUser', 'PrimaryUser') }

            @{ Nazwa = 'SMS_R_System.LastLogonUserName'
               Wql   = "SELECT Name, NetbiosName, LastLogonUserName FROM SMS_R_System " +
                       "WHERE NetbiosName = '$bezpieczny' OR Name = '$bezpieczny'"
               Pola  = @('LastLogonUserName') }

            @{ Nazwa = 'SMS_G_System_COMPUTER_SYSTEM.UserName'
               Wql   = "SELECT Name, UserName FROM SMS_G_System_COMPUTER_SYSTEM " +
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

        foreach ($z in $zrodla) {
            $odp = Invoke-JezykZapytanieSccm -Sesja $sesja.Sesja -Serwer $polaczenie.Serwer `
                                             -Przestrzen $przestrzen -Zapytanie $z.Wql `
                                             -Protokol $sesja.Protokol -LimitSek $LimitSek

            if ($odp.Blad) {
                # TYLKO brak samej klasy jest problemem JEDNEGO zrodla - reszta bledow
                # dotyczy calej przestrzeni albo sesji i powtorzylaby sie identycznie.
                if ($odp.Blad.Krotki -eq 'brak klasy w SCCM') {
                    $niedostepne += '{0}: {1}' -f $z.Nazwa, $odp.Blad.Krotki
                    continue
                }
                $odmowa = $odp.Blad
                break
            }

            foreach ($wiersz in @($odp.Wiersze)) {
                if ($wiersz.Name -or $wiersz.NetbiosName) { $znaleziona = $true }

                foreach ($nazwaPola in $z.Pola) {
                    $wartosc = ([string]$wiersz.$nazwaPola).Trim()
                    if ($wartosc) {
                        $uzytkownik = $wartosc
                        $pole       = $nazwaPola
                        break
                    }
                }

                if ($uzytkownik) {
                    $data = ConvertTo-JezykCzasLokalny $wiersz.LastActiveTime
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

        if (-not $uzytkownik) {
            # Dwa rozne braki, dwie rozne odpowiedzi: maszyna bez zapisanego uzytkownika
            # czeka na meldunek klienta, maszyny nieznanej trzeba szukac gdzie indziej.
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
            $wynik.Szczegoly = $szczegolyBraku -join [Environment]::NewLine
            return $wynik
        }

        $wynik.Uzytkownik = $uzytkownik
        $wynik.Data       = $data

        $opisWyniku = @('źródło: {0} (pole {1}); protokół: {2}; stos: {3}; serwer: {4}' -f
                        $zrodlo, $pole, $sesja.Protokol, $stos, $polaczenie.Serwer)
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

<#
.SYNOPSIS
    Odblokowuje konto w AD. JEDYNA operacja ZAPISU w calym narzedziu.

.DESCRIPTION
    Obwarowana z dwoch stron: wolajacy sprawdza, czy domena jest dozwolona, i TUTAJ
    sprawdzamy to ponownie - warunek "tylko ta domena" opiera sie na stanie interfejsu,
    a stan interfejsu da sie rozspojnic.

    Nie rzuca wyjatkiem: odmowa uprawnien to normalna odpowiedz AD, nie awaria narzedzia.
#>
function Unlock-JezykKonto {
    param([string]$Login, [string]$Domena,
          [System.Management.Automation.PSCredential]$Poswiadczenia)

    # Serwer to kontroler, ktory FAKTYCZNIE przyjal zapis. Wolajacy odczytuje po nim konto
    # od nowa: stan blokady jest replikowany pilnie, ale nie natychmiast, wiec odczyt
    # z przypadkowego kontrolera potrafi oddac stan sprzed odblokowania.
    $wynik = [pscustomobject]@{ Udane = $false; Komunikat = ''; Szczegoly = ''; Serwer = '' }

    # Najpierw ksztalt danych, potem uprawnienie: wartosc o zlym ksztalcie nie ma prawa
    # dojsc nawet do sprawdzania listy domen.
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

    $parametry = $null
    try {
        # Zapis idzie na EMULATOR PDC, bo to on jest autorytatywny dla blokad: nieudane
        # uwierzytelnienia z kazdego kontrolera sa lancuchowo kierowane wlasnie tam.
        # Zapis skierowany "gdziekolwiek" potrafi trafic na kontroler tylko do odczytu.
        # Rozpoznanie emulatora jest opcjonalne - gdy sie nie uda, zapis idzie na domene.
        $serwer = $Domena
        $odczyt = @{ Identity = $Domena; Server = $Domena; ErrorAction = 'Stop' }
        if ($Poswiadczenia) { $odczyt['Credential'] = $Poswiadczenia }
        try {
            $emulator = (Get-ADDomain @odczyt).PDCEmulator
            if ($emulator -and (Test-JezykNazwaHosta $emulator)) { $serwer = $emulator }
        }
        catch { }
        finally { $odczyt.Clear() }

        # Poswiadczenia dokladane WARUNKOWO - bez nich zapis idzie na koncie, na ktorym
        # Jezyk dziala.
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
        # Prawo do odblokowywania jest OSOBNE od prawa odczytu, wiec odmowa jest tu
        # spodziewana i ma trafic do pola Status. Jezyk nie dokłada do komunikatu nazwy
        # uzytkownika z poswiadczen; co znajdzie sie w tresci wyjatku, decyduje AD.
        $opis = Get-JezykOpisBledu $_ ('Odblokowanie konta {0}' -f $Login)
        $wynik.Komunikat = $opis.Krotki
        $wynik.Szczegoly = $opis.Szczegoly
    }
    finally {
        if ($parametry) { $parametry.Clear() }

        # $Error TRZYMA OBIEKT POSWIADCZEN. Nieudane wywolanie wklada tam rekord bledu,
        # a ten niesie InvocationInfo.BoundParameters - czyli slownik zwiazanych parametrow
        # razem z obiektem PSCredential. Bez tego wiersza haslo administratora dalo sie
        # odczytac do konca zycia procesu. Czyscimy CALA liste, bo rozpoznanie emulatora
        # PDC tez idzie z poswiadczeniami; Jezyk nigdzie nie czyta $Error.
        $Error.Clear()
    }

    return $wynik
}

# Jedno miejsce z decyzja "czy w tej domenie wolno odblokowywac", zeby interfejs i logika
# nie mogly sie rozjechac. Pusta lista znaczy "nigdzie" i jest wartoscia domyslna.
function Test-JezykWolnoOdblokowac {
    param([string]$Domena)
    if (-not $Domena) { return $false }
    return (@($Script:DomenyZOdblokowaniem) -contains $Domena.ToLower())
}

<#
.SYNOPSIS
    Sprawdza stan konta w AD. Nigdy nie rzuca wyjatkiem - zawsze zwraca obiekt wyniku.

.DESCRIPTION
    Kazdy blad jest zamieniany na obiekt wyniku. Gdyby wyjatek wydostal sie do GUI,
    kliniecie "Szukaj" konczyloby sie bledem w niewidocznej konsoli, a okno wygladaloby,
    jakby nic sie nie stalo.

.PARAMETER Serwer
    Konkretny kontroler zamiast nazwy domeny. Uzywany po odblokowaniu konta: zapis idzie na
    emulator PDC, a stan blokady replikuje sie pilnie, lecz nie natychmiast - odczyt
    z przypadkowego kontrolera potrafilby oddac stan sprzed zapisu i pokazac "Konto
    zablokowane" sekunde po udanym odblokowaniu.

    Nazwa przechodzi TE SAMA biala liste co kazdy inny adres w narzedziu; wartosc, ktora
    jej nie przejdzie, jest po cichu pomijana na rzecz nazwy domeny. Nazwa przyniesiona
    z sieci nie zostaje adresem polaczenia bez sprawdzenia.
#>
<#
.SYNOPSIS
    Zamienia nazwe wyrozniajaca przelozonego na czytelny podpis.

.DESCRIPTION
    Atrybut Manager niesie NAZWE WYROZNIAJACA ("CN=Jan Kowalski,OU=Kadry,DC=jezyk,DC=pl"),
    a nie nazwisko - wpisany do pola wprost byl by scianą tekstu, w ktorej nazwiska trzeba
    szukac wzrokiem. Rozwiazujemy go osobnym odczytem i skladamy podpis "Jan Kowalski (jkowalski)".

    WLASNY try, i to jest tu najwazniejsze: przelozony bywa kontem z INNEJ domeny, kontem
    juz usunietym albo obiektem, do ktorego nie ma prawa odczytu. Zaden z tych przypadkow
    nie moze zamienic udanego odczytu konta w komunikat o bledzie - operator dzwoni w sprawie
    blokady, a nie przelozonego.

    Wartosc ZAPASOWA wyciagamy wprost z nazwy wyrozniajacej: pierwszy czlon (CN) to i tak
    zwykle to samo imie i nazwisko. Lepsze niz puste pole, ktore wyglada jak brak danych.
    Odwrotne ukosniki, ktorymi LDAP oslania przecinki w nazwie ("CN=Kowalski\, Jan"),
    zdejmujemy - inaczej byly by widoczne w oknie.
#>
function Get-JezykPodpisMenedzera {
    param([string]$Dn, [string]$Serwer = '')

    if ($null -eq $Dn) { $Dn = '' }
    $Dn = $Dn.Trim()
    if (-not $Dn) { return '' }

    # Zapasowy podpis skladamy PRZED zapytaniem - ma byc gotowy takze wtedy, gdy odczyt
    # w ogole nie dojdzie do skutku.
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

        # Bez nazwy wyswietlanej pokazujemy sam login, zamiast loginu z pustymi nawiasami -
        # ta sama zasada co na liscie wyboru kont.
        if (-not $nazwa) { return $login }
        if (-not $login) { return $nazwa }
        return '{0} ({1})' -f $nazwa, $login
    }
    catch { return $zapasowy }
}

<#
.SYNOPSIS
    Zamienia wlasciciela obiektu AD ("DOMENA\konto") na czytelny podpis osoby.

.DESCRIPTION
    Wzorowana na Get-JezykPodpisMenedzera, z jedna roznica: oddaje obiekt, a nie napis.
    Widok musi wiedziec, CZY trafila sie osoba - AD wpisuje jako wlasciciela GRUPE
    (Administratorzy domeny), gdy obiekt zakladal jej czlonek, a nazwa grupy nie jest
    odpowiedzia na pytanie "kto". Bez tej flagi okno nie odroznialoby nazwiska od grupy.

    Osoba = $null znaczy "nie bylo czego sprawdzac", czyli pusty wlasciciel - deskryptor,
    ktorego nie udalo sie odczytac. To nie to samo, co "sprawdzono i to nie jest osoba".
#>
function Get-JezykPodpisWlasciciela {
    param([string]$Wlasciciel, [string]$Serwer = '')

    if ($null -eq $Wlasciciel) { $Wlasciciel = '' }
    $Wlasciciel = $Wlasciciel.Trim()
    if (-not $Wlasciciel) { return [pscustomobject]@{ Podpis = ''; Osoba = $null } }

    # Czesc za OSTATNIM ukosnikiem: "JEZYK\jkowalski" -> "jkowalski". Wartosc bez ukosnika
    # (goly SID, gdy Windows nie zdolal przetlumaczyc) idzie do sprawdzenia w calosci -
    # AD przyjmuje SID jako tozsamosc, wiec i taki zapis ma szanse zamienic sie w nazwisko.
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

        # Bez nazwy wyswietlanej sam login, zamiast loginu z pustymi nawiasami - ta sama
        # zasada co przy menedzerze i na liscie wyboru kont.
        $podpis = if ($nazwa) { '{0} ({1})' -f $nazwa, $login } else { $login }
        return [pscustomobject]@{ Podpis = $podpis; Osoba = $true }
    }
    catch {
        # Grupa, konto komputera albo konto z innej domeny: Get-ADUser rzuca, a wlasciciel
        # i tak jest prawdziwa odpowiedzia - pokazujemy go w zapisie, ktory zna administrator.
        return [pscustomobject]@{ Podpis = $Wlasciciel; Osoba = $false }
    }
}

function Get-JezykUserStatus {
    param([string]$Login, [string]$Serwer = '')

    # Login przepisywany z maila albo zgloszenia bardzo czesto ma doklejona spacje.
    if ($null -eq $Login) { $Login = '' }
    $Login = $Login.Trim()

    $adres = $Script:Config.Domena
    if ($Serwer -and (Test-JezykNazwaWDomenach $Serwer $Script:Domeny)) { $adres = $Serwer }

    # Pusty login to nie awaria, tylko "uzytkownik jeszcze nic nie wpisal" - kontroler
    # domeny nie jest w ogole odpytywany.
    if ([string]::IsNullOrWhiteSpace($Login)) {
        return New-JezykResult -Login '' -Status 'Empty' -Message 'Wpisz login i kliknij "Szukaj".'
    }

    if (-not (Test-JezykNazwaKonta $Login)) {
        return New-JezykResult -Login $Login -Status 'NotFound' `
                               -Message ('Nazwa "{0}" nie jest poprawną nazwą konta.' -f $Login)
    }

    try {
        # -Identity, a nie -Filter: parametr traktuje tekst jako wartosc do odnalezienia,
        # a nie jako fragment zapytania, wiec znaki o znaczeniu skladniowym w LDAP nie maja
        # tu czego zepsuc.
        #
        # -Properties jest konieczne: Get-ADUser domyslnie zwraca tylko podstawowy zestaw
        # atrybutow. LockedOut nie jest zwyklym atrybutem w bazie - modul wylicza go na
        # biezaco po stronie kontrolera domeny.
        $user = Get-ADUser -Identity $Login `
                           -Server $adres `
                           -Properties LockedOut, Enabled, LockoutTime, DisplayName,
                                       GivenName, Surname, EmailAddress,
                                       OfficePhone, MobilePhone, Manager,
                                       CanonicalName, pwdLastSet, PasswordLastSet,
                                       'msDS-UserPasswordExpiryTimeComputed',
                                       AccountExpirationDate, Created, LastLogonDate `
                           -ErrorAction Stop

        # LockoutTime to FILETIME; 0 albo brak atrybutu znaczy, ze konta nigdy nie blokowano.
        # Osobny try, bo nietypowa wartosc nie moze zamienic udanego odczytu w komunikat o bledzie.
        $czasBlokady = $null
        if ($user.LockoutTime -and $user.LockoutTime -gt 0) {
            try   { $czasBlokady = [datetime]::FromFileTime($user.LockoutTime) }
            catch { $czasBlokady = $null }
        }

        $lokalizacja = Get-JezykKatalogZeSciezki $user.CanonicalName

        # OBA NUMERY, KAZDY OSOBNO (LDAP: telephoneNumber i mobile - w oknie AD "Glowny"
        # i "Komorkowy"). Wczesniej komorka pokazywala sie WYLACZNIE wtedy, gdy nie bylo
        # stacjonarnego, wiec przy koncie z dwoma numerami operator nie widzial tego, pod
        # ktorym najlatwiej sie dodzwonic. Brak obu zostawia pola PUSTE - konto bez numeru
        # to nie usterka, ta sama zasada co przy e-mailu.
        $telefonGlowny    = ([string]$user.OfficePhone).Trim()
        $telefonKomorkowy = ([string]$user.MobilePhone).Trim()

        # Rozwiazanie przelozonego ma WLASNY try wewnatrz - patrz Get-JezykPodpisMenedzera.
        # Serwer przekazujemy ten sam, z ktorego czytalismy konto: przelozony lezy zwykle
        # w tej samej domenie, a odpytanie innego kontrolera bylo by druga podroza po sieci.
        $menedzer = Get-JezykPodpisMenedzera -Dn ([string]$user.Manager) -Serwer $adres

        # pwdLastSet rowne zero to sposob, w jaki AD zapisuje "uzytkownik musi zmienic haslo
        # przy nastepnym logowaniu".
        $wymuszonaZmiana = $null
        if ($null -ne $user.pwdLastSet) { $wymuszonaZmiana = ($user.pwdLastSet -eq 0) }

        # msDS-UserPasswordExpiryTimeComputed nie jest zwykla data - ma dwie wartosci
        # specjalne: 0 (haslo do zmiany przy logowaniu) i maksimum Int64 (nigdy nie wygasa).
        # Podanie ktorejkolwiek do FromFileTime konczy sie wyjatkiem.
        $hasloWygasa    = $null
        $hasloBezTerminu = $null
        $terminHasla = $user.'msDS-UserPasswordExpiryTimeComputed'
        # Progiem jest ToFileTimeUtc, a nie sama stala Int64: ToFileTime przeliczalby czas
        # lokalny, wiec wynik zalezalby od strefy czasowej stacji, a porownanie z MaxValue
        # przepuszczaloby wartosci absurdalne, ale mniejsze - i pokazywaloby termin w roku 9999.
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

        # Login bierzemy z AD (SamAccountName), a nie z pola tekstowego - dzieki temu widac
        # go w oryginalnej pisowni.
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
        # Typ wyjatku sprawdzamy PO NAZWIE, a nie konstrukcja "catch [Typ]": tamta wymaga,
        # zeby PowerShell rozwiazal typ juz przy parsowaniu pliku. Na stacji bez RSAT typ
        # nie istnieje, wiec skrypt wywalilby sie bledem parsowania i uzytkownik nie
        # zobaczylby czytelnego okna z komunikatem o braku modulu.
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

<#
.SYNOPSIS
    Sklada JEDNA pozycje listy wyboru z konta zwroconego przez AD.

.DESCRIPTION
    Wydzielone, bo pozycje powstaja w DWOCH miejscach: przy wyszukiwaniu po nazwie
    (Find-JezykUsers) i w przestrzeni tla, ktora szuka po numerze. Tamta musi oddac oknu
    pozycje GOTOWE, a nie surowe obiekty ADUser - inaczej skladanie opisu wedrowaloby do
    widoku, ktoremu nie wolno pytac katalogu o nic.

    Dwie kopie tego samego skladania rozjechalyby sie przy pierwszej zmianie opisu i lista
    pokazywalaby konta znalezione po nazwie inaczej niz te same konta znalezione po numerze.
#>
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

<#
.SYNOPSIS
    Szuka kont po NUMERZE TELEFONU, niezaleznie od tego, jak zapisano go w AD.

.DESCRIPTION
    JEDEN FILTR, Z GWIAZDKA MIEDZY KAZDA CYFRA. Ten sam numer bywa w katalogu zapisany na
    kilka sposobow - "+48123456789", "123 456 789", "123456789", "+48 123456789" - a wzorzec
    "*1*2*3*..." obejmuje je wszystkie naraz, bo separatory wpadaja w gwiazdki. Obejmuje tez
    zapis dokladny, wiec osobny "szybki" etap na formy bez separatorow niczego nie dokladal:
    telephoneNumber domyslnie NIE JEST w AD indeksowany, wiec obie formy to i tak pelny skan,
    a numer zapisany z separatorami placil za ten skan DWA RAZY.

    LAG PRZY NUMERZE INFOLINII BRAL SIE ZE STRONY, A NIE Z LICZBY ZWROCONYCH WIERSZY.
    -ResultSetSize ucina odpowiedz PO STRONIE KLIENTA: kontroler i tak zbiera cala strone,
    a strona ma domyslnie 256 wierszy. Numer, ktorego uzywa kilkadziesiat osob, nigdy jej
    nie zapelnia, wiec kontroler przegladal CALA domene - i to sa te kilka sekund, w ktorych
    okno stalo. -ResultPageSize rowny limitowi konczy jego prace, gdy tylko uzbiera tyle
    trafien. To ta jedna wartosc naprawia lag; sam limit trafien nie naprawial go wcale.

    PYTAMY O JEDEN WIERSZ WIECEJ, NIZ POKAZUJEMY. Komplet znaczy wtedy "bylo ich wiecej",
    a nie "bylo dokladnie tylu" - i wolajacy moze powiedziec to wprost, zamiast pokazywac
    liste ucieta w polowie. Tak samo zachowuje sie wyszukiwanie po niepelnym nazwisku.

    GWIAZDKI WPUSZCZAJA TRAFIENIA PRZYPADKOWE ("*1*2*3*" pasuje tez do "1x2x3"), wiec kazdy
    zwrocony numer porownujemy jeszcze raz po samych cyfrach - patrz Test-JezykNumerPasuje.

    NUMER SKRACAMY DO DZIEWIECIU OSTATNICH CYFR, zeby "+48 123 456 789" i "123456789" byly
    tym samym numerem. Dopasowanie dziala wtedy w OBIE strony, niezaleznie od tego, ktora
    forma stoi w katalogu, a ktora wpisal operator.

    KSZTALT WYNIKU, A NIE GOLA TABLICA. "Nikogo nie znaleziono", "jest ich za wielu" i "nie
    udalo sie sprawdzic" prowadza do trzech roznych komunikatow, a pusta tablica umie
    powiedziec tylko to pierwsze - i przy dwoch pozostalych po prostu klamie.
#>
function Find-JezykUsersPoNumerze {
    param([string]$Cyfry, [int]$Limit = 10, [string]$Serwer = '', [string]$SzukajOd = '')

    $wynik = [pscustomobject]@{ Trafienia = @(); ZaDuzo = $false; Przerwane = $false; Powod = '' }

    # BRAK SERWERA TO PRZERWANIE, A NIE PUSTA LISTA. Ta funkcja wykonuje sie w OSOBNEJ
    # przestrzeni uruchomieniowej, gdzie $Script:Config nie istnieje - dawna wartosc
    # zapasowa "$Script:Config.Domena" dalaby tam po cichu pusty adres i zapytanie o nikogo.
    if (-not $Serwer) {
        $wynik.Przerwane = $true
        $wynik.Powod     = 'Nie przeszukano numerów telefonu: nie podano domeny do zapytania.'
        return $wynik
    }

    # Druga zapora mimo sprawdzenia u wolajacego: do wzorca maja trafic same cyfry ZAWSZE,
    # a nie tylko wtedy, gdy wyglada to na potrzebne. Gorna granica jak w E.164 - dluzszy
    # ciag numerem juz nie jest.
    $Cyfry = Get-JezykCyfry $Cyfry
    if ($Cyfry.Length -lt 6 -or $Cyfry.Length -gt 15) { return $wynik }

    # LIMIT BEZ SENSU ZASTEPUJEMY DOMYSLNYM. Brak klucza w konfiguracji daje [int]$null,
    # czyli ZERO - a limit zero znaczy "kazdy numer ma zbyt wielu wlascicieli", wiec
    # wyszukiwanie przestaje cokolwiek znajdowac i nie mowi przy tym ani slowa. Nie jest to
    # ostroznosc na zapas: log ze zgloszenia pokazal limit 1 przy skonfigurowanych dziesieciu.
    if ($Limit -lt 1) { $Limit = 10 }

    $rdzen = if ($Cyfry.Length -gt 9) { $Cyfry.Substring($Cyfry.Length - 9) } else { $Cyfry }

    # APOSTROFY W FILTRZE SA CELOWE i nie wolno ich zamieniac na cudzyslowy: $nr ma dojsc do
    # modulu AD jako NAZWA ZMIENNEJ, ktorej wartosc modul podstawi sam, a nie jako gotowy
    # fragment filtra sklejony z tekstu. Powod opisany szerzej przy filtrze w Find-JezykUsers.
    # (PSScriptAnalyzer zglasza tu falszywy alarm "zmienna nigdy nie uzyta".)
    $nr = '*' + (($rdzen.ToCharArray()) -join '*') + '*'

    # OfficePhone i MobilePhone to przyjazne nazwy atrybutow telephoneNumber i mobile.
    $pola  = 'DisplayName', 'GivenName', 'Surname', 'OfficePhone', 'MobilePhone'
    $filtr = 'OfficePhone -like $nr -or MobilePhone -like $nr'

    # PODDRZEWO DOKLADAMY TYLKO WTEDY, GDY JE PODANO. -SearchBase z pusta wartoscia nie
    # znaczy "od korzenia" - modul AD odrzuca ja bledem, wiec pusty klucz w ustawieniach
    # wywrocilby wyszukiwanie zamiast zostawic je bez zmian.
    $dodatkowe = @{}
    if ($SzukajOd) { $dodatkowe['SearchBase'] = $SzukajOd }

    try {
        # OBIE WARTOSCI, NIE JEDNA. -ResultSetSize konczy CZYTANIE odpowiedzi, a
        # -ResultPageSize konczy SZUKANIE: kontroler oddaje strone, gdy tylko ja zapelni,
        # wiec przy stronie rownej limitowi przestaje przegladac domene po jedenastym
        # trafieniu, zamiast szukac dalej do konca.
        #
        # To ratuje WYLACZNIE numer infolinii. Numer nalezacy do jednej osoby nie zapelni
        # strony NIGDY, wiec kontroler i tak przeglada wszystkie konta - stad to zapytanie
        # chodzi w tle, a nie w watku okna.
        $trafienia = @(Get-ADUser -Filter $filtr -Server $Serwer -Properties $pola `
                                  -ResultPageSize ($Limit + 1) -ResultSetSize ($Limit + 1) `
                                  @dodatkowe -ErrorAction Stop)
    }
    catch {
        # "NIE UDALO SIE SPRAWDZIC" TO NIE TO SAMO, CO "NIKOGO NIE MA". Pusta lista zwrocona
        # po bledzie kazalaby oknu powiedziec "nie znaleziono konta", czyli sklamac o tym,
        # czego nie wiemy. Przyczyna idzie w calosci pod przycisk "!".
        $wynik.Przerwane = $true
        $wynik.Powod     = 'Nie udało się przeszukać numerów telefonu w domenie "{0}": {1}' -f
                           $Serwer, $_.Exception.Message
        return $wynik
    }

    # KOMPLET WIERSZY ZNACZY "BYLO ICH WIECEJ", A NIE "BYLO DOKLADNIE TYLE". Decyzja zapada
    # PRZED odsiewem po cyfrach: lista ucieta u kontrolera jest niepelna niezaleznie od tego,
    # ile pozycji przetrwa odsiew.
    if ($trafienia.Count -gt $Limit) {
        $wynik.ZaDuzo = $true
        return $wynik
    }

    # Odsiew ostatni: wzorzec z gwiazdkami wpuszcza trafienia przypadkowe, wiec kazdy numer
    # porownujemy jeszcze raz po samych cyfrach.
    $wynik.Trafienia = @($trafienia | Where-Object {
        (Test-JezykNumerPasuje $Cyfry ([string]$_.OfficePhone)) -or
        (Test-JezykNumerPasuje $Cyfry ([string]$_.MobilePhone))
    })

    return $wynik
}

<#
.SYNOPSIS
    Wejscie zadania w tle: szuka po numerze i oddaje GOTOWE pozycje listy wyboru.

.DESCRIPTION
    Cala zawartosc tej funkcji dalaby sie wpisac wprost w tekst skladany przez
    New-JezykSkryptTla - i wlasnie dlatego jej tam nie ma. Kod zyjacy w napisie nie
    wykonuje sie w zestawie weryfikacyjnym ani razu, a tutaj wykonuje sie w calosci.

    Przeliczenie surowych obiektow ADUser na pozycje listy MUSI zapasc po tej stronie,
    czyli jeszcze w przestrzeni tla: widok dostaje wtedy to samo, co przy wyszukiwaniu po
    nazwie, i nie musi wiedziec, skad pozycja przyszla.
#>
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

<#
.SYNOPSIS
    Szuka kont, ktorych dane ZACZYNAJA SIE od podanego tekstu. Zwraca lekka liste kandydatow.

.DESCRIPTION
    Filtr jest tu konieczny, wiec chronimy sie inaczej niz przez -Identity: wzorzec trafia
    do niego jako ZMIENNA, a modul AD podstawia jej wartosc, zamiast parsowac ja jako
    fragment filtra. Wpisanie "*)(cn=*" jest wiec szukanym ciagiem znakow, nie poleceniem.
    -ResultSetSize ogranicza odpowiedz, zeby sama gwiazdka nie sciagnela calej domeny.

    Pobieramy TYLKO to, co trafia na liste. Atrybut wymieniony w -Filter nie musi byc
    w -Properties: filtr wykonuje sie po stronie kontrolera domeny.

    DWA ZAPYTANIA, bo w AD sa to dwa rozne rodzaje obiektow. Get-ADUser nie zwroci
    kontaktu NIGDY, niezaleznie od filtra - kontakt jest obiektem klasy "contact", nie ma
    sAMAccountName ani stanu konta, wiec nie miesci sie w tym poleceniu. Kontakty ida
    osobnym zapytaniem Get-ADObject i lada POD kontami: pierwsza pozycja listy ma pozostac
    kontem, bo okno wybiera ja samo po wyszukaniu.
#>
function Find-JezykUsers {
    param([string]$Fragment)

    if ($null -eq $Fragment) { $Fragment = '' }
    $Fragment = $Fragment.Trim()

    # Ksztalt wyniku jest JEDEN dla wszystkich pieciu stanow - wolajacy nie moze musiec
    # sprawdzac, czy dane pole w ogole istnieje.
    $pusty = [pscustomobject]@{ Status = 'Empty'; Konta = @(); Szczegoly = ''
                                Message = 'Wpisz login, imię i nazwisko, e-mail, numer telefonu albo login@domena i kliknij "Szukaj".' }
    if ([string]::IsNullOrWhiteSpace($Fragment)) { return $pusty }

    $slowa = @($Fragment -split '\s+' | Where-Object { $_ })

    try {
        # Gwiazdka tylko na koncu: dopasowanie OD POCZATKU wartosci korzysta z indeksow
        # katalogu i pozostaje szybkie. Dopasowanie dowolnego fragmentu wymusiloby
        # przeszukanie wszystkich obiektow w domenie.
        $wzorzec = $Fragment + '*'

        # Limit pobieramy o jeden wiekszy niz pokazujemy - dzieki temu wiemy, czy wynikow
        # bylo WIECEJ niz limit, zamiast po cichu uciac liste.
        $limit = $Script:Config.LimitWynikow

        # APOSTROFY SA TU CELOWE i nie wolno ich zamieniac na cudzyslowy. Dzieki nim
        # $wzorzec nie jest rozwijany przez PowerShella, tylko przekazywany modulowi AD.
        # Cudzyslowy sklejalyby tekst przed wyslaniem i otwieraly droge do wstrzykniecia.
        # (PSScriptAnalyzer zglasza tu falszywy alarm "zmienna nigdy nie uzyta".)
        #
        # Warunki laczy -or, wiec jedno pole obsluguje login, imie, nazwisko i adres.
        # UserPrincipalName to OSOBNY atrybut niz EmailAddress i czesto ma inna wartosc.
        $filtr = 'SamAccountName -like $wzorzec -or GivenName -like $wzorzec ' +
                 '-or Surname -like $wzorzec -or EmailAddress -like $wzorzec ' +
                 '-or UserPrincipalName -like $wzorzec -or DisplayName -like $wzorzec'

        # Wpis dwuwyrazowy: GivenName i Surname sprawdzaja sie OSOBNO, wiec zadne pojedyncze
        # pole nie zaczyna sie od calej frazy. Dokladamy pare warunkow w obu kolejnosciach,
        # bo nie da sie przewidziec, czy ktos wpisze "Jan Kowalski" czy "Kowalski Jan".
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

        # NUMERU TELEFONU TA FUNKCJA JUZ NIE SZUKA - robi to zadanie w tle
        # (Start-JezykZadanieNumeru), a wynik dokleja do listy Update-JezykNumerWTle.
        # Powod: telephoneNumber i mobile NIE SA w AD indeksowane, a filtr ma gwiazdke na
        # poczatku wartosci, wiec numer nalezacy do JEDNEJ osoby zmusza kontroler do
        # przejrzenia wszystkich kont. Trzymane tutaj, kazalo oknu czekac na to przegladanie
        # takze wtedy, gdy konta po nazwie byly gotowe po dwoch dziesiatych sekundy.
        #
        # Zapytanie po nazwie zostaje synchroniczne: idzie po atrybutach indeksowanych,
        # z gwiazdka na KONCU wartosci, wiec wraca od razu i nie ma czego przenosic w tlo.

        # KONTAKTY. Nazwy atrybutow SUROWE, jak w LDAP (name, displayName, givenName, sn,
        # mail): Get-ADObject nie ma mapy przyjaznych nazw, ktora jest w Get-ADUser, wiec
        # "Surname" bylby dla niego nieznanym atrybutem. Apostrofy wokol filtra jak wyzej -
        # to one sprawiaja, ze $wzorzec podstawia modul AD, a nie PowerShell.
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

        # Wlasny try: kontakty sa DODATKIEM do wyniku. Domena bez kontaktow albo odmowa
        # odczytu tej galezi katalogu nie moze przeslonic znalezionych kont.
        $kontakty = @()
        try {
            $kontakty = @(Get-ADObject -Filter $filtrKontakt `
                                       -Server $Script:Config.Domena `
                                       -Properties displayName, givenName, sn, mail `
                                       -ResultSetSize ($limit + 1) `
                                       -ErrorAction Stop)
        }
        catch { $kontakty = @() }

        # Limit liczony od SUMY, nie od kazdego zapytania osobno - inaczej lista potrafilaby
        # urosnac do dwukrotnosci limitu.
        $lacznie = $znalezione.Count + $kontakty.Count

        if ($lacznie -eq 0) {
            # O NUMERZE NIE MA TU JUZ MOWY. Wyszukiwanie po numerze chodzi osobno i w tej
            # chwili moze jeszcze trwac, wiec ta odpowiedz mowi wylacznie o tym, co
            # sprawdzono: o nazwie. Spoznione trafienie po numerze potrafi ten stan cofnac -
            # patrz Update-JezykNumerWTle w Jezyk-3-Widok.ps1.
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

        # Kontakt niesie DN zamiast loginu - nie ma sAMAccountName, wiec to jedyna
        # tozsamosc, po ktorej da sie go pozniej odczytac.
        $wpisy = @(foreach ($c in ($kontakty | Sort-Object Name)) {
            # NAZWA OBIEKTU (atrybut Name, czyli cn) IDZIE NA LISTE W NAWIASIE. Dotad byla
            # wylacznie wartoscia zapasowa, wiec kontakt z wypelnionym displayName pokazywal
            # ja dopiero PO wybraniu pozycji, w polu przemianowanym na "Nazwa" - a to wlasnie
            # po niej operator rozpoznaje wpis, ktorego szukal. Na liscie widac wiec oba
            # napisy naraz i nie trzeba klikac po kolei, zeby trafic we wlasciwy kontakt.
            $nazwaObiektu = [string]$c.Name
            $nazwa = Get-JezykOsoba ([string]$c.displayName) ([string]$c.givenName) ([string]$c.sn)
            if (-not $nazwa) { $nazwa = $nazwaObiektu }

            # Nawias TYLKO gdy niesie cos nowego: przy kontakcie bez displayName obie wartosci
            # sa te same i "Jan Kowalski (Jan Kowalski)" bylby samym halasem.
            $podpis = if ($nazwaObiektu -and $nazwaObiektu -ne $nazwa) {
                '{0} ({1})' -f $nazwa, $nazwaObiektu
            } else { $nazwa }

            $opis = if ($c.mail) { '[Kontakt] {0} - {1}' -f $podpis, [string]$c.mail } else { '[Kontakt] {0}' -f $podpis }
            # Ksztalt pozycji zostaje TEN SAM co przy koncie - lista jest jedna, a dwa
            # ksztalty w jednej kolekcji rozjechalyby sie przy pierwszej zmianie. Nazwy
            # obiektu nie odkladamy: po wybraniu pozycji Get-JezykKontaktStatus czyta
            # kontakt od nowa po DN i przynosi ja swieza.
            [pscustomobject]@{
                Typ         = 'Kontakt'
                Login       = ''
                Dn          = [string]$c.DistinguishedName
                DisplayName = $nazwa
                Opis        = $opis
            }
        })

        # Konta PIERWSZE, kontakty pod nimi. Okno zaznacza pozycje zerowa samo, wiec
        # kolejnosc przesadza o tym, co widac zaraz po wyszukaniu.
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

<#
.SYNOPSIS
    Odczytuje pozycje typu Kontakt. Tozsamoscia jest DN, bo kontakt nie ma loginu.

.DESCRIPTION
    Kontakt to wpis ksiazki adresowej, a nie konto: nie ma sAMAccountName, nie loguje sie,
    nie da sie go zablokowac ani odblokowac i nie pojawi sie w inwentaryzacji SCCM. Dlatego
    wraca ze Statusem 'Kontakt' - warstwa renderujaca po nim poznaje, ze polom stanu konta
    nie ma czym wypelnic, a przycisk odblokowania ma zostac nieczynny.

    Ksztalt obiektu wyniku pozostaje JEDEN (New-JezykResult) - inaczej okno musialoby miec
    druga sciezke wyswietlania, a dwie sciezki rozjezdzaja sie przy pierwszej zmianie.

    Nazwy atrybutow surowe, jak w LDAP: Get-ADObject nie ma mapy przyjaznych nazw.
#>
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
                                            telephoneNumber, mobile,
                                            CanonicalName, whenCreated `
                                -ErrorAction Stop

        $lokalizacja = Get-JezykKatalogZeSciezki ([string]$kontakt.CanonicalName)

        # Osobny try: nietypowa wartosc daty nie moze zamienic udanego odczytu w komunikat
        # o bledzie.
        $utworzono = $null
        if ($kontakt.whenCreated) {
            try   { $utworzono = [datetime]$kontakt.whenCreated }
            catch { $utworzono = $null }
        }

        $nazwa = Get-JezykOsoba ([string]$kontakt.displayName) ([string]$kontakt.givenName) ([string]$kontakt.sn)
        if (-not $nazwa) { $nazwa = [string]$kontakt.Name }

        # Oba numery osobno, tak samo jak przy koncie. Nazwy atrybutow SUROWE, bo
        # Get-ADObject nie ma mapy przyjaznych nazw, ktora jest w Get-ADUser -
        # "OfficePhone" bylby dla niego nieznanym atrybutem.
        $telefonGlowny    = ([string]$kontakt.telephoneNumber).Trim()
        $telefonKomorkowy = ([string]$kontakt.mobile).Trim()

        # BEZ Szczegolow: udany odczyt kontaktu to sukces, a Szczegoly zapalaja przy polu
        # Status przycisk "!", ktory ma znaczyc wylacznie "cos nie dziala".
        return New-JezykResult -Login '' -Status 'Kontakt' `
                               -NazwaObiektu ([string]$kontakt.Name) `
                               -DisplayName $nazwa `
                               -Imie ([string]$kontakt.givenName) `
                               -Nazwisko ([string]$kontakt.sn) `
                               -Email ([string]$kontakt.mail) `
                               -TelefonGlowny $telefonGlowny `
                               -TelefonKomorkowy $telefonKomorkowy `
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

<#
.SYNOPSIS
    Czy maszyna odpowiada na ping i pod jakim adresem IP? Odpowiedz brzmi tak, nie albo
    "nie wiadomo" - i te trzy stany trzeba rozroznic.

.DESCRIPTION
    SCCM mowi, ktorej maszyny uzytkownik uzywal OSTATNIO. Nie mowi, czy ta maszyna stoi
    teraz wlaczona - a to jest pierwsze pytanie osoby przy telefonie. Stad ta funkcja.

    ROZWIAZANIE NAZWY IDZIE OSOBNO I MA WLASNY TERMIN, dokladnie jak w Test-JezykPortOtwarty.
    To pulapka, ktora raz juz zamrozila okno Jezyka: odpytanie DNS potrafi trwac dowolnie
    dlugo, a termin nalozony na sama operacje sieciowa nie obejmuje ani jednej milisekundy
    rozwiazywania nazwy. Termin jest LACZNY dla obu krokow - wolajacego obchodzi calkowity
    czas sondy, a nie to, ktory z krokow go zjadl.

    Ping idzie NA GOTOWY ADRES, nie na nazwe: nazwa jest juz rozwiazana i nie ma czego
    rozwiazywac drugi raz. Ping.Send termin honoruje, wiec nie potrzebuje obejscia przez
    BeginConnect, ktorego wymagal TcpClient.

    IPv4 MA PIERWSZENSTWO nad IPv6 - to adres, ktory operator rozpozna i ktory wpisze
    w narzedziu zdalnego pulpitu.

    TRZY STANY POLA Odpowiada, i zaden nie moze udawac drugiego:
      $true  - maszyna odpowiedziala,
      $false - nazwa rozpoznana, ale maszyna milczy,
      $null  - NIE WIADOMO (zla nazwa, DNS nie odpowiedzial, brak czasu). Okno pokazuje
               ten stan kolorem neutralnym: zielony i czerwony maja znaczyc fakt, a nie
               brak wiedzy.

    UWAGA, KTORA MUSI ZOSTAC PRZY TEJ FUNKCJI: milczenie na ping NIE JEST dowodem, ze
    maszyna jest wylaczona. Zapora Windows blokuje ICMP w konfiguracji domyslnej wielu
    firm. "Nie odpowiada" znaczy dokladnie tyle, ile mowi - nic wiecej.
#>
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

    if (-not $adresy -or @($adresy).Count -eq 0) {
        $wynik.Blad      = 'nazwa nierozpoznana'
        $wynik.Szczegoly = 'DNS odpowiedział, ale nie podał żadnego adresu dla "{0}".' -f $Nazwa
        return $wynik
    }

    $adres = @($adresy | Where-Object {
        $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork })[0]
    if (-not $adres) { $adres = @($adresy)[0] }

    # ADRES ZAPISUJEMY NAWET GDY MASZYNA NIE ODPOWIE. DNS ja zna - to osobny fakt od tego,
    # czy jest wlaczona, i wlasnie on jest potrzebny do polaczenia zdalnego.
    $wynik.Adres = [string]$adres

    $pozostalo = $LimitMs - $zegar.ElapsedMilliseconds
    if ($pozostalo -le 0) {
        $wynik.Blad      = 'brak czasu na ping'
        $wynik.Szczegoly = 'Rozpoznanie nazwy "{0}" zajęło cały budżet {1} ms - na ping nie zostało nic.' -f $Nazwa, $LimitMs
        return $wynik
    }

    $ping = $null
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $odpowiedz = $ping.Send($adres, [int]$pozostalo)

        $wynik.Odpowiada = ($odpowiedz.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
        $wynik.Szczegoly = if ($wynik.Odpowiada) {
            '{0} ({1}) odpowiedział w {2} ms.' -f $Nazwa, $adres, $odpowiedz.RoundtripTime
        } else {
            '{0} ({1}) nie odpowiedział na ping: {2}. To NIE jest dowód, że maszyna jest wyłączona - zapora często blokuje ICMP.' -f $Nazwa, $adres, $odpowiedz.Status
        }
    }
    catch {
        # Odpowiada zostaje $null: sonda sie nie odbyla, wiec nie wiemy nic o maszynie.
        $wynik.Blad      = 'ping nie doszedł do skutku'
        $wynik.Szczegoly = 'Ping na {0} ({1}) zawiódł: {2}' -f $Nazwa, $adres, $_.Exception.Message
    }
    finally {
        if ($ping) { try { $ping.Dispose() } catch { } }
    }

    return $wynik
}

# Sprawdza komputer w AD po nazwie NetBIOS. Widok komputera jest celowo krotszy od widoku
# konta - odpowiada na trzy pytania: gdzie w drzewie AD lezy ten komputer, kto ostatnio
# z niego korzystal (to idzie w tlo, do SCCM) i kto go do AD dodal.
# Nazwa NetBIOS jest dla Get-ADComputer prawidlowa tozsamoscia, wiec wystarczy -Identity;
# AD dopasowuje ja przy tym BEZ rozrozniania wielkosci liter, wiec literowka w wielkosci
# liter nie wymaga tu zadnego kodu - wystarczy pokazac pisownie, ktora oddalo AD.
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

        # AD nie ma atrybutu "tworca". Wlasciciel obiektu to konto, ktore go zalozylo -
        # z jednym zastrzezeniem: gdy zakladal go czlonek Administratorow domeny, AD wpisuje
        # tu GRUPE, a nie osobe. Dlatego obok podpisu idzie flaga, czy to w ogole osoba.
        # mS-DS-CreatorSID celowo NIE jest czytany: wypelnia go wylacznie dolaczenie maszyny
        # do domeny przez zwyklego uzytkownika, a tutaj wszystkie zaklada administrator.
        $wlasciciel = ''
        try {
            # Pole przez PSObject.Properties, a NIE przez typ: ActiveDirectorySecurity nie
            # istnieje pod pwsh na macOS, wiec sprawdzenie typu wylaczyloby te funkcje
            # z zestawu weryfikacyjnego. Ten sam powod co w Get-JezykOpisBleduWmi.
            $deskryptor = $komputer.nTSecurityDescriptor
            if ($deskryptor -and $deskryptor.PSObject.Properties['Owner']) {
                $wlasciciel = [string]$deskryptor.Owner
            }
        }
        catch {
            # Brak prawa odczytu deskryptora nie ma prawa przewrocic wyszukiwania komputera:
            # katalog i uzytkownik maszyny sa nadal prawdziwa odpowiedzia.
            $wlasciciel = ''
        }

        $podpis = Get-JezykPodpisWlasciciela -Wlasciciel $wlasciciel -Serwer $Script:Config.Domena

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
            Utworzono   = $utworzono
            # Nazwa Z AD, a nie ta wpisana: AD dopasowuje nazwe NetBIOS bez rozrozniania
            # wielkosci liter, wiec "jez-0123" znajduje JEZ-0123 - i to pisownia z AD ma
            # trafic przed oczy operatora.
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
