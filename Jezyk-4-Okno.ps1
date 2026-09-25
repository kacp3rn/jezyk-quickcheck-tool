# Jezyk-4-Okno - siatka okna, sprite jeza, rysowanie, budowa okna i zadania w tle.
# Linia 1 musi zostac zwyklym komentarzem - oslania pierwsza instrukcje przed zdublowanym BOM.

# Wlasny trap w kazdej czesci: trap wznawia prace w zakresie, w ktorym go zdefiniowano.
trap { Register-JezykBladCzesci $_; continue }


#region SEKCJA 4 - OKNO
# Gorny wiersz wspolny, reszta w dwoch panelach (pnlKonto, pnlKomputer) - tryb pokazuje jeden.

# --- RYTM SIATKI ---------------------------------------------------------------------
# Wszystkie wspolrzedne wynikaja z ponizszych stalych i z pomiaru pola, nic nie jest wpisane
# recznie (README: Siatka okna liczy sie sama).

# Odstep od paska tytulu do pierwszej kontrolki - wlasna liczba, nie reszta arytmetyki srodka.
$Script:MarginesGorny = 2

# Odstep od dolu pola do etykiety nastepnego wiersza - jedyna liczba gestosci siatki.
$Script:PrzerwaWierszy     = 8

# Wiersz z wyborem domeny stoi nad wszystkim, wiec reszta okna schodzi o jego wysokosc.
$Script:PasekDomeny   = 30

# Pietro paneli bez listy wyboru - wartosc startowa dla pola 22 px; New-JezykForm liczy ja z pomiaru.
$Script:PanelBezListy = $Script:MarginesGorny + $Script:PasekDomeny + 22 + $Script:PrzerwaWierszy

# Wysokosc wiersza listy wyboru kont (tylko przy wyszukiwaniu czesciowym).
$Script:PasListyWyboru = 30
# Pietro z lista liczone od pietra bez niej - roznica to sama lista.
$Script:PanelZListą   = $Script:PanelBezListy + $Script:PasListyWyboru

$Script:PierwszyWiersz     = 92    # y etykiety pierwszego wiersza wewnatrz panelu konta
$Script:OdstepPodEtykieta  = 20    # ile nizej od etykiety lezy jej pole

# Skok wiersza (etykieta, pole, przerwa) - start dla pola 22 px; New-JezykForm liczy go z pomiaru.
$Script:SkokWiersza        = $Script:OdstepPodEtykieta + 22 + $Script:PrzerwaWierszy

# Pusty pas za kwadratem znacznika bez tekstu (WinForms dokleja 2 px) - odejmowany od odstepu napisu.
$Script:PasZaZnacznikiem   = 2

# O ile "!" cofa sie od prawej krawedzi pola - widoczna ramka konczy sie wczesniej niz prostokat.
$Script:CofniecieWykrzyknika = 1

# O ile kwadrat kryjacy przycisk listy jest szerszy od systemowego (wezszy zostawilby jasne paski).
$Script:ZapasStrzalkiListy = 2

# Najdluzszy napis werdyktu - mierzy szerokosc etykiety.
# Uwaga: przy kazdym nowym tekscie werdyktu (Set-JezykResult) sprawdz, czy nie jest dluzszy.
$Script:NajdluzszyWerdykt  = 'Pozycja typu Kontakt - to nie jest konto'

# Srodek wiersza werdyktu - wspolny dla kwadratu, napisu i przycisku odblokowania.
$Script:SrodekWerdyktu     = 16

# Rytm poziomy. Obie kolumny musza wyjsc rowne, wiec sa WYLICZANE, a nie wpisane.
$Script:Margines      = 12
$Script:SzerokoscOkna = 620
$Script:PrzerwaKolumn = 28

$Script:SzerokoscPelna = $Script:SzerokoscOkna - 2 * $Script:Margines
# Nieparzysta reszta ma isc na przerwe, nie na jedna z kolumn.
$Script:SzerokoscKolumny = [int](($Script:SzerokoscPelna - $Script:PrzerwaKolumn) / 2)
$Script:DrugaKolumna     = $Script:Margines + $Script:SzerokoscKolumny + $Script:PrzerwaKolumn

# --- JEZ, KTORY MOWI, ZE OKNO PRACUJE ------------------------------------------------
# Wskaznik pracy w pustej prawej czesci wiersza domeny. Rusza sie naprawde tylko przy szukaniu
# po numerze - przy zapytaniu synchronicznym stoi (README: Praca w tle).

# Sprite jeza wyprowadzony raz z Ikona-Jezyk.ico; '.' = przezroczyste (programu .ico nie czyta).
# Uwaga: najjasniejszy odcien to '*', nie 'O' - klucze @{} nie rozrozniaja wielkosci liter.
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

# Kolory tu, pedzle nie - pedzel GDI przy wczytaniu pliku wywrocilby zestaw weryfikacyjny.
# Jablko: nakladka 10x10 na sylwetke - wieksze zjadaloby oko i policzek (README: Praca w tle).
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

# --- IKONKA MOTYWU --------------------------------------------------------------------
# Ksiezyc albo slonce liczone z geometrii i rysowane z wygladzaniem; wymiary to ulamki boku.
$Script:BokIkonyMotywu    = 18   # MINIMALNY bok ikonki - rosnie do wysokosci linii pisma

# Wysokosc pasa podpisu (ikonka i dwa napisy) - start; New-JezykForm liczy ja z czcionki okna.
$Script:WysokoscPasaPodpisu = $Script:BokIkonyMotywu

# Przerwa miedzy ikonka a napisem z wersja (z marginesami wychodzi ok. szerokosci spacji).
$Script:OdstepIkonyMotywu = 5

# KSIEZYC (w motywie jasnym): tarcza minus kolo przesuniete w prawo i w gore.
$Script:KsiezycPromien      = 0.47   # promien tarczy - ulamek boku
$Script:KsiezycWyciecie     = 0.85   # promien kola wycinajacego - ulamek promienia tarczy
$Script:KsiezycPrzesuniecie = 0.60   # odleglosc srodkow obu kol - ulamek promienia tarczy
# Kat wyciecia; os Y rosnie w dol. -20, nie -45 - przy -45 sierp wypadal pod srodkiem pudelka.
$Script:KsiezycKat          = -20
$Script:KsiezycPunktyLuku   = 24     # odcinki na kazdym z dwoch lukow sierpa

# SLONCE pokazuje sie w motywie CIEMNYM - tak samo, niesie powrot do jasnego.
$Script:SlonceTarcza    = 0.21   # promien tarczy - ulamek boku
$Script:SlonceRamieOd   = 0.33   # poczatek promienia - odleglosc od srodka, ulamek boku
$Script:SlonceRamieDo   = 0.48   # koniec promienia
$Script:SlonceGrubosc   = 0.11   # grubosc promienia - ulamek boku; przy 18 px to 2 px
$Script:SlonceIleRamion = 8

# Kolory ikonek nie zaleza od motywu - kazda pokazuje sie tylko na swoim tle.
# Uwaga: klucze musza sie roznic takze bez wielkosci liter ("Duplicate keys").
$Script:PaletaIkonyMotywu = @{
    'k' = [System.Drawing.Color]::FromArgb(95, 110, 200)   # ksiezyc - indygo
    's' = [System.Drawing.Color]::FromArgb(255, 195, 55)   # slonce - tarcza
    'p' = [System.Drawing.Color]::FromArgb(255, 150, 40)   # slonce - promienie
}

# Bufor pedzli ikonki - kolory stale, wiec bez uniewazniania.
$Script:PedzleIkonyMotywu = $null

# Pedzel GDI - styk z systemem, ktory zestaw weryfikacyjny zastepuje atrapa.
function New-JezykPedzel {
    param($Kolor)
    [System.Drawing.SolidBrush]::new($Kolor)
}

# Region kontrolki (obcinanie ramki listy) - styk z systemem, jak pedzel wyzej.
function New-JezykObszar {
    param([int]$X, [int]$Y, [int]$Szerokosc, [int]$Wysokosc)
    [System.Drawing.Region]::new([System.Drawing.Rectangle]::new($X, $Y, $Szerokosc, $Wysokosc))
}

# Rysuje napis przycisku (z Tag) w calym jego prostokacie - przycisk moze byc rowny polu.
# Text przycisku pusty; tla i ramki nie malujemy; kolor z palety wg Enabled (README: Siatka okna).
function Set-JezykRysunekNapisuPrzycisku {
    param($Przycisk, $Grafika)

    if (-not $Przycisk) { return }

    # Przycisk bez napisu w Tag (np. przycisk motywu) nie ma tu czego rysowac.
    $napis = [string]$Przycisk.Tag
    if (-not $napis) { return }

    $kolor = if ($Przycisk.Enabled) { $Script:Config.KolorTekstu }
             else                   { $Script:Config.KolorNieczynny }

    Set-JezykNapisNaSrodku -Grafika $Grafika -Tekst $napis `
                           -Czcionka $Przycisk.Font `
                           -Szerokosc $Przycisk.Width -Wysokosc $Przycisk.Height `
                           -Kolor $kolor
}

# Napis wysrodkowany w prostokacie (TextRenderer) - styk z systemem, zastepowany w testach.
function Set-JezykNapisNaSrodku {
    param($Grafika, [string]$Tekst, $Czcionka, [int]$Szerokosc, [int]$Wysokosc, $Kolor)

    [System.Windows.Forms.TextRenderer]::DrawText(
        $Grafika, $Tekst, $Czcionka,
        [System.Drawing.Rectangle]::new(0, 0, $Szerokosc, $Wysokosc),
        $Kolor,
        ([System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
         [System.Windows.Forms.TextFormatFlags]::VerticalCenter))
}

# Bufor pedzli kwadratu ze strzalka - kolory z palety, pada przy zmianie motywu.
$Script:PedzleStrzalki = $null

# Najmniejsza polowa podstawy strzalki (3 - jak systemowa przy 100% DPI); wyzej rosnie z kwadratem.
$Script:MinimalnaPolowaStrzalki = 3

# Maluje kwadrat ze strzalka zakrywajacy systemowy przycisk listy (jego kolorow nie da sie zmienic).
# Trojkat z poziomych paskow - rysunek da sie odtworzyc ze sladu w testach.
function Set-JezykRysunekStrzalkiListy {
    param($Strzalka, $Grafika)

    if (-not $Strzalka) { return }

    if (-not $Script:PedzleStrzalki) {
        $Script:PedzleStrzalki = @{
            Tlo      = New-JezykPedzel $Script:Config.KolorPrzyciskuListy
            Strzalka = New-JezykPedzel $Script:Config.KolorTekstu
        }
    }

    $szer = $Strzalka.Width
    $wys  = $Strzalka.Height

    $Grafika.FillRectangle($Script:PedzleStrzalki.Tlo, 0, 0, $szer, $wys)

    # Szostka: przy kwadracie 19 px daje systemowa polowe 3.
    $polowa  = [Math]::Max($Script:MinimalnaPolowaStrzalki, [int][Math]::Floor($szer / 6))
    $srodekX = [int][Math]::Floor($szer / 2)
    # Floor, nie [int] - [int] zaokragla i strzalka schodzilaby o piksel.
    $gora    = [int][Math]::Floor(($wys - ($polowa + 1)) / 2)

    for ($i = 0; $i -le $polowa; $i++) {
        $Grafika.FillRectangle($Script:PedzleStrzalki.Strzalka,
                               $srodekX - $polowa + $i, $gora + $i,
                               2 * ($polowa - $i) + 1, 1)
    }
}

# Grubosc pasa zamalowujacego systemowa ramke flag (motyw rysuje linie z rozjasnieniem).
$Script:ZamalowanieRamkiFlag = 3

$Script:PedzleRamkiFlag = $null

# Przemalowuje ramke "Flagi konta" kolorem palety: cztery pasy scierajace od krawedzi, potem linie.
# Gorna linia w polowie paska tytulu GroupBoxa (README: Ciemny motyw).
function Set-JezykRysunekRamkiFlag {
    param($Ramka, $Grafika)

    if (-not $Ramka) { return }

    if (-not $Script:PedzleRamkiFlag) {
        $Script:PedzleRamkiFlag = @{
            Tlo   = New-JezykPedzel $Script:Config.KolorOkna
            Linia = New-JezykPedzel $Script:Config.KolorObramowki
        }
    }

    $szer = $Ramka.ClientSize.Width
    $wys  = $Ramka.ClientSize.Height
    $gora = [int][Math]::Floor($Ramka.DisplayRectangle.Top / 2)
    $pas  = $Script:ZamalowanieRamkiFlag

    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Tlo, 0, 0, $szer, ($gora + $pas))
    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Tlo, 0, ($wys - $pas), $szer, $pas)
    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Tlo, 0, 0, $pas, $wys)
    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Tlo, ($szer - $pas), 0, $pas, $wys)

    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Linia, 0, $gora, $szer, 1)
    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Linia, 0, ($wys - 1), $szer, 1)
    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Linia, 0, $gora, 1, ($wys - $gora))
    $Grafika.FillRectangle($Script:PedzleRamkiFlag.Linia, ($szer - 1), $gora, 1, ($wys - $gora))
}

# Przesuniecie stawiajace srodek masy wielokata (nie obwiednie) w srodku kwadratu, przyciete do niego.
function Get-JezykPrzesuniecieNaSrodek {
    param($Punkty, [int]$Bok)

    $lista = @($Punkty)
    if ($lista.Count -lt 3) { return [System.Drawing.PointF]::new(0, 0) }

    $pole = 0.0
    $sumaX = 0.0
    $sumaY = 0.0
    $minX = [double]::MaxValue
    $maxX = [double]::MinValue
    $minY = [double]::MaxValue
    $maxY = [double]::MinValue

    for ($i = 0; $i -lt $lista.Count; $i++) {
        $a = $lista[$i]
        $b = $lista[($i + 1) % $lista.Count]
        $skos  = $a.X * $b.Y - $b.X * $a.Y
        $pole  += $skos
        $sumaX += ($a.X + $b.X) * $skos
        $sumaY += ($a.Y + $b.Y) * $skos

        if ($a.X -lt $minX) { $minX = $a.X }
        if ($a.X -gt $maxX) { $maxX = $a.X }
        if ($a.Y -lt $minY) { $minY = $a.Y }
        if ($a.Y -gt $maxY) { $maxY = $a.Y }
    }

    # Figura zdegenerowana (wszystkie punkty w jednej linii) nie ma srodka masy.
    if ($pole -eq 0.0) { return [System.Drawing.PointF]::new(0, 0) }

    $pole  = $pole / 2
    $masaX = $sumaX / (6 * $pole)
    $masaY = $sumaY / (6 * $pole)
    $srodek = $Bok / 2

    $dx = [Math]::Max(-$minX, [Math]::Min($srodek - $masaX, $Bok - $maxX))
    $dy = [Math]::Max(-$minY, [Math]::Min($srodek - $masaY, $Bok - $maxY))

    [System.Drawing.PointF]::new($dx, $dy)
}

# Figury ikonki motywu (sama geometria, bez GDI): sierp z dwoch lukow albo tarcza i promienie slonca.
# Wynik rozwiniety - owijaj @() u wolajacego; sierp dosuniety srodkiem masy.
function Get-JezykFiguryMotywu {
    param([ValidateSet('Jasny', 'Ciemny')][string]$Motyw, [int]$Bok)

    $srodek = $Bok / 2

    if ($Motyw -eq 'Jasny') {
        # Uwaga: $R i $r to dla PowerShella jedna zmienna - nazwy w pelnych slowach (README: Siatka okna).
        $promien         = $Script:KsiezycPromien * $Bok
        $promienWyciecia = $Script:KsiezycWyciecie * $promien
        $odstepSrodkow   = $Script:KsiezycPrzesuniecie * $promien

        # Przeciecie okregow: x0 - odleglosc cieciwy, h - polowa cieciwy, t0 i s0 - katy rogu.
        $x0 = ($promien * $promien - $promienWyciecia * $promienWyciecia +
               $odstepSrodkow * $odstepSrodkow) / (2 * $odstepSrodkow)
        $h  = [Math]::Sqrt($promien * $promien - $x0 * $x0)
        $t0 = [Math]::Atan2($h, $x0)
        $s0 = [Math]::Atan2($h, $x0 - $odstepSrodkow)

        $kat = $Script:KsiezycKat * [Math]::PI / 180
        $cos = [Math]::Cos($kat)
        $sin = [Math]::Sin($kat)
        $n   = $Script:KsiezycPunktyLuku

        $punkty = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        $dodaj  = {
            param([double]$X, [double]$Y)
            $punkty.Add([System.Drawing.PointF]::new($srodek + $X * $cos - $Y * $sin,
                                                     $srodek + $X * $sin + $Y * $cos))
        }

        # Luk zewnetrzny: od rogu (t0) przez strone oswietlona (pi) do drugiego rogu.
        for ($i = 0; $i -le $n; $i++) {
            $t = $t0 + (2 * [Math]::PI - 2 * $t0) * $i / $n
            & $dodaj ($promien * [Math]::Cos($t)) ($promien * [Math]::Sin($t))
        }
        # Luk wewnetrzny: z powrotem, po tej czesci kola wycinajacego, ktora lezy w tarczy.
        for ($i = 0; $i -le $n; $i++) {
            $s = (2 * [Math]::PI - $s0) - (2 * [Math]::PI - 2 * $s0) * $i / $n
            & $dodaj ($odstepSrodkow + $promienWyciecia * [Math]::Cos($s)) `
                     ($promienWyciecia * [Math]::Sin($s))
        }

        $przes = Get-JezykPrzesuniecieNaSrodek $punkty $Bok
        $dosuniete = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        foreach ($punkt in $punkty) {
            $dosuniete.Add([System.Drawing.PointF]::new($punkt.X + $przes.X,
                                                        $punkt.Y + $przes.Y))
        }

        return [pscustomobject]@{
            Znak   = 'k'
            Punkty = $dosuniete.ToArray()
            Kolo   = $null
            Srodek = [System.Drawing.PointF]::new($srodek + $przes.X, $srodek + $przes.Y)
        }
    }

    $tarcza = $Script:SlonceTarcza * $Bok
    [pscustomobject]@{
        Znak   = 's'
        Punkty = $null
        Kolo   = [System.Drawing.RectangleF]::new($srodek - $tarcza, $srodek - $tarcza,
                                                  2 * $tarcza, 2 * $tarcza)
    }

    # Ramiona: waskie czworokaty wzdluz promienia (u - kierunek ramienia, (-uy, ux) - w poprzek).
    $od    = $Script:SlonceRamieOd * $Bok
    $do    = $Script:SlonceRamieDo * $Bok
    $pol   = $Script:SlonceGrubosc * $Bok / 2
    $ile   = $Script:SlonceIleRamion
    for ($i = 0; $i -lt $ile; $i++) {
        $a  = 2 * [Math]::PI * $i / $ile
        $ux = [Math]::Cos($a)
        $uy = [Math]::Sin($a)
        $punkty = foreach ($para in @(@($od, -1), @($do, -1), @($do, 1), @($od, 1))) {
            [System.Drawing.PointF]::new($srodek + $ux * $para[0] - $uy * $pol * $para[1],
                                         $srodek + $uy * $para[0] + $ux * $pol * $para[1])
        }
        [pscustomobject]@{ Znak = 'p'; Punkty = [System.Drawing.PointF[]]$punkty; Kolo = $null }
    }
}

# Rysuje ikonke motywu z wygladzaniem i przesunieciem pikseli o pol (bez nich schodki i krzywizna).
function Set-JezykRysunekMotywu {
    param($Grafika, [int]$Bok)

    $figury = @(Get-JezykFiguryMotywu -Motyw $Script:Motyw -Bok $Bok)
    if ($figury.Count -eq 0) { return }

    if (-not $Script:PedzleIkonyMotywu) {
        $Script:PedzleIkonyMotywu = @{}
        foreach ($znak in $Script:PaletaIkonyMotywu.Keys) {
            $Script:PedzleIkonyMotywu[$znak] = New-JezykPedzel $Script:PaletaIkonyMotywu[$znak]
        }
    }

    $Grafika.SmoothingMode   = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $Grafika.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    foreach ($figura in $figury) {
        $pedzel = $Script:PedzleIkonyMotywu[$figura.Znak]
        if ($figura.Kolo) {
            $Grafika.FillEllipse($pedzel, $figura.Kolo)
        }
        else {
            $Grafika.FillPolygon($pedzel, $figura.Punkty)
        }
    }
}

# Mapa jeza dla stanu, bez GDI: NaPlecach to odbicie w pionie z jasnymi lapami.
# Uwaga: jablko na KOPII ([string[]]) - podmiana wiersza w MapaJeza zatrulaby reszte sesji.
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

# Polozenie i komorka jeza w klatce - czysta arytmetyka (rysowania zestaw weryfikacyjny nie wykonuje).
# Komorka przez Floor; poza z wynikiem przycinana do pasa (najpierw gorna granica, potem dolna).
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

    # Kolysanie o komorke co dwie klatki.
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

# Rysuje jeza (jedyne siegniecie animacji po GDI) - wspolrzedne gotowe, pedzle leniwie w buforze.
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

# Skok wiersza dla pola o podanej wysokosci: etykieta, pole i przerwa.
function Get-JezykSkokWiersza {
    param([int]$WysokoscPola)
    $Script:OdstepPodEtykieta + $WysokoscPola + $Script:PrzerwaWierszy
}

# Polowa wysokosci zaokraglona w dol - [int] zaokragla bankiersko (21/2 -> 10, 23/2 -> 12).
function Get-JezykPolowaWysokosci {
    param([int]$Wysokosc)
    [int][math]::Floor($Wysokosc / 2)
}

# Srodek pierwszego wiersza: gorny margines + polowa kontrolki.
function Get-JezykSrodekWiersza {
    param([int]$WysokoscPola)
    $Script:MarginesGorny + (Get-JezykPolowaWysokosci $WysokoscPola)
}

# Gora panelu bez listy: margines, wiersz domeny, wiersz wyszukiwania i przerwa.
function Get-JezykPietroBezListy {
    param([int]$WysokoscPola)
    $Script:MarginesGorny + $Script:PasekDomeny + $WysokoscPola + $Script:PrzerwaWierszy
}

# Wysokosc obszaru roboczego (oba widoki): panel, przerwa wiersza, pas podpisu i dolny margines.
function Get-JezykWysokoscOkna {
    param([int]$GoraPanelu, [int]$WysokoscPanelu)

    $GoraPanelu + $WysokoscPanelu + $Script:PrzerwaWierszy + $Script:WysokoscPasaPodpisu + 2
}

# Przycina wysokosc okna do obszaru roboczego ekranu (wtedy AutoScroll pokazuje pasek); pod try.
function Get-JezykWysokoscWEkranie {
    param([int]$Wysokosc)

    try {
        $maksWysokosc = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height - 60
        if ($maksWysokosc -gt 200 -and $Wysokosc -gt $maksWysokosc) { return $maksWysokosc }
    }
    catch { }

    $Wysokosc
}

# Wysokosc pola przy danej czcionce (PreferredHeight pola na boku) - od niej zalezy cala siatka.
function Get-JezykWysokoscPola {
    param($Czcionka)

    $pole = New-Object System.Windows.Forms.TextBox
    try {
        $pole.Font = $Czcionka
        $pole.PreferredHeight
    }
    finally { $pole.Dispose() }
}

# Wyrownuje kontrolki w pionie do wspolnego srodka wiersza (wg ich rzeczywistej wysokosci).
function Set-JezykSrodekPionowy {
    param([object[]]$Kontrolki, [int]$Srodek)
    foreach ($kontrolka in $Kontrolki) {
        $kontrolka.Top = $Srodek - (Get-JezykPolowaWysokosci $kontrolka.Height)
    }
}

# Dosuwa kontrolki prawa krawedzia do podanej wspolrzednej (osobno - da sie sprawdzic na atrapie).
function Set-JezykDoPrawej {
    param([object[]]$Kontrolki, [int]$Prawa)
    foreach ($kontrolka in $Kontrolki) {
        if ($kontrolka) { $kontrolka.Left = $Prawa - $kontrolka.Width }
    }
}

# Zsuwa kontrolki w dol (wszystkie o tyle samo), zeby najwyzsza nie weszla na pole wiersz wyzej.
function Set-JezykPonizejPola {
    param([object[]]$Kontrolki, $Pole, [int]$Odstep)

    $gora = [int]::MaxValue
    foreach ($kontrolka in $Kontrolki) {
        if ($kontrolka -and $kontrolka.Top -lt $gora) { $gora = $kontrolka.Top }
    }

    $nadmiar = ($Pole.Top + $Pole.Height + $Odstep) - $gora
    if ($nadmiar -le 0) { return }

    foreach ($kontrolka in $Kontrolki) {
        if ($kontrolka) { $kontrolka.Top = $kontrolka.Top + $nadmiar }
    }
}

# Szerokosc przycisku z napisu i czterech spacji (margines rosnie z czcionka).
function Get-JezykSzerokoscPrzycisku {
    param([string]$Napis, $Czcionka)

    $bezMarginesow = [System.Windows.Forms.TextFormatFlags]::NoPadding
    $pomiar = [System.Windows.Forms.TextRenderer]::MeasureText($Napis, $Czcionka,
                                                              [System.Drawing.Size]::Empty, $bezMarginesow)
    return ($pomiar.Width + 4 * (Get-JezykSzerokoscSpacji $Czcionka))
}

# Szerokosc spacji przy danej czcionce (roznica "x x" i "xx", bez marginesow).
function Get-JezykSzerokoscSpacji {
    param($Czcionka)

    $bezMarginesow = [System.Windows.Forms.TextFormatFlags]::NoPadding
    $zSpacja = [System.Windows.Forms.TextRenderer]::MeasureText('x x', $Czcionka, [System.Drawing.Size]::Empty, $bezMarginesow)
    $bezSpacji = [System.Windows.Forms.TextRenderer]::MeasureText('xx', $Czcionka, [System.Drawing.Size]::Empty, $bezMarginesow)
    $zSpacja.Width - $bezSpacji.Width
}

# Odstep napisu od kwadratu znacznika: jedna spacja czcionki napisu (napis to osobna etykieta).
function Get-JezykOdstepZnacznika {
    param($Czcionka)
    (Get-JezykSzerokoscSpacji $Czcionka) - $Script:PasZaZnacznikiem
}

# Szerokosc kwadratu kryjacego przycisk listy (SystemInformation - styk z systemem).
function Get-JezykSzerokoscStrzalki {
    [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + $Script:ZapasStrzalkiListy
}

# Stawia kwadrat ze strzalka na przycisku listy - od jej wymiarow, piksel wewnatrz z gory i z dolu.
function Set-JezykStrzalkaListy {
    param($Lista, $Strzalka, [int]$Szerokosc)

    if (-not $Lista -or -not $Strzalka) { return }

    $Strzalka.Width  = $Szerokosc
    $Strzalka.Height = $Lista.Height - 2
    $Strzalka.Left   = $Lista.Left + $Lista.Width - $Szerokosc - 1
    $Strzalka.Top    = $Lista.Top + 1
}

# Rozklada kontrolki po rownych slupkach i srodkuje kazda w swoim (pomiar musi byc juz zrobiony).
# Z -Napisy srodkuje sie para: kontrolka, -Odstep i jej napis.
function Set-JezykSrodekWSlupkach {
    param([object[]]$Kontrolki, [int]$Lewa, [int]$Szerokosc,
          [object[]]$Napisy = @(), [int]$Odstep = 0)

    $ile = @($Kontrolki).Count
    if ($ile -eq 0 -or $Szerokosc -le 0) { return }

    $slupek = $Szerokosc / $ile

    for ($i = 0; $i -lt $ile; $i++) {
        # Szerokosc calej pary.
        $napis = if ($i -lt @($Napisy).Count) { $Napisy[$i] } else { $null }
        $razem = $Kontrolki[$i].Width
        if ($napis) { $razem += $Odstep + $napis.Width }

        # Srodek slupka w jego polowie (+ 0.5), dzielenie zmiennoprzecinkowe.
        $srodek = $Lewa + [int]($slupek * ($i + 0.5))
        $Kontrolki[$i].Left = $srodek - [int]($razem / 2)

        if ($napis) { $napis.Left = $Kontrolki[$i].Left + $Kontrolki[$i].Width + $Odstep }
    }
}

# Zdejmuje AutoSize i srodkuje tresc w prostokacie o zadanej wysokosci - jedna linia pisma z sasiadami.
# -NajdluzszyTekst: szerokosc mierzona na najdluzszym mozliwym napisie (werdykt).
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

# Przycina etykiete nad polem, zeby przy duzej czcionce nie zakrywala jego gornej ramki (oba okna).
function Set-JezykEtykietaNadPolem {
    param($Etykieta)

    $wysokoscEtykiety = $Script:OdstepPodEtykieta - 2
    if ($Etykieta.AutoSize -and $Etykieta.Height -gt $wysokoscEtykiety) {
        Set-JezykSrodekTekstu $Etykieta $wysokoscEtykiety
    }
}

# Blokada zdarzen na czas programowego wypelniania listy - patrz Set-JezykListaKont.
$Script:BlokadaZdarzen = $false

# Styl ramki z palety (ramki nie da sie pomalowac); straz na wlasciwosc BorderStyle, nie na typ.
function Set-JezykRamkeKontrolki {
    param($Kontrolka)

    if (-not $Kontrolka) { return }
    if (-not $Kontrolka.PSObject.Properties['BorderStyle']) { return }

    $Kontrolka.BorderStyle = $Script:Config.RamkaPola
}

# Obcina krawedz listy rozwijanej o tyle pikseli, ile mowi paleta (bialej ramki nie da sie pomalowac).
# Straz na DropDownStyle, nie na typ.
function Set-JezykObciecieListy {
    param($Kontrolka)

    if (-not $Kontrolka) { return }
    if (-not $Kontrolka.PSObject.Properties['DropDownStyle']) { return }

    $ile = [int]$Script:Config.ObciecieListy

    # Powrot do jasnego motywu musi obciecie zdjac.
    if ($ile -le 0) {
        $Kontrolka.Region = $null
        return
    }

    $Kontrolka.Region = New-JezykObszar $ile $ile `
                                        ($Kontrolka.Width  - 2 * $ile) `
                                        ($Kontrolka.Height - 2 * $ile)
}

# Maluje kontrolke wedlug ROLI (nie typu) kolorami z palety; -Rejestruj tylko z New-JezykForm.
# Kolor niosacy znaczenie ustawia Set-JezykKolorPola - i on ma ostatnie slowo.
function Set-JezykWyglad {
    param($Kontrolka,
          [ValidateSet('Okno', 'Pole', 'Lista', 'Przycisk', 'Podpis',
                       'InfoProblem', 'InfoNiebieski', 'Ikona', 'StrzalkaListy')][string]$Rola,
          [switch]$Rejestruj)

    if (-not $Kontrolka) { return }

    if ($Rejestruj) { $Script:KontrolkiMotywu[$Kontrolka] = $Rola }

    switch ($Rola) {
        'Okno' {
            $Kontrolka.BackColor = $Script:Config.KolorOkna
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
        }
        'Pole' {
            # Tlo jawnie - pole ReadOnly rysowaloby sie na tle okna.
            $Kontrolka.BackColor = $Script:Config.KolorTla
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            Set-JezykRamkeKontrolki $Kontrolka
        }
        'Podpis' {
            # Podpis przygaszony wzgledem wszystkiego, co cos znaczy.
            $Kontrolka.BackColor = $Script:Config.KolorOkna
            $Kontrolka.ForeColor = $Script:Config.KolorNieznany
        }
        'Lista' {
            $Kontrolka.BackColor = $Script:Config.KolorKontrolki
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            Set-JezykRamkeKontrolki $Kontrolka
            Set-JezykObciecieListy  $Kontrolka
        }
        'Przycisk' {
            $Kontrolka.BackColor = $Script:Config.KolorKontrolki
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            $Kontrolka.FlatAppearance.BorderColor = $Script:Config.KolorObramowki
        }
        'InfoProblem' {
            $Kontrolka.BackColor = $Script:Config.KolorProblemTlo
            $Kontrolka.ForeColor = $Script:Config.KolorProblem
            $Kontrolka.FlatAppearance.BorderColor = $Script:Config.KolorProblem
        }
        'InfoNiebieski' {
            $Kontrolka.BackColor = $Script:Config.KolorInfoTlo
            $Kontrolka.ForeColor = $Script:Config.KolorInfo
            $Kontrolka.FlatAppearance.BorderColor = $Script:Config.KolorInfo
        }
        'Ikona' {
            # Invalidate - zmiana BackColor nie wywoluje Paint; bez FlatAppearance (PictureBox go nie ma).
            $Kontrolka.BackColor = $Script:Config.KolorOkna
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            $Kontrolka.Invalidate()
        }
        'StrzalkaListy' {
            # Kwadrat listy: wlasny klucz palety (w jasnym motywie systemowy); Invalidate jak wyzej.
            $Kontrolka.BackColor = $Script:Config.KolorPrzyciskuListy
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            $Kontrolka.Invalidate()
        }
    }
}

# Etykieta opisujaca pole.
function New-JezykEtykieta {
    param([string]$Tekst, [int]$X, [int]$Y)

    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.Text     = $Tekst
    $lbl.Location = [System.Drawing.Point]::new($X, $Y)
    $lbl.AutoSize = $true
    $lbl
}

# Pole tylko do odczytu: ReadOnly (tresc da sie skopiowac), sama szerokosc (wysokosc z czcionki).
function New-JezykPole {
    param([int]$X, [int]$Y, [int]$Szerokosc)

    $txt           = New-Object System.Windows.Forms.TextBox
    $txt.Location  = [System.Drawing.Point]::new($X, $Y)
    $txt.Width     = $Szerokosc
    $txt.ReadOnly  = $true
    Set-JezykWyglad $txt 'Pole' -Rejestruj
    $txt
}

# Znacznik tylko do odczytu: AutoCheck = $false zamiast Enabled = $false (wyszarzony slabo widac).
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

# Kwadrat ze strzalka kryjacy przycisk listy - etykieta, nie przycisk (bez ramki i wcisniecia).
function New-JezykStrzalkaListy {
    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $false
    $lbl.Text     = ''
    Set-JezykWyglad $lbl 'StrzalkaListy' -Rejestruj
    $lbl
}

# Przycisk "!" (nastepca dymka): powstaje niewidoczny, pokazuje go Set-JezykInfo; klucz w Tag.
function New-JezykPrzyciskInfo {
    # -BezRejestracji dla okna na zadanie - zarejestrowany przycisk zostalby w rejestrze po Dispose().
    param([string]$Klucz, [int]$Bok = 18, [switch]$BezRejestracji)

    $btn           = New-Object System.Windows.Forms.Button
    $btn.Text      = '!'
    $btn.Tag       = $Klucz
    $btn.Size      = [System.Drawing.Size]::new($Bok, $Bok)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btn 'InfoProblem' -Rejestruj:(-not $BezRejestracji)
    $btn.FlatAppearance.BorderSize  = 2
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btn.TabStop   = $false
    $btn.Visible   = $false

    # Zerowe marginesy - inaczej "!" nie miesci sie w kwadracie 18 px.
    $btn.Padding = [System.Windows.Forms.Padding]::new(0)
    $btn.Margin  = [System.Windows.Forms.Padding]::new(0)
    $btn
}

# Stawia "!" w linii etykiety, prawa krawedzia na widocznej krawedzi pola; pion z linii pisma.
function Set-JezykPrzyciskPrzyEtykiecie {
    param($Przycisk, $Etykieta, $Pole)

    if (-not $Przycisk -or -not $Etykieta -or -not $Pole) { return }

    $wysokoscLinii = [int][math]::Ceiling($Etykieta.Font.GetHeight())

    $Przycisk.Left = $Pole.Left + $Pole.Width - $Script:CofniecieWykrzyknika - $Przycisk.Width
    $Przycisk.Top  = $Etykieta.Top + [int](($wysokoscLinii - $Przycisk.Height) / 2)
}

# Wysokosc okna z pokazanego panelu (tylko ClientSize, nie Location) i pas podpisu pod nim.
function Set-JezykWysokoscOkna {
    param([int]$GoraPanelu, [int]$WysokoscPanelu)

    $k        = $Script:Kontrolki
    $wysokosc = Get-JezykWysokoscOkna $GoraPanelu $WysokoscPanelu

    $goraPasa = $wysokosc - $Script:WysokoscPasaPodpisu - 2
    $k.PodpisAutor.Top   = $goraPasa
    $k.PodpisWersja.Top  = $goraPasa
    $k.PrzyciskMotyw.Top = $goraPasa

    $k.Okno.ClientSize = [System.Drawing.Size]::new($Script:SzerokoscOkna,
                                                    (Get-JezykWysokoscWEkranie $wysokosc))
}

# Wiersze paneli zasilane przez SCCM (opis zaklada New-JezykForm); uklad startowy pelny.
$Script:WierszeSccm      = @()
$Script:UkladBezSccm     = $false
# Zapisane przesuniecia "kontrolka + wlasciwosc + piksele" - powrot cofa dokladnie je.
$Script:PrzesunieciaSccm = @()

# Chowa wiersze SCCM poza DomenyZSccm i zsuwa pod nimi kazda kontrolke panelu, albo cofa to.
# Przesuniecia zapisane, nie liczone drugi raz; przy powrocie wraca widocznosc tylko stalych.
function Set-JezykUkladSccm {
    param([bool]$ZSccm)

    $bezSccm = -not $ZSccm
    if ($bezSccm -eq $Script:UkladBezSccm) { return }

    if ($bezSccm) {
        foreach ($opis in @($Script:WierszeSccm)) {
            $progi  = @($opis.Wiersze | ForEach-Object { $_.Top })
            $ukryte = @($opis.Stale) + @($opis.Zmienne)

            foreach ($kontrolka in $ukryte) { $kontrolka.Visible = $false }

            foreach ($kontrolka in @($opis.Panel.Controls)) {
                if ($ukryte -contains $kontrolka) { continue }

                $wierszy = @($progi | Where-Object { $_ -lt $kontrolka.Top }).Count
                if ($wierszy -eq 0) { continue }

                $piksele = $wierszy * $Script:SkokWiersza
                $kontrolka.Top = $kontrolka.Top - $piksele
                $Script:PrzesunieciaSccm += [pscustomobject]@{
                    Kontrolka = $kontrolka; Wlasciwosc = 'Top'; Piksele = $piksele }
            }

            $piksele = $progi.Count * $Script:SkokWiersza
            $opis.Panel.Height = $opis.Panel.Height - $piksele
            $Script:PrzesunieciaSccm += [pscustomobject]@{
                Kontrolka = $opis.Panel; Wlasciwosc = 'Height'; Piksele = $piksele }
        }
    }
    else {
        foreach ($przesuniecie in @($Script:PrzesunieciaSccm)) {
            $kontrolka  = $przesuniecie.Kontrolka
            $wlasciwosc = $przesuniecie.Wlasciwosc
            $kontrolka.$wlasciwosc = $kontrolka.$wlasciwosc + $przesuniecie.Piksele
        }
        $Script:PrzesunieciaSccm = @()

        foreach ($opis in @($Script:WierszeSccm)) {
            foreach ($kontrolka in @($opis.Stale)) { $kontrolka.Visible = $true }
        }
    }

    $Script:UkladBezSccm = $bezSccm
}

# Pokazuje widok wybranego trybu; przy kazdej zmianie czysci OBA widoki.
function Set-JezykWidok {
    $k    = $Script:Kontrolki
    $tryb = [string]$k.Tryb.SelectedItem

    $komputer = ($tryb -eq $Script:Config.TrybKomputer)
    # Lista wyboru tylko przy wyszukiwaniu kont.
    $zListą = (-not $komputer)

    $k.ListaKont.Visible = $zListą
    $Script:BlokadaZdarzen = $true
    try { $k.ListaKont.Items.Clear() } finally { $Script:BlokadaZdarzen = $false }

    Clear-JezykKonto
    Clear-JezykKomputer

    # Jez gasnie - wynik, o ktorym mowil, zniknal.
    Set-JezykStanJeza 'Ukryty'

    # Wiersze SCCM przed wysokoscia okna - zsuniecie zmienia wysokosc paneli.
    Set-JezykUkladSccm (Test-JezykDomenaZSccm $Script:Config.Domena)

    $gora = if ($zListą) { $Script:PanelZListą } else { $Script:PanelBezListy }

    $k.PanelKonto.Visible    = (-not $komputer)
    $k.PanelKomputer.Visible = $komputer

    # Panel i wysokosc okna razem; wysokosc z kontrolki panelu, nie liczona drugi raz.
    if ($komputer) {
        $k.PanelKomputer.Location = [System.Drawing.Point]::new(0, $gora)
        Set-JezykWysokoscOkna $gora $k.PanelKomputer.Height
    } else {
        $k.PanelKonto.Location = [System.Drawing.Point]::new(0, $gora)
        Set-JezykWysokoscOkna $gora $k.PanelKonto.Height
    }
}


# --- ZADANIA W TLE -------------------------------------------------------------------
# Siedem niezaleznych zadan (Logowanie, Komputer, Uzytkownik, Ping, Numer, Dysk, Grupa), kazde
# z wlasnym licznikiem pokolen; wynik odbiera zegar WinForms na watku interfejsu (README: Praca w tle).
$Script:PokolenieLogowania  = 0
$Script:PokolenieKomputera  = 0
$Script:PokolenieUzytkownika = 0
$Script:PokoleniePingu      = 0
$Script:PokolenieNumeru     = 0
$Script:PokolenieDysku      = 0
$Script:PokolenieGrupy      = 0
$Script:ZadanieLogowania    = $null
$Script:ZadanieKomputera    = $null
$Script:ZadanieUzytkownika  = $null
$Script:ZadaniePingu        = $null
$Script:ZadanieNumeru       = $null
$Script:ZadanieDysku        = $null
$Script:ZadanieGrupy        = $null
$Script:ZegarTla            = $null

# Czy Status niesie notke "trwa szukanie po numerze" (a nie odpowiedz); zerowany przy kazdym szukaniu.
$Script:StatusCzekaNaNumer  = $false

# Czy pola SCCM (komputer, IP, MAC) niosa notke "sprawdzanie" - marker gasi kazda galaz odpowiedzi.
$Script:PolaCzekajaNaSccm   = $false

# To samo dla pola "Ostatnie logowanie" - osobne zadanie, osobny marker.
$Script:PoleCzekaNaLogowanie = $false

# Czy Status widoku komputera niesie notke "Łączenie".
$Script:StatusCzekaNaDysk    = $false

# Zdanie sprzed notki "Łączenie" - wraca przy rezygnacji z okna poswiadczen.
$Script:StatusPrzedLaczeniem = ''

# Okno grup, ktorego Status niesie notke "Sprawdzanie" ($null - zadne; okno nie jest w rejestrze kontrolek).
$Script:OknoSprawdzaniaGrupy = $null

# Numer klatki kropek - wspolny dla wszystkich notek.
$Script:KlatkaKropek        = 0

# Taktow zegara (250 ms) na klatke kropek - kropki co 500 ms.
$Script:TaktowNaKlatkeKropek = 2

# Nazwa pokazanej maszyny - zrodlo prawdy dla "Pinguj", "Polacz" i "Dyski" (wspolna dla obu widokow).
$Script:OstatniKomputer = ''

# Ktory widok zamowil sonde z "Pinguj" - odpowiedz wraca bez sladu po zamawiajacym.
$Script:WidokSondy = 'Konto'

# Adres IP, do ktorego dopasowano pokazany MAC.
$Script:MacDlaAdresu = ''

# Odpowiedz sondy dla pokazanej maszyny - $true, $false albo $null (wspolna dla obu widokow).
$Script:MaszynaOdpowiada = $null

# Gotowe teksty skryptow dla wszystkich zadan - skladane raz, patrz New-JezykSkryptTla.
$Script:SkryptyTla = @{}

# Zadania PORZUCONE w polowie, czekajace na zwolnienie - patrz Stop-JezykZadanieTla.
$Script:ZadaniaPorzucone = @()

# Po ilu ms porzucone zadanie przestaje byc sprawdzane co takt (przechodzi do spisanych).
$Script:TerminPorzuconegoMs = 120000

# Zadania spisane - zwalniane dopiero po faktycznym zakonczeniu; ponad limit wypadaja najstarsze.
$Script:ZadaniaSpisane  = @()
$Script:LimitSpisanych  = 50

# Slad wywolan, ktore za dlugo trzymaly watek interfejsu (ostatnie 20, prog 250 ms).
$Script:DiagnostykaTla    = @()
$Script:ProgDiagnostykiMs = 250
$Script:LimitDiagnostyki  = 20

# Zapisuje wywolanie (Open, BeginInvoke, BeginStop, Dispose), ktore trzymalo watek dluzej niz prog.
function Add-JezykDiagnostyke {
    param([string]$Nazwa, [long]$Ms)

    if ($Ms -lt $Script:ProgDiagnostykiMs) { return }

    $Script:DiagnostykaTla += '{0:HH:mm:ss}  {1}: {2} ms' -f (Get-Date), $Nazwa, $Ms
    if ($Script:DiagnostykaTla.Count -gt $Script:LimitDiagnostyki) {
        $Script:DiagnostykaTla = @($Script:DiagnostykaTla | Select-Object -Last $Script:LimitDiagnostyki)
    }

    # "!" przy Status pokazuje slad od razu (wolane zawsze z watku interfejsu).
    $przycisk = $Script:Kontrolki['InfoStatus']
    if ($przycisk) { $przycisk.Visible = $true }
}

# Lista kontrolerow per domena z poprzedniego wyszukania (tylko w pamieci).
$Script:KontroleryCache = @{}

# Ostatni odczyt z AD - zrodlo prawdy dla zapisu.
$Script:OstatnieKonto = $null

# Data przyblizona pokazanego konta - potrzebna obu etapom wypelniania pola.
$Script:LogowaniePrzyblizone = $null

# Sklada (raz) tekst skryptu dla przestrzeni w tle: KOMPLET wstrzykiwanych funkcji, param() pierwsze.
function New-JezykSkryptTla {
    param([ValidateSet('Logowanie', 'Komputer', 'Uzytkownik', 'Ping', 'Numer', 'Dysk', 'Grupa')][string]$Zadanie)

    if ($Script:SkryptyTla.ContainsKey($Zadanie)) { return $Script:SkryptyTla[$Zadanie] }

    # Komplet zaleznosci obu zapytan do SCCM (z dopasowaniem karty sieciowej) - jedna lista dla obu.
    $sccm = @('Test-JezykNazwaKonta', 'Test-JezykNazwaHosta',
              'Get-JezykSccmPolaczenie', 'Test-JezykPortOtwarty',
              'Get-JezykOpisBleduWmi', 'Open-JezykSesjaSccm',
              'Invoke-JezykZapytanieWmi', 'Invoke-JezykZapytanieWmiStare',
              'Invoke-JezykZapytanieSccm', 'ConvertTo-JezykCzasLokalny',
              'Get-JezykRozbiteWpisy', 'Get-JezykBajtyIPv4', 'Test-JezykMaskaIPv4',
              'Test-JezykTaSamaPodsiec', 'Get-JezykKartySieciowe',
              'Get-JezykMacDlaAdresu', 'Get-JezykDopasowanieMac',
              'Set-JezykMacWWyniku')

    if ($Zadanie -eq 'Numer') {
        # Numer telefonu: najwolniejsze zadanie (atrybuty bez indeksu). Lista to domkniecie przechodnie.
        $funkcje = 'Get-JezykCyfry', 'Test-JezykNumerPasuje', 'Get-JezykOsoba',
                   'New-JezykPozycjaKonta', 'Find-JezykUsersPoNumerze',
                   'Find-JezykPozycjePoNumerze'

        # Import modulu AD bezwarunkowo - Get-ADUser jest tu jedyna droga.
        $naglowek  = 'param($Cyfry, $Limit, $Serwer, $SzukajOd)'
        $naglowek += "`r`n" + 'Import-Module ActiveDirectory -ErrorAction SilentlyContinue'
        $wywolanie = 'Find-JezykPozycjePoNumerze -Cyfry $Cyfry -Limit $Limit' +
                     ' -Serwer $Serwer -SzukajOd $SzukajOd'
    }
    elseif ($Zadanie -eq 'Ping') {
        # Sama sonda ICMP ("Pinguj") - bez powtarzania zapytania do SCCM.
        $funkcje = 'Test-JezykNazwaHosta', 'Get-JezykAdresyDoSondy', 'Get-JezykPingKomputera'

        $naglowek  = 'param($Netbios)'
        $wywolanie = 'Get-JezykPingKomputera -Nazwa $Netbios'
    }
    elseif ($Zadanie -eq 'Dysk') {
        # Cicha proba polaczenia z udzialem; "potrzeba poswiadczen" wraca na watek interfejsu.
        $funkcje = 'Test-JezykNazwaKonta', 'Get-JezykSciezkaUdzialu',
                   'Get-JezykStanPolaczeniaUdzialu', 'Invoke-JezykPolaczenieUdzialu',
                   'Connect-JezykUdzialDysku'

        $naglowek  = 'param($Netbios, $Litera)'
        $wywolanie = 'Connect-JezykUdzialDysku -Netbios $Netbios -Litera $Litera'
    }
    elseif ($Zadanie -eq 'Grupa') {
        # "Sprawdz nazwy" w oknie grup - drugi przebieg (cn=*...*) przeglada cala domene.
        $funkcje = 'Get-JezykFrazaLdap', 'Get-JezykOpisBledu', 'Get-JezykFolderAd',
                   'Get-JezykPodpisyGrup', 'Find-JezykGrupyPoNazwie'

        # Import modulu AD bezwarunkowo - Get-ADGroup jest tu jedyna droga.
        $naglowek  = 'param($Fraza, $Limit, $Serwer)'
        $naglowek += "`r`n" + 'Import-Module ActiveDirectory -ErrorAction SilentlyContinue'
        $wywolanie = 'Find-JezykGrupyPoNazwie -Fraza $Fraza -Limit $Limit -Serwer $Serwer'
    }
    elseif ($Zadanie -eq 'Logowanie') {
        $funkcje = 'Test-JezykNazwaHosta', 'Test-JezykDn',
                   'Get-JezykLastLogonZKontrolera', 'Invoke-JezykRownolegle',
                   'Get-JezykOstatnieLogowanie'

        # Modul AD tylko gdy trzeba rozpoznac kontrolery albo isc droga zapasowa (import trwa 1-3 s).
        $naglowek  = 'param($Login, $Domena, $Dn, $Kontrolery)'
        $naglowek += "`r`n" + 'if (-not $Dn -or @($Kontrolery).Count -eq 0) {' +
                     ' Import-Module ActiveDirectory -ErrorAction SilentlyContinue }'
        $wywolanie = 'Get-JezykOstatnieLogowanie -Login $Login -Domena $Domena -Dn $Dn -Kontrolery $Kontrolery'
    }
    elseif ($Zadanie -eq 'Komputer') {
        # Droga od loginu do maszyny; rozbior pol z kontami (Get-JezykKontaMaszyny) tylko tutaj.
        $funkcje = $sccm + @('Get-JezykAdresyDoSondy', 'Get-JezykPingKomputera',
                             'Get-JezykKontaZPola', 'Get-JezykKontaMaszyny',
                             'Select-JezykMaszyneDlaLoginu',
                             'Get-JezykOstatnioUzywanyKomputer')

        # Zadanie SCCM idzie przez WMI i modulu AD nie potrzebuje w ogole.
        $naglowek  = 'param($Login, $SccmSerwer, $SccmKodLokacji, $SccmProtokol, $SccmProtokolZapasowy)'
        $wywolanie = 'Get-JezykOstatnioUzywanyKomputer -Login $Login -Serwer $SccmSerwer' +
                     ' -KodLokacji $SccmKodLokacji -Protokol $SccmProtokol' +
                     ' -ProtokolZapasowy $SccmProtokolZapasowy'
    }
    else {
        # Droga odwrotna: od maszyny do uzytkownika (z sonda i dopasowaniem karty).
        $funkcje = $sccm + @('Get-JezykAdresyDoSondy', 'Get-JezykPingKomputera',
                             'Get-JezykUzytkownikKomputera')

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

# Przestrzen uruchomieniowa (MTA) z gotowym skryptem - dostaje wylacznie tekst, zadnych kontrolek.
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
    # Bez loginu zadanie nie rusza - pole wraca do samej daty przyblizonej.
    if (-not $Login) { Set-JezykPoleLogowaniaBezTla; return }

    $Script:PokolenieLogowania++
    $mojePokolenie = $Script:PokolenieLogowania
    $domena        = $Script:Config.Domena

    # Kontrolery: z konfiguracji, potem z pamieci poprzedniego wyszukania, na koncu z katalogu.
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
        # Awaria uruchomienia nie przerywa okna - data przyblizona juz stoi w polu.
        Set-JezykPoleLogowaniaBezTla
    }
}

# Uruchamia w tle zapytanie do SCCM o ostatnio uzywany komputer.
function Start-JezykZadanieKomputera {
    param([string]$Login)

    Stop-JezykZadanieKomputera
    # Jak wyzej: bez loginu nie ma o co pytac SCCM, a zapalona notka mrugalaby bez konca.
    if (-not $Login) { Set-JezykPoleKomputeraBezTla -Blad ''; return }

    # Brak ustawien SCCM - odpowiedz od razu, ta sama droga renderowania (bez przestrzeni w tle).
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

# Uruchamia w tle zapytanie SCCM o ostatnio zalogowanego uzytkownika maszyny (z sonda i MAC).
function Start-JezykZadanieUzytkownika {
    param([string]$Netbios)

    Stop-JezykZadanieUzytkownika
    if (-not $Netbios) { return }

    # Brak ustawien SCCM - odpowiedz od razu, ta sama droga renderowania.
    $polaczenie = Get-JezykSccmPolaczenie -Serwer     ([string]$Script:Ustawienia.SccmSerwer) `
                                          -KodLokacji ([string]$Script:Ustawienia.SccmKodLokacji) `
                                          -Protokol   ([string]$Script:Ustawienia.SccmProtokol)
    if ($polaczenie.Blad) {
        # Pelny ksztalt z polami sondy - renderer czyta je wszystkie; sonda pojdzie osobnym zadaniem.
        Update-JezykUzytkownikaWTle -Uzytkownik ([pscustomobject]@{
            Uzytkownik = ''; Data = $null; Blad = 'brak ustawień SCCM'; Szczegoly = $polaczenie.Blad
            Odpowiada = $null; Adres = ''; Mac = ''; MacSzczegoly = ''
            MacPodstawa = ''; MacKarta = $null; MacKarty = @(); MacWpisow = 0 })
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

# Uruchamia w tle sonde ICMP maszyny z ekranu (przycisk "Pinguj"); wlasny licznik pokolen.
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
        # Nieudane uruchomienie - stan "nie wiadomo", nie czerwony napis.
        Update-JezykPingWTle -Ping ([pscustomobject]@{
            Odpowiada = $null; Adres = ''; Blad = 'nie sprawdzono'; Szczegoly = $_.Exception.Message })
    }
}

# Uruchamia w tle wyszukiwanie po numerze telefonu - konfiguracja idzie argumentami.
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
        # Nieudane uruchomienie to przerwanie, nie pusty wynik.
        Update-JezykNumerWTle -Wynik ([pscustomobject]@{
            Trafienia = @(); ZaDuzo = $false; Przerwane = $true
            Powod     = 'Nie udało się uruchomić wyszukiwania po numerze telefonu: {0}' -f $_.Exception.Message })
    }
}

# Uruchamia w tle cicha probe polaczenia z udzialem (przycisk "Dyski"); wlasny licznik pokolen.
function Start-JezykZadanieDysku {
    param([string]$Netbios, [string]$Litera)

    Stop-JezykZadanieDysku

    # Bez maszyny albo litery zadanie nie rusza - notka gasnie.
    if (-not $Netbios -or -not $Litera) { Set-JezykNotkeLaczenia -Wylacz; return }

    $Script:PokolenieDysku++
    $mojePokolenie = $Script:PokolenieDysku

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Dysk')
        [void]$zadanie.Ps.AddArgument($Netbios).AddArgument($Litera)

        $Script:ZadanieDysku = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania polaczenia z udzialem' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        # Nieudane uruchomienie - ta sama droga co odpowiedz (notke trzeba zgasic).
        Update-JezykDyskWTle -Wynik ([pscustomobject]@{
            Stan = 'Blad'; Kod = $null; Sciezka = ''
            Komunikat = 'Nie udało się zacząć łączenia z udziałem.'
            Szczegoly = $_.Exception.Message })
    }
}

# Uruchamia w tle "Sprawdz nazwy" okna grup; okno jedzie w uchwycie - odpowiedz wie, dokad wrocic.
function Start-JezykZadanieGrupy {
    param($Okno, [string]$Fraza, [int]$Limit)

    Stop-JezykZadanieGrupy

    $Script:PokolenieGrupy++
    $mojePokolenie = $Script:PokolenieGrupy

    try {
        $zegar = [System.Diagnostics.Stopwatch]::StartNew()

        $zadanie = New-JezykPrzestrzenTla (New-JezykSkryptTla 'Grupa')
        [void]$zadanie.Ps.AddArgument($Fraza).
                          AddArgument($Limit).
                          AddArgument([string]$Script:Config.Domena)

        $Script:ZadanieGrupy = [pscustomobject]@{
            Ps          = $zadanie.Ps
            Przestrzen  = $zadanie.Przestrzen
            Uchwyt      = $zadanie.Ps.BeginInvoke()
            Pokolenie   = $mojePokolenie
            Okno        = $Okno
            Fraza       = $Fraza
            Limit       = $Limit
            Przerwane   = $false
            PorzuconeO  = $null
        }

        Add-JezykDiagnostyke 'uruchomienie zadania sprawdzania nazwy grupy' $zegar.ElapsedMilliseconds

        if ($Script:ZegarTla) { $Script:ZegarTla.Start() }
    }
    catch {
        # Nieudane uruchomienie to przerwanie, nie pusty wynik - ta sama droga co odpowiedz.
        Update-JezykNazwaGrupyWTle -Okno $Okno -Fraza $Fraza -Limit $Limit -Wynik ([pscustomobject]@{
            Trafienia = @(); ZaDuzo = $false; Przerwane = $true
            Powod     = 'Nie udało się uruchomić sprawdzania nazwy grupy: {0}' -f $_.Exception.Message })
    }
}

# Odbiera wynik zadania daty, jesli gotowy; wynik z innego pokolenia odrzucany.
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

# Odbiera trafienia po numerze; wynik z innego pokolenia odrzucany.
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

# Odbiera odpowiedz proby polaczenia z udzialem - zadanie zdjete z rejestru PRZED renderowaniem.
# Uwaga: okno poswiadczen pompuje takty zegara - bez tego stanelo by drugie okno nad pierwszym.
function Receive-JezykZadanieDysku {
    $zadanie = $Script:ZadanieDysku
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    $Script:ZadanieDysku = $null

    $wynik = $null
    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($dane.Count -gt 0) { $wynik = $dane[0] }
    }
    catch {
        $wynik = [pscustomobject]@{
            Stan = 'Blad'; Kod = $null; Sciezka = ''
            Komunikat = 'Łączenie z udziałem zawiodło.'
            Szczegoly = $_.Exception.Message }
    }

    Stop-JezykZadanieTla $zadanie

    if ($zadanie.Pokolenie -ne $Script:PokolenieDysku) { return }

    # Pusta odpowiedz tez jest odpowiedzia - notka nie moze zostac.
    if ($null -eq $wynik) {
        $wynik = [pscustomobject]@{
            Stan = 'Blad'; Kod = $null; Sciezka = ''
            Komunikat = 'Łączenie z udziałem nie dało odpowiedzi.'
            Szczegoly = 'Zadanie w tle zakończyło się, nie oddając wyniku.' }
    }

    Update-JezykDyskWTle -Wynik $wynik
}

# Odbiera odpowiedz "Sprawdz nazwy" - zadanie zdjete z rejestru PRZED renderowaniem.
# Uwaga: okno wyboru grupy pompuje takty zegara (README: Kod > Jezyk-4-Okno > Zadania w tle).
function Receive-JezykZadanieGrupy {
    $zadanie = $Script:ZadanieGrupy
    if (-not $zadanie -or -not $zadanie.Uchwyt.IsCompleted) { return }

    $Script:ZadanieGrupy = $null

    $wynik = $null
    try {
        $dane = @($zadanie.Ps.EndInvoke($zadanie.Uchwyt))
        if ($dane.Count -gt 0) { $wynik = $dane[0] }
    }
    catch {
        $wynik = [pscustomobject]@{
            Trafienia = @(); ZaDuzo = $false; Przerwane = $true
            Powod     = 'Sprawdzanie nazwy grupy zawiodło: {0}' -f $_.Exception.Message }
    }

    Stop-JezykZadanieTla $zadanie

    if ($zadanie.Pokolenie -ne $Script:PokolenieGrupy) { return }

    # Pusta odpowiedz tez jest odpowiedzia - notka nie moze zostac.
    if ($null -eq $wynik) {
        $wynik = [pscustomobject]@{
            Trafienia = @(); ZaDuzo = $false; Przerwane = $true
            Powod     = 'Zadanie w tle zakończyło się, nie oddając wyniku.' }
    }

    Update-JezykNazwaGrupyWTle -Okno $zadanie.Okno -Wynik $wynik `
                               -Fraza ([string]$zadanie.Fraza) -Limit ([int]$zadanie.Limit)
}

# Sprzata zadanie: zakonczone zwalnia od razu, biegnace przerywa asynchronicznie (BeginStop, raz)
# i odklada na liste porzuconych - Stop() zamrozilby okno.
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

# Zwalnia zadania, ktore juz sie zatrzymaly: porzucone co takt, po terminie przenosi do spisanych.
# Uwaga: Dispose wylacznie na zakonczonym - na biegnacym zablokowalby okno (README: Praca w tle).
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
        # Dispose wylacznie na zadaniu zakonczonym.
        if ($zadanie.Uchwyt -and -not $zadanie.Uchwyt.IsCompleted) { $czekaja += $zadanie; continue }

        $zegar = [System.Diagnostics.Stopwatch]::StartNew()
        try { $zadanie.Ps.Dispose() }         catch { }
        try { $zadanie.Przestrzen.Dispose() } catch { }
        Add-JezykDiagnostyke 'zwolnienie spisanego zadania (Dispose)' $zegar.ElapsedMilliseconds
    }

    # Sufit - ponad nim przepadaja najstarsze.
    if ($czekaja.Count -gt $Script:LimitSpisanych) {
        $ilePrzepada = $czekaja.Count - $Script:LimitSpisanych
        Add-JezykDiagnostyke ('spisane porzucone bez zwolnienia (sufit {0}): {1}' -f
                              $Script:LimitSpisanych, $ilePrzepada) $Script:ProgDiagnostykiMs
        $czekaja = @($czekaja | Select-Object -Last $Script:LimitSpisanych)
    }

    $Script:ZadaniaSpisane = $czekaja
}

# Porzucenie zadania danego rodzaju (siedem blizniakow ponizej).
# $null najpierw - ponowne wejscie nie wezmie tego samego obiektu drugi raz.
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

function Stop-JezykZadanieDysku {
    if (-not $Script:ZadanieDysku) { return }
    $zadanie = $Script:ZadanieDysku
    $Script:ZadanieDysku = $null
    Stop-JezykZadanieTla $zadanie
}

function Stop-JezykZadanieGrupy {
    if (-not $Script:ZadanieGrupy) { return }
    $zadanie = $Script:ZadanieGrupy
    $Script:ZadanieGrupy = $null
    Stop-JezykZadanieTla $zadanie
}

# Sprzatanie przy zamykaniu okna; zegar zatrzymywany na koncu (porzucenie zadania go uruchamia).
function Stop-JezykZadaniaTla {
    Stop-JezykZadanieLogowania
    Stop-JezykZadanieKomputera
    Stop-JezykZadanieUzytkownika
    Stop-JezykZadaniePingu
    Stop-JezykZadanieNumeru
    Stop-JezykZadanieDysku
    Stop-JezykZadanieGrupy

    # Ostatnie podejscie do porzuconych; reszta odchodzi razem z procesem.
    Clear-JezykZadaniaPorzucone

    if ($Script:ZegarTla) { $Script:ZegarTla.Stop() }
}

# Tytul okna grup: podpis konta i licznik - "42" przy pelnej liscie, "3 z 42" po zawezeniu.
function Get-JezykTytulGrup {
    param([string]$Podpis, [int]$Ile, [int]$Wszystkich)

    # Uwaga: napisy do zmiennych - w argumencie metody przecinki naleza do metody.
    $licznik = if ($Ile -eq $Wszystkich) { [string]$Wszystkich }
               else                      { '{0} z {1}' -f $Ile, $Wszystkich }

    $tytul = 'Jeżyk - Grupy AD: {0} ({1})' -f $Podpis, $licznik
    return $tytul
}

# Grupy pasujace do fragmentu nazwy (IndexOf, nie -like - tekst, nie wzorzec; w dowolnym miejscu).
# Oddaje PARY - numeruje je Get-JezykWierszeGrup z tej samej tablicy (README: Usuniecie bierze grupe).
function Select-JezykGrupyDoPokazania {
    param([object[]]$Grupy, [string]$Fraza)

    # Jedna pisownia - $fraza i $Fraza to ta sama zmienna.
    $Fraza = ([string]$Fraza).Trim()
    $wynik = @()

    foreach ($grupa in @(Get-JezykParyGrup $Grupy)) {
        # Po nazwie, nie po podpisie - grupy o tej samej nazwie zostaja albo znikaja razem.
        $nazwa = [string]$grupa.Nazwa
        if ($Fraza -and ($nazwa.IndexOf($Fraza, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)) {
            continue
        }
        $wynik += $grupa
    }

    # Wolajacy owija wynik w @() - PowerShell rozwija tablice.
    return @($wynik)
}

# Numeruje wiersze listy (1, 2, 3...) - jedyne miejsce numeracji; kolejnosc jak w tablicy wejsciowej.
# Wiersz niesie podpis (z folderem przy powtorzonej nazwie).
function Get-JezykWierszeGrup {
    param([object[]]$Grupy)

    $wiersze = @()
    $nr      = 0

    foreach ($grupa in @(Get-JezykParyGrup $Grupy)) {
        $nr++
        $wiersze += '{0}. {1}' -f $nr, ([string]$grupa.Podpis)
    }

    return @($wiersze)
}

# Nowy pierwszy widoczny wiersz po ruchu kolkiem - staly krok (3 wiersze), bez kontrolki.
# Truncate, nie [int] (zaokragla); dodatnia Delta = w gore listy.
function Get-JezykNowyWierszListy {
    param([int]$Gora, [int]$Delta, [int]$Ile, [int]$Widoczne, [int]$WierszeNaObrot = 3)

    if ($Delta -eq 0) { return $Gora }

    $obroty = [int][Math]::Truncate($Delta / 120)
    # Drobny skok kolka (ponizej 120) liczy sie jako jeden obrot - inaczej lista stalaby w miejscu.
    if ($obroty -eq 0) {
        if ($Delta -gt 0) { $obroty = 1 } else { $obroty = -1 }
    }

    # Ostatni wiersz ma dojsc na gore okna, ale nie wyzej - inaczej pod lista zostaje pustka.
    $najnizszy = $Ile - $Widoczne
    if ($najnizszy -lt 0) { $najnizszy = 0 }

    $nowa = $Gora - $obroty * $WierszeNaObrot
    if ($nowa -lt 0)          { $nowa = 0 }
    if ($nowa -gt $najnizszy) { $nowa = $najnizszy }
    return $nowa
}

# Przewija liste kolkiem wlasnym krokiem; Handled = $true, inaczej obsluga domyslna dodaje swoj.
function Set-JezykPrzewijanieListy {
    param($Lista, $Zdarzenie)

    if ($Zdarzenie.PSObject.Properties['Handled']) { $Zdarzenie.Handled = $true }

    $wysokoscWiersza = [int]$Lista.ItemHeight
    if ($wysokoscWiersza -le 0) { return }

    # Floor, bo wiersz widoczny w polowie nie jest wierszem, na ktorym da sie zatrzymac.
    $widoczne = [int][Math]::Floor($Lista.ClientSize.Height / $wysokoscWiersza)

    $Lista.TopIndex = Get-JezykNowyWierszListy -Gora $Lista.TopIndex -Delta $Zdarzenie.Delta `
                                              -Ile $Lista.Items.Count -Widoczne $widoczne
}

# Nadaje liscie wysokosc z calych wierszy, zanim ktos zmierzy sie od jej dolu.
# IntegralHeight tnie dopiero przy tworzeniu uchwytu, a ItemHeight jest prawdziwy dopiero z uchwytem.
function Set-JezykWysokoscListy {
    param($Lista, [int]$Wysokosc)

    $null = $Lista.Handle

    $wiersz = [int]$Lista.ItemHeight
    if ($wiersz -le 0) {
        $Lista.Height = $Wysokosc
        return
    }

    $ramka   = $Lista.Height - $Lista.ClientSize.Height
    # Floor, bo wiersz widoczny w polowie to dokladnie to, czego IntegralHeight ma nie dopuscic.
    $wiersze = [int][Math]::Floor(($Wysokosc - $ramka) / $wiersz)
    if ($wiersze -lt 1) { $wiersze = 1 }

    $Lista.Height = $ramka + $wiersze * $wiersz
}

# Wypelnia liste grup wg filtra i uaktualnia tytul - jedna sciezka dla startu i kazdego znaku.
# Stan okna na Tag (ginie z oknem); BeginUpdate/EndUpdate - jedno przerysowanie.
function Update-JezykFiltrGrup {
    param($Pole)

    $lista = $Pole.Tag
    if (-not $lista) { return }

    $grupy    = @($lista.Tag)
    $widoczne = @(Select-JezykGrupyDoPokazania -Grupy $grupy -Fraza $Pole.Text)
    $wiersze  = @(Get-JezykWierszeGrup $widoczne)

    $okno = $Pole.FindForm()

    # Widoczne pary odkladane z tej samej tablicy i PRZED narysowaniem listy (zaznaczenie -> grupa).
    if ($okno -and $okno.Tag) { $okno.Tag.WidoczneGrupy = $widoczne }

    $lista.BeginUpdate()
    try {
        $lista.Items.Clear()
        if ($wiersze.Count -gt 0) { $lista.Items.AddRange([object[]]$wiersze) }
        # Po zawezeniu listy poprzedni pierwszy wiersz wskazywalby poza jej koniec.
        $lista.TopIndex = 0
    }
    finally { $lista.EndUpdate() }

    if (-not $okno) { return }
    $okno.Text = Get-JezykTytulGrup -Podpis ([string]$okno.Tag.Podpis) -Ile $widoczne.Count `
                                    -Wszystkich $grupy.Count

    # Wyczyszczenie listy gasi zaznaczenie - przelicz "Usun z grupy".
    Set-JezykPrzyciskUsunGrupe -Okno $okno
}

# Okno grup AD pokazanego konta: lista z filtrem, a w domenie z zarzadzaniem - dodawanie i usuwanie.
# Zrodlem jest $Script:OstatnieKonto; geometria liczona po dodaniu kontrolek, kazdy wiersz od sasiada.
function Show-JezykGrupyAd {
    $konto = $Script:OstatnieKonto
    if (-not $konto) { return }

    # Straz przed pierwsza kontrolka - ten sam warunek co dostepnosc przycisku.
    if (-not (Test-JezykJestPoCoOtwieracGrupy $konto)) { return }

    # Pary nazwa + DN - bez DN nie da sie usunac z grupy.
    $grupy          = @(Get-JezykParyGrup $konto.GrupyPelne)
    $wolnoZarzadzac = Test-JezykMoznaZarzadzacGrupami $konto
    # Druga os: domena z zarzadzaniem (kontakt dostaje w Status wyjasnienie; poza domena - nic).
    $domenaZZarzadzaniem = Test-JezykWolnoZarzadzacGrupami $Script:Config.Domena

    # Kontakt nie ma loginu - podpis to nazwa obiektu.
    $podpis = [string]$konto.Login
    if (-not $podpis) { $podpis = [string]$konto.NazwaObiektu }

    # Wymiary liczone ze stalych siatki okna glownego, zeby oba okna mialy ten sam rytm.
    $margines           = $Script:Margines
    $szerokosc          = $Script:SzerokoscKolumny + 2 * $margines
    $wysokoscListy      = 300
    $szerokoscPrzycisku = 90
    $odstepEtykiety     = 8
    $odstepPrzyciskow   = 8
    # Przerwa pod para przyciskow do etykiety "Status:" - mniejsza, bo przyciski stoja tylko po prawej.
    $przerwaPodPrzyciskami = 2

    $okno = $null
    try {
        $okno                 = New-Object System.Windows.Forms.Form
        $okno.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $okno.MaximizeBox     = $false
        $okno.MinimizeBox     = $false
        $okno.ShowInTaskbar   = $false
        $okno.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
        # Ta sama czcionka, co w oknie glownym - honoruje ustawienia systemu i skalowanie DPI.
        $okno.Font            = [System.Drawing.SystemFonts]::MessageBoxFont
        # Bez -Rejestruj: okno na zadanie ginie w finally { Dispose() }.
        Set-JezykWyglad $okno 'Okno'

        # Wysokosc przycisku rowna polu, jak w oknie glownym.
        $wysokoscPrzycisku = Get-JezykWysokoscPola $okno.Font

        $lblFiltr = New-JezykEtykieta 'Szukaj grupy:' $margines $margines

        # Zwykly TextBox (tu pisze operator), nie New-JezykPole.
        $txtFiltr           = New-Object System.Windows.Forms.TextBox
        $txtFiltr.MaxLength = 256
        Set-JezykWyglad $txtFiltr 'Pole'

        $lista = New-Object System.Windows.Forms.ListBox
        Set-JezykWyglad $lista 'Lista'
        # Wysokosc z calych wierszy - liczy ja Set-JezykWysokoscListy przed pomiarem od dolu listy.
        $lista.IntegralHeight = $true
        # Poziomy pasek - dlugie nazwy da sie doczytac.
        $lista.HorizontalScrollbar = $true
        # Pelna lista wisi na kontrolce, bo to ona jest filtrowana, i ginie razem z oknem.
        $lista.Tag = $grupy
        # Pole filtra musi trafic do swojej listy bez pomocy zmiennych lokalnych tej funkcji.
        $txtFiltr.Tag = $lista

        # --- WIERSZE ZARZADZANIA -------------------------------------------------------
        # Tylko w domenie z DomenyZZarzadzaniemGrupami i tylko dla konta; poza nia schowane, nie wyszarzone.
        # "Dodaj" bierze grupe z pola (po "Sprawdz nazwy"), "Usun z grupy" - z zaznaczenia na liscie.
        $lblNazwaGrupy = New-JezykEtykieta 'Nazwa grupy:' $margines 0

        $txtGrupa           = New-Object System.Windows.Forms.TextBox
        $txtGrupa.MaxLength = 256
        Set-JezykWyglad $txtGrupa 'Pole'

        # Napis w Tag, Text pusty (Set-JezykRysunekNapisuPrzycisku).
        $btnSprawdz           = New-Object System.Windows.Forms.Button
        $btnSprawdz.Text      = ''
        $btnSprawdz.Tag       = 'Sprawdź nazwy'
        $btnSprawdz.Size      = [System.Drawing.Size]::new(
                                    (Get-JezykSzerokoscPrzycisku ([string]$btnSprawdz.Tag) $okno.Font),
                                    $wysokoscPrzycisku)
        $btnSprawdz.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnSprawdz 'Przycisk'
        $btnSprawdz.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })

        $btnDodaj           = New-Object System.Windows.Forms.Button
        $btnDodaj.Text      = ''
        $btnDodaj.Tag       = 'Dodaj'
        $btnDodaj.Size      = [System.Drawing.Size]::new(
                                  (Get-JezykSzerokoscPrzycisku ([string]$btnDodaj.Tag) $okno.Font),
                                  $wysokoscPrzycisku)
        $btnDodaj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnDodaj 'Przycisk'
        $btnDodaj.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        # Stan poczatkowy: "Dodaj" zapala sie dopiero po rozpoznaniu nazwy.
        $btnDodaj.Enabled = $false

        $btnUsun           = New-Object System.Windows.Forms.Button
        $btnUsun.Text      = ''
        $btnUsun.Tag       = 'Usuń z grupy'
        $btnUsun.Size      = [System.Drawing.Size]::new(
                                 (Get-JezykSzerokoscPrzycisku ([string]$btnUsun.Tag) $okno.Font),
                                 $wysokoscPrzycisku)
        $btnUsun.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnUsun 'Przycisk'
        $btnUsun.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        # Stan poczatkowy: nic nie jest zaznaczone, wiec nie ma czego usuwac.
        $btnUsun.Enabled = $false

        $lblNazwaGrupy.Visible = $wolnoZarzadzac
        $txtGrupa.Visible      = $wolnoZarzadzac
        $btnSprawdz.Visible    = $wolnoZarzadzac
        $btnDodaj.Visible      = $wolnoZarzadzac
        $btnUsun.Visible       = $wolnoZarzadzac

        # --- NOTKA ---------------------------------------------------------------------
        # Pole "Status:" okna (dwie linijki) - tylko w domenie z zarzadzaniem; poza nia go nie ma.
        $lblNotka = New-JezykEtykieta 'Status:' $margines 0

        $txtNotka           = New-Object System.Windows.Forms.TextBox
        $txtNotka.ReadOnly  = $true
        $txtNotka.Multiline = $true
        Set-JezykWyglad $txtNotka 'Pole'

        $lblNotka.Visible = $domenaZZarzadzaniem
        $txtNotka.Visible = $domenaZZarzadzaniem

        # Wlasny "!" (Set-JezykInfo stoi na rejestrach okna glownego), bez rejestracji w motywie.
        $btnInfo = New-JezykPrzyciskInfo 'Grupy' -BezRejestracji

        # Napis w Tag, Text pusty (Set-JezykRysunekNapisuPrzycisku).
        $btnZamknij           = New-Object System.Windows.Forms.Button
        $btnZamknij.Text      = ''
        $btnZamknij.Tag       = 'Zamknij'
        $btnZamknij.Size      = [System.Drawing.Size]::new($szerokoscPrzycisku, $wysokoscPrzycisku)
        $btnZamknij.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnZamknij 'Przycisk'
        $btnZamknij.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        $btnZamknij.DialogResult = [System.Windows.Forms.DialogResult]::OK

        # Stan okna na Tag - kontrolki odnajduja sie nawzajem, a stan ginie razem z oknem.
        $okno.Tag = @{
            Podpis        = $podpis
            PoleFiltra    = $txtFiltr
            Lista         = $lista
            PoleGrupy     = $txtGrupa
            PrzyciskSprawdz = $btnSprawdz
            PrzyciskDodaj = $btnDodaj
            PrzyciskUsun  = $btnUsun
            Notka         = $txtNotka
            PrzyciskInfo  = $btnInfo
            Szczegoly     = ''
            Wybrana       = $null
            # Czy "Sprawdz nazwy" czeka na odpowiedz z tla (ustawia Set-JezykSprawdzanieGrupy).
            Sprawdzanie   = $false
            # Pary widoczne teraz na liscie, w jej kolejnosci (wypelnia Update-JezykFiltrGrup).
            WidoczneGrupy = @()
        }

        # Pole filtra pierwsze - dostaje fokus samo.
        $okno.Controls.AddRange(@($lblFiltr, $txtFiltr, $lista,
                                  $lblNazwaGrupy, $txtGrupa, $btnSprawdz,
                                  $btnUsun, $btnDodaj,
                                  $lblNotka, $txtNotka, $btnInfo, $btnZamknij))

        # Szerokosc okna z wiersza, ktory jej potrzebuje (etykieta i przyciski rosna z czcionka).
        if ($wolnoZarzadzac) {
            $minimumPola = 2 * $btnSprawdz.Width
            $wierszPola  = $margines + $lblNazwaGrupy.Width + $odstepEtykiety + $minimumPola +
                           $odstepPrzyciskow + $btnSprawdz.Width + $margines
            # Drugi wiersz ma wlasne wymaganie: dwa przyciski obok siebie przy prawej krawedzi.
            $wierszAkcji = $margines + $btnUsun.Width + $odstepPrzyciskow +
                           $btnDodaj.Width + $margines
            $potrzebne   = [Math]::Max($wierszPola, $wierszAkcji)
            if ($potrzebne -gt $szerokosc) { $szerokosc = $potrzebne }
        }

        $txtFiltr.Left  = $lblFiltr.Right + $odstepEtykiety
        $txtFiltr.Width = $szerokosc - $margines - $txtFiltr.Left
        # Gorny margines ten sam, co w oknie glownym.
        Set-JezykSrodekPionowy -Kontrolki @($lblFiltr, $txtFiltr) `
                               -Srodek ($Script:MarginesGorny + (Get-JezykPolowaWysokosci $txtFiltr.Height))

        $lista.Left   = $margines
        $lista.Width  = $szerokosc - 2 * $margines
        # Przerwa miedzy wierszami ta sama, co w oknie glownym ($margines tylko na ramce).
        $lista.Top    = $txtFiltr.Bottom + $Script:PrzerwaWierszy
        Set-JezykWysokoscListy $lista $wysokoscListy

        # Kazdy nastepny wiersz mierzy sie od sasiada; bez wierszy zarzadzania notka siada pod lista.
        $dolPoprzedniego = $lista.Bottom
        $przerwaNadNotka = $Script:PrzerwaWierszy

        if ($wolnoZarzadzac) {
            # Wiersz nazwy: pole ciagnie sie od etykiety do "Sprawdz nazwy" przy prawej krawedzi.
            $btnSprawdz.Left = $szerokosc - $margines - $btnSprawdz.Width
            $txtGrupa.Left   = $lblNazwaGrupy.Right + $odstepEtykiety
            $txtGrupa.Width  = $btnSprawdz.Left - $odstepPrzyciskow - $txtGrupa.Left

            Set-JezykSrodekPionowy -Kontrolki @($lblNazwaGrupy, $txtGrupa, $btnSprawdz) `
                                   -Srodek ($dolPoprzedniego + $Script:PrzerwaWierszy +
                                            (Get-JezykPolowaWysokosci $txtGrupa.Height))
            $dolPoprzedniego = $txtGrupa.Bottom

            # Wiersz akcji: para przyciskow przy prawej krawedzi - "Usun z grupy" od sasiada.
            $btnDodaj.Left = $szerokosc - $margines - $btnDodaj.Width
            $btnUsun.Left  = $btnDodaj.Left - $odstepPrzyciskow - $btnUsun.Width
            $btnDodaj.Top  = $dolPoprzedniego + $Script:PrzerwaWierszy
            $btnUsun.Top   = $btnDodaj.Top
            $dolPoprzedniego = $btnDodaj.Bottom
            $przerwaNadNotka = $przerwaPodPrzyciskami
        }

        if ($domenaZZarzadzaniem) {
            # Wlasna etykieta notki - "!" staje tam, gdzie w oknie glownym.
            $lblNotka.Left   = $margines
            $lblNotka.Top    = $dolPoprzedniego + $przerwaNadNotka
            $txtNotka.Left   = $margines
            $txtNotka.Top    = $lblNotka.Top + $Script:OdstepPodEtykieta
            $txtNotka.Width  = $szerokosc - 2 * $margines
            # Druga linijka z czcionki, jak przy polach "Status:" w oknie glownym.
            $txtNotka.Height = $txtNotka.PreferredHeight + [int][math]::Ceiling($okno.Font.GetHeight())
            # Etykieta nie moze zakrywac gornej ramki pola.
            Set-JezykEtykietaNadPolem $lblNotka
            Set-JezykPrzyciskPrzyEtykiecie $btnInfo $lblNotka $txtNotka
            $dolPoprzedniego = $txtNotka.Bottom
        }

        $btnZamknij.Left = $szerokosc - $margines - $szerokoscPrzycisku
        $btnZamknij.Top  = $dolPoprzedniego + $Script:PrzerwaWierszy

        $okno.ClientSize = [System.Drawing.Size]::new($szerokosc,
                               ($btnZamknij.Bottom + $margines))

        # Ciemny pasek tytulu i przewijania (siegniecie po Handle tworzy uchwyt przed pokazaniem).
        $ciemny = ($Script:Motyw -eq 'Ciemny')
        Set-JezykCiemnyPasekTytulu      $okno.Handle  -Ciemny:$ciemny
        Set-JezykCiemnyPasekPrzewijania $lista.Handle -Ciemny:$ciemny

        # Pierwsze wypelnienie ta sama droga, co kazdy klawisz.
        Update-JezykFiltrGrup $txtFiltr

        # Notka otwierajaca tylko gdy widok sam nie tlumaczy: brak grup albo kontakt w domenie z zarzadzaniem.
        $notka = ''
        if ($grupy.Count -eq 0) { $notka = 'To konto nie należy do żadnej grupy.' }
        if ($konto.Status -eq 'Kontakt' -and $domenaZZarzadzaniem) {
            $notka = 'Kontakt nie jest kontem w domenie - nie da się go dopisać do grupy.'
        }
        if ($notka) { Set-JezykNotkeGrup -Okno $okno -Tekst $notka }

        $txtFiltr.Add_TextChanged({ Update-JezykFiltrGrup $this })
        $lista.Add_MouseWheel({ Set-JezykPrzewijanieListy $this $_ })

        # "Usun z grupy" zalezy od zaznaczenia (zmienia sie tez klawiatura i filtrem).
        $lista.Add_SelectedIndexChanged({ Set-JezykPrzyciskUsunGrupe -Okno $this.FindForm() })

        if ($wolnoZarzadzac) {
            # Zmiana tekstu uniewaznia rozpoznana grupe - zapis nie moze isc na DN spoza pola.
            $txtGrupa.Add_TextChanged({
                $stan = $this.FindForm().Tag
                if (-not $stan) { return }
                $stan.Wybrana = $null
                if ($stan.PrzyciskDodaj) { $stan.PrzyciskDodaj.Enabled = $false }
            })

            # Uwaga: Enter jako "Sprawdz nazwy" tylko przez PreviewKeyDown - okno z AcceptButton
            # oddaje Entera przyciskowi przed KeyDown.
            $txtGrupa.Add_PreviewKeyDown({
                if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $_.IsInputKey = $true }
            })

            # Handled i SuppressKeyPress - bez nich pole odpowiada dzwiekiem.
            $txtGrupa.Add_KeyDown({
                if ($_.KeyCode -ne [System.Windows.Forms.Keys]::Enter) { return }
                $_.Handled          = $true
                $_.SuppressKeyPress = $true
                Invoke-JezykSprawdzenieNazwyGrupy -Okno $this.FindForm()
            })

            $btnSprawdz.Add_Click({ Invoke-JezykSprawdzenieNazwyGrupy -Okno $this.FindForm() })
            $btnDodaj.Add_Click({   Invoke-JezykDodanieDoGrupy        -Okno $this.FindForm() })
            $btnUsun.Add_Click({    Invoke-JezykUsuniecieZGrupy       -Okno $this.FindForm() })
        }

        # Tresc spod "!" wlasnym MessageBoxem (rejestry okna glownego tu nie siegaja).
        $btnInfo.Add_Click({
            $okienko = $this.FindForm()
            $stan    = $okienko.Tag
            if (-not $stan -or -not $stan.Szczegoly) { return }
            [void][System.Windows.Forms.MessageBox]::Show($okienko, [string]$stan.Szczegoly,
                'Jeżyk - Grupy AD', [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        })

        # Esc i Enter zamykaja (poza polem nazwy grupy).
        $okno.AcceptButton = $btnZamknij
        $okno.CancelButton = $btnZamknij

        [void]$okno.ShowDialog($Script:Kontrolki.Okno)
    }
    finally {
        if ($okno) {
            # Odpowiedz "Sprawdz nazwy" nie ma juz dokad wrocic - notka i zadanie gasna przed Dispose.
            Set-JezykSprawdzanieGrupy -Okno $okno -Wylacz
            Stop-JezykZadanieGrupy
            # ShowDialog nie zwalnia okna sam - Dispose zwalnia uchwyty.
            $okno.Dispose()
        }
    }
}

# Okno wyboru jednej z kilku grup rozpoznanych przez "Sprawdz nazwy".
# Wlascicielem jest okno grup - podpiete pod glowne chowaloby sie za nim.
function Show-JezykWyborGrupy {
    param($Trafienia, $Wlasciciel)

    # Wiersze i zwracana pozycja z jednej tablicy (po Get-JezykParyGrup) - indeksy sie nie rozjada.
    $pozycje = @(Get-JezykParyGrup $Trafienia)
    if ($pozycje.Count -eq 0) { return $null }

    $margines           = $Script:Margines
    $szerokosc          = $Script:SzerokoscKolumny + 2 * $margines
    $szerokoscPrzycisku = 90
    $odstepPrzyciskow   = 8

    $okno = $null
    try {
        $okno                 = New-Object System.Windows.Forms.Form
        $okno.Text            = 'Jeżyk - Wybierz grupę'
        $okno.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $okno.MaximizeBox     = $false
        $okno.MinimizeBox     = $false
        $okno.ShowInTaskbar   = $false
        $okno.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
        $okno.Font            = [System.Drawing.SystemFonts]::MessageBoxFont
        Set-JezykWyglad $okno 'Okno'

        $wysokoscPrzycisku = Get-JezykWysokoscPola $okno.Font

        $lista = New-Object System.Windows.Forms.ListBox
        Set-JezykWyglad $lista 'Lista'
        $lista.IntegralHeight      = $true
        $lista.HorizontalScrollbar = $true

        foreach ($wiersz in @(Get-JezykWierszeGrup $pozycje)) {
            [void]$lista.Items.Add($wiersz)
        }
        # Pierwsza pozycja zaznaczona od razu, zeby Enter dzialal bez siegania po mysz.
        if ($lista.Items.Count -gt 0) { $lista.SelectedIndex = 0 }

        # Napis w Tag, Text pusty (Set-JezykRysunekNapisuPrzycisku).
        $btnWybierz              = New-Object System.Windows.Forms.Button
        $btnWybierz.Text         = ''
        $btnWybierz.Tag          = 'Wybierz'
        $btnWybierz.Size         = [System.Drawing.Size]::new($szerokoscPrzycisku, $wysokoscPrzycisku)
        $btnWybierz.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnWybierz 'Przycisk'
        $btnWybierz.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        $btnWybierz.DialogResult = [System.Windows.Forms.DialogResult]::OK

        $btnAnuluj              = New-Object System.Windows.Forms.Button
        $btnAnuluj.Text         = ''
        $btnAnuluj.Tag          = 'Anuluj'
        $btnAnuluj.Size         = [System.Drawing.Size]::new($szerokoscPrzycisku, $wysokoscPrzycisku)
        $btnAnuluj.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnAnuluj 'Przycisk'
        $btnAnuluj.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        $btnAnuluj.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

        # Lista jest PIERWSZA, wiec dostaje fokus sama.
        $okno.Controls.AddRange(@($lista, $btnWybierz, $btnAnuluj))

        # Geometria po dodaniu kontrolek (czcionka dziedziczona dopiero wtedy).
        $wysokoscWiersza = [int][math]::Ceiling($okno.Font.GetHeight()) + 2
        $lista.Left      = $margines
        $lista.Width     = $szerokosc - 2 * $margines
        $lista.Top       = $margines
        $lista.Height    = $pozycje.Count * $wysokoscWiersza

        $btnAnuluj.Left  = $szerokosc - $margines - $szerokoscPrzycisku
        $btnWybierz.Left = $btnAnuluj.Left - $odstepPrzyciskow - $szerokoscPrzycisku
        $btnWybierz.Top  = $lista.Bottom + $margines
        $btnAnuluj.Top   = $btnWybierz.Top

        $okno.ClientSize = [System.Drawing.Size]::new($szerokosc,
                               ($btnWybierz.Bottom + $margines))

        # Dwuklik = "Wybierz"; okno bierze sie z samej kontrolki.
        $lista.Add_DoubleClick({
            $this.FindForm().DialogResult = [System.Windows.Forms.DialogResult]::OK
        })

        $okno.AcceptButton = $btnWybierz
        $okno.CancelButton = $btnAnuluj

        $ciemny = ($Script:Motyw -eq 'Ciemny')
        Set-JezykCiemnyPasekTytulu      $okno.Handle  -Ciemny:$ciemny
        Set-JezykCiemnyPasekPrzewijania $lista.Handle -Ciemny:$ciemny

        $odpowiedz = if ($Wlasciciel) { $okno.ShowDialog($Wlasciciel) } else { $okno.ShowDialog() }
        if ($odpowiedz -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

        $nr = [int]$lista.SelectedIndex
        if ($nr -lt 0 -or $nr -ge $pozycje.Count) { return $null }
        return $pozycje[$nr]
    }
    finally {
        if ($okno) { $okno.Dispose() }
    }
}

# --- OKNO WYBORU DYSKU ----------------------------------------------------------------
# Udzialy administracyjne (C$, D$) - stala lista, nie ustawienie (litera dysku nie jest adresem).
$Script:LiteryDyskow = @('C', 'D')

# Okno wyboru udzialu pokazanej maszyny - oddaje litere albo pusty napis; straz przed kontrolkami.
# Funkcja oddaje wynik - wszystko inne po drodze idzie przez [void].
function Show-JezykWyborDysku {
    $maszyna = [string]$Script:OstatniKomputer
    if (-not $maszyna) { return '' }

    # Wymiary ze stalych siatki okna glownego - ten sam rytm, co w oknie grup.
    $margines           = $Script:Margines
    $szerokosc          = $Script:SzerokoscKolumny + 2 * $margines
    $szerokoscPrzycisku = 90
    $odstepPrzyciskow   = 8

    $okno = $null
    try {
        $okno                 = New-Object System.Windows.Forms.Form
        $okno.Text            = 'Jeżyk - Dyski: {0}' -f $maszyna
        $okno.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $okno.MaximizeBox     = $false
        $okno.MinimizeBox     = $false
        $okno.ShowInTaskbar   = $false
        $okno.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
        $okno.Font            = [System.Drawing.SystemFonts]::MessageBoxFont
        Set-JezykWyglad $okno 'Okno'

        # Wysokosc przycisku rowna polu (pomiar po ustawieniu czcionki okna).
        $wysokoscPrzycisku = Get-JezykWysokoscPola $okno.Font

        $lista = New-Object System.Windows.Forms.ListBox
        Set-JezykWyglad $lista 'Lista'
        # Wysokosc z calych wierszy.
        $lista.IntegralHeight = $true

        foreach ($litera in $Script:LiteryDyskow) {
            # Uwaga: napis do zmiennej - w argumencie metody przecinek nalezy do metody.
            $pozycja = '{0}$' -f $litera
            [void]$lista.Items.Add($pozycja)
        }
        # Pierwsza pozycja zaznaczona od razu, zeby Enter dzialal bez siegania po mysz.
        if ($lista.Items.Count -gt 0) { $lista.SelectedIndex = 0 }

        # Napis w Tag, Text pusty (Set-JezykRysunekNapisuPrzycisku).
        $btnOtworz              = New-Object System.Windows.Forms.Button
        $btnOtworz.Text         = ''
        $btnOtworz.Tag          = 'Otwórz'
        $btnOtworz.Size         = [System.Drawing.Size]::new($szerokoscPrzycisku, $wysokoscPrzycisku)
        $btnOtworz.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnOtworz 'Przycisk'
        $btnOtworz.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        $btnOtworz.DialogResult = [System.Windows.Forms.DialogResult]::OK

        $btnZamknij              = New-Object System.Windows.Forms.Button
        $btnZamknij.Text         = ''
        $btnZamknij.Tag          = 'Zamknij'
        $btnZamknij.Size         = [System.Drawing.Size]::new($szerokoscPrzycisku, $wysokoscPrzycisku)
        $btnZamknij.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnZamknij 'Przycisk'
        $btnZamknij.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        $btnZamknij.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

        # Lista jest PIERWSZA, wiec dostaje fokus sama - tak samo jak pole filtra w oknie grup.
        $okno.Controls.AddRange(@($lista, $btnOtworz, $btnZamknij))

        # Geometria po dodaniu kontrolek (czcionka dziedziczona dopiero wtedy).
        $wysokoscWiersza = [int][math]::Ceiling($okno.Font.GetHeight()) + 2
        $lista.Left      = $margines
        $lista.Width     = $szerokosc - 2 * $margines
        $lista.Top       = $margines
        $lista.Height    = @($Script:LiteryDyskow).Count * $wysokoscWiersza

        $btnZamknij.Left = $szerokosc - $margines - $szerokoscPrzycisku
        $btnOtworz.Left  = $btnZamknij.Left - $odstepPrzyciskow - $szerokoscPrzycisku
        $btnOtworz.Top   = $lista.Bottom + $margines
        $btnZamknij.Top  = $btnOtworz.Top

        $okno.ClientSize = [System.Drawing.Size]::new($szerokosc,
                               ($btnOtworz.Bottom + $margines))

        # Dwuklik = "Otworz"; okno bierze sie z samej kontrolki.
        $lista.Add_DoubleClick({
            $this.FindForm().DialogResult = [System.Windows.Forms.DialogResult]::OK
        })

        $okno.AcceptButton = $btnOtworz
        $okno.CancelButton = $btnZamknij

        # Siegniecie po Handle tworzy uchwyt przed pokazaniem okna.
        Set-JezykCiemnyPasekTytulu $okno.Handle -Ciemny:($Script:Motyw -eq 'Ciemny')

        $odpowiedz = $okno.ShowDialog($Script:Kontrolki.Okno)
        if ($odpowiedz -ne [System.Windows.Forms.DialogResult]::OK) { return '' }

        $wybrana = [string]$lista.SelectedItem
        if (-not $wybrana) { return '' }

        # Na liscie "C$", dalej idzie sama litera - dolar doklada Get-JezykSciezkaUdzialu.
        return $wybrana.Substring(0, 1)
    }
    finally {
        # ShowDialog nie zwalnia okna sam - Dispose zwalnia uchwyty.
        if ($okno) { $okno.Dispose() }
    }
}

# Buduje okno glowne, wypelnia rejestr kontrolek i podpina zdarzenia.
# Funkcja kontrolna - zostaje ostatnia w pliku.
function New-JezykForm {

    $form                 = New-Object System.Windows.Forms.Form
    $form.Text            = $Script:Config.TytulOkna
    # Tlo okna jawnie - dziedzicza je etykiety i znaczniki.
    Set-JezykWyglad $form 'Okno' -Rejestruj

    # Czcionka PIERWSZA (MessageBoxFont - ustawienia systemu i DPI) - od niej zalezy caly rytm siatki.
    $form.Font            = [System.Drawing.SystemFonts]::MessageBoxFont

    # Skok wiersza z faktycznej wysokosci pola.
    $wysokoscPola       = Get-JezykWysokoscPola $form.Font
    $Script:SkokWiersza = Get-JezykSkokWiersza $wysokoscPola

    # Pietra paneli z tego samego pomiaru - przed pierwsza wspolrzedna.
    $Script:PanelBezListy = Get-JezykPietroBezListy $wysokoscPola
    $Script:PanelZListą   = $Script:PanelBezListy + $Script:PasListyWyboru

    # Pole "Status:" ma dwie linijki - druga to wysokosc linii pisma.
    $drugaLinia      = [int][math]::Ceiling($form.Font.GetHeight())
    $wysokoscStatusu = $wysokoscPola + $drugaLinia

    # Dziewiec wierszy (0-8); panel konczy sie na dolnej krawedzi pola "Status:".
    $wysokoscPanelu = (Get-JezykWierszPole 8) + $wysokoscStatusu

    # Pas podpisu: czcionka o punkt mniejsza, wysokosc = wieksze z boku ikonki i linii pisma.
    $czcionkaPasa               = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size - 1)
    $Script:WysokoscPasaPodpisu = [Math]::Max($Script:BokIkonyMotywu,
                                              [int][Math]::Ceiling($czcionkaPasa.GetHeight()))

    # Wysokosc okna nadaje Set-JezykWysokoscOkna na koncu; AutoScroll - zapora na okno wyzsze od ekranu.
    $form.AutoScroll = $true

    # Ramka nierozciagliwa - kontrolki stoja na wyliczonych wspolrzednych.
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $true
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen

    # Ikona opcjonalna - jej brak nie przerywa startu.
    $plikIkony = Join-Path $Script:KatalogSkryptu 'Ikona-Jezyk.ico'
    if (Test-Path -LiteralPath $plikIkony) {
        try   { $form.Icon = [System.Drawing.Icon]::new($plikIkony, 32, 32) }
        catch { }
    }

    # --- WIERSZ DOMENY I WIERSZ WYSZUKIWANIA -----------------------------------------
    # Wspolny slupek etykiet; srodki wierszy licza sie w sekcji wyrownania.
    $slupekEtykiet = 70

    $lblDomena = New-JezykEtykieta 'Domena' $Script:Margines 0
    $lblPodaj  = New-JezykEtykieta 'Podaj'  $Script:Margines 0

    # Zmiana domeny = inny parametr -Server dla wszystkich zapytan.
    $cmbDomena               = New-Object System.Windows.Forms.ComboBox
    $cmbDomena.Left          = $slupekEtykiet
    $cmbDomena.Width         = 240
    $cmbDomena.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbDomena.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $cmbDomena 'Lista' -Rejestruj
    foreach ($d in $Script:Domeny) { [void]$cmbDomena.Items.Add($d) }
    $cmbDomena.SelectedIndex = 0

    # DropDownList - tryb zawsze znany; FlatStyle = Flat, bo inaczej lista ignoruje BackColor.
    $cmbTryb               = New-Object System.Windows.Forms.ComboBox
    $cmbTryb.Left          = $slupekEtykiet
    $cmbTryb.Width         = 180
    $cmbTryb.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbTryb.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $cmbTryb 'Lista' -Rejestruj
    [void]$cmbTryb.Items.Add($Script:Config.TrybNazwa)
    [void]$cmbTryb.Items.Add($Script:Config.TrybKomputer)
    $cmbTryb.SelectedIndex = 0

    $przerwa = 16

    # Napis w Tag, Text pusty (Set-JezykRysunekNapisuPrzycisku) - przycisk moze byc rowny polu.
    $btnSzukaj           = New-Object System.Windows.Forms.Button
    $btnSzukaj.Text      = ''
    $btnSzukaj.Tag       = 'Szukaj'
    $btnSzukaj.Width     = 96
    # Wysokosc rowna polu - napis rysowany w calym prostokacie, nie ma sie gdzie uciac.
    $btnSzukaj.Height    = $wysokoscPola
    $btnSzukaj.Left      = $Script:Margines + $Script:SzerokoscPelna - $btnSzukaj.Width
    $btnSzukaj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnSzukaj 'Przycisk' -Rejestruj

    # Jez - wskaznik pracy i odpowiedz (Set-JezykStanJeza) - w pustej prawej czesci wiersza domeny.
    # PictureBox (podwojne buforowanie z fabryki); tla nie ustawiamy - dziedziczy je po oknie.
    $jezSzukania         = New-Object System.Windows.Forms.PictureBox
    # Od konca listy domen do prawej krawedzi zawartosci.
    $jezSzukania.Left    = $cmbDomena.Right + $przerwa
    $jezSzukania.Width   = $Script:Margines + $Script:SzerokoscPelna - $jezSzukania.Left
    $jezSzukania.Visible = $false
    # $this - kontrolka zdarzenia, $_ - PaintEventArgs (procedura nie widzi zmiennych tej funkcji).
    $jezSzukania.Add_Paint({
        Set-JezykRysunekJeza -Grafika $_.Graphics -Szerokosc $this.Width -Wysokosc $this.Height
    })

    # Pole wypelnia miejsce miedzy lista trybu a przyciskiem.
    $txtSzukaj           = New-Object System.Windows.Forms.TextBox
    $txtSzukaj.Left      = $cmbTryb.Right + $przerwa
    $txtSzukaj.Width     = $btnSzukaj.Left - $przerwa - $txtSzukaj.Left
    # Zabezpieczenie przed wklejeniem calego akapitu tekstu.
    $txtSzukaj.MaxLength = 256
    Set-JezykWyglad $txtSzukaj 'Pole' -Rejestruj

    # Lista wyboru kont (tylko przy wyszukiwaniu czesciowym); DisplayMember = Opis.
    $cmbWynik               = New-Object System.Windows.Forms.ComboBox
    # Na pietrze panelu bez listy - ta sama stala.
    $cmbWynik.Location      = [System.Drawing.Point]::new($Script:Margines, $Script:PanelBezListy)
    $cmbWynik.Width         = $Script:SzerokoscPelna
    $cmbWynik.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    # FlatStyle = Flat - jak przy dwoch listach wyzej.
    $cmbWynik.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $cmbWynik 'Lista' -Rejestruj
    $cmbWynik.DisplayMember = 'Opis'
    $cmbWynik.Visible       = $false

    # --- PANEL: WIDOK KONTA ----------------------------------------------------------
    $pnlKonto      = New-Object System.Windows.Forms.Panel
    Set-JezykWyglad $pnlKonto 'Okno' -Rejestruj
    $pnlKonto.Size = [System.Drawing.Size]::new($Script:SzerokoscOkna, $wysokoscPanelu)

    # Werdykt: jedyny napis, ktorego kolor i tresc zaleza od stanu konta; pion z wyrownania na koncu.
    $chkWerdykt           = New-JezykCheckbox '' $Script:Margines 0 18
    # Poziom napisu z wyrownania (od kwadratu); napis startowy neutralny, szerokosc z NajdluzszyWerdykt.
    $lblWerdykt           = New-JezykEtykieta 'Nie sprawdzono' 0 0
    # Czcionka z czcionki okna: o punkt wieksza i pogrubiona.
    $lblWerdykt.Font      = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size + 1, [System.Drawing.FontStyle]::Bold)
    # Rola "Okno" PRZED kolorem - dzieki niej werdykt dostaje kolorowy napis, a nie kolorowe tlo.
    Set-JezykWyglad    $lblWerdykt 'Okno' -Rejestruj
    Set-JezykKolorPola $lblWerdykt 'Nieznany'

    # "Odblokuj konto" - widocznosc i dostepnosc ustawia Set-JezykPrzyciskOdblokuj.
    $btnOdblokuj           = New-Object System.Windows.Forms.Button
    $btnOdblokuj.Text      = ''
    $btnOdblokuj.Tag       = 'Odblokuj konto'
    $btnOdblokuj.Width     = 130
    # Wysokosc rowna polu.
    $btnOdblokuj.Height    = $wysokoscPola
    $btnOdblokuj.Left      = $Script:Margines + $Script:SzerokoscPelna - $btnOdblokuj.Width
    $btnOdblokuj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnOdblokuj 'Przycisk' -Rejestruj
    $btnOdblokuj.Enabled   = $false

    # Ramka faktow werdyktu: trzy rowne kolumny, wyliczane.
    $grpFlagi          = New-Object System.Windows.Forms.GroupBox
    Set-JezykWyglad $grpFlagi 'Okno' -Rejestruj
    $grpFlagi.Text     = ''
    $grpFlagi.Location = [System.Drawing.Point]::new($Script:Margines, 32)
    $grpFlagi.Size     = [System.Drawing.Size]::new($Script:SzerokoscPelna, 52)

    # Wspolrzedne zerowe celowo - nadaje je wyrownanie (szerokosc znana dopiero po dodaniu do okna).
    # Kwadrat i napis to dwie kontrolki - odstepu i linii pisma napisu znacznika nie da sie ustawic.
    $chkAktywne     = New-JezykCheckbox '' 0 0 18
    $chkZablokowane = New-JezykCheckbox '' 0 0 18
    $chkFlagaHasla  = New-JezykCheckbox '' 0 0 18

    $lblAktywne     = New-JezykEtykieta 'Konto aktywne'      0 0
    $lblZablokowane = New-JezykEtykieta 'Konto zablokowane'  0 0
    $lblFlagaHasla  = New-JezykEtykieta 'Flaga zmiany hasła' 0 0

    $grpFlagi.Controls.AddRange(@($chkAktywne,     $lblAktywne,
                                  $chkZablokowane, $lblZablokowane,
                                  $chkFlagaHasla,  $lblFlagaHasla))

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

    # Przyciski "!" przy polach, ktore moga zglosic usterke; pokazuje je Set-JezykInfo (README: Przycisk "!").
    $btnInfoStatus   = New-JezykPrzyciskInfo 'Status'
    $btnInfoKomputer = New-JezykPrzyciskInfo 'Komputer'

    # Niebieski "!" - niejednoznacznosc (maszyna wspoldzielona), nie usterka.
    $btnInfoKomputerWspoldzielony = New-JezykPrzyciskInfo 'KomputerWspoldzielony'
    Set-JezykWyglad $btnInfoKomputerWspoldzielony 'InfoNiebieski' -Rejestruj

    # Komputer obok e-maila - data logowania potrzebuje calej szerokosci.
    $lblEmail = New-JezykEtykieta 'E-mail:' $L (Get-JezykWiersz 1)
    $txtEmail = New-JezykPole                $L (Get-JezykWierszPole 1) $W
    # "Uzywany", nie "zalogowany" - ostatni uzytkownik wg inwentaryzacji; pole krotsze o "Pinguj".
    $szerokoscPingu = 72
    $przerwaPingu   = 8

    $lblKomputerUzytkownika = New-JezykEtykieta 'Ostatnio używany komputer:' $P (Get-JezykWiersz 1)
    $txtKomputerUzytkownika = New-JezykPole $P (Get-JezykWierszPole 1) `
                                            ($W - $szerokoscPingu - $przerwaPingu)

    # "Pinguj" - nieczynny, dopoki SCCM nie poda nazwy maszyny; bez TabStop.
    $btnPinguj           = New-Object System.Windows.Forms.Button
    $btnPinguj.Text      = ''
    $btnPinguj.Tag       = 'Pinguj'
    $btnPinguj.Width     = $szerokoscPingu
    $btnPinguj.Height    = $wysokoscPola
    $btnPinguj.Left      = $P + $W - $szerokoscPingu
    $btnPinguj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnPinguj 'Przycisk' -Rejestruj
    $btnPinguj.Enabled   = $false
    $btnPinguj.TabStop   = $false

    # "Polacz" nad "Pinguj", w pustej linii etykiety; widocznosc ustawia Set-JezykPrzyciskiZdalne.
    $btnPolacz           = New-Object System.Windows.Forms.Button
    $btnPolacz.Text      = ''
    $btnPolacz.Tag       = 'Połącz'
    $btnPolacz.Width     = $szerokoscPingu
    $btnPolacz.Height    = $wysokoscPola
    $btnPolacz.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnPolacz 'Przycisk' -Rejestruj
    $btnPolacz.Visible   = $false
    $btnPolacz.TabStop   = $false

    # Adres IP pod nazwa maszyny; w pustej lewej polowie wiersza - adres MAC z niebieskim "!".
    $lblKomputerMac = New-JezykEtykieta 'Adres MAC:' $L (Get-JezykWiersz 2)
    $txtKomputerMac = New-JezykPole                  $L (Get-JezykWierszPole 2) $W
    $btnInfoMac     = New-JezykPrzyciskInfo 'Mac'
    Set-JezykWyglad $btnInfoMac 'InfoNiebieski' -Rejestruj

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

    # Telefon i przelozony w jednym wierszu.
    $lblTelefon  = New-JezykEtykieta 'Telefon:'  $L (Get-JezykWiersz 5)
    $txtTelefon  = New-JezykPole                 $L (Get-JezykWierszPole 5) $W
    $lblMenedzer = New-JezykEtykieta 'Przełożony:' $P (Get-JezykWiersz 5)
    $txtMenedzer = New-JezykPole                 $P (Get-JezykWierszPole 5) $W

    # Katalog konta w lewej polowie; prawa przyjela grupy AD (bez nowego wiersza).
    $lblKatalog = New-JezykEtykieta 'Katalog konta:' $L (Get-JezykWiersz 6)
    $txtKatalog = New-JezykPole                      $L (Get-JezykWierszPole 6) $W

    # Etykieta w linii etykiet, przycisk w linii pol; szerokosc z kolumny.
    $lblGrupy = New-JezykEtykieta 'Grupy AD użytkownika:' $P (Get-JezykWiersz 6)

    # "Wyswietl grupy" - dostepnosc ustawia Set-JezykPrzyciskGrupy.
    $btnGrupyAd           = New-Object System.Windows.Forms.Button
    $btnGrupyAd.Text      = ''
    $btnGrupyAd.Tag       = 'Wyświetl grupy'
    $btnGrupyAd.Width     = $W
    $btnGrupyAd.Height    = $wysokoscPola
    $btnGrupyAd.Left      = $P
    $btnGrupyAd.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnGrupyAd 'Przycisk' -Rejestruj
    $btnGrupyAd.Enabled   = $false
    $btnGrupyAd.TabStop   = $false

    # Cala szerokosc, bo pole niesie dwie daty naraz.
    $lblOstatnieLogowanie = New-JezykEtykieta 'Ostatnie logowanie:' $L (Get-JezykWiersz 7)
    $txtOstatnieLogowanie = New-JezykPole                           $L (Get-JezykWierszPole 7) $C

    # "Status:" ma dwie linijki - niesie najdluzsze komunikaty.
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
        $btnInfoKomputerWspoldzielony, $btnPinguj, $btnPolacz,
        $lblKomputerMac, $txtKomputerMac, $btnInfoMac,
        $lblKomputerIp, $txtKomputerIp,
        $lblKatalog, $txtKatalog,
        $lblGrupy, $btnGrupyAd,
        $lblStatus, $txtStatus, $btnInfoStatus))

    # --- PANEL: WIDOK KOMPUTERA ------------------------------------------------------
    # Ten sam rytm co w widoku konta, tylko liczony od gory panelu.
    $kompWiersz0 = 6
    $kompWiersz1 = $kompWiersz0 + $Script:SkokWiersza
    $kompWiersz2 = $kompWiersz1 + $Script:SkokWiersza
    $kompWiersz3 = $kompWiersz2 + $Script:SkokWiersza
    $kompWiersz4 = $kompWiersz3 + $Script:SkokWiersza
    $kompWiersz5 = $kompWiersz4 + $Script:SkokWiersza

    $pnlKomputer         = New-Object System.Windows.Forms.Panel
    Set-JezykWyglad $pnlKomputer 'Okno' -Rejestruj
    # Wysokosc panelu z ostatniego wiersza (bez zapasu pod polem) - czyta ja Set-JezykWysokoscOkna.
    $pnlKomputer.Size    = [System.Drawing.Size]::new($Script:SzerokoscOkna,
                                                     ($kompWiersz5 + $Script:OdstepPodEtykieta +
                                                      $wysokoscStatusu))
    $pnlKomputer.Visible = $false

    $lblKompKatalog = New-JezykEtykieta 'Katalog komputera:' $Script:Margines $kompWiersz0
    $txtKompKatalog = New-JezykPole $Script:Margines ($kompWiersz0 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    # Droga odwrotna do "Ostatnio uzywany komputer": z maszyny do uzytkownika (SCCM).
    $lblKompUzytkownik = New-JezykEtykieta 'Ostatnio zalogowany użytkownik:' $Script:Margines $kompWiersz1
    $txtKompUzytkownik = New-JezykPole $Script:Margines ($kompWiersz1 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $btnInfoUzytkownik = New-JezykPrzyciskInfo 'Uzytkownik'

    # Wlasciciel obiektu w AD z data zalozenia; niebieski "!" tylko gdy pole nie nazywa osoby.
    $lblKompTworca = New-JezykEtykieta 'Dodany do AD przez:' $Script:Margines $kompWiersz2
    $txtKompTworca = New-JezykPole $Script:Margines ($kompWiersz2 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $btnInfoTworca = New-JezykPrzyciskInfo 'Tworca'
    Set-JezykWyglad $btnInfoTworca 'InfoNiebieski' -Rejestruj

    # Stan konta komputera w AD - pole kolorowane (zielone, czerwone, neutralne).
    $lblKompWlaczone = New-JezykEtykieta 'Konto komputera w AD:' $Script:Margines $kompWiersz3
    $txtKompWlaczone = New-JezykPole $Script:Margines ($kompWiersz3 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    # MAC i IP maszyny (jedyny dwukolumnowy wiersz panelu); kolor sondy niesie pole adresu IP.
    $lblKompMac = New-JezykEtykieta 'Adres MAC:' $Script:Margines $kompWiersz4
    $txtKompMac = New-JezykPole $Script:Margines ($kompWiersz4 + $Script:OdstepPodEtykieta) $Script:SzerokoscKolumny
    # Niebieski "!" - brak dopasowania karty to nie usterka.
    $btnInfoMacMaszyny = New-JezykPrzyciskInfo 'MacMaszyny'
    Set-JezykWyglad $btnInfoMacMaszyny 'InfoNiebieski' -Rejestruj

    $lblKompIp = New-JezykEtykieta 'Adres IP:' $Script:DrugaKolumna $kompWiersz4
    $txtKompIp = New-JezykPole $Script:DrugaKolumna ($kompWiersz4 + $Script:OdstepPodEtykieta) `
                               ($Script:SzerokoscKolumny - $szerokoscPingu - $przerwaPingu)

    $btnKompPinguj           = New-Object System.Windows.Forms.Button
    $btnKompPinguj.Text      = ''
    $btnKompPinguj.Tag       = 'Pinguj'
    $btnKompPinguj.Width     = $szerokoscPingu
    $btnKompPinguj.Height    = $wysokoscPola
    $btnKompPinguj.Left      = $Script:DrugaKolumna + $Script:SzerokoscKolumny - $szerokoscPingu
    $btnKompPinguj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnKompPinguj 'Przycisk' -Rejestruj
    $btnKompPinguj.Enabled   = $false
    $btnKompPinguj.TabStop   = $false

    # "Polacz" nad "Pinguj", jak w widoku konta; wspolrzedne z sasiada.
    $btnKompPolacz           = New-Object System.Windows.Forms.Button
    $btnKompPolacz.Text      = ''
    $btnKompPolacz.Tag       = 'Połącz'
    $btnKompPolacz.Width     = $szerokoscPingu
    $btnKompPolacz.Height    = $wysokoscPola
    $btnKompPolacz.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnKompPolacz 'Przycisk' -Rejestruj
    $btnKompPolacz.Visible   = $false
    $btnKompPolacz.TabStop   = $false

    # "Dyski" obok "Polacz", znika i pojawia sie jak on - stan poczatkowy przez Visible, nie Enabled.
    $btnKompDyski           = New-Object System.Windows.Forms.Button
    $btnKompDyski.Text      = ''
    $btnKompDyski.Tag       = 'Dyski'
    $btnKompDyski.Width     = $szerokoscPingu
    $btnKompDyski.Height    = $wysokoscPola
    $btnKompDyski.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnKompDyski 'Przycisk' -Rejestruj
    $btnKompDyski.Visible   = $false
    $btnKompDyski.TabStop   = $false

    # "Status:" w dwoch linijkach, jak w widoku konta; "!" dla niepowodzen akcji zdalnych.
    $lblKompStatus  = New-JezykEtykieta 'Status:' $Script:Margines $kompWiersz5
    $txtKompStatus  = New-JezykPole $Script:Margines ($kompWiersz5 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $txtKompStatus.Multiline = $true
    $btnInfoStatusMaszyny = New-JezykPrzyciskInfo 'StatusMaszyny'

    $pnlKomputer.Controls.AddRange(@($lblKompKatalog, $txtKompKatalog,
                                     $lblKompUzytkownik, $txtKompUzytkownik, $btnInfoUzytkownik,
                                     $lblKompTworca, $txtKompTworca, $btnInfoTworca,
                                     $lblKompWlaczone, $txtKompWlaczone,
                                     $lblKompMac, $txtKompMac, $btnInfoMacMaszyny,
                                     $lblKompIp, $txtKompIp, $btnKompPinguj, $btnKompPolacz,
                                     $btnKompDyski,
                                     $lblKompStatus, $txtKompStatus, $btnInfoStatusMaszyny))

    # Pas podpisu: dwa napisy i ikonka motywu na jednej linii pisma; pion nadaje Set-JezykWysokoscOkna.
    $lblAutor           = New-JezykEtykieta ('Autor: ' + $Script:Config.Autor) `
                                            $Script:Margines 0
    Set-JezykWyglad $lblAutor 'Podpis' -Rejestruj
    $lblAutor.Font      = $czcionkaPasa

    # Numer wersji na drugim koncu pasa; pion z podpisu, poziom z wyrownania.
    $lblWersja           = New-JezykEtykieta ('Wersja: ' + $Script:Config.Wersja) $Script:Margines $lblAutor.Top
    Set-JezykWyglad $lblWersja 'Podpis' -Rejestruj
    $lblWersja.Font      = $lblAutor.Font

    # Przycisk motywu (ksiezyc albo slonce): bez ramki, zerowe marginesy, bok z wysokosci pasa.
    $btnMotyw           = New-Object System.Windows.Forms.Button
    $btnMotyw.Size      = [System.Drawing.Size]::new($Script:WysokoscPasaPodpisu, $Script:WysokoscPasaPodpisu)
    $btnMotyw.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMotyw.FlatAppearance.BorderSize = 0
    $btnMotyw.TabStop   = $false
    $btnMotyw.Padding   = [System.Windows.Forms.Padding]::new(0)
    $btnMotyw.Margin    = [System.Windows.Forms.Padding]::new(0)
    Set-JezykWyglad $btnMotyw 'Ikona' -Rejestruj
    $btnMotyw.Add_Paint({ Set-JezykRysunekMotywu -Grafika $_.Graphics -Bok $this.Width })

    # Kwadraty ze strzalka trzech list - wspolrzedne w sekcji wyrownania.
    $strzDomeny = New-JezykStrzalkaListy
    $strzTryb   = New-JezykStrzalkaListy
    $strzWynik  = New-JezykStrzalkaListy

    $form.Controls.AddRange(@($lblDomena, $cmbDomena, $lblPodaj, $cmbTryb,
                              $txtSzukaj, $jezSzukania, $btnSzukaj, $cmbWynik,
                              $pnlKonto, $pnlKomputer, $lblAutor, $lblWersja, $btnMotyw,
                              $strzDomeny, $strzTryb, $strzWynik))

    # Uwaga: kwadraty na wierzch (SetChildIndex 0) - AddRange dokleja na spod i nie byloby ich widac.
    foreach ($strzalka in @($strzDomeny, $strzTryb, $strzWynik)) {
        $form.Controls.SetChildIndex($strzalka, 0)
    }

    # --- WYROWNANIE W PIONIE ---------------------------------------------------------
    # Po dodaniu kontrolek do okna - dopiero wtedy maja czcionke okna; przyciski maja juz wysokosc pola.

    Set-JezykSrodekTekstu $lblDomena $cmbDomena.Height
    Set-JezykSrodekTekstu $lblPodaj  $cmbTryb.Height

    # Oba napisy pasa w pudelku o wysokosci ikonki (jedna linia pisma); przed dosuwaniem do prawej.
    Set-JezykSrodekTekstu $lblAutor  $Script:WysokoscPasaPodpisu
    Set-JezykSrodekTekstu $lblWersja $Script:WysokoscPasaPodpisu

    # Wersja do prawego marginesu dopiero teraz - Width znany po odziedziczeniu czcionki.
    Set-JezykDoPrawej @($lblWersja) ($Script:SzerokoscOkna - $Script:Margines)

    # Ikonka motywu na lewo od napisu z wersja, liczona od niego; gora wprost z napisu.
    $btnMotyw.Top = $lblWersja.Top
    Set-JezykDoPrawej @($btnMotyw) ($lblWersja.Left - $Script:OdstepIkonyMotywu)

    # Wysokosc jeza z listy domen (rosnie z czcionka).
    $jezSzukania.Height = $cmbDomena.Height

    # Srodek pierwszego wiersza z pomiaru listy domen (bywa o piksel nizsza od pola).
    $srodekDomeny = Get-JezykSrodekWiersza $cmbDomena.Height
    # Drugi srodek z pierwszego, nie druga kopia liczby.
    $srodekPodaj  = $srodekDomeny + $Script:PasekDomeny

    Set-JezykSrodekPionowy @($lblDomena, $cmbDomena, $jezSzukania) $srodekDomeny
    Set-JezykSrodekPionowy @($lblPodaj, $cmbTryb, $txtSzukaj, $btnSzukaj) $srodekPodaj

    # Kwadraty ze strzalka na przyciskach list; szerokosc liczy Windows (Get-JezykSzerokoscStrzalki).
    $szerStrzalki = Get-JezykSzerokoscStrzalki
    Set-JezykStrzalkaListy $cmbDomena $strzDomeny $szerStrzalki
    Set-JezykStrzalkaListy $cmbTryb   $strzTryb   $szerStrzalki
    Set-JezykStrzalkaListy $cmbWynik  $strzWynik  $szerStrzalki

    # Kwadrat listy kont widoczny razem z nia (dalej pilnuje tego zdarzenie VisibleChanged).
    $strzWynik.Visible = $cmbWynik.Visible

    # Znaczniki i ich napisy w jednym pudelku (wspolna linia pisma); zapas na kwadrat 13 px.
    $wysokoscZnacznika = [int][math]::Ceiling($form.Font.GetHeight()) + 8
    foreach ($znacznik in @($chkAktywne, $chkZablokowane, $chkFlagaHasla,
                            $lblAktywne, $lblZablokowane, $lblFlagaHasla)) {
        Set-JezykSrodekTekstu $znacznik $wysokoscZnacznika
    }

    # Trzy znaczniki wysrodkowane, kazdy w swojej trzeciej czesci ramki (miary z DisplayRectangle).
    $obszarFlag = $grpFlagi.DisplayRectangle

    Set-JezykSrodekWSlupkach @($chkAktywne, $chkZablokowane, $chkFlagaHasla) `
                             $obszarFlag.Left $obszarFlag.Width `
                             @($lblAktywne, $lblZablokowane, $lblFlagaHasla) `
                             (Get-JezykOdstepZnacznika $lblAktywne.Font)

    # Pion od linii ramki (polowa paska tytulu GroupBoxa), nie od DisplayRectangle; Floor, nie [int].
    $goraRamkiFlag = [int][Math]::Floor($obszarFlag.Top / 2)
    $srodekFlag    = $goraRamkiFlag +
                     [int][Math]::Floor(($grpFlagi.ClientSize.Height - $goraRamkiFlag) / 2)
    Set-JezykSrodekPionowy @($chkAktywne, $chkZablokowane, $chkFlagaHasla,
                             $lblAktywne, $lblZablokowane, $lblFlagaHasla) $srodekFlag

    # Przy werdykcie odwrotnie: kwadrat dostaje wysokosc wiekszego napisu.
    $wysokoscWerdyktu = $lblWerdykt.PreferredSize.Height + 4
    Set-JezykSrodekTekstu $lblWerdykt $wysokoscWerdyktu $Script:NajdluzszyWerdykt
    Set-JezykSrodekTekstu $chkWerdykt $wysokoscWerdyktu

    # Napis werdyktu od kwadratu o jedna spacje swojej czcionki.
    $lblWerdykt.Left = $chkWerdykt.Left + $chkWerdykt.Width +
                       (Get-JezykOdstepZnacznika $lblWerdykt.Font)

    Set-JezykSrodekPionowy @($chkWerdykt, $lblWerdykt, $btnOdblokuj) $Script:SrodekWerdyktu

    # Oba pola "Status:" dostaja druga linijke - z czcionki, ta sama liczba co wysokosc paneli.
    foreach ($pole in @($txtStatus, $txtKompStatus)) {
        $pole.Height = $pole.PreferredHeight + $drugaLinia
    }

    # --- ETYKIETY NIE MOGA SIEGNAC SWOJEGO POLA --------------------------------------
    # Regula: Set-JezykEtykietaNadPolem.
    foreach ($panel in @($pnlKonto, $pnlKomputer)) {
        foreach ($kontrolka in $panel.Controls) {
            if ($kontrolka -is [System.Windows.Forms.Label]) { Set-JezykEtykietaNadPolem $kontrolka }
        }
    }

    # --- PRZYCISKI "!" ---------------------------------------------------------------
    # Na samym koncu wyrownania - pion liczony z czcionki etykiet.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik,
                        $btnInfoKomputerWspoldzielony, $btnInfoTworca, $btnInfoMac,
                        $btnInfoMacMaszyny, $btnInfoStatusMaszyny)) {
        # Pogrubiona czcionka z czcionki okna.
        $info.Font = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size, [System.Drawing.FontStyle]::Bold)

        # Na wierzch panelu - dluga etykieta nie moze zakryc "!".
        $info.Parent.Controls.SetChildIndex($info, 0)
    }

    # "Pinguj" srodkowany na swoim polu (pomiar po dodaniu do okna).
    Set-JezykSrodekPionowy @($btnPinguj) `
        ($txtKomputerUzytkownika.Top + (Get-JezykPolowaWysokosci $txtKomputerUzytkownika.Height))

    # Przycisk grup srodkowany na polu katalogu z tego samego wiersza.
    Set-JezykSrodekPionowy @($btnGrupyAd) `
        ($txtKatalog.Top + (Get-JezykPolowaWysokosci $txtKatalog.Height))

    # "Polacz" od gotowego Top sasiada ("Pinguj") - odstep niezalezny od DPI.
    $odstepPionowyPolacz = 2
    $btnPolacz.Left = $btnPinguj.Left
    $btnPolacz.Top  = $btnPinguj.Top - $btnPolacz.Height - $odstepPionowyPolacz

    # Wyzsze przyciski zsuwamy razem, zeby "Polacz" nie wszedl na pole wiersz wyzej.
    Set-JezykPonizejPola @($btnPolacz, $btnPinguj) $txtImieNazwisko $odstepPionowyPolacz

    # Kazdy "!" konczy sie razem ze swoim polem; czerwony i niebieski przy maszynie nigdy razem.
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoKomputer              $lblKomputerUzytkownika $txtKomputerUzytkownika
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoKomputerWspoldzielony $lblKomputerUzytkownika $txtKomputerUzytkownika
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoMac                   $lblKomputerMac         $txtKomputerMac
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoStatus                $lblStatus              $txtStatus
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoUzytkownik            $lblKompUzytkownik      $txtKompUzytkownik
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoTworca                $lblKompTworca          $txtKompTworca
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoMacMaszyny            $lblKompMac             $txtKompMac
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoStatusMaszyny         $lblKompStatus          $txtKompStatus

    # Ta sama para w widoku komputera: "Pinguj" na polu, "Polacz" od sasiada.
    Set-JezykSrodekPionowy @($btnKompPinguj) `
        ($txtKompIp.Top + (Get-JezykPolowaWysokosci $txtKompIp.Height))

    $btnKompPolacz.Left = $btnKompPinguj.Left
    $btnKompPolacz.Top  = $btnKompPinguj.Top - $btnKompPolacz.Height - $odstepPionowyPolacz

    # "Dyski" bierze obie wspolrzedne od "Polacz".
    $btnKompDyski.Left = $btnKompPolacz.Left - $btnKompDyski.Width - $przerwaPingu
    $btnKompDyski.Top  = $btnKompPolacz.Top

    # To samo zsuniecie co w widoku konta (pole wiersz wyzej: "Konto komputera w AD").
    Set-JezykPonizejPola @($btnKompDyski, $btnKompPolacz, $btnKompPinguj) `
                         $txtKompWlaczone $odstepPionowyPolacz

    # --- WIERSZE ZASILANE PRZEZ SCCM -------------------------------------------------
    # Opis dla Set-JezykUkladSccm: Wiersze (znikaja w calosci), Stale (wracaja), Zmienne (tylko chowane).
    # Uwaga: nowa kontrolka w tych wierszach musi tu trafic - inaczej zostanie na polu, ktore wjedzie.
    $Script:WierszeSccm = @(
        [pscustomobject]@{
            Panel   = $pnlKonto
            Wiersze = @($txtKomputerMac)
            Stale   = @($lblKomputerUzytkownika, $txtKomputerUzytkownika, $btnPinguj,
                        $lblKomputerMac, $txtKomputerMac, $lblKomputerIp, $txtKomputerIp)
            Zmienne = @($btnPolacz, $btnInfoKomputer, $btnInfoKomputerWspoldzielony, $btnInfoMac)
        },
        [pscustomobject]@{
            Panel   = $pnlKomputer
            Wiersze = @($txtKompUzytkownik, $txtKompMac)
            Stale   = @($lblKompUzytkownik, $txtKompUzytkownik,
                        $lblKompMac, $txtKompMac, $lblKompIp, $txtKompIp, $btnKompPinguj)
            Zmienne = @($btnInfoUzytkownik, $btnInfoMacMaszyny, $btnKompPolacz, $btnKompDyski)
        })

    # Enter w dowolnym miejscu okna dziala jak klikniecie "Szukaj".
    $form.AcceptButton = $btnSzukaj

    # Rejestr kontrolek przed podpieciem zdarzen - procedury siegaja wylacznie tutaj.
    $Script:Kontrolki = @{
        Okno          = $form
        Domena        = $cmbDomena
        Tryb          = $cmbTryb
        PoleSzukaj    = $txtSzukaj
        Przycisk      = $btnSzukaj
        JezSzukania   = $jezSzukania
        ListaKont     = $cmbWynik
        # Kwadraty ze strzalka - dla procedur zdarzen.
        StrzalkaDomeny    = $strzDomeny
        StrzalkaTrybu     = $strzTryb
        StrzalkaListyKont = $strzWynik
        PanelKonto    = $pnlKonto
        PanelKomputer = $pnlKomputer
        # Pas podpisu - przesuwa go Set-JezykWysokoscOkna.
        PodpisAutor   = $lblAutor
        PodpisWersja  = $lblWersja
        PrzyciskMotyw = $btnMotyw

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
        # Jedyna etykieta zmieniajaca tresc: "Login:" albo "Nazwa:" (kontakt).
        EtykietaLoginKonta = $lblLoginKonta
        TxtImieNazwisko   = $txtImieNazwisko
        TxtEmail          = $txtEmail
        TxtTelefon        = $txtTelefon
        TxtMenedzer       = $txtMenedzer
        PrzyciskOdblokuj       = $btnOdblokuj
        TxtOstatnieLogowanie   = $txtOstatnieLogowanie
        TxtKomputerUzytkownika = $txtKomputerUzytkownika
        TxtKomputerIp          = $txtKomputerIp
        TxtKomputerMac         = $txtKomputerMac
        PrzyciskPinguj         = $btnPinguj
        PrzyciskPolacz         = $btnPolacz
        # Widok zapala go i gasi - patrz Set-JezykPrzyciskGrupy w Jezyk-3-Widok.ps1.
        PrzyciskGrupyAd        = $btnGrupyAd
        TxtKatalog        = $txtKatalog
        TxtStatus         = $txtStatus

        TxtKomputerKatalog = $txtKompKatalog
        TxtKomputerStatus  = $txtKompStatus
        # Pole widoku KOMPUTERA z uzytkownikiem (nie mylic z TxtKomputerUzytkownika w widoku konta).
        TxtKomputerUzytkownikMaszyny = $txtKompUzytkownik
        TxtKomputerTworca            = $txtKompTworca
        TxtKomputerWlaczone          = $txtKompWlaczone
        # Przyrostek "Maszyny" = widok komputera.
        TxtKomputerIpMaszyny         = $txtKompIp
        TxtKomputerMacMaszyny        = $txtKompMac
        PrzyciskPingujMaszyny        = $btnKompPinguj
        PrzyciskPolaczMaszyny        = $btnKompPolacz
        PrzyciskDyskiMaszyny         = $btnKompDyski

        # Przyciski "!" - klucze "Info" + klucz z Set-JezykInfo (skleja je sama).
        InfoStatus                = $btnInfoStatus
        InfoKomputer              = $btnInfoKomputer
        InfoUzytkownik            = $btnInfoUzytkownik
        InfoTworca                = $btnInfoTworca
        InfoMac                   = $btnInfoMac
        InfoKomputerWspoldzielony = $btnInfoKomputerWspoldzielony
        InfoMacMaszyny            = $btnInfoMacMaszyny
        InfoStatusMaszyny         = $btnInfoStatusMaszyny
    }

    # --- ZDARZENIA -------------------------------------------------------------------
    # Scriptblocki nie odwoluja sie do zmiennych lokalnych tej funkcji.
    $btnSzukaj.Add_Click({ Invoke-JezykSearch })

    # Kwadraty ze strzalka: rysunek i klikniecie przekazane liscie (DroppedDown).
    foreach ($strzalka in @($strzDomeny, $strzTryb, $strzWynik)) {
        $strzalka.Add_Paint({ Set-JezykRysunekStrzalkiListy -Strzalka $this -Grafika $_.Graphics })
    }
    $strzDomeny.Add_Click({ $Script:Kontrolki.Domena.DroppedDown    = $true })
    $strzTryb.Add_Click({   $Script:Kontrolki.Tryb.DroppedDown      = $true })
    $strzWynik.Add_Click({  $Script:Kontrolki.ListaKont.DroppedDown = $true })

    $cmbWynik.Add_VisibleChanged({ $Script:Kontrolki.StrzalkaListyKont.Visible = $this.Visible })

    # Ramka wokol flag konta przemalowana po WinForms - patrz Set-JezykRysunekRamkiFlag.
    $grpFlagi.Add_Paint({ Set-JezykRysunekRamkiFlag -Ramka $this -Grafika $_.Graphics })

    $zegar          = New-Object System.Windows.Forms.Timer
    $zegar.Interval = 250
    $zegar.Add_Tick({
        # Kazde zadanie sprawdzane niezaleznie - wolniejsze nie wstrzymuje szybszego.
        Receive-JezykZadanieLogowania
        Receive-JezykZadanieKomputera
        Receive-JezykZadanieUzytkownika
        Receive-JezykZadaniePingu
        Receive-JezykZadanieNumeru
        Receive-JezykZadanieDysku
        Receive-JezykZadanieGrupy

        # Kropki PO wszystkich Receive - odpowiedz z tego taktu zdazyla zgasic notke.
        Update-JezykKropkiSprawdzania

        Clear-JezykZadaniaPorzucone

        # Zegar stoi, gdy nic nie biegnie i nie ma porzuconych (spisane czekaja na nastepne szukanie).
        if (-not $Script:ZadanieLogowania -and -not $Script:ZadanieKomputera -and
            -not $Script:ZadanieUzytkownika -and -not $Script:ZadaniePingu -and
            -not $Script:ZadanieNumeru -and -not $Script:ZadanieDysku -and
            -not $Script:ZadanieGrupy -and
            @($Script:ZadaniaPorzucone).Count -eq 0) {
            $Script:ZegarTla.Stop()
        }
    })
    $Script:ZegarTla = $zegar

    # Osobny zegar animacji jeza (~16 klatek/s), chodzi tylko w stanie 'Szuka'.
    $zegarJeza          = New-Object System.Windows.Forms.Timer
    $zegarJeza.Interval = $Script:TaktJeza
    $zegarJeza.Add_Tick({
        $Script:KlatkaJeza++
        # Invalidate tylko tutaj - widok dotyka wylacznie Visible.
        $Script:Kontrolki.JezSzukania.Invalidate()
    })
    $Script:ZegarJeza = $zegarJeza

    # Sprzatanie zadan i zegara jeza przy zamykaniu okna.
    $form.Add_FormClosing({
        Stop-JezykZadaniaTla
        if ($Script:ZegarJeza) { $Script:ZegarJeza.Stop() }
    })

    # Jedna procedura dla wszystkich "!" - klucz z Tag przycisku.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik,
                        $btnInfoKomputerWspoldzielony, $btnInfoTworca, $btnInfoMac,
                        $btnInfoMacMaszyny, $btnInfoStatusMaszyny)) {
        $info.Add_Click({ Show-JezykInformacja ([string]$this.Tag) })
    }

    # Kazdy przycisk z napisem rysuje go sam (Text pusty) - pominiety bylby pusty.
    foreach ($przycisk in @($btnSzukaj, $btnOdblokuj, $btnPinguj, $btnPolacz,
                            $btnGrupyAd, $btnKompPinguj, $btnKompPolacz, $btnKompDyski)) {
        $przycisk.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
    }

    $cmbDomena.Add_SelectedIndexChanged({
        $Script:Config.Domena = [string]$Script:Kontrolki.Domena.SelectedItem
        # Kontrolery innej domeny to inne maszyny - zapamietana lista przestaje obowiazywac.
        $Script:KontroleryCache = @{}
        # Set-JezykWidok czysci widok i ustawia przycisk odblokowania dla nowej domeny.
        Set-JezykWidok
    })

    $btnOdblokuj.Add_Click({ Invoke-JezykOdblokowanie })
    $btnPinguj.Add_Click({ Invoke-JezykPing })
    $btnPolacz.Add_Click({ Invoke-JezykPolacz })
    # Drugi panel - widok podany jawnie.
    $btnKompPinguj.Add_Click({ Invoke-JezykPing   -Widok Maszyna })
    $btnKompPolacz.Add_Click({ Invoke-JezykPolacz -Widok Maszyna })
    # Bez -Widok: ten przycisk stoi tylko w jednym panelu, wiec nie ma czego wskazywac.
    $btnKompDyski.Add_Click({ Invoke-JezykDyski })
    $btnGrupyAd.Add_Click({ Show-JezykGrupyAd })

    $btnMotyw.Add_Click({ Invoke-JezykPrzelaczenieMotywu })

    $cmbTryb.Add_SelectedIndexChanged({ Set-JezykWidok })
    $cmbWynik.Add_SelectedIndexChanged({ Invoke-JezykWyborKonta })

    # Po pokazaniu okna: fokus, systemowa czesc motywu (potrzebuje uchwytow) i oprawa list.
    $form.Add_Shown({
        $Script:Kontrolki.PoleSzukaj.Focus()
        Set-JezykMotywSystemowy

        # Wymiary list sa prawdziwe dopiero teraz - patrz Update-JezykOprawaList.
        Update-JezykOprawaList
    })

    # Oprawa list przeliczana takze po kazdej zmianie ich rozmiaru.
    foreach ($lista in @($cmbDomena, $cmbTryb, $cmbWynik)) {
        $lista.Add_SizeChanged({ Update-JezykOprawaList })
    }

    # Wysokosc okna i pas podpisu tym samym wywolaniem, co przy zmianie trybu (widok podany jawnie).
    Set-JezykWysokoscOkna $Script:PanelZListą $pnlKonto.Height

    # Motyw na samym koncu, gdy wszystkie kontrolki maja role.
    Set-JezykMotyw $Script:Motyw

    $form
}

#endregion
