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

# ZADNEGO WLASNEGO PASA NA WSKAZNIK PRACY. Pasek postepu mial tu kiedys swoje dziesiec
# pikseli pod wierszem wyszukiwania; zastapil go jez, ktory stoi w miejscu JUZ PUSTYM -
# w prawej, niezajetej czesci wiersza domeny (patrz sekcja JEZ nizej). Dlatego panele
# wracaja do wspolrzednych sprzed paska i okno jest o te dziesiec pikseli nizsze.
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

# --- JEZ, KTORY MOWI, ZE OKNO PRACUJE ------------------------------------------------
# Wskaznik pracy okna. Stal tu kiedys pasek Marquee we wlasnym pasie pod wierszem
# wyszukiwania; jez zajmuje miejsce, ktore BYLO JUZ PUSTE - prawa, niezajeta czesc
# wiersza domeny, dokladnie nad polem wyszukiwania i przyciskiem "Szukaj". Dlatego
# nie kosztowal ani jednej wspolrzednej i nie zabral miejsca zadnemu sasiadowi.
#
# RUSZA SIE NAPRAWDE TYLKO PRZY WYSZUKIWANIU PO NUMERZE TELEFONU. Klatki odmierza zegar
# na watku interfejsu, a przy zapytaniu synchronicznym ten watek stoi w zapytaniu - jez
# jest wtedy widoczny, ale NIERUCHOMY, dokladnie jak wczesniej pasek. Numer telefonu
# jest jedynym zapytaniem, ktore zeszlo do przestrzeni w tle. Nie obiecuj animacji tam,
# gdzie jej nie bedzie.

# Sprite wyprowadzony z Ikona-Jezyk.ico (wariant 24x24) RAZ, przy pisaniu kodu: odsianie
# granatowego tla i zielonego glifu terminala, zalanie przezroczystosci od krawedzi (zeby
# oko nie wypadlo jako dziura), przyciecie do ramki i cztery odcienie po jasnosci.
#
# PROGRAM NIGDY NIE CZYTA .ico NA POTRZEBY ANIMACJI - mapa siedzi tutaj, wiec brak pliku
# ikony nadal niczego nie psuje, tak samo jak przed ta zmiana.
#
# Jez patrzy w prawo, wiec biegnie w prawo i nie trzeba go odbijac. Znak '.' znaczy
# "nie rysuj nic" - tlo okna ma w tym miejscu przeswitywac.
#
# NAJJASNIEJSZY ODCIEN TO '*', A NIE 'O'. Klucze hashtable w PowerShellu NIE ROZROZNIAJA
# WIELKOSCI LITER, wiec 'o' i 'O' to ten sam klucz i paleta nie dala sie w ogole wczytac
# ("Duplicate keys"). Zapora: Weryfikacja/testy-uklad.ps1.
$Script:MapaJeza = @(
    '.........#.##........'
    '......########.......'
    '....############.....'
    '..###############....'
    '..################...'
    '.#################...'
    '.#################...'
    '###########++#+o+#...'
    '###########+#oo**o#..'
    '############o*o+o*#..'
    '###########+o*o#+*o#.'
    '###########oooo#+*o##'
    '###########+ooo*ooo#.'
    '##########+ooooo+###.'
    '.########++oo++##....'
    '..#########+o+##.....'
    '..#####+####++###....'
    '.......###..###.#....'
)

# KOLORY TU, PEDZLE NIE - i to nie jest kosmetyka. System.Drawing.SolidBrush RZUCA
# WYJATKIEM pod pwsh na macOS, a zestaw weryfikacyjny dolacza ten plik kropka: pedzel
# zalozony na poziomie skryptu wywrocilby CALY zestaw, zanim ruszyloby pierwsze
# sprawdzenie. Color::FromArgb jest czysta struktura i dziala wszedzie, wiec paleta
# moze tu stac. Pedzle powstaja leniwie w Set-JezykRysunekJeza, ktore wola wylacznie
# procedura Paint - a tej zestaw nie wykonuje nigdy.
# JABLKO, ktore jez dostaje po udanym wyszukaniu. Nakladka na sylwetke, a NIE osobna
# mapa osiemnastowierszowa: druga kopia jeza rozjechalaby sie z pierwsza przy pierwszej
# zmianie rysunku. Ogonek bierze '#', a polysk '*' - oba kolory juz sa, wiec paleta rosnie
# tylko o czerwien, jej cien i listek.
#
# MIERZ JE W PIKSELACH EKRANU, A NIE W KRATKACH MAPY. Komorka sprite'u ma przy 100% DPI
# dokladnie JEDEN piksel (pas jest wysoki na tyle, co lista domen), wiec caly jez zajmuje
# 21 na 18 pikseli. Pierwsze jablko (6 na 7 kratek) bylo w oknie prawie niewidoczne, a nawet
# po powiekszeniu do 8 na 9 wciaz bylo za male. DZIESIEC NA DZIESIEC TO GRANICA, NIE
# PRZYPADEK: kolumny 1-10 (z 21) i wiersze 0-9 (z 18) siedza CALE przed kolumna 11, w ktorej
# zaczyna sie pysk - jablko szersze albo wyzsze zaczeloby zjadac oko i policzek jeza.
$Script:MapaJablka = @(
    '....#.....'
    '..zzz#....'
    '.cccwwccc.'
    'ccccccc**c'
    'cccccccc*c'
    'cccccccccc'
    'cccccccccc'
    'cccccccccc'
    '.cccccccc.'
    '..cccccc..'
)

# Gdzie jablko siada na jezu - na zadzie, miedzy kolcami.
$Script:JablkoWiersz  = 0
$Script:JablkoKolumna = 1

$Script:PaletaJeza = @{
    '#' = [System.Drawing.Color]::FromArgb(60, 25, 4)      # kolce, oko, lapy, ogonek jablka
    '+' = [System.Drawing.Color]::FromArgb(147, 93, 37)    # cien na pysku
    'o' = [System.Drawing.Color]::FromArgb(215, 141, 62)   # pysk
    '*' = [System.Drawing.Color]::FromArgb(237, 176, 101)  # rozjasnienia, polysk jablka
    'c' = [System.Drawing.Color]::FromArgb(198, 48, 42)    # czerwien jablka
    'w' = [System.Drawing.Color]::FromArgb(146, 26, 26)    # cien jablka
    'z' = [System.Drawing.Color]::FromArgb(94, 148, 58)    # listek
}

$Script:PedzleJeza = $null   # bufor pedzli, zakladany przy pierwszym rysowaniu
$Script:ZegarJeza  = $null   # zegar animacji - OSOBNY od $Script:ZegarTla
$Script:KlatkaJeza = 0       # licznik klatek, zerowany przy KAZDYM ZAPALENIU, ale nie przy pozie
$Script:StanJeza   = 'Ukryty'   # Ukryty | Szuka | Jablko | NaPlecach

$Script:TaktJeza = 60        # ms miedzy klatkami, czyli okolo 16 klatek na sekunde
$Script:KrokJeza = 6         # pikseli na klatke, mnozone przez rozmiar komorki

<#
.SYNOPSIS
    Rysunek jeza dla zadanego stanu - gotowa mapa znakow, bez GDI.

.DESCRIPTION
    NA PLECACH TO ODBICIE W PIONIE, A NIE OBROT O 180 STOPNI. Jez ma zostac zwrocony w te
    sama strone, co przy biegu - kolce maja lezec na ziemi, a lapy sterczec do gory.
    Obrot odwrocilby go takze w poziomie i wygladalby jak inne zwierze.

    SAMO ODBICIE NIE WYSTARCZA. Lapy zostawaly w tym samym ciemnym odcieniu, co grzbiet,
    i przy osiemnastu pikselach wysokosci zlewaly sie z sylwetka - poza czytala sie jak
    "jez z odchylona glowa", a nie jak "jez na plecach". Rysujemy je wiec na dwa piksele
    i w jasnym odcieniu brzucha, zeby odcialy sie od kolcow.

    JABLKO NAKLADAMY NA KOPIE, I TO NIE JEST OSTROZNOSC NA WYROST. Napisy w PowerShellu sa
    niezmienne, ale TABLICA juz nie: podmiana wiersza w $Script:MapaJeza zatrulaby biegnacego
    jeza na cala reszte sesji, a zobaczylby to dopiero ktos przy DRUGIM wyszukiwaniu. Rzutowanie
    na [string[]] alokuje nowa tablice - @() wokol istniejacej tablicy tego NIE gwarantuje.

    Wszystkie pozy maja te same wymiary, co $Script:MapaJeza. Na tym stoi cala arytmetyka
    klatki, ktora szerokosc jeza liczy raz. Pilnuje tego Weryfikacja/testy-uklad.ps1.
#>
function Get-JezykSpriteJeza {
    param([ValidateSet('Ukryty', 'Szuka', 'Jablko', 'NaPlecach')][string]$Stan)

    if ($Stan -eq 'NaPlecach') {
        $ostatni    = @($Script:MapaJeza).Count - 1
        $odwrocona  = [string[]]($Script:MapaJeza[$ostatni..0])

        # Lapy to slad ostatniego wiersza sylwetki, czyli wlasnie te, po ktorych jez chodzil.
        $lapy = $odwrocona[0] -replace '[^.]', 'o'
        $odwrocona[0] = $lapy
        $odwrocona[1] = $lapy
        return @($odwrocona)
    }

    if ($Stan -ne 'Jablko') { return @($Script:MapaJeza) }

    $sprite = [string[]]@($Script:MapaJeza)
    for ($w = 0; $w -lt @($Script:MapaJablka).Count; $w++) {
        $wiersz   = $Script:JablkoWiersz + $w
        $linia    = $sprite[$wiersz]
        $nakladka = $Script:MapaJablka[$w]
        for ($k = 0; $k -lt $nakladka.Length; $k++) {
            # '.' w nakladce znaczy "tu jablka nie ma" - kolce maja zostac widoczne.
            if ($nakladka[$k] -eq '.') { continue }
            $kolumna = $Script:JablkoKolumna + $k
            $linia = $linia.Substring(0, $kolumna) + $nakladka[$k] + $linia.Substring($kolumna + 1)
        }
        $sprite[$wiersz] = $linia
    }
    @($sprite)
}

<#
.SYNOPSIS
    Gdzie i jak duzy stoi jez w zadanej klatce - czysta arytmetyka, bez GDI.

.DESCRIPTION
    CALA ARYTMETYKA JEST TUTAJ, A NIE W RYSOWANIU, I TO NIE JEST PORZADKOWANIE. Graphics
    i SolidBrush nie istnieja pod pwsh na macOS, wiec funkcji rysujacej zestaw weryfikacyjny
    nie wykona nigdy - liczba schowana w jej wnetrzu nie bylaby sprawdzona ani razu.
    Rysowanie dostaje gotowe wspolrzedne i samo niczego nie liczy.

    ROZMIAR KOMORKI PRZEZ [Math]::Floor, A NIE [int]. [int] w PowerShellu ZAOKRAGLA
    (bankiersko), wiec przy pasie 30 px i osiemnastu wierszach mapy dalby 2 zamiast 1
    i jez wystawalby poza pas gora i dolem.

    DROGA OBEJMUJE SZEROKOSC JEZA, zeby wybiegl CALY za prawa krawedz, zanim wroci
    z lewej. Bez tego znikalby w polowie kroku, uciety krawedzia pasa.

    PODSKOK NIE MOZE PRZEKROCZYC ZAPASU nad jezem. Przy pasie akurat tak wysokim, jak mapa,
    kolysanie wypchneloby go poza gorna krawedz i obcieloby mu kolce.

    POZA Z WYNIKIEM ZOSTAJE TAM, GDZIE JEZ SKONCZYL BIEC - ale PRZYCIETA do pasa, i bez tego
    przyciecia byloby jej nie widac wcale. Klatka zerowa stoi CALA za lewa krawedzia (jez ma
    z niej dopiero wbiec), a wyszukanie po nazwisku trwa ulamek sekundy i zegar animacji nie
    tyka ani razu - wiec kazda poza po zapytaniu synchronicznym siedzialaby poza pasem.

    PRZYCINAMY OD GORY, POTEM OD DOLU. Odwrotna kolejnosc daje liczbe UJEMNA, gdy pas jest
    wezszy od jeza: gorna granica jest wtedy sama w sobie ujemna.
#>
function Get-JezykKlatkaJeza {
    param([int]$Numer, [int]$Szerokosc, [int]$Wysokosc,
          [ValidateSet('Ukryty', 'Szuka', 'Jablko', 'NaPlecach')][string]$Stan = 'Szuka')

    $wierszy = @($Script:MapaJeza).Count
    if ($wierszy -eq 0 -or $Szerokosc -le 0 -or $Wysokosc -le 0) { return $null }

    $komorka = [int][Math]::Floor($Wysokosc / $wierszy)
    if ($komorka -lt 1) { $komorka = 1 }

    $szerokoscJeza = $Script:MapaJeza[0].Length * $komorka
    $krok  = $Script:KrokJeza * $komorka
    $droga = $Szerokosc + $szerokoscJeza

    # Kolysanie o jedna komorke co dwie klatki - tyle wystarczy, zeby czytalo sie jako
    # bieg, a nie jako przesuwany obrazek.
    $zapas   = $Wysokosc - $wierszy * $komorka
    $podskok = if (($Numer % 4) -lt 2) { 0 } else { 1 }
    if ($podskok -gt $zapas) { $podskok = $zapas }

    # Start caly za lewa krawedzia: jez ma WBIEC w pas, a nie mrugnac w jego srodku.
    $x = (($Numer * $krok) % $droga) - $szerokoscJeza

    if ($Stan -ne 'Szuka') {
        # Jez stoi z wynikiem: nie kolysze sie i nie wychodzi poza pas.
        $podskok = 0
        $prawa = $Szerokosc - $szerokoscJeza
        if ($x -gt $prawa) { $x = $prawa }
        if ($x -lt 0)      { $x = 0 }
    }

    [pscustomobject]@{
        Komorka = $komorka
        X       = $x
        # Jez stoi na dnie pasa, a podskok unosi go o jedna komorke.
        Y       = $zapas - $podskok
    }
}

<#
.SYNOPSIS
    Rysuje jeza na podanej powierzchni - jedyne miejsce w programie, ktore siega po GDI.

.DESCRIPTION
    NIC TU NIE LICZYMY - wspolrzedne przychodza gotowe z Get-JezykKlatkaJeza. Ta funkcja
    nie wykona sie w zestawie weryfikacyjnym ani razu, wiec kazda liczba schowana w jej
    wnetrzu bylaby liczba niesprawdzona.

    Pedzle zakladamy leniwie i trzymamy w $Script:PedzleJeza: przy szesnastu klatkach na
    sekunde nie ma po co powolywac ich od nowa, a zyja i tak tyle, co okno.
#>
function Set-JezykRysunekJeza {
    param($Grafika, [int]$Szerokosc, [int]$Wysokosc)

    $klatka = Get-JezykKlatkaJeza -Numer $Script:KlatkaJeza -Szerokosc $Szerokosc `
                                  -Wysokosc $Wysokosc -Stan $Script:StanJeza
    if (-not $klatka) { return }

    $sprite = @(Get-JezykSpriteJeza -Stan $Script:StanJeza)

    if (-not $Script:PedzleJeza) {
        $Script:PedzleJeza = @{}
        foreach ($znak in $Script:PaletaJeza.Keys) {
            $Script:PedzleJeza[$znak] = [System.Drawing.SolidBrush]::new($Script:PaletaJeza[$znak])
        }
    }

    # Piksel-art ma byc ostry - wygladzanie rozmyloby krawedzie komorek.
    $Grafika.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

    for ($w = 0; $w -lt $sprite.Count; $w++) {
        $linia = $sprite[$w]
        for ($k = 0; $k -lt $linia.Length; $k++) {
            $pedzel = $Script:PedzleJeza[[string]$linia[$k]]
            if (-not $pedzel) { continue }   # '.' - w tym miejscu ma byc widac tlo okna
            $Grafika.FillRectangle($pedzel,
                                   $klatka.X + $k * $klatka.Komorka,
                                   $klatka.Y + $w * $klatka.Komorka,
                                   $klatka.Komorka, $klatka.Komorka)
        }
    }
}

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

    # Widok i lista wlasnie zniknely, wiec jez z jablkiem opowiadalby o wyniku, ktorego
    # nikt juz nie widzi. Wolane takze przy starcie okna - stad stan poczatkowy.
    Set-JezykStanJeza 'Ukryty'

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
# PIEC ZADAN, NIE JEDNO, i kazde z wlasnym LICZNIKIEM POKOLEN. Liczone razem oddawaly wynik
# dopiero wtedy, gdy skonczyly wszystkie - data czekalaby na SCCM. Pokolenia odrzucaja wynik
# starego zadania, ktory dotarl po przelaczeniu na inne konto: inaczej dane jednego
# uzytkownika wpisalyby sie do okna opisujacego juz kogos innego.
#
# Zadanie uzytkownika maszyny nalezy do WIDOKU KOMPUTERA, a logowanie i komputer do widoku
# konta - naraz pracuje wiec najwyzej jedna strona okna. Wlasny licznik i tak jest konieczny:
# widoki przelaczaja sie w trakcie trwania zapytania.
#
# PIATE ZADANIE - NUMER TELEFONU - stoi obok pozostalych, bo nalezy do WYSZUKIWANIA, a nie
# do wyswietlonego konta. Wlasny licznik pokolen jest tu szczegolnie potrzebny: operator
# klika "Szukaj" dwa razy pod rzad, a to zapytanie trwa najdluzej ze wszystkich, wiec
# odpowiedz na PIERWSZY numer potrafi dojsc juz po wpisaniu drugiego i dokleilaby do listy
# kogos, kogo nikt nie szukal.
$Script:PokolenieLogowania  = 0
$Script:PokolenieKomputera  = 0
$Script:PokolenieUzytkownika = 0
$Script:PokoleniePingu      = 0
$Script:PokolenieNumeru     = 0
$Script:ZadanieLogowania    = $null
$Script:ZadanieKomputera    = $null
$Script:ZadanieUzytkownika  = $null
$Script:ZadaniePingu        = $null
$Script:ZadanieNumeru       = $null
$Script:ZegarTla            = $null

# Czy pole "Status:" niesie w tej chwili NOTKE O TRWAJACYM szukaniu po numerze, a nie
# odpowiedz. Po samej pustej liscie tego nie poznasz: pusta jest takze przy bledzie odczytu
# i przy "zbyt wielu trafieniach", a tamte dwa zdania sa PRAWDZIWE i wazne - zakrycie ich
# odpowiedzia o numerze skasowaloby jedyna wiadomosc o awarii.
#
# Zerowany na poczatku KAZDEGO wyszukiwania, nie po odebraniu wyniku: zapalony i zapomniany
# z poprzedniego pozwolilby spoznionej odpowiedzi o numerze nadpisac opis konta, ktore
# tym razem znalazlo sie juz po nazwie.
$Script:StatusCzekaNaNumer  = $false

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
    param([ValidateSet('Logowanie', 'Komputer', 'Uzytkownik', 'Ping', 'Numer')][string]$Zadanie)

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

    if ($Zadanie -eq 'Numer') {
        # WYSZUKIWANIE PO NUMERZE TELEFONU. Najwolniejsze z pieciu zadan i jedyne, ktorego
        # czasu nie da sie skrocic: telephoneNumber i mobile NIE SA w AD indeksowane, wiec
        # kontroler przeglada konto po koncie. -ResultPageSize przerywa to przegladanie
        # tylko przy numerze nalezacym do wielu osob; numer jednej osoby zmusza kontroler
        # do przejscia calej domeny i tego nie obejdzie zaden filtr.
        #
        # DOMKNIECIE PRZECHODNIE, nie pierwszy poziom: Find-JezykPozycjePoNumerze wola
        # Find-JezykUsersPoNumerze i New-JezykPozycjaKonta, ta pierwsza wola Get-JezykCyfry
        # i Test-JezykNumerPasuje, a druga Get-JezykOsoba. Pominiecie ktorejkolwiek konczy
        # sie wyjatkiem WEWNATRZ przestrzeni, ktorego okno nie zobaczy - zobaczy tylko brak
        # wyniku.
        $funkcje = 'Get-JezykCyfry', 'Test-JezykNumerPasuje', 'Get-JezykOsoba',
                   'New-JezykPozycjaKonta', 'Find-JezykUsersPoNumerze',
                   'Find-JezykPozycjePoNumerze'

        # IMPORT BEZWARUNKOWY, inaczej niz przy dacie logowania. Tam modul AD bywa
        # niepotrzebny i dlatego import jest pod warunkiem; tutaj Get-ADUser jest JEDYNA
        # droga, wiec warunek tylko odsuwalby ten sam koszt o jedna linijke.
        $naglowek  = 'param($Cyfry, $Limit, $Serwer, $SzukajOd)'
        $naglowek += "`r`n" + 'Import-Module ActiveDirectory -ErrorAction SilentlyContinue'
        $wywolanie = 'Find-JezykPozycjePoNumerze -Cyfry $Cyfry -Limit $Limit' +
                     ' -Serwer $Serwer -SzukajOd $SzukajOd'
    }
    elseif ($Zadanie -eq 'Ping') {
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
        # Get-JezykKontaMaszyny dochodzi tu z tego samego powodu, co Get-JezykPingKomputera -
        # wola ja Get-JezykOstatnioUzywanyKomputer, wiec bez niej zadanie konczy sie cisza.
        $funkcje = $sccm + @('Get-JezykPingKomputera', 'Get-JezykKontaMaszyny', 'Get-JezykOstatnioUzywanyKomputer')

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

<#
.SYNOPSIS
    Uruchamia w tle wyszukiwanie kont po NUMERZE TELEFONU.

.DESCRIPTION
    Piate zadanie i jedyne, ktore nalezy do WYSZUKIWANIA, a nie do konta juz pokazanego
    w oknie. Wczesniej to zapytanie szlo wprost z Find-JezykUsers, czyli na watku
    interfejsu, i okno stalo przez cale przegladanie katalogu - takze wtedy, gdy konta po
    nazwie byly gotowe od razu.

    ZADNEGO ODCZYTU ZE $Script:Config PO STRONIE PRZESTRZENI: adres domeny, limit
    i poddrzewo ida jako ARGUMENTY. Przestrzen startuje pusta i o konfiguracji nie wie nic.
#>
function Start-JezykZadanieNumeru {
    param([string]$Cyfry)

    Stop-JezykZadanieNumeru
    if (-not $Cyfry) { return }

    $Script:PokolenieNumeru++
    $mojePokolenie = $Script:PokolenieNumeru

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Numer')
        [void]$zadanie.Ps.AddArgument($Cyfry).
                          AddArgument([int]$Script:Config.LimitNumeru).
                          AddArgument([string]$Script:Config.Domena).
                          AddArgument([string](Get-JezykSzukajOd $Script:Config.Domena))

        $Script:ZadanieNumeru = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania wyszukiwania po numerze' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        # Nieudane uruchomienie to PRZERWANIE, a nie pusty wynik: nie sprawdzilismy niczego,
        # wiec okno nie moze powiedziec, ze nikogo nie ma.
        Update-JezykNumerWTle -Wynik ([pscustomobject]@{
            Trafienia = @(); ZaDuzo = $false; Przerwane = $true
            Powod     = 'Nie udało się uruchomić wyszukiwania po numerze telefonu: {0}' -f $_.Exception.Message })
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

# Odbiera trafienia po numerze telefonu. Wynik z niezgodnego pokolenia jest odrzucany -
# dotyczylby numeru, ktorego operator juz nie szuka.
function Receive-JezykZadanieNumeru {
    $zadanie = $Script:ZadanieNumeru
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($zadanie.Pokolenie -eq $Script:PokolenieNumeru -and $dane.Count -gt 0) {
            Update-JezykNumerWTle -Wynik $dane[0]
        }
    }
    catch {
        if ($zadanie.Pokolenie -eq $Script:PokolenieNumeru) {
            Update-JezykNumerWTle -Wynik ([pscustomobject]@{
                Trafienia = @(); ZaDuzo = $false; Przerwane = $true
                Powod     = 'Wyszukiwanie po numerze telefonu zawiodło: {0}' -f $_.Exception.Message })
        }
    }
    finally { Stop-JezykZadanieNumeru }
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

function Stop-JezykZadanieNumeru {
    if (-not $Script:ZadanieNumeru) { return }
    $zadanie = $Script:ZadanieNumeru
    $Script:ZadanieNumeru = $null
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
    Stop-JezykZadanieNumeru

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
    # Zapas obejmuje DWIE linijki ostatniego pola: "Status:" niesie najdluzsze teksty
    # w calym oknie i jest jedynym polem dwulinijkowym - patrz sekcja wyrownania.
    $wysokoscPanelu = (Get-JezykWierszPole 8) + 58    # ostatnie pole (2 linijki) + margines
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

    # JEZ - znak, ze okno pracuje, i odpowiedz, gdy skonczy. Zaczyna biec przy KAZDYM
    # klinieciu "Szukaj", a gdy nie ma juz na co czekac, staje: z jablkiem, jesli cos sie
    # znalazlo, albo na plecach, jesli nie. Poza zostaje az do nastepnego wyszukiwania.
    # Wszystkie cztery stany ustawia Set-JezykStanJeza w Jezyk-3-Widok.ps1.
    #
    # STOI W WOLNEJ, PRAWEJ CZESCI WIERSZA DOMENY - nad polem wyszukiwania i przyciskiem
    # "Szukaj". To miejsce BYLO JUZ PUSTE, wiec jez nie zabral szerokosci zadnej kontrolce
    # ani nie przesunal zadnego wiersza. Poprzednik, pasek Marquee, mial na to wlasny pas
    # pod wierszem wyszukiwania i kosztowal dziesiec pikseli wysokosci calego okna.
    #
    # PictureBox, a nie Panel: ma podwojne buforowanie z fabryki, wiec animacja nie mruga.
    # Tla NIE ustawiamy - kontrolka dziedziczy je po oknie i jez wyglada jak wpisany w nie.
    #
    # Rusza sie naprawde tylko przy wyszukiwaniu po numerze telefonu, bo tylko ono zeszlo
    # do przestrzeni w tle. Przy zapytaniu synchronicznym jest widoczny, ale nieruchomy:
    # klatki odmierza zegar na watku interfejsu, a ten stoi wtedy w zapytaniu.
    $jezSzukania         = New-Object System.Windows.Forms.PictureBox
    # Lewa krawedz od konca listy domen, prawa rowna prawej krawedzi calej zawartosci -
    # zadnej wspolrzednej wpisanej liczba.
    $jezSzukania.Left    = $cmbDomena.Right + $przerwa
    $jezSzukania.Width   = $Script:Margines + $Script:SzerokoscPelna - $jezSzukania.Left
    $jezSzukania.Visible = $false
    # Procedura zdarzenia nie widzi zmiennych tej funkcji. $this jest kontrolka, ktora
    # zdarzenie zglosila, i tylko stamtad wolno wziac jej rozmiar; $_ to argumenty
    # zdarzenia, czyli PaintEventArgs z powierzchnia do rysowania. To jedyne miejsce
    # w programie, ktore korzysta z $_ w procedurze zdarzenia.
    $jezSzukania.Add_Paint({
        Set-JezykRysunekJeza -Grafika $_.Graphics -Szerokosc $this.Width -Wysokosc $this.Height
    })

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
    # Ta sama wspolrzedna, co gorna krawedz panelu bez listy - lista i panel zajmuja
    # w tym miejscu to samo pietro okna, wiec licza sie z jednej stalej.
    $cmbWynik.Location      = [System.Drawing.Point]::new($Script:Margines, $Script:PanelBezListy)
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
    # ZOSTALY DWA CZERWONE, przy jedynych polach, ktore potrafia zglosic realna usterke.
    # Odpadly:
    #   Domena, Ostatnie logowanie - stale wyjasnienia bez zwiazku z awaria,
    #   Odblokuj konto - powody wylaczenia przycisku ("najpierw znajdz konto", "konto nie
    #     jest zablokowane") to normalne stany, a nie bledy; wykrzyknik zapalal sie tam
    #     zaraz po starcie okna i przestawal cokolwiek znaczyc.
    # Get-JezykOpisKonfiguracji zostaje jako funkcja - jest kontrolna dla
    # Jezyk-1-Srodowisko.ps1 w Kod-Jezyk.ps1 - traci tylko podpiecie pod GUI.
    $btnInfoStatus   = New-JezykPrzyciskInfo 'Status'
    $btnInfoKomputer = New-JezykPrzyciskInfo 'Komputer'

    # Trzeci, NIEBIESKI: nie usterka, tylko realna niejednoznacznosc - maszyna, ktora wg
    # SCCM ma wiecej niz jedno konto. Wlasny kolor nadpisany PO utworzeniu, zeby nie ruszac
    # sygnatury New-JezykPrzyciskInfo uzywanej przez pozostale, czerwone przyciski.
    $btnInfoKomputerWspoldzielony = New-JezykPrzyciskInfo 'KomputerWspoldzielony'
    $btnInfoKomputerWspoldzielony.BackColor = $Script:Config.KolorInfoTlo
    $btnInfoKomputerWspoldzielony.ForeColor = $Script:Config.KolorInfo
    $btnInfoKomputerWspoldzielony.FlatAppearance.BorderColor = $Script:Config.KolorInfo

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

    # DWIE LINIJKI, NIE JEDNA. To pole niesie najdluzsze teksty w oknie - komunikat
    # o numerze uzywanym przez wiele osob ma ponad sto trzydziesci znakow i w jednej
    # linijce widac z niego pierwsza polowe zdania. Zawijanie wierszy jest przy Multiline
    # domyslne; wysokosc liczy sie z czcionki, w sekcji wyrownania.
    $lblStatus = New-JezykEtykieta 'Status:' $L (Get-JezykWiersz 8)
    $txtStatus = New-JezykPole               $L (Get-JezykWierszPole 8) $C
    $txtStatus.Multiline = $true

    $pnlKonto.Controls.AddRange(@(
        $chkWerdykt, $lblWerdykt, $btnOdblokuj, $grpFlagi,
        $lblLoginKonta, $txtLoginKonta, $lblImieNazwisko, $txtImieNazwisko,
        $lblEmail, $txtEmail,
        $lblHasloWygasa, $txtHasloWygasa, $lblKontoWygasa, $txtKontoWygasa,
        $lblOstatniaZmiana, $txtOstatniaZmiana, $lblKontoUtworzono, $txtKontoUtworzono,
        $lblTelefon, $txtTelefon, $lblMenedzer, $txtMenedzer,
        $lblOstatnieLogowanie, $txtOstatnieLogowanie,
        $lblKomputerUzytkownika, $txtKomputerUzytkownika, $btnInfoKomputer,
        $btnInfoKomputerWspoldzielony, $btnPinguj,
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
                                                     ($kompWiersz2 + $Script:OdstepPodEtykieta + 58))
    $pnlKomputer.Visible = $false

    $lblKompKatalog = New-JezykEtykieta 'Katalog komputera:' $Script:Margines $kompWiersz0
    $txtKompKatalog = New-JezykPole $Script:Margines ($kompWiersz0 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    # Droga ODWROTNA do pola "Ostatnio uzywany komputer" w widoku konta: tam z loginu
    # szukamy maszyny, tu z maszyny szukamy uzytkownika. Zrodlo to samo - inwentaryzacja
    # SCCM - wiec i tu przy etykiecie stoi przycisk "!" na wypadek jej milczenia.
    $lblKompUzytkownik = New-JezykEtykieta 'Ostatnio zalogowany użytkownik:' $Script:Margines $kompWiersz1
    $txtKompUzytkownik = New-JezykPole $Script:Margines ($kompWiersz1 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $btnInfoUzytkownik = New-JezykPrzyciskInfo 'Uzytkownik'

    # Dwie linijki, tak samo jak w widoku konta: to pole niesie komunikaty o niepowodzeniu
    # zapytania do SCCM, rownie dlugie. Jedno pole dwulinijkowe, a drugie jednolinijkowe
    # wygladaloby jak usterka.
    $lblKompStatus  = New-JezykEtykieta 'Status:' $Script:Margines $kompWiersz2
    $txtKompStatus  = New-JezykPole $Script:Margines ($kompWiersz2 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $txtKompStatus.Multiline = $true

    $pnlKomputer.Controls.AddRange(@($lblKompKatalog, $txtKompKatalog,
                                     $lblKompUzytkownik, $txtKompUzytkownik, $btnInfoUzytkownik,
                                     $lblKompStatus, $txtKompStatus))

    # Podpis autora lezy POZA panelami, wiec widac go w obu trybach.
    $lblAutor           = New-JezykEtykieta ('Autor: ' + $Script:Config.Autor) $Script:Margines ($wysokoscOkna - 20)
    $lblAutor.ForeColor = $Script:Config.KolorNieznany
    $lblAutor.Font      = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size - 1)

    $form.Controls.AddRange(@($lblDomena, $cmbDomena, $lblPodaj, $cmbTryb,
                              $txtSzukaj, $jezSzukania, $btnSzukaj, $cmbWynik,
                              $pnlKonto, $pnlKomputer, $lblAutor))

    # --- WYROWNANIE W PIONIE ---------------------------------------------------------
    # CALE wyrownanie stoi TUTAJ, po dodaniu kontrolek do okna, i nie da sie go przeniesc
    # wyzej: kontrolka dziedziczy czcionke okna dopiero w momencie dodania, wiec kazdy pomiar
    # tekstu zrobiony wczesniej mierzylby czcionke domyslna.
    Set-JezykSrodekTekstu $lblDomena $cmbDomena.Height
    Set-JezykSrodekTekstu $lblPodaj  $cmbTryb.Height
    # Wysokosc jeza bierze sie z listy domen, a nie z liczby: pas ma rosnac razem z nia,
    # gdy czcionka systemu urosnie przy DPI 125-150%. Musi stac TUTAJ, bo dopiero teraz
    # lista zna swoja rzeczywista wysokosc.
    $jezSzukania.Height = $cmbDomena.Height
    Set-JezykSrodekPionowy @($lblDomena, $cmbDomena, $jezSzukania) $srodekDomeny
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

    # OBA POLA "Status:" DOSTAJA DRUGA LINIJKE. Wysokosc liczona z czcionki, a nie wpisana:
    # PreferredHeight to wysokosc JEDNEJ linii razem z ramka, wiec dokladamy do niej
    # wysokosc kolejnej. Liczba wpisana na sztywno zgadzalaby sie wylacznie przy 100% DPI -
    # ta sama zasada, co przy $wysokoscZnacznika i Set-JezykSrodekPionowy.
    $drugaLinia = [int][math]::Ceiling($form.Font.GetHeight())
    foreach ($pole in @($txtStatus, $txtKompStatus)) {
        $pole.Height = $pole.PreferredHeight + $drugaLinia
    }

    # --- PRZYCISKI "!" ---------------------------------------------------------------
    # Stawiane NA SAMYM KONCU wyrownania, bo licza sie z rzeczywistej szerokosci etykiet,
    # a te znaja swoja szerokosc dopiero po odziedziczeniu czcionki okna - i po tym, jak
    # wyrownanie wyzej poprzestawialo im wspolrzedne pionowe.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik, $btnInfoKomputerWspoldzielony)) {
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

    # Drugi przycisk stoi TUZ ZA pierwszym, nie za etykieta - Top dziedziczy z niego (obaj
    # centruja sie wzgledem tej samej etykiety), Left dosuwa sie o wlasna szerokosc + odstep.
    $btnInfoKomputerWspoldzielony.Top  = $btnInfoKomputer.Top
    $btnInfoKomputerWspoldzielony.Left = $btnInfoKomputer.Left + $btnInfoKomputer.Width + 4

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
        JezSzukania   = $jezSzukania
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
        InfoStatus                = $btnInfoStatus
        InfoKomputer              = $btnInfoKomputer
        InfoUzytkownik            = $btnInfoUzytkownik
        InfoKomputerWspoldzielony = $btnInfoKomputerWspoldzielony
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
        Receive-JezykZadanieNumeru

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
            -not $Script:ZadanieNumeru -and
            @($Script:ZadaniaPorzucone).Count -eq 0) {
            $Script:ZegarTla.Stop()
        }
    })
    $Script:ZegarTla = $zegar

    # ZEGAR ANIMACJI JEZA - OSOBNY OD POWYZSZEGO, i to nie jest rozrzutnosc. Zegar zadan
    # budzi sie co cwierc sekundy i tylko dopoki cos biegnie w tle; animacja potrzebuje
    # kilkunastu klatek na sekunde. Zlaczone w jeden albo zamulilyby jeden koniec, albo
    # drugi budzilyby bez potrzeby.
    #
    # Chodzi WYLACZNIE w stanie 'Szuka' - zapala go i zatrzymuje Set-JezykStanJeza. Poza
    # z wynikiem jest NIERUCHOMA, wiec zegar ma przy niej stac: zegar chodzacy nad statycznym
    # obrazkiem budzilby watek interfejsu kilkanascie razy na sekunde do konca dnia.
    $zegarJeza          = New-Object System.Windows.Forms.Timer
    $zegarJeza.Interval = $Script:TaktJeza
    $zegarJeza.Add_Tick({
        $Script:KlatkaJeza++
        # Invalidate TYLKO tutaj. Jezyk-3-Widok.ps1 dotyka wylacznie Visible, bo atrapa
        # kontrolki w zestawie weryfikacyjnym nie ma metod rysowania.
        $Script:Kontrolki.JezSzukania.Invalidate()
    })
    $Script:ZegarJeza = $zegarJeza

    # Bez sprzatania proces potrafi zostac w pamieci, czekajac na przestrzen uruchomieniowa,
    # ktorej nikt juz nie odbierze. Zegar animacji gasimy przy tej samej okazji.
    $form.Add_FormClosing({
        Stop-JezykZadaniaTla
        if ($Script:ZegarJeza) { $Script:ZegarJeza.Stop() }
    })

    # Jedna procedura dla WSZYSTKICH przyciskow "!". Klucz pola przychodzi z Tag klikanego
    # przycisku - procedury zdarzen nie widza zmiennych lokalnych tej funkcji, a $this jest
    # kontrolka, ktora zdarzenie zglosila.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik, $btnInfoKomputerWspoldzielony)) {
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
