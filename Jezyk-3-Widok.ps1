# Jezyk-3-Widok - przelozenie wyniku na kontrolki okna i obsluga zdarzen. Zero zapytan do sieci.
# Linia 1 musi zostac zwyklym komentarzem - oslania pierwsza instrukcje przed zdublowanym BOM.

# Wlasny trap w kazdej czesci: trap wznawia prace w zakresie, w ktorym go zdefiniowano.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 3 - RENDEROWANIE WYNIKU
# Renderer dostaje obiekt wyniku i wypelnia kontrolki - nie wie, skad wynik przyszedl.

# Data z dopiskiem wzglednym: "2026-05-14 08:12 (98 dni temu)"; GdyBrak - napis, gdy daty nie ma.
function Format-JezykData {
    param($Data, [string]$GdyBrak = 'brak danych')

    if ($null -eq $Data) { return $GdyBrak }

    # Pelne dni - godziny w dopisku niczego nie wnosza.
    $dni = [int][math]::Round(((Get-Date) - $Data).TotalDays)

    if     ($dni -gt 0) { $wzglednie = '{0} dni temu' -f $dni }
    elseif ($dni -lt 0) { $wzglednie = 'za {0} dni'   -f [math]::Abs($dni) }
    else                { $wzglednie = 'dzisiaj' }

    '{0:yyyy-MM-dd HH:mm} ({1})' -f $Data, $wzglednie
}

# Tresc pola, ktorego wartosci moze nie byc - pokazany obiekt nie ma pustych pol.
function Get-JezykWartoscPola {
    param([string]$Wartosc, [string]$GdyBrak = 'nie wpisano w AD')

    if ($Wartosc) { return $Wartosc }
    return $GdyBrak
}

# Tresc pola "Ostatnie logowanie" dla wszystkich stanow (dokladna, najpozniejsza znana, nieudana, trwa, brak).
# "Dokladna" tylko przy komplecie odpowiedzi - rozstrzyga logika (Pelna), widok tylko ja pokazuje.
function Get-JezykTekstLogowania {
    param($Wynik = $null, $Przyblizona, [switch]$Trwa, [string]$Kropki = '...', [switch]$Nieudane)

    if ($Wynik -and -not $Wynik.Blad) {
        # Liczby po dwukropku - bez odmiany liczebnika.
        $zakres = 'kontrolery: {0} z {1}' -f $Wynik.Odpytane, $Wynik.Wszystkie

        # Odpowiedzi byly, ale zadna nie zna logowania.
        if ($null -eq $Wynik.Data) {
            if ($Wynik.Pelna) { return 'nigdy - żaden kontroler nie zna logowania tego konta' }
            return 'brak danych · {0}' -f $zakres
        }

        if (-not $Wynik.Pelna) {
            return 'Najpóźniejsza znana: {0} · {1}' -f (Format-JezykData $Wynik.Data), $zakres
        }
        if ($null -ne $Przyblizona) {
            return 'Dokładna data: {0} · poprzednia data: {1:yyyy-MM-dd HH:mm}' -f (Format-JezykData $Wynik.Data), $Przyblizona
        }
        return 'Dokładna data: {0}' -f (Format-JezykData $Wynik.Data)
    }

    # Uscislenie sie nie odbylo - data przyblizona zostaje, ale nie udaje jego wyniku.
    if ($Nieudane -or $Wynik) {
        if ($null -ne $Przyblizona) {
            return 'Data przybliżona: {0} · nie udało się uściślić' -f (Format-JezykData $Przyblizona)
        }
        return 'brak danych'
    }

    if ($null -ne $Przyblizona) {
        if ($Trwa) { return 'Data przybliżona: {0} precyzowanie{1}' -f (Format-JezykData $Przyblizona), $Kropki }
        return 'Data przybliżona: {0}' -f (Format-JezykData $Przyblizona)
    }

    if ($Trwa) { return 'sprawdzanie' + $Kropki }
    return 'brak danych'
}

# Tresc "!" przy dacie logowania: czego obejscie kontrolerow nie objelo i dlaczego; pusta przy komplecie.
function Get-JezykOpisLogowania {
    param($Wynik, $Przyblizona = $null)

    if (-not $Wynik -or $Wynik.Pelna) { return '' }

    $linie = @()
    if ($Wynik.Blad) {
        $linie += [string]$Wynik.Blad
    }
    elseif ($Wynik.Odpytane -lt $Wynik.Wszystkie) {
        $linie += ('Odpowiedziało {0} z {1} kontrolerów. Logowanie obsłużone przez kontroler, który nie odpowiedział, nie jest tu widoczne - prawdziwa data może być późniejsza.' -f
                   $Wynik.Odpytane, $Wynik.Wszystkie)
    }

    # Podloga: lastLogonTimestamp nowszy od kazdego lastLogon, ktory przyszedl.
    if ($Wynik.ZTimestampu -and $Przyblizona -is [datetime]) {
        $zKontrolerow = if ($Wynik.DataKontrolerow -is [datetime]) {
            '{0:yyyy-MM-dd HH:mm} z {1}' -f $Wynik.DataKontrolerow, $Wynik.ZKontrolera
        } else { 'żaden nie zna logowania' }

        if ($linie.Count) { $linie += '' }
        $linie += ('Data z lastLogonTimestamp ({0:yyyy-MM-dd HH:mm}) jest późniejsza niż lastLogon z kontrolerów, które odpowiedziały ({1}). Logowanie obsłużył kontroler spoza listy albo atrybut odświeżyła usługa działająca w imieniu tego konta - pokazana data pochodzi z lastLogonTimestamp.' -f
                   $Przyblizona, $zKontrolerow)
    }

    if (@($Wynik.Odrzucone).Count) {
        if ($linie.Count) { $linie += '' }
        $linie += ('Pominięte nazwy kontrolerów (nieprawidłowe): {0}' -f (@($Wynik.Odrzucone) -join ', '))
    }

    # Kontroler po kontrolerze - po tym widac, czy to zapora, usluga czy termin.
    $przebieg = @(@($Wynik.Przebieg) | Where-Object { $_ })
    if ($przebieg.Count) {
        $linie += @('', 'Kontroler po kontrolerze (odczyt modułem AD):') + $przebieg
    }
    if ($Wynik.ZKontrolera -and -not $Wynik.ZTimestampu) {
        $linie += @('', ('Najpóźniejszą datę podał: {0}' -f $Wynik.ZKontrolera))
    }
    if ($Wynik.Czasy) {
        $linie += @('', ('Czas: {0}' -f $Wynik.Czasy))
    }

    return ($linie -join [Environment]::NewLine)
}

# Nazwa z SCCM ze stanem sesji: "(zalogowany teraz)", sama data ostatniej aktywnosci albo sama nazwa.
# Bez godziny - LastActiveTime to aktywnosc klienta SCCM, nie logowanie (README: Ostatnio uzywany komputer).
function Get-JezykTekstSesji {
    param([string]$Nazwa, $Data = $null, [bool]$Teraz = $false)

    if ($Teraz)          { return '{0} (zalogowany teraz)' -f $Nazwa }
    if ($null -ne $Data) { return '{0} ({1:yyyy-MM-dd})' -f $Nazwa, $Data }
    return $Nazwa
}

# Oba numery telefonu w jednym napisie: glowny, potem komorkowy, bez podpisow; pusty pomijany.
function Get-JezykTelefony {
    param([string]$Glowny, [string]$Komorkowy)

    return ((@($Glowny, $Komorkowy) | Where-Object { $_ }) -join ', ')
}

# Koloruje kontrolke wedlug ZNACZENIA i zapamietuje role (przezywa zmiane motywu).
# Pole dostaje kolorowe tlo, werdykt (rola wygladu "Okno") - kolorowy napis; nigdy oba.
function Set-JezykKolorPola {
    param($Pole, [ValidateSet('Tekstu', 'Ok', 'Problem', 'Nieznany')][string]$Rola)

    if (-not $Pole) { return }

    $Script:RoleKolorow[$Pole] = $Rola

    if ($Script:KontrolkiMotywu[$Pole] -eq 'Okno') {
        $Pole.BackColor = $Script:Config.KolorOkna
        $Pole.ForeColor = $Script:Config['Kolor' + $Rola]
        return
    }

    $Pole.ForeColor = $Script:Config.KolorTekstu
    $Pole.BackColor = switch ($Rola) {
        'Ok'      { $Script:Config.KolorPolaOk }
        'Problem' { $Script:Config.KolorPolaProblem }
        default   { $Script:Config.KolorTla }
    }
}

# Czysci widok konta do stanu "nic nie wiadomo" - na poczatku kazdego wyniku i przy zmianie trybu.
function Clear-JezykKonto {
    $k = $Script:Kontrolki

    # Wyczyszczony widok nie wie o koncie nic - werdykt mowi to wprost.
    $k.WerdyktBox.Checked   = $false
    $k.Werdykt.Text         = 'Nie sprawdzono'
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

    # Etykieta pierwszego pola wraca na "Login:" (kontakt przestawia ja na "Nazwa:").
    if ($k.EtykietaLoginKonta) { $k.EtykietaLoginKonta.Text = 'Login:' }

    # Adres dopasowania MAC dotyczyl poprzedniej maszyny.
    $Script:MacDlaAdresu = ''

    # Notka SCCM gasnie razem z polami - inaczej zegar wpisywalby kropki do pustego widoku.
    Set-JezykNotkeSprawdzania -Wylacz
    Stop-JezykNotkeKonsoli -Widok Konto

    # Data przyblizona i wynik naleza do poprzedniego konta.
    $Script:LogowaniePrzyblizone = $null
    $Script:OstatnieKonto        = $null

    # Maszyna poprzedniego konta - zostawiona kazalaby "Pinguj" sprawdzac cudzy komputer.
    $Script:OstatniKomputer  = ''
    # Wynik sondy ginie razem z maszyna, ktorej dotyczyl.
    $Script:MaszynaOdpowiada = $null
    if ($k.PrzyciskPinguj) { $k.PrzyciskPinguj.Enabled = $false }
    Set-JezykPrzyciskiZdalne ''

    # Przycisk grup gasnie razem z kontem, ktorego grupy pokazywal.
    Set-JezykPrzyciskGrupy $null

    Set-JezykInfo 'Komputer'              ''
    Set-JezykInfo 'KomputerWspoldzielony' ''
    Set-JezykInfo 'Status'                ''
    Set-JezykInfo 'Logowanie'             ''
    Set-JezykInfo 'LogowanieNiepelne'     ''
    # "!" przy adresie MAC tez nalezy do poprzedniego konta.
    Set-JezykInfo 'Mac'                   ''

    # Zadania w tle gasna razem z widokiem - inaczej spozniony wynik wpisalby sie do cudzego widoku.
    Stop-JezykZadanieLogowania
    Stop-JezykZadanieKomputera
    Stop-JezykZadaniePingu

    # Przycisk gasnie - inaczej odblokowalby konto, ktorego juz nie widac.
    Set-JezykPrzyciskOdblokuj $null

    # Zerowanie koloru jest warunkiem poprawnosci: kolor zostaje na kontrolce po zdjeciu tresci.
    Set-JezykKolorPola $k.TxtHasloWygasa 'Tekstu'
    Set-JezykKolorPola $k.TxtKomputerUzytkownika 'Tekstu'
}

# Wypelnia widok konta z obiektu wyniku: werdykt (wniosek) i znaczniki (fakty zrodlowe).
function Set-JezykResult {
    param($Result)

    $k = $Script:Kontrolki
    Clear-JezykKonto
    $Script:OstatnieKonto = $Result

    # Jedno wywolanie na wszystkie galezie - wynik bez konta niesie pusta liste grup.
    Set-JezykPrzyciskGrupy $Result

    switch ($Result.Status) {

        'Ok' {
            # Blokada i wylaczenie to dwa niezalezne stany (kazdy naprawia sie inaczej).
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
            $k.TxtImieNazwisko.Text = Get-JezykWartoscPola (Get-JezykOsoba ([string]$Result.DisplayName) `
                                                     ([string]$Result.Imie) ([string]$Result.Nazwisko))

            # Brak wartosci mowi o sobie wprost - puste pole wygladaloby na nieudany odczyt.
            $k.TxtEmail.Text = Get-JezykWartoscPola ([string]$Result.Email)

            # Numery przychodza tym samym zapytaniem - pustka znaczy tylko "nie wpisano w AD".
            $telefony = Get-JezykTelefony ([string]$Result.TelefonGlowny) ([string]$Result.TelefonKomorkowy)
            $k.TxtTelefon.Text  = if ($telefony) { $telefony } else { 'nie wpisano w AD' }

            # Przelozony: pustka znaczy tylko "nie wpisano w AD" (nierozwiazany DN spada do CN).
            $k.TxtMenedzer.Text = if ($Result.Menedzer) { [string]$Result.Menedzer } else { 'nie wpisano w AD' }

            # Trzy stany hasla, kazdy znaczy co innego dla osoby przy telefonie.
            if     ($Result.ZmianaHaslaWymuszona) { $k.TxtHasloWygasa.Text = 'nie dotyczy (zmiana wymagana)' }
            elseif ($Result.HasloNigdyNieWygasa)  { $k.TxtHasloWygasa.Text = 'nigdy' }
            else                                  { $k.TxtHasloWygasa.Text = Format-JezykData $Result.HasloWygasa }

            # Czerwien tylko wtedy, gdy termin naprawde minal.
            if ($Result.HasloWygasa -and $Result.HasloWygasa -lt (Get-Date)) {
                Set-JezykKolorPola $k.TxtHasloWygasa 'Problem'
            }

            $k.TxtKontoWygasa.Text    = Format-JezykData $Result.KontoWygasa 'nigdy'
            $k.TxtOstatniaZmiana.Text = Format-JezykData $Result.OstatniaZmianaHasla 'nigdy nie ustawiono'
            $k.TxtKontoUtworzono.Text = Format-JezykData $Result.KontoUtworzono

            # Dwa niezalezne zadania w tle: data przyblizona od razu (tlo ja uscisli), komputer czeka na SCCM.
            # Komputer tylko w domenie znanej SCCM - poza nia jego pola sa schowane.
            $zSccm = Test-JezykDomenaZSccm $Script:Config.Domena
            $Script:LogowaniePrzyblizone   = $Result.OstatnieLogowaniePrzyblizone
            Set-JezykNotkeSprawdzania -Notka $(if ($zSccm) { 'Obie' } else { 'Logowanie' })
            Set-JezykInfo 'Komputer'              ''
            Set-JezykInfo 'KomputerWspoldzielony' ''
            Start-JezykZadanieLogowania -Login ([string]$Result.Login) -Dn ([string]$Result.Dn) `
                                        -Przyblizona $Result.OstatnieLogowaniePrzyblizone
            if ($zSccm) { Start-JezykZadanieKomputera -Login ([string]$Result.Login) }

            # Lokalizacja z CanonicalName - pustka znaczy "nie udalo sie ustalic".
            $k.TxtKatalog.Text = Get-JezykWartoscPola ([string]$Result.Lokalizacja) 'brak danych'

            # Czas blokady tylko przy aktywnej blokadzie - AD nie zeruje LockoutTime po jej wygasnieciu.
            $status = [string]$Result.Message
            if ($zablokowane -and $Result.LockoutTime) {
                $status = '{0} Blokada od {1:yyyy-MM-dd HH:mm}.' -f $status, $Result.LockoutTime
            }
            $k.TxtStatus.Text = $status.Trim()
        }

        'Kontakt' {
            # Kontakt nie ma stanu konta - werdykt nazywa rodzaj pozycji, kolor neutralny.
            $k.WerdyktBox.Checked = $false
            $k.Werdykt.Text       = 'Pozycja typu Kontakt - to nie jest konto'
            Set-JezykKolorPola $k.Werdykt 'Nieznany'

            $k.TxtImieNazwisko.Text = Get-JezykWartoscPola (Get-JezykOsoba ([string]$Result.DisplayName) `
                                                     ([string]$Result.Imie) ([string]$Result.Nazwisko))
            $k.TxtEmail.Text          = Get-JezykWartoscPola ([string]$Result.Email)
            $telefonyKontaktu = Get-JezykTelefony ([string]$Result.TelefonGlowny) ([string]$Result.TelefonKomorkowy)
            $k.TxtTelefon.Text        = if ($telefonyKontaktu) { $telefonyKontaktu } else { 'nie wpisano w AD' }
            $k.TxtKontoUtworzono.Text = Format-JezykData $Result.KontoUtworzono
            $k.TxtKatalog.Text        = Get-JezykWartoscPola ([string]$Result.Lokalizacja) 'brak danych'
            $k.TxtStatus.Text         = [string]$Result.Message

            # Kontakt nie ma loginu - pierwsze pole pokazuje nazwe obiektu (cn), etykieta idzie za trescia.
            if ($k.EtykietaLoginKonta) { $k.EtykietaLoginKonta.Text = 'Nazwa:' }
            $k.TxtLoginKonta.Text = [string]$Result.NazwaObiektu

            # Pola, ktorych kontakt nie posiada: "nie dotyczy", a nie pustka (telefon kontakt miec moze).
            foreach ($pole in @($k.TxtHasloWygasa, $k.TxtKontoWygasa,
                                $k.TxtOstatniaZmiana, $k.TxtMenedzer,
                                $k.TxtOstatnieLogowanie, $k.TxtKomputerUzytkownika,
                                $k.TxtKomputerIp, $k.TxtKomputerMac)) {
                if ($pole) { $pole.Text = 'nie dotyczy (kontakt)' }
            }

            # Kontakt: zadnych zadan w tle - nie loguje sie i nie ma go w SCCM.
        }

        'NotFound' { $k.Werdykt.Text = 'Nie znaleziono konta'; $k.TxtStatus.Text = [string]$Result.Message }

        'Empty'    { $k.Werdykt.Text = 'Nie sprawdzono';       $k.TxtStatus.Text = [string]$Result.Message }

        # Galaz domyslna to Status = 'Error'; sam powod trafia do statusu.
        default    { $k.Werdykt.Text = 'Błąd sprawdzenia';     $k.TxtStatus.Text = [string]$Result.Message }
    }

    # Pelna tresc bledu pod "!" przy Status - wylacznie przy stanie problemowym.
    $problem = ($Result.Status -notin 'Ok', 'Kontakt', 'Empty')
    Set-JezykInfo 'Status' $(if ($problem) { [string]$Result.Szczegoly } else { '' })

    # Poza switch-em - przycisk przeliczany przy kazdym stanie.
    Set-JezykPrzyciskOdblokuj $Result
}

# Czysci widok komputera do stanu "nic nie wiadomo" i porzuca jego zadania w tle.
function Clear-JezykKomputer {
    $k = $Script:Kontrolki

    Stop-JezykZadanieUzytkownika
    Stop-JezykZadaniePingu
    # Laczenie z udzialem nalezy do tej maszyny.
    Stop-JezykZadanieDysku

    foreach ($pole in @($k.TxtKomputerKatalog, $k.TxtKomputerUzytkownikMaszyny,
                        $k.TxtKomputerTworca, $k.TxtKomputerWlaczone, $k.TxtKomputerStatus,
                        $k.TxtKomputerIpMaszyny, $k.TxtKomputerMacMaszyny)) {
        if ($pole) { $pole.Text = '' }
    }

    # Pola czyscimy wprost, wiec markery kropek (SCCM, laczenie, konsola) gasimy osobno.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz
    Set-JezykNotkeLaczenia -Wylacz
    Stop-JezykNotkeKonsoli -Widok Maszyna

    # Pole kolorowane czysci sie z tresci i z koloru (takze adres IP z kolorem sondy).
    foreach ($pole in @($k.TxtKomputerWlaczone, $k.TxtKomputerIpMaszyny)) {
        Set-JezykKolorPola $pole 'Tekstu'
    }

    # Maszyna zapomniana razem z polami - to ona steruje przyciskami, nie pole tekstowe.
    $Script:OstatniKomputer  = ''
    $Script:MacDlaAdresu     = ''
    # Wynik sondy ginie razem z maszyna.
    $Script:MaszynaOdpowiada = $null
    if ($k.PrzyciskPingujMaszyny) { $k.PrzyciskPingujMaszyny.Enabled = $false }
    # "Polacz" i "Dyski" gasi jedno miejsce z warunkiem - patrz Set-JezykPrzyciskiZdalne.
    Set-JezykPrzyciskiZdalne '' -Widok Maszyna

    Set-JezykInfo 'Uzytkownik' ''
    Set-JezykInfo 'Tworca' ''
    Set-JezykInfo 'MacMaszyny' ''
    Set-JezykInfo 'StatusMaszyny' ''
}

# Tresc pola "Dodany do AD przez": podpis wlasciciela i data zalozenia; pusty podpis = nie ustalono.
function Get-JezykOpisTworcy {
    param($Podpis, $Utworzono)

    $tekst = [string]$Podpis
    if (-not $tekst) { $tekst = 'nie udało się ustalić' }

    if ($null -ne $Utworzono) { $tekst = '{0} · {1}' -f $tekst, (Format-JezykData $Utworzono) }

    $tekst
}

# Wypelnia widok komputera: katalog i tworca z AD od razu, uzytkownik z SCCM w tle.
function Set-JezykComputerResult {
    param($Result)

    $k = $Script:Kontrolki
    Clear-JezykKomputer

    if ($Result.Status -eq 'Ok') {
        $k.TxtKomputerKatalog.Text = Get-JezykWartoscPola ([string]$Result.Lokalizacja) 'brak danych'

        # Nazwa z AD, nie z pola tekstowego - idzie do WQL i do zdalnej konsoli.
        $Script:OstatniKomputer = [string]$Result.Nazwa
        if ($k.PrzyciskPingujMaszyny) {
            $k.PrzyciskPingujMaszyny.Enabled = [bool]$Script:OstatniKomputer
        }
        # "Polacz" i "Dyski" czekaja na sonde - tu stan "jeszcze nie wiadomo".
        Set-JezykPrzyciskiZdalne $Script:OstatniKomputer -Widok Maszyna

        # Zapytanie o uzytkownika i sonda tylko w domenie znanej SCCM.
        if (Test-JezykDomenaZSccm $Script:Config.Domena) {
            # Kropki - trzy pola czekaja na to samo zapytanie.
            Set-JezykNotkeSprawdzania -Notka 'Sccm'
            Start-JezykZadanieUzytkownika -Netbios ([string]$Result.Nazwa)

            # Zadanie SCCM bywa nieuruchomione (brak ustawien) - wtedy sonda zapasowa.
            if (-not $Script:ZadanieUzytkownika) { Invoke-JezykPing -Widok Maszyna }
        }

        if ($k.TxtKomputerTworca) {
            $k.TxtKomputerTworca.Text = Get-JezykOpisTworcy $Result.Tworca $Result.Utworzono
        }

        # Trzy stany, trzy kolory: "nie wiadomo" dostaje kolor neutralny.
        if ($k.TxtKomputerWlaczone) {
            $k.TxtKomputerWlaczone.Text = if ($null -eq $Result.Wlaczone) { 'Nie wiadomo' }
                                          elseif ($Result.Wlaczone)      { 'Włączone' }
                                          else                           { 'Wyłączone - ta maszyna nie zaloguje się do domeny' }

            $rolaWlaczone = if ($null -eq $Result.Wlaczone) { 'Tekstu' }
                            elseif ($Result.Wlaczone)      { 'Ok' }
                            else                           { 'Problem' }
            Set-JezykKolorPola $k.TxtKomputerWlaczone $rolaWlaczone
        }

        # "!" tylko gdy pole nie nazywa osoby: $false grupa albo SID, $null deskryptor nieodczytany.
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

# Wypelnia liste trafien calymi obiektami (DisplayMember pokazuje opis).
# Blokada zdarzen - kazde dodanie pozycji wywoluje SelectedIndexChanged.
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

# Wybor pozycji z listy: pelny odczyt jednej pozycji - konta po loginie, kontaktu po DN.
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

# Obsluga "Szukaj": jedyne miejsce, w ktorym tryb przeklada sie na funkcje logiki.
# Przycisk wylaczony na czas zapytania; finally przywraca go takze po bledzie.
function Invoke-JezykSearch {
    $k    = $Script:Kontrolki
    $okno = $k.Okno
    $tryb = [string]$k.Tryb.SelectedItem
    $tekst = $k.PoleSzukaj.Text

    # Poprzednie szukanie po numerze porzucane ZAWSZE i przed rozgalezieniem na tryb.
    Stop-JezykZadanieNumeru

    $k.Przycisk.Enabled = $false
    $okno.UseWaitCursor = $true

    # Jez przy kazdym szukaniu; przy zapytaniu synchronicznym stoi nieruchomo (README: Praca w tle).
    Set-JezykStanJeza 'Szuka'

    # Domyslnie "nie znaleziono" - finally biegnie takze po wyjatku.
    $znaleziono = $false

    # Pole Status niesie na razie odpowiedz, a nie notke o trwajacym szukaniu - patrz nizej.
    $Script:StatusCzekaNaNumer = $false

    # Przerysowanie teraz - inaczej kursor i jez pojawilyby sie dopiero po zapytaniu.
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
                # Zaznaczenie odpala Invoke-JezykWyborKonta - pierwsza pozycja pokazuje sie od razu.
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

            # Numer telefonu rusza na koncu, po zaznaczeniu - Set-JezykResult nadpisuje pole Status.
            # Rusza takze wtedy, gdy po nazwie nic nie znaleziono.
            if (Test-JezykWygladaNaTelefon $tekst) {
                Start-JezykZadanieNumeru -Cyfry (Get-JezykCyfry $tekst)

                # Notka zastepuje zdanie, ktore przestalo byc prawda - wylacznie przy 'NotFound'
                # i tylko gdy zadanie naprawde ruszylo (README: Wyszukiwanie po numerze telefonu).
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

        # Jez staje z wynikiem, chyba ze biegnie zadanie numeru; poza zostaje do nastepnego szukania.
        if (-not $Script:ZadanieNumeru) {
            # Uwaga: przez zmienna - "Polecenie (if ...)" nie jest poprawne w Windows PowerShell 5.1.
            $stan = if ($znaleziono) { 'Jablko' } else { 'NaPlecach' }
            Set-JezykStanJeza $stan
        }
    }
}

# "Odblokuj konto": domena decyduje o widocznosci, konto (znalezione i zablokowane) o dostepnosci.
# Bez "!" - to normalne stany, nie bledy.
function Set-JezykPrzyciskOdblokuj {
    param($Result)

    $przycisk = $Script:Kontrolki.PrzyciskOdblokuj
    if (-not $przycisk) { return }

    $wolno = Test-JezykWolnoOdblokowac $Script:Config.Domena

    $przycisk.Visible = $wolno
    $przycisk.Enabled = (
        $wolno -and
        $Result -and $Result.Status -eq 'Ok' -and [bool]$Result.LockedOut
    )
}

# Obsluga "Odblokuj konto": okno logowania = potwierdzenie; poswiadczenia gina z wywolaniem.
function Invoke-JezykOdblokowanie {
    $k      = $Script:Kontrolki
    $domena = $Script:Config.Domena

    # Login z obiektu wyniku, nie z kontrolki - zrodlem prawdy jest ostatni odczyt z AD.
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

        # Niepowodzenie: powod odmowy zostaje na ekranie.
        if (-not $wynik.Udane) {
            $k.TxtStatus.Text = $wynik.Komunikat
            Set-JezykInfo 'Status' ([string]$wynik.Szczegoly)
            return
        }

        # Odswiezenie przed komunikatem (Clear-JezykKonto czysci Status), z kontrolera, ktory przyjal zapis.
        $poZapisie = Get-JezykUserStatus -Login $login -Serwer ([string]$wynik.Serwer)
        Set-JezykResult -Result $poZapisie

        $status     = [string]$wynik.Komunikat
        $tresc      = @([string]$wynik.Komunikat)
        $ikona      = [System.Windows.Forms.MessageBoxIcon]::Information
        # Domyslnie puste - "!" tylko w dwoch galeziach ponizej, gdy cos nie poszlo jak trzeba.
        $infoStatus = ''

        if ($poZapisie.Status -ne 'Ok') {
            # Zapis sie udal, odczyt nie - powod odczytu nie moze zginac.
            $status = '{0} Ponowny odczyt konta: {1}' -f $status, $poZapisie.Message
            $tresc += @('', ('Zapis się powiódł, ale ponowny odczyt konta zawiódł: {0}' -f $poZapisie.Message))
            $ikona  = [System.Windows.Forms.MessageBoxIcon]::Warning
            $infoStatus = [string]$wynik.Szczegoly
        }
        elseif ($poZapisie.LockedOut) {
            # Kontroler, ktory przyjal zapis, znow widzi blokade - blokada od nowa, nie replikacja.
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

        # Komunikat na koncu - po jego zamknieciu widac stan PO operacji.
        [void][System.Windows.Forms.MessageBox]::Show(
            ($tresc -join [Environment]::NewLine),
            $Script:Config.TytulOkna,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            $ikona)
    }
    finally {
        # Haslo niszczone (Dispose), a nie tylko zapominane - okno bywa otwarte godzinami.
        if ($poswiadczenia) {
            try { $poswiadczenia.Password.Dispose() } catch { }
        }
        $poswiadczenia = $null
    }
}

# Zamyka pole daty bez wyniku uscislenia: data przyblizona zostaje, znika "precyzowanie...".
# Z powodem (awaria zadania) pole i "!" mowia wprost, ze uscislenie sie nie odbylo.
function Set-JezykPoleLogowaniaBezTla {
    param([string]$Blad = '')
    Set-JezykNotkeSprawdzania -Notka 'Logowanie' -Wylacz

    Set-JezykInfo 'Logowanie' $(if ($Blad) { 'Uściślenie daty nie doszło do skutku: {0}' -f $Blad } else { '' })
    Set-JezykInfo 'LogowanieNiepelne' ''

    $k = $Script:Kontrolki
    if (-not $k.TxtOstatnieLogowanie) { return }
    $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Przyblizona $Script:LogowaniePrzyblizone `
                                                           -Nieudane:([bool]$Blad)
}

# Zamyka pole komputera po nieudanym zapytaniu SCCM; dostepnosc maszyny gasnie razem z nim.
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

# Kontrolki sondy wskazanego panelu - widok podawany jawnie, nie odczytywany z listy trybu.
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

# Jedyne miejsce decyzji o kolorze dostepnosci (trzy stany) i o adresie IP w polu.
function Set-JezykDostepnoscKomputera {
    param($Odpowiada, [string]$Adres, [string]$Opis = '',
          [ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $pola = Get-JezykPolaSondy -Widok $Widok
    if (-not $pola.Kolor) { return }

    $rolaSondy = if ($null -eq $Odpowiada) { 'Tekstu' }
                 elseif ($Odpowiada)       { 'Ok' }
                 else                      { 'Problem' }
    Set-JezykKolorPola $pola.Kolor $rolaSondy

    if ($pola.Ip) {
        $pola.Ip.Text = if ($Adres) { $Adres }
                        elseif ($Opis) { $Opis }
                        else { 'nie sprawdzono' }
    }

    # Odpowiedz sondy odkladana tu - jedyny punkt widzacy wszystkie stany obu widokow.
    $Script:MaszynaOdpowiada = $Odpowiada
    Set-JezykPrzyciskiZdalne $Script:OstatniKomputer -Widok $Widok
}

# Tresc "!" przy adresie MAC skladana z danych: dopasowanie po podsieci albo lista kart z adresem.
function Get-JezykTrescMac {
    param($Wynik)

    if (-not $Wynik) { return '' }

    $powodTwardy = [string]$Wynik.MacSzczegoly
    if ($powodTwardy) { return $powodTwardy }

    $podstawa = [string]$Wynik.MacPodstawa
    if (-not $podstawa -or $podstawa -eq 'Adres') { return '' }

    $adresSondy = [string]$Wynik.Adres
    # @() wokol potoku, nie zmiennej - @($null).Count to 1.
    $karty  = @(@($Wynik.MacKarty) | Where-Object { $_ })
    $wpisow = [int]$Wynik.MacWpisow
    $linie  = @()

    # Bez trafionej karty zdanie o dopasowaniu powstaloby z pustym adresem.
    $trafiona = $Wynik.MacKarta
    if ($podstawa -eq 'Podsiec' -and $trafiona) {
        $oMasce = if ($trafiona.MaskaZSccm) { 'maska {0} z inwentaryzacji' -f $trafiona.Maska }
                  else { 'maski SCCM nie podał, przyjęto {0}' -f $trafiona.Maska }

        $linie += 'Pokazany adres MAC nie jest dokładnym trafieniem.'
        $linie += ''
        $linie += (('Sonda zastała maszynę pod adresem {0}. Tego adresu nie ma żadna karta znana ' +
                    'SCCM, ale karta {1} ma zapisany adres {2} z tej samej podsieci ({3}) - maszyna ' +
                    'odpowiada więc przez tę kartę, choć zapisany adres jest starszy niż bieżąca ' +
                    'dzierżawa DHCP.') -f $adresSondy, $trafiona.Mac, $trafiona.Adres, $oMasce)
        if ($trafiona.Opis) {
            $linie += ''
            $linie += ('Karta: {0}' -f $trafiona.Opis)
        }

        return ($linie -join [Environment]::NewLine)
    }

    if ($wpisow -eq 0) {
        return ('SCCM nie zna żadnej karty sieciowej tej maszyny. Klasa ' +
                'SMS_G_System_NETWORK_ADAPTER_CONFIGURATION bywa wyłączona w ustawieniach ' +
                'inwentaryzacji sprzętu.')
    }

    $linie += if ($podstawa -eq 'Wiele') {
        (('Sonda zastała maszynę pod adresem {0}. Tego adresu nie ma żadna karta znana SCCM, ' +
          'a adres z jego podsieci ma więcej niż jedna karta - która z nich odpowiada, nie ' +
          'wiadomo, więc pole nie pokazuje żadnej.') -f $adresSondy)
    } else {
        (('Sonda zastała maszynę pod adresem {0}. Żadna karta znana SCCM nie ma tego adresu ' +
          'ani adresu z jego podsieci. Inwentaryzacja sprzętu bywa starsza niż bieżąca ' +
          'dzierżawa DHCP.') -f $adresSondy)
    }

    $linie += ''
    if ($karty.Count) {
        $linie += 'Karty z zapisanym adresem IPv4:'
        foreach ($karta in $karty) {
            $zapisy = @()
            foreach ($wpis in @($karta.Adresy)) {
                $zapisy += if ($wpis.MaskaZSccm) { '{0} / {1}' -f $wpis.Adres, $wpis.Maska }
                           else { [string]$wpis.Adres }
            }

            $wiersz = '  {0}   {1}' -f $karta.Mac, ($zapisy -join ', ')
            if ($karta.Opis) { $wiersz = '{0}   {1}' -f $wiersz, $karta.Opis }
            $linie += $wiersz
        }
    }
    else {
        $linie += 'Żadna karta znana SCCM nie ma zapisanego adresu IPv4.'
    }

    # Liczby po dwukropku - bez odmiany liczebnika.
    $linie += ''
    $linie += ('Wiersze inwentaryzacji: {0}.' -f $wpisow)
    if (($wpisow - $karty.Count) -gt 0) {
        $linie += (('Wpisy bez zapisanego adresu IPv4: {0} - tunele, karty wirtualne i karty ' +
                    'wyłączone w chwili inwentaryzacji.') -f ($wpisow - $karty.Count))
    }

    return ($linie -join [Environment]::NewLine)
}

# Pole "Adres MAC" i jego "!": tresc wedlug podstawy dopasowania; MAC z podsieci oznaczony w polu.
function Set-JezykAdresMac {
    param([string]$Mac, [string]$Szczegoly,
          [ValidateSet('', 'Adres', 'Podsiec', 'Wiele', 'Brak')][string]$Podstawa = '',
          [ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $pola = Get-JezykPolaSondy -Widok $Widok
    if ($pola.Mac) {
        $pola.Mac.Text = if ($Mac -and $Podstawa -eq 'Podsiec') { $Mac + ' (ta podsieć)' }
                         elseif ($Mac) { $Mac }
                         elseif ($Podstawa -or $Szczegoly) { 'nie dopasowano' }
                         else { 'nie sprawdzono' }
    }

    Set-JezykInfo $pola.KluczMac $Szczegoly
}

# Zapala i gasi notki "sprawdzanie" (SCCM i logowanie - dwa niezalezne zadania, wspolny licznik).
# -Wylacz nie rusza tresci pol: wolajacy wpisuje zaraz wartosc prawdziwa.
function Set-JezykNotkeSprawdzania {
    param([ValidateSet('Obie', 'Sccm', 'Logowanie')][string]$Notka = 'Obie', [switch]$Wylacz)

    $stan = -not $Wylacz
    if ($Notka -ne 'Logowanie') { $Script:PolaCzekajaNaSccm    = $stan }
    if ($Notka -ne 'Sccm')      { $Script:PoleCzekaNaLogowanie = $stan }

    if ($Wylacz) { return }

    # Licznik zerowany tylko przy zapalaniu - zgaszenie jednej notki nie cofa kropek drugiej.
    $Script:KlatkaKropek = 0

    # Pierwsza klatka od razu - zapytanie bywa krotsze niz takt zegara.
    Update-JezykKropkiSprawdzania
}

# Notka "Łączenie" w polu Status: widoku komputera - zapamietuje zakryte zdanie (tylko za pierwszym razem).
function Set-JezykNotkeLaczenia {
    param([switch]$Wylacz)

    if ($Wylacz) {
        $Script:StatusCzekaNaDysk = $false
        return
    }

    # Notka konsoli oddaje pole z potwierdzeniem - inaczej zapamietalibysmy jej kropki.
    if ($Script:NotkaKonsoli -and $Script:NotkaKonsoli.Widok -eq 'Maszyna') { Update-JezykNotkeKonsoli -Teraz }

    $pole = $Script:Kontrolki.TxtKomputerStatus
    if (-not $Script:StatusCzekaNaDysk) {
        $Script:StatusPrzedLaczeniem = if ($pole) { [string]$pole.Text } else { '' }
    }

    $Script:StatusCzekaNaDysk = $true

    # Licznik klatek wspolny z notka sprawdzania - kropki ida rownym krokiem.
    $Script:KlatkaKropek = 0

    # Pierwsza klatka od razu - polaczenie bywa krotsze niz takt zegara.
    Update-JezykKropkiSprawdzania
}

# Notka "Trwa laczenie z NAZWA" po "Polacz" - w polu Status: tego widoku, z ktorego kliknieto.
# Poprzednia notka konsoli konczy sie najpierw, a pierwsza klatka jest odrysowana od razu.
function Set-JezykNotkeKonsoli {
    param([ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto',
          $Pole, [string]$Klucz, [string]$Netbios)

    Update-JezykNotkeKonsoli -Teraz

    # Napis rowny obecnej tresci - pierwsza klatka rozpoznaje pole jako swoje.
    $Script:NotkaKonsoli = [pscustomobject]@{
        Widok   = $Widok
        Pole    = $Pole
        Klucz   = $Klucz
        Netbios = $Netbios
        Napis   = if ($Pole) { [string]$Pole.Text } else { '' }
        Proces  = $null
        Termin  = (Get-Date).AddSeconds($Script:TerminNotkiKonsoli)
    }

    $Script:KlatkaKropek = 0
    Update-JezykKropkiSprawdzania

    # Uruchomienie z udzialu zajmuje watek okna - bez odrysowania notka pokazalaby sie po fakcie.
    if ($Pole -and $Pole.PSObject.Methods['Refresh']) { $Pole.Refresh() }
}

# Gasi notke konsoli bez ruszania pola (wolajacy wpisuje wartosc sam); z -Widok tylko notke tego widoku.
function Stop-JezykNotkeKonsoli {
    param([ValidateSet('', 'Konto', 'Maszyna')][string]$Widok = '')

    $notka = $Script:NotkaKonsoli
    if (-not $notka) { return }
    if ($Widok -and $notka.Widok -ne $Widok) { return }

    $Script:NotkaKonsoli = $null

    # Zwalnia tylko uchwyt - konsola biegnie dalej sama.
    if ($notka.Proces) { try { $notka.Proces.Dispose() } catch { } }
}

# Konczy notke konsoli, gdy konsola pokazala okno, zamknela sie albo minal termin (-Teraz - od razu).
# Wynik trafia do pola tylko wtedy, gdy pole nadal niesie notke; puste szczegoly gasza "!".
function Update-JezykNotkeKonsoli {
    param([switch]$Teraz)

    $notka = $Script:NotkaKonsoli
    if (-not $notka) { return }

    $stan = Get-JezykStanKonsoli -Proces $notka.Proces -Netbios $notka.Netbios `
                                 -Sciezka ([string]$Script:Ustawienia.SciezkaRemoteControl)
    if ($stan.Stan -eq 'Czeka' -and -not $Teraz -and (Get-Date) -lt $notka.Termin) { return }

    # Obcy napis w polu to nowsza wiadomosc - zostaje.
    $swoje = ($notka.Pole -and [string]$notka.Pole.Text -eq $notka.Napis)
    Stop-JezykNotkeKonsoli
    if (-not $swoje) { return }

    $notka.Pole.Text = [string]$stan.Komunikat
    Set-JezykInfo $notka.Klucz ([string]$stan.Szczegoly)
}

# Klatka kropek w polach czekajacych na tlo; bez wlasnego zegara - takt ZegarTla, klatka co 500 ms.
# Zgaszony marker zatrzymuje wszystko - odpowiedz z tego samego taktu ma ostatnie slowo.
function Update-JezykKropkiSprawdzania {
    if (-not $Script:PolaCzekajaNaSccm -and -not $Script:PoleCzekaNaLogowanie -and
        -not $Script:StatusCzekaNaDysk -and -not $Script:OknoSprawdzaniaGrupy -and
        -not $Script:NotkaKonsoli) { return }

    $klatka = [int][math]::Floor($Script:KlatkaKropek / $Script:TaktowNaKlatkeKropek)
    $kropki = '.' * (1 + ($klatka % 3))
    $Script:KlatkaKropek++

    $k = $Script:Kontrolki

    # Szesc pol (oba widoki) - zadania "Komputer" i "Uzytkownik" nigdy nie biegna naraz.
    if ($Script:PolaCzekajaNaSccm) {
        foreach ($pole in @($k.TxtKomputerUzytkownika, $k.TxtKomputerIp, $k.TxtKomputerMac,
                            $k.TxtKomputerUzytkownikMaszyny, $k.TxtKomputerIpMaszyny,
                            $k.TxtKomputerMacMaszyny)) {
            if ($pole) { $pole.Text = 'sprawdzanie' + $kropki }
        }
    }

    # Notka logowania jest dopiskiem do daty przyblizonej, nie zamiast niej.
    if ($Script:PoleCzekaNaLogowanie -and $k.TxtOstatnieLogowanie) {
        $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Przyblizona $Script:LogowaniePrzyblizone `
                                                               -Trwa -Kropki $kropki
    }

    # Notka konsoli ustepuje, gdy pole zapisal ktos inny; stoi PRZED laczeniem - "Dyski" wygrywa.
    if ($Script:NotkaKonsoli) {
        $notka = $Script:NotkaKonsoli
        if (-not $notka.Pole -or [string]$notka.Pole.Text -ne $notka.Napis) {
            Stop-JezykNotkeKonsoli
        }
        else {
            $notka.Napis     = 'Trwa łączenie z {0}{1}' -f $notka.Netbios, $kropki
            $notka.Pole.Text = $notka.Napis
        }
    }

    # Notka laczenia - tylko pole Status: widoku komputera (zakrywa zdanie do odtworzenia).
    if ($Script:StatusCzekaNaDysk -and $k.TxtKomputerStatus) {
        $k.TxtKomputerStatus.Text = 'Łączenie' + $kropki
    }

    # Notka "Sprawdz nazwy" - pole Status okna grup (okno na zadanie, poza rejestrem kontrolek).
    if ($Script:OknoSprawdzaniaGrupy) {
        $stan = $Script:OknoSprawdzaniaGrupy.Tag
        if ($stan -and $stan.Notka) { $stan.Notka.Text = 'Sprawdzanie' + $kropki }
    }
}

# Obsluga "Pinguj": sonda maszyny z ekranu (nazwa z pamieci, nie z pola tekstowego).
function Invoke-JezykPing {
    param([ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    if (-not $Script:OstatniKomputer) { return }

    # Widok zamawiajacy odkladamy teraz - odpowiedz z tla nie wie, kto ja zamowil.
    $Script:WidokSondy = $Widok

    $pola = Get-JezykPolaSondy -Widok $Widok
    # Napis statyczny - marker kropek gasilby odpowiedzi zadania SCCM.
    if ($pola.Ip)    { $pola.Ip.Text = 'sprawdzanie...' }
    Set-JezykKolorPola $pola.Kolor 'Tekstu'

    # W tle - rozwiazanie nazwy i sonda to do 1,5 s zamrozonego okna.
    Start-JezykZadaniePingu -Netbios $Script:OstatniKomputer
}

# Wynik sondy z przycisku "Pinguj": kolor dostepnosci i adres IP; inny adres uniewaznia pokazany MAC.
function Update-JezykPingWTle {
    param($Ping)

    # Widok bierzemy z markera odlozonego przy zamawianiu sondy - patrz Invoke-JezykPing.
    $widok = if ($Script:WidokSondy) { $Script:WidokSondy } else { 'Konto' }

    Set-JezykDostepnoscKomputera -Odpowiada $Ping.Odpowiada `
                                 -Adres ([string]$Ping.Adres) `
                                 -Opis ([string]$Ping.Blad) `
                                 -Widok $widok

    # MAC opisuje karte spod konkretnego adresu - inny adres uniewaznia pokazany MAC.
    $adres = [string]$Ping.Adres
    if ($Script:MacDlaAdresu -and $adres -and $adres -ne $Script:MacDlaAdresu) {
        Set-JezykAdresMac -Widok $widok -Mac '' -Podstawa 'Brak' -Szczegoly (
            'Maszyna odpowiada teraz spod adresu {0}, a pokazany wcześniej adres MAC opisywał kartę spod {1}. Nowego dopasowania sonda nie zna - zna je wyłącznie SCCM, więc wyszukaj ponownie.' -f
                $adres, $Script:MacDlaAdresu)
        $Script:MacDlaAdresu = ''
    }
}

# To samo po drugiej stronie okna: zamyka pole uzytkownika maszyny w widoku komputera.
function Set-JezykPoleUzytkownikaBezTla {
    param([string]$Blad)
    # Marker gasnie przed czymkolwiek innym, w kazdej galezi.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownikMaszyny) { return }
    $k.TxtKomputerUzytkownikMaszyny.Text = 'nie sprawdzono'
    Set-JezykDostepnoscKomputera -Odpowiada $null -Adres '' -Widok Maszyna
    Set-JezykAdresMac -Mac '' -Szczegoly '' -Widok Maszyna
    Set-JezykInfo 'Uzytkownik' $Blad
}

# Odklada tresc pod "!" przy polu i pokazuje przycisk tylko wtedy, gdy jest co pokazac.
function Set-JezykInfo {
    param([string]$Klucz, [string]$Tekst)

    $Script:Informacje[$Klucz] = $Tekst

    $przycisk = $Script:Kontrolki['Info' + $Klucz]
    if (-not $przycisk) { return }

    # Status pokazuje "!" takze dla samego sladu zamulen tla.
    $jest = [bool]$Tekst
    if ($Klucz -eq 'Status' -and (Test-JezykJestDiagnostyka)) { $jest = $true }

    $przycisk.Visible = $jest
}

# Czy slad zamulen tla nie jest pusty? (@($null).Count to 1, a zmienna powstaje w czesci 4.)
function Test-JezykJestDiagnostyka {
    if (-not $Script:DiagnostykaTla) { return $false }
    return (@($Script:DiagnostykaTla).Count -gt 0)
}

# Pokazuje tresc spod "!" (klikniecie przycisku); przy Status dokleja slad zamulen tla.
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

# Wynik obejscia kontrolerow do pola daty i jego "!"; domena z uchwytu zadania, nie z biezacego wyboru.
function Update-JezykLogowanieWTle {
    param($Logowanie, [string]$Domena = '')

    # Wynik przyszedl - slowo "precyzowanie" przestaje byc prawdziwe.
    Set-JezykNotkeSprawdzania -Notka 'Logowanie' -Wylacz

    $k = $Script:Kontrolki

    # Lista kontrolerow zapamietywana per domena dla nastepnych zadan.
    if ($Domena -and @($Logowanie.Kontrolery).Count -gt 0) {
        $Script:KontroleryCache[$Domena] = @($Logowanie.Kontrolery)
    }

    # Niepelne pokrycie mowi o sobie w samym polu i pod jego "!" - nie w cudzym polu Status.
    $k.TxtOstatnieLogowanie.Text = Get-JezykTekstLogowania -Wynik $Logowanie `
                                                           -Przyblizona $Script:LogowaniePrzyblizone
    # Czerwony tylko gdy uscislenie nie doszlo do skutku; niepelne pokrycie - niebieski. Nigdy oba.
    $opis = Get-JezykOpisLogowania -Wynik $Logowanie -Przyblizona $Script:LogowaniePrzyblizone
    Set-JezykInfo 'Logowanie'         $(if ($Logowanie.Blad) { $opis } else { '' })
    Set-JezykInfo 'LogowanieNiepelne' $(if ($Logowanie.Blad) { '' } else { $opis })

    # Odrzucona nazwa kontrolera to usterka konfiguracji, nie sieci - dopisek w Status.
    if (@($Logowanie.Odrzucone).Count -gt 0 -and $k.TxtStatus.Text -notmatch 'Pominięte') {
        $k.TxtStatus.Text = ('{0} Pominięte nazwy kontrolerów: {1}.' -f
                             $k.TxtStatus.Text, (@($Logowanie.Odrzucone) -join ', ')).Trim()
    }
}

# Wynik SCCM do pola "Ostatnio zalogowany uzytkownik" w widoku komputera; "!" tylko przy bledzie.
function Update-JezykUzytkownikaWTle {
    param($Uzytkownik)

    # Marker gasnie przed wpisaniem odpowiedzi - inaczej nastepny takt nadpisalby ja kropkami.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

    $k = $Script:Kontrolki
    if (-not $k.TxtKomputerUzytkownikMaszyny) { return }

    if ($Uzytkownik.Uzytkownik) {
        $k.TxtKomputerUzytkownikMaszyny.Text = Get-JezykTekstSesji -Nazwa ([string]$Uzytkownik.Uzytkownik) `
                                                   -Data $Uzytkownik.Data -Teraz ([bool]$Uzytkownik.ZalogowanyTeraz)
    }
    else {
        $k.TxtKomputerUzytkownikMaszyny.Text = if ($Uzytkownik.Blad) { $Uzytkownik.Blad } else { 'brak danych' }
    }

    # Dostepnosc i karta sieciowa przychodza tym samym wynikiem.
    Set-JezykDostepnoscKomputera -Odpowiada $Uzytkownik.Odpowiada `
                                 -Adres ([string]$Uzytkownik.Adres) -Widok Maszyna

    Set-JezykAdresMac -Mac ([string]$Uzytkownik.Mac) `
                      -Szczegoly (Get-JezykTrescMac -Wynik $Uzytkownik) `
                      -Podstawa ([string]$Uzytkownik.MacPodstawa) -Widok Maszyna

    # Adres dopasowania MAC - ponowny ping sprawdzi, czy karta nadal pasuje.
    $Script:MacDlaAdresu = if ($Uzytkownik.Mac) { [string]$Uzytkownik.Adres } else { '' }

    Set-JezykInfo 'Uzytkownik' $(if ($Uzytkownik.Blad) { [string]$Uzytkownik.Szczegoly } else { '' })
}

# Doklada trafienia po numerze telefonu: na koniec listy, bez sortowania i bez ruszania zaznaczenia.
# Cztery odpowiedzi; notke "trwa" zastepuje (README: Wyszukiwanie po numerze telefonu).
function Update-JezykNumerWTle {
    param($Wynik)

    $k = $Script:Kontrolki

    # Stan notki czytany raz, na wejsciu - galezie nizej zmieniaja pole Status.
    $notka = $Script:StatusCzekaNaNumer

    try {
        if ($Wynik.Przerwane) {
            # "Nie udalo sie sprawdzic" to nie "nikogo nie ma" - lista moze byc niepelna.
            if ($notka) {
                # Pole mowilo "trwa" - zastepujemy pelnym zdaniem.
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
            # Bez cytowania wpisanej wartosci - pole moze juz niesc inny numer.
            $zaWielu = 'Numeru używa w domenie {0} więcej niż {1} osób - to zwykle numer infolinii albo wspólny numer działu. Poszukaj po nazwisku albo loginie.' -f
                       $Script:Config.Domena, [int]$Script:Config.LimitNumeru

            if ($k.ListaKont.Items.Count -eq 0) {
                # Pusta lista: komunikat ZASTEPUJE tresc pola razem z werdyktem (doklejony ginal poza polem).
                $k.TxtStatus.Text     = $zaWielu
                $k.Werdykt.Text       = 'Numer należy do wielu osób'
                Set-JezykKolorPola $k.Werdykt 'Nieznany'
            }
            else {
                # Zdanie o trafieniach po nazwie zostaje - numer dopisuje sie za nim.
                $k.TxtStatus.Text = ('{0} {1}' -f $k.TxtStatus.Text, $zaWielu).Trim()
            }
            return
        }

        $trafienia = @($Wynik.Trafienia)
        if ($trafienia.Count -eq 0) {
            if ($notka) {
                # Koniec szukania, nikogo nie ma - zdanie "trwa" nie moze zostac.
                $k.Werdykt.Text   = 'Nie znaleziono konta'
                $k.TxtStatus.Text = 'Nie znaleziono nikogo w domenie {0} - ani po nazwie, ani po numerze telefonu.' -f
                                    $Script:Config.Domena
            }
            return
        }

        $lista = $k.ListaKont

        # Bez duplikatow (po DN) - konto z numerem w loginie trafia do obu zapytan.
        $juzSa = @{}
        foreach ($pozycja in $lista.Items) { $juzSa[[string]$pozycja.Dn] = $true }

        # Notka stoi tylko przy pustej liscie, wiec tu nie dotrwa.
        $nowe = @($trafienia | Where-Object { -not $juzSa.ContainsKey([string]$_.Dn) })
        if ($nowe.Count -eq 0) { return }

        $bylaPusta = ($lista.Items.Count -eq 0)

        # Blokada zdarzen jak w Set-JezykListaKont.
        $Script:BlokadaZdarzen = $true
        try { foreach ($pozycja in $nowe) { [void]$lista.Items.Add($pozycja) } }
        finally { $Script:BlokadaZdarzen = $false }

        if ($bylaPusta) {
            # Lista byla pusta - zaznaczenie odpala pelny odczyt i poprawia werdykt oraz status.
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

        # Poza jeza z koncowego stanu listy; w finally, bo odpowiedzi wychodza przez return.
        $stan = if ($k.ListaKont.Items.Count -gt 0) { 'Jablko' } else { 'NaPlecach' }
        Set-JezykStanJeza $stan
    }
}

# Stan jeza: Ukryty, Szuka, Jablko, NaPlecach - kontrolka, licznik klatek i zegar naraz.
# Licznik zerowany tylko przy 'Szuka'; Invalidate konieczne (Szuka -> Jablko nie zmienia Visible).
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

# Widocznosc "Polacz" i "Dyski": maszyna, sciezka konsoli (tylko "Polacz") i potwierdzona sonda.
# Swiadomie chowa przy stanie przejsciowym - droga powrotu to "Pinguj" (README: Kod > Jezyk-3-Widok).
function Set-JezykPrzyciskiZdalne {
    param([string]$Netbios, [ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $k = $Script:Kontrolki

    # Porownanie z $true: $null chowa tak samo jak $false.
    $odpowiada = ($true -eq $Script:MaszynaOdpowiada)

    $polacz = if ($Widok -eq 'Maszyna') { $k.PrzyciskPolaczMaszyny } else { $k.PrzyciskPolacz }
    if ($polacz) {
        # Pusta sciezka = funkcja wylaczona; czytana przy kazdym wywolaniu.
        $sciezka = ([string]$Script:Ustawienia.SciezkaRemoteControl).Trim()

        $polacz.Visible = ([bool]$Netbios -and [bool]$sciezka -and $odpowiada)
    }

    if ($Widok -ne 'Maszyna') { return }

    # "Dyski" nie pyta o sciezke do niczego - udzialy administracyjne zaklada system sam.
    if ($k.PrzyciskDyskiMaszyny) {
        $k.PrzyciskDyskiMaszyny.Visible = ([bool]$Netbios -and $odpowiada)
    }
}

# Obsluga "Polacz": zdalna konsola ConfigMgr dla maszyny z pamieci.
# Status niesie "Trwa laczenie" do okna konsoli; niepowodzenie trafia do Status i "!".
function Invoke-JezykPolacz {
    param([ValidateSet('Konto', 'Maszyna')][string]$Widok = 'Konto')

    $k = $Script:Kontrolki
    if (-not $Script:OstatniKomputer) { return }

    # Kazdy widok ma wlasne Status: i "!".
    $pole  = if ($Widok -eq 'Maszyna') { $k.TxtKomputerStatus } else { $k.TxtStatus }
    $klucz = if ($Widok -eq 'Maszyna') { 'StatusMaszyny' }      else { 'Status' }

    # Notka przed uruchomieniem - samo uruchomienie z udzialu potrafi chwile trwac.
    Set-JezykNotkeKonsoli -Widok $Widok -Pole $pole -Klucz $klucz -Netbios $Script:OstatniKomputer

    $wynik = Start-JezykRemoteControl -Netbios $Script:OstatniKomputer `
                                      -Sciezka ([string]$Script:Ustawienia.SciezkaRemoteControl)

    if (-not $wynik.Udane) {
        Stop-JezykNotkeKonsoli
        if ($pole) { $pole.Text = [string]$wynik.Komunikat }
        Set-JezykInfo $klucz ([string]$wynik.Szczegoly)
        return
    }

    # Kropki ida, dopoki konsola nie pokaze okna - pilnuje tego takt ZegarTla.
    if ($Script:NotkaKonsoli) { $Script:NotkaKonsoli.Proces = $wynik.Proces }
    if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
}

# Obsluga "Dyski": pyta o litere udzialu, a laczenie zleca zadaniu w tle.
# Bez -Widok - przycisk stoi tylko w panelu komputera; pusta odpowiedz okna = rezygnacja.
function Invoke-JezykDyski {
    if (-not $Script:OstatniKomputer) { return }

    $litera = Show-JezykWyborDysku
    if (-not $litera) { return }

    # Notka przed zadaniem - zapamietuje zdanie, zanim zakryja je kropki.
    Set-JezykNotkeLaczenia
    Start-JezykZadanieDysku -Netbios $Script:OstatniKomputer -Litera $litera
}

# Rozstrzyga odpowiedz proby polaczenia z udzialem; kazde z czterech zakonczen gasi notke.
# Okno poswiadczen pada tutaj - na watku interfejsu (README: Przycisk "Dyski").
function Update-JezykDyskWTle {
    param($Wynik)

    $k = $Script:Kontrolki

    if ($Wynik.Stan -eq 'Poswiadczenia') {
        $uchwyt = [IntPtr]::Zero
        $okno   = $k.Okno
        if ($okno -and $okno.PSObject.Properties['Handle'] -and $null -ne $okno.Handle) {
            $uchwyt = [IntPtr]$okno.Handle
        }

        $Wynik = Connect-JezykUdzialDysku -Netbios $Wynik.Netbios -Litera $Wynik.Litera `
                                          -Uchwyt $uchwyt -Interaktywnie
    }

    Set-JezykNotkeLaczenia -Wylacz

    # Rezygnacja nie jest bledem - pole wraca do zdania sprzed notki, "!" nietkniety.
    if ($Wynik.Stan -eq 'Anulowano') {
        if ($k.TxtKomputerStatus) { $k.TxtKomputerStatus.Text = [string]$Script:StatusPrzedLaczeniem }
        return
    }

    if ($Wynik.Stan -ne 'Ok') {
        if ($k.TxtKomputerStatus) { $k.TxtKomputerStatus.Text = [string]$Wynik.Komunikat }
        Set-JezykInfo 'StatusMaszyny' ([string]$Wynik.Szczegoly)
        return
    }

    # Sesja juz stoi - otwarcie wraca od razu.
    $otwarcie = Open-JezykUdzialDysku -Netbios $Wynik.Netbios -Litera $Wynik.Litera

    if ($k.TxtKomputerStatus) { $k.TxtKomputerStatus.Text = [string]$otwarcie.Komunikat }

    # Jedno wywolanie na obie sciezki: puste szczegoly gasza "!".
    Set-JezykInfo 'StatusMaszyny' ([string]$otwarcie.Szczegoly)
}

# Dostepnosc przycisku grup - wyszarza sie (stan przejsciowy), a nie znika.
function Set-JezykPrzyciskGrupy {
    param($Result)

    $przycisk = $Script:Kontrolki.PrzyciskGrupyAd
    if (-not $przycisk) { return }

    $przycisk.Enabled = Test-JezykJestPoCoOtwieracGrupy $Result
}

# Czy czlonkostwem tego konta wolno tu zarzadzac: domena z listy, konto (nie kontakt) i login.
function Test-JezykMoznaZarzadzacGrupami {
    param($Result)

    if (-not $Result) { return $false }
    if ($Result.Status -ne 'Ok') { return $false }
    if (-not [bool]$Result.Login) { return $false }
    return (Test-JezykWolnoZarzadzacGrupami $Script:Config.Domena)
}

# Czy okno grup ma co pokazac albo co zrobic: sa grupy albo wolno dopisac pierwsza.
function Test-JezykJestPoCoOtwieracGrupy {
    param($Result)

    if (-not $Result) { return $false }
    if ($Result.Status -ne 'Ok' -and $Result.Status -ne 'Kontakt') { return $false }

    # Filtr, nie samo @().Count - @($null) ma jeden element.
    if (@($Result.Grupy | Where-Object { $_ }).Count -gt 0) { return $true }

    return (Test-JezykMoznaZarzadzacGrupami $Result)
}

# Notka i "!" w oknie grup - okno na zadanie niczego nie rejestruje, wiec nie Set-JezykInfo.
function Set-JezykNotkeGrup {
    param($Okno, [string]$Tekst, [string]$Szczegoly = '')

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan) { return }

    $stan.Szczegoly = $Szczegoly
    if ($stan.Notka)        { $stan.Notka.Text = $Tekst }
    if ($stan.PrzyciskInfo) { $stan.PrzyciskInfo.Visible = [bool]$Szczegoly }
}

# Nowa lista grup do wyniku konta, na liste okna (z tytulem) i do przycisku w oknie glownym.
function Update-JezykGrupyWOknie {
    param($Okno, [object[]]$Grupy)

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan) { return }

    # Pary nazwa + DN (ta sama normalizacja co w New-JezykResult) - DN potrzebny do usuniecia.
    $nowe = @(Get-JezykParyGrup $Grupy)

    if ($Script:OstatnieKonto) {
        $Script:OstatnieKonto.GrupyPelne = $nowe
        $Script:OstatnieKonto.Grupy      = @($nowe | ForEach-Object { $_.Nazwa })
    }
    if ($stan.Lista)      { $stan.Lista.Tag = $nowe }
    if ($stan.PoleFiltra) { Update-JezykFiltrGrup $stan.PoleFiltra }

    Set-JezykPrzyciskGrupy $Script:OstatnieKonto
}

# Notka "Sprawdzanie" w Status okna grup i blokada wiersza nazwy na czas zadania - jedna funkcja na oba.
# -Wylacz nie rusza tresci notki: wolajacy wpisuje zaraz odpowiedz.
function Set-JezykSprawdzanieGrupy {
    param($Okno, [switch]$Wylacz)

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan) { return }

    $stan.Sprawdzanie            = -not $Wylacz
    $Script:OknoSprawdzaniaGrupy = if ($Wylacz) { $null } else { $Okno }

    # Pole tylko do odczytu, nie wyszarzone - odpowiedz wpisze do niego nazwe z AD.
    if ($stan.PoleGrupy)       { $stan.PoleGrupy.ReadOnly       = -not $Wylacz }
    if ($stan.PrzyciskSprawdz) { $stan.PrzyciskSprawdz.Enabled = [bool]$Wylacz }
    # "Usun z grupy" czeka razem z wierszem - jego komunikat zakrylyby kropki.
    Set-JezykPrzyciskUsunGrupe -Okno $Okno

    if ($Wylacz) { return }

    # Stary "!" nie moze stac przy kropkach.
    Set-JezykNotkeGrup -Okno $Okno -Tekst ''

    $Script:KlatkaKropek = 0

    # Pierwsza klatka od razu - odpowiedz bywa krotsza niz takt zegara.
    Update-JezykKropkiSprawdzania
}

# Obsluga "Sprawdz nazwy": zapala notke i zleca rozpoznanie nazwy grupy zadaniu w tle.
function Invoke-JezykSprawdzenieNazwyGrupy {
    param($Okno)

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan) { return }

    # Enter w polu dochodzi tu takze w trakcie sprawdzania - drugie zapytanie o to samo.
    if ($stan.Sprawdzanie) { return }

    # Poprzednie rozpoznanie traci waznosc od razu, a nie po odpowiedzi.
    $stan.Wybrana = $null
    if ($stan.PrzyciskDodaj) { $stan.PrzyciskDodaj.Enabled = $false }

    $fraza = ''
    if ($stan.PoleGrupy) { $fraza = [string]$stan.PoleGrupy.Text }

    if (-not (Get-JezykFrazaLdap $fraza)) {
        Set-JezykNotkeGrup -Okno $Okno -Tekst 'Wpisz fragment nazwy grupy, a potem kliknij „Sprawdź nazwy”.'
        return
    }

    # Notka przed zadaniem - pierwsza klatka stoi, zanim zadanie ruszy.
    Set-JezykSprawdzanieGrupy -Okno $Okno
    Start-JezykZadanieGrupy -Okno $Okno -Fraza $fraza -Limit ([int]$Script:Config.LimitPodpowiedziGrup)
}

# Odpowiedz "Sprawdz nazwy" z tla; notka i blokada gasna przed rozgalezieniem, wiec w kazdej galezi.
function Update-JezykNazwaGrupyWTle {
    param($Okno, $Wynik, [string]$Fraza, [int]$Limit)

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan) { return }

    # Przed czymkolwiek innym - nastepny takt zegara nadpisalby odpowiedz kropkami.
    Set-JezykSprawdzanieGrupy -Okno $Okno -Wylacz

    # Nieudane sprawdzenie odroznialne od pustego wyniku - inaczej ktos zalozylby grupe drugi raz.
    if ($Wynik.Przerwane) {
        Set-JezykNotkeGrup -Okno $Okno -Tekst 'Nie udało się sprawdzić nazwy grupy w AD.' `
                           -Szczegoly ([string]$Wynik.Powod)
        return
    }

    $trafienia = @($Wynik.Trafienia)
    if ($trafienia.Count -eq 0) {
        $pusto = 'Nie znaleziono grupy pasującej do „{0}”.' -f $Fraza
        Set-JezykNotkeGrup -Okno $Okno -Tekst $pusto
        return
    }

    $wybrana = $trafienia[0]
    if ($trafienia.Count -gt 1) {
        $wybrana = Show-JezykWyborGrupy -Trafienia $trafienia -Wlasciciel $Okno
        if (-not $wybrana) {
            # Rezygnacja z wyboru jest cisza: notka nadal mowi prawde o tym, co znaleziono.
            $wiele = 'Znaleziono {0} grup - kliknij „Sprawdź nazwy” i wybierz jedną.' -f $trafienia.Count
            Set-JezykNotkeGrup -Okno $Okno -Tekst $wiele
            return
        }
    }

    # W polu nazwa z AD, a nie wpisana - widac, ktora grupe rozpoznano.
    if ($stan.PoleGrupy) { $stan.PoleGrupy.Text = [string]$wybrana.Nazwa }

    # Uwaga: wybor zapamietany PO przepisaniu pola - TextChanged zeruje go (README: Kod > Jezyk-3-Widok).
    $stan.Wybrana = $wybrana
    if ($stan.PrzyciskDodaj) { $stan.PrzyciskDodaj.Enabled = $true }

    # Pole dostaje nazwe, notka podpis (z folderem, gdy nazwa sie powtarza).
    $tekst = 'Rozpoznano grupę „{0}”. Kliknij „Dodaj”, aby dopisać do niej konto.' -f $wybrana.Podpis
    if ($Wynik.ZaDuzo) {
        # Zdanie uniewazniajace poprzednie ZASTEPUJE je, a nie staje za nim.
        $tekst = 'Trafień było więcej niż {0} - pokazano pierwsze. Rozpoznano grupę „{1}”.' -f $Limit, $wybrana.Podpis
    }
    Set-JezykNotkeGrup -Okno $Okno -Tekst $tekst
}

# Grupa zaznaczona na liscie - z WidoczneGrupy (po filtrze), a nie z napisu pozycji.
function Get-JezykZaznaczonaGrupe {
    param($Okno)

    if (-not $Okno) { return $null }
    $stan = $Okno.Tag
    if (-not $stan -or -not $stan.Lista) { return $null }

    $widoczne = @($stan.WidoczneGrupy)
    $nr = [int]$stan.Lista.SelectedIndex
    if ($nr -lt 0 -or $nr -ge $widoczne.Count) { return $null }
    return $widoczne[$nr]
}

# "Usun z grupy" czynny, gdy zaznaczona pozycja ma DN i wolno zarzadzac (przeliczany takze po filtrze).
function Set-JezykPrzyciskUsunGrupe {
    param($Okno)

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan -or -not $stan.PrzyciskUsun) { return }

    $grupa = Get-JezykZaznaczonaGrupe -Okno $Okno
    # W trakcie "Sprawdz nazwy" wyszarzony - komunikat usuniecia zakrylyby kropki.
    $stan.PrzyciskUsun.Enabled = ([bool]$grupa -and [bool]$grupa.Dn -and -not $stan.Sprawdzanie -and
                                  (Test-JezykMoznaZarzadzacGrupami $Script:OstatnieKonto))
}

# Pyta Tak/Nie przed zmiana czlonkostwa (domyslnie "Nie"): konto, grupa, domena i folder grupy.
function Confirm-JezykZmianyCzlonkostwa {
    param($Okno, [string]$Login, [string]$Grupa, [string]$Domena,
          [ValidateSet('Dodaj', 'Usun')][string]$Akcja, [string]$Folder = '')

    # Uwaga: napis do zmiennej - w argumencie metody przecinki naleza do metody, nie do -f.
    $tresc = if ($Akcja -eq 'Usun') {
        'Usunąć konto "{0}" z grupy "{1}" w domenie {2}?' -f $Login, $Grupa, $Domena
    } else {
        'Dodać konto "{0}" do grupy "{1}" w domenie {2}?' -f $Login, $Grupa, $Domena
    }

    # Folder grupy w kazdym pytaniu - nazwa grupy nie jest w domenie jednoznaczna.
    if ($Folder) { $tresc = "{0}`n`nFolder grupy w AD: {1}" -f $tresc, $Folder }

    $odpowiedz = [System.Windows.Forms.MessageBox]::Show(
        $Okno, $tresc, 'Jeżyk - Grupy AD',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2)

    return ($odpowiedz -eq [System.Windows.Forms.DialogResult]::Yes)
}

# Wspolny ogon obu zmian czlonkostwa: potwierdzenie, zapis, odczyt z kontrolera zapisu, odswiezenie.
# $true, gdy zapis sie udal - takze gdy odczyt po nim zawiodl (powodzenia nie wolno zgubic).
function Invoke-JezykZapisCzlonkostwa {
    param($Okno, $Grupa, [ValidateSet('Dodaj', 'Usun')][string]$Akcja)

    if (-not $Okno -or -not $Grupa) { return $false }

    # Konto z obiektu wyniku, nie z kontrolki.
    if (-not $Script:OstatnieKonto -or $Script:OstatnieKonto.Status -ne 'Ok') { return $false }
    $login = [string]$Script:OstatnieKonto.Login
    if (-not $login) { return $false }

    $domena = [string]$Script:Config.Domena

    # Potwierdzenie PRZED zapisem. Rezygnacja jest cisza: zadnego zapisu, zadnego bledu.
    $zgoda = Confirm-JezykZmianyCzlonkostwa -Okno $Okno -Login $login `
                                            -Grupa ([string]$Grupa.Nazwa) -Domena $domena -Akcja $Akcja `
                                            -Folder (Get-JezykFolderAd ([string]$Grupa.Dn))
    if (-not $zgoda) { return $false }

    $Okno.UseWaitCursor = $true
    try {
        $wynik = Set-JezykCzlonkostwoGrupy -Login $login -Dn ([string]$Script:OstatnieKonto.Dn) `
                                           -GrupaDn ([string]$Grupa.Dn) -Domena $domena -Akcja $Akcja
    }
    finally { $Okno.UseWaitCursor = $false }

    # Niepowodzenie: powod odmowy zostaje w notce.
    if (-not $wynik.Udane) {
        Set-JezykNotkeGrup -Okno $Okno -Tekst ([string]$wynik.Komunikat) `
                           -Szczegoly ([string]$wynik.Szczegoly)
        return $false
    }

    $odczyt = Get-JezykGrupyKonta -Login $login -Serwer ([string]$wynik.Serwer)

    if (-not $odczyt.Udane) {
        $tekst = '{0} Nie udało się jednak odświeżyć listy - zamknij i otwórz okno grup.' -f $wynik.Komunikat
        Set-JezykNotkeGrup -Okno $Okno -Tekst $tekst -Szczegoly ([string]$odczyt.Szczegoly)
        return $true
    }

    Update-JezykGrupyWOknie -Okno $Okno -Grupy @($odczyt.Grupy)
    Set-JezykNotkeGrup -Okno $Okno -Tekst ([string]$wynik.Komunikat)
    return $true
}

# Obsluga przycisku "Dodaj": grupa bierze sie z rozpoznanej nazwy ("Sprawdz nazwy").
function Invoke-JezykDodanieDoGrupy {
    param($Okno)

    if (-not $Okno) { return }
    $stan = $Okno.Tag
    if (-not $stan) { return }

    $wybrana = $stan.Wybrana
    if (-not $wybrana) { return }

    if (-not (Invoke-JezykZapisCzlonkostwa -Okno $Okno -Grupa $wybrana -Akcja 'Dodaj')) { return }

    # Po zapisie pole czyszczone (budzi TextChanged, co gasi "Dodaj" i zeruje wybor).
    if ($stan.PoleGrupy) { $stan.PoleGrupy.Text = '' }
    $stan.Wybrana = $null
    if ($stan.PrzyciskDodaj) { $stan.PrzyciskDodaj.Enabled = $false }
}

# Obsluga przycisku "Usun z grupy": grupa bierze sie z zaznaczenia na liscie.
function Invoke-JezykUsuniecieZGrupy {
    param($Okno)

    $grupa = Get-JezykZaznaczonaGrupe -Okno $Okno
    if (-not $grupa) { return }

    # Pozycja bez DN (wpis memberOf bez CN=) - mowimy to wprost zamiast milczec.
    if (-not $grupa.Dn) {
        Set-JezykNotkeGrup -Okno $Okno `
                           -Tekst 'Tej pozycji nie da się usunąć - katalog nie podał nazwy wyróżniającej grupy.'
        return
    }

    [void](Invoke-JezykZapisCzlonkostwa -Okno $Okno -Grupa $grupa -Akcja 'Usun')
}

# Naklada motyw: paleta, bufory pedzli, role wygladu, a NA KONCU role kolorow znaczacych.
# Uwaga: odwrotna kolejnosc zdjelaby czerwien z werdyktu (README: Ciemny motyw).
function Set-JezykMotyw {
    param([ValidateSet('Jasny', 'Ciemny')][string]$Motyw)

    $Script:Motyw = $Motyw

    $paleta = if ($Motyw -eq 'Ciemny') { $Script:MotywCiemny } else { $Script:MotywJasny }
    foreach ($klucz in @($paleta.Keys)) { $Script:Config[$klucz] = $paleta[$klucz] }

    # Bufory pedzli (strzalka listy, ramka flag) ida z palety - padaja razem z nia.
    $Script:PedzleStrzalki   = $null
    $Script:PedzleRamkiFlag  = $null

    # Kopia kluczy, bo obie funkcje ponizej pisza do tych samych tablic.
    foreach ($kontrolka in @($Script:KontrolkiMotywu.Keys)) {
        Set-JezykWyglad $kontrolka $Script:KontrolkiMotywu[$kontrolka]
    }
    foreach ($pole in @($Script:RoleKolorow.Keys)) {
        Set-JezykKolorPola $pole $Script:RoleKolorow[$pole]
    }

    # Po rolach: zmiana BorderStyle odtwarza uchwyt i wysokosc nadana wczesniej by przepadla.
    Set-JezykWyrownaniePol

    # Obciecie ramki list i kwadrat ze strzalka przeliczane razem.
    Update-JezykOprawaList

    if ($Script:Kontrolki.JezSzukania) { $Script:Kontrolki.JezSzukania.Invalidate() }

    Set-JezykMotywSystemowy
}

# Uchwyt okna kontrolki albo zero - bez tworzenia uchwytu (IsHandleCreated przed Handle).
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

# Wyrownuje wnetrze pol po zmianie grubosci ramki: w dol o roznice, nizej o jej dwukrotnosc.
# Licznik nalozonego wciecia - przelaczanie motywu wraca na miejsce, a nie sumuje poprawki.
function Set-JezykWyrownaniePol {
    $delta = $Script:WciecieNalozone - $Script:Config.WciecieRamkiPola
    if ($delta -eq 0) { return }

    foreach ($kontrolka in @($Script:KontrolkiMotywu.Keys)) {
        if ($Script:KontrolkiMotywu[$kontrolka] -ne 'Pole') { continue }
        if (-not $kontrolka) { continue }

        # Uwaga: wysokosc czytana PRZED zdjeciem AutoSize - zdjecie cofa ja do tej z konstruktora.
        $wysokosc = $kontrolka.Height
        $kontrolka.AutoSize = $false

        $kontrolka.Top    = $kontrolka.Top + $delta
        $kontrolka.Height = $wysokosc - 2 * $delta
    }

    $Script:WciecieNalozone = $Script:Config.WciecieRamkiPola
}

# Oprawa trzech list rozwijanych (obciecie ramki, kwadrat ze strzalka) - wolana tez po pokazaniu okna.
function Update-JezykOprawaList {
    $k = $Script:Kontrolki
    if (-not $k) { return }

    $szerokosc = Get-JezykSzerokoscStrzalki

    foreach ($para in @(@($k.Domena,    $k.StrzalkaDomeny),
                        @($k.Tryb,      $k.StrzalkaTrybu),
                        @($k.ListaKont, $k.StrzalkaListyKont))) {
        Set-JezykObciecieListy $para[0]
        Set-JezykStrzalkaListy $para[0] $para[1] $szerokosc
    }
}

# Ciemny pasek tytulu i paski przewijania - to rysuje system, nie WinForms.
function Set-JezykMotywSystemowy {
    $ciemny = ($Script:Motyw -eq 'Ciemny')
    $k      = $Script:Kontrolki

    Set-JezykCiemnyPasekTytulu (Get-JezykUchwyt $k.Okno) -Ciemny:$ciemny

    # Tylko kontrolki z paskiem przewijania.
    foreach ($kontrolka in @($k.ListaKont, $k.Domena, $k.Tryb)) {
        Set-JezykCiemnyPasekPrzewijania (Get-JezykUchwyt $kontrolka) -Ciemny:$ciemny
    }
}

# Klikniecie ikonki motywu: przelacza motyw i oddaje fokus polu wyszukiwania
# (bez tego w wycieciu sierpa widac prostokat fokusu).
function Invoke-JezykPrzelaczenieMotywu {
    if ($Script:Motyw -eq 'Ciemny') { Set-JezykMotyw 'Jasny' }
    else                            { Set-JezykMotyw 'Ciemny' }

    $pole = $Script:Kontrolki.PoleSzukaj
    if ($pole) { [void]$pole.Focus() }
}

# Wynik SCCM do pola "Ostatnio uzywany komputer"; "!" tylko przy bledzie.
# Funkcja kontrolna - zostaje ostatnia w pliku.
function Update-JezykKomputerWTle {
    param($Komputer)

    # Gasimy tylko notke SCCM - zadanie daty moze jeszcze trwac.
    Set-JezykNotkeSprawdzania -Notka 'Sccm' -Wylacz

    $k = $Script:Kontrolki

    if ($Komputer.Nazwa) {
        $k.TxtKomputerUzytkownika.Text = Get-JezykTekstSesji -Nazwa ([string]$Komputer.Nazwa) `
                                             -Data $Komputer.Data -Teraz ([bool]$Komputer.ZalogowanyTeraz)
    }
    else {
        $k.TxtKomputerUzytkownika.Text = if ($Komputer.Blad) { $Komputer.Blad } else { 'brak danych' }
    }

    # Nazwa maszyny odkladana osobno - kontrolka sluzy do pokazywania, nie do przenoszenia stanu.
    $Script:OstatniKomputer = [string]$Komputer.Nazwa
    if ($k.PrzyciskPinguj) { $k.PrzyciskPinguj.Enabled = [bool]$Script:OstatniKomputer }
    Set-JezykPrzyciskiZdalne $Script:OstatniKomputer

    # Sonda przyszla w tym samym zadaniu - kolor i adres od razu.
    Set-JezykDostepnoscKomputera -Odpowiada $Komputer.Odpowiada -Adres ([string]$Komputer.Adres)

    # MAC dopasowany do tego adresu; adres odkladamy dla ponownego pingu.
    Set-JezykAdresMac -Mac ([string]$Komputer.Mac) -Szczegoly (Get-JezykTrescMac -Wynik $Komputer) `
                      -Podstawa ([string]$Komputer.MacPodstawa)
    $Script:MacDlaAdresu = if ($Komputer.Mac) { [string]$Komputer.Adres } else { '' }

    Set-JezykInfo 'Komputer' $(if ($Komputer.Blad) { [string]$Komputer.Szczegoly } else { '' })

    # Niebieski "!" (wspoldzielenie) nigdy razem z czerwonym - stoja w tym samym miejscu.
    Set-JezykInfo 'KomputerWspoldzielony' $(if ($Komputer.Wspoldzielony -and -not $Komputer.Blad) { [string]$Komputer.SzczegolyWspoldzielenia } else { '' })
}

#endregion
