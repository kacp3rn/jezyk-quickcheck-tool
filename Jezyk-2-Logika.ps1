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

# Sciezka do programu uruchamianego przez przycisk "Polacz" - jedyne miejsce w Jezyku,
# w ktorym cokolwiek startuje jako osobny proces. Zadanie tej zapory jest wezsze niz
# "czy plik istnieje": ma NIE PRZEPUSCIC sciezki, ktora system musialby dopiero gdzies
# odszukac. Sama nazwa pliku ("CmRcViewer.exe") poszlaby po PATH, a sciezka wzgledna po
# biezacym katalogu - w obu przypadkach o tym, co sie uruchomi, decydowalaby maszyna
# operatora, a nie konfiguracja (twarda zasada nr 1).
#
# KSZTALT SPRAWDZAMY WLASNYM WZORCEM, A NIE [System.IO.Path]::IsPathRooted. Tamta metoda
# odpowiada na INNE PYTANIE niz nasze: mowi, czy sciezka jest zakotwiczona wedlug regul
# platformy, na ktorej akurat pracuje. My pytamy wezej i konkretnie - czy to PELNA SCIEZKA
# WINDOWSOWA, czyli litera dysku albo UNC, bo tylko taka ma tu sens. Regula wpisana wprost
# nie zalezy od niczego poza soba i mowi dokladnie to, co sprawdza.
#
# Istnienia pliku NIE sprawdzamy tutaj: Test-Path na martwym udziale sieciowym potrafi
# stanac na dlugo, a te funkcje wola sie z watku interfejsu. Brakujacy plik i tak zglosi
# sie wyjatkiem przy uruchomieniu - i tam ma nazwe, ktora da sie pokazac operatorowi.
function Test-JezykSciezkaProgramu {
    param([string]$Sciezka)

    if ([string]::IsNullOrWhiteSpace($Sciezka)) { return $false }
    if ($Sciezka.Length -gt 260) { return $false }
    # Znaki sterujace i cudzyslow - to drugie dlatego, ze wartosc trafia do wiersza
    # polecen tworzonego procesu, gdzie cudzyslow ma znaczenie skladniowe.
    if ($Sciezka -match '["\x00-\x1F]') { return $false }
    if (-not $Sciezka.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) { return $false }

    # Litera dysku (C:\...) albo UNC (\\serwer\...). Nic innego nie jest sciezka pelna.
    return ($Sciezka -match '^(?:[A-Za-z]:\\|\\\\[^\\])')
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
    # JEDNA PISOWNIA. $tekst i $Tekst to dla PowerShella ta sama zmienna, wiec dwie pisownie
    # nie znacza dwoch wartosci - znacza tylko, ze czytajacy moze tak pomyslec. Zapora:
    # Weryfikacja/spojnosc.ps1.
    $Tekst = $Tekst.Trim()
    if (-not $Tekst) { return $false }

    if ($Tekst -notmatch '^[0-9+()\s./-]+$') { return $false }

    $cyfry = Get-JezykCyfry $Tekst
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

    # Zdalna konsola jest opcjonalna: puste = przycisk "Połącz" sie nie pojawia. Wpis BLEDNY
    # juz nie - przycisk pokazywalby sie przy kazdej wykrytej maszynie, a kazde klikniecie
    # konczylo sie tym samym komunikatem, czyli literowka wygladalaby na awarie konsoli.
    $sciezkaRc = ([string]$Script:Ustawienia.SciezkaRemoteControl).Trim()
    if ($sciezkaRc -and -not (Test-JezykSciezkaProgramu $sciezkaRc)) {
        $bledy += 'SciezkaRemoteControl: "{0}" nie jest pełną ścieżką do pliku .exe (wymagana litera dysku albo \\serwer).' -f $sciezkaRc
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

        # Nazwy grup gotowe do pokazania - patrz Get-JezykNazwyGrup. Tablica, a nie napis:
        # okno stawia je jedna pod druga na liscie, a sklejenie ich tutaj kazaloby mu ten
        # napis z powrotem rozebrac.
        [string[]]$Grupy = @(),

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

        # DOKLADNIE ZAKLADKA "Czlonek grupy" Z KONSOLI AD, i tylko ona. Nie ma tu grupy
        # PODSTAWOWEJ (zwykle "Uzytkownicy domeny") - AD nie trzyma jej w memberOf, tylko
        # w primaryGroupID - ani czlonkostw DZIEDZICZONYCH przez grupy zagniezdzone.
        # Obie granice sa swiadome: rozwiniecie drzewa to zapytanie rekurencyjne do
        # kontrolera, czyli dokladnie ta klasa kosztu, ktorej to pole mialo nie miec.
        #
        # ODSIANIE PUSTYCH JEST WARUNKIEM POPRAWNOSCI, A NIE PORZADKAMI. @($null) to
        # w PowerShellu tablica JEDNOELEMENTOWA, wiec konto bez grup przyszlo by tu
        # z Count = 1 - przycisk "Grupy AD" zapalalby sie przy KAZDYM koncie i otwieral
        # liste z jedna pusta pozycja. Filtr gwarantuje, ze Count niesie liczbe grup.
        Grupy = @($Grupy | Where-Object { $_ })

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
    Nazwy kont zapisane w JEDNYM polu SCCM - kazda bez przedrostka domeny.

.DESCRIPTION
    Jedna regula rozbierania takiego pola, w jednym miejscu. Pola z nazwami uzytkownikow
    bywaja zapisane raz jako "konto", raz jako "DOMENA\konto", a PrimaryUser dodatkowo bywa
    LISTA kont oddzielonych przecinkami. Korzystaja z tej reguly dwie rzeczy: licznik
    odrebnych kont na maszynie i dopasowanie loginu do wiersza - czyli miejsce, w ktorym
    zapada decyzja, czyja to maszyna. Dwie kopie rozjechalyby sie przy pierwszej zmianie.
#>
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
    $surowe   = (Get-JezykKontaZPola ([string]$Wiersz.CurrentLogonUser)) +
                (Get-JezykKontaZPola ([string]$Wiersz.LastLogonUser)) +
                (Get-JezykKontaZPola ([string]$Wiersz.PrimaryUser))

    foreach ($bezDomeny in $surowe) {
        $klucz = $bezDomeny.ToLowerInvariant()
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

    JEDNA OSOBA MIEWA KILKA URZADZEN, wiec oddajemy ich uszeregowana liste (Urzadzenia,
    do LimitUrzadzen pozycji) razem z liczba wszystkich dopasowan (IleUrzadzen). W polu
    okna miesci sie jedna nazwa z data i tak ma zostac; reszta idzie pod niebieski "!".
    Pierwsza pozycja listy JEST ta z pola - obie biora sie z tego samego szeregowania,
    patrz Select-JezykMaszyneDlaLoginu.

    Sonda ICMP, adres i karta sieciowa opisuja WYLACZNIE pozycje pierwsza. Nie jest to
    oszczednosc, tylko odpowiedz na pytanie, ktore operator zadal: pyta o maszyne, przy
    ktorej ktos siedzi, a nie o stan wszystkiego, co kiedykolwiek jej przypisano.
#>
<#
.SYNOPSIS
    Wybiera adres MAC karty, ktora odpowiada pod wskazanym adresem IP.

.DESCRIPTION
    Maszyna miewa kilka kart naraz - Ethernet, Wi-Fi, czesto jeszcze VPN albo Hyper-V -
    a inwentaryzacja SCCM oddaje je wszystkie. Adres wziety "z brzegu" opisywalby inna
    karte niz ta, ktora odpowiada pod pokazanym IP, i NIC BY TEGO NIE ZDRADZILO: jeden
    adres MAC wyglada w oknie dokladnie jak kazdy inny.

    Jedna karta miewa adres IPv4 i IPv6 naraz, a inwentaryzacja oddaje je raz tablica, raz
    jednym napisem po przecinku - wiec ksztaltu nie zakladamy wcale, patrz komentarz
    w ciele funkcji.

    Brak dopasowania oddajemy jako pusty napis, a nie jako pierwszy lepszy adres: "nie
    wiadomo" i "wiadomo, ze ten" to dwie rozne odpowiedzi.
#>
function Get-JezykMacDlaAdresu {
    param($Karty, [string]$Adres)

    if (-not $Adres) { return '' }

    $szukany = $Adres.Trim()

    foreach ($karta in @($Karty)) {
        if (-not $karta) { continue }
        if (-not $karta.MACAddress) { continue }

        # KSZTALTU IPAddress NIE ZAKLADAMY. Inwentaryzacja sprzetu splaszcza wlasciwosci
        # tablicowe do jednego napisu, wiec ta sama karta potrafi przyjsc raz jako tablica
        # adresow, a raz jako "10.0.0.5, fe80::1" w calosci - a wtedy porownanie calego
        # napisu z pojedynczym adresem jest falszywe dla KAZDEJ karty z IPv6 i adres MAC
        # po prostu nie wychodzi. Rozbieramy wiec kazdy element, zamiast ufac, ze jest juz
        # rozebrany. Porownanie zostaje DOKLADNE: fragment adresu nie jest adresem.
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

<#
.SYNOPSIS
    Wybiera z wierszy SCCM maszyne nalezaca do podanego loginu - i mowi, po czym ja poznal.

.DESCRIPTION
    TO TUTAJ ZAPADA DECYZJA, CZY TO TEN LOGIN, a nie w zapytaniu WQL. Wzorzec LIKE robi
    wylacznie zgrubny przesiew, bo tego, jak dostawca SMS traktuje w nim odwrotny ukosnik,
    nie da sie orzec z gory: przy jednej interpretacji "%\\jan" znaczy "cokolwiek, ukosnik,
    jan", przy drugiej - "cokolwiek i DWA ukosniki". Zapis "DOMENA\jan" wypadal przez to raz
    tak, raz inaczej - stad zgloszenie "czasami nie pokazuje komputera", choc uzytkownik byl
    zalogowany. Tutaj regul nie musimy zgadywac, bo rozbieramy pole sami.

    PRZESIEW JEST SZERSZY NIZ ODPOWIEDZ i tak ma byc: "%jan%" lapie tez "janine" i "bojana",
    a podkreslenie jest w LIKE znakiem wieloznacznym, wiec "jan_k" lapie "jan1k". Dopasowanie
    ponizej jest dokladne, wiec wszystko to odpada - i wlasnie dlatego wzorzec nie potrzebuje
    juz zadnego uciekania znakow.

    KOLEJNOSC POL NIESIE ODPOWIEDZ NA PYTANIE OPERATORA. Pyta on, przy ktorej maszynie ta
    osoba siedzi: CurrentLogonUser znaczy "siedzi przy niej teraz", LastLogonUser - "siedziala
    ostatnio", a PrimaryUser to przypisanie, a nie zdarzenie. Data aktywnosci rozstrzyga
    dopiero WEWNATRZ stopnia; liczona ponad nim wysuwalaby wiecznie wlaczony komputer wspolny
    przed laptopa, przy ktorym operator faktycznie kogos szuka.

    Porownanie idzie BEZ WZGLEDU NA WIELKOSC LITER (-contains, nie -ccontains) i tak ma
    zostac: AD nie rozroznia wielkosci w nazwie konta, a SCCM zapisuje ja tak, jak przyszla
    od klienta. To jest odwrotnosc pulapki z nazwami zmiennych - tam wielkosc liter MUSI byc
    brana pod uwage, tutaj brac jej pod uwage nie wolno.

    Wiersz bez nazwy maszyny nie liczy sie za trafienie: nie ma go czym pokazac w polu,
    a zajalby miejsce prawdziwej odpowiedzi z kolejnego zrodla.

    ODDAJEMY CALA USZEREGOWANA LISTE, a zwyciezczyni jest po prostu jej pierwsza pozycja.
    Dwie osobne reguly - jedna wybierajaca maszyne do pola, druga ustawiajaca liste pod
    przyciskiem "!" - rozjechalyby sie przy pierwszej zmianie i okno pokazywaloby w polu
    inna maszyne, niz lista obok podaje jako pierwsza.
#>
function Select-JezykMaszyneDlaLoginu {
    param($Wiersze, [string]$Login,
          $Pola = @('CurrentLogonUser', 'LastLogonUser', 'PrimaryUser'))

    $wynik = [pscustomobject]@{ Wiersz = $null; Pole = ''; Data = $null; Ile = 0; Lista = @() }
    if (-not $Login) { return $wynik }

    $nazwyPol = @($Pola)
    $pozycje  = New-Object System.Collections.Generic.List[object]
    $indeks   = 0

    foreach ($wiersz in @($Wiersze)) {
        if (-not $wiersz) { continue }

        # NetbiosName jest tylko w SMS_R_System; pozostale zrodla maja samo Name.
        $nazwa = [string]$wiersz.NetbiosName
        if (-not $nazwa) { $nazwa = [string]$wiersz.Name }
        if (-not $nazwa) { continue }

        $stopien = -1
        for ($i = 0; $i -lt $nazwyPol.Count; $i++) {
            $nazwaPola = $nazwyPol[$i]
            if ((Get-JezykKontaZPola ([string]$wiersz.$nazwaPola)) -contains $Login) {
                $stopien = $i
                break
            }
        }
        if ($stopien -lt 0) { continue }

        $kiedy = ConvertTo-JezykCzasLokalny $wiersz.LastActiveTime

        # Id sluzy do doczytania daty i tylko do tego - zrodla 2 i 3 nie znaja
        # LastActiveTime wcale. Zero znaczy "to zrodlo nie poda identyfikatora zasobu".
        $id = 0
        if ($wiersz.ResourceID) { try { $id = [int]$wiersz.ResourceID } catch { $id = 0 } }

        $pozycje.Add([pscustomobject]@{
            Nazwa   = $nazwa
            Pole    = $nazwyPol[$stopien]
            Data    = $kiedy
            Id      = $id
            Wiersz  = $wiersz
            Stopien = $stopien
            # Sortujemy rosnaco, wiec "bez daty" musi byc WIEKSZE - pozycja bez daty ma
            # stanac za kazda datowana z tego samego stopnia, dokladnie tak jak dotad.
            BezDaty = [int]($null -eq $kiedy)
            Indeks  = $indeks })
        $indeks++
    }

    if ($pozycje.Count -eq 0) { return $wynik }

    # INDEKS JAKO OSTATNI KLUCZ, a nie zdanie sie na stabilnosc sortowania: Sort-Object
    # kolejnosci elementow rownych nie gwarantuje, a od niej zalezy, ktora maszyna trafi
    # do pola, gdy dwie maja te sama date. Nizszy stopien bije kazda date; data rozstrzyga
    # tylko w obrebie tego samego stopnia.
    $uszeregowane = @($pozycje | Sort-Object -Property @{ Expression = 'Stopien' },
                                                       @{ Expression = 'BezDaty' },
                                                       @{ Expression = 'Data'; Descending = $true },
                                                       @{ Expression = 'Indeks' })

    $wynik.Lista  = @($uszeregowane | ForEach-Object {
                        [pscustomobject]@{ Nazwa = $_.Nazwa; Pole = $_.Pole; Data = $_.Data; Id = $_.Id } })
    $wynik.Ile    = $uszeregowane.Count
    $wynik.Wiersz = $uszeregowane[0].Wiersz
    $wynik.Pole   = $uszeregowane[0].Pole
    $wynik.Data   = $uszeregowane[0].Data

    return $wynik
}

function Get-JezykOstatnioUzywanyKomputer {
    param([string]$Login, [string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom',
          [bool]$ProtokolZapasowy = $false, [int]$LimitSek = 15, [int]$LimitUrzadzen = 3)

    # Odpowiada i Adres wypelnia sonda ICMP na samym koncu, po ustaleniu nazwy maszyny.
    # $null w Odpowiada znaczy "nie sprawdzono albo nie wiadomo" i tak ma zostac na kazdej
    # sciezce bledu - patrz Get-JezykPingKomputera.
    # Mac wypelnia sie PO sondzie i tylko wtedy, gdy karta z inwentaryzacji SCCM ma ten sam
    # adres IP, ktory oddalo rozwiazanie nazwy. MacSzczegoly niesie powod, gdy sie nie udalo.
    #
    # Urzadzenia to uszeregowana lista dopasowanych maszyn - do LimitUrzadzen pozycji,
    # pierwsza jest zawsze ta, ktorej nazwa stoi w polu. IleUrzadzen mowi, ile dopasowano
    # NAPRAWDE, bo to dwie rozne liczby i operator ma prawo znac obie.
    #
    # Limit jest WARTOSCIA DOMYSLNA PARAMETRU, a nie zmienna skryptowa: ta funkcja biegnie
    # w przestrzeni uruchomieniowej w tle, a ta startuje pusta i zadnego $Script:... w niej
    # nie ma.
    $wynik = [pscustomobject]@{ Nazwa = ''; Data = $null; Odpowiada = $null; Adres = ''
                                Blad = ''; Szczegoly = ''
                                Wspoldzielony = $false; SzczegolyWspoldzielenia = ''
                                Urzadzenia = @(); IleUrzadzen = 0
                                Mac = ''; MacSzczegoly = '' }

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
        # WZORZEC JEST PRZESIEWEM, NIE ODPOWIEDZIA. Nazwy uzytkownika bywaja zapisane raz
        # jako "konto", raz jako "DOMENA\konto", a PrimaryUser potrafi byc LISTA kont po
        # przecinku - dotad lapal to wzorzec "%\\konto", czyli ZALOZENIE o tym, ze dostawca
        # SMS traktuje odwrotny ukosnik jako znak ucieczki. Zalozenia nie da sie sprawdzic
        # ani stad, ani testem, a gdy jest falszywe, zapis z domena nie trafia NIGDY.
        # Dlatego wzorzec nie zawiera juz ukosnika ani uciekania znakow, a o tym, czy to ten
        # login, rozstrzyga Select-JezykMaszyneDlaLoginu - patrz jego opis.
        #
        # Pole, po ktorym przesiewamy, musi tez byc W SELECT: bez niego dopasowanie nie ma
        # czego czytac i odrzucaloby kazdy wiersz zrodla 2 i 3.
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
        $poleTrafienia = ''
        $ileMaszyn     = 0
        $urzadzenia    = @()
        $zrodlo        = ''
        $stos          = 'CIM'
        $odmowa        = $null
        $niedostepne   = @()

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

            # Zrodlo liczy sie za trafione dopiero wtedy, gdy DOPASOWANIE oddalo wiersz.
            # Sam niepusty wynik nie wystarcza z dwoch powodow naraz: przesiew LIKE jest
            # szerszy od odpowiedzi (przy "janie" lapie takze "janine"), a klasa, ktora
            # zwrocila rekordy bez Name i bez NetbiosName, nie ma czego pokazac w polu.
            # Odrzucenie wszystkich wierszy NIE konczy przeszukiwania - kolejne zrodla ida
            # normalnie; dawniej falszywe trafienie ucinalo je i pokazywalo cudza maszyne.
            $trafienie = Select-JezykMaszyneDlaLoginu -Wiersze $odp.Wiersze -Login $Login -Pola $z.Pola
            if ($trafienie.Wiersz) {
                $najlepsza     = $trafienie.Wiersz
                $poleTrafienia = $trafienie.Pole
                $ileMaszyn     = $trafienie.Ile
                $urzadzenia    = @(@($trafienie.Lista) | Select-Object -First $LimitUrzadzen)
                $zrodlo        = $z.Nazwa
                $stos          = $odp.Stos
                break
            }
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
            $wynik.Szczegoly = $szczegolyBraku -join [Environment]::NewLine
            return $wynik
        }

        # Aktywnosc jest DODATKIEM: brak klasy albo brak prawa do niej zostawia same nazwy.
        # Date niosa wiersze pierwszego zrodla i wtedy jest juz w pozycjach; zrodla 2 i 3 nie
        # znaja jej wcale, wiec dla nich pytamy osobno - JEDNYM zapytaniem o WSZYSTKIE
        # pokazywane maszyny naraz. Po jednym zapytaniu na maszyne kosztowaloby trzy podroze
        # po sieci zamiast jednej, za dokladnie te sama odpowiedz.
        $bezDaty = @($urzadzenia | Where-Object { $null -eq $_.Data -and $_.Id -gt 0 })
        if ($bezDaty.Count) {
            try {
                # ResourceId przez [int] - do zapytania trafiaja wtedy same liczby, niezaleznie
                # od tego, co oddal serwer.
                $warunki = @($bezDaty | ForEach-Object { 'ResourceId = {0}' -f [int]$_.Id })
                $daty    = @{}
                foreach ($wpis in @(Invoke-JezykZapytanieWmi -Sesja $sesja.Sesja -Przestrzen $przestrzen -LimitSek $LimitSek `
                                        -Zapytanie (
                    "SELECT ResourceId, LastActiveTime FROM SMS_CombinedDeviceResources WHERE " +
                    ($warunki -join ' OR ')))) {
                    $kiedy = ConvertTo-JezykCzasLokalny $wpis.LastActiveTime
                    if ($null -ne $kiedy) { $daty[[string][int]$wpis.ResourceId] = $kiedy }
                }

                foreach ($pozycja in $bezDaty) {
                    $klucz = [string][int]$pozycja.Id
                    if ($daty.ContainsKey($klucz)) { $pozycja.Data = $daty[$klucz] }
                }
            }
            catch { }
        }

        # NAZWA I DATA BIORA SIE Z PIERWSZEJ POZYCJI LISTY, a nie z osobnej arytmetyki obok:
        # pole i lista pod przyciskiem "!" maja mowic o tej samej maszynie, a dwa wyliczenia
        # tej samej rzeczy rozjezdzaja sie przy pierwszej zmianie.
        $wynik.Urzadzenia  = $urzadzenia
        $wynik.IleUrzadzen = $ileMaszyn
        $wynik.Nazwa       = [string]$urzadzenia[0].Nazwa
        $wynik.Data        = $urzadzenia[0].Data

        # Wieloosobowosc sprawdzamy WYLACZNIE, gdy trafilo pierwsze zrodlo - tylko ono
        # niesie CurrentLogonUser/LastLogonUser/PrimaryUser w wierszu (zrodla 2 i 3 tych
        # pol w ogole nie znaja, wiec dla nich nie ma jak tego rozstrzygnac).
        if ($zrodlo -eq $zrodla[0].Nazwa) {
            $konta = Get-JezykKontaMaszyny -Wiersz $najlepsza
            if ($konta.Count -gt 1) {
                $wynik.Wspoldzielony = $true
                $wynik.SzczegolyWspoldzielenia =
                    'SCCM zna na maszynie {0} więcej niż jedno konto ({1}) - pokazana data i nazwa mogą dotyczyć innej osoby niż {2}.' -f
                        $wynik.Nazwa, ($konta -join ', '), $Login
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

        # ADRES MAC MUSI PASOWAC DO POKAZANEGO IP, a nie byc "jakims" adresem maszyny.
        # Laptop ma Ethernet, Wi-Fi, czesto jeszcze karte VPN albo Hyper-V - wybranie
        # pierwszego z brzegu dawaloby adres innej karty niz ta, ktora odpowiada pod tym IP,
        # i nic by tego nie zdradzilo. Dlatego pytamy o karty Z ICH ADRESAMI i dopasowujemy.
        #
        # Inwentaryzacja bywa starsza od dzierzawy DHCP, wiec BRAK DOPASOWANIA jest zwyklym,
        # spodziewanym wynikiem - i ma wyjsc jako "nie wiadomo", a nie jako cudzy adres.
        if (-not $wynik.Adres) {
            $wynik.MacSzczegoly = 'Nie ustalono adresu IP maszyny, więc nie ma do czego dopasować karty sieciowej.'
        }
        elseif (-not $najlepsza.ResourceID) {
            $wynik.MacSzczegoly = 'Źródło, które podało tę maszynę, nie niesie identyfikatora zasobu (ResourceID), a bez niego nie ma jak zapytać o jej karty sieciowe.'
        }
        else {
            try {
                $idKarty = [int]$najlepsza.ResourceID
                $karty = @(Invoke-JezykZapytanieWmi -Sesja $sesja.Sesja -Przestrzen $przestrzen -LimitSek $LimitSek `
                               -Zapytanie (
                    "SELECT MACAddress, IPAddress FROM SMS_G_System_NETWORK_ADAPTER_CONFIGURATION WHERE ResourceId = $idKarty"))

                $wynik.Mac = Get-JezykMacDlaAdresu -Karty $karty -Adres $wynik.Adres

                if (-not $wynik.Mac) {
                    $wynik.MacSzczegoly = if ($karty.Count) {
                        'Żadna z {0} kart sieciowych znanych SCCM nie ma adresu {1}. Inwentaryzacja sprzętu jest odświeżana co kilka dni, więc po zmianie dzierżawy DHCP zapisany adres bywa starszy niż ten, pod którym maszyna odpowiada teraz.' -f $karty.Count, $wynik.Adres
                    } else {
                        'SCCM nie zna żadnej karty sieciowej tej maszyny. Klasa SMS_G_System_NETWORK_ADAPTER_CONFIGURATION bywa wyłączona w ustawieniach inwentaryzacji sprzętu.'
                    }
                }
            }
            catch {
                # Powod zapisujemy, zamiast go polknac: pusty catch zamienilby brak prawa
                # albo wylaczona klase w ciche "brak danych", nie do odroznienia od maszyny
                # bez kart sieciowych.
                $wynik.MacSzczegoly = 'Odczyt kart sieciowych z SCCM zawiódł: {0}' -f $_.Exception.Message
            }
        }

        $opisWyniku = @('źródło: {0}; protokół: {1}; stos: {2}; serwer: {3}' -f
                        $zrodlo, $sesja.Protokol, $stos, $polaczenie.Serwer)
        if ($opisPingu) { $opisWyniku += $opisPingu }
        if ($ileMaszyn -gt 1) {
            $opisWyniku += 'dopasowanych maszyn: {0}; pokazana ta z najświeższym śladem logowania (pole {1})' -f $ileMaszyn, $poleTrafienia
        }
        if ($niedostepne.Count) {
            $opisWyniku += 'klasy, które nie odpowiedziały: {0}' -f ($niedostepne -join '; ')
        }
        if ($null -eq $wynik.Data) {
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

    MASZYNA MIEWA KILKA KONT, wiec obok pokazanego uzytkownika oddajemy ich liste (Konta,
    do LimitKont pozycji). NIE JEST TO HISTORIA LOGOWAN i nie da sie jej stad zrobic: te
    trzy klasy trzymaja po jednym rekordzie na maszyne, a nie dziennik. Lista wymienia wiec
    konta z ROZNYCH POL tego samego rekordu - zalogowane teraz, zalogowane ostatnio,
    przypisane na stale - i tylko widok potrafi to nazwac tak, zeby nikt nie wzial trzech
    rol za trzy kolejne logowania.

    Razem z uzytkownikiem oddajemy DOSTEPNOSC MASZYNY (sonda ICMP) i adres MAC karty, ktora
    odpowiada pod znalezionym adresem - tak samo jak droga odwrotna i z tego samego powodu:
    obie rzeczy sa dodatkiem do zapytania, ktore i tak idzie w tle, wiec nie kosztuja okna
    ani jednej milisekundy. Nazwy pol sa IDENTYCZNE jak w Get-JezykOstatnioUzywanyKomputer,
    zeby widok mial jedna sciezke renderowania dla obu polowek okna.
#>
function Get-JezykUzytkownikKomputera {
    param([string]$Netbios, [string]$Serwer = '', [string]$KodLokacji = '', [string]$Protokol = 'Dcom',
          [bool]$ProtokolZapasowy = $false, [int]$LimitSek = 15, [int]$LimitKont = 3)

    # Konta to lista odrebnych kont TEGO rekordu - do LimitKont pozycji, pierwsze jest to,
    # ktore stoi w polu. Kazde niesie nazwy pol, w ktorych wystapilo; na slowa operatora
    # zamienia je widok. Limit jest wartoscia domyslna parametru, a nie zmienna skryptowa:
    # funkcja biegnie w przestrzeni uruchomieniowej w tle, a ta startuje pusta.
    $wynik = [pscustomobject]@{ Uzytkownik = ''; Data = $null; Blad = ''; Szczegoly = ''
                                Odpowiada = $null; Adres = ''; Mac = ''; MacSzczegoly = ''
                                Konta = @() }

    # Nazwa pochodzi z AD, wiec jest bezpieczna - ale zapytanie budowane z tekstu sprawdza
    # sie ZAWSZE, a nie tylko wtedy, gdy wyglada to na potrzebne.
    if (-not (Test-JezykNazwaKonta $Netbios)) {
        $wynik.Blad      = 'nieprawidłowa nazwa komputera'
        $wynik.Szczegoly = 'Nazwa "{0}" zawiera znaki spoza dozwolonego zestawu.' -f $Netbios
        return $wynik
    }

    # SONDA ICMP PRZED ZAPYTANIEM DO SCCM, a nie po nim. Z tej funkcji wychodzi PIEC drog
    # powrotu (brak ustawien, brak sesji, odmowa, brak zapisanego uzytkownika, wynik),
    # a dostepnosc maszyny jest prawdziwa odpowiedzia w kazdej z nich - ICMP nie potrzebuje
    # SCCM do niczego. Postawiona na koncu wypadlaby ze wszystkich drog poza ostatnia,
    # czyli akurat tam, gdzie maszyny nie ma w inwentaryzacji, a pytanie "czy ona w ogole
    # odpowiada" jest najczestsze. Cena to najwyzej 1,5 s (caly budzet sondy) doliczone do
    # zapytania z wlasnym limitem 15 s, w polu, ktore i tak animuje kropki.
    #
    # Wlasny try: sonda jest DODATKIEM. Uzytkownik maszyny ma sie pokazac takze wtedy, gdy
    # sprawdzenie dostepnosci samo zawiedzie.
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
        # Kolejnosc jak przy drodze odwrotnej: najpierw klasa, ktora zasila wezel "Devices"
        # w konsoli, bo to ona jest odswiezana najczesciej i niesie od razu date aktywnosci.
        # Pola w kazdym zrodle sa uporzadkowane OD NAJSWIEZSZEGO: trwajaca sesja przed
        # ostatnia zakonczona, a uzytkownik glowny na koncu, bo opisuje przypisanie, a nie
        # zdarzenie.
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
        $konta       = New-Object System.Collections.Generic.List[object]
        $widziane    = @{}
        $zrodlo      = ''
        $stos        = 'CIM'
        $data        = $null
        $odmowa      = $null
        $niedostepne = @()
        $znaleziona  = $false
        # Wiersz, ktory opisal TE maszyne - trzymany wylacznie dla identyfikatora zasobu,
        # ktorym pytamy pozniej o karty sieciowe.
        $wierszMaszyny = $null

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
                if ($wiersz.Name -or $wiersz.NetbiosName) {
                    $znaleziona = $true
                    # PIERWSZY wiersz opisujacy maszyne, takze gdy nie niesie zadnego
                    # uzytkownika: karta sieciowa jest wtedy nadal znana, a maszyna
                    # w inwentaryzacji bez zapisanego logowania to czesty przypadek.
                    if (-not $wierszMaszyny) { $wierszMaszyny = $wiersz }
                }

                # PETLA IDZIE PRZEZ WSZYSTKIE POLA, a nie konczy sie na pierwszym niepustym.
                # W polu okna nadal staje pierwsze - to sie nie zmienia - ale jedna maszyna
                # miewa konto zalogowane teraz, inne ostatnio i jeszcze inne przypisane na
                # stale, a operator pyta wlasnie o nie.
                foreach ($nazwaPola in $z.Pola) {
                    $wartosc = ([string]$wiersz.$nazwaPola).Trim()
                    if (-not $wartosc) { continue }

                    if (-not $uzytkownik) {
                        $uzytkownik = $wartosc
                        $pole       = $nazwaPola
                    }

                    # PrimaryUser bywa LISTA kont po przecinku, wiec kazde pole rozbieramy.
                    foreach ($zapis in $wartosc -split ',') {
                        $pelny = $zapis.Trim()
                        if (-not $pelny) { continue }

                        # PELNY ZAPIS W OKNIE, POROWNANIE PO SAMEJ NAZWIE KONTA. Pokazujemy
                        # to, co zapisal SCCM - razem z przedrostkiem domeny - bo operator
                        # porownuje to z konsola. O tym, CZY TO TO SAMO KONTO, rozstrzyga
                        # Get-JezykKontaZPola: "jkowalski" i "JEZYK\JKowalski" to jedna
                        # osoba. Bez tego jeden czlowiek wyczerpalby caly limit pozycji
                        # i drugi uzytkownik maszyny nie zmiescilby sie na liscie.
                        #
                        # Tablice PRZYPISUJEMY do zmiennej - @(Get-JezykKontaZPola ...) nie
                        # rozwinaloby jej, tylko owinelo w jednoelementowa tablice tablic.
                        $bezDomeny = Get-JezykKontaZPola $pelny
                        if ($bezDomeny.Count -eq 0) { continue }

                        $klucz = $bezDomeny[0].ToLowerInvariant()
                        if (-not $klucz) { continue }

                        if ($widziane.ContainsKey($klucz)) {
                            $znane = $widziane[$klucz]
                            if ($znane.Pola -notcontains $nazwaPola) { $znane.Pola += $nazwaPola }
                            continue
                        }

                        $pozycja = [pscustomobject]@{ Nazwa = $pelny; Pola = @($nazwaPola) }
                        $widziane[$klucz] = $pozycja
                        $konta.Add($pozycja)
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

        # ADRES MAC MUSI PASOWAC DO POKAZANEGO IP, a nie byc "jakims" adresem maszyny -
        # ten sam powod i ten sam sposob, co przy drodze odwrotnej: laptop ma Ethernet,
        # Wi-Fi, czesto jeszcze karte VPN albo Hyper-V, a jeden adres MAC wyglada w oknie
        # dokladnie jak kazdy inny.
        #
        # Blok stoi PO odmowie (tam przestrzeni juz raz odmowiono, wiec pytanie o karty
        # powtorzyloby tylko te sama odmowe), ale PRZED wyjsciem "brak zapisanego
        # uzytkownika": maszyna bywa w inwentaryzacji bez zapisanego logowania, a karte
        # sieciowa SCCM zna wtedy tak samo dobrze.
        #
        # Maszyny NIEZNANEJ w SCCM zostawiamy bez powodu - pole ma wtedy powiedziec
        # "nie sprawdzono", bo nie bylo czego dopasowywac, a nie "nie dopasowano".
        if ($wierszMaszyny) {
            if (-not $wynik.Adres) {
                $wynik.MacSzczegoly = 'Nie ustalono adresu IP maszyny, więc nie ma do czego dopasować karty sieciowej.'
            }
            elseif (-not $wierszMaszyny.ResourceID) {
                $wynik.MacSzczegoly = 'Źródło, które podało tę maszynę, nie niesie identyfikatora zasobu (ResourceID), a bez niego nie ma jak zapytać o jej karty sieciowe.'
            }
            else {
                try {
                    $idKarty = [int]$wierszMaszyny.ResourceID
                    $karty = @(Invoke-JezykZapytanieWmi -Sesja $sesja.Sesja -Przestrzen $przestrzen -LimitSek $LimitSek `
                                   -Zapytanie (
                        "SELECT MACAddress, IPAddress FROM SMS_G_System_NETWORK_ADAPTER_CONFIGURATION WHERE ResourceId = $idKarty"))

                    $wynik.Mac = Get-JezykMacDlaAdresu -Karty $karty -Adres $wynik.Adres

                    if (-not $wynik.Mac) {
                        $wynik.MacSzczegoly = if ($karty.Count) {
                            'Żadna z {0} kart sieciowych znanych SCCM nie ma adresu {1}. Inwentaryzacja sprzętu jest odświeżana co kilka dni, więc po zmianie dzierżawy DHCP zapisany adres bywa starszy niż ten, pod którym maszyna odpowiada teraz.' -f $karty.Count, $wynik.Adres
                        } else {
                            'SCCM nie zna żadnej karty sieciowej tej maszyny. Klasa SMS_G_System_NETWORK_ADAPTER_CONFIGURATION bywa wyłączona w ustawieniach inwentaryzacji sprzętu.'
                        }
                    }
                }
                catch {
                    # Powod zapisujemy, zamiast go polknac: pusty catch zamienilby brak prawa
                    # albo wylaczona klase w ciche "brak danych", nie do odroznienia od maszyny
                    # bez kart sieciowych.
                    $wynik.MacSzczegoly = 'Odczyt kart sieciowych z SCCM zawiódł: {0}' -f $_.Exception.Message
                }
            }
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
            # Sonda odbyla sie takze na tej drodze, a jej wynik bywa TU najciekawszy: maszyny
            # nie ma w inwentaryzacji, wiec "czy ona w ogole odpowiada" zostaje jedyna
            # odpowiedzia, jaka okno ma. Pole adresu pokazuje ja skrotem, pelne zdanie tutaj.
            if ($opisPingu) { $szczegolyBraku += @('', $opisPingu) }
            $wynik.Szczegoly = $szczegolyBraku -join [Environment]::NewLine
            return $wynik
        }

        $wynik.Uzytkownik = $uzytkownik
        $wynik.Data       = $data
        $wynik.Konta      = @($konta | Select-Object -First $LimitKont)

        $opisWyniku = @('źródło: {0} (pole {1}); protokół: {2}; stos: {3}; serwer: {4}' -f
                        $zrodlo, $pole, $sesja.Protokol, $stos, $polaczenie.Serwer)
        if ($opisPingu) { $opisWyniku += $opisPingu }
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
    Zamienia liste czlonkostw z memberOf na nazwy grup.

.DESCRIPTION
    Atrybut memberOf niesie NAZWY WYROZNIAJACE grup ("CN=GG_Kadry_Odczyt,OU=Grupy,
    DC=jezyk,DC=pl"), a nie nazwy - tak samo jak Manager przy przelozonym. Bierzemy
    pierwszy czlon i zdejmujemy odwrotne ukosniki, ktorymi LDAP oslania przecinki
    w nazwie ("CN=Dzial IT\, Warszawa") - inaczej byly by widoczne w oknie. Wzorzec
    jest ten sam, co przy podpisie zapasowym w Get-JezykPodpisMenedzera: ten sam
    problem ma miec jedna odpowiedz.

    ZADNEGO ZAPYTANIA DO AD. Nazwa grupy siedzi w jej wlasnej nazwie wyrozniajacej,
    wiec odczyt kazdej grupy z osobna bylby N podrozami po sieci po wartosc, ktora
    juz mamy w reku - a lista bywa kilkudziesieciopozycyjna.

    Zapis, ktory nie zaczyna sie od CN=, oddajemy w CALOSCI. Lepiej pokazac nazwe
    wyrozniajaca niz zgubic czlonkostwo, o ktorego istnieniu operator ma sie dowiedziec.

    Sortujemy tutaj, bo memberOf przychodzi w kolejnosci dowolnej, a okno ma tylko
    pokazac gotowa liste - formatowanie po stronie widoku nie ma tu czego rozstrzygac.
#>
function Get-JezykNazwyGrup {
    param($Czlonkostwa)

    $nazwy = @()
    foreach ($dn in @($Czlonkostwa)) {
        $tekst = ([string]$dn).Trim()
        if (-not $tekst) { continue }

        if ($tekst -match '^\s*CN=((?:[^,\\]|\\.)+)') {
            $nazwy += ($Matches[1] -replace '\\(.)', '$1').Trim()
        } else {
            $nazwy += $tekst
        }
    }

    # NAWIASY TU NIE WYSTARCZA I NIE MOGA WYSTARCZYC. PowerShell ROZWIJA tablice oddawana
    # z funkcji: przy zerze grup wolajacy dostaje $null, a przy jednej sam napis, a nie
    # tablice jednoelementowa. Dlatego kazde wywolanie owija sie w @() NA MIEJSCU WYWOLANIA
    # - ta sama konwencja, co przy @(Confirm-JezykUstawienia) - a New-JezykResult odsiewa
    # jeszcze puste pozycje, bo @($null) to tablica JEDNOELEMENTOWA.
    return @($nazwy | Sort-Object -Unique)
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
                                       OfficePhone, MobilePhone, Manager, MemberOf,
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

        # Grupy przychodza W TYM SAMYM ZAPYTANIU, co reszta konta - memberOf jest zwyklym
        # atrybutem obiektu, wiec nie kosztuje ani jednej dodatkowej podrozy po sieci.
        # Nie ma tu drugiego odczytu ani zadania w tle, bo nie ma na co czekac.
        $grupy = @(Get-JezykNazwyGrup $user.MemberOf)

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
                                            telephoneNumber, mobile, memberOf,
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
                               -Grupy @(Get-JezykNazwyGrup $kontakt.memberOf) `
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
<#
.SYNOPSIS
    Adresy maszyny w kolejnosci, w ktorej warto je sondowac.

.DESCRIPTION
    PIERWSZY ADRES Z DNS-A TO NIE JEST ADRES MASZYNY. Maszyna z Ethernetem i Wi-Fi rejestruje
    w DNS OBA adresy, a kolejnosc odpowiedzi nie jest ustalona - serwer podaje je na zmiane.
    Branie "tego z brzegu" dawalo wiec raz adres karty podlaczonej, raz odlaczonej, i to przy
    tej samej maszynie: adres w oknie skakal miedzy wyszukaniami, a razem z nim skakal adres
    MAC, bo karte dopasowujemy do POKAZANEGO adresu. Rekord, ktorego DNS jeszcze nie sprzatnal,
    dokladal do tego czerwone pole przy maszynie, ktora dziala.

    IPv4 przed reszta, bo to jego pokazujemy i to on trafia do zdalnej konsoli. Lista jest
    przycinana, zeby sondowanie miescilo sie w budzecie: maszyna z kilkunastoma adresami
    (tunele, Hyper-V) zjadalaby go na adresach, ktorych i tak nie pokazemy.
#>
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

    # KANDYDACI, A NIE JEDEN ADRES Z BRZEGU - patrz Get-JezykAdresyDoSondy wyzej.
    # Pusta kolejka to jedyny przypadek "DNS odpowiedzial, ale nie ma czego sondowac",
    # wiec i bramka jest jedna: druga, na samej odpowiedzi DNS, sprawdzalaby to samo.
    $kandydaci = Get-JezykAdresyDoSondy -Adresy $adresy
    if (@($kandydaci).Count -eq 0) {
        $wynik.Blad      = 'nazwa nierozpoznana'
        $wynik.Szczegoly = 'DNS odpowiedział, ale nie podał żadnego adresu dla "{0}".' -f $Nazwa
        return $wynik
    }

    # ADRES ZAPISUJEMY NAWET GDY MASZYNA NIE ODPOWIE. DNS ja zna - to osobny fakt od tego,
    # czy jest wlaczona, i wlasnie on jest potrzebny do polaczenia zdalnego. Gdy ktorys
    # z kandydatow odpowie, ten wpis zastapi adres, ktory faktycznie odpowiedzial.
    $wynik.Adres = $kandydaci[0]

    $pozostalo = $LimitMs - $zegar.ElapsedMilliseconds
    if ($pozostalo -le 0) {
        $wynik.Blad      = 'brak czasu na ping'
        $wynik.Szczegoly = 'Rozpoznanie nazwy "{0}" zajęło cały budżet {1} ms - na ping nie zostało nic.' -f $Nazwa, $LimitMs
        return $wynik
    }

    # BUDZET DZIELIMY NA KANDYDATOW, zeby caly pomiar nadal miescil sie w $LimitMs - okno
    # czeka na wynik zadania i dwukrotnie dluzsze czekanie byloby widac. Zatrzymujemy sie
    # na PIERWSZYM, ktory odpowie: to on jest adresem maszyny, a nie ten, ktory DNS podal
    # jako pierwszy.
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

        # $null znaczy tu "petla przeszla do konca i nikt nie odpowiedzial" - wyjatek nie
        # doszedlby w to miejsce wcale, wiec niewiedza nadal nie miesza sie z odpowiedzia.
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

<#
.SYNOPSIS
    Uruchamia zdalna konsole (CmRcViewer.exe z ConfigMgr) dla wskazanej maszyny.

.DESCRIPTION
    JEDYNE miejsce w calym narzedziu, ktore startuje osobny proces. Dotad Jezyk wychodzil
    poza siebie wylacznie przez AD, DNS, ICMP i WMI - i kazda z tych drog wracala z danymi.
    Ta nie wraca z niczym: oddaje maszyne pod cudzy program.

    Sciezka pochodzi WYLACZNIE z $Script:Ustawienia i jest podawana argumentem, a nie
    czytana tutaj - dzieki temu funkcja daje sie sprawdzic bez konfiguracji, a odpowiedz
    na pytanie "co uruchamiamy" ma jedno zrodlo.

    Zwraca ten sam ksztalt, co Unlock-JezykKonto (Udane / Komunikat / Szczegoly), bo widok
    obsluguje oba tak samo: krotkie zdanie do pola Status, pelna tresc pod przycisk "!".
    Funkcja NIE RZUCA WYJATKIEM - jak wszystko, czego wynik ma trafic do okna.

.NOTES
    Bez -Wait: Start-Process wraca zaraz po utworzeniu procesu, wiec watek interfejsu nie
    czeka na zamkniecie konsoli i nie trzeba tu zadania w tle. Z -Wait okno stalo by przez
    cala sesje zdalna.
#>
function Start-JezykRemoteControl {
    param([string]$Netbios, [string]$Sciezka)

    if ($null -eq $Netbios) { $Netbios = '' }
    if ($null -eq $Sciezka) { $Sciezka = '' }
    $Netbios = $Netbios.Trim()
    $Sciezka = $Sciezka.Trim()

    $wynik = [pscustomobject]@{ Udane = $false; Komunikat = ''; Szczegoly = '' }

    # BIALA LISTA NA NAZWIE MASZYNY. Nazwa idzie argumentem tworzonego procesu, czyli
    # w miejsce, gdzie tekst przestaje byc tekstem - ta sama zapora, co przy odczycie
    # komputera z AD i przy zapytaniu do SCCM. Do pola trafia z SCCM, wiec w praktyce
    # jest poprawna; sprawdzamy ja mimo to, bo "w praktyce" nie jest gwarancja.
    if (-not (Test-JezykNazwaKonta $Netbios)) {
        $wynik.Komunikat = 'Nie mam nazwy maszyny, z którą można się połączyć.'
        $wynik.Szczegoly = 'Wartość "{0}" nie wygląda na nazwę komputera, więc nie została nikomu podana.' -f $Netbios
        return $wynik
    }

    # SCIEZKA SPRAWDZANA TAKZE TUTAJ, nie tylko przy sterowaniu przyciskiem. Ta sama zasada,
    # co przy uprawnieniu do odblokowania: stan interfejsu da sie rozspojnic, a funkcja
    # wykonujaca operacje ma bronic sie sama.
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
        # -ArgumentList TABLICA, nie sklejony napis: kazdy element idzie osobnym argumentem
        # i nie ma miejsca, w ktorym spacja albo cudzyslow zmienialyby podzial.
        Start-Process -FilePath $Sciezka -ArgumentList @($Netbios) -ErrorAction Stop
        $wynik.Udane     = $true
        $wynik.Komunikat = 'Uruchomiono zdalną konsolę dla maszyny {0}.' -f $Netbios
    }
    catch {
        # Tu laduje brakujacy plik, odmowa uruchomienia i martwy udzial sieciowy. Rozroznia
        # je tresc wyjatku, ktora zostaje w calosci - skracanie zabieraloby dokladnie te
        # informacje, po ktora sie do komunikatu siega.
        $opis = Get-JezykOpisBledu $_ ('Uruchomienie zdalnej konsoli dla {0}' -f $Netbios)
        $wynik.Komunikat = $opis.Krotki
        $wynik.Szczegoly = '{0}{1}Ścieżka z konfiguracji: {2}' -f
                           $opis.Szczegoly, ([Environment]::NewLine + [Environment]::NewLine), $Sciezka
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
        #
        # Owner NIE JEST polem .NET: ActiveDirectorySecurity ma wylacznie metode GetOwner(),
        # a wlasnosc Owner dokleja PowerShell - i to ona tlumaczy SID na nazwe. Tlumaczenie
        # nie zawsze wychodzi: konto skasowane, z drugiego lasu albo zza relacji zaufania,
        # ktora akurat nie odpowiada. Brak prawa do samego atrybutu wyglada inaczej (atrybut
        # nie przychodzi wcale), ale konczy sie tym samym - pustym wlascicielem, czyli
        # "nie wiadomo", stanem, ktory wynik i tak juz opisuje.
        #
        # OSLONA JEST UBEZPIECZENIEM, a nie reakcja na znany blad. Pod pwsh 7 sprawdzone:
        # bledu wlasnosci doklejanej przez siebie PowerShell nie wypuszcza - odklada go
        # do $Error i oddaje $null, wiec catch nie ma tu czego lapac. Produkt chodzi jednak
        # WYLACZNIE na Windows PowerShell 5.1, ktorego z maszyny deweloperskiej sprawdzic
        # sie nie da - a gdyby 5.1 jednak wyjatek wypuscil, polecialby przez CALE
        # wyszukiwanie komputera i zamienil poprawny wynik w blad. Dlatego oslona obejmuje
        # DOKLADNIE JEDNO wyrazenie: nie ma w niej kodu, ktorego usterke moglaby zagluszyc.
        $wlasciciel = ''
        try   { $wlasciciel = [string]$komputer.nTSecurityDescriptor.Owner }
        catch { $wlasciciel = '' }

        $podpis = Get-JezykPodpisWlasciciela -Wlasciciel $wlasciciel -Serwer $Script:Config.Domena

        # Konto komputera wylaczone w AD to dokladnie to, co "Centrum administracyjne Active
        # Directory" pokazuje wyszarzonym monitorkiem z kropka i slowem "Wyłączone". Nazwa
        # obiektu sie przy tym NIE zmienia, wiec z samego wyszukiwania tego nie widac -
        # a maszyna z wylaczonym kontem nie zaloguje sie do domeny.
        # Enabled jest wlasnoscia domyslna Get-ADComputer, wiec nie trzeba jej zamawiac
        # w -Properties. Wartosc logiczna zostaje SUROWA, tak jak Enabled przy koncie -
        # $null (atrybut nie przyszedl) to "nie wiadomo", a nie "wylaczone".
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
