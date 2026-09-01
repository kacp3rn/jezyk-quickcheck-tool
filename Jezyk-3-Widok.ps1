# Jezyk-3-Widok - przelozenie wyniku na kontrolki okna. Zero zapytan do sieci.
# TA LINIA MUSI POZOSTAC ZWYKLYM KOMENTARZEM - oslania pierwsza instrukcje przed
# zdublowanym znacznikiem BOM. Powod opisany w Kod-Jezyk.ps1.

# Wlasny trap w kazdej czesci: trap wznawia prace w zakresie, w ktorym go zdefiniowano.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 3 - RENDEROWANIE WYNIKU
# Renderer nie wie, skad wzial sie wynik ani ktory tryb go wywolal - dostaje obiekt
# i wypelnia kontrolki. Dzieki temu wyszukiwanie po loginie i wybor konta z listy
# prowadza do dokladnie tego samego kodu wyswietlajacego.

# Data razem z dopiskiem, jak dawno temu albo za ile to nastapi: "2026-05-14 08:12
# (98 dni temu)". Dopisek nie jest ozdobnikiem - "za 3 dni" od razu mowi, ze trzeba
# dzialac teraz, czego sama data nie pokazuje.
# GdyBrak: przy dacie waznosci konta brak wartosci znaczy "nigdy", a nie "nie wiem".
function Format-JezykData {
    param($Data, [string]$GdyBrak = 'brak danych')

    if ($null -eq $Data) { return $GdyBrak }

    # Zaokraglamy do pelnych dni - godziny w dopisku niczego nie wnosza, a sama data jest obok.
    $dni = [int][math]::Round(((Get-Date) - $Data).TotalDays)

    if     ($dni -gt 0) { $wzglednie = '{0} dni temu' -f $dni }
    elseif ($dni -lt 0) { $wzglednie = 'za {0} dni'   -f [math]::Abs($dni) }
    else                { $wzglednie = 'dzisiaj' }

    '{0:yyyy-MM-dd HH:mm} ({1})' -f $Data, $wzglednie
}

<#
.SYNOPSIS
    Tresc pola "Ostatnie logowanie" - jedna funkcja dla wszystkich czterech stanow.

.DESCRIPTION
    Pole wypelnia sie dwuetapowo, a ta funkcja opisuje oba etapy naraz, zeby nie dalo sie
    ich rozjechac przy pozniejszej zmianie tekstu. Nieudane uscislenie NIE kasuje wartosci
    przyblizonej - data przeterminowana o kilka dni jest lepsza niz komunikat o porazce.
#>
function Get-JezykTekstLogowania {
    param($Dokladna, $Przyblizona, [switch]$Trwa)

    if ($null -ne $Dokladna) {
        if ($null -ne $Przyblizona) {
            return 'Dokładna data: {0} · poprzednia data: {1:yyyy-MM-dd HH:mm}' -f (Format-JezykData $Dokladna), $Przyblizona
        }
        return 'Dokładna data: {0}' -f (Format-JezykData $Dokladna)
    }

    if ($null -ne $Przyblizona) {
        if ($Trwa) { return 'Data przybliżona: {0} precyzowanie...' -f (Format-JezykData $Przyblizona) }
        return 'Data przybliżona: {0}' -f (Format-JezykData $Przyblizona)
    }

    if ($Trwa) { return 'sprawdzanie...' }
    return 'brak danych'
}

# Czysci widok konta do stanu "nic nie wiadomo". Wolane na poczatku kazdego renderowania
# i przy zmianie trybu: pol jest kilkanascie i latwo przeoczyc, ze ktores nie zostalo
# nadpisane, a zielony napis po nieudanym zapytaniu bylby najgorszym z nieporozumien.
function Clear-JezykKonto {
    $k = $Script:Kontrolki

    $k.WerdyktBox.Checked   = $false
    $k.Werdykt.Text         = 'Konto zablokowane'
    $k.Werdykt.ForeColor    = $Script:Config.KolorNieznany

    $k.ChkAktywne.Checked     = $false
    $k.ChkZablokowane.Checked = $false
    $k.ChkFlagaHasla.Checked  = $false

    foreach ($pole in @($k.TxtLoginKonta, $k.TxtImieNazwisko, $k.TxtEmail,
                        $k.TxtHasloWygasa, $k.TxtKontoWygasa, $k.TxtOstatniaZmiana,
                        $k.TxtKontoUtworzono, $k.TxtTelefon, $k.TxtMenedzer,
                        $k.TxtOstatnieLogowanie, $k.TxtKomputerUzytkownika,
                        $k.TxtKomputerIp, $k.TxtKatalog, $k.TxtStatus)) {
        if ($pole) { $pole.Text = '' }
    }

    # Etykieta pierwszego pola wraca do stanu domyslnego. Widok kontaktu przestawia ja na
    # "Nazwa:" - bez tego zostalaby tak przy nastepnym wyszukaniu KONTA i opisywalaby login
    # slowem "Nazwa".
    if ($k.EtykietaLoginKonta) { $k.EtykietaLoginKonta.Text = 'Login:' }

    # Data przyblizona nalezy do KONKRETNEGO konta - zostawiona wpisalaby sie do pola
    # opisujacego juz kogos innego.
    $Script:LogowaniePrzyblizone = $null
    $Script:OstatnieKonto        = $null

    # Nazwa maszyny nalezy do KONKRETNEGO konta - zostawiona kazalaby przyciskowi "Pinguj"
    # sprawdzac komputer kogos, kogo juz nie ma na ekranie.
    $Script:OstatniKomputer = ''
    if ($k.PrzyciskPinguj) { $k.PrzyciskPinguj.Enabled = $false }

    Set-JezykInfo 'Komputer' ''
    Set-JezykInfo 'Status'   ''

    # ZADANIA W TLE GASNA RAZEM Z WIDOKIEM. Bez tego zadanie z poprzedniego wyszukania
    # bieglo dalej po wejsciu na sciezke "nie znaleziono", "zbyt wiele trafien" i "blad"
    # oraz po zmianie trybu i domeny - a te sciezki nie podbijaja licznika pokolen, wiec
    # spozniony wynik SCCM sprzed dwoch wyszukan wpisywal sie do pola opisujacego JUZ
    # KOGOS INNEGO. Drugi, dotkliwszy skutek: kolejne wyszukanie musialo przerwac zywe
    # zadanie tkwiace w wywolaniu DCOM, a takie przerwanie potrafi zamrozic okno.
    Stop-JezykZadanieLogowania
    Stop-JezykZadanieKomputera
    Stop-JezykZadaniePingu

    # Przycisk gasnie razem z widokiem: zostawiony czynny odblokowywalby konto, ktorego
    # juz nie widac na ekranie.
    Set-JezykPrzyciskOdblokuj $null

    # PRZYWROCENIE KOLORU JEST WARUNKIEM POPRAWNOSCI, NIE KOSMETYKA - i dotyczy teraz
    # DWOCH pol. "Haslo wygasa" bywa czerwone, a "Ostatnio uzywany komputer" czerwony albo
    # zielony; bez zerowania pierwsza taka wartosc zabarwialaby pole na stale i KAZDE
    # nastepne konto wygladaloby tak samo, niezaleznie od tego, co o nim wiadomo.
    $k.TxtHasloWygasa.ForeColor = [System.Drawing.SystemColors]::WindowText
    $k.TxtKomputerUzytkownika.ForeColor = [System.Drawing.SystemColors]::WindowText
}

<#
.SYNOPSIS
    Wypelnia widok konta danymi z obiektu wyniku.

.DESCRIPTION
    Werdykt: zaznaczony i czerwony = z kontem jest problem, a napis mowi jaki. Siatka
    znacznikow pod spodem pokazuje surowe fakty, z ktorych werdykt powstal - powielenie
    pozycji "Konto zablokowane" w obu miejscach jest swiadome: napis podaje wniosek,
    siatka dane zrodlowe.
#>
function Set-JezykResult {
    param($Result)

    $k = $Script:Kontrolki
    Clear-JezykKonto
    $Script:OstatnieKonto = $Result

    switch ($Result.Status) {

        'Ok' {
            # Dwa niezalezne stany konta. Objaw dla uzytkownika jest ten sam ("nie moge sie
            # zalogowac"), ale naprawa inna: blokade zdejmuje Unlock-ADAccount i mija ona
            # tez sama po czasie, wylaczenie zdejmuje Enable-ADAccount.
            $zablokowane = [bool]$Result.LockedOut
            $wylaczone   = -not [bool]$Result.Enabled
            $problem     = ($zablokowane -or $wylaczone)

            if     ($zablokowane -and $wylaczone) { $napis = 'Konto zablokowane i wyłączone' }
            elseif ($zablokowane)                 { $napis = 'Konto zablokowane' }
            elseif ($wylaczone)                   { $napis = 'Konto wyłączone' }
            else                                  { $napis = 'Konto aktywne' }

            $k.WerdyktBox.Checked = $problem
            $k.Werdykt.Text       = $napis
            if ($problem) { $k.Werdykt.ForeColor = $Script:Config.KolorProblem }
            else          { $k.Werdykt.ForeColor = $Script:Config.KolorOk }

            $k.ChkAktywne.Checked     = (-not $wylaczone)
            $k.ChkZablokowane.Checked = $zablokowane
            $k.ChkFlagaHasla.Checked  = [bool]$Result.ZmianaHaslaWymuszona

            $k.TxtLoginKonta.Text   = [string]$Result.Login
            $k.TxtImieNazwisko.Text = Get-JezykOsoba ([string]$Result.DisplayName) `
                                                     ([string]$Result.Imie) ([string]$Result.Nazwisko)

            # Brak adresu zostawia pole PUSTE: napis "brak danych" sugerowalby nieudany
            # odczyt, a tu chodzi o konto, ktore po prostu nie ma skrzynki.
            $k.TxtEmail.Text = [string]$Result.Email

            # NUMER MOWI O SWOIM BRAKU WPROST, tak samo jak przelozony nizej. Pustka nigdy
            # nie znaczy tu porazki odczytu: wybor numeru (stacjonarny czy komorka) zapada
            # w logice, ktora pyta katalog, wiec puste pole ma dokladnie jedno znaczenie -
            # w AD nie ma zadnego numeru. Skoro znaczenie jest jedno i pewne, ma byc
            # NAPISANE, a nie zgadywane z pustki.
            #
            # E-mail zostaje przy pustce swiadomie: konto bez skrzynki to stan normalny
            # i czesty, a napis przy kazdym takim koncie bylby samym halasem.
            $k.TxtTelefon.Text  = if ($Result.Telefon) { [string]$Result.Telefon } else { 'nie wpisano w AD' }

            # PRZELOZONY MOWI O SWOIM BRAKU WPROST. Pusty napis czytalo sie jak nieudany
            # odczyt, a tutaj pustka NIGDY nie znaczy porazki: nieudane rozwiazanie nazwy
            # wyrozniajacej spada w Get-JezykPodpisMenedzera do CN z DN, wiec puste pole
            # ma dokladnie jedno znaczenie - w atrybucie Manager nikogo nie ma. Skoro
            # znaczenie jest jedno i pewne, ma byc napisane, a nie zgadywane z pustki.
            $k.TxtMenedzer.Text = if ($Result.Menedzer) { [string]$Result.Menedzer } else { 'nie wpisano w AD' }

            # Trzy stany hasla, kazdy znaczy co innego dla osoby przy telefonie.
            if     ($Result.ZmianaHaslaWymuszona) { $k.TxtHasloWygasa.Text = 'nie dotyczy (zmiana wymagana)' }
            elseif ($Result.HasloNigdyNieWygasa)  { $k.TxtHasloWygasa.Text = 'nigdy' }
            else                                  { $k.TxtHasloWygasa.Text = Format-JezykData $Result.HasloWygasa }

            # Barwimy wylacznie wtedy, gdy termin FAKTYCZNIE minal. Przy wymuszonej zmianie
            # pole zawiera tekst, a nie date, wiec czerwony termin nie mialby czego dotyczyc.
            if ($Result.HasloWygasa -and $Result.HasloWygasa -lt (Get-Date)) {
                $k.TxtHasloWygasa.ForeColor = $Script:Config.KolorProblem
            }

            $k.TxtKontoWygasa.Text    = Format-JezykData $Result.KontoWygasa 'nigdy'
            $k.TxtOstatniaZmiana.Text = Format-JezykData $Result.OstatniaZmianaHasla 'nigdy nie ustawiono'
            $k.TxtKontoUtworzono.Text = Format-JezykData $Result.KontoUtworzono

            # Dwa wolne pola, dwa NIEZALEZNE zadania w tle. Data nie czeka nawet na wlasne
            # zadanie: wartosc przyblizona przyszla razem z reszta konta, wiec pokazujemy ja
            # od razu, a tlo tylko ja uscisli. Komputer czekac musi - AD nie wie o nim nic.
            $Script:LogowaniePrzyblizone   = $Result.OstatnieLogowaniePrzyblizone
            $k.TxtOstatnieLogowanie.Text   = Get-JezykTekstLogowania -Przyblizona $Script:LogowaniePrzyblizone -Trwa
            $k.TxtKomputerUzytkownika.Text = 'sprawdzanie...'
            if ($k.TxtKomputerIp) { $k.TxtKomputerIp.Text = 'sprawdzanie...' }
            Set-JezykInfo 'Komputer' ''
            Start-JezykZadanieLogowania -Login ([string]$Result.Login) -Dn ([string]$Result.Dn)
            Start-JezykZadanieKomputera -Login ([string]$Result.Login)

            $k.TxtKatalog.Text = [string]$Result.Lokalizacja

            # Moment zalozenia blokady dopisujemy do statusu WYLACZNIE przy aktywnej
            # blokadzie: AD nie zeruje LockoutTime po samoczynnym wygasnieciu, wiec poza
            # tym przypadkiem data wprowadzalaby w blad.
            $status = [string]$Result.Message
            if ($zablokowane -and $Result.LockoutTime) {
                $status = '{0} Blokada od {1:yyyy-MM-dd HH:mm}.' -f $status, $Result.LockoutTime
            }
            $k.TxtStatus.Text = $status.Trim()
        }

        'Kontakt' {
            # Kontakt nie ma stanu konta, wiec werdykt nie ma o czym orzekac - mowi wprost,
            # z jakim rodzajem pozycji ma sie do czynienia. Kolor nieznany, bo tu nie ma
            # ani problemu, ani jego braku.
            $k.WerdyktBox.Checked = $false
            $k.Werdykt.Text       = 'Pozycja typu Kontakt - to nie jest konto'
            $k.Werdykt.ForeColor  = $Script:Config.KolorNieznany

            $k.TxtImieNazwisko.Text = Get-JezykOsoba ([string]$Result.DisplayName) `
                                                     ([string]$Result.Imie) ([string]$Result.Nazwisko)
            $k.TxtEmail.Text          = [string]$Result.Email
            # Kontakt to wpis ksiazki adresowej, wiec numer jest tu najbardziej na miejscu -
            # i tym bardziej jego brak zasluguje na slowo zamiast pustki.
            $k.TxtTelefon.Text        = if ($Result.Telefon) { [string]$Result.Telefon } else { 'nie wpisano w AD' }
            $k.TxtKontoUtworzono.Text = Format-JezykData $Result.KontoUtworzono
            $k.TxtKatalog.Text        = [string]$Result.Lokalizacja
            $k.TxtStatus.Text         = [string]$Result.Message

            # PIERWSZE POLE ZMIENIA ZNACZENIE: kontakt nie ma loginu, ma za to nazwe
            # obiektu w AD (atrybut Name, czyli cn). Etykieta idzie za trescia, zeby pole
            # nie opisywalo czegos, czego w nim nie ma. Clear-JezykKonto przywraca "Login:".
            if ($k.EtykietaLoginKonta) { $k.EtykietaLoginKonta.Text = 'Nazwa:' }
            $k.TxtLoginKonta.Text = [string]$Result.NazwaObiektu

            # "Nie dotyczy", a nie pusto. Puste pole wyglada jak nieudany odczyt, a tych
            # wartosci nie ma z czego wziac: kontakt po prostu ich nie posiada.
            # Menedzer jest w tej liscie, bo kontakt nie ma przelozonego w strukturze
            # firmy; telefon NIE JEST - kontakt numer miec moze i wlasnie po to istnieje.
            foreach ($pole in @($k.TxtHasloWygasa, $k.TxtKontoWygasa,
                                $k.TxtOstatniaZmiana, $k.TxtMenedzer,
                                $k.TxtOstatnieLogowanie, $k.TxtKomputerUzytkownika,
                                $k.TxtKomputerIp)) {
                if ($pole) { $pole.Text = 'nie dotyczy (kontakt)' }
            }

            # ZADNYCH ZADAN W TLE. Kontakt nigdy sie nie loguje i nie ma go w inwentaryzacji
            # SCCM, wiec obejscie kontrolerow i zapytanie do SCCM pytalyby o nieistniejace
            # konto - i tak wlasnie wygladalaby ich odpowiedz.
        }

        'NotFound' { $k.Werdykt.Text = 'Nie znaleziono konta'; $k.TxtStatus.Text = [string]$Result.Message }

        'Empty'    { $k.Werdykt.Text = 'Nie sprawdzono';       $k.TxtStatus.Text = [string]$Result.Message }

        # Galaz domyslna to Status = 'Error'; sam powod trafia do statusu.
        default    { $k.Werdykt.Text = 'Błąd sprawdzenia';     $k.TxtStatus.Text = [string]$Result.Message }
    }

    # Pelna tresc idzie pod przycisk "!" przy polu Status, nie na ekran - w polu jest na
    # nia za malo miejsca. ALE TYLKO PRZY STANIE PROBLEMOWYM: znalezione konto ('Ok')
    # i znaleziony kontakt ('Kontakt') to sukcesy, a wykrzyknik ma znaczyc wylacznie
    # "cos nie dziala". Kontakt zapalal go dotad zawsze, bo jego odczyt wypelnial Szczegoly
    # takze po udanym znalezieniu.
    $problem = ($Result.Status -notin 'Ok', 'Kontakt', 'Empty')
    Set-JezykInfo 'Status' $(if ($problem) { [string]$Result.Szczegoly } else { '' })

    # POZA switch-em, zeby przeliczyc przycisk przy KAZDYM stanie - takze wtedy, gdy konta
    # nie znaleziono.
    Set-JezykPrzyciskOdblokuj $Result
}

# Czysci widok komputera do stanu "nic nie wiadomo" - odpowiednik Clear-JezykKonto po
# drugiej stronie okna. Gasi takze zadanie w tle: bez tego spozniona odpowiedz SCCM sprzed
# dwoch wyszukan wpisalaby sie do pola opisujacego JUZ INNA maszyne.
function Clear-JezykKomputer {
    $k = $Script:Kontrolki

    Stop-JezykZadanieUzytkownika

    foreach ($pole in @($k.TxtKomputerKatalog, $k.TxtKomputerUzytkownikMaszyny, $k.TxtKomputerStatus)) {
        if ($pole) { $pole.Text = '' }
    }

    Set-JezykInfo 'Uzytkownik' ''
}

# Widok komputera odpowiada na dwa pytania: gdzie w drzewie AD lezy ten komputer i kto
# ostatnio z niego korzystal. Pierwsze wie AD i jest w wyniku od razu; drugie wie wylacznie
# SCCM, wiec idzie w tlo - tak samo jak droga odwrotna w widoku konta.
function Set-JezykComputerResult {
    param($Result)

    $k = $Script:Kontrolki
    Clear-JezykKomputer

    if ($Result.Status -eq 'Ok') {
        $k.TxtKomputerKatalog.Text = [string]$Result.Lokalizacja

        # Nazwa Z AD, a nie z pola tekstowego: idzie do zapytania WQL, a AD zna ja
        # w oryginalnej pisowni.
        if ($k.TxtKomputerUzytkownikMaszyny) { $k.TxtKomputerUzytkownikMaszyny.Text = 'sprawdzanie...' }
        Start-JezykZadanieUzytkownika -Netbios ([string]$Result.Nazwa)
    }

    $k.TxtKomputerStatus.Text = [string]$Result.Message
}

# Lista przechowuje CALE obiekty kandydatow, a nie same napisy - dzieki DisplayMember
# pokazuje opis, a kod ma pod reka login potrzebny do pelnego odczytu.
# Blokada zdarzen jest konieczna: kazde dodanie pozycji wywoluje SelectedIndexChanged,
# wiec bez niej jedno wyszukanie odpalaloby kilka pelnych zapytan do AD.
function Set-JezykListaKont {
    param($Konta)

    $lista = $Script:Kontrolki.ListaKont
    $Script:BlokadaZdarzen = $true
    try {
        $lista.Items.Clear()
        foreach ($konto in $Konta) { [void]$lista.Items.Add($konto) }
    }
    finally { $Script:BlokadaZdarzen = $false }
}

# Wybor pozycji z listy: komplet atrybutow czytamy dopiero tutaj, dla jednej pozycji.
# Rozgalezienie po TYPIE, bo kontakt nie ma loginu - jego jedyna tozsamoscia jest nazwa
# wyrozniajaca i czyta go inne polecenie.
function Invoke-JezykWyborKonta {
    if ($Script:BlokadaZdarzen) { return }

    $wybrane = $Script:Kontrolki.ListaKont.SelectedItem
    if ($null -eq $wybrane) { return }

    if ([string]$wybrane.Typ -eq 'Kontakt') {
        Set-JezykResult -Result (Get-JezykKontaktStatus -Dn ([string]$wybrane.Dn))
        return
    }

    Set-JezykResult -Result (Get-JezykUserStatus -Login ([string]$wybrane.Login))
}

<#
.SYNOPSIS
    Obsluga "Szukaj" - jedyne miejsce, w ktorym tryb przeklada sie na funkcje logiki.

.DESCRIPTION
    Zapytanie jest synchroniczne, wiec okno na moment przestaje reagowac; bez wylaczenia
    przycisku niecierpliwe podwojne klikniecie ustawialoby w kolejce drugie zapytanie.
    Blok finally jest niezbedny - gdyby renderowanie przerwalo sie w polowie, przycisk
    zostalby wylaczony na stale.
#>
function Invoke-JezykSearch {
    $k    = $Script:Kontrolki
    $okno = $k.Okno
    $tryb = [string]$k.Tryb.SelectedItem
    $tekst = $k.PoleSzukaj.Text

    $k.Przycisk.Enabled = $false
    $okno.UseWaitCursor = $true
    # Wymuszenie przerysowania - inaczej zmiana kursora pojawilaby sie dopiero po
    # zakonczeniu zapytania, czyli gdy nie jest juz potrzebna.
    $okno.Refresh()

    try {
        if ($tryb -eq $Script:Config.TrybKomputer) {
            Set-JezykComputerResult -Result (Get-JezykComputerStatus -Netbios $tekst)
        }
        else {
            $lista = Find-JezykUsers -Fragment $tekst
            Set-JezykListaKont -Konta $lista.Konta

            if ($lista.Status -eq 'Ok') {
                # Przypisanie zaznaczenia odpala Invoke-JezykWyborKonta, ktore wykona pelny
                # odczyt - dzieki temu pierwsza pozycja pokazuje sie bez dodatkowego klikniecia.
                $Script:Kontrolki.ListaKont.SelectedIndex = 0

                # NOTKA O PRZERWANYM WYSZUKIWANIU PO NUMERZE IDZIE PO ZAZNACZENIU, nie przed.
                # Zaznaczenie uruchamia Set-JezykResult, a ten nadpisuje pole Status opisem
                # konta i gasi przycisk "!" - wpisana wczesniej notka ginelaby bez sladu,
                # dokladnie tak jak kiedys ginelo potwierdzenie odblokowania.
                #
                # Lista jest tu NIEPELNA i operator musi o tym wiedziec: ktos, kogo szukal,
                # mogl nie zdazyc sie na niej znalezc. Ta sama technika, co przy zanizonej
                # dacie logowania - doklejamy zdanie do pola Status, a powod pod "!".
                if ($lista.PrzerwanoNumer) {
                    $k.TxtStatus.Text = ('{0} UWAGA: przeszukanie numerów telefonu przerwał limit czasu - lista może być niepełna.' -f
                                         $k.TxtStatus.Text).Trim()
                    Set-JezykInfo 'Status' ([string]$lista.Szczegoly)
                }
            }
            else {
                # Brak trafien, zbyt wiele trafien albo blad. Status 'Ok' nigdy tu nie trafi.
                Clear-JezykKonto
                $k.Werdykt.Text   = if ($lista.Status -eq 'NotFound') { 'Nie znaleziono konta' }
                                    elseif ($lista.Status -eq 'Empty') { 'Nie sprawdzono' }
                                    else { 'Błąd sprawdzenia' }
                $k.TxtStatus.Text = [string]$lista.Message
                Set-JezykInfo 'Status' ([string]$lista.Szczegoly)
            }
        }
    }
    finally {
        $okno.UseWaitCursor = $false
        $k.Przycisk.Enabled = $true
    }
}

<#
.SYNOPSIS
    Dostepnosc przycisku "Odblokuj konto": domena dozwolona, konto znalezione i FAKTYCZNIE
    zablokowane.

.DESCRIPTION
    Przycisk jest widoczny zawsze, a nie chowany - znikajaca kontrolka jest gorsza niz
    wyszarzona, bo nie da sie przewidziec, czy w ogole istnieje.

    BEZ ZADNEGO WYKRZYKNIKA. Zadna z czterech przyczyn wylaczenia nie jest bledem: domena
    tylko do odczytu, kontakt zamiast konta, brak wyszukanego konta i konto niezablokowane
    to wszystko NORMALNE, SPODZIEWANE stany. Wykrzyknik przy takim stanie zapalal sie
    zaraz po starcie okna i przestawal cokolwiek znaczyc - a ma znaczyc dokladnie jedno:
    "cos nie dziala". Samo wyszarzenie przycisku wystarczy za komunikat "jest, ale nie teraz".
#>
function Set-JezykPrzyciskOdblokuj {
    param($Result)

    $przycisk = $Script:Kontrolki.PrzyciskOdblokuj
    if (-not $przycisk) { return }

    $domena = $Script:Config.Domena

    $przycisk.Enabled = (
        (Test-JezykWolnoOdblokowac $domena) -and
        $Result -and $Result.Status -eq 'Ok' -and [bool]$Result.LockedOut
    )
}

<#
.SYNOPSIS
    Obsluga klikniecia w "Odblokuj konto".

.DESCRIPTION
    Okno logowania jest zarazem POTWIERDZENIEM: wpisanie loginu i hasla jest mocniejsze niz
    klikniecie "tak". Prawo zapisu w katalogu bywa przypisane innemu kontu niz to, na ktorym
    pracuje administrator - stad pytanie o poswiadczenia zamiast ustawien.

    Poswiadczenia trafiaja wylacznie do jednego wywolania i gina razem z nim: nie ma zmiennej
    skryptowej, ktora by je przezyla, nie ma zapisu do pliku ani do zadania w tle.
#>
function Invoke-JezykOdblokowanie {
    $k      = $Script:Kontrolki
    $domena = $Script:Config.Domena

    # LOGIN Z OBIEKTU WYNIKU, NIE Z KONTROLKI. Kontrolka sluzy do pokazywania, a nie do
    # przenoszenia stanu - zrodlem prawdy dla operacji zapisu jest ostatni odczyt z AD.
    if (-not $Script:OstatnieKonto -or $Script:OstatnieKonto.Status -ne 'Ok') { return }
    $login = [string]$Script:OstatnieKonto.Login
    if (-not $login) { return }

    $poswiadczenia = $null
    try {
        try {
            $poswiadczenia = Get-Credential -Message (
                'Konto z prawem odblokowywania w domenie {0}. Zostanie odblokowane konto {1}.' -f $domena, $login)
        }
        catch {
            $opis = Get-JezykOpisBledu $_ 'Okno logowania'
            $k.TxtStatus.Text = $opis.Krotki
            Set-JezykInfo 'Status' $opis.Szczegoly
            return
        }

        # Anulowanie okna logowania: zadnego zapisu, zadnego bledu.
        if (-not $poswiadczenia) { return }

        $wynik = Unlock-JezykKonto -Login $login -Domena $domena -Poswiadczenia $poswiadczenia

        # Niepowodzenie konczy sie tutaj: nie ma czego odswiezac, a powod odmowy jest
        # jedyna rzecza, ktora ma zostac na ekranie.
        if (-not $wynik.Udane) {
            $k.TxtStatus.Text = $wynik.Komunikat
            Set-JezykInfo 'Status' ([string]$wynik.Szczegoly)
            return
        }

        # ODSWIEZENIE IDZIE PRZED KOMUNIKATEM, a nie po nim. Odswiezenie zaczyna sie od
        # Clear-JezykKonto, ktore czysci pole Status - komunikat wpisany wczesniej ginal
        # w nim bez sladu i nikt nigdy nie widzial potwierdzenia.
        #
        # Odczyt idzie z kontrolera, KTORY PRZYJAL ZAPIS. Stan blokady replikuje sie
        # pilnie, ale nie natychmiast, wiec odczyt z przypadkowego kontrolera potrafil
        # oddac stan sprzed odblokowania i pokazac "Konto zablokowane" sekunde po udanej
        # operacji. Sam odczyt idzie na koncie Jezyka; podane poswiadczenia sluzyly
        # wylacznie do zapisu.
        $poZapisie = Get-JezykUserStatus -Login $login -Serwer ([string]$wynik.Serwer)
        Set-JezykResult -Result $poZapisie

        $status     = [string]$wynik.Komunikat
        $tresc      = @([string]$wynik.Komunikat)
        $ikona      = [System.Windows.Forms.MessageBoxIcon]::Information
        # Domyslnie PUSTE - odblokowanie sie udalo, wiec przycisk "!" nie ma czego
        # sygnalizowac. Dwie ponizsze galezie to jedyne miejsca, w ktorych cos NIE dziala
        # tak jak powinno, i tylko wtedy dostaje tresc.
        $infoStatus = ''

        if ($poZapisie.Status -ne 'Ok') {
            # Zapis sie udal, odczyt po nim nie - jego powod jest wazniejszy niz
            # potwierdzenie i nie wolno go zgubic.
            $status = '{0} Ponowny odczyt konta: {1}' -f $status, $poZapisie.Message
            $tresc += @('', ('Zapis się powiódł, ale ponowny odczyt konta zawiódł: {0}' -f $poZapisie.Message))
            $ikona  = [System.Windows.Forms.MessageBoxIcon]::Warning
            $infoStatus = [string]$wynik.Szczegoly
        }
        elseif ($poZapisie.LockedOut) {
            # Odczyt z kontrolera, ktory przyjal zapis, a konto nadal zablokowane - to nie
            # jest opoznienie replikacji, tylko blokada zalozona od nowa. Zwykle usluga
            # albo zadanie logujace sie na stare haslo.
            $status = '{0} UWAGA: konto jest zablokowane PONOWNIE - coś loguje się na nieaktualne hasło.' -f $status
            $tresc += @('', 'UWAGA: konto jest już zablokowane PONOWNIE.',
                        'Kontroler, który przyjął zapis, nadal widzi blokadę - to nie jest opóźnienie replikacji. Zwykle znaczy to, że jakaś usługa, zadanie albo urządzenie loguje się na nieaktualne hasło.')
            $ikona  = [System.Windows.Forms.MessageBoxIcon]::Warning
            $infoStatus = [string]$wynik.Szczegoly
        }
        else {
            $tresc += @('', ('Widok odświeżony odczytem z kontrolera {0}.' -f $wynik.Serwer))
        }

        $k.TxtStatus.Text = $status
        Set-JezykInfo 'Status' $infoStatus

        # Okno na SAMYM KONCU: pod nim jest juz odswiezony widok, wiec po zamknieciu
        # komunikatu widac stan PO operacji, a nie przed nia.
        [void][System.Windows.Forms.MessageBox]::Show(
            ($tresc -join [Environment]::NewLine),
            $Script:Config.TytulOkna,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            $ikona)
    }
    finally {
        # Haslo NISZCZYMY, a nie tylko zapominamy referencje: samo przypisanie $null
        # zostawialoby je w pamieci do czasu odsmiecania, a okno bywa otwarte godzinami.
        if ($poswiadczenia) {
            try { $poswiadczenia.Password.Dispose() } catch { }
        }
        $poswiadczenia = $null
    }
}

# Zamyka pole daty po nieudanym uscisleniu: data przyblizona ZOSTAJE, znika tylko dopisek
# "precyzowanie...", bo nic sie juz nie precyzuje.
function Set-JezykPoleLogowaniaBezTla {
    $k = $Script:Kontrolki
    if (-not $k.TxtOstatnieLogowanie) { return }
    $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Przyblizona $Script:LogowaniePrzyblizone
}

# Zamyka pole komputera po nieudanym zapytaniu do SCCM. Dostepnosc gasnie razem z nim:
# bez nazwy maszyny nie ma czego pingowac, a zostawiony kolor opisywalby poprzednia.
function Set-JezykPoleKomputeraBezTla {
    param([string]$Blad)
    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownika) { return }
    $k.TxtKomputerUzytkownika.Text = 'nie sprawdzono'
    Set-JezykDostepnoscKomputera -Odpowiada $null -Adres ''
    Set-JezykInfo 'Komputer' $Blad
}

<#
.SYNOPSIS
    Maluje pole komputera wedlug dostepnosci maszyny i wpisuje jej adres IP.

.DESCRIPTION
    JEDNO MIEJSCE, W KTORYM ZAPADA DECYZJA O KOLORZE - wolaja je i sonda automatyczna
    po wyszukaniu, i przycisk "Pinguj", i sciezki bledu. Dwie kopie tej decyzji rozjechalyby
    sie przy pierwszej zmianie i pole potrafiloby zostac zielone po nieudanej probie.

    TRZY STANY, BO TYLE ICH JEST:
      $true  - zielony, maszyna odpowiedziala,
      $false - czerwony, maszyna milczy,
      $null  - kolor NEUTRALNY: nie sprawdzono albo nie wiadomo. Zielony i czerwony maja
               znaczyc fakt; pomalowanie niewiedzy ktorymkolwiek z nich bylo by klamstwem.

    Adres IP zostaje wpisany takze wtedy, gdy maszyna nie odpowiada - DNS ja zna, a to
    osobny fakt od tego, czy jest wlaczona, i wlasnie ten adres jest potrzebny do
    polaczenia zdalnego.
#>
function Set-JezykDostepnoscKomputera {
    param($Odpowiada, [string]$Adres, [string]$Opis = '')

    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownika) { return }

    $k.TxtKomputerUzytkownika.ForeColor = if ($null -eq $Odpowiada) { [System.Drawing.SystemColors]::WindowText }
                                          elseif ($Odpowiada)       { $Script:Config.KolorOk }
                                          else                      { $Script:Config.KolorProblem }

    if (-not $k.TxtKomputerIp) { return }

    $k.TxtKomputerIp.Text = if ($Adres) { $Adres }
                            elseif ($Opis) { $Opis }
                            else { 'nie sprawdzono' }
}

# Obsluga przycisku "Pinguj": sprawdza JESZCZE RAZ maszyne, ktora jest juz na ekranie.
# Nazwa idzie z $Script:OstatniKomputer, a nie z pola tekstowego - pole sluzy do
# pokazywania i niesie takze date, wiec nie jest zrodlem prawdy.
function Invoke-JezykPing {
    $k = $Script:Kontrolki
    if (-not $Script:OstatniKomputer) { return }

    if ($k.TxtKomputerIp) { $k.TxtKomputerIp.Text = 'sprawdzanie...' }
    if ($k.TxtKomputerUzytkownika) {
        $k.TxtKomputerUzytkownika.ForeColor = [System.Drawing.SystemColors]::WindowText
    }

    # W TLE, NIE TUTAJ. Rozwiazanie nazwy i sonda ICMP to do poltorej sekundy, a policzone
    # na watku interfejsu byloby tyle samo zamrozonego okna.
    Start-JezykZadaniePingu -Netbios $Script:OstatniKomputer
}

# Przepisuje wynik sondy na zadanie z przycisku "Pinguj". Pole z nazwa maszyny zostaje
# nietkniete - zmienia sie wylacznie jego kolor i adres obok.
function Update-JezykPingWTle {
    param($Ping)

    Set-JezykDostepnoscKomputera -Odpowiada $Ping.Odpowiada `
                                 -Adres ([string]$Ping.Adres) `
                                 -Opis ([string]$Ping.Blad)
}

# To samo po drugiej stronie okna: zamyka pole uzytkownika maszyny w widoku komputera.
function Set-JezykPoleUzytkownikaBezTla {
    param([string]$Blad)
    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownikMaszyny) { return }
    $k.TxtKomputerUzytkownikMaszyny.Text = 'nie sprawdzono'
    Set-JezykInfo 'Uzytkownik' $Blad
}

<#
.SYNOPSIS
    Odklada tresc pod przycisk "!" przy danym polu - albo zdejmuje ja razem z przyciskiem.

.DESCRIPTION
    Nastepczyni dymka nad kontrolka. Dymek niosl cala diagnostyke narzedzia, ale nic
    w oknie nie sygnalizowalo, ze tam jest - kto nie wiedzial, ten nie najezdzal kursorem.
    Przycisk widac.

    Tresc trzymamy OSOBNO od przycisku: przycisk odpowiada wylacznie za widocznosc, a tekst
    ma przezyc kazde przerysowanie okna. Przycisk pojawia sie dokladnie wtedy, gdy jest
    co pokazac, i znika razem z trescia.

    Osobna funkcja takze dlatego, ze w testach kontrolek nie ma wcale - jeden warunek
    tutaj zastepuje warunek przy kazdym z kilkunastu wywolan.
#>
function Set-JezykInfo {
    param([string]$Klucz, [string]$Tekst)

    $Script:Informacje[$Klucz] = $Tekst

    $przycisk = $Script:Kontrolki['Info' + $Klucz]
    if (-not $przycisk) { return }

    # Pole Status niesie dodatkowo slad po zamulonych wywolaniach tla - patrz
    # Show-JezykInformacja. Gdy jest tylko on, przycisk i tak ma sie pokazac.
    $jest = [bool]$Tekst
    if ($Klucz -eq 'Status' -and (Test-JezykJestDiagnostyka)) { $jest = $true }

    $przycisk.Visible = $jest
}

# Czy jest cokolwiek w sladzie zamulen tla? Osobna funkcja, bo zmienna powstaje dopiero
# w SEKCJI 4, a @($null).Count wynosi JEDEN - warunek napisany wprost mowilby "jest",
# zanim cokolwiek by sie wydarzylo.
function Test-JezykJestDiagnostyka {
    if (-not $Script:DiagnostykaTla) { return $false }
    return (@($Script:DiagnostykaTla).Count -gt 0)
}

<#
.SYNOPSIS
    Pokazuje tresc odlozona przez Set-JezykInfo. Wolane z klikniecia w przycisk "!".

.DESCRIPTION
    Do pola Status doklejany jest slad po wywolaniach, ktore ZA DLUGO trzymaly watek
    interfejsu. To jedyne miejsce, w ktorym da sie go zobaczyc bez debuggera, a odpowiada
    na jedyne pytanie, ktore pada po zamarciu okna: co je zamrozilo.
#>
function Show-JezykInformacja {
    param([string]$Klucz)

    $czesci = @()
    $tekst  = [string]$Script:Informacje[$Klucz]
    if ($tekst) { $czesci += $tekst }

    if ($Klucz -eq 'Status' -and (Test-JezykJestDiagnostyka)) {
        $czesci += @('', 'Zadania w tle, które zatrzymały okno na dłużej niż ćwierć sekundy:',
                     '') + @($Script:DiagnostykaTla)
    }

    if (@($czesci).Count -eq 0) { return }

    $tytul = [string]$Script:TytulyInformacji[$Klucz]
    if (-not $tytul) { $tytul = 'Informacja' }

    [void][System.Windows.Forms.MessageBox]::Show(
        ($czesci -join [Environment]::NewLine), ('Jeżyk - {0}' -f $tytul),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information)
}

<#
.SYNOPSIS
    Przepisuje wynik obejscia kontrolerow do pola daty logowania.

.DESCRIPTION
    Nazwa domeny przychodzi z UCHWYTU ZADANIA, a nie z biezacego wyboru w oknie: lista
    kontrolerow nalezy do domeny, w ktorej zadanie wystartowalo, a wybor mogl sie w tym
    czasie zmienic.
#>
function Update-JezykLogowanieWTle {
    param($Logowanie, [string]$Domena = '')

    $k = $Script:Kontrolki

    # Pamiec kontrolerow: ich rozpoznanie to osobne zapytanie, a lista zmienia sie raz na
    # wiele miesiecy - zapamietujemy ja pod nazwa domeny i podajemy nastepnemu zadaniu.
    if ($Domena -and @($Logowanie.Kontrolery).Count -gt 0) {
        $Script:KontroleryCache[$Domena] = @($Logowanie.Kontrolery)
    }

    $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Dokladna $Logowanie.Data `
                                                           -Przyblizona $Script:LogowaniePrzyblizone

    # Niepelne pokrycie znaczy, ze data MOZE byc zanizona - prawdziwe logowanie moglo trafic
    # na kontroler, ktory zamilkl.
    if ($Logowanie.Wszystkie -gt 0 -and $Logowanie.Odpytane -lt $Logowanie.Wszystkie -and
        $k.TxtStatus.Text -notmatch 'zaniżona') {
        $k.TxtStatus.Text = ('{0} Data logowania MOŻE być zaniżona - odpowiedziało {1} z {2} kontrolerów.' -f
                             $k.TxtStatus.Text, $Logowanie.Odpytane, $Logowanie.Wszystkie).Trim()
    }

    # Odrzucona nazwa to NIE to samo co milczacy kontroler: pierwsze jest usterka
    # konfiguracji, druga problemem z siecia. Idzie do pola Status, a nie pod przycisk "!"
    # przy dacie - tamten niesie stale wyjasnienie, skad biora sie dwie daty.
    if (@($Logowanie.Odrzucone).Count -gt 0 -and $k.TxtStatus.Text -notmatch 'Pominięte') {
        $k.TxtStatus.Text = ('{0} Pominięte nazwy kontrolerów: {1}.' -f
                             $k.TxtStatus.Text, (@($Logowanie.Odrzucone) -join ', ')).Trim()
    }
}

# Przepisuje wynik zapytania do SCCM do pola "Ostatnio zalogowany uzytkownik" w widoku
# komputera. Ta sama zasada co przy polu obok: przycisk "!" zapala sie WYLACZNIE przy
# bledzie, bo ma znaczyc dokladnie jedno - "cos nie dziala".
function Update-JezykUzytkownikaWTle {
    param($Uzytkownik)

    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownikMaszyny) { return }

    if ($Uzytkownik.Uzytkownik) {
        $k.TxtKomputerUzytkownikMaszyny.Text = if ($null -ne $Uzytkownik.Data) {
            '{0} ({1:yyyy-MM-dd HH:mm})' -f $Uzytkownik.Uzytkownik, $Uzytkownik.Data
        } else {
            [string]$Uzytkownik.Uzytkownik
        }
    }
    else {
        $k.TxtKomputerUzytkownikMaszyny.Text = if ($Uzytkownik.Blad) { $Uzytkownik.Blad } else { 'brak danych' }
    }

    Set-JezykInfo 'Uzytkownik' $(if ($Uzytkownik.Blad) { [string]$Uzytkownik.Szczegoly } else { '' })
}

# Przepisuje wynik zapytania do SCCM do pola "Ostatnio uzywany komputer". Pelna diagnostyka
# idzie pod przycisk "!" WYLACZNIE PRZY BLEDZIE: w polu jest na nia za malo miejsca, a bez
# niej nazwa przyczyny mowi, CO sie stalo, ale nie mowi, co z tym zrobic. Na sukcesie
# przycisk zostaje ukryty, mimo ze Szczegoly niosa przy okazji zrodlo/protokol/serwer -
# to nie usterka, wiec nie ma czego sygnalizowac wykrzyknikiem.
function Update-JezykKomputerWTle {
    param($Komputer)

    $k = $Script:Kontrolki

    if ($Komputer.Nazwa) {
        $k.TxtKomputerUzytkownika.Text = if ($null -ne $Komputer.Data) {
            '{0} ({1:yyyy-MM-dd HH:mm})' -f $Komputer.Nazwa, $Komputer.Data
        } else {
            $Komputer.Nazwa
        }
    }
    else {
        $k.TxtKomputerUzytkownika.Text = if ($Komputer.Blad) { $Komputer.Blad } else { 'brak danych' }
    }

    # NAZWA MASZYNY ODKLADANA OSOBNO. Przycisk "Pinguj" potrzebuje jej samej, a w polu
    # tekstowym siedzi razem z data - ta sama zasada, co przy $Script:LogowaniePrzyblizone
    # i przy loginie do odblokowania: kontrolka sluzy do pokazywania, nie do przenoszenia
    # stanu. Przycisk jest czynny dokladnie wtedy, gdy jest co pingowac.
    $Script:OstatniKomputer = [string]$Komputer.Nazwa
    if ($k.PrzyciskPinguj) { $k.PrzyciskPinguj.Enabled = [bool]$Script:OstatniKomputer }

    # Wynik sondy przyszedl razem z nazwa - zapytanie do SCCM i ping poszly jednym zadaniem
    # w tle, wiec kolor i adres sa gotowe od razu, bez drugiej podrozy po sieci.
    Set-JezykDostepnoscKomputera -Odpowiada $Komputer.Odpowiada -Adres ([string]$Komputer.Adres)

    Set-JezykInfo 'Komputer' $(if ($Komputer.Blad) { [string]$Komputer.Szczegoly } else { '' })
}

#endregion
