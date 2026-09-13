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
    param($Dokladna, $Przyblizona, [switch]$Trwa, [string]$Kropki = '...')

    if ($null -ne $Dokladna) {
        if ($null -ne $Przyblizona) {
            return 'Dokładna data: {0} · poprzednia data: {1:yyyy-MM-dd HH:mm}' -f (Format-JezykData $Dokladna), $Przyblizona
        }
        return 'Dokładna data: {0}' -f (Format-JezykData $Dokladna)
    }

    if ($null -ne $Przyblizona) {
        if ($Trwa) { return 'Data przybliżona: {0} precyzowanie{1}' -f (Format-JezykData $Przyblizona), $Kropki }
        return 'Data przybliżona: {0}' -f (Format-JezykData $Przyblizona)
    }

    if ($Trwa) { return 'sprawdzanie' + $Kropki }
    return 'brak danych'
}

# Czysci widok konta do stanu "nic nie wiadomo". Wolane na poczatku kazdego renderowania
# i przy zmianie trybu: pol jest kilkanascie i latwo przeoczyc, ze ktores nie zostalo
# nadpisane, a zielony napis po nieudanym zapytaniu bylby najgorszym z nieporozumien.
<#
.SYNOPSIS
    Sklada oba numery telefonu w jeden napis do pola "Telefon:".

.DESCRIPTION
    KOLEJNOSC JEST STALA: glowny (LDAP telephoneNumber), potem komorkowy (mobile) - taka
    sama, w jakiej stoja w oknie AD. Stala, bo pole ich NIE PODPISUJE: przy dwoch numerach
    operator poznaje je po miejscu, a miejsce zmienne nie znaczyloby nic.

    PUSTY NUMER JEST POMIJANY, a nie zastepowany myslnikiem ani pustym miejscem po
    przecinku: jeden numer ma wygladac jak jeden numer, a nie jak polowa pary.

    Podpisy ("Glowny: ...") swiadomie odpadly - pole ma szerokosc polowy kolumny, a dwa
    numery z prefiksem +48 i podpisami sie w niej nie miesza i zostalyby uciete.
#>
function Get-JezykTelefony {
    param([string]$Glowny, [string]$Komorkowy)

    return ((@($Glowny, $Komorkowy) | Where-Object { $_ }) -join ', ')
}

<#
.SYNOPSIS
    Nadaje polu kolor wedlug ZNACZENIA, nie wedlug odcienia - i to znaczenie zapamietuje.

.DESCRIPTION
    JEDYNE MIEJSCE, KTORE USTAWIA ForeColor NA POLU. Paleta zmienia sie w trakcie dzialania
    okna (przycisk motywu w prawym dolnym rogu), wiec odcien zapisany na kontrolce przestaje
    po przelaczeniu cokolwiek znaczyc: zielen dobrana pod biale tlo na ciemnym tle jest
    nieczytelna, a nieczytelny werdykt to werdykt, ktorego nie ma. Przemalowac da sie tylko
    to, o czym wiadomo, CO mialo znaczyc - stad rola zamiast koloru.

    Rola trafia do $Script:RoleKolorow, skad czyta ja Set-JezykMotyw. Kluczem jest SAMA
    KONTROLKA, a nie jej nazwa z rejestru: pola sondy przychodza z Get-JezykPolaSondy juz
    jako obiekty i nazwy przy sobie nie maja.

    "Tekstu" to stan neutralny - nie "brak koloru", tylko kolor tekstu z biezacej palety.
    Czyszczenie pola idzie ta sama droga, co kazdy inny stan: kolor zostaje na kontrolce
    po zdjeciu tresci, wiec zerowanie NIE JEST kosmetyka.
#>
function Set-JezykKolorPola {
    param($Pole, [ValidateSet('Tekstu', 'Ok', 'Problem', 'Nieznany')][string]$Rola)

    if (-not $Pole) { return }

    $Script:RoleKolorow[$Pole] = $Rola
    $Pole.ForeColor = $Script:Config['Kolor' + $Rola]
}

function Clear-JezykKonto {
    $k = $Script:Kontrolki

    $k.WerdyktBox.Checked   = $false
    $k.Werdykt.Text         = 'Konto zablokowane'
    Set-JezykKolorPola $k.Werdykt 'Nieznany'

    $k.ChkAktywne.Checked     = $false
    $k.ChkZablokowane.Checked = $false
    $k.ChkFlagaHasla.Checked  = $false

    foreach ($pole in @($k.TxtLoginKonta, $k.TxtImieNazwisko, $k.TxtEmail,
                        $k.TxtHasloWygasa, $k.TxtKontoWygasa, $k.TxtOstatniaZmiana,
                        $k.TxtKontoUtworzono, $k.TxtTelefon, $k.TxtMenedzer,
                        $k.TxtOstatnieLogowanie, $k.TxtKomputerUzytkownika,
                        $k.TxtKomputerIp, $k.TxtKomputerMac, $k.TxtKatalog, $k.TxtStatus)) {
        if ($pole) { $pole.Text = '' }
    }

    # Etykieta pierwszego pola wraca do stanu domyslnego. Widok kontaktu przestawia ja na
    # "Nazwa:" - bez tego zostalaby tak przy nastepnym wyszukaniu KONTA i opisywalaby login
    # slowem "Nazwa".
    if ($k.EtykietaLoginKonta) { $k.EtykietaLoginKonta.Text = 'Login:' }

    # Adres, do ktorego dopasowano MAC, opisuje POPRZEDNIA maszyne - zostawiony kazalby
    # ponownemu pingowi porownywac sie z czyms, czego w oknie juz nie ma.
    $Script:MacDlaAdresu = ''

    # Notka o trwajacym zapytaniu do SCCM gasnie razem z polami. Trzy pola sa tu czyszczone
    # WPROST, z pominieciem obu funkcji, ktore normalnie ja zdejmuja - zapomniany marker
    # kazalby zegarowi tla wpisywac kropki do widoku, w ktorym nic juz nie trwa.
    Set-JezykNotkeSprawdzania -Wylacz

    # Data przyblizona nalezy do KONKRETNEGO konta - zostawiona wpisalaby sie do pola
    # opisujacego juz kogos innego.
    $Script:LogowaniePrzyblizone = $null
    $Script:OstatnieKonto        = $null

    # Nazwa maszyny nalezy do KONKRETNEGO konta - zostawiona kazalaby przyciskowi "Pinguj"
    # sprawdzac komputer kogos, kogo juz nie ma na ekranie.
    $Script:OstatniKomputer = ''
    if ($k.PrzyciskPinguj) { $k.PrzyciskPinguj.Enabled = $false }
    Set-JezykPrzyciskPolacz ''

    # Grupy naleza do KONKRETNEGO konta - zostawiony czynny przycisk pokazywalby liste
    # opisujaca kogos, kogo juz nie ma w oknie. Samej listy nie ma czego zerowac osobno:
    # jedzie w $Script:OstatnieKonto, ktore gasnie linijke wyzej.
    Set-JezykPrzyciskGrupy @()

    Set-JezykInfo 'Komputer'              ''
    Set-JezykInfo 'KomputerWspoldzielony' ''
    Set-JezykInfo 'Status'                ''

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
    Set-JezykKolorPola $k.TxtHasloWygasa 'Tekstu'
    Set-JezykKolorPola $k.TxtKomputerUzytkownika 'Tekstu'
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

    # JEDNO WYWOLANIE NA WSZYSTKIE GALEZIE. Wynik bez konta ("nie znaleziono", "blad",
    # pusty login) niesie pusta liste grup, wiec warunek w Set-JezykPrzyciskGrupy gasi
    # przycisk sam - bez wpisu w kazdej galezi switcha z osobna.
    Set-JezykPrzyciskGrupy $Result.Grupy

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
            if ($problem) { Set-JezykKolorPola $k.Werdykt 'Problem' }
            else          { Set-JezykKolorPola $k.Werdykt 'Ok' }

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
            # nie znaczy tu porazki odczytu: oba numery przychodza z tego samego zapytania,
            # co reszta konta, wiec puste pole ma dokladnie jedno znaczenie - w AD nie ma
            # zadnego numeru. Skoro znaczenie jest jedno i pewne, ma byc NAPISANE, a nie
            # zgadywane z pustki.
            #
            # E-mail zostaje przy pustce swiadomie: konto bez skrzynki to stan normalny
            # i czesty, a napis przy kazdym takim koncie bylby samym halasem.
            $telefony = Get-JezykTelefony ([string]$Result.TelefonGlowny) ([string]$Result.TelefonKomorkowy)
            $k.TxtTelefon.Text  = if ($telefony) { $telefony } else { 'nie wpisano w AD' }

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
                Set-JezykKolorPola $k.TxtHasloWygasa 'Problem'
            }

            $k.TxtKontoWygasa.Text    = Format-JezykData $Result.KontoWygasa 'nigdy'
            $k.TxtOstatniaZmiana.Text = Format-JezykData $Result.OstatniaZmianaHasla 'nigdy nie ustawiono'
            $k.TxtKontoUtworzono.Text = Format-JezykData $Result.KontoUtworzono

            # Dwa wolne pola, dwa NIEZALEZNE zadania w tle. Data nie czeka nawet na wlasne
            # zadanie: wartosc przyblizona przyszla razem z reszta konta, wiec pokazujemy ja
            # od razu, a tlo tylko ja uscisli. Komputer czekac musi - AD nie wie o nim nic.
            $Script:LogowaniePrzyblizone   = $Result.OstatnieLogowaniePrzyblizone
            Set-JezykNotkeSprawdzania
            Set-JezykInfo 'Komputer'              ''
            Set-JezykInfo 'KomputerWspoldzielony' ''
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
            Set-JezykKolorPola $k.Werdykt 'Nieznany'

            $k.TxtImieNazwisko.Text = Get-JezykOsoba ([string]$Result.DisplayName) `
                                                     ([string]$Result.Imie) ([string]$Result.Nazwisko)
            $k.TxtEmail.Text          = [string]$Result.Email
            # Kontakt to wpis ksiazki adresowej, wiec numer jest tu najbardziej na miejscu -
            # i tym bardziej jego brak zasluguje na slowo zamiast pustki.
            $telefonyKontaktu = Get-JezykTelefony ([string]$Result.TelefonGlowny) ([string]$Result.TelefonKomorkowy)
            $k.TxtTelefon.Text        = if ($telefonyKontaktu) { $telefonyKontaktu } else { 'nie wpisano w AD' }
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
    Stop-JezykZadaniePingu

    foreach ($pole in @($k.TxtKomputerKatalog, $k.TxtKomputerUzytkownikMaszyny,
                        $k.TxtKomputerTworca, $k.TxtKomputerWlaczone, $k.TxtKomputerStatus,
                        $k.TxtKomputerIpMaszyny, $k.TxtKomputerMacMaszyny)) {
        if ($pole) { $pole.Text = '' }
    }

    # Pola SCCM czyscimy tu wprost, z pominieciem funkcji, ktore normalnie gasza marker
    # kropek - wiec gasimy go osobno. Zostawiony animowalby napis nad polami, w ktorych
    # nic juz nie stoi.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

    # POLE KOLOROWANE CZYSCI SIE DWA RAZY: z tresci i z koloru. Sam tekst zdjety zostawia
    # czerwien na kontrolce, wiec pierwsze wylaczone konto zabarwiloby pole NA STALE
    # i kazda nastepna maszyna wygladalaby na wylaczona. Dotyczy to takze pola adresu IP,
    # ktore po tej stronie okna niesie kolor sondy.
    foreach ($pole in @($k.TxtKomputerWlaczone, $k.TxtKomputerIpMaszyny)) {
        Set-JezykKolorPola $pole 'Tekstu'
    }

    # Maszyna zapomniana RAZEM z polami: to ona jest zrodlem prawdy dla obu przyciskow,
    # a nie pole tekstowe. Przyciski gasna tu, a nie przy wyniku - wynik nie-Ok idzie
    # ta sama droga i niczego nie zapala.
    $Script:OstatniKomputer = ''
    $Script:MacDlaAdresu    = ''
    if ($k.PrzyciskPingujMaszyny) { $k.PrzyciskPingujMaszyny.Enabled = $false }
    Set-JezykPrzyciskPolacz '' -Widok Maszyna

    Set-JezykInfo 'Uzytkownik' ''
    Set-JezykInfo 'Tworca' ''
    Set-JezykInfo 'MacMaszyny' ''
    Set-JezykInfo 'StatusMaszyny' ''
}

<#
.SYNOPSIS
    Sklada tresc pola "Dodany do AD przez" z podpisu wlasciciela i daty zalozenia.

.DESCRIPTION
    Jedno pole, bo to jedna odpowiedz na jedno pytanie - a dwa pola na tak krotkie wartosci
    podwyzszalyby panel bez powodu. Data jest w tym samym zapisie, co "Konto utworzono"
    w widoku konta, wiec obie strony okna czyta sie tak samo.

    Pusty podpis znaczy "deskryptora nie udalo sie odczytac", a nie "nikt nie dodal" -
    stad wlasny napis, a nie puste pole wygladajace jak brak wyszukiwania.
#>
function Get-JezykOpisTworcy {
    param($Podpis, $Utworzono)

    $tekst = [string]$Podpis
    if (-not $tekst) { $tekst = 'nie udało się ustalić' }

    if ($null -ne $Utworzono) { $tekst = '{0} · {1}' -f $tekst, (Format-JezykData $Utworzono) }

    $tekst
}

# Widok komputera odpowiada na trzy pytania: gdzie w drzewie AD lezy ten komputer, kto
# ostatnio z niego korzystal i kto go do AD dodal. Pierwsze i trzecie wie AD i sa w wyniku
# od razu; drugie wie wylacznie SCCM, wiec idzie w tlo - tak samo jak droga odwrotna
# w widoku konta.
function Set-JezykComputerResult {
    param($Result)

    $k = $Script:Kontrolki
    Clear-JezykKomputer

    if ($Result.Status -eq 'Ok') {
        $k.TxtKomputerKatalog.Text = [string]$Result.Lokalizacja

        # Nazwa Z AD, a nie z pola tekstowego: idzie do zapytania WQL i do zdalnej konsoli,
        # a AD zna ja w oryginalnej pisowni. Ona tez jest zrodlem prawdy dla obu przyciskow.
        $Script:OstatniKomputer = [string]$Result.Nazwa
        if ($k.PrzyciskPingujMaszyny) {
            $k.PrzyciskPingujMaszyny.Enabled = [bool]$Script:OstatniKomputer
        }
        Set-JezykPrzyciskPolacz $Script:OstatniKomputer -Widok Maszyna

        # Kropki zamiast napisu nieruchomego: trzy pola czekaja teraz na to samo zapytanie
        # (uzytkownik, adres IP, adres MAC), a napis nieruchomy nie odroznia trwajacej
        # pracy od zawieszonej.
        Set-JezykNotkeSprawdzania -Notka 'Sccm'
        Start-JezykZadanieUzytkownika -Netbios ([string]$Result.Nazwa)

        # ZADANIE SCCM BYWA NIEURUCHOMIONE - bez ustawien wraca, zanim cokolwiek zbuduje.
        # Dostepnosc maszyny jest wtedy nadal odpowiedzia, bo ICMP nie potrzebuje SCCM do
        # niczego; bez tego sonda "automatyczna" nie odbylaby sie w takim wdrozeniu ani raz.
        if (-not $Script:ZadanieUzytkownika) { Invoke-JezykPing -Widok Maszyna }

        if ($k.TxtKomputerTworca) {
            $k.TxtKomputerTworca.Text = Get-JezykOpisTworcy $Result.Tworca $Result.Utworzono
        }

        # TRZY STANY, TRZY KOLORY - jak przy dostepnosci maszyny. "Nie wiadomo" dostaje
        # kolor neutralny, bo pomalowanie go zielenia albo czerwienia byloby nieprawda:
        # nieodczytany atrybut to nie to samo, co odczytane "wyłączone".
        if ($k.TxtKomputerWlaczone) {
            $k.TxtKomputerWlaczone.Text = if ($null -eq $Result.Wlaczone) { 'Nie wiadomo' }
                                          elseif ($Result.Wlaczone)      { 'Włączone' }
                                          else                           { 'Wyłączone - ta maszyna nie zaloguje się do domeny' }

            $rolaWlaczone = if ($null -eq $Result.Wlaczone) { 'Tekstu' }
                            elseif ($Result.Wlaczone)      { 'Ok' }
                            else                           { 'Problem' }
            Set-JezykKolorPola $k.TxtKomputerWlaczone $rolaWlaczone
        }

        # "!" zapala sie WYLACZNIE wtedy, gdy pole nie nazywa osoby - inaczej bylby stalym
        # wyjasnieniem, a takie z tego okna zostaly celowo usuniete. Trzy stany, nie dwa:
        # $true osoba, $false grupa albo SID, $null deskryptor nieodczytany.
        if ($Result.TworcaOsoba -eq $true) {
            Set-JezykInfo 'Tworca' ''
        }
        elseif ($null -eq $Result.TworcaOsoba) {
            Set-JezykInfo 'Tworca' ('Nie udało się odczytać właściciela obiektu komputera ' +
                'w AD (atrybut nTSecurityDescriptor). Najczęściej znaczy to brak prawa ' +
                'odczytu deskryptora zabezpieczeń tego obiektu.')
        }
        else {
            Set-JezykInfo 'Tworca' ('Pole pokazuje właściciela obiektu w AD, czyli konto, ' +
                'które ten komputer założyło. Tu właścicielem NIE jest osoba: gdy obiekt ' +
                'zakłada członek grupy Administratorzy domeny, AD zapisuje jako właściciela ' +
                'tę grupę, a nie jej członka - nazwiska nie da się wtedy z AD odczytać.')
        }
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
    Zapytanie po NAZWIE jest synchroniczne, wiec okno na moment przestaje reagowac; bez
    wylaczenia przycisku niecierpliwe podwojne klikniecie ustawialoby w kolejce drugie
    zapytanie. Blok finally jest niezbedny - gdyby renderowanie przerwalo sie w polowie,
    przycisk zostalby wylaczony na stale.

    "Na moment" jest tu doslowne: filtr po nazwie idzie po atrybutach indeksowanych,
    z gwiazdka na koncu wartosci, wiec wraca od razu. Wyszukiwanie po NUMERZE takie nie
    jest i wlasnie dlatego rusza osobno, w tle - patrz Start-JezykZadanieNumeru.
#>
function Invoke-JezykSearch {
    $k    = $Script:Kontrolki
    $okno = $k.Okno
    $tryb = [string]$k.Tryb.SelectedItem
    $tekst = $k.PoleSzukaj.Text

    # ZATRZYMANIE POPRZEDNIEGO SZUKANIA PO NUMERZE IDZIE PIERWSZE i PRZED ROZGALEZIENIEM
    # NA TRYB. Bez tego trafienia z poprzedniego numeru dolaczylyby do listy zbudowanej
    # wlasnie teraz - a w trybie komputera doklejalyby sie do listy, ktorej nikt nie widzi,
    # i dopisywaly notke do panelu konta stojacego wtedy poza ekranem.
    #
    # Start-JezykZadanieNumeru robi to samo na wejsciu, ale odpala sie wylacznie wtedy, gdy
    # nowy wpis wyglada na numer - a porzucic poprzednie zadanie trzeba ZAWSZE.
    Stop-JezykZadanieNumeru

    $k.Przycisk.Enabled = $false
    $okno.UseWaitCursor = $true

    # JEZ ZAPALA SIE PRZY KAZDYM SZUKANIU, nie tylko po numerze telefonu: operator ma
    # widziec, ze okno pracuje, niezaleznie od tego, czego szuka. Gasnie w finally - chyba
    # ze wlasnie ruszylo zadanie numeru i jest jeszcze na co czekac.
    #
    # Przy zapytaniu synchronicznym jez jest widoczny, ale NIERUCHOMY: klatki odmierza zegar
    # na watku interfejsu, a ten stoi wtedy w zapytaniu. Zapytania po nazwie ida po atrybutach
    # indeksowanych i trwaja ulamek sekundy, wiec jez mignie - i tyle ma zrobic.
    Set-JezykStanJeza 'Szuka'

    # Domyslnie "nie znaleziono": finally biegnie takze po wyjatku, a wyjatek na pewno nie
    # jest udanym wyszukaniem.
    $znaleziono = $false

    # Pole Status niesie na razie odpowiedz, a nie notke o trwajacym szukaniu - patrz nizej.
    $Script:StatusCzekaNaNumer = $false

    # Wymuszenie przerysowania - inaczej zmiana kursora i zapalenie jeza pojawilyby sie
    # dopiero po zakonczeniu zapytania, czyli gdy nie sa juz potrzebne.
    $okno.Refresh()

    try {
        if ($tryb -eq $Script:Config.TrybKomputer) {
            # Wynik do zmiennej, a nie wprost w argument: jego status decyduje o pozie jeza.
            $wynik = Get-JezykComputerStatus -Netbios $tekst
            Set-JezykComputerResult -Result $wynik
            $znaleziono = ($wynik.Status -eq 'Ok')
        }
        else {
            $lista = Find-JezykUsers -Fragment $tekst
            Set-JezykListaKont -Konta $lista.Konta
            $znaleziono = ($lista.Status -eq 'Ok')

            if ($lista.Status -eq 'Ok') {
                # Przypisanie zaznaczenia odpala Invoke-JezykWyborKonta, ktore wykona pelny
                # odczyt - dzieki temu pierwsza pozycja pokazuje sie bez dodatkowego klikniecia.
                $Script:Kontrolki.ListaKont.SelectedIndex = 0
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

            # NUMER TELEFONU RUSZA NA KONCU, JUZ PO ZAZNACZENIU PIERWSZEJ POZYCJI.
            # Zaznaczenie uruchamia Set-JezykResult, a ten nadpisuje pole Status opisem
            # konta - cokolwiek dopisanego wczesniej zgineloby bez sladu, dokladnie tak,
            # jak kiedys ginelo potwierdzenie odblokowania.
            #
            # Zadanie rusza takze wtedy, gdy po nazwie NIC nie znaleziono: to najczestszy
            # przypadek przy szukaniu po numerze i wtedy wlasnie jest najbardziej potrzebne.
            if (Test-JezykWygladaNaTelefon $tekst) {
                Start-JezykZadanieNumeru -Cyfry (Get-JezykCyfry $tekst)

                # NOTKA ZASTEPUJE ZDANIE, KTORE WLASNIE PRZESTALO BYC PRAWDA. Po pustym
                # wyniku po nazwie okno mowilo "Nie znaleziono konta ani kontaktu pasujacego
                # do ..." - brzmialo to jak werdykt i bylo nim przez kilkanascie sekund,
                # podczas gdy szukanie po numerze, czyli to, po ktore operator tu przyszedl,
                # dopiero sie zaczynalo. Kto nie wiedzial, ze cos jeszcze trwa, zamykal okno
                # przed odpowiedzia.
                #
                # WYLACZNIE PRZY 'NotFound'. Przy bledzie odczytu i przy "zbyt wielu
                # trafieniach" pole niesie zdanie prawdziwe i wazne - notka zakrylaby jedyna
                # wiadomosc o awarii.
                #
                # I wylacznie, gdy zadanie NAPRAWDE ruszylo: nieudane uruchomienie zostawia
                # $Script:ZadanieNumeru pustym, a wtedy nie ma juz na co czekac i "trwa"
                # bylo by klamstwem od pierwszej chwili.
                if ($Script:ZadanieNumeru -and $lista.Status -eq 'NotFound') {
                    $k.Werdykt.Text   = 'Trwa szukanie po numerze'
                    $k.TxtStatus.Text = 'Po nazwie nic nie znaleziono. Trwa jeszcze szukanie po numerze telefonu w domenie {0} - to potrwa dłużej, poczekaj na wynik.' -f
                                        $Script:Config.Domena
                    $Script:StatusCzekaNaNumer = $true
                }
            }
        }
    }
    finally {
        $okno.UseWaitCursor = $false
        $k.Przycisk.Enabled = $true

        # Jez STAJE Z WYNIKIEM, CHYBA ZE zadanie numeru wlasnie ruszylo i biegnie - wtedy ma
        # biec dalej, bo werdykt jeszcze nie jest znany. Nieudany start zostawia
        # $Script:ZadanieNumeru pusty, wiec jez staje takze wtedy.
        #
        # Poza zostaje na ekranie az do nastepnego klikniecia "Szukaj".
        if (-not $Script:ZadanieNumeru) {
            # Wynik przez ZMIENNA, a nie wprost w argumencie: "Polecenie (if ...)" nie jest
            # poprawne w Windows PowerShell 5.1.
            $stan = if ($znaleziono) { 'Jablko' } else { 'NaPlecach' }
            Set-JezykStanJeza $stan
        }
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
    Set-JezykNotkeSprawdzania -Notka 'Logowanie' -Wylacz

    $k = $Script:Kontrolki
    if (-not $k.TxtOstatnieLogowanie) { return }
    $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Przyblizona $Script:LogowaniePrzyblizone
}

# Zamyka pole komputera po nieudanym zapytaniu do SCCM. Dostepnosc gasnie razem z nim:
# bez nazwy maszyny nie ma czego pingowac, a zostawiony kolor opisywalby poprzednia.
function Set-JezykPoleKomputeraBezTla {
    param([string]$Blad)
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownika) { return }
    $k.TxtKomputerUzytkownika.Text = 'nie sprawdzono'
    Set-JezykDostepnoscKomputera -Odpowiada $null -Adres ''
    Set-JezykAdresMac -Mac '' -Szczegoly ''
    Set-JezykInfo 'Komputer'              $Blad
    Set-JezykInfo 'KomputerWspoldzielony' ''
}

<#
.SYNOPSIS
    Oddaje kontrolki sondy nalezace do WSKAZANEGO panelu - oba widoki maja wlasna trojke.

.DESCRIPTION
    WIDOK PODAJE SIE JAWNIE, a nie odczytuje z listy trybu. Sonda obsluguje obie polowki
    okna, a Set-JezykWidok czysci JE OBIE juz PO przestawieniu listy - czyszczenie konta
    trafialoby wtedy w kontrolki maszyny. Wolajacy zawsze wie, czyj wynik renderuje.

    W widoku maszyny kolor niesie SAMO pole adresu: nazwy maszyny nie ma tam w zadnym polu,
    bo to ona jest pytaniem wpisanym przez operatora.
#>
function Get-JezykPolaSondy {
    param([ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $k = $Script:Kontrolki

    if ($Widok -eq 'Maszyna') {
        return [pscustomobject]@{ Kolor    = $k.TxtKomputerIpMaszyny
                                  Ip       = $k.TxtKomputerIpMaszyny
                                  Mac      = $k.TxtKomputerMacMaszyny
                                  KluczMac = 'MacMaszyny' }
    }

    [pscustomobject]@{ Kolor    = $k.TxtKomputerUzytkownika
                       Ip       = $k.TxtKomputerIp
                       Mac      = $k.TxtKomputerMac
                       KluczMac = 'Mac' }
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

    Ktory panel wypelnic, mowi -Widok - patrz Get-JezykPolaSondy wyzej.
#>
function Set-JezykDostepnoscKomputera {
    param($Odpowiada, [string]$Adres, [string]$Opis = '',
          [ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $pola = Get-JezykPolaSondy -Widok $Widok
    if (-not $pola.Kolor) { return }

    $rolaSondy = if ($null -eq $Odpowiada) { 'Tekstu' }
                 elseif ($Odpowiada)       { 'Ok' }
                 else                      { 'Problem' }
    Set-JezykKolorPola $pola.Kolor $rolaSondy

    if (-not $pola.Ip) { return }

    $pola.Ip.Text = if ($Adres) { $Adres }
                    elseif ($Opis) { $Opis }
                    else { 'nie sprawdzono' }
}

<#
.SYNOPSIS
    Wypelnia pole "Adres MAC" i rozstrzyga przy nim przycisk "!".

.DESCRIPTION
    MAC pokazujemy WYLACZNIE wtedy, gdy karta z inwentaryzacji SCCM ma ten sam adres IP,
    ktory stoi w polu obok. Maszyna miewa kilka kart - Ethernet, Wi-Fi, VPN, Hyper-V -
    i adres wziety "z brzegu" opisywalby inna z nich niz ta, ktora odpowiada pod pokazanym
    IP. Nic by tego przy tym nie zdradzilo, bo jeden adres MAC wyglada jak kazdy inny.

    Brak dopasowania jest zwyklym wynikiem, nie awaria: inwentaryzacja sprzetu odswieza sie
    co kilka dni, wiec po zmianie dzierzawy DHCP zapisany adres bywa starszy niz biezacy.
    Stad przycisk NIEBIESKI i tresc pod nim - zapalany tylko wtedy, gdy jest co wyjasnic.
#>
function Set-JezykAdresMac {
    param([string]$Mac, [string]$Szczegoly,
          [ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $pola = Get-JezykPolaSondy -Widok $Widok
    if ($pola.Mac) {
        $pola.Mac.Text = if ($Mac) { $Mac }
                         elseif ($Szczegoly) { 'nie dopasowano' }
                         else { 'nie sprawdzono' }
    }

    # Tresc tylko wtedy, gdy MAC-a NIE MA: przy trafieniu wyjasniac nie ma czego, a przycisk
    # widoczny zawsze bylby stalym wyjasnieniem - takie z tego okna zostaly usuniete.
    Set-JezykInfo $pola.KluczMac $(if ($Mac) { '' } else { $Szczegoly })
}

<#
.SYNOPSIS
    Zapala i gasi notki "sprawdzanie" w polach czekajacych na odpowiedz z tla.

.DESCRIPTION
    DWIE NOTKI, BO DWA NIEZALEZNE ZADANIA. Trzy pola SCCM ("Ostatnio uzywany komputer",
    "Adres IP", "Adres MAC") czekaja na zadanie Komputer, a "Ostatnie logowanie" na zadanie
    Logowanie - koncza sie w innych chwilach, wiec kazde gasi WYLACZNIE swoja notke.
    Licznik klatek jest przy tym wspolny, zeby kropki w obu miejscach szly rownym krokiem.

    JEDNO MIEJSCE NA WSZYSTKIE CZYNNOSCI - dokladnie ta sama zasada, co przy
    Set-JezykStanJeza. Notka to markery, licznik klatek ORAZ tresc pol; rozpisana po
    miejscach wywolania rozjechalaby sie przy pierwszej zmianie i zostawilaby w oknie slowo
    "sprawdzanie" nad praca, ktora dawno sie skonczyla.

    MARKER, A NIE SAMA TRESC POLA. Po napisie w polu nie poznasz, czy to notka, czy juz
    odpowiedz - "nie sprawdzono" wyglada jak kazdy inny wynik. Dopiero marker pozwala
    zegarowi tla odroznic pole, ktore wolno przemalowac, od pola z gotowa odpowiedzia.

    -Wylacz NIE RUSZA TRESCI POL. Kazdy wolajacy wpisuje zaraz potem wartosc prawdziwa,
    a wyczyszczenie pol tutaj dawaloby mrugniecie pustka miedzy jednym a drugim.
#>
function Set-JezykNotkeSprawdzania {
    param([ValidateSet('Obie', 'Sccm', 'Logowanie')][string]$Notka = 'Obie', [switch]$Wylacz)

    $stan = -not $Wylacz
    if ($Notka -ne 'Logowanie') { $Script:PolaCzekajaNaSccm    = $stan }
    if ($Notka -ne 'Sccm')      { $Script:PoleCzekaNaLogowanie = $stan }

    if ($Wylacz) { return }

    # Licznik zerujemy WYLACZNIE przy zapalaniu. Zgaszenie jednej notki nie moze odrzucic
    # kropek drugiej na poczatek cyklu - zadania koncza sie niezaleznie od siebie.
    $Script:KlatkaKropek = 0

    # Pierwsza klatka OD RAZU, nie dopiero za takt zegara. Zapytanie bywa krotsze niz
    # cwierc sekundy i pola staly wtedy puste przez cale swoje czekanie.
    Update-JezykKropkiSprawdzania
}

<#
.SYNOPSIS
    Jedna klatka animowanych kropek w polach czekajacych na odpowiedz z tla.

.DESCRIPTION
    BEZ WLASNEGO ZEGARA. Wolana z taktu $Script:ZegarTla, bo ten budzi sie co 250 ms i chodzi
    dokladnie tak dlugo, jak zyja zadania w tle - czyli w tym samym oknie czasu, o ktore tu
    chodzi. Osobny zegar budzilby watek interfejsu drugi raz po to samo, a zapomniany
    chodzilby nad nieruchomym napisem do konca dnia.

    TAKT ZEGARA TO NIE KLATKA. Kropki zmieniaja sie co 500 ms, czyli co drugie budzenie -
    stad dzielenie licznika przez $Script:TaktowNaKlatkeKropek. Cztery zmiany na sekunde
    czytaja sie jak migotanie, a nie jak trwajaca praca.

    ZGASZONY MARKER ZATRZYMUJE WSZYSTKO i to jest zapora, nie oszczednosc: odpowiedz, ktora
    przyszla w tym samym takcie, gasi swoj marker w Receive-JezykZadanie... - a te ida
    w zegarze PRZED ta funkcja, wiec klatka nie ma juz czego nadpisac.
#>
function Update-JezykKropkiSprawdzania {
    if (-not $Script:PolaCzekajaNaSccm -and -not $Script:PoleCzekaNaLogowanie) { return }

    $klatka = [int][math]::Floor($Script:KlatkaKropek / $Script:TaktowNaKlatkeKropek)
    $kropki = '.' * (1 + ($klatka % 3))
    $Script:KlatkaKropek++

    $k = $Script:Kontrolki

    # SZESC POL, NIE TRZY: oba widoki maja swoja trojke i oba czekaja na zapytanie do SCCM.
    # Jeden marker wystarcza, bo zadania "Komputer" i "Uzytkownik" nigdy nie biegna naraz -
    # Set-JezykWidok przerywa przy zmianie trybu oba. Kropki lecace w panelu niewidocznym
    # nikomu nie przeszkadzaja, a czyszczenie przy powrocie i tak je zdejmie.
    if ($Script:PolaCzekajaNaSccm) {
        foreach ($pole in @($k.TxtKomputerUzytkownika, $k.TxtKomputerIp, $k.TxtKomputerMac,
                            $k.TxtKomputerUzytkownikMaszyny, $k.TxtKomputerIpMaszyny,
                            $k.TxtKomputerMacMaszyny)) {
            if ($pole) { $pole.Text = 'sprawdzanie' + $kropki }
        }
    }

    # Data przyblizona przyszla razem z kontem i siedzi juz w polu, wiec notka jest tu
    # DOPISKIEM do prawdziwej odpowiedzi, a nie zamiast niej - stad ta sama funkcja
    # skladajaca tekst, co przy gotowym wyniku.
    if ($Script:PoleCzekaNaLogowanie -and $k.TxtOstatnieLogowanie) {
        $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Przyblizona $Script:LogowaniePrzyblizone `
                                                               -Trwa -Kropki $kropki
    }
}

# Obsluga przycisku "Pinguj": sprawdza JESZCZE RAZ maszyne, ktora jest juz na ekranie.
# Nazwa idzie z $Script:OstatniKomputer, a nie z pola tekstowego - pole sluzy do
# pokazywania i niesie takze date, wiec nie jest zrodlem prawdy.
function Invoke-JezykPing {
    param([ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    if (-not $Script:OstatniKomputer) { return }

    # KTORY WIDOK ZAMOWIL SONDE, ODKLADAMY TERAZ. Wynik wraca z tla po sekundach, przez
    # osobne zadanie, a wtedy nikt juz nie pamieta, ktory przycisk go zamowil - i nie ma
    # tego skad odczytac, bo obie polowki okna maja wlasna trojke pol.
    $Script:WidokSondy = $Widok

    $pola = Get-JezykPolaSondy -Widok $Widok
    # NAPIS STATYCZNY, nie animowany. Ta praca trwa do poltorej sekundy - nie ma czym migac,
    # a zapalenie markera kropek gasiloby odpowiedzi zadania SCCM, ktore o tym nie wie.
    if ($pola.Ip)    { $pola.Ip.Text = 'sprawdzanie...' }
    Set-JezykKolorPola $pola.Kolor 'Tekstu'

    # W TLE, NIE TUTAJ. Rozwiazanie nazwy i sonda ICMP to do poltorej sekundy, a policzone
    # na watku interfejsu byloby tyle samo zamrozonego okna.
    Start-JezykZadaniePingu -Netbios $Script:OstatniKomputer
}

# Przepisuje wynik sondy na zadanie z przycisku "Pinguj". Pole z nazwa maszyny zostaje
# nietkniete - zmienia sie wylacznie jego kolor i adres obok.
function Update-JezykPingWTle {
    param($Ping)

    # Widok bierzemy z markera odlozonego przy zamawianiu sondy - patrz Invoke-JezykPing.
    $widok = if ($Script:WidokSondy) { $Script:WidokSondy } else { 'Konto' }

    Set-JezykDostepnoscKomputera -Odpowiada $Ping.Odpowiada `
                                 -Adres ([string]$Ping.Adres) `
                                 -Opis ([string]$Ping.Blad) `
                                 -Widok $widok

    # POKAZANY MAC OPISUJE KARTE SPOD KONKRETNEGO ADRESU. Gdy maszyna odpowiada juz spod
    # innego - a wlasnie po to klika sie "Pinguj" po dluzszej chwili - dotychczasowy adres
    # MAC przestaje byc odpowiedzia i nie wolno go zostawic. Sonda nie ma przy tym skad
    # wziac nowego: idzie sama, bez sesji do SCCM.
    $adres = [string]$Ping.Adres
    if ($Script:MacDlaAdresu -and $adres -and $adres -ne $Script:MacDlaAdresu) {
        Set-JezykAdresMac -Widok $widok -Mac '' -Szczegoly (
            'Maszyna odpowiada teraz spod adresu {0}, a pokazany wcześniej adres MAC opisywał kartę spod {1}. Nowego dopasowania sonda nie zna - zna je wyłącznie SCCM, więc wyszukaj ponownie.' -f
                $adres, $Script:MacDlaAdresu)
        $Script:MacDlaAdresu = ''
    }
}

# To samo po drugiej stronie okna: zamyka pole uzytkownika maszyny w widoku komputera.
function Set-JezykPoleUzytkownikaBezTla {
    param([string]$Blad)
    # Marker gasnie PRZED czymkolwiek innym, w kazdej galezi, ktora odpowiedz moze wyjsc -
    # slowo "sprawdzanie" zostawione po skonczonej pracy klamie tak samo, jak jego brak
    # w trakcie.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownikMaszyny) { return }
    $k.TxtKomputerUzytkownikMaszyny.Text = 'nie sprawdzono'
    Set-JezykDostepnoscKomputera -Odpowiada $null -Adres '' -Widok Maszyna
    Set-JezykAdresMac -Mac '' -Szczegoly '' -Widok Maszyna
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

    # Dokladna data przyszla - slowo "precyzowanie" przestaje byc prawdziwe.
    Set-JezykNotkeSprawdzania -Notka 'Logowanie' -Wylacz

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

    # Marker kropek gasnie PRZED wpisaniem czegokolwiek - inaczej nastepny takt zegara
    # nadpisalby gotowa odpowiedz napisem "sprawdzanie".
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

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

    # Dostepnosc i karta sieciowa przychodza TYM SAMYM wynikiem, co uzytkownik - jedna
    # podroz po sieci na trzy pola, dokladnie jak po drugiej stronie okna.
    Set-JezykDostepnoscKomputera -Odpowiada $Uzytkownik.Odpowiada `
                                 -Adres ([string]$Uzytkownik.Adres) -Widok Maszyna

    Set-JezykAdresMac -Mac ([string]$Uzytkownik.Mac) `
                      -Szczegoly ([string]$Uzytkownik.MacSzczegoly) -Widok Maszyna

    # Adres, do ktorego MAC zostal dopasowany - ponowny ping sprawdzi po nim, czy pokazana
    # karta nadal opisuje te maszyne.
    $Script:MacDlaAdresu = if ($Uzytkownik.Mac) { [string]$Uzytkownik.Adres } else { '' }

    Set-JezykInfo 'Uzytkownik' $(if ($Uzytkownik.Blad) { [string]$Uzytkownik.Szczegoly } else { '' })
}

<#
.SYNOPSIS
    Doklada do listy wyboru konta znalezione po NUMERZE TELEFONU - juz po tym, jak okno
    pokazalo wynik wyszukiwania po nazwie.

.DESCRIPTION
    CZTERY ROZNE ODPOWIEDZI, NIE DWIE. Trafienia, "jest ich za wielu", "nie udalo sie
    sprawdzic" i "nikogo nie ma" prowadza do zupelnie innych zdan w oknie, a pusta lista
    umie powiedziec tylko to ostatnie.

    DOKLEJAMY NA KONIEC, BEZ SORTOWANIA I BEZ RUSZANIA ZAZNACZENIA. Zapytanie trwa sekundy,
    wiec operator zdazyl juz kogos wybrac i ma przed soba jego dane - przestawienie listy
    albo zaznaczenia zabraloby mu to sprzed oczu w losowym momencie. Wyjatkiem jest lista
    PUSTA: tam nie ma czego zabierac, a bez zaznaczenia trafienie nie pokazaloby sie samo.

    ZBYT WIELU WLASCICIELI TO NIE USTERKA. Kontroler odpowiedzial i odpowiedz jest pelna -
    wiemy na pewno, ze trafien jest wiecej niz limit. Przycisku "!" wiec nie zapalamy,
    bo nie ma czego pod nim pokazac.

    NOTKE "TRWA SZUKANIE" ZASTEPUJEMY, A NIE DOKLEJAMY ZA NIA. Invoke-JezykSearch stawia ja
    w polu Status na czas pracy zadania i od chwili, w ktorej ta funkcja ruszyla, jest ona
    nieprawdziwa - szukanie wlasnie sie skonczylo. Doklejenie zostawiloby "trwa" na ekranie
    do konca dnia. Ktore zdanie tam stoi, mowi $Script:StatusCzekaNaNumer, bo po samej
    pustej liscie tego nie poznasz.
#>
function Update-JezykNumerWTle {
    param($Wynik)

    $k = $Script:Kontrolki

    # Czytamy RAZ, na wejsciu: galezie nizej same zmieniaja pole Status, wiec pytanie
    # zadane pozniej dotyczyloby juz zdania, ktore ta funkcja dopiero co tam wpisala.
    $notka = $Script:StatusCzekaNaNumer

    try {
        if ($Wynik.Przerwane) {
            # "NIE UDALO SIE SPRAWDZIC" TO NIE "NIKOGO NIE MA". Lista jest niepelna i operator
            # musi o tym wiedziec: ktos, kogo szukal, mogl sie na niej nie znalezc.
            if ($notka) {
                # Pole mowilo "trwa" i nie ma za czym doklejac - a samo "nie powiodlo sie"
                # zostawiloby operatora bez odpowiedzi na pytanie, ktore zadal.
                $k.Werdykt.Text   = 'Nie udało się sprawdzić numeru'
                $k.TxtStatus.Text = 'Po nazwie nic nie znaleziono, a przeszukanie numerów telefonu się nie powiodło - nie wiadomo, czy ten numer do kogoś należy.'
            }
            else {
                $k.TxtStatus.Text = ('{0} UWAGA: przeszukanie numerów telefonu się nie powiodło - lista może być niepełna.' -f
                                     $k.TxtStatus.Text).Trim()
            }
            Set-JezykInfo 'Status' ([string]$Wynik.Powod)
            return
        }

        if ($Wynik.ZaDuzo) {
            # Bez cytowania wpisanej wartosci: od uruchomienia zadania minely sekundy i operator
            # mogl juz zaczac wpisywac co innego - pole tekstowe niesie wtedy inny numer niz ten,
            # ktorego dotyczy ta odpowiedz.
            #
            # Jedno zdanie na oba przypadki: czyta sie i samodzielnie, i doklejone za innym.
            $zaWielu = 'Numeru używa w domenie {0} więcej niż {1} osób - to zwykle numer infolinii albo wspólny numer działu. Poszukaj po nazwisku albo loginie.' -f
                       $Script:Config.Domena, [int]$Script:Config.LimitNumeru

            if ($k.ListaKont.Items.Count -eq 0) {
                # PRZY PUSTEJ LISCIE POLE NIE NIESIE NIC, ZA CZYM WARTO DOKLEJAC: albo notke
                # "trwa szukanie", ktora wlasnie przestala byc prawda, albo - zanim ja tu
                # postawiono - "Nie znaleziono konta ani kontaktu", czyli zdanie DOKLADNIE
                # odwrotne do stanu faktycznego: kont z tym numerem nie brakuje, jest ich za
                # wielu. Doklejone na koncu wyjasnienie ginelo poza widoczna czescia pola,
                # wiec operator czytal tylko to pierwsze zdanie. Dlatego ZASTEPUJEMY, a nie
                # doklejamy - razem z werdyktem.
                $k.TxtStatus.Text     = $zaWielu
                $k.Werdykt.Text       = 'Numer należy do wielu osób'
                Set-JezykKolorPola $k.Werdykt 'Nieznany'
            }
            else {
                # Cos znalazlo sie po nazwie, wiec zdanie o tych trafieniach jest prawdziwe
                # i ma zostac. Numer dopisuje sie za nim jako druga, osobna informacja.
                $k.TxtStatus.Text = ('{0} {1}' -f $k.TxtStatus.Text, $zaWielu).Trim()
            }
            return
        }

        $trafienia = @($Wynik.Trafienia)
        if ($trafienia.Count -eq 0) {
            if ($notka) {
                # Szukanie skonczylo sie i nikogo nie ma. Bez tego zdanie "trwa jeszcze
                # szukanie" zostawaloby na ekranie do nastepnego klikniecia "Szukaj" -
                # klamiac tak samo jak to, ktore mialo zastapic.
                #
                # Bez cytowania wpisanej wartosci, z tego samego powodu, co przy "za wielu":
                # od uruchomienia zadania minely sekundy i w polu moze juz stac co innego.
                $k.Werdykt.Text   = 'Nie znaleziono konta'
                $k.TxtStatus.Text = 'Nie znaleziono nikogo w domenie {0} - ani po nazwie, ani po numerze telefonu.' -f
                                    $Script:Config.Domena
            }
            return
        }

        $lista = $k.ListaKont

        # Bez duplikatow: konto z numerem w loginie potrafi trafic do obu zapytan, a dwa razy
        # ta sama osoba na liscie wyglada jak usterka.
        $juzSa = @{}
        foreach ($pozycja in $lista.Items) { $juzSa[[string]$pozycja.Dn] = $true }

        # Notka tu nie dotrwa i nie trzeba jej sprzatac: stawiana jest wylacznie przy PUSTEJ
        # liscie, a z pustej listy $juzSa wychodzi pusty i zadne trafienie nie odpada.
        $nowe = @($trafienia | Where-Object { -not $juzSa.ContainsKey([string]$_.Dn) })
        if ($nowe.Count -eq 0) { return }

        $bylaPusta = ($lista.Items.Count -eq 0)

        # Blokada zdarzen jak w Set-JezykListaKont: kazde dodanie pozycji wywoluje
        # SelectedIndexChanged, wiec bez niej jedno doklejenie odpalaloby kilka pelnych
        # zapytan do AD.
        $Script:BlokadaZdarzen = $true
        try { foreach ($pozycja in $nowe) { [void]$lista.Items.Add($pozycja) } }
        finally { $Script:BlokadaZdarzen = $false }

        if ($bylaPusta) {
            # Okno mowi w tej chwili "Nie znaleziono konta" - a wlasnie znalezlismy. Zaznaczenie
            # odpala Invoke-JezykWyborKonta, ktore wykona pelny odczyt i nadpisze caly widok
            # kontem, wiec werdykt i status poprawiaja sie same.
            $lista.SelectedIndex = 0
        }
        else {
            $k.TxtStatus.Text = ('{0} Po numerze telefonu dołączono {1} {2} - sprawdź listę wyboru.' -f
                                 $k.TxtStatus.Text, $nowe.Count,
                                 (Get-JezykOdmiana $nowe.Count 'konto' 'konta' 'kont')).Trim()
        }
    }
    finally {
        # Odpowiedz jest, wiec notki juz nie ma - zapali sie dopiero przy nastepnym szukaniu.
        $Script:StatusCzekaNaNumer = $false

        # POZA Z KONCOWEGO STANU LISTY, a nie z tego, co oddalo samo zadanie. Po nazwie mogl
        # sie ktos znalezc, choc numer nie dal nic - i odwrotnie: przy liscie pustej to
        # wlasnie numer jest jedynym trafieniem, jakie w ogole padlo.
        #
        # finally, a nie koniec funkcji: cztery odpowiedzi wychodza stad przez return,
        # wiec poza postawiona na koncu nie doczekalaby sie zadnej z nich.
        $stan = if ($k.ListaKont.Items.Count -gt 0) { 'Jablko' } else { 'NaPlecach' }
        Set-JezykStanJeza $stan
    }
}

<#
.SYNOPSIS
    Ustawia stan jeza - jedyny wskaznik pracy i wyniku wyszukiwania.

.DESCRIPTION
    CZTERY STANY: Ukryty (nic sie nie dzieje), Szuka (biegnie), Jablko (znaleziono),
    NaPlecach (nie znaleziono). Poza z wynikiem zostaje na ekranie az do nastepnego
    wyszukiwania - to ona, a nie zniknieciecie wskaznika, jest odpowiedzia dla operatora.

    JEDNO MIEJSCE NA WSZYSTKIE CZYNNOSCI. Wskaznik to kontrolka, licznik klatek ORAZ zegar
    animacji; rozpisane po miejscach wywolania rozjechalyby sie przy pierwszej zmianie
    i zostawilyby zegar chodzacy nad nieruchomym obrazkiem.

    LICZNIK KLATEK ZERUJEMY WYLACZNIE PRZY 'Szuka'. Poza ma zostac tam, gdzie jez skonczyl
    biec, wiec wyzerowanie go przy stawianiu pozy odrzucaloby jeza z powrotem na start.

    INVALIDATE JEST TU KONIECZNE. Przejscie 'Szuka' -> 'Jablko' nie zmienia Visible, wiec
    bez niego kontrolka nie przerysowalaby sie wcale i operator ogladalby biegnacego jeza
    zamrozonego w ostatniej klatce.

    ZEGARA MOZE NIE BYC. Zestaw weryfikacyjny nie buduje okna, wiec $Script:ZegarJeza jest
    tam pusty - straz jest ta sama, co przy $Script:ZegarTla w Jezyk-4-Okno.ps1.
#>
function Set-JezykStanJeza {
    param([ValidateSet('Ukryty', 'Szuka', 'Jablko', 'NaPlecach')][string]$Stan)

    $Script:StanJeza = $Stan
    $Script:Kontrolki.JezSzukania.Visible = ($Stan -ne 'Ukryty')

    if ($Stan -eq 'Szuka') { $Script:KlatkaJeza = 0 }

    $Script:Kontrolki.JezSzukania.Invalidate()

    if ($Script:ZegarJeza) {
        if ($Stan -eq 'Szuka') { $Script:ZegarJeza.Start() } else { $Script:ZegarJeza.Stop() }
    }
}

<#
.SYNOPSIS
    Pokazuje albo chowa przycisk "Polacz" - jedyne miejsce z warunkiem jego widocznosci.

.DESCRIPTION
    Przycisk ZNIKA I POJAWIA SIE, a nie wyszarza sie jak "Pinguj" i "Odblokuj konto".
    Roznica jest zamierzona: tamte dwa maja stany, ktore warto pokazac ("jest, ale nie
    teraz"), a ten ma tylko jeden powod istnienia - jest maszyna i jest czym sie z nia
    polaczyc. Przycisk wyszarzony na stale w kazdym wdrozeniu bez konsoli ConfigMgr bylby
    obietnica, ktorej nikt tam nigdy nie spelni.

    Warunek stoi TUTAJ, w jednym miejscu, a nie przy kazdym z dwoch wywolan - rozpisany
    rozjechalby sie przy pierwszej zmianie i przycisk zostawalby widoczny po przelaczeniu
    konta.
#>
function Set-JezykPrzyciskPolacz {
    param([string]$Netbios, [ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $przycisk = if ($Widok -eq 'Maszyna') { $Script:Kontrolki.PrzyciskPolaczMaszyny }
                else                      { $Script:Kontrolki.PrzyciskPolacz }
    if (-not $przycisk) { return }

    # Pusta sciezka w konfiguracji = funkcja swiadomie wylaczona, dokladnie tak samo jak
    # puste SccmSerwer. Czytamy ja przy kazdym wywolaniu, a nie raz przy starcie, bo to
    # jedna linia mniej stanu do zgubienia.
    $sciezka = ([string]$Script:Ustawienia.SciezkaRemoteControl).Trim()

    $przycisk.Visible = ([bool]$Netbios -and [bool]$sciezka)
}

# Obsluga przycisku "Polacz": oddaje wykryta maszyne zdalnej konsoli z ConfigMgr.
# Nazwa idzie z $Script:OstatniKomputer, a nie z pola tekstowego - dokladnie z tego samego
# powodu, co przy "Pinguj": w polu siedzi razem z data ostatniej aktywnosci.
#
# Wynik obslugujemy NIESYMETRYCZNIE i to jest swiadome. Niepowodzenie ma gdzie trafic
# (pole Status i przycisk "!"), bo inaczej klikniecie nie robiloby nic i nie mowiloby
# dlaczego. Powodzenie nie rusza NICZEGO: otwarte okno konsoli jest samo w sobie
# potwierdzeniem, a Set-JezykInfo 'Status' '' skasowaloby diagnostyke nalezaca do
# WYSZUKIWANIA, nie do tego klikniecia - to nie jest wykrzyknik tego przycisku.
function Invoke-JezykPolacz {
    param([ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $k = $Script:Kontrolki
    if (-not $Script:OstatniKomputer) { return }

    # Kazdy widok ma wlasne pole Status: i wlasny przycisk "!" przy nim - niepowodzenie ma
    # trafic tam, gdzie operator patrzy, a nie do panelu, ktorego w tej chwili nie widac.
    $pole  = if ($Widok -eq 'Maszyna') { $k.TxtKomputerStatus } else { $k.TxtStatus }
    $klucz = if ($Widok -eq 'Maszyna') { 'StatusMaszyny' }      else { 'Status' }

    $wynik = Start-JezykRemoteControl -Netbios $Script:OstatniKomputer `
                                      -Sciezka ([string]$Script:Ustawienia.SciezkaRemoteControl)

    if (-not $wynik.Udane) {
        if ($pole) { $pole.Text = [string]$wynik.Komunikat }
        Set-JezykInfo $klucz ([string]$wynik.Szczegoly)
    }
}

<#
.SYNOPSIS
    Zapala albo gasi przycisk "Grupy AD" - jedyne miejsce z warunkiem jego dostepnosci.

.DESCRIPTION
    Przycisk SIE WYSZARZA, a nie znika jak "Polacz". Roznica jest zamierzona: "Polacz"
    ma jeden powod istnienia i we wdrozeniu bez konsoli ConfigMgr nie zadziala NIGDY,
    a ten ma normalny stan przejsciowy - "jest, ale najpierw znajdz konto" - dokladnie
    taki, jaki pokazuja "Pinguj" i "Odblokuj konto".

    Warunek stoi TUTAJ, w jednym miejscu, a nie przy kazdym z dwoch wywolan. Rozpisany
    rozjechalby sie przy pierwszej zmianie i przycisk zostawalby czynny po przelaczeniu
    na konto bez grup - otwierajac liste opisujaca kogos, kogo juz nie ma na ekranie.
#>
function Set-JezykPrzyciskGrupy {
    param([string[]]$Grupy)

    $przycisk = $Script:Kontrolki.PrzyciskGrupyAd
    if (-not $przycisk) { return }

    # FILTR, A NIE SAMO @().Count. W PowerShellu @($null) to tablica JEDNOELEMENTOWA,
    # wiec licznik bez odsiania pustych zapalalby przycisk przy koncie bez grup - czyli
    # dokladnie tam, gdzie ma byc wyszarzony, i bez zadnego komunikatu o pomylce.
    $przycisk.Enabled = (@($Grupy | Where-Object { $_ }).Count -gt 0)
}

<#
.SYNOPSIS
    Naklada motyw na cale okno - palete, kontrolki i kolory niosace znaczenie.

.DESCRIPTION
    JEDNA FUNKCJA USTAWIA WSZYSTKO NARAZ, tak samo jak Set-JezykStanJeza ustawia kontrolke,
    licznik i zegar. Rozpisana po miejscach wywolania rozjedzie sie przy pierwszej zmianie,
    a pominiety krok nie zglasza sie niczym: kontrolka po prostu zostaje w starym kolorze.

    KOLEJNOSC NIE JEST DOWOLNA:
      1. paleta - zanim cokolwiek ja przeczyta,
      2. bufor pedzla ikonki na $null - inaczej ikonka narysuje sie starym kolorem,
      3. role wygladu - maluja tla i domyslny kolor tekstu,
      4. role kolorow - i dopiero one maja ostatnie slowo. Odwrotna kolejnosc zdjelaby
         czerwien z werdyktu i okno przez chwile twierdziloby, ze z kontem wszystko
         w porzadku. Zdanie nieprawdziwe przez chwile kosztuje tyle samo, co nieprawdziwe
         na stale - operator czyta werdykt raz.

    Jeza prosimy o przerysowanie osobno: jego tlo dziedziczy sie po oknie, ale poza zostaje
    ta sama, wiec nic innego by o to nie poprosilo.
#>
function Set-JezykMotyw {
    param([ValidateSet('Jasny', 'Ciemny')][string]$Motyw)

    $Script:Motyw = $Motyw

    $paleta = if ($Motyw -eq 'Ciemny') { $Script:MotywCiemny } else { $Script:MotywJasny }
    foreach ($klucz in @($paleta.Keys)) { $Script:Config[$klucz] = $paleta[$klucz] }

    $Script:PedzelMotywu = $null

    # Kopia kluczy, bo obie funkcje ponizej pisza do tych samych tablic.
    foreach ($kontrolka in @($Script:KontrolkiMotywu.Keys)) {
        Set-JezykWyglad $kontrolka $Script:KontrolkiMotywu[$kontrolka]
    }
    foreach ($pole in @($Script:RoleKolorow.Keys)) {
        Set-JezykKolorPola $pole $Script:RoleKolorow[$pole]
    }

    if ($Script:Kontrolki.JezSzukania) { $Script:Kontrolki.JezSzukania.Invalidate() }

    Set-JezykMotywSystemowy
}

<#
.SYNOPSIS
    Uchwyt okna kontrolki albo zero, gdy go jeszcze nie ma.

.DESCRIPTION
    PYTAMY PRZEZ PSObject.Properties, A NIE PO TYPIE. Zestaw weryfikacyjny podstawia
    [pscustomobject], wiec warunek na [System.Windows.Forms.Control] nie bylby w nim nigdy
    prawdziwy i cala sciezka systemowa nie wykonalaby sie ani razu.

    IsHandleCreated sprawdzamy PRZED Handle, bo samo siegniecie po Handle TWORZY uchwyt.
    Motyw nakladamy na koniec budowy okna, zanim cokolwiek zostalo pokazane - wymuszenie
    uchwytow w tamtym miejscu zmienialoby kolejnosc powstawania kontrolek. Zamiast tego
    sciezka systemowa wykonuje sie powtornie z Add_Shown, gdy uchwyty juz sa.
#>
function Get-JezykUchwyt {
    param($Kontrolka)

    if (-not $Kontrolka) { return [IntPtr]::Zero }

    $wlasciwosci = $Kontrolka.PSObject.Properties
    if (-not $wlasciwosci['IsHandleCreated'] -or -not $Kontrolka.IsHandleCreated) {
        return [IntPtr]::Zero
    }
    if (-not $wlasciwosci['Handle']) { return [IntPtr]::Zero }

    return $Kontrolka.Handle
}

# Ciemny pasek tytulu i ciemne paski przewijania - dwie rzeczy, ktorych WinForms nie umie,
# bo rysuje je system, a nie kontrolka. Osobna funkcja, zeby Set-JezykMotyw dalo sie
# przeczytac: tamta mowi, CO sie zmienia, ta - czego nie da sie zmienic zwyklym kolorem.
function Set-JezykMotywSystemowy {
    $ciemny = ($Script:Motyw -eq 'Ciemny')
    $k      = $Script:Kontrolki

    Set-JezykCiemnyPasekTytulu (Get-JezykUchwyt $k.Okno) -Ciemny:$ciemny

    # Tylko kontrolki, ktore naprawde maja pasek przewijania. Pola "Status:" sa
    # wielolinijkowe, ale bez paska - dopisanie ich tutaj niczego by nie zmienilo.
    foreach ($kontrolka in @($k.ListaKont, $k.Domena, $k.Tryb)) {
        Set-JezykCiemnyPasekPrzewijania (Get-JezykUchwyt $kontrolka) -Ciemny:$ciemny
    }
}

# Klikniecie ikonki. Przelacza na drugi motyw - innych stanow nie ma, wiec nie ma tu czego
# wybierac ani o co pytac.
function Invoke-JezykPrzelaczenieMotywu {
    if ($Script:Motyw -eq 'Ciemny') { Set-JezykMotyw 'Jasny' }
    else                            { Set-JezykMotyw 'Ciemny' }
}

# Przepisuje wynik zapytania do SCCM do pola "Ostatnio uzywany komputer". Pelna diagnostyka
# idzie pod przycisk "!" WYLACZNIE PRZY BLEDZIE: w polu jest na nia za malo miejsca, a bez
# niej nazwa przyczyny mowi, CO sie stalo, ale nie mowi, co z tym zrobic. Na sukcesie
# przycisk zostaje ukryty, mimo ze Szczegoly niosa przy okazji zrodlo/protokol/serwer -
# to nie usterka, wiec nie ma czego sygnalizowac wykrzyknikiem.
function Update-JezykKomputerWTle {
    param($Komputer)

    # Odpowiedz przyszla - notka przestaje byc prawdziwa, i to ZANIM cokolwiek wpiszemy.
    # Gasimy WYLACZNIE swoja: zadanie daty logowania biegnie niezaleznie i moze jeszcze trwac.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

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
    Set-JezykPrzyciskPolacz $Script:OstatniKomputer

    # Wynik sondy przyszedl razem z nazwa - zapytanie do SCCM i ping poszly jednym zadaniem
    # w tle, wiec kolor i adres sa gotowe od razu, bez drugiej podrozy po sieci.
    Set-JezykDostepnoscKomputera -Odpowiada $Komputer.Odpowiada -Adres ([string]$Komputer.Adres)

    # MAC dopasowany do TEGO adresu - i tylko do niego. Adres odkladamy osobno, zeby
    # ponowny ping mial z czym porownac swoj wynik (patrz Update-JezykPingWTle).
    Set-JezykAdresMac -Mac ([string]$Komputer.Mac) -Szczegoly ([string]$Komputer.MacSzczegoly)
    $Script:MacDlaAdresu = if ($Komputer.Mac) { [string]$Komputer.Adres } else { '' }

    Set-JezykInfo 'Komputer' $(if ($Komputer.Blad) { [string]$Komputer.Szczegoly } else { '' })

    # Niebieski "!" - nie usterka, wiec klucz jest niezalezny od Blad powyzej. Gaszony na
    # kazdej innej sciezce, inaczej zostalby stan po POPRZEDNIM, wspoldzielonym komputerze.
    Set-JezykInfo 'KomputerWspoldzielony' $(if ($Komputer.Wspoldzielony) { [string]$Komputer.SzczegolyWspoldzielenia } else { '' })
}

#endregion
