# Jezyk-4-Okno - siatka okna, budowa kontrolek WinForms i zadania w tle.
# TA LINIA MUSI POZOSTAC ZWYKLYM KOMENTARZEM - oslania pierwsza instrukcje przed
# zdublowanym znacznikiem BOM. Powod opisany w Kod-Jezyk.ps1.

# Wlasny trap w kazdej czesci: trap wznawia prace w zakresie, w ktorym go zdefiniowano.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 4 - OKNO
# Gorny wiersz (Domena / Podaj / pole / Szukaj) jest wspolny, a to, co pod nim, siedzi
# w dwoch panelach: pnlKonto i pnlKomputer. Przelaczenie trybu to pokazanie jednego
# panelu i schowanie drugiego, a nie przestawianie kilkunastu wspolrzednych.

# --- RYTM SIATKI ---------------------------------------------------------------------
# ZADNA wspolrzedna kontrolki nie jest wpisana recznie - wszystkie wyliczaja sie z ponizszych
# stalych. Zmiana odstepow to zmiana jednej liczby zamiast przeliczania osiemnastu na piechote.
# Odstepy sa rozrzutne celowo: pola biora wysokosc z czcionki, wiec przy skalowaniu DPI
# 125-150% rosna, a wspolrzedne zostaja - zapas chroni wtedy przed nachodzeniem wierszy.

# Wiersz z wyborem domeny stoi nad wszystkim, wiec reszta okna schodzi o jego wysokosc.
$Script:PasekDomeny   = 34

$Script:PanelBezListy = 46 + $Script:PasekDomeny
$Script:PanelZListą   = 80 + $Script:PasekDomeny

$Script:PierwszyWiersz     = 100   # y etykiety pierwszego wiersza wewnatrz panelu konta
$Script:SkokWiersza        = 58    # odleglosc miedzy kolejnymi wierszami
$Script:OdstepPodEtykieta  = 20    # ile nizej od etykiety lezy jej pole

$Script:PasekPodpisu       = 22    # pasek na podpis autora u dolu, poza panelami

# Najdluzszy napis, jaki moze pokazac etykieta werdyktu. Potrzebny do ZMIERZENIA jej
# szerokosci: po zdjeciu AutoSize szerokosc dobrana do biezacego napisu ucielaby dluzszy.
#
# MUSI BYC FAKTYCZNIE NAJDLUZSZY ZE WSZYSTKICH tekstow werdyktu (patrz Set-JezykResult
# w Jezyk-3-Widok.ps1) - to juz raz zawiodlo: dopisanie werdyktu dla kontaktu ("Pozycja
# typu Kontakt - to nie jest konto", 41 znakow) bez uaktualnienia tej stalej ucinalo jego
# tekst, bo byla wtedy zmierzona na krotszym "Konto zablokowane i wyłączone" (30 znakow).
# Przy KAZDYM nowym tekscie werdyktu sprawdz, czy nie jest od tego dluzszy.
$Script:NajdluzszyWerdykt  = 'Pozycja typu Kontakt - to nie jest konto'

# Srodek wiersza werdyktu - wspolny dla kwadratu, napisu i przycisku odblokowania.
$Script:SrodekWerdyktu     = 16

# Rytm poziomy. Obie kolumny musza wyjsc rowne, wiec sa WYLICZANE, a nie wpisane.
$Script:Margines      = 12
$Script:SzerokoscOkna = 620
$Script:PrzerwaKolumn = 28

$Script:SzerokoscPelna = $Script:SzerokoscOkna - 2 * $Script:Margines
# Dzielenie calkowite: nieparzysta reszta idzie na przerwe, nie na jedna z kolumn -
# bo to wlasnie roznica szerokosci kolumn rzuca sie w oczy.
$Script:SzerokoscKolumny = [int](($Script:SzerokoscPelna - $Script:PrzerwaKolumn) / 2)
$Script:DrugaKolumna     = $Script:Margines + $Script:SzerokoscKolumny + $Script:PrzerwaKolumn

# y ETYKIETY wiersza o podanym numerze (liczonym od zera).
function Get-JezykWiersz { param([int]$Numer) $Script:PierwszyWiersz + $Script:SkokWiersza * $Numer }

# y POLA nalezacego do wiersza o podanym numerze.
function Get-JezykWierszPole { param([int]$Numer) (Get-JezykWiersz $Numer) + $Script:OdstepPodEtykieta }

# Wyrownuje kontrolki w PIONIE do wspolnego srodka wiersza. WinForms wylicza wysokosc listy
# rozwijanej i przycisku z czcionki, a nie z tego, co wpiszemy w Size - wspolrzedne wpisane
# recznie zgadzaja sie wiec tylko przy 100% DPI. Zamiast zgadywac liczby, pytamy kontrolki
# o ich RZECZYWISTA wysokosc.
function Set-JezykSrodekPionowy {
    param([object[]]$Kontrolki, [int]$Srodek)
    foreach ($kontrolka in $Kontrolki) {
        $kontrolka.Top = $Srodek - [int]($kontrolka.Height / 2)
    }
}

<#
.SYNOPSIS
    Rozklada kontrolki po rownych slupkach i srodkuje kazda w SWOIM slupku.

.DESCRIPTION
    Szerokosc dzielimy na tyle slupkow, ile jest kontrolek, i kazda ustawiamy na srodku
    swojego. Wersja poprzednia stawiala je w slupkach liczonych od stalego lewego
    marginesu, wiec caly rzad byl docisniety do lewej, a po prawej zostawala pustka
    tym wieksza, im krotsze byly napisy.

    LEWA KRAWEDZ I SZEROKOSC PODAJE WOLAJACY, bo przy GroupBoxie nie sa to zero i Width:
    ramka rezerwuje u gory pasek na tytul i ma wlasne obramowanie, wiec prawdziwe wnetrze
    zna wylacznie jej DisplayRectangle.

    POMIAR MUSI BYC JUZ ZROBIONY: srodkowanie liczy sie z Width kazdej kontrolki, a ta
    jest znana dopiero po Set-JezykSrodekTekstu i po odziedziczeniu czcionki okna.
#>
function Set-JezykSrodekWSlupkach {
    param([object[]]$Kontrolki, [int]$Lewa, [int]$Szerokosc)

    $ile = @($Kontrolki).Count
    if ($ile -eq 0 -or $Szerokosc -le 0) { return }

    $slupek = $Szerokosc / $ile

    for ($i = 0; $i -lt $ile; $i++) {
        # Srodek slupka lezy w jego polowie, stad + 0.5. Dzielenie idzie na liczbach
        # zmiennoprzecinkowych - przy calkowitym polowka slupka znikalaby i rzad
        # przesuwalby sie w lewo o kilka pikseli.
        $srodek = $Lewa + [int]($slupek * ($i + 0.5))
        $Kontrolki[$i].Left = $srodek - [int]($Kontrolki[$i].Width / 2)
    }
}

<#
.SYNOPSIS
    Zdejmuje AutoSize i srodkuje tresc kontrolki w prostokacie o zadanej wysokosci.

.DESCRIPTION
    Kontrolka z AutoSize ma wysokosc SAMEGO TEKSTU, wiec wyrownanie ustawia w jednej linii
    prostokaty, a nie linie pisma - lista rozwijana ma wlasne marginesy wewnetrzne i jej
    tekst siedzi w nich nizej niz napis w ciasnej etykiecie obok. Przy checkboxie dochodzi
    kwadrat o stalych 13 px, ktory w ciasnym prostokacie nie miesci sie razem z napisem.

    POMIAR MUSI SIE ODBYC TUTAJ, a nie w fabryce kontrolki: swiezo utworzona kontrolka ma
    jeszcze czcionke domyslna i dziedziczy czcionke okna dopiero po dodaniu do niego.

.PARAMETER NajdluzszyTekst
    Podawany dla werdyktu, ktorego tresc zmienia sie w trakcie dzialania - szerokosc mierzy
    sie wtedy na najdluzszym mozliwym napisie, a nie na biezacym.
#>
function Set-JezykSrodekTekstu {
    param($Kontrolka, [int]$Wysokosc, [string]$NajdluzszyTekst = '')

    if ($NajdluzszyTekst) {
        $biezacy         = $Kontrolka.Text
        $Kontrolka.Text  = $NajdluzszyTekst
        $szerokosc       = $Kontrolka.PreferredSize.Width
        $Kontrolka.Text  = $biezacy
    }
    else {
        $szerokosc = $Kontrolka.PreferredSize.Width
    }

    $Kontrolka.AutoSize  = $false
    $Kontrolka.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    if ($Kontrolka -is [System.Windows.Forms.CheckBox]) {
        $Kontrolka.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    }
    $Kontrolka.Size = [System.Drawing.Size]::new($szerokosc, $Wysokosc)
}

# Blokada zdarzen na czas programowego wypelniania listy - patrz Set-JezykListaKont.
$Script:BlokadaZdarzen = $false

# Etykieta opisujaca pole.
function New-JezykEtykieta {
    param([string]$Tekst, [int]$X, [int]$Y)

    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.Text     = $Tekst
    $lbl.Location = [System.Drawing.Point]::new($X, $Y)
    $lbl.AutoSize = $true
    $lbl
}

# Pole tekstowe tylko do odczytu. ReadOnly zamiast Enabled = $false, bo tresc ma dac sie
# zaznaczyc i skopiowac; wylaczona kontrolka bylaby wyszarzona i niczego by nie oddala.
# Ustawiamy SAMA szerokosc: wysokosc pole wylicza z czcionki, a wartosc podana na sztywno
# przestaje pasowac przy skalowaniu DPI i litery obcinaja sie od dolu.
function New-JezykPole {
    param([int]$X, [int]$Y, [int]$Szerokosc)

    $txt           = New-Object System.Windows.Forms.TextBox
    $txt.Location  = [System.Drawing.Point]::new($X, $Y)
    $txt.Width     = $Szerokosc
    $txt.ReadOnly  = $true
    # Jawnie kolor okna, bo pole ReadOnly rysuje sie domyslnie na szarym tle i wygladaloby
    # jak nieczynne.
    $txt.BackColor = [System.Drawing.SystemColors]::Window
    $txt
}

# Checkbox tylko do odczytu. AutoCheck = $false zamiast Enabled = $false, bo wylaczona
# kontrolka rysuje wyszarzony, slabo widoczny znacznik - a to wlasnie znacznik niesie informacje.
function New-JezykCheckbox {
    param([string]$Tekst, [int]$X, [int]$Y, [int]$Szerokosc = 0)

    $chk           = New-Object System.Windows.Forms.CheckBox
    $chk.Text      = $Tekst
    $chk.Location  = [System.Drawing.Point]::new($X, $Y)
    $chk.AutoCheck = $false
    if ($Szerokosc -gt 0) { $chk.Size = [System.Drawing.Size]::new($Szerokosc, 20) }
    else                  { $chk.AutoSize = $true }
    $chk
}

<#
.SYNOPSIS
    Maly przycisk "!" - nastepca dymka. Staje obok nazwy pola, ktorego dotyczy.

.DESCRIPTION
    Dymek niosl cala diagnostyke narzedzia, ale nic w oknie nie sygnalizowalo, ze tam
    cokolwiek jest - kto nie wiedzial, ten nie najezdzal kursorem. Przycisk widac i widac
    takze to, ze go nie ma: powstaje NIEWIDOCZNY i pokazuje sie dopiero wtedy, gdy
    Set-JezykInfo odlozy pod nim tresc - a odklada ja WYLACZNIE wtedy, gdy cos naprawde
    nie dziala (patrz wywolania Set-JezykInfo w Jezyk-3-Widok.ps1). To nie jest przycisk
    pomocy ani stale dostepny opis - jego pojawienie sie samo w sobie jest komunikatem.

    Kolor CZERWONY, nie neutralny szary reszty interfejsu: przycisk ma rzucac sie w oczy
    jak werdykt problemu, a nie zlewac sie z tlem, bo widocznosc "!" JEST juz informacja
    o usterce.

    Klucz siedzi w Tag, wiec wszystkie przyciski obsluguje JEDNA procedura zdarzenia -
    procedury zdarzen i tak nie widza zmiennych lokalnych funkcji budujacej okno.

    TabStop wylaczony: przycisk jest dodatkiem i nie ma przerywac wedrowki tabulatorem
    miedzy polami.
#>
function New-JezykPrzyciskInfo {
    param([string]$Klucz, [int]$Bok = 18)

    $btn           = New-Object System.Windows.Forms.Button
    $btn.Text      = '!'
    $btn.Tag       = $Klucz
    $btn.Size      = [System.Drawing.Size]::new($Bok, $Bok)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.BackColor = $Script:Config.KolorProblemTlo
    $btn.ForeColor = $Script:Config.KolorProblem
    $btn.FlatAppearance.BorderColor = $Script:Config.KolorProblem
    $btn.FlatAppearance.BorderSize  = 2
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btn.TabStop   = $false
    $btn.Visible   = $false

    # Bez wyzerowanych marginesow wewnetrznych wykrzyknik nie miesci sie w kwadracie 18 px
    # i rysuje sie uciety od dolu.
    $btn.Padding = [System.Windows.Forms.Padding]::new(0)
    $btn.Margin  = [System.Windows.Forms.Padding]::new(0)
    $btn
}

<#
.SYNOPSIS
    Stawia przycisk "!" tuz za etykieta pola i srodkuje go z nia w pionie.

.DESCRIPTION
    POMIAR SZEROKOSCI MUSI SIE ODBYC PO DODANIU KONTROLEK DO OKNA - z tego samego powodu
    co przy Set-JezykSrodekTekstu: etykieta ma AutoSize, wiec jej szerokosc zalezy od
    czcionki, a czcionke okna dziedziczy dopiero w momencie dodania. Zmierzona wczesniej
    dalaby szerokosc czcionki domyslnej i przycisk wchodzilby na napis.

    PION LICZONY Z CZCIONKI, NIE Z $Etykieta.Height. Etykiety, przy ktorych stoi ten
    przycisk, MAJA WLACZONE AutoSize (nie przeszly przez Set-JezykSrodekTekstu - to wciaz
    zwykle pola siatki, tylko z dodatkowym przyciskiem obok) - ich Height to zmierzona
    wysokosc jednowierszowego tekstu, ktora bywa o kilka pikseli inna niz staly bok
    przycisku (18 px), i to niedopasowanie bylo widac jako krzywy wykrzyknik. Font.GetHeight
    daje stabilna, przewidywalna wysokosc linii - ta sama technika juz sprawdzona przy
    liczeniu wysokosci checkboxow (patrz $wysokoscZnacznika nizej w tym pliku).
#>
function Set-JezykPrzyciskPrzyEtykiecie {
    param($Przycisk, $Etykieta, [int]$Odstep = 6)

    if (-not $Przycisk -or -not $Etykieta) { return }

    $wysokoscLinii = [int][math]::Ceiling($Etykieta.Font.GetHeight())

    $Przycisk.Left = $Etykieta.Left + $Etykieta.Width + $Odstep
    $Przycisk.Top  = $Etykieta.Top + [int](($wysokoscLinii - $Przycisk.Height) / 2)
}

# Pokazuje widok wlasciwy dla wybranego trybu. Przy kazdej zmianie czyscimy OBA widoki -
# bez tego po przejsciu z konta na komputer zostalyby dane poprzedniego wyszukania,
# opisane etykietami z zupelnie innego widoku.
function Set-JezykWidok {
    $k    = $Script:Kontrolki
    $tryb = [string]$k.Tryb.SelectedItem

    $komputer = ($tryb -eq $Script:Config.TrybKomputer)
    # Lista wyboru ma sens wylacznie przy wyszukiwaniu uzytkownikow - zapytanie o komputer
    # zwraca zawsze najwyzej jeden obiekt.
    $zListą = (-not $komputer)

    $k.ListaKont.Visible = $zListą
    $Script:BlokadaZdarzen = $true
    try { $k.ListaKont.Items.Clear() } finally { $Script:BlokadaZdarzen = $false }

    Clear-JezykKonto
    Clear-JezykKomputer

    $gora = if ($zListą) { $Script:PanelZListą } else { $Script:PanelBezListy }

    $k.PanelKonto.Visible    = (-not $komputer)
    $k.PanelKomputer.Visible = $komputer

    # Przesuwamy wylacznie panel. Rozmiaru okna NIE ruszamy - jest staly, ustalony raz
    # w New-JezykForm, inaczej okno skakaloby wysokoscia przy kazdej zmianie trybu.
    if ($komputer) {
        $k.PanelKomputer.Location = [System.Drawing.Point]::new(0, $gora)
    } else {
        $k.PanelKonto.Location = [System.Drawing.Point]::new(0, $gora)
    }
}


# --- ZADANIA W TLE -------------------------------------------------------------------
# Dwie informacje sa WOLNE: dokladna data logowania wymaga odpytania wszystkich kontrolerow,
# a ostatnio uzywany komputer - zapytania do SCCM. Liczone na watku interfejsu zamrazaly okno.
#
# Osobna przestrzen uruchomieniowa liczy w tle, a zegar WinForms co cwierc sekundy sprawdza,
# czy skonczyla. Zegar, a nie BeginInvoke na kontrolce: zdarzenie zegara wykonuje sie NA
# WATKU INTERFEJSU, wiec znika cala klasa bledow z dostepem z obcego watku.
#
# TRZY ZADANIA, NIE JEDNO, i kazde z wlasnym LICZNIKIEM POKOLEN. Liczone razem oddawaly wynik
# dopiero wtedy, gdy skonczyly wszystkie - data czekalaby na SCCM. Pokolenia odrzucaja wynik
# starego zadania, ktory dotarl po przelaczeniu na inne konto: inaczej dane jednego
# uzytkownika wpisalyby sie do okna opisujacego juz kogos innego.
#
# Trzecie zadanie (uzytkownik maszyny) nalezy do WIDOKU KOMPUTERA, a dwa pierwsze do widoku
# konta - naraz pracuje wiec najwyzej jedna strona okna. Wlasny licznik i tak jest konieczny:
# widoki przelaczaja sie w trakcie trwania zapytania.
$Script:PokolenieLogowania  = 0
$Script:PokolenieKomputera  = 0
$Script:PokolenieUzytkownika = 0
$Script:PokoleniePingu      = 0
$Script:ZadanieLogowania    = $null
$Script:ZadanieKomputera    = $null
$Script:ZadanieUzytkownika  = $null
$Script:ZadaniePingu        = $null
$Script:ZegarTla            = $null

# Nazwa maszyny z ostatniej odpowiedzi SCCM - jedyne zrodlo prawdy dla przycisku "Pinguj".
# Pole tekstowe niesie ja razem z data, wiec nie nadaje sie do przeniesienia stanu.
$Script:OstatniKomputer = ''

# Gotowe teksty skryptow dla wszystkich zadan - skladane raz, patrz New-JezykSkryptTla.
$Script:SkryptyTla = @{}

# Zadania PORZUCONE w polowie, czekajace na zwolnienie - patrz Stop-JezykZadanieTla.
$Script:ZadaniaPorzucone = @()

# Po ilu milisekundach porzucone zadanie przestaje byc sprawdzane co takt zegara.
# Przestrzen tkwiaca w nieprzerywalnym wywolaniu sieciowym moze sie nie zglosic przez
# dlugie minuty, a lista przegladana na watku interfejsu co cwierc sekundy nie moze rosnac.
$Script:TerminPorzuconegoMs = 120000

# Zadania SPISANE - te, ktore przekroczyly termin wyzej. Nie przepadaja: przestrzen
# uruchomieniowa zadania daty logowania potrafi miec w srodku zaladowany modul AD, czyli
# kilkadziesiat megabajtow, i dotad zostawala w pamieci do konca zycia procesu, bo po
# wykresleniu z listy NIKT JUZ NIGDY nie probowal jej zwolnic - nawet gdy zawieszone
# wywolanie w koncu wracalo. Teraz czekaja tutaj i sa zwalniane przy pierwszym przegladzie
# PO tym, jak sie faktycznie zakoncza.
#
# Sufit jest ostatnia zapora: powyzej niego wypadaja najstarsze, czyli te, ktore nie
# odpuscily najdluzej. Lista pilnujaca pamieci nie moze sama stac sie wyciekiem.
$Script:ZadaniaSpisane  = @()
$Script:LimitSpisanych  = 50

# Slad po wywolaniach cyklu zycia zadan, ktore ZA DLUGO trzymaly watek interfejsu.
# Ograniczony do ostatnich kilkunastu - to nie jest dziennik, tylko odpowiedz na pytanie
# "co wlasnie zamulilo okno".
$Script:DiagnostykaTla    = @()
$Script:ProgDiagnostykiMs = 250
$Script:LimitDiagnostyki  = 20

<#
.SYNOPSIS
    Zapisuje wywolanie, ktore trzymalo watek interfejsu dluzej niz prog.

.DESCRIPTION
    Open, BeginInvoke, BeginStop i Dispose wykonuja sie NA WATKU INTERFEJSU i kazde z nich
    potrafi zablokowac sie na przestrzeni tkwiacej w wywolaniu, ktorego PowerShell nie umie
    przerwac - polaczenie DCOM z milczacym hostem jest tego wzorcowym przykladem. Kiedy
    okno zamiera, samo odczucie nie mowi, ktore z czterech zawinilo.

    Slad jest widoczny pod przyciskiem "!" przy polu Status, wiec zamarcie przestaje byc
    odczuciem, a staje sie zmierzonym faktem z nazwa wywolania.
#>
function Add-JezykDiagnostyke {
    param([string]$Nazwa, [long]$Ms)

    if ($Ms -lt $Script:ProgDiagnostykiMs) { return }

    $Script:DiagnostykaTla += '{0:HH:mm:ss}  {1}: {2} ms' -f (Get-Date), $Nazwa, $Ms
    if ($Script:DiagnostykaTla.Count -gt $Script:LimitDiagnostyki) {
        $Script:DiagnostykaTla = @($Script:DiagnostykaTla | Select-Object -Last $Script:LimitDiagnostyki)
    }

    # Przycisk "!" przy polu Status pokazuje ten slad, wiec ma sie pojawic TERAZ, a nie
    # dopiero przy nastepnym wyszukaniu. Wszystkie wywolania tej funkcji ida z watku
    # interfejsu, wiec dotkniecie kontrolki jest tu bezpieczne.
    $przycisk = $Script:Kontrolki['InfoStatus']
    if ($przycisk) { $przycisk.Visible = $true }
}

# Lista kontrolerow per domena, zapamietana z poprzedniego wyszukania. Nie jest to pamiec
# trwala - przy kazdym uruchomieniu pierwsze wyszukanie znow rozpoznaje kontrolery.
$Script:KontroleryCache = @{}

# Ostatni odczyt z AD - zrodlo prawdy dla operacji zapisu. Kontrolki sluza do pokazywania
# danych, nie do ich przenoszenia.
$Script:OstatnieKonto = $null

# Data przyblizona z ostatniego pokazanego konta. Trzymana osobno, bo potrzebuja jej oba
# etapy wypelniania pola, a drugi z nich (zegar) nie widzi juz obiektu wyniku.
$Script:LogowaniePrzyblizone = $null

<#
.SYNOPSIS
    Sklada tekst skryptu dla przestrzeni w tle. Wynik jest zapamietywany.

.DESCRIPTION
    Tekst zalezy wylacznie od definicji funkcji, a te sa stale przez cale zycie procesu -
    skladanie go przy kazdym klinieciu "Szukaj" bylo praca wykonywana od nowa po to, zeby
    otrzymac ten sam wynik.

    KOMPLET FUNKCJI JEST WARUNKIEM DZIALANIA: przestrzen startuje pusta, wiec funkcja
    pominieta na liscie konczy zadanie wyjatkiem "nie rozpoznano nazwy polecenia" WEWNATRZ
    przestrzeni, a wolajacy widzi tylko brak wyniku. Kolejnosc tez jest krytyczna - param()
    musi byc PIERWSZA instrukcja skryptu.
#>
function New-JezykSkryptTla {
    param([ValidateSet('Logowanie', 'Komputer', 'Uzytkownik', 'Ping')][string]$Zadanie)

    if ($Script:SkryptyTla.ContainsKey($Zadanie)) { return $Script:SkryptyTla[$Zadanie] }

    # KOMPLET zaleznosci obu zapytan do SCCM, policzony z ich tresci, a nie z pamieci.
    # Oba wchodza tam ta sama droga (sonda portu, sesja, zapytanie z droga zapasowa,
    # klasyfikacja bledu, przeliczenie czasu) i roznia sie WYLACZNIE funkcja wejsciowa,
    # wiec lista jest jedna - dwie kopie rozjechalyby sie przy pierwszej zmianie.
    $sccm = @('Test-JezykNazwaKonta', 'Test-JezykNazwaHosta',
              'Get-JezykSccmPolaczenie', 'Test-JezykPortOtwarty',
              'Get-JezykOpisBleduWmi', 'Open-JezykSesjaSccm',
              'Invoke-JezykZapytanieWmi', 'Invoke-JezykZapytanieWmiStare',
              'Invoke-JezykZapytanieSccm', 'ConvertTo-JezykCzasLokalny')

    if ($Zadanie -eq 'Ping') {
        # NAJLZEJSZE Z CZTERECH ZADAN: sama sonda ICMP na znanej juz nazwie maszyny.
        # Osobne, bo przycisk "Pinguj" ma sprawdzic dostepnosc PONOWNIE, nie powtarzac
        # calego zapytania do SCCM - tamto trwa sekundy i pytaloby o to samo, co juz wiadomo.
        $funkcje = 'Test-JezykNazwaHosta', 'Get-JezykPingKomputera'

        $naglowek  = 'param($Netbios)'
        $wywolanie = 'Get-JezykPingKomputera -Nazwa $Netbios'
    }
    elseif ($Zadanie -eq 'Logowanie') {
        $funkcje = 'Test-JezykNazwaHosta', 'Test-JezykDn',
                   'Get-JezykLastLogonZKontrolera', 'Invoke-JezykRownolegle',
                   'Get-JezykOstatnieLogowanie'

        # MODUL AD LADOWANY WARUNKOWO - to najdrozsza rzecz w calym wyszukiwaniu.
        # Import w swiezej przestrzeni trwa sekunde do trzech, a potrzebny jest tylko wtedy,
        # gdy trzeba rozpoznac kontrolery (Get-ADDomainController) albo skorzystac z drogi
        # zapasowej przez Get-ADUser. Sam odczyt lastLogon idzie surowym LDAP-em. Lista
        # kontrolerow jest pamietana, wiec od drugiego wyszukania importu nie ma wcale.
        $naglowek  = 'param($Login, $Domena, $Dn, $Kontrolery)'
        $naglowek += "`r`n" + 'if (-not $Dn -or @($Kontrolery).Count -eq 0) {' +
                     ' Import-Module ActiveDirectory -ErrorAction SilentlyContinue }'
        $wywolanie = 'Get-JezykOstatnieLogowanie -Login $Login -Domena $Domena -Dn $Dn -Kontrolery $Kontrolery'
    }
    elseif ($Zadanie -eq 'Komputer') {
        # Wejsciem jest droga OD LOGINU DO MASZYNY. Get-JezykPingKomputera dochodzi TYLKO
        # tutaj, a nie do wspolnej listy $sccm: droga odwrotna (uzytkownik maszyny) nie
        # pinguje niczego, a funkcja wstrzyknieta bez potrzeby to martwy kod w przestrzeni.
        $funkcje = $sccm + @('Get-JezykPingKomputera', 'Get-JezykOstatnioUzywanyKomputer')

        # Zadanie SCCM idzie przez WMI i modulu AD nie potrzebuje w ogole.
        $naglowek  = 'param($Login, $SccmSerwer, $SccmKodLokacji, $SccmProtokol, $SccmProtokolZapasowy)'
        $wywolanie = 'Get-JezykOstatnioUzywanyKomputer -Login $Login -Serwer $SccmSerwer' +
                     ' -KodLokacji $SccmKodLokacji -Protokol $SccmProtokol' +
                     ' -ProtokolZapasowy $SccmProtokolZapasowy'
    }
    else {
        # Wejsciem jest droga ODWROTNA: OD MASZYNY DO UZYTKOWNIKA.
        $funkcje = $sccm + @('Get-JezykUzytkownikKomputera')

        $naglowek  = 'param($Netbios, $SccmSerwer, $SccmKodLokacji, $SccmProtokol, $SccmProtokolZapasowy)'
        $wywolanie = 'Get-JezykUzytkownikKomputera -Netbios $Netbios -Serwer $SccmSerwer' +
                     ' -KodLokacji $SccmKodLokacji -Protokol $SccmProtokol' +
                     ' -ProtokolZapasowy $SccmProtokolZapasowy'
    }

    $definicje = ''
    foreach ($nazwa in $funkcje) {
        $definicje += "function $nazwa {`r`n" + (Get-Command $nazwa).Definition + "`r`n}`r`n"
    }

    $Script:SkryptyTla[$Zadanie] = $naglowek + "`r`n" + $definicje + $wywolanie + "`r`n"
    $Script:SkryptyTla[$Zadanie]
}

# Otwiera przestrzen uruchomieniowa z gotowym skryptem, jeszcze bez argumentow.
# MTA, bo tylko watek interfejsu musi byc STA. Przestrzen dostaje WYLACZNIE tekst -
# zadnych kontrolek ani obiektow interfejsu.
function New-JezykPrzestrzenTla {
    param([string]$Tresc)

    $przestrzen = [runspacefactory]::CreateRunspace()
    $przestrzen.ApartmentState = 'MTA'
    $przestrzen.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $przestrzen
    [void]$ps.AddScript($Tresc)

    [pscustomobject]@{ Ps = $ps; Przestrzen = $przestrzen }
}

# Uruchamia w tle obejscie kontrolerow domeny po dokladna date logowania.
function Start-JezykZadanieLogowania {
    param([string]$Login, [string]$Dn = '')

    Stop-JezykZadanieLogowania
    if (-not $Login) { return }

    $Script:PokolenieLogowania++
    $mojePokolenie = $Script:PokolenieLogowania
    $domena        = $Script:Config.Domena

    # Lista z konfiguracji ma pierwszenstwo; pusta = bierzemy zapamietana z poprzedniego
    # wyszukania, a gdy i jej nie ma, zadanie zapyta o nia katalog.
    $kontrolery = @($Script:Ustawienia.Kontrolery)
    if ($kontrolery.Count -eq 0) { $kontrolery = @($Script:KontroleryCache[$domena]) }

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Logowanie')
        [void]$zadanie.Ps.AddArgument($Login).
                          AddArgument($domena).
                          AddArgument($Dn).
                          AddArgument([string[]]$kontrolery)

        $Script:ZadanieLogowania = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Domena      = $domena
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania daty logowania' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        # Awaria uruchomienia nie moze przerwac pracy okna - konto jest juz pokazane,
        # a data przyblizona siedzi w polu.
        Set-JezykPoleLogowaniaBezTla
    }
}

# Uruchamia w tle zapytanie do SCCM o ostatnio uzywany komputer.
function Start-JezykZadanieKomputera {
    param([string]$Login)

    Stop-JezykZadanieKomputera
    if (-not $Login) { return }

    # Brak ustawien SCCM rozstrzygamy TUTAJ, przed zbudowaniem czegokolwiek: inaczej kazde
    # znalezione konto powolywaloby pelna przestrzen uruchomieniowa po odpowiedz znana
    # z gory. Wynik skladamy w ksztalcie, jaki oddaloby zadanie, i puszczamy przez te sama
    # funkcje renderujaca - dzieki temu nie ma drugiej sciezki wyswietlania.
    $polaczenie = Get-JezykSccmPolaczenie -Serwer     ([string]$Script:Ustawienia.SccmSerwer) `
                                          -KodLokacji ([string]$Script:Ustawienia.SccmKodLokacji) `
                                          -Protokol   ([string]$Script:Ustawienia.SccmProtokol)
    if ($polaczenie.Blad) {
        Update-JezykKomputerWTle -Komputer ([pscustomobject]@{
            Nazwa = ''; Data = $null; Blad = 'brak ustawień SCCM'; Szczegoly = $polaczenie.Blad })
        return
    }

    $Script:PokolenieKomputera++
    $mojePokolenie = $Script:PokolenieKomputera

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Komputer')
        [void]$zadanie.Ps.AddArgument($Login).
                          AddArgument([string]$Script:Ustawienia.SccmSerwer).
                          AddArgument([string]$Script:Ustawienia.SccmKodLokacji).
                          AddArgument([string]$Script:Ustawienia.SccmProtokol).
                          AddArgument([bool]$Script:Ustawienia.SccmProtokolZapasowy)

        $Script:ZadanieKomputera = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania SCCM' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        Set-JezykPoleKomputeraBezTla -Blad $_.Exception.Message
    }
}

# Uruchamia w tle zapytanie do SCCM o ostatnio zalogowanego uzytkownika podanej maszyny.
# Blizniacze do Start-JezykZadanieKomputera i z tego samego powodu: to zapytanie sieciowe,
# a policzone na watku interfejsu zamrozilo by okno na czas odpowiedzi SCCM.
function Start-JezykZadanieUzytkownika {
    param([string]$Netbios)

    Stop-JezykZadanieUzytkownika
    if (-not $Netbios) { return }

    # Brak ustawien SCCM rozstrzygamy TUTAJ, przed zbudowaniem czegokolwiek - tak samo jak
    # przy drodze odwrotnej. Wynik skladamy w ksztalcie, jaki oddaloby zadanie, i puszczamy
    # przez te sama funkcje renderujaca.
    $polaczenie = Get-JezykSccmPolaczenie -Serwer     ([string]$Script:Ustawienia.SccmSerwer) `
                                          -KodLokacji ([string]$Script:Ustawienia.SccmKodLokacji) `
                                          -Protokol   ([string]$Script:Ustawienia.SccmProtokol)
    if ($polaczenie.Blad) {
        Update-JezykUzytkownikaWTle -Uzytkownik ([pscustomobject]@{
            Uzytkownik = ''; Data = $null; Blad = 'brak ustawień SCCM'; Szczegoly = $polaczenie.Blad })
        return
    }

    $Script:PokolenieUzytkownika++
    $mojePokolenie = $Script:PokolenieUzytkownika

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Uzytkownik')
        [void]$zadanie.Ps.AddArgument($Netbios).
                          AddArgument([string]$Script:Ustawienia.SccmSerwer).
                          AddArgument([string]$Script:Ustawienia.SccmKodLokacji).
                          AddArgument([string]$Script:Ustawienia.SccmProtokol).
                          AddArgument([bool]$Script:Ustawienia.SccmProtokolZapasowy)

        $Script:ZadanieUzytkownika = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania SCCM (użytkownik maszyny)' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        Set-JezykPoleUzytkownikaBezTla -Blad $_.Exception.Message
    }
}

# Uruchamia w tle sonde ICMP na maszynie, ktora jest juz na ekranie - obsluga przycisku
# "Pinguj". Czwarte zadanie, a nie ponowienie zadania SCCM: tamto trwa sekundy i pytaloby
# o nazwe maszyny, ktora juz znamy. Wlasny licznik pokolen, bo operator potrafi kliknac
# dwa razy pod rzad, a spozniona odpowiedz pierwszej sondy pomalowalaby pole wynikiem
# nieaktualnym.
function Start-JezykZadaniePingu {
    param([string]$Netbios)

    Stop-JezykZadaniePingu
    if (-not $Netbios) { return }

    $Script:PokoleniePingu++
    $mojePokolenie = $Script:PokoleniePingu

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Ping')
        [void]$zadanie.Ps.AddArgument($Netbios)

        $Script:ZadaniePingu = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania pingu' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        # Nieudane uruchomienie zostawia stan "nie wiadomo", a nie czerwony napis: sonda
        # sie nie odbyla, wiec o maszynie nadal nic nie wiemy.
        Update-JezykPingWTle -Ping ([pscustomobject]@{
            Odpowiada = $null; Adres = ''; Blad = 'nie sprawdzono'; Szczegoly = $_.Exception.Message })
    }
}

# Odbiera wynik zadania daty logowania, jesli juz jest gotowy. Wynik z niezgodnego pokolenia
# jest odrzucany - dotyczylby konta, ktorego nie ma juz na ekranie.
function Receive-JezykZadanieLogowania {
    $zadanie = $Script:ZadanieLogowania
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($zadanie.Pokolenie -eq $Script:PokolenieLogowania -and $dane.Count -gt 0) {
            Update-JezykLogowanieWTle -Logowanie $dane[0] -Domena $zadanie.Domena
        }
    }
    catch {
        if ($zadanie.Pokolenie -eq $Script:PokolenieLogowania) { Set-JezykPoleLogowaniaBezTla }
    }
    finally { Stop-JezykZadanieLogowania }
}

# Odbiera wynik zadania SCCM, jesli juz jest gotowy.
function Receive-JezykZadanieKomputera {
    $zadanie = $Script:ZadanieKomputera
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($zadanie.Pokolenie -eq $Script:PokolenieKomputera -and $dane.Count -gt 0) {
            Update-JezykKomputerWTle -Komputer $dane[0]
        }
    }
    catch {
        if ($zadanie.Pokolenie -eq $Script:PokolenieKomputera) {
            Set-JezykPoleKomputeraBezTla -Blad $_.Exception.Message
        }
    }
    finally { Stop-JezykZadanieKomputera }
}

# Odbiera wynik zadania o uzytkowniku maszyny, jesli juz jest gotowy.
function Receive-JezykZadanieUzytkownika {
    $zadanie = $Script:ZadanieUzytkownika
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($zadanie.Pokolenie -eq $Script:PokolenieUzytkownika -and $dane.Count -gt 0) {
            Update-JezykUzytkownikaWTle -Uzytkownik $dane[0]
        }
    }
    catch {
        if ($zadanie.Pokolenie -eq $Script:PokolenieUzytkownika) {
            Set-JezykPoleUzytkownikaBezTla -Blad $_.Exception.Message
        }
    }
    finally { Stop-JezykZadanieUzytkownika }
}

# Odbiera wynik sondy ICMP z przycisku "Pinguj".
function Receive-JezykZadaniePingu {
    $zadanie = $Script:ZadaniePingu
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($zadanie.Pokolenie -eq $Script:PokoleniePingu -and $dane.Count -gt 0) {
            Update-JezykPingWTle -Ping $dane[0]
        }
    }
    catch {
        if ($zadanie.Pokolenie -eq $Script:PokoleniePingu) {
            Update-JezykPingWTle -Ping ([pscustomobject]@{
                Odpowiada = $null; Adres = ''; Blad = 'nie sprawdzono'; Szczegoly = $_.Exception.Message })
        }
    }
    finally { Stop-JezykZadaniePingu }
}

<#
.SYNOPSIS
    Przerywa i sprzata zadanie w tle - zakonczone albo porzucone w polowie.

.DESCRIPTION
    Zadanie ZAKONCZONE zwalniamy wprost. Zadanie PORZUCONE (ponowne klikniecie "Szukaj",
    zamkniecie okna) biegnie jeszcze w tle i trzyma otwarte polaczenie w kontekscie
    operatora, wiec prosimy o przerwanie - ale przez BeginStop, czyli ASYNCHRONICZNIE.
    Stop() jest blokujacy i zamrozilby okno na czas trwajacego zapytania.

    O PRZERWANIE PROSIMY DOKLADNIE RAZ. Przestrzen tkwiaca w wywolaniu, ktorego PowerShell
    nie umie przerwac (polaczenie DCOM z milczacym hostem jest tego wzorcowym przykladem),
    nie zatrzyma sie, dopoki to wywolanie samo nie odpusci - a kazda kolejna prosba
    o zatrzymanie zajmuje na ten czas watek z puli. Kilka takich prosb pod rzad wyczerpuje
    pule i okno przestaje odpowiadac. Znacznik Przerwane pilnuje, zeby prosba padla raz.

    Zwolnienia nie robimy od razu, bo przypadloby na moment, w ktorym przestrzen jest
    w trakcie zatrzymywania. Zadanie trafia na liste, ktora oprozia zegar.
#>
function Stop-JezykZadanieTla {
    param($Zadanie)

    if (-not $Zadanie) { return }

    if ($Zadanie.Uchwyt -and -not $Zadanie.Uchwyt.IsCompleted) {
        if (-not $Zadanie.Przerwane) {
            $Zadanie.Przerwane = $true
            $zegar = [System.Diagnostics.Stopwatch]::StartNew()
            try { [void]$Zadanie.Ps.BeginStop($null, $null) } catch { }
            Add-JezykDiagnostyke 'przerwanie porzuconego zadania (BeginStop)' $zegar.ElapsedMilliseconds
        }

        # Moment porzucenia, od ktorego liczy sie termin z Clear-JezykZadaniaPorzucone.
        if (-not $Zadanie.PorzuconeO) { $Zadanie.PorzuconeO = [datetime]::UtcNow }

        $Script:ZadaniaPorzucone += $Zadanie
        # Zegar musi chodzic, dopoki jest co zwalniac - to on jako jedyny przeglada liste.
        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
        return
    }

    $zegar = [System.Diagnostics.Stopwatch]::StartNew()
    try { $Zadanie.Ps.Dispose() }         catch { }
    try { $Zadanie.Przestrzen.Dispose() } catch { }
    Add-JezykDiagnostyke 'zwolnienie zakończonego zadania (Dispose)' $zegar.ElapsedMilliseconds
}

<#
.SYNOPSIS
    Zwalnia zadania w tle, ktore zdazyly sie juz zatrzymac - z obu list naraz.

.DESCRIPTION
    Wolane z zegara, czyli NA WATKU INTERFEJSU - nie ma tu wiec ani dostepu z obcego watku,
    ani wyscigu z zatrzymywaniem. I wlasnie dlatego lista porzuconych nie moze rosnac bez
    konca: przegladamy ja co cwierc sekundy.

    Zadanie, ktore po TERMINIE nadal sie nie zatrzymalo, schodzi z tej listy na liste
    SPISANYCH. Nie jest zwalniane od razu i nie moze byc: jego przestrzen tkwi
    w wywolaniu, ktorego nikt nie przerwie, a Dispose na takim obiekcie schodzi do
    zatrzymania SYNCHRONICZNEGO i zablokowalby okno - dokladnie to, czemu zadania w tle
    mialy zapobiegac. Ten zakaz obowiazuje bez wyjatku.

    ALE PRZESTAJEMY JE TRACIC. Wczesniej spisane zadanie znikalo z listy i nikt juz nigdy
    nie probowal go zwolnic, nawet gdy zawieszone wywolanie w koncu wracalo - przestrzen
    (przy dacie logowania z modulem AD w srodku) zostawala w pamieci do konca zycia
    procesu. Teraz czeka na drugiej liscie i zostaje zwolniona przy pierwszym przegladzie
    po tym, jak sie faktycznie zakonczy.

    Drugiej listy NIE trzymamy zegarem przy zyciu: zadanie, ktore nie odpuscilo przez dwie
    minuty, nie zglosi sie w nastepnej cwiartce sekundy, a chodzacy bez przerwy zegar
    kosztowalby wiecej niz zwloka. Przeglada sie ona razem z pierwsza, czyli przy okazji
    kazdego kolejnego wyszukiwania - a wlasnie wtedy pamiec zaczyna byc potrzebna.
#>
function Clear-JezykZadaniaPorzucone {

    $teraz = [datetime]::UtcNow

    # --- LISTA PIERWSZA: PORZUCONE, SPRAWDZANE CO TAKT ---------------------------------
    if (@($Script:ZadaniaPorzucone).Count -gt 0) {
        $zostaja = @()
        $spisane = 0

        foreach ($zadanie in @($Script:ZadaniaPorzucone)) {
            if ($zadanie.Uchwyt -and -not $zadanie.Uchwyt.IsCompleted) {

                $od = if ($zadanie.PorzuconeO) { ($teraz - $zadanie.PorzuconeO).TotalMilliseconds } else { 0 }
                if ($od -ge $Script:TerminPorzuconegoMs) {
                    $Script:ZadaniaSpisane += $zadanie
                    $spisane++
                    continue
                }

                $zostaja += $zadanie
                continue
            }

            $zegar = [System.Diagnostics.Stopwatch]::StartNew()
            try { $zadanie.Ps.Dispose() }         catch { }
            try { $zadanie.Przestrzen.Dispose() } catch { }
            Add-JezykDiagnostyke 'zwolnienie porzuconego zadania (Dispose)' $zegar.ElapsedMilliseconds
        }

        if ($spisane -gt 0) {
            Add-JezykDiagnostyke ('spisane po {0} s, czekaja na zakonczenie: {1}' -f
                                  [int]($Script:TerminPorzuconegoMs / 1000), $spisane) $Script:ProgDiagnostykiMs
        }

        $Script:ZadaniaPorzucone = $zostaja
    }

    # --- LISTA DRUGA: SPISANE, ZWALNIANE DOPIERO PO ZAKONCZENIU ------------------------
    if (@($Script:ZadaniaSpisane).Count -eq 0) { return }

    $czekaja = @()
    foreach ($zadanie in @($Script:ZadaniaSpisane)) {
        # WARUNEK JEST TU CALA OSTROZNOSCIA: Dispose wolamy WYLACZNIE na zadaniu, ktore
        # samo sie juz zakonczylo. Na biegnacym zablokowaloby watek interfejsu.
        if ($zadanie.Uchwyt -and -not $zadanie.Uchwyt.IsCompleted) { $czekaja += $zadanie; continue }

        $zegar = [System.Diagnostics.Stopwatch]::StartNew()
        try { $zadanie.Ps.Dispose() }         catch { }
        try { $zadanie.Przestrzen.Dispose() } catch { }
        Add-JezykDiagnostyke 'zwolnienie spisanego zadania (Dispose)' $zegar.ElapsedMilliseconds
    }

    # Sufit: powyzej niego wypadaja NAJSTARSZE, czyli te, ktore nie odpuscily najdluzej.
    # Dopiero one przepadaja bez zwolnienia - tak jak dawniej przepadaly wszystkie.
    if ($czekaja.Count -gt $Script:LimitSpisanych) {
        $ilePrzepada = $czekaja.Count - $Script:LimitSpisanych
        Add-JezykDiagnostyke ('spisane porzucone bez zwolnienia (sufit {0}): {1}' -f
                              $Script:LimitSpisanych, $ilePrzepada) $Script:ProgDiagnostykiMs
        $czekaja = @($czekaja | Select-Object -Last $Script:LimitSpisanych)
    }

    $Script:ZadaniaSpisane = $czekaja
}

# Przypisanie $null idzie PIERWSZE, zeby ponowne wejscie tutaj nie zabralo sie za ten sam
# obiekt drugi raz.
function Stop-JezykZadanieLogowania {
    if (-not $Script:ZadanieLogowania) { return }
    $zadanie = $Script:ZadanieLogowania
    $Script:ZadanieLogowania = $null
    Stop-JezykZadanieTla $zadanie
}

function Stop-JezykZadanieKomputera {
    if (-not $Script:ZadanieKomputera) { return }
    $zadanie = $Script:ZadanieKomputera
    $Script:ZadanieKomputera = $null
    Stop-JezykZadanieTla $zadanie
}

function Stop-JezykZadanieUzytkownika {
    if (-not $Script:ZadanieUzytkownika) { return }
    $zadanie = $Script:ZadanieUzytkownika
    $Script:ZadanieUzytkownika = $null
    Stop-JezykZadanieTla $zadanie
}

function Stop-JezykZadaniePingu {
    if (-not $Script:ZadaniePingu) { return }
    $zadanie = $Script:ZadaniePingu
    $Script:ZadaniePingu = $null
    Stop-JezykZadanieTla $zadanie
}

# Sprzatanie przy zamykaniu okna. Zatrzymanie zegara musi byc OSTATNIE: porzucenie
# trwajacego zadania dopisuje je do listy i samo URUCHAMIA zegar, wiec zatrzymany najpierw
# wstawalby z powrotem - w trakcie zamykania okna, gdy kontrolki sa juz zwalniane.
function Stop-JezykZadaniaTla {
    Stop-JezykZadanieLogowania
    Stop-JezykZadanieKomputera
    Stop-JezykZadanieUzytkownika
    Stop-JezykZadaniePingu

    # Ostatnie podejscie do porzuconych; reszta odchodzi razem z procesem.
    Clear-JezykZadaniaPorzucone

    if ($Script:ZegarTla) { $Script:ZegarTla.Stop() }
}

<#
.SYNOPSIS
    Buduje okno, wypelnia rejestr kontrolek i podpina zdarzenia.

.DESCRIPTION
    Rozmiar okna jest STALY i wyliczany z wymiaru wyzszego z widokow - dzieki temu okno nie
    skacze przy zmianie trybu. Widok komputera zostawia u dolu puste miejsce; to swiadoma cena.
#>
function New-JezykForm {

    # ClientSize, a nie Size: podajemy rozmiar obszaru roboczego, bez ramki i paska tytulu,
    # wiec wspolrzedne kontrolek zgadzaja sie niezaleznie od motywu Windows.
    $form                 = New-Object System.Windows.Forms.Form
    $form.Text            = $Script:Config.TytulOkna

    # DZIEWIEC WIERSZY (0-8). Osmy doszedl razem z polem "Adres IP" - pol polowkowych jest
    # jedenascie, czyli nieparzyscie, a trzy dolne potrzebuja calej szerokosci, wiec jedno
    # miejsce w siatce zostaje wolne i okno uroslo o jeden skok wiersza.
    $wysokoscPanelu = (Get-JezykWierszPole 8) + 40    # ostatnie pole + jego wysokosc + margines
    $wysokoscOkna   = $Script:PanelZListą + $wysokoscPanelu + 12 + $Script:PasekPodpisu
    $form.ClientSize      = [System.Drawing.Size]::new($Script:SzerokoscOkna, $wysokoscOkna)

    # SIATKA JEST WYZSZA O JEDEN WIERSZ NIZ PRZED DOLOZENIEM ADRESU IP, a wspolrzedne rosna
    # razem ze skalowaniem DPI. Przy 150% i ekranie 1080p okno moze nie zmiescic sie
    # w obszarze roboczym - i wtedy dolne pola byly by NIE DO OBEJRZENIA, bo rozmiar jest
    # staly, a kontrolki stoja na sztywnych wspolrzednych.
    #
    # AutoScroll jest zapora na ten przypadek i nie kosztuje nic, gdy okno sie miesci:
    # WinForms pokazuje pasek przewijania WYLACZNIE wtedy, gdy kontrolki wychodza poza
    # obszar roboczy okna. Wysokosc przycinamy do obszaru roboczego ekranu, zeby pasek mial
    # sie kiedy pojawic - bez tego okno po prostu wystawaloby poza ekran.
    #
    # Calosc pod try, bo to zabezpieczenie, nie warunek dzialania: gdyby odczyt rozmiaru
    # ekranu zawiodl, okno ma wystartowac w rozmiarze policzonym z siatki.
    $form.AutoScroll = $true
    try {
        $obszarEkranu = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height
        # Zapas na ramke okna i pasek tytulu - ClientSize ich nie obejmuje.
        $maksWysokosc = $obszarEkranu - 60
        if ($maksWysokosc -gt 200 -and $wysokoscOkna -gt $maksWysokosc) {
            $form.ClientSize = [System.Drawing.Size]::new($Script:SzerokoscOkna, $maksWysokosc)
        }
    }
    catch { }

    # Staly rozmiar, bo kontrolki sa pozycjonowane na sztywno i przy rozciaganiu zostalyby
    # w miejscu.
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $true
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen

    # MessageBoxFont zamiast zaszytego 'Segoe UI 9': to czcionka, ktorej system faktycznie
    # uzywa w oknach dialogowych - honoruje ustawienia uzytkownika i skalowanie DPI.
    # Ustawiona na formularzu, bo dzieci dziedzicza ja automatycznie.
    $form.Font            = [System.Drawing.SystemFonts]::MessageBoxFont

    # Ikona jest opcjonalna i celowo nie przerywa startu: brakujacy plik to drobiazg
    # kosmetyczny i nie moze przeszkodzic w sprawdzeniu konta.
    $plikIkony = Join-Path $Script:KatalogSkryptu 'Ikona-Jezyk.ico'
    if (Test-Path -LiteralPath $plikIkony) {
        try   { $form.Icon = [System.Drawing.Icon]::new($plikIkony, 32, 32) }
        catch { }
    }

    # --- WIERSZ DOMENY I WIERSZ WYSZUKIWANIA -----------------------------------------
    # Wspolny slupek na etykiety, zeby obie listy zaczynaly sie w tej samej wspolrzednej.
    $slupekEtykiet = 70
    $srodekDomeny  = 25
    $srodekPodaj   = 25 + $Script:PasekDomeny

    $lblDomena = New-JezykEtykieta 'Domena' $Script:Margines 0
    $lblPodaj  = New-JezykEtykieta 'Podaj'  $Script:Margines 0

    # Zmiana domeny przekierowuje wszystkie zapytania - wystarczy podmiana parametru -Server,
    # bo konto ma prawo odczytu we wszystkich domenach powiazanych zaufaniem.
    $cmbDomena               = New-Object System.Windows.Forms.ComboBox
    $cmbDomena.Left          = $slupekEtykiet
    $cmbDomena.Width         = 240
    $cmbDomena.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbDomena.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    $cmbDomena.BackColor     = $Script:Config.KolorKontrolki
    foreach ($d in $Script:Domeny) { [void]$cmbDomena.Items.Add($d) }
    $cmbDomena.SelectedIndex = 0

    # DropDownList, a nie DropDown: listy nie da sie edytowac, wiec tryb zawsze ma jedna ze
    # znanych wartosci. FlatStyle = Flat jest WARUNKIEM widocznosci koloru - przy wlaczonych
    # stylach wizualnych lista ignoruje BackColor, bo rysuje ja motyw systemu. Cena: kontrolka
    # traci wyglad systemowy.
    $cmbTryb               = New-Object System.Windows.Forms.ComboBox
    $cmbTryb.Left          = $slupekEtykiet
    $cmbTryb.Width         = 180
    $cmbTryb.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbTryb.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    $cmbTryb.BackColor     = $Script:Config.KolorKontrolki
    [void]$cmbTryb.Items.Add($Script:Config.TrybNazwa)
    [void]$cmbTryb.Items.Add($Script:Config.TrybKomputer)
    $cmbTryb.SelectedIndex = 0

    $przerwa = 16

    $btnSzukaj           = New-Object System.Windows.Forms.Button
    $btnSzukaj.Text      = 'Szukaj'
    $btnSzukaj.Width     = 96
    $btnSzukaj.Left      = $Script:Margines + $Script:SzerokoscPelna - $btnSzukaj.Width
    $btnSzukaj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSzukaj.BackColor = $Script:Config.KolorKontrolki
    $btnSzukaj.FlatAppearance.BorderColor = $Script:Config.KolorObramowki

    # Pole wypelnia to, co zostalo miedzy lista trybu a przyciskiem, wiec prawa krawedz
    # wiersza pokrywa sie z prawa krawedzia wszystkich pol nizej.
    $txtSzukaj           = New-Object System.Windows.Forms.TextBox
    $txtSzukaj.Left      = $cmbTryb.Right + $przerwa
    $txtSzukaj.Width     = $btnSzukaj.Left - $przerwa - $txtSzukaj.Left
    # Zabezpieczenie przed wklejeniem calego akapitu tekstu.
    $txtSzukaj.MaxLength = 256

    # Lista wyboru kont - widoczna wylacznie przy wyszukiwaniu czesciowym. DisplayMember
    # sprawia, ze pokazuje pole Opis, a kod ma pod reka caly obiekt kandydata.
    $cmbWynik               = New-Object System.Windows.Forms.ComboBox
    $cmbWynik.Location      = [System.Drawing.Point]::new($Script:Margines, 46 + $Script:PasekDomeny)
    $cmbWynik.Width         = $Script:SzerokoscPelna
    $cmbWynik.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbWynik.DisplayMember = 'Opis'
    $cmbWynik.Visible       = $false

    # --- PANEL: WIDOK KONTA ----------------------------------------------------------
    $pnlKonto      = New-Object System.Windows.Forms.Panel
    $pnlKonto.Size = [System.Drawing.Size]::new($Script:SzerokoscOkna, $wysokoscPanelu)

    # Werdykt: jedyna kontrolka, ktora zmienia kolor, i jedyna, ktorej tresc zalezy od stanu
    # konta. Wspolrzedna pionowa ustawiana jest przez wyrownanie na koncu tej funkcji.
    $chkWerdykt           = New-JezykCheckbox '' $Script:Margines 0 18
    $lblWerdykt           = New-JezykEtykieta 'Konto zablokowane' ($Script:Margines + 24) 0
    # Czcionka WYPROWADZONA z czcionki okna, a nie wpisana z nazwy - ma pozostac o punkt
    # wieksza i pogrubiona takze wtedy, gdy system uzywa innej czcionki dialogow.
    $lblWerdykt.Font      = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size + 1, [System.Drawing.FontStyle]::Bold)
    $lblWerdykt.ForeColor = $Script:Config.KolorNieznany

    # Jedyna czynna kontrolka w widoku i jedyna operacja zapisu w narzedziu.
    $btnOdblokuj           = New-Object System.Windows.Forms.Button
    $btnOdblokuj.Text      = 'Odblokuj konto'
    $btnOdblokuj.Width     = 130
    $btnOdblokuj.Height    = 26
    $btnOdblokuj.Left      = $Script:Margines + $Script:SzerokoscPelna - $btnOdblokuj.Width
    $btnOdblokuj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOdblokuj.BackColor = $Script:Config.KolorKontrolki
    $btnOdblokuj.FlatAppearance.BorderColor = $Script:Config.KolorObramowki
    $btnOdblokuj.Enabled   = $false

    # Siatka faktow, z ktorych powstaje werdykt. Trzy rowne kolumny, wyliczane - poprzednie
    # odstepy wpisane recznie widac bylo golym okiem.
    $grpFlagi          = New-Object System.Windows.Forms.GroupBox
    $grpFlagi.Text     = ''
    $grpFlagi.Location = [System.Drawing.Point]::new($Script:Margines, 32)
    $grpFlagi.Size     = [System.Drawing.Size]::new($Script:SzerokoscPelna, 56)

    # WSPOLRZEDNE SA TU ZEROWE CELOWO - nadaje je wyrownanie na koncu tej funkcji, tak samo
    # jak przy werdykcie nizej. Znacznik zwiezy sie tam do szerokosci swojego napisu, a nie
    # da sie go wysrodkowac w slupku, zanim ta szerokosc bedzie znana - a znana jest dopiero
    # po odziedziczeniu czcionki okna, czyli po dodaniu kontrolki do okna.
    $chkAktywne     = New-JezykCheckbox 'Konto aktywne'      0 0
    $chkZablokowane = New-JezykCheckbox 'Konto zablokowane'  0 0
    $chkFlagaHasla  = New-JezykCheckbox 'Flaga zmiany hasła' 0 0
    $grpFlagi.Controls.AddRange(@($chkAktywne, $chkZablokowane, $chkFlagaHasla))

    # --- SIATKA POL ------------------------------------------------------------------
    $L = $Script:Margines           # lewa kolumna
    $P = $Script:DrugaKolumna       # prawa kolumna
    $W = $Script:SzerokoscKolumny   # szerokosc kolumny
    $C = $Script:SzerokoscPelna     # cala szerokosc

    # Dane osobowe ida pierwsze - tozsamosc konta przed jego stanem technicznym.
    $lblLoginKonta   = New-JezykEtykieta 'Login:'           $L (Get-JezykWiersz 0)
    $txtLoginKonta   = New-JezykPole                        $L (Get-JezykWierszPole 0) $W
    $lblImieNazwisko = New-JezykEtykieta 'Imię i nazwisko:' $P (Get-JezykWiersz 0)
    $txtImieNazwisko = New-JezykPole                        $P (Get-JezykWierszPole 0) $W

    # Przyciski "!" - po jednym na pole, przy ktorym MOZE wystapic usterka. Powstaja
    # niewidoczne; pokazuje je Set-JezykInfo wylacznie wtedy, gdy dana funkcja faktycznie
    # nie dziala. Wspolrzedne dostaja na koncu tej funkcji, razem z calym wyrownaniem.
    #
    # ZOSTALY DWA, przy jedynych polach, ktore potrafia zglosic realna usterke. Odpadly:
    #   Domena, Ostatnie logowanie - stale wyjasnienia bez zwiazku z awaria,
    #   Odblokuj konto - powody wylaczenia przycisku ("najpierw znajdz konto", "konto nie
    #     jest zablokowane") to normalne stany, a nie bledy; wykrzyknik zapalal sie tam
    #     zaraz po starcie okna i przestawal cokolwiek znaczyc.
    # Get-JezykOpisKonfiguracji zostaje jako funkcja - jest kontrolna dla
    # Jezyk-1-Srodowisko.ps1 w Kod-Jezyk.ps1 - traci tylko podpiecie pod GUI.
    $btnInfoStatus   = New-JezykPrzyciskInfo 'Status'
    $btnInfoKomputer = New-JezykPrzyciskInfo 'Komputer'

    # Komputer stoi przy e-mailu, a nie przy dacie logowania: data pokazuje DWIE wartosci
    # naraz i nie miesci sie w kolumnie, a adres e-mail nigdy nie potrzebowal calej szerokosci.
    $lblEmail = New-JezykEtykieta 'E-mail:' $L (Get-JezykWiersz 1)
    $txtEmail = New-JezykPole                $L (Get-JezykWierszPole 1) $W
    # "Uzywany", a nie "zalogowany": SCCM podaje ostatniego uzytkownika maszyny wedlug
    # inwentaryzacji, a nie trwajaca sesje.
    #
    # POLE JEST KROTSZE OD KOLUMNY o miejsce na przycisk "Pinguj" - obie kontrolki dziela
    # ten sam wiersz, bo przycisk sprawdza dokladnie te maszyne, ktorej nazwa stoi obok.
    # Tresc pola bywa dluzsza niz jego szerokosc; to zwykle pole tekstowe, wiec przewija sie
    # samo, a caly napis da sie zaznaczyc i skopiowac.
    $szerokoscPingu = 72
    $przerwaPingu   = 8

    $lblKomputerUzytkownika = New-JezykEtykieta 'Ostatnio używany komputer:' $P (Get-JezykWiersz 1)
    $txtKomputerUzytkownika = New-JezykPole $P (Get-JezykWierszPole 1) `
                                            ($W - $szerokoscPingu - $przerwaPingu)

    # Jedyna czynna kontrolka poza "Odblokuj konto" - i jedyna, ktora nic nie zapisuje.
    # Nieczynny do momentu, w ktorym SCCM poda nazwe maszyny: bez niej nie ma czego pingowac.
    # TabStop wylaczony, jak przy przyciskach "!": wedrowka tabulatorem ma prowadzic przez
    # pola z danymi, a nie przez dodatki.
    $btnPinguj           = New-Object System.Windows.Forms.Button
    $btnPinguj.Text      = 'Pinguj'
    $btnPinguj.Width     = $szerokoscPingu
    $btnPinguj.Height    = 22
    $btnPinguj.Left      = $P + $W - $szerokoscPingu
    $btnPinguj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnPinguj.BackColor = $Script:Config.KolorKontrolki
    $btnPinguj.FlatAppearance.BorderColor = $Script:Config.KolorObramowki
    $btnPinguj.Enabled   = $false
    $btnPinguj.TabStop   = $false

    # ADRES IP W OSOBNYM POLU, DOKLADNIE POD NAZWA MASZYNY. Doklejony do pola obok
    # wypchnalby z niego date ostatniej aktywnosci, a w kolumnie nie ma miejsca na oba
    # napisy naraz. Pion pod komputerem mowi bez slowa, ktorej maszyny adres to jest.
    #
    # Lewa polowa tego wiersza zostaje pusta i jest to swiadoma cena: pol polowkowych jest
    # jedenascie, czyli nieparzyscie, a trzy pozostale potrzebuja calej szerokosci (dwie
    # daty logowania, sciezka katalogu, status). Jedno wolne miejsce musi wiec gdzies byc
    # i najmniej przeszkadza wlasnie tu.
    $lblKomputerIp = New-JezykEtykieta 'Adres IP:' $P (Get-JezykWiersz 2)
    $txtKomputerIp = New-JezykPole                 $P (Get-JezykWierszPole 2) $W

    $lblHasloWygasa    = New-JezykEtykieta 'Hasło wygasa:'          $L (Get-JezykWiersz 3)
    $txtHasloWygasa    = New-JezykPole                              $L (Get-JezykWierszPole 3) $W
    $lblKontoWygasa    = New-JezykEtykieta 'Konto wygasa:'          $P (Get-JezykWiersz 3)
    $txtKontoWygasa    = New-JezykPole                              $P (Get-JezykWierszPole 3) $W

    $lblOstatniaZmiana = New-JezykEtykieta 'Ostatnia zmiana hasła:' $L (Get-JezykWiersz 4)
    $txtOstatniaZmiana = New-JezykPole                              $L (Get-JezykWierszPole 4) $W
    $lblKontoUtworzono = New-JezykEtykieta 'Konto utworzono:'       $P (Get-JezykWiersz 4)
    $txtKontoUtworzono = New-JezykPole                              $P (Get-JezykWierszPole 4) $W

    # Dwie informacje "kontaktowe" w jednym wierszu: pod ktory numer zadzwonic i kogo
    # zapytac o zgode. Obie mieszcza sie w kolumnie, wiec nie zabieraja calej szerokosci.
    $lblTelefon  = New-JezykEtykieta 'Telefon:'  $L (Get-JezykWiersz 5)
    $txtTelefon  = New-JezykPole                 $L (Get-JezykWierszPole 5) $W
    $lblMenedzer = New-JezykEtykieta 'Przełożony:' $P (Get-JezykWiersz 5)
    $txtMenedzer = New-JezykPole                 $P (Get-JezykWierszPole 5) $W

    # Cala szerokosc, bo pole niesie dwie daty naraz.
    $lblOstatnieLogowanie = New-JezykEtykieta 'Ostatnie logowanie:' $L (Get-JezykWiersz 6)
    $txtOstatnieLogowanie = New-JezykPole                           $L (Get-JezykWierszPole 6) $C

    $lblKatalog = New-JezykEtykieta 'Katalog konta:' $L (Get-JezykWiersz 7)
    $txtKatalog = New-JezykPole                      $L (Get-JezykWierszPole 7) $C

    $lblStatus = New-JezykEtykieta 'Status:' $L (Get-JezykWiersz 8)
    $txtStatus = New-JezykPole               $L (Get-JezykWierszPole 8) $C

    $pnlKonto.Controls.AddRange(@(
        $chkWerdykt, $lblWerdykt, $btnOdblokuj, $grpFlagi,
        $lblLoginKonta, $txtLoginKonta, $lblImieNazwisko, $txtImieNazwisko,
        $lblEmail, $txtEmail,
        $lblHasloWygasa, $txtHasloWygasa, $lblKontoWygasa, $txtKontoWygasa,
        $lblOstatniaZmiana, $txtOstatniaZmiana, $lblKontoUtworzono, $txtKontoUtworzono,
        $lblTelefon, $txtTelefon, $lblMenedzer, $txtMenedzer,
        $lblOstatnieLogowanie, $txtOstatnieLogowanie,
        $lblKomputerUzytkownika, $txtKomputerUzytkownika, $btnInfoKomputer, $btnPinguj,
        $lblKomputerIp, $txtKomputerIp,
        $lblKatalog, $txtKatalog, $lblStatus, $txtStatus, $btnInfoStatus))

    # --- PANEL: WIDOK KOMPUTERA ------------------------------------------------------
    # Ten sam rytm co w widoku konta, tylko liczony od gory panelu.
    $kompWiersz0 = 6
    $kompWiersz1 = $kompWiersz0 + $Script:SkokWiersza
    $kompWiersz2 = $kompWiersz1 + $Script:SkokWiersza

    $pnlKomputer         = New-Object System.Windows.Forms.Panel
    # Wysokosc WYLICZANA z ostatniego wiersza, a nie wpisana: dolozenie kolejnego pola nie
    # wymaga wtedy przeliczania jej na piechote. Panel jest nizszy od panelu konta i tak ma
    # zostac - okno ma staly rozmiar, a widok komputera odpowiada na mniej pytan.
    $pnlKomputer.Size    = [System.Drawing.Size]::new($Script:SzerokoscOkna,
                                                     ($kompWiersz2 + $Script:OdstepPodEtykieta + 40))
    $pnlKomputer.Visible = $false

    $lblKompKatalog = New-JezykEtykieta 'Katalog komputera:' $Script:Margines $kompWiersz0
    $txtKompKatalog = New-JezykPole $Script:Margines ($kompWiersz0 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    # Droga ODWROTNA do pola "Ostatnio uzywany komputer" w widoku konta: tam z loginu
    # szukamy maszyny, tu z maszyny szukamy uzytkownika. Zrodlo to samo - inwentaryzacja
    # SCCM - wiec i tu przy etykiecie stoi przycisk "!" na wypadek jej milczenia.
    $lblKompUzytkownik = New-JezykEtykieta 'Ostatnio zalogowany użytkownik:' $Script:Margines $kompWiersz1
    $txtKompUzytkownik = New-JezykPole $Script:Margines ($kompWiersz1 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $btnInfoUzytkownik = New-JezykPrzyciskInfo 'Uzytkownik'

    $lblKompStatus  = New-JezykEtykieta 'Status:' $Script:Margines $kompWiersz2
    $txtKompStatus  = New-JezykPole $Script:Margines ($kompWiersz2 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    $pnlKomputer.Controls.AddRange(@($lblKompKatalog, $txtKompKatalog,
                                     $lblKompUzytkownik, $txtKompUzytkownik, $btnInfoUzytkownik,
                                     $lblKompStatus, $txtKompStatus))

    # Podpis autora lezy POZA panelami, wiec widac go w obu trybach.
    $lblAutor           = New-JezykEtykieta ('Autor: ' + $Script:Config.Autor) $Script:Margines ($wysokoscOkna - 20)
    $lblAutor.ForeColor = $Script:Config.KolorNieznany
    $lblAutor.Font      = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size - 1)

    $form.Controls.AddRange(@($lblDomena, $cmbDomena, $lblPodaj, $cmbTryb,
                              $txtSzukaj, $btnSzukaj, $cmbWynik,
                              $pnlKonto, $pnlKomputer, $lblAutor))

    # --- WYROWNANIE W PIONIE ---------------------------------------------------------
    # CALE wyrownanie stoi TUTAJ, po dodaniu kontrolek do okna, i nie da sie go przeniesc
    # wyzej: kontrolka dziedziczy czcionke okna dopiero w momencie dodania, wiec kazdy pomiar
    # tekstu zrobiony wczesniej mierzylby czcionke domyslna.
    Set-JezykSrodekTekstu $lblDomena $cmbDomena.Height
    Set-JezykSrodekTekstu $lblPodaj  $cmbTryb.Height
    Set-JezykSrodekPionowy @($lblDomena, $cmbDomena) $srodekDomeny
    Set-JezykSrodekPionowy @($lblPodaj, $cmbTryb, $txtSzukaj, $btnSzukaj) $srodekPodaj

    # Zapas nad wysokoscia tekstu jest konieczny: kwadrat ma stale 13 px i w ciasnym
    # prostokacie nie miescil sie razem z napisem.
    $wysokoscZnacznika = [int][math]::Ceiling($form.Font.GetHeight()) + 8
    foreach ($znacznik in @($chkAktywne, $chkZablokowane, $chkFlagaHasla)) {
        Set-JezykSrodekTekstu $znacznik $wysokoscZnacznika
    }

    # TRZY ZNACZNIKI WYSRODKOWANE, KAZDY W SWOJEJ TRZECIEJ CZESCI RAMKI. Wczesniej staly
    # w trzech slupkach liczonych od stalego lewego marginesu, wiec cala trojka byla
    # docisnieta do lewej krawedzi, a po prawej zostawalo kilkadziesiat pikseli pustki.
    #
    # MIARY Z DisplayRectangle, A NIE Z Size. GroupBox rezerwuje u gory pasek na tytul
    # (nawet pusty) i ma wlasna ramke, wiec dopiero DisplayRectangle podaje prawdziwe
    # wnetrze. To ta sama zasada, co przy Set-JezykSrodekPionowy: pytamy kontrolke o jej
    # rzeczywiste wymiary, zamiast wpisywac liczby, ktore zgadzaja sie tylko przy 100% DPI.
    $obszarFlag = $grpFlagi.DisplayRectangle

    Set-JezykSrodekWSlupkach @($chkAktywne, $chkZablokowane, $chkFlagaHasla) `
                             $obszarFlag.Left $obszarFlag.Width

    # Pion tez z wnetrza ramki, a nie ze stalej: wysokosc znacznika liczy sie z czcionki,
    # wiec wpisana na sztywno wspolrzedna rozjezdzala sie przy skalowaniu DPI.
    Set-JezykSrodekPionowy @($chkAktywne, $chkZablokowane, $chkFlagaHasla) `
                           ($obszarFlag.Top + [int]($obszarFlag.Height / 2))

    # Przy werdykcie rownanie idzie w druga strone: napis jest wiekszy od reszty okna, wiec
    # to KWADRAT dostaje jego wysokosc.
    $wysokoscWerdyktu = $lblWerdykt.PreferredSize.Height + 4
    Set-JezykSrodekTekstu $lblWerdykt $wysokoscWerdyktu $Script:NajdluzszyWerdykt
    Set-JezykSrodekTekstu $chkWerdykt $wysokoscWerdyktu

    Set-JezykSrodekPionowy @($chkWerdykt, $lblWerdykt, $btnOdblokuj) $Script:SrodekWerdyktu

    # --- PRZYCISKI "!" ---------------------------------------------------------------
    # Stawiane NA SAMYM KONCU wyrownania, bo licza sie z rzeczywistej szerokosci etykiet,
    # a te znaja swoja szerokosc dopiero po odziedziczeniu czcionki okna - i po tym, jak
    # wyrownanie wyzej poprzestawialo im wspolrzedne pionowe.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik)) {
        # Czcionka wyprowadzona z czcionki okna, jak przy werdykcie: wykrzyknik ma byc
        # pogrubiony takze wtedy, gdy system uzywa innej czcionki dialogow.
        $info.Font = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size, [System.Drawing.FontStyle]::Bold)
    }

    # Przycisk "Pinguj" srodkuje sie w pionie na polu, ktore opisuje. Wysokosc pola liczy
    # sie z czcionki, wiec pomiar musi byc TUTAJ, po dodaniu kontrolek do okna.
    Set-JezykSrodekPionowy @($btnPinguj) `
        ($txtKomputerUzytkownika.Top + [int]($txtKomputerUzytkownika.Height / 2))

    Set-JezykPrzyciskPrzyEtykiecie $btnInfoKomputer   $lblKomputerUzytkownika
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoStatus     $lblStatus
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoUzytkownik $lblKompUzytkownik

    # Enter w dowolnym miejscu okna dziala jak klikniecie "Szukaj".
    $form.AcceptButton = $btnSzukaj

    # Rejestr kontrolek musi zostac wypelniony PRZED podpieciem zdarzen, bo procedury obslugi
    # siegaja wylacznie tutaj - powod opisany przy $Script:Kontrolki w SEKCJI 1.
    $Script:Kontrolki = @{
        Okno          = $form
        Domena        = $cmbDomena
        Tryb          = $cmbTryb
        PoleSzukaj    = $txtSzukaj
        Przycisk      = $btnSzukaj
        ListaKont     = $cmbWynik
        PanelKonto    = $pnlKonto
        PanelKomputer = $pnlKomputer

        WerdyktBox        = $chkWerdykt
        Werdykt           = $lblWerdykt
        ChkAktywne        = $chkAktywne
        ChkZablokowane    = $chkZablokowane
        ChkFlagaHasla     = $chkFlagaHasla
        TxtHasloWygasa    = $txtHasloWygasa
        TxtKontoWygasa    = $txtKontoWygasa
        TxtOstatniaZmiana = $txtOstatniaZmiana
        TxtKontoUtworzono = $txtKontoUtworzono
        TxtLoginKonta     = $txtLoginKonta
        # Etykieta pierwszego pola jest JEDYNA, ktora zmienia tresc w trakcie dzialania:
        # konto ma "Login:", kontakt "Nazwa:" - bo kontakt loginu nie ma.
        EtykietaLoginKonta = $lblLoginKonta
        TxtImieNazwisko   = $txtImieNazwisko
        TxtEmail          = $txtEmail
        TxtTelefon        = $txtTelefon
        TxtMenedzer       = $txtMenedzer
        PrzyciskOdblokuj       = $btnOdblokuj
        TxtOstatnieLogowanie   = $txtOstatnieLogowanie
        TxtKomputerUzytkownika = $txtKomputerUzytkownika
        TxtKomputerIp          = $txtKomputerIp
        PrzyciskPinguj         = $btnPinguj
        TxtKatalog        = $txtKatalog
        TxtStatus         = $txtStatus

        TxtKomputerKatalog = $txtKompKatalog
        TxtKomputerStatus  = $txtKompStatus
        # Nazwa celowo inna niz TxtKomputerUzytkownika: tamto pole jest w widoku KONTA
        # i niesie MASZYNE, to jest w widoku KOMPUTERA i niesie UZYTKOWNIKA. Podobne
        # nazwy juz raz kusily, zeby wpisac wynik nie w to pole, co trzeba.
        TxtKomputerUzytkownikMaszyny = $txtKompUzytkownik

        # Przyciski "!". Klucze celowo nazwane "Info" + klucz z Set-JezykInfo - ta funkcja
        # skleja nazwe sama, wiec dolozenie kolejnego pola nie wymaga jej edycji.
        InfoStatus     = $btnInfoStatus
        InfoKomputer   = $btnInfoKomputer
        InfoUzytkownik = $btnInfoUzytkownik
    }

    # --- ZDARZENIA -------------------------------------------------------------------
    # W scriptblockach NIE MA odwolan do zmiennych lokalnych tej funkcji - te przestana
    # istniec, zanim zdarzenie sie wydarzy.
    $btnSzukaj.Add_Click({ Invoke-JezykSearch })

    $zegar          = New-Object System.Windows.Forms.Timer
    $zegar.Interval = 250
    $zegar.Add_Tick({
        # Kazde zadanie sprawdzane niezaleznie - wolniejsze nie wstrzymuje szybszego.
        Receive-JezykZadanieLogowania
        Receive-JezykZadanieKomputera
        Receive-JezykZadanieUzytkownika
        Receive-JezykZadaniePingu

        Clear-JezykZadaniaPorzucone

        # Zegar chodzi tylko dopoki jest na co czekac ALBO co zwolnic.
        #
        # $Script:ZadaniaSpisane CELOWO NIE MA W TYM WARUNKU. Zadanie, ktore nie odpuscilo
        # przez dwie minuty, nie zglosi sie w nastepnej cwiartce sekundy - trzymanie dla
        # niego zegara przy zyciu znaczyloby budzenie watku interfejsu cztery razy na
        # sekunde przez cala reszte dnia. Spisane doczekaja nastepnego wyszukiwania: ono
        # uruchamia zadanie w tle, zegar rusza i przy pierwszym takcie je zwalnia.
        if (-not $Script:ZadanieLogowania -and -not $Script:ZadanieKomputera -and
            -not $Script:ZadanieUzytkownika -and -not $Script:ZadaniePingu -and
            @($Script:ZadaniaPorzucone).Count -eq 0) {
            $Script:ZegarTla.Stop()
        }
    })
    $Script:ZegarTla = $zegar

    # Bez sprzatania proces potrafi zostac w pamieci, czekajac na przestrzen uruchomieniowa,
    # ktorej nikt juz nie odbierze.
    $form.Add_FormClosing({ Stop-JezykZadaniaTla })

    # Jedna procedura dla WSZYSTKICH przyciskow "!". Klucz pola przychodzi z Tag klikanego
    # przycisku - procedury zdarzen nie widza zmiennych lokalnych tej funkcji, a $this jest
    # kontrolka, ktora zdarzenie zglosila.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik)) {
        $info.Add_Click({ Show-JezykInformacja ([string]$this.Tag) })
    }

    $cmbDomena.Add_SelectedIndexChanged({
        $Script:Config.Domena = [string]$Script:Kontrolki.Domena.SelectedItem
        # Kontrolery innej domeny to inne maszyny - zapamietana lista przestaje obowiazywac.
        $Script:KontroleryCache = @{}
        # Set-JezykWidok czysci widok, a czyszczenie gasi przycisk odblokowania - nie ma
        # wiec powodu przeliczac go tu osobno.
        Set-JezykWidok
    })

    $btnOdblokuj.Add_Click({ Invoke-JezykOdblokowanie })
    $btnPinguj.Add_Click({ Invoke-JezykPing })

    $cmbTryb.Add_SelectedIndexChanged({ Set-JezykWidok })
    $cmbWynik.Add_SelectedIndexChanged({ Invoke-JezykWyborKonta })

    # Focus() wywolany wczesniej nie zadziala - okna jeszcze nie widac.
    $form.Add_Shown({ $Script:Kontrolki.PoleSzukaj.Focus() })

    $form
}

#endregion
