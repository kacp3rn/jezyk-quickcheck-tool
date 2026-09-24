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
# Odstepy BYLY rozrzutne celowo: pola biora wysokosc z czcionki, wiec przy skalowaniu DPI
# 125-150% rosna, a wspolrzedne zostaja - zapas chronil wtedy przed nachodzeniem wierszy.
# Cena byla jednak stala: przy zwyklej czcionce ten sam zapas zostawal miedzy polami jako
# pustka, ktorej nikt nie potrzebowal. Dlatego skok wiersza NIE JEST juz wpisana liczba,
# tylko wynikiem pomiaru pola (patrz $Script:SkokWiersza nizej) - rosnie wtedy, gdy rosnie
# czcionka, i tylko wtedy.

# Odstep od paska tytulu do pierwszej kontrolki. WLASNA LICZBA, a nie polowa pierwszego
# wiersza: wiersz srodkuje sie wokol stalej wspolrzednej, a wysokosc listy rosnie z czcionka
# systemu, wiec margines wychodzacy jako "srodek minus polowa kontrolki" zwezal sie sam -
# przy 100% DPI zostawalo z niego osiem pikseli, przy "Rozmiarze tekstu" 150% trzy. Srodek
# wiersza liczy dzis Get-JezykSrodekWiersza WLASNIE Z TEGO MARGINESU i z pomiaru kontrolki,
# ktora w tym wierszu stoi.
#
# Reszty bialego miejsca nad napisem "Domena" nie da sie zabrac: to jeszcze okolo czterech
# pikseli wewnetrznego marginesu listy i etykiety, ktory rysuje Windows.
$Script:MarginesGorny = 2

# Odstep od DOLU pola do etykiety nastepnego wiersza - jedyna liczba opisujaca gestosc
# siatki. Cala reszta skoku to miejsce, ktore zajmuja sama etykieta i samo pole. Stoi tak
# wysoko, bo liczy sie z niej takze pietro panelu ponizej.
$Script:PrzerwaWierszy     = 8

# Wiersz z wyborem domeny stoi nad wszystkim, wiec reszta okna schodzi o jego wysokosc.
$Script:PasekDomeny   = 30

# ZADNEGO WLASNEGO PASA NA WSKAZNIK PRACY. Pasek postepu mial tu kiedys swoje dziesiec
# pikseli pod wierszem wyszukiwania; zastapil go jez, ktory stoi w miejscu JUZ PUSTYM -
# w prawej, niezajetej czesci wiersza domeny (patrz sekcja JEZ nizej). Dlatego panele
# wracaja do wspolrzednych sprzed paska i okno jest o te dziesiec pikseli nizsze.
#
# TA WARTOSC TO WYLACZNIE PUNKT STARTOWY, policzony dla pola o zwyklej wysokosci 22 px -
# tak samo jak $Script:SkokWiersza nizej. New-JezykForm przelicza ja z FAKTYCZNEGO pomiaru
# (Get-JezykPietroBezListy), zanim postawi pierwsza kontrolke: gorny margines jest stala,
# a oba wiersze nad panelem rosna z czcionka, wiec pietro musi jechac razem z nimi.
$Script:PanelBezListy = $Script:MarginesGorny + $Script:PasekDomeny + 22 + $Script:PrzerwaWierszy

# Miejsce na sama liste wyboru kont - wiersz, ktory pokazuje sie wylacznie przy wyszukiwaniu
# czesciowym.
$Script:PasListyWyboru = 30
# Pietro z lista wyboru LICZONE OD PIETRA BEZ NIEJ: roznica to miejsce na sama liste,
# wiec zmiana jednego z tych dwoch nie moze zostawic drugiego w tyle.
$Script:PanelZListą   = $Script:PanelBezListy + $Script:PasListyWyboru

$Script:PierwszyWiersz     = 92    # y etykiety pierwszego wiersza wewnatrz panelu konta
$Script:OdstepPodEtykieta  = 20    # ile nizej od etykiety lezy jej pole

# Odleglosc miedzy kolejnymi wierszami. LICZONA Z WYSOKOSCI POLA, a nie wpisana na sztywno:
# wiersze stoja na stalych wspolrzednych, a pole bierze wysokosc z czcionki okna, ktora
# Windows powieksza przy skalowaniu ekranu i przy ustawieniu "Rozmiar tekstu". Liczba
# wpisana recznie musialaby wiec obsluzyc najwieksza czcionke - i przy zwyklej zostawiala
# miedzy wierszami dwa razy wiecej pustki, niz trzeba.
#
# TA WARTOSC TO WYLACZNIE PUNKT STARTOWY, policzony dla pola o zwyklej wysokosci 22 px.
# New-JezykForm przelicza ja z FAKTYCZNEGO pomiaru, zanim postawi pierwsza kontrolke.
$Script:SkokWiersza        = $Script:OdstepPodEtykieta + 22 + $Script:PrzerwaWierszy

# Pusty pas, ktory pudelko znacznika BEZ TEKSTU ma za kwadratem - WinForms dokleja za nim
# piksel odstepu i piksel zapasu. Napis znacznika liczy sie od KONCA KWADRATU (patrz
# Get-JezykOdstepZnacznika), wiec ten pas trzeba odjac - inaczej kazdy napis stalby o dwa
# piksele dalej, niz mowi jego odstep.
#
# Pudelka moga przez to na siebie zachodzic, gdy spacja jest wezsza od pasa. To bezpieczne:
# pas jest pusty, znacznik lezy wyzej (AddRange dodaje go przed etykieta), a etykieta
# zaczyna tekst dopiero za wlasnym marginesem, szerszym niz te 2 px.
$Script:PasZaZnacznikiem   = 2

# O ILE WYKRZYKNIK COFA SIE OD PRAWEJ KRAWEDZI POLA. Prostokat pola konczy sie dalej niz
# jego WIDOCZNA ramka: przy Fixed3D ostatnia kolumna to jasny refleks krawedzi 3D, ktory
# na tle okna znika, a przy FixedSingle kreska jest wprawdzie widoczna, ale przycisk "!"
# ma wlasna ramke 2 px i zlewa sie z nia w jeden gruby slupek. Kwadrat konczacy sie
# dokladnie na Left + Width wygladal przez to w obu motywach na wysuniety poza pole.
$Script:CofniecieWykrzyknika = 1

# O ile szerszy od systemowego przycisku listy rozwijanej ma byc kwadrat, ktorym go
# zakrywamy. Szerokosc systemowego liczy WinForms i przy paru pikselach zapasu kryjemy
# kawalek ciemnego pola wiecej - czego nie widac. Kwadrat WEZSZY zostawilby po bokach
# jasne paski, czyli dokladnie to, co mial zakryc.
$Script:ZapasStrzalkiListy = 2

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

# KOLORY TU, PEDZLE NIE - i to nie jest kosmetyka. Pedzel to zasob GDI zakladany przy samym
# wczytaniu pliku, a ten plik dolacza kropka takze zestaw weryfikacyjny, ktory GDI nie ma:
# pedzel na poziomie skryptu wywrocilby CALY zestaw, zanim ruszyloby pierwsze sprawdzenie.
# Color::FromArgb jest czysta struktura, wiec paleta moze tu stac. Pedzle powstaja leniwie
# w Set-JezykRysunekJeza, ktore wola wylacznie procedura Paint - a tej zestaw nie wykonuje
# nigdy.
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

# --- IKONKA MOTYWU --------------------------------------------------------------------
# Ksiezyc albo slonce na przycisku w prawym dolnym rogu. FIGURY Z GEOMETRII, RYSOWANE
# Z WYGLADZANIEM - a nie mapa pikseli, jak dotad. Przy boku 18 px na komorke mapy
# przypadal jeden piksel, wiec luk sierpa i tarcza slonca wychodzily schodkami i ikonka
# wygladala na poszarpana. Znak z czcionki odpada tak samo jak wczesniej: glifow ksiezyca
# i slonca nie ma w Segoe UI, wiec Windows schodzi na czcionke zastepcza - a ta bywa inna
# na kazdej stacji i inaczej wysrodkowana.
#
# WYMIARY SA ULAMKAMI BOKU, a nie pikselami: figura rosnie razem z pasem podpisu przy
# DPI 125-150%, tak samo jak dotad rosla komorka mapy.
$Script:BokIkonyMotywu    = 18   # MINIMALNY bok ikonki - rosnie do wysokosci linii pisma

# WYSOKOSC PASA PODPISU - wspolne pudelko ikonki motywu i obu napisow w dolnym rogu.
# WARTOSC STARTOWA DLA ZWYKLEJ CZCIONKI, tak samo jak przy $Script:PanelBezListy wyzej:
# New-JezykForm przelicza ja z faktycznej czcionki okna (wieksze z dwojga - bok ikonki
# albo linia pisma). Stala musi tu stac, bo wysokosc okna liczy sie z niej jeszcze przed
# zbudowaniem okna, a brak wartosci dalby w arytmetyce po cichu zero.
$Script:WysokoscPasaPodpisu = $Script:BokIkonyMotywu

# Przerwa miedzy pudelkiem ikonki a pudelkiem napisu z wersja. Widac wiecej: napis zaczyna
# sie za wlasnym marginesem etykiety, a figura konczy przed krawedzia swojego kwadratu -
# razem wychodzi okolo pieciu-szesciu pikseli, czyli mniej wiecej szerokosc spacji.
$Script:OdstepIkonyMotywu = 5

# KSIEZYC pokazuje sie w motywie JASNYM - niesie to, co klikniecie WLACZY.
# Sierp to tarcza minus drugie kolo, przesuniete w prawo i w gore - rogi patrza wtedy
# w prawy gorny rog, jak w zwyklym znaku ksiezyca. Promien i przesuniecie kola
# wycinajacego sa ulamkami PROMIENIA TARCZY, bo to one razem decyduja o grubosci sierpa.
# 0.42 zostawialo po poltora piksela pustki z kazdej strony kwadratu, a sierp - ktory
# zajmuje polowe tarczy - czytal sie wtedy jako plama w jego lewym dolnym narozniku.
$Script:KsiezycPromien      = 0.47   # promien tarczy - ulamek boku
$Script:KsiezycWyciecie     = 0.85   # promien kola wycinajacego - ulamek promienia tarczy
$Script:KsiezycPrzesuniecie = 0.60   # odleglosc srodkow obu kol - ulamek promienia tarczy
# Kierunek wyciecia w stopniach; os Y rosnie W DOL, wiec kat ujemny kieruje rogi w gore.
# NIE -45: przy pelnej przekatnej ciezar sierpa wypadal dwa piksele pod srodkiem pudelka
# i ikonka czytala sie jako postawiona nizej niz napis obok niej. Przy -20 ksiezyc zostaje
# pochylony, a srodek masy wraca pod srodek kwadratu (patrz Get-JezykPrzesuniecieNaSrodek).
$Script:KsiezycKat          = -20
$Script:KsiezycPunktyLuku   = 24     # odcinki na kazdym z dwoch lukow sierpa

# SLONCE pokazuje sie w motywie CIEMNYM - tak samo, niesie powrot do jasnego.
$Script:SlonceTarcza    = 0.21   # promien tarczy - ulamek boku
$Script:SlonceRamieOd   = 0.33   # poczatek promienia - odleglosc od srodka, ulamek boku
$Script:SlonceRamieDo   = 0.48   # koniec promienia
$Script:SlonceGrubosc   = 0.11   # grubosc promienia - ulamek boku; przy 18 px to 2 px
$Script:SlonceIleRamion = 8

# KOLORY IKONEK NIE ZALEZA OD MOTYWU, i to nie jest niedopatrzenie: kazda ikonka pokazuje
# sie WYLACZNIE w swoim oknie - ksiezyc w jasnym, slonce w ciemnym - wiec kazda ma dobrany
# odcien pod SWOJE tlo i nigdy nie trafi na to drugie. Ksiezyc jest indygo, bo zolty na
# jasnoszarym tle wyplukuje sie do niewidocznosci; slonce zlote, bo na #202020 swieci.
#
# Klucze sa POJEDYNCZYMI LITERAMI i musza sie roznic takze bez wielkosci liter - tablica
# mieszajaca ich nie rozroznia i @{} z 'k' oraz 'K' rzuca "Duplicate keys", wywracajac cala
# czwarta czesc przy starcie. Zglasza to parser, wiec awaria wyglada na blad skladni
# w miejscu niezwiazanym z przyczyna.
$Script:PaletaIkonyMotywu = @{
    'k' = [System.Drawing.Color]::FromArgb(95, 110, 200)   # ksiezyc - indygo
    's' = [System.Drawing.Color]::FromArgb(255, 195, 55)   # slonce - tarcza
    'p' = [System.Drawing.Color]::FromArgb(255, 150, 40)   # slonce - promienie
}

# Bufor pedzli, zakladany przy pierwszym rysowaniu - tak samo jak $Script:PedzleJeza
# i z tego samego powodu: kolory sa stale, wiec nie ma go po co uniewazniac.
$Script:PedzleIkonyMotywu = $null

# Pedzel GDI. Wydzielony, bo to JEDYNE miejsce rysowania ikonki, ktore wychodzi poza
# proces - zestaw weryfikacyjny podstawia tutaj wlasna atrape i cala petla rysujaca
# wykonuje sie naprawde, zamiast byc sprawdzana regeksem po tresci funkcji.
function New-JezykPedzel {
    param($Kolor)
    [System.Drawing.SolidBrush]::new($Kolor)
}

# Widoczny obszar kontrolki. Wydzielony z tego samego powodu, co pedzel wyzej: Region to
# obiekt GDI, czyli drugi styk z systemem w obcinaniu ramki listy - zestaw weryfikacyjny
# podstawia tu wlasna atrape i cala arytmetyka obciecia wykonuje sie naprawde.
function New-JezykObszar {
    param([int]$X, [int]$Y, [int]$Szerokosc, [int]$Wysokosc)
    [System.Drawing.Region]::new([System.Drawing.Rectangle]::new($X, $Y, $Szerokosc, $Wysokosc))
}

<#
.SYNOPSIS
    Rysuje napis przycisku w CALYM jego prostokacie - dlatego wysokosc przycisku jest nasza.

.DESCRIPTION
    NAPIS RYSUJEMY SAMI I DZIEKI TEMU PRZYCISK MOZE BYC ROWNY POLU. WinForms uklada wlasny
    napis w prostokacie POMNIEJSZONYM o ramke stylu Flat, o grubosc z FlatAppearance.BorderSize,
    o staly margines wewnetrzny i o Padding - a gdy tego miejsca zabraknie, ucina mu ogonki
    liter (g, j, y, a z ogonkiem). Tak zginely kiedys napisy na CZYNNYCH "Pinguj", "Polacz"
    i "Szukaj". Pierwsza odpowiedzia byl wlasny wzor na te arytmetyke - mylil sie o piksel.
    Druga: zapytac o wysokosc sama kontrolke (GetPreferredSize) - a ta oddaje, ile potrzebuje
    NA SWOICH ZASADACH, czyli znacznie wiecej, niz ma pole obok, i przycisk wygladal przy
    polach na przerosniety. Napis srodkowany w CALYM prostokacie nie ma sie gdzie uciac, wiec
    pytanie o wysokosc przestaje istniec: przycisk dostaje tyle, ile ma pole.

    WARUNKIEM JEST PUSTY Text PRZYCISKU - napis WinForms lezalby pod naszym, przesuniety
    o te kilka pikseli ramki, i oba widac by bylo jako jeden rozmyty. Napis jedzie wiec
    w Tag, tak samo jak tresc pod przyciskiem "!".

    TLA ANI RAMKI NIE MALUJEMY. Rysowal je tu tylko ten, kto musial zetrzec napis narysowany
    pod spodem - a pod spodem nie ma teraz nic. Dzieki temu tlo, ramka, podswietlenie pod
    kursorem, wcisniecie i prostokat fokusu zostaja systemowe i dzialaja same.

    KOLOR Z PALETY, a nie z przycisku. WinForms przy FlatStyle = Flat maluje napis wylaczonego
    przycisku kolorem ControlPaint.Dark(BackColor) i nie ma wlasciwosci, ktora by to zmienila:
    przy tle #2D2D2D wychodzila z tego niemal czern i przycisk wygladal jak pusty prostokat,
    a operator nie wiedzial, czy jest wylaczony, czy to usterka narzedzia. Dlatego kolor
    wybiera stan Enabled, a jedna sciezka obsluguje oba motywy - w jasnym KolorNieczynny to
    systemowy GrayText, czyli dokladnie to, czego uzytkownik Windows sie spodziewa.
#>
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

# Napis wysrodkowany w prostokacie. Wydzielony, bo TextRenderer to - obok pedzla - drugi
# styk z systemem w rysowaniu przycisku; zestaw weryfikacyjny podstawia tu wlasna atrape
# i cala reszta funkcji wyzej wykonuje sie naprawde, zamiast byc sprawdzana regeksem.
function Set-JezykNapisNaSrodku {
    param($Grafika, [string]$Tekst, $Czcionka, [int]$Szerokosc, [int]$Wysokosc, $Kolor)

    [System.Windows.Forms.TextRenderer]::DrawText(
        $Grafika, $Tekst, $Czcionka,
        [System.Drawing.Rectangle]::new(0, 0, $Szerokosc, $Wysokosc),
        $Kolor,
        ([System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
         [System.Windows.Forms.TextFormatFlags]::VerticalCenter))
}

# Bufor pedzli kwadratu ze strzalka. Tak samo jak przy wylaczonym przycisku kolory ida
# z palety, wiec bufor pada przy kazdym przelaczeniu motywu - patrz Set-JezykMotyw.
$Script:PedzleStrzalki = $null

# NAJMNIEJSZA polowa podstawy trojkata. Przy 3 podstawa ma 7 px i wysokosc 4 px - tyle,
# ile ma systemowa strzalka listy przy 100% DPI. Wyzej trojkat ROSNIE RAZEM Z KWADRATEM:
# szerokosc przycisku listy liczy Windows i przy DPI 125-150% jest wieksza, a strzalka
# wpisana na sztywno zostalaby przy niej znaczkiem wielkosci jednej trzeciej pola.
$Script:MinimalnaPolowaStrzalki = 3

<#
.SYNOPSIS
    Maluje kwadrat ze strzalka, ktory zakrywa systemowy przycisk listy rozwijanej.

.DESCRIPTION
    ComboBox przy FlatStyle = Flat maluje swoj przycisk na sztywno kolorem
    SystemColors.Control, a strzalke - SystemColors.ControlText. Zadna wlasciwosc tego nie
    zmienia, wiec w ciemnym oknie przy ciemnej liscie zostawal jasny kwadrat. To ta sama
    sytuacja, co przy napisie wylaczonego przycisku: skoro systemowego rysowania nie da sie
    poprowadzic, nie uzywa sie go - kwadrat zaslania etykieta, ktora malujemy sami.

    TROJKAT ZLOZONY Z POZIOMYCH PASKOW, a nie z FillPolygon. Pasek to ten sam
    FillRectangle, ktorym maluje sie jez i ikonka motywu, wiec rysunek da sie odtworzyc ze
    sladu i porownac z oczekiwanym ksztaltem zamiast sprawdzac tresc funkcji regeksem.
#>
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

    # Szostka: przy kwadracie 19 px wychodzi z tego dokladnie systemowa polowa 3, a przy
    # kazdym szerszym trojkat zajmuje stala czesc jego szerokosci.
    $polowa  = [Math]::Max($Script:MinimalnaPolowaStrzalki, [int][Math]::Floor($szer / 6))
    $srodekX = [int][Math]::Floor($szer / 2)
    # Floor, nie [int]: [int] w PowerShellu zaokragla i przy nieparzystej wysokosci
    # kwadratu strzalka schodzilaby o piksel nizej, niz wypada srodek.
    $gora    = [int][Math]::Floor(($wys - ($polowa + 1)) / 2)

    for ($i = 0; $i -le $polowa; $i++) {
        $Grafika.FillRectangle($Script:PedzleStrzalki.Strzalka,
                               $srodekX - $polowa + $i, $gora + $i,
                               2 * ($polowa - $i) + 1, 1)
    }
}

# Grubosc pasa, ktorym zamalowujemy systemowa ramke wokol flag. Motyw rysuje ja jako linie
# i jej rozjasnienie, wiec jeden piksel by nie wystarczyl.
$Script:ZamalowanieRamkiFlag = 3

$Script:PedzleRamkiFlag = $null

<#
.SYNOPSIS
    Przemalowuje ramke wokol flag konta - kolorem obramowki z biezacej palety.

.DESCRIPTION
    GroupBox rysuje swoj obrys motywem systemu i nie ma wlasciwosci, ktora nadalaby mu
    kolor: w ciemnym oknie zostawala wokol trzech flag jasna, prawie biala obwodka. Trzeci
    przypadek tej samej reguly, po napisie wylaczonego przycisku i przycisku listy
    rozwijanej - systemowego rysowania nie da sie poprowadzic, wiec malujemy po nim.

    NAJPIERW ZETRZEC, POTEM NARYSOWAC. Sama linia w naszym kolorze zostawilaby pod soba
    systemowa: motyw rysuje ja grubsza niz piksel, wiec pas zamalowania musi byc szerszy
    od linii, ktora po nim idzie.

    ZAMALOWUJEMY CZTERY PASY, A NIE CALY PROSTOKAT - srodek ramki zajmuja znaczniki i ich
    napisy, a te rysuja sie WCZESNIEJ, bo sa osobnymi kontrolkami.

    PASY ZACZYNAJA SIE OD ZERA, A NIE OD NASZEJ LINII. Pierwsza wersja scierala dopiero od
    wysokosci $gora i gorna krawedz zostawala biala, choc trzy pozostale wychodzily dobrze:
    systemowa linia gorna lezy WYZEJ niz nasza i pas do niej nie siegal. Nad ramka jest
    pusto, wiec zamalowanie tego miejsca nic nie kosztuje - a jest odporne na to, gdzie
    dokladnie motyw systemu postawil swoja kreske.

    GORNA KRAWEDZ NASZEJ LINII LEZY W POLOWIE PASKA TYTULU, tak samo jak przy srodkowaniu
    znacznikow: GroupBox rezerwuje ten pasek nawet przy pustym tytule, a widoczna ramka
    biegnie przez jego srodek.
#>
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

<#
.SYNOPSIS
    Przesuniecie, ktore stawia SRODEK MASY wielokata w srodku kwadratu o podanym boku.

.DESCRIPTION
    SRODEK MASY, A NIE OBWIEDNIA. Obwiednia sierpa jest wysrodkowana sama z siebie - luk
    zewnetrzny biegnie po okregu wokol srodka kwadratu - ale ciezar figury lezy po stronie
    PRZECIWNEJ do wyciecia, a to ciezar czyta sie jako polozenie ikonki. Przy wycieciu
    skierowanym w gore sierp wygladal wiec na postawiony NIZEJ niz napis, obok ktorego stoi,
    choc arytmetyka obwiedni byla poprawna. To ta sama pomylka, co przy srodkowaniu etykiety
    z AutoSize na sasiedniej kontrolce: rownamy prostokaty, a widac tresc.

    PRZESUNIECIE PRZYCINAMY DO KWADRATU. Przy duzej tarczy pelne wyrownanie wyprowadzilo by
    figure za krawedz przycisku, a ikonka ucieta jest gorsza od nieco przesunietej. Stad
    Max/Min zamiast samej roznicy - i stad kat wyciecia dobrany tak, zeby reszta po
    przycieciu byla mniejsza od piksela.

    Pole liczone wzorem na powierzchnie wielokata (suma iloczynow skosnych): to samo, czym
    zestaw weryfikacyjny mierzy pole figury, ale tam liczone NIEZALEZNIE - inaczej
    sprawdzalby wzor samym soba.
#>
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

<#
.SYNOPSIS
    Figury ikonki motywu dla przycisku o podanym boku - sama geometria, bez GDI.

.DESCRIPTION
    Kazda figura to obiekt z Znak (klucz palety) i ALBO Punkty (wielokat), ALBO Kolo
    (prostokat opisany na kole). Wynik WYCHODZI ROZWINIETY - owijaj @() na miejscu
    wywolania, tak samo jak przy Get-JezykSpriteJeza.

    SIERP TO WIELOKAT Z DWOCH LUKOW. Zewnetrzny biegnie po tarczy od rogu do rogu przez
    strone oswietlona, wewnetrzny wraca po brzegu kola wycinajacego. Rogi to punkty
    przeciecia obu okregow. Liczone w ukladzie, w ktorym wyciecie lezy na osi X - wzor na
    przeciecie ma wtedy jeden wiersz - i dopiero na koncu obracane o $Script:KsiezycKat.
    Wielokat, a nie tarcza zamalowana kolorem tla: tlo przycisku zmienia sie pod kursorem,
    wiec zamalowane wyciecie pokazaloby sie wtedy jako drugie kolo.

    SRODEK W POLOWIE BOKU, bez zaokraglania. Set-JezykRysunekMotywu rysuje z przesunieciem
    pikseli o pol, wiec polowa boku wypada na granicy pikseli i figura ma po obu stronach
    tyle samo miejsca.

    SIERP DOSUWAMY SRODKIEM MASY (Get-JezykPrzesuniecieNaSrodek), bo sam w kwadracie stoi
    krzywo: obwiednia jest wysrodkowana, ale caly ciezar lezy po stronie przeciwnej do
    wyciecia. Slonce jest symetryczne wzgledem srodka i nie potrzebuje niczego takiego.
    Figura sierpa oddaje przez to SRODEK TARCZY po przesunieciu - wszystko, co liczy sie
    od tarczy, a nie od kwadratu, musi brac go stamtad.
#>
function Get-JezykFiguryMotywu {
    param([ValidateSet('Jasny', 'Ciemny')][string]$Motyw, [int]$Bok)

    $srodek = $Bok / 2

    if ($Motyw -eq 'Jasny') {
        # NAZWY W PELNYCH SLOWACH, I TO NIE JEST OZDOBA. Stalo tu $R, $r i $d - a PowerShELL
        # NIE ROZROZNIA WIELKOSCI LITER W NAZWACH ZMIENNYCH, wiec $R i $r to JEDNA zmienna:
        # druga linijka nadpisywala promien tarczy promieniem wyciecia. Sierp nadal wychodzil
        # sierpem, tylko o 15% mniejszym i innego kroju niz mowia stale - a zadne sprawdzenie
        # tego nie widzialo, bo kazde bylo prawdziwe dla dowolnego sierpa. To ta sama pulapka,
        # co przy kluczach tablicy mieszajacej 'o' i 'O' w palecie jeza, tylko cichsza: tam
        # parser rzucil "Duplicate keys", tutaj nie stalo sie nic.
        $promien         = $Script:KsiezycPromien * $Bok
        $promienWyciecia = $Script:KsiezycWyciecie * $promien
        $odstepSrodkow   = $Script:KsiezycPrzesuniecie * $promien

        # Przeciecie okregow: x0 - odleglosc cieciwy od srodka tarczy wzdluz osi wyciecia,
        # h - polowa cieciwy. t0 i s0 to katy rogu widziane ze srodka tarczy i ze srodka
        # kola wycinajacego.
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

    # Ramiona to waskie czworokaty wzdluz promienia kola - u = kierunek ramienia,
    # (-uy, ux) = kierunek w poprzek niego.
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

<#
.SYNOPSIS
    Rysuje ikonke motywu na przycisku - kolorami z palety ikonki.

.DESCRIPTION
    WYGLADZANIE WLACZONE. Przy boku 18 px luk bez wygladzania wychodzi schodkami - to
    wlasnie wygladalo na poszarpane. Krawedzie mieszaja sie z tlem przycisku, ktore
    WinForms maluje przed zdarzeniem Paint, wiec wygladaja dobrze na kazdym tle, takze
    na podswietleniu pod kursorem.

    PRZESUNIECIE PIKSELI O POL (PixelOffsetMode HighQuality). Bez niego srodek piksela
    lezy na liczbie calkowitej i figura wysrodkowana w polowie parzystego boku jest
    o pol piksela krzywa - rozmyta z jednej strony, ostra z drugiej.

    Jeden rodzaj obiektu GDI - pedzel - tak jak dotad: tarcza slonca to FillEllipse,
    reszta to FillPolygon.
#>
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
    i SolidBrush wymagaja GDI, ktorego zestaw weryfikacyjny nie ma - funkcji rysujacej nie
    wykona wiec nigdy, a liczba schowana w jej wnetrzu nie bylaby sprawdzona ani razu.
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

# Skok wiersza dla pola o podanej wysokosci: etykieta, jej pole i przerwa do nastepnej
# etykiety. Wydzielona z samego pomiaru, zeby arytmetyke dalo sie sprawdzic dla calego
# zakresu czcionek, a nie tylko dla tej, ktora akurat ma maszyna.
function Get-JezykSkokWiersza {
    param([int]$WysokoscPola)
    $Script:OdstepPodEtykieta + $WysokoscPola + $Script:PrzerwaWierszy
}

# POLOWA WYSOKOSCI KONTROLKI, ZAOKRAGLONA W DOL. [int] w PowerShellu zaokragla BANKIERSKO,
# a nie obcina: [int](21/2) daje 10, ale [int](23/2) daje 12. Z dwoch kontrolek stojacych
# w jednym wierszu wyzsza dostawala przez to piksel W GORE ponad wspolny srodek - i tylko
# przy niektorych wysokosciach, wiec przy jednej czcionce bylo widac, a przy innej nie.
# Tak wychodzilo pole wyszukiwania i "Szukaj" nad liste trybu. Ta sama decyzja, co przy
# $goraRamkiFlag w New-JezykForm; jedna funkcja, zeby zaokraglenie bylo wszedzie to samo.
function Get-JezykPolowaWysokosci {
    param([int]$Wysokosc)
    [int][math]::Floor($Wysokosc / 2)
}

# Srodek pierwszego wiersza okna dla pola o podanej wysokosci: gorny margines i polowa
# kontrolki. LICZONY, A NIE WPISANY - kontrolka o wysokosci $WysokoscPola zaczyna sie wtedy
# dokladnie $Script:MarginesGorny pod paskiem tytulu, przy kazdej czcionce systemu.
function Get-JezykSrodekWiersza {
    param([int]$WysokoscPola)
    $Script:MarginesGorny + (Get-JezykPolowaWysokosci $WysokoscPola)
}

# Gorna krawedz panelu bez listy wyboru: gorny margines, dwa wiersze gornego pasa (domena
# i wyszukiwanie) i przerwa pod nimi. Liczona z pomiaru z tego samego powodu, co skok
# wiersza: gdy wiersze jada w gore razem z marginesem, pietro panelu musi jechac z nimi -
# inaczej przerwa nad panelem rosnie dokladnie o tyle, o ile zwezil sie margines.
function Get-JezykPietroBezListy {
    param([int]$WysokoscPola)
    $Script:MarginesGorny + $Script:PasekDomeny + $WysokoscPola + $Script:PrzerwaWierszy
}

<#
.SYNOPSIS
    Wysokosc obszaru roboczego okna dla panelu o podanej gornej krawedzi i wysokosci.

.DESCRIPTION
    JEDNA ARYTMETYKA NA OBA WIDOKI. Kazdy z paneli ma inna gorna krawedz (konto stoi pod
    lista wyboru, komputer bez niej) i inna wysokosc, a okno konczy sie pod pasem podpisu,
    ktory lezy PRZERWE WIERSZA pod ostatnim polem - tym samym odstepem, co miedzy wierszami.
    Dotad ta liczba byla wpisana w New-JezykForm raz, dla widoku wyzszego; druga kopia dla
    drugiego widoku rozjechalaby sie przy pierwszej zmianie siatki.

    Koncowe "+ 2" to dolny margines pasa - ta sama dwojka, co przy stawianiu podpisu
    w Set-JezykWysokoscOkna.
#>
function Get-JezykWysokoscOkna {
    param([int]$GoraPanelu, [int]$WysokoscPanelu)

    $GoraPanelu + $WysokoscPanelu + $Script:PrzerwaWierszy + $Script:WysokoscPasaPodpisu + 2
}

<#
.SYNOPSIS
    Przycina wysokosc okna do obszaru roboczego ekranu.

.DESCRIPTION
    Siatka rosnie razem ze skalowaniem DPI, wiec przy 150% i ekranie 1080p okno moze nie
    zmiescic sie w obszarze roboczym - a wtedy dolne pola bylyby NIE DO OBEJRZENIA, bo
    kontrolki stoja na sztywnych wspolrzednych. Zapora dziala w parze z $form.AutoScroll:
    WinForms pokazuje pasek przewijania WYLACZNIE wtedy, gdy kontrolki wychodza poza obszar
    roboczy okna, wiec okno trzeba przyciac, zeby pasek mial sie kiedy pojawic.

    Zapas 60 px na ramke okna i pasek tytulu - ClientSize ich nie obejmuje.

    CALOSC POD TRY, bo to zabezpieczenie, a nie warunek dzialania: gdyby odczyt rozmiaru
    ekranu zawiodl, okno ma dostac wysokosc policzona z siatki. Ten sam catch przepuszcza
    zestaw weryfikacyjny, ktory typow okienkowych nie ma wcale.
#>
function Get-JezykWysokoscWEkranie {
    param([int]$Wysokosc)

    try {
        $maksWysokosc = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height - 60
        if ($maksWysokosc -gt 200 -and $Wysokosc -gt $maksWysokosc) { return $maksWysokosc }
    }
    catch { }

    $Wysokosc
}

# Wysokosc pola tekstowego przy podanej czcionce. Styk z systemem, tak jak
# Get-JezykSzerokoscStrzalki: PreferredHeight liczy WinForms z czcionki i z grubosci ramki,
# czyli dokladnie tak, jak zrobi to kazde pole zalozone przez New-JezykPole. Od tej jednej
# liczby zalezy caly rytm siatki - i wysokosc kazdego przycisku w oknie.
#
# Pole POWOLANE NA BOKU i od razu zwolnione - nie ma go w oknie i nie ma byc. Pytamy
# o miare, zanim powstanie pierwsza kontrolka, bo od niej zalezy caly rytm siatki.
function Get-JezykWysokoscPola {
    param($Czcionka)

    $pole = New-Object System.Windows.Forms.TextBox
    try {
        $pole.Font = $Czcionka
        $pole.PreferredHeight
    }
    finally { $pole.Dispose() }
}

# Wyrownuje kontrolki w PIONIE do wspolnego srodka wiersza. WinForms wylicza wysokosc listy
# rozwijanej i przycisku z czcionki, a nie z tego, co wpiszemy w Size - wspolrzedne wpisane
# recznie zgadzaja sie wiec tylko przy 100% DPI. Zamiast zgadywac liczby, pytamy kontrolki
# o ich RZECZYWISTA wysokosc.
function Set-JezykSrodekPionowy {
    param([object[]]$Kontrolki, [int]$Srodek)
    foreach ($kontrolka in $Kontrolki) {
        $kontrolka.Top = $Srodek - (Get-JezykPolowaWysokosci $kontrolka.Height)
    }
}

# Dosuwa kontrolki PRAWA krawedzia do podanej wspolrzednej. Osobna funkcja, a nie linijka
# w miejscu uzycia, z jednego powodu: zestaw weryfikacyjny nie buduje okna, wiec arytmetyke
# wyrownania da sie sprawdzic tylko wtedy, gdy mozna ja zawolac na atrapie - tak samo jak
# oba wyrownania powyzej.
function Set-JezykDoPrawej {
    param([object[]]$Kontrolki, [int]$Prawa)
    foreach ($kontrolka in $Kontrolki) {
        if ($kontrolka) { $kontrolka.Left = $Prawa - $kontrolka.Width }
    }
}

# Zsuwa kontrolki w dol tak, zeby najwyzsza z nich nie weszla na pole wiersz wyzej.
# Wszystkie o te sama liczbe, bo stoja jedna nad druga i odstep miedzy nimi ma zostac.
# Osobna funkcja z tego samego powodu, co Set-JezykDoPrawej: arytmetyke da sie wtedy
# sprawdzic na atrapie, bez budowania okna.
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

# Szerokosc przycisku LICZONA Z NAPISU, a nie wpisana. Napis rysuje
# Set-JezykRysunekNapisuPrzycisku w CALYM prostokacie kontrolki, wiec za waski przycisk
# obcina napis od boku - a 90 px, ktore starcza na "Zamknij" przy zwyklej czcionce, nie
# starcza na "Sprawdz nazwy" przy "Rozmiarze tekstu" 150%. Margines po bokach bierze sie
# z szerokosci spacji, zeby rosl razem z czcionka zamiast zostawac stala liczba pikseli.
function Get-JezykSzerokoscPrzycisku {
    param([string]$Napis, $Czcionka)

    $bezMarginesow = [System.Windows.Forms.TextFormatFlags]::NoPadding
    $pomiar = [System.Windows.Forms.TextRenderer]::MeasureText($Napis, $Czcionka,
                                                              [System.Drawing.Size]::Empty, $bezMarginesow)
    return ($pomiar.Width + 4 * (Get-JezykSzerokoscSpacji $Czcionka))
}

function Get-JezykSzerokoscSpacji {
    param($Czcionka)

    $bezMarginesow = [System.Windows.Forms.TextFormatFlags]::NoPadding
    $zSpacja = [System.Windows.Forms.TextRenderer]::MeasureText('x x', $Czcionka, [System.Drawing.Size]::Empty, $bezMarginesow)
    $bezSpacji = [System.Windows.Forms.TextRenderer]::MeasureText('xx', $Czcionka, [System.Drawing.Size]::Empty, $bezMarginesow)
    $zSpacja.Width - $bezSpacji.Width
}

<#
.SYNOPSIS
    Odstep miedzy pudelkiem znacznika a pudelkiem jego napisu: jedna spacja od konca kwadratu.

.DESCRIPTION
    NAPIS JEST OSOBNA ETYKIETA, a nie tekstem znacznika: WinForms rozklada wlasny napis
    znacznika po swojemu i odstepu od kwadratu nie da sie podac zadna wlasciwoscia - napis
    stal przez to za daleko i o piksel za nisko.

    JEDNA SPACJA, bo tak wyglada przerwa miedzy dwoma slowami - i taka przerwe operator
    zamowil. Stala -2 (napis na samym koncu kwadratu) wygladala jak przyklejona, a stala
    dodatnia zgadzalaby sie tylko przy 100%: spacja rosnie razem z rozmiarem tekstu.

    CZCIONKA NAPISU, nie okna: werdykt ma wlasna, wieksza i pogrubiona, wiec i jego spacja
    jest szersza.
#>
function Get-JezykOdstepZnacznika {
    param($Czcionka)
    (Get-JezykSzerokoscSpacji $Czcionka) - $Script:PasZaZnacznikiem
}

# Szerokosc kwadratu kryjacego przycisk listy. Wydzielona, bo SystemInformation to styk
# z systemem - pyta Windows o rozmiar elementu interfejsu, ktory przy DPI 125-150% jest
# inny. Zestaw weryfikacyjny podstawia tu wlasna liczbe i cala arytmetyka oprawy list
# wykonuje sie naprawde.
function Get-JezykSzerokoscStrzalki {
    [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + $Script:ZapasStrzalkiListy
}

<#
.SYNOPSIS
    Stawia kwadrat ze strzalka dokladnie na systemowym przycisku swojej listy rozwijanej.

.DESCRIPTION
    WSPOLRZEDNE BRANE OD LISTY, a nie wpisane: wysokosc listy WinForms wylicza z czcionki,
    wiec przy DPI 125-150% rosnie, a kwadrat wpisany na sztywno przestalby zakrywac to,
    po co powstal.

    PIKSEL ZAPASU Z GORY I Z DOLU: skrajne piksele listy sa juz obciete (patrz
    Set-JezykObciecieListy), wiec kwadrat ma stanac w jej wnetrzu, a nie na jej krawedzi.
    W prawo idzie az do krawedzi listy, bo tam zakrywa i przycisk, i kawalek obrysu.
#>
function Set-JezykStrzalkaListy {
    param($Lista, $Strzalka, [int]$Szerokosc)

    if (-not $Lista -or -not $Strzalka) { return }

    $Strzalka.Width  = $Szerokosc
    $Strzalka.Height = $Lista.Height - 2
    $Strzalka.Left   = $Lista.Left + $Lista.Width - $Szerokosc - 1
    $Strzalka.Top    = $Lista.Top + 1
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

.PARAMETER Napisy
    Etykiety stojace po prawej stronie kontrolek - po jednej na kazda. Podane, srodkuja sie
    razem ze swoja kontrolka jako JEDNA CALOSC: inaczej rzad trzech par wyszedlby krzywo,
    bo kazdy napis ma inna dlugosc, a slupek jest wspolny.

.PARAMETER Odstep
    Przerwa miedzy kontrolka a jej napisem. Ma znaczenie wylacznie razem z -Napisy.
#>
function Set-JezykSrodekWSlupkach {
    param([object[]]$Kontrolki, [int]$Lewa, [int]$Szerokosc,
          [object[]]$Napisy = @(), [int]$Odstep = 0)

    $ile = @($Kontrolki).Count
    if ($ile -eq 0 -or $Szerokosc -le 0) { return }

    $slupek = $Szerokosc / $ile

    for ($i = 0; $i -lt $ile; $i++) {
        # SZEROKOSC CALEJ PARY, a nie samej kontrolki - patrz opis parametru -Napisy.
        $napis = if ($i -lt @($Napisy).Count) { $Napisy[$i] } else { $null }
        $razem = $Kontrolki[$i].Width
        if ($napis) { $razem += $Odstep + $napis.Width }

        # Srodek slupka lezy w jego polowie, stad + 0.5. Dzielenie idzie na liczbach
        # zmiennoprzecinkowych - przy calkowitym polowka slupka znikalaby i rzad
        # przesuwalby sie w lewo o kilka pikseli.
        $srodek = $Lewa + [int]($slupek * ($i + 0.5))
        $Kontrolki[$i].Left = $srodek - [int]($razem / 2)

        if ($napis) { $napis.Left = $Kontrolki[$i].Left + $Kontrolki[$i].Width + $Odstep }
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

<#
.SYNOPSIS
    Przycina etykiete stojaca NAD swoim polem tak, zeby nie siegala jego gornej ramki.

.DESCRIPTION
    Etykieta ma AutoSize, czyli wysokosc SAMEGO TEKSTU - a ta rosnie razem z czcionka
    systemu. Pole lezy stale $Script:OdstepPodEtykieta ponizej etykiety, wiec gdy linia
    pisma przekroczy ten odstep, prostokat etykiety nachodzi na gorna krawedz pola
    i ZAKRYWA JEGO RAMKE - dokladnie na szerokosc napisu, bo tyle ma sama etykieta.
    Widac to jako ramke urwana pod "Login:" czy "Status:" i wracajaca za koncem napisu.

    Czcionke okna bierzemy z ustawien systemu (SystemFonts.MessageBoxFont), a Windows
    potrafi ja powiekszyc NIEZALEZNIE od skalowania ekranu - stad usterka takze przy
    skalowaniu 100%.

    JEDNA FUNKCJA NA OBA OKNA. Okno grup ma to samo pole "Status:" pod etykieta, co okno
    glowne, i ta sama usterka wrocila tam jako zgloszenie - druga kopia reguly rozjechalaby
    sie z pierwsza przy pierwszej zmianie odstepu.

    Etykiety, ktore juz przeszly przez Set-JezykSrodekTekstu (werdykt), maja AutoSize
    zdjete i wlasna, celowo dobrana wysokosc - tych nie ruszamy. Przy zwyklej czcionce
    etykieta sie miesci i tez zostaje nietknieta.
#>
function Set-JezykEtykietaNadPolem {
    param($Etykieta)

    $wysokoscEtykiety = $Script:OdstepPodEtykieta - 2
    if ($Etykieta.AutoSize -and $Etykieta.Height -gt $wysokoscEtykiety) {
        Set-JezykSrodekTekstu $Etykieta $wysokoscEtykiety
    }
}

# Blokada zdarzen na czas programowego wypelniania listy - patrz Set-JezykListaKont.
$Script:BlokadaZdarzen = $false

<#
.SYNOPSIS
    Nadaje kontrolce styl ramki z biezacej palety - jesli kontrolka ramke w ogole ma.

.DESCRIPTION
    RAMKI NIE DA SIE POMALOWAC, da sie tylko wybrac jej styl. Domyslny Fixed3D rysuje motyw
    systemu i nie wie nic o ciemnym tle - w ciemnym oknie kazde pole dostawalo przez to
    jasna obwodke. FixedSingle jest jednopikselowa i ciemniejsza od pola, a przy tym
    zostawia tekstowi wciecie od krawedzi, czego calkowity brak ramki juz nie robi.

    STRAZ NA ISTNIENIE WLASCIWOSCI, A NIE NA TYP KONTROLKI. Role "Lista" nosi i ListBox,
    ktory BorderStyle ma, i trzy ComboBoxy, ktore nie maja go WCALE - to nie jest
    wlasciwosc klasy Control. Pytanie o typ zamknelo by te funkcje przed zestawem
    weryfikacyjnym, ktory podstawia [pscustomobject].

    ComboBox z FlatStyle = Flat maluje swoja ramke sam i tedy sie do niej nie dosiegnie.
#>
function Set-JezykRamkeKontrolki {
    param($Kontrolka)

    if (-not $Kontrolka) { return }
    if (-not $Kontrolka.PSObject.Properties['BorderStyle']) { return }

    $Kontrolka.BorderStyle = $Script:Config.RamkaPola
}

<#
.SYNOPSIS
    Zdejmuje z listy rozwijanej tyle pikseli krawedzi, ile kaze paleta.

.DESCRIPTION
    RAMKI LISTY NIE DA SIE ANI POMALOWAC, ANI WYBRAC JEJ STYLU. ComboBox nie ma
    wlasciwosci BorderStyle wcale, a przy FlatStyle = Flat WinForms rysuje obrys na sztywno
    kolorem SystemColors.Window - czyli bialym. W jasnym oknie bialy obrys przy bialym polu
    jest niewidoczny, w ciemnym zostaje obwodka doklejona do ciemnej kontrolki.

    Zostaje jedyne narzedzie, ktore dziala na KAZDA ramke: obciecie. Kontrolka o zwezonym
    obszarze skrajnych pikseli nie rysuje wcale, wiec zamiast obrysu widac pod nimi tlo
    okna. Ile ich zdjac, mowi paleta - w jasnym motywie zero, bo tam nie ma czego poprawiac.

    STRAZ NA DropDownStyle, A NIE NA TYP KONTROLKI. Role "Lista" nosi takze ListBox okna
    grup, ktory ramke ma zwyczajna i obcinac go nie ma po co. Pytamy o wlasciwosc, nie
    o typ - z tego samego powodu, co przy Set-JezykRamkeKontrolki wyzej.
#>
function Set-JezykObciecieListy {
    param($Kontrolka)

    if (-not $Kontrolka) { return }
    if (-not $Kontrolka.PSObject.Properties['DropDownStyle']) { return }

    $ile = [int]$Script:Config.ObciecieListy

    # POWROT DO JASNEGO MOTYWU MUSI OBCIECIE ZDJAC, a nie tylko go nie nakladac - inaczej
    # lista zostalaby zwezona na zawsze po pierwszym pobycie w ciemnym.
    if ($ile -le 0) {
        $Kontrolka.Region = $null
        return
    }

    $Kontrolka.Region = New-JezykObszar $ile $ile `
                                        ($Kontrolka.Width  - 2 * $ile) `
                                        ($Kontrolka.Height - 2 * $ile)
}

<#
.SYNOPSIS
    Maluje kontrolke wedlug jej ROLI w oknie, kolorami z biezacej palety.

.DESCRIPTION
    JEDNO MIEJSCE Z REGULAMI KOLORU, wolane dwa razy w zyciu kazdej kontrolki: przy budowie
    okna i przy kazdym przelaczeniu motywu. Dwie kopie tych regul rozjechalyby sie przy
    pierwszej zmianie, a rozjazd widac dopiero po powrocie z ciemnego motywu do jasnego.

    ROLA, A NIE TYP KONTROLKI. Rozpoznawanie po [System.Windows.Forms.Button] zamykaloby te
    funkcje przed zestawem weryfikacyjnym - ten podstawia [pscustomobject], wiec zaden
    warunek na typ nie bylby w nim prawdziwy i petla malujaca nie wykonalaby sie ani razu.
    To ta sama zasada, co przy czytaniu pol wyjatku przez PSObject.Properties.

    -REJESTRUJ PODAJE WYLACZNIE New-JezykForm. Okno "Grupy AD" wola te same role bez niego:
    jego kontrolki gina razem z oknem w finally { Dispose() }, a zarejestrowane zostawialyby
    w $Script:KontrolkiMotywu martwe uchwyty, przybywajace po jednym komplecie na otwarcie.

    Rejestr jest TABLICA kontrolka -> rola, a nie lista na kazda role: cztery niebieskie
    przyciski "!" rodza sie czerwone i dopiero potem dostaja swoj kolor, wiec druga
    rejestracja ma ZASTAPIC pierwsza. W liscie zostalyby w obu i kolor zalezalby od
    kolejnosci przemalowania.

    Kolor NIESIONY PRZEZ TRESC (werdykt, wygasle haslo, dostepnosc maszyny) nie nalezy do
    zadnej roli - ustawia go Set-JezykKolorPola i to on ma ostatnie slowo, bo Set-JezykMotyw
    odtwarza role kolorow PO rolach wygladu.

    Przygaszony napis podpisu ("Autor:", "Wersja:") nalezy tu, a nie tam: jest WYGLADEM
    - nie zmienia sie ze stanem niczego i niczego nie znaczy.
#>
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
            # Tlo JAWNIE, bo pole ReadOnly bez tego rysuje sie na kolorze tla okna
            # i wyglada jak nieczynne - i dlatego, ze pole moze wracac ze stanu, w ktorym
            # Set-JezykKolorPola pomalowal mu tlo. Kolor tekstu jawnie z tego samego powodu.
            $Kontrolka.BackColor = $Script:Config.KolorTla
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            Set-JezykRamkeKontrolki $Kontrolka
        }
        'Podpis' {
            # Napis lezy na tle okna i ma byc przygaszony wzgledem wszystkiego, co w oknie
            # cos znaczy.
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
            # Tlo okna, zeby ikonka siedziala w nim jak wpisana, a nie jak naklejka.
            # Rysunek bierze kolor z palety przy KAZDYM przerysowaniu, wiec po zmianie
            # motywu trzeba o nie poprosic - zmiana BackColor sama zdarzenia Paint nie
            # wywoluje. BEZ FlatAppearance: te sama role dostaje takze PictureBox, ktory
            # tego pola nie ma.
            $Kontrolka.BackColor = $Script:Config.KolorOkna
            $Kontrolka.ForeColor = $Script:Config.KolorTekstu
            $Kontrolka.Invalidate()
        }
        'StrzalkaListy' {
            # Kwadrat ze strzalka domalowany na wierzchu listy rozwijanej. Tlo ma WLASNY
            # klucz palety, a nie KolorKontrolki: w jasnym motywie ma zostac dokladnie
            # systemowe, bo tam przycisk listy wyglada dobrze i nie po to go zakrywamy.
            # Invalidate z tego samego powodu, co przy ikonce motywu: rysunek bierze kolor
            # przy kazdym przerysowaniu, a zmiana BackColor sama go nie zamawia.
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
    Set-JezykWyglad $txt 'Pole' -Rejestruj
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
    Kwadrat ze strzalka, ktory zakrywa systemowy przycisk listy rozwijanej.

.DESCRIPTION
    ETYKIETA, A NIE PRZYCISK: ma wylacznie przyjac klikniecie i dac sie pomalowac, a
    przycisk dokladalby do tego wlasna ramke i wlasny stan wcisniecia. Rysunek powstaje
    w Set-JezykRysunekStrzalkiListy, wspolrzedne - w Set-JezykStrzalkaListy.
#>
function New-JezykStrzalkaListy {
    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $false
    $lbl.Text     = ''
    Set-JezykWyglad $lbl 'StrzalkaListy' -Rejestruj
    $lbl
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
    # -BezRejestracji dla okna budowanego NA ZADANIE: zarejestrowana kontrolka zostaje
    # w $Script:KontrolkiMotywu po Dispose() i pierwsze przelaczenie motywu probuje
    # pomalowac martwy uchwyt.
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

    # Bez wyzerowanych marginesow wewnetrznych wykrzyknik nie miesci sie w kwadracie 18 px
    # i rysuje sie uciety od dolu.
    $btn.Padding = [System.Windows.Forms.Padding]::new(0)
    $btn.Margin  = [System.Windows.Forms.Padding]::new(0)
    $btn
}

<#
.SYNOPSIS
    Stawia przycisk "!" w linii etykiety pola - prawa krawedzia na jego WIDOCZNEJ krawedzi.

.DESCRIPTION
    POZIOM Z POLA, NIE Z ETYKIETY. Przycisk stal dawniej tuz za napisem, wiec kazdy
    wykrzyknik w oknie konczyl sie gdzie indziej - tam, gdzie akurat konczyl sie tekst
    jego etykiety, a ten rosnie z czcionka systemu. Koniec pola jest staly i wspolny dla
    etykiety i pola, wiec wykrzyknik wyglada na czesc wiersza, a nie na dopisek do napisu.

    Cena jest swiadoma: przy duzym tekscie wykrzyknik wchodzi na koniec dlugiej etykiety
    ("Ostatnio uzywany komputer:" od okolo 125% DPI). Dlatego przyciski "!" leza w oknie
    NAD etykietami (SetChildIndex w New-JezykForm) - przyciety ogon slowa da sie
    przeczytac, zakryty przycisk przestaje istniec.

    PION LICZONY Z CZCIONKI, NIE Z $Etykieta.Height. Etykiety, przy ktorych stoi ten
    przycisk, MAJA WLACZONE AutoSize (nie przeszly przez Set-JezykSrodekTekstu - to wciaz
    zwykle pola siatki, tylko z dodatkowym przyciskiem obok) - ich Height to zmierzona
    wysokosc jednowierszowego tekstu, ktora bywa o kilka pikseli inna niz staly bok
    przycisku (18 px), i to niedopasowanie bylo widac jako krzywy wykrzyknik. Font.GetHeight
    daje stabilna, przewidywalna wysokosc linii - ta sama technika juz sprawdzona przy
    liczeniu wysokosci checkboxow (patrz $wysokoscZnacznika nizej w tym pliku).
#>
function Set-JezykPrzyciskPrzyEtykiecie {
    param($Przycisk, $Etykieta, $Pole)

    if (-not $Przycisk -or -not $Etykieta -or -not $Pole) { return }

    $wysokoscLinii = [int][math]::Ceiling($Etykieta.Font.GetHeight())

    $Przycisk.Left = $Pole.Left + $Pole.Width - $Script:CofniecieWykrzyknika - $Przycisk.Width
    $Przycisk.Top  = $Etykieta.Top + [int](($wysokoscLinii - $Przycisk.Height) / 2)
}

<#
.SYNOPSIS
    Nadaje oknu wysokosc pokazanego panelu i stawia pod nim pas podpisu.

.DESCRIPTION
    OKNO KONCZY SIE POD TYM PANELEM, KTORY WIDAC. Dotad rozmiar byl staly i wymierzony
    widokiem wyzszym, czyli kontem - w trybie komputera zostawalo pod polem "Status:"
    kilkaset pikseli pustki, a podpis autora stal oderwany na samym dole.

    RUSZAMY WYLACZNIE ClientSize, nigdy Location: gorna krawedz okna ma zostac tam, gdzie
    byla, wiec przy zmianie trybu jedzie sama dolna. Inaczej pasek tytulu i oba gorne
    wiersze skakalyby po ekranie przy kazdym przelaczeniu.

    PAS PODPISU JEDZIE RAZEM Z DOLEM. Lezy POZA panelami, wiec widac go w obu trybach -
    i w obu ma lezec dokladnie $Script:PrzerwaWierszy pod ostatnim polem. Jego pion liczy
    sie TUTAJ i tylko tutaj: druga kopia wzoru rozjechalaby sie przy pierwszej zmianie
    wysokosci pasa, a rozjazd o kilka pikseli na dole okna jest dokladnie tym, czego nikt
    nie zauwazy w kodzie.

    PODPIS LICZY SIE Z WYSOKOSCI NIEPRZYCIETEJ, a przyciecie do ekranu dotyczy samego
    okna: przy oknie wyzszym od ekranu pas ma zostac pod panelem i dac sie doscrollowac,
    a nie wskoczyc na pole "Status:".
#>
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

# Wiersze obu paneli zasilane przez SCCM - opis zaklada New-JezykForm, patrz
# Set-JezykUkladSccm. Uklad startowy jest PELNY, bo tak panele buduje New-JezykForm.
$Script:WierszeSccm      = @()
$Script:UkladBezSccm     = $false
# Pary "kontrolka + wlasciwosc + o ile pojechala" - powrot cofa dokladnie te liczby.
$Script:PrzesunieciaSccm = @()

<#
.SYNOPSIS
    Chowa wiersze zasilane przez SCCM i zsuwa pod nimi reszte panelu - albo cofa to co do piksela.

.DESCRIPTION
    DOMENA DECYDUJE, a nie wynik wyszukania: poza domenami z DomenyZSccm te pola nie
    wypelnia sie NIGDY, dopoki ktos nie zmieni konfiguracji - ta sama zasada, co przy
    "Odblokuj konto". Pusty wiersz w srodku panelu wygladalby jak nieudany odczyt, wiec
    reszta panelu jedzie w gore, a okno kurczy sie razem z nim: Set-JezykWidok czyta
    wysokosc panelu PO tej funkcji.

    KAZDA KONTROLKA PANELU, A NIE LISTA. Jedzie o tyle skokow wiersza, ile usunietych
    wierszy lezy nad nia. Lista przesuwanych kontrolek rozjechalaby sie przy pierwszym
    nowym polu - zapomniane zostaloby na starym miejscu i weszlo na sasiada, bez zadnego
    komunikatu.

    PROGIEM JEST POLE USUNIETEGO WIERSZA. Wszystko z wierszy ponizej lezy nizej niz ono -
    takze przycisk "!", ktory stoi do dwoch pikseli NAD swoja etykieta
    (Set-JezykPrzyciskPrzyEtykiecie) - a wszystko z wierszy powyzej lezy wyzej, bo skok to
    etykieta, pole i przerwa.

    PRZESUNIECIA ZAPISANE, A NIE LICZONE DRUGI RAZ. Powrot odejmuje dokladnie to, co dodalo
    zsuniecie - dzieki temu sklada sie z poprawka motywu (Set-JezykWyrownaniePol), ktora
    takze przesuwa pola, a kolejne przelaczenia domeny wracaja na te same liczby, zamiast
    je sumowac. Z tego samego powodu progi sa czytane z BIEZACEGO Top pol, a nie z siatki.

    WRACA WIDOCZNOSC TYLKO STALYCH. Etykiety, pola i "Pinguj" sa widoczne zawsze, gdy jest
    ich wiersz. Przyciski "!", "Polacz" i "Dyski" maja wlasnych wlascicieli (Set-JezykInfo,
    Set-JezykPrzyciskiZdalne) i zostaja schowane: pokazane tutaj zapalilyby sie bez
    powodu, a Clear-JezykKonto i Clear-JezykKomputer ustawily je przed chwila tak, jak trzeba.

    Bez zmiany stanu nie robi nic - Set-JezykWidok wola ja przy KAZDEJ zmianie trybu.
#>
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

    # WIERSZE SCCM PRZED WYSOKOSCIA OKNA - zsuniecie zmienia wysokosc paneli, a ta jest
    # czytana nizej wprost z kontrolki. Zmiana domeny idzie wlasnie tedy, wiec innego
    # miejsca, ktore by uklad przeliczalo, nie ma. Po obu Clear-: przyciski, ktorych ta
    # funkcja nie pokazuje, maja juz stan wlasciwy dla pustego widoku.
    Set-JezykUkladSccm (Test-JezykDomenaZSccm $Script:Config.Domena)

    $gora = if ($zListą) { $Script:PanelZListą } else { $Script:PanelBezListy }

    $k.PanelKonto.Visible    = (-not $komputer)
    $k.PanelKomputer.Visible = $komputer

    # PANEL I WYSOKOSC OKNA RAZEM. Panel komputera ma trzy wiersze mniej niz panel konta
    # i stoi o pas listy wyboru wyzej, wiec okno wymierzone kontem zostawialo pod nim
    # kilkaset pikseli pustki. Wysokosc bierzemy z KONTROLKI panelu, a nie liczymy drugi
    # raz z wierszy - obie dostaly ja w New-JezykForm z tej samej siatki, a druga kopia
    # arytmetyki rozjechalaby sie przy dolozeniu pola.
    if ($komputer) {
        $k.PanelKomputer.Location = [System.Drawing.Point]::new(0, $gora)
        Set-JezykWysokoscOkna $gora $k.PanelKomputer.Height
    } else {
        $k.PanelKonto.Location = [System.Drawing.Point]::new(0, $gora)
        Set-JezykWysokoscOkna $gora $k.PanelKonto.Height
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
# SZESC ZADAN, NIE JEDNO, i kazde z wlasnym LICZNIKIEM POKOLEN. Liczone razem oddawaly wynik
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
#
# SZOSTE ZADANIE - POLACZENIE Z UDZIALEM DYSKOWYM - jest jedyne, ktorego odpowiedz potrafi
# WROCIC PO WIECEJ: gdy poswiadczenia operatora nie wystarczaja, okno pyta o konto oknem
# systemowym, a to rysuje sie wylacznie na watku interfejsu. W tle idzie wiec sama proba
# cicha - i tylko po to, zeby okno nie stalo przez cala rozmowe z serwerem.
$Script:PokolenieLogowania  = 0
$Script:PokolenieKomputera  = 0
$Script:PokolenieUzytkownika = 0
$Script:PokoleniePingu      = 0
$Script:PokolenieNumeru     = 0
$Script:PokolenieDysku      = 0
$Script:ZadanieLogowania    = $null
$Script:ZadanieKomputera    = $null
$Script:ZadanieUzytkownika  = $null
$Script:ZadaniePingu        = $null
$Script:ZadanieNumeru       = $null
$Script:ZadanieDysku        = $null
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

# Czy trzy pola czekajace na odpowiedz SCCM - "Ostatnio uzywany komputer", "Adres IP"
# i "Adres MAC" - niosa w tej chwili NOTKE O TRWAJACYM zapytaniu, a nie odpowiedz. Po samej
# tresci pola tego nie poznasz: "sprawdzanie" wyglada jak kazdy inny napis, a zostawione po
# zakonczonej pracy klamie dokladnie tak samo jak zdanie nieprawdziwe, tylko odwrotnie
# w czasie. Marker gasi KAZDA galaz, ktora odpowiedz moze wyjsc - patrz
# Set-JezykNotkeSprawdzania w Jezyk-3-Widok.ps1.
$Script:PolaCzekajaNaSccm   = $false

# To samo dla pola "Ostatnie logowanie", ktore czeka na WLASNE, niezalezne zadanie i konczy
# je w innej chwili niz zapytanie do SCCM. Jeden wspolny marker gasilby napis nad praca,
# ktora jeszcze trwa - albo zostawialby go nad ta, ktora juz sie skonczyla.
$Script:PoleCzekaNaLogowanie = $false

# Czy pole "Status:" widoku komputera niesie w tej chwili NOTKE O TRWAJACYM laczeniu
# z udzialem dyskowym, a nie odpowiedz. Powod jest ten sam, co przy dwoch markerach wyzej:
# po samej tresci pola tego nie poznasz, a notka zostawiona po zakonczonej pracy klamie
# dokladnie tak samo, jak zdanie nieprawdziwe - tylko odwrotnie w czasie.
$Script:StatusCzekaNaDysk    = $false

# Zdanie, ktore stalo w polu "Status:", ZANIM notka je zakryla. Potrzebne tylko na jednej
# drodze - rezygnacji z okna poswiadczen: powodzenie i niepowodzenie maja wlasne komunikaty,
# wiec zastepuja notke odpowiedzia i nie maja czego przywracac. Rezygnacja nie ma nic do
# powiedzenia i pole musi wrocic tam, gdzie bylo, zamiast zostac z kropkami na zawsze.
$Script:StatusPrzedLaczeniem = ''

# Numer klatki animacji kropek - WSPOLNY dla obu notek, zeby kropki szly w oknie rownym
# krokiem. Trzymany osobno od markerow, bo zegar podbija go w innym miejscu, niz notka
# sie zapala.
$Script:KlatkaKropek        = 0

# Ile TAKTOW ZEGARA przypada na jedna klatke kropek. Zegar tla budzi sie co 250 ms, a kropki
# maja zmieniac sie co 500: cztery zmiany na sekunde czytaja sie jak migotanie, a nie jak
# trwajaca praca.
$Script:TaktowNaKlatkeKropek = 2

# Nazwa maszyny pokazanej w oknie - jedyne zrodlo prawdy dla przyciskow "Pinguj" i "Polacz".
# Pole tekstowe niesie ja razem z data, wiec nie nadaje sie do przeniesienia stanu.
# WSPOLNA DLA OBU WIDOKOW i tak ma zostac: panele nigdy nie sa widoczne naraz, a zmiana
# trybu czysci oba. W widoku konta maszyne podaje SCCM, w widoku komputera - Active
# Directory, i to jedyna roznica.
$Script:OstatniKomputer = ''

# Ktory widok zamowil sonde z przycisku "Pinguj". Wynik wraca osobnym zadaniem po sekundach
# i nie ma na sobie zadnego sladu po tym, skad przyszedl - a obie polowki okna maja wlasne
# pola adresu. Odczytanie tego z listy trybu byloby zgadywaniem: tryb da sie przestawic,
# zanim odpowiedz wroci.
$Script:WidokSondy = 'Konto'

# Adres IP, do ktorego dopasowano pokazany adres MAC. Bez niego ponowny ping nie mialby
# jak zauwazyc, ze maszyna odpowiada juz spod innego adresu - a wtedy pokazany MAC
# opisuje karte, ktorej pod tym adresem nie ma.
$Script:MacDlaAdresu = ''

# Ostatnia odpowiedz sondy dla POKAZANEJ maszyny - zrodlo prawdy dla przyciskow "Polacz"
# i "Dyski". Dotad wynik sondy zyl wylacznie w kolorze kontrolki, a kolor nie nadaje sie
# na warunek: przechowuje go rejestr rol i odtwarza go motyw.
#
# TROJSTANOWA I TAK MA ZOSTAC. $false znaczy "nazwa rozpoznana, ale maszyna milczy",
# a $null - "nie wiadomo"; splaszczenie do [bool] zamienilo by drugie w pierwsze.
# Obie akcje zdalne wymagaja jednak POTWIERDZONEJ odpowiedzi, wiec gasna tak samo przy
# $false i przy $null - patrz Set-JezykPrzyciskiZdalne.
#
# WSPOLNA DLA OBU WIDOKOW, jak $Script:OstatniKomputer: panele nigdy nie sa widoczne
# naraz, a zmiana trybu czysci oba.
$Script:MaszynaOdpowiada = $null

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
    param([ValidateSet('Logowanie', 'Komputer', 'Uzytkownik', 'Ping', 'Numer', 'Dysk')][string]$Zadanie)

    if ($Script:SkryptyTla.ContainsKey($Zadanie)) { return $Script:SkryptyTla[$Zadanie] }

    # KOMPLET zaleznosci obu zapytan do SCCM, policzony z ich tresci, a nie z pamieci.
    # Oba wchodza tam ta sama droga (sonda portu, sesja, zapytanie z droga zapasowa,
    # klasyfikacja bledu, przeliczenie czasu) i roznia sie WYLACZNIE funkcja wejsciowa,
    # wiec lista jest jedna - dwie kopie rozjechalyby sie przy pierwszej zmianie. Na tej samej
    # liscie stoi komplet dopasowania karty sieciowej: oba zapytania konczy Set-JezykMacWWyniku,
    # a ono siega po cale domkniecie - az do arytmetyki maski.
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
        $funkcje = 'Test-JezykNazwaHosta', 'Get-JezykAdresyDoSondy', 'Get-JezykPingKomputera'

        $naglowek  = 'param($Netbios)'
        $wywolanie = 'Get-JezykPingKomputera -Nazwa $Netbios'
    }
    elseif ($Zadanie -eq 'Dysk') {
        # PROBA CICHA POLACZENIA Z UDZIALEM - bez pytania o konto, wiec nie ma tu czego
        # rysowac i cala rozmowa z serwerem moze isc w tle. O to w tym zadaniu chodzi:
        # dotad szla przez ShellExecute na watku interfejsu i okno stalo.
        #
        # Odpowiedz "potrzeba poswiadczen" wraca STAD NA WATEK INTERFEJSU i dopiero tam
        # pada pytanie o konto - systemowe okno poswiadczen potrzebuje rodzica i petli
        # komunikatow, a przestrzen w tle nie ma ani jednego, ani drugiego.
        $funkcje = 'Test-JezykNazwaKonta', 'Get-JezykSciezkaUdzialu',
                   'Get-JezykStanPolaczeniaUdzialu', 'Invoke-JezykPolaczenieUdzialu',
                   'Connect-JezykUdzialDysku'

        $naglowek  = 'param($Netbios, $Litera)'
        $wywolanie = 'Connect-JezykUdzialDysku -Netbios $Netbios -Litera $Litera'
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
        # Wejsciem jest droga ODWROTNA: OD MASZYNY DO UZYTKOWNIKA.
        # Sonda i dopasowanie karty sieciowej jada w tym samym zadaniu, tak samo jak po
        # drugiej stronie okna - Test-JezykNazwaHosta jest juz w $sccm.
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
    # Bez loginu zadanie nie ruszy WCALE, wiec notka o trwajacym precyzowaniu daty mrugalaby
    # nad praca, ktorej nikt nie zaczal. Pole wraca do samej daty przyblizonej.
    if (-not $Login) { Set-JezykPoleLogowaniaBezTla; return }

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
    # Jak wyzej: bez loginu nie ma o co pytac SCCM, a zapalona notka mrugalaby bez konca.
    if (-not $Login) { Set-JezykPoleKomputeraBezTla -Blad ''; return }

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
        # Ksztalt CALY, razem z polami sondy - renderer jest jeden i czyta je wszystkie.
        # Sonda odbedzie sie osobnym zadaniem, bo ICMP nie potrzebuje SCCM; tu oddajemy
        # tylko "nie sprawdzono", zeby pola nie zostaly z poprzedniego wyszukania.
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

<#
.SYNOPSIS
    Uruchamia w tle ciche polaczenie z udzialem dyskowym maszyny.

.DESCRIPTION
    SZOSTE ZADANIE i jedyne, ktore nalezy do KLIKNIECIA - nie do pokazanego konta ani do
    wyszukiwania. Wlasny licznik pokolen jest i tak konieczny: operator klika "Dyski" drugi
    raz (choćby po to, zeby wybrac inna litere), a odpowiedz na pierwsza probe potrafi dojsc
    juz po tym i otworzylaby udzial, ktorego nikt juz nie chce.

    ODPOWIEDZ BYWA POL-ODPOWIEDZIA: "potrzeba poswiadczen" znaczy, ze pytanie trzeba zadac
    jeszcze raz, tyle ze z watku interfejsu i oknem systemowym - patrz Update-JezykDyskWTle.
#>
function Start-JezykZadanieDysku {
    param([string]$Netbios, [string]$Litera)

    Stop-JezykZadanieDysku

    # Bez maszyny albo bez litery zadanie nie ruszy WCALE, wiec notka o trwajacym laczeniu
    # migalaby nad praca, ktorej nikt nie zaczal.
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
        # Nieudane URUCHOMIENIE to awaria tej drogi, a nie odmowa serwera. Idzie ta sama
        # droga powrotu co odpowiedz, bo notke trzeba zgasic tak czy owak - zostawiona
        # migalaby kropkami nad niczym do konca zycia okna.
        Update-JezykDyskWTle -Wynik ([pscustomobject]@{
            Stan = 'Blad'; Kod = $null; Sciezka = ''
            Komunikat = 'Nie udało się zacząć łączenia z udziałem.'
            Szczegoly = $_.Exception.Message })
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
    Odbiera odpowiedz cichej proby polaczenia z udzialem.

.DESCRIPTION
    ZADANIE ZDEJMUJEMY Z REJESTRU PRZED RENDEROWANIEM, inaczej niz w pozostalych pieciu -
    i to nie jest kosmetyka. Ta odpowiedz potrafi postawic MODALNE okno poswiadczen, a ono
    pompuje komunikaty watku, w tym takt zegara tla. Drugi takt wszedlby wiec tutaj jeszcze
    raz, zawolal EndInvoke po raz kolejny na tym samym uchwycie i postawil DRUGIE okno
    poswiadczen nad pierwszym. Zdjete z rejestru zadanie nie ma jak wpasc w ten cykl.

    Wynik z niezgodnego pokolenia odrzucamy tak samo jak wszedzie - dotyczylby litery albo
    maszyny, ktorej operator juz nie wybral. NOTKI WTEDY NIE GASIMY: nalezy juz do zadania,
    ktore biegnie, a nie do tego, ktore wlasnie wrocilo.
#>
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

    # PUSTA ODPOWIEDZ TEZ JEST ODPOWIEDZIA. Zadanie, ktore nie oddalo nic, zostawiloby
    # migajaca notke nad praca, ktora sie skonczyla - a operator czyta to pole raz.
    if ($null -eq $wynik) {
        $wynik = [pscustomobject]@{
            Stan = 'Blad'; Kod = $null; Sciezka = ''
            Komunikat = 'Łączenie z udziałem nie dało odpowiedzi.'
            Szczegoly = 'Zadanie w tle zakończyło się, nie oddając wyniku.' }
    }

    Update-JezykDyskWTle -Wynik $wynik
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

function Stop-JezykZadanieDysku {
    if (-not $Script:ZadanieDysku) { return }
    $zadanie = $Script:ZadanieDysku
    $Script:ZadanieDysku = $null
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
    Stop-JezykZadanieDysku

    # Ostatnie podejscie do porzuconych; reszta odchodzi razem z procesem.
    Clear-JezykZadaniaPorzucone

    if ($Script:ZegarTla) { $Script:ZegarTla.Stop() }
}

<#
.SYNOPSIS
    Sklada tytul okna grup: podpis konta i licznik pozycji.

.DESCRIPTION
    JEDNO MIEJSCE, bo tytul powstaje dwa razy - przy budowie okna i po kazdym znaku wpisanym
    do pola filtra. Dwa miejsca skladajace ten sam napis rozjechalyby sie przy pierwszej zmianie.

    Licznik ma dwie postaci celowo. Przy pelnej liscie sama liczba odpowiada na pytanie "do ilu
    grup nalezy to konto"; przy zawezonej dopiero "X z Y" mowi, ze reszta nie znikla, tylko jest
    odfiltrowana - bez tego zawezona lista wygladalaby jak konto o trzech grupach.
#>
function Get-JezykTytulGrup {
    param([string]$Podpis, [int]$Ile, [int]$Wszystkich)

    # Napisy skladamy do zmiennych, a nie w argumencie metody: w wywolaniu metody przecinki
    # naleza do listy argumentow METODY, wiec operator -f dostalby tylko pierwsza wartosc.
    $licznik = if ($Ile -eq $Wszystkich) { [string]$Wszystkich }
               else                      { '{0} z {1}' -f $Ile, $Wszystkich }

    $tytul = 'Jeżyk - Grupy AD: {0} ({1})' -f $Podpis, $licznik
    return $tytul
}

<#
.SYNOPSIS
    Wybiera grupy pasujace do wpisanego fragmentu nazwy i numeruje je do pokazania na liscie.

.DESCRIPTION
    DOPASOWANIE PRZEZ IndexOf, A NIE PRZEZ -like. Operator wpisuje TEKST, nie wzorzec: w -like
    znaki '*', '?' i '[' z pola filtra bylyby wieloznacznikami, wiec sama gwiazdka pokazywalaby
    komplet, a nawias kwadratowy nie pokazywalby nic i wygladaloby to na zgubione grupy.
    OrdinalIgnoreCase odpowiada przy tym na pytanie operatora ("czy ten ciag znakow w niej jest"),
    a nie na pytanie o kolejnosc alfabetu.

    FRAGMENT W DOWOLNYM MIEJSCU, a nie od poczatku nazwy. Nazwy grup zaczynaja sie od przedrostka
    typu "GG_" albo "DL_", ktorego nikt nie chce przepisywac, zeby dojsc do slowa niosacego sens.

    ODDAJE PARY, A NIE GOTOWE NAPISY - i to jest tu rzecz najwazniejsza. Okno usuwa konto
    z grupy ZAZNACZONEJ NA LISCIE, czyli odwzorowuje numer pozycji na grupe; gdyby ta funkcja
    oddawala same napisy, wolajacy musialby odtworzyc to odwzorowanie drugi raz i przy
    pierwszej zmianie filtra usunieto by konto z INNEJ grupy niz zaznaczona. Numeracja stoi
    osobno, w Get-JezykWierszeGrup, i jedzie po TEJ SAMEJ tablicy.

    ODSIEW PUSTYCH I NORMALIZACJA STOJA TUTAJ, a nie u wolajacego: Get-JezykParyGrup przyjmuje
    i pary, i same nazwy, wiec ta sama droga obsluguje liste grup konta i trafienia z AD.
    @($null) to w PowerShellu tablica JEDNOELEMENTOWA, wiec pusty wpis dokladalby do listy
    ponumerowany, pusty wiersz.
#>
function Select-JezykGrupyDoPokazania {
    param([object[]]$Grupy, [string]$Fraza)

    # JEDNA PISOWNIA - patrz Weryfikacja/spojnosc.ps1: $fraza i $Fraza to ta sama zmienna.
    $Fraza = ([string]$Fraza).Trim()
    $wynik = @()

    foreach ($grupa in @(Get-JezykParyGrup $Grupy)) {
        # PO NAZWIE, A NIE PO PODPISIE: grupy o tej samej nazwie zostaja albo znikaja RAZEM,
        # wiec zawezenie nie zostawi jednej bez drugiej, a folder z podpisu trafieniem nie jest.
        $nazwa = [string]$grupa.Nazwa
        if ($Fraza -and ($nazwa.IndexOf($Fraza, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)) {
            continue
        }
        $wynik += $grupa
    }

    # NAWIASY TU NIE WYSTARCZA I NIE MOGA WYSTARCZYC. PowerShell ROZWIJA tablice w wyniku, wiec
    # przy zerze trafien nie wyjdzie stad nic (i @() u wolajacego da Count 0), a przy jednym -
    # sam obiekt. Owiniecie @() musi stac na miejscu wywolania.
    return @($wynik)
}

# NUMERACJA W JEDNYM MIEJSCU. Widoczne pozycje zawsze ida 1, 2, 3..., wiec ostatni numer jest
# od razu liczba trafien; numer z pelnej listy nie powiedzialby nic komus, kto tej pelnej listy
# juz nie widzi. Funkcja jest wspolna dla listy grup konta i dla okna wyboru grupy - druga
# kopia numerowania rozjechalaby sie z pierwsza, a widac to dopiero na zawezonej liscie.
#
# KOLEJNOSC MUSI BYC TA SAMA, CO W TABLICY PODANEJ NA WEJSCIU: to po niej okno odnajduje
# zaznaczona grupe (Get-JezykZaznaczonaGrupe), wiec przestawienie wierszy znaczy usuniecie
# konta z innej grupy niz ta, ktora operator zobaczyl.
#
# WIERSZ NIESIE PODPIS, A NIE SAMA NAZWE (Get-JezykPodpisyGrup): dwie grupy o tej samej
# nazwie z dwoch OU dostaja w nim folder AD. Bez tego to dwa identyczne wiersze, a wybor
# jednego z nich - zgadywanie, ktore konczy sie zapisem w nie tej grupie.
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

<#
.SYNOPSIS
    Liczy nowy pierwszy widoczny wiersz listy po ruchu kolkiem myszy.

.DESCRIPTION
    Sama arytmetyka, bez kontrolki - dzieki temu da sie ja zawolac w zestawie weryfikacyjnym,
    ktory okna nie buduje.

    KROK JEST STALY I WLASNY. Lista pozostawiona sama sobie przewija tyle wierszy, ile mowi
    ustawienie Windows "Przewin o:", a przy wartosci "jeden ekran naraz" system oddaje -1
    i jedno klikniecie kolka przerzuca CALA strone. Stad wrazenie, ze lista sie rozpedza
    i nie da sie zatrzymac na wlasciwej pozycji.

    [Math]::Truncate, A NIE SAMO [int]: [int] w PowerShellu zaokragla (bankiersko), wiec
    [int](60/120) dalo by 1 zamiast 0, a [int](-60/120) - 0 zamiast -1.

    Delta DODATNIA to ruch kolka od siebie, czyli patrzenie WYZEJ - numer pierwszego wiersza maleje.
#>
function Get-JezykNowyWierszListy {
    param([int]$Gora, [int]$Delta, [int]$Ile, [int]$Widoczne, [int]$WierszeNaObrot = 3)

    if ($Delta -eq 0) { return $Gora }

    $obroty = [int][Math]::Truncate($Delta / 120)
    # Kolko o drobniejszym skoku oddaje mniej niz pelne 120 na jedno zdarzenie. Bez tej linii
    # lista stalaby w miejscu az do uzbierania calego obrotu, czyli wygladalaby na zawieszona.
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

<#
.SYNOPSIS
    Przewija liste kolkiem myszy wlasnym, stalym krokiem. Procedura zdarzenia MouseWheel.

.DESCRIPTION
    Handled USTAWIAMY PRZEZ PSObject.Properties, a nie po sprawdzeniu typu zdarzenia: zestaw
    weryfikacyjny wola te funkcje na atrapie, bez WinForms, a odwolanie do typu zamkneloby ja
    przed nim. Wzor: Get-JezykOpisBleduWmi.

    Bez Handled obsluga wlasna nie ZASTEPUJE domyslnej, tylko sie z nia DODAJE - lista skacze
    wtedy dalej niz przedtem, czyli poprawka pogarsza dokladnie to, co miala naprawic.
#>
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

<#
.SYNOPSIS
    Nadaje liscie wysokosc z calych wierszy, zanim ktokolwiek zmierzy sie od jej dolu.

.DESCRIPTION
    IntegralHeight PRZYCINA LISTE DOPIERO PRZY TWORZENIU UCHWYTU, a wspolrzedne okna grup
    licza sie wczesniej. Wiersz pod lista liczyl sie wiec od wysokosci ZAMOWIONEJ, a lista
    kurczyla sie potem o ulamek wiersza - i o tyle rosla szpara pod nia, bez zadnego
    komunikatu. Wrocilo to jako zgloszenie "za duzo miejsca miedzy lista a polem nazwy".

    Przyciecie liczymy wiec SAMI, z faktycznej wysokosci wiersza. Ta jest prawdziwa dopiero
    z uchwytem (przed nim ItemHeight oddaje wartosc zastepcza, a nie te z czcionki okna) -
    stad siegniecie po Handle, ktore uchwyt tworzy. Wysokosc wychodzi juz calowierszowa,
    wiec systemowe przyciecie nie ma potem czego ruszac, a Bottom listy jest prawdziwy
    w chwili, w ktorej mierzy sie od niego nastepny wiersz.

    RAMKA TO POMIAR, A NIE LICZBA: roznica wysokosci kontrolki i jej obszaru roboczego zalezy
    od stylu ramki i od DPI. Minimum jeden wiersz - lista bez zadnego widocznego wiersza nie
    dalaby sie ani czytac, ani przewinac.
#>
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

<#
.SYNOPSIS
    Wypelnia liste grup wedlug tresci pola filtra i uaktualnia licznik w tytule okna.

.DESCRIPTION
    JEDNA SCIEZKA DLA PIERWSZEGO WYPELNIENIA I DLA KAZDEGO ZNAKU. Osobny kod na start i osobny
    na filtrowanie rozjechalby sie przy pierwszej zmianie, a roznicy nie widac: okno po prostu
    otwieraloby sie inaczej, niz wyglada po skasowaniu filtra.

    STAN IDZIE PRZEZ Tag. Procedury zdarzen nie sa domknieciami i nie widza zmiennych lokalnych
    Show-JezykGrupyAd, a $Script:Kontrolki opisuje okno GLOWNE. Tag ginie razem z oknem, wiec
    ani pelna lista grup, ani rozpoznana grupa nie staja sie rzeczami, ktore trzeba pamietac
    o wyczyszczeniu przy zmianie konta - inaczej niz zmienna skryptowa. Na oknie wisi cala
    tablica skrotow (podpis, kontrolki, rozpoznana grupa), bo kontrolki tego okna musza
    odnalezc sie nawzajem.

    BeginUpdate/EndUpdate: bez nich lista przerysowuje sie przy kazdej dokladanej pozycji, czyli
    kilkadziesiat razy na jedno nacisniecie klawisza.
#>
function Update-JezykFiltrGrup {
    param($Pole)

    $lista = $Pole.Tag
    if (-not $lista) { return }

    $grupy    = @($lista.Tag)
    $widoczne = @(Select-JezykGrupyDoPokazania -Grupy $grupy -Fraza $Pole.Text)
    $wiersze  = @(Get-JezykWierszeGrup $widoczne)

    $okno = $Pole.FindForm()

    # WIDOCZNE PARY ODKLADAMY Z TEJ SAMEJ TABLICY, z ktorej powstaly napisy, i PRZED
    # narysowaniem listy. Stad Get-JezykZaznaczonaGrupe odwzorowuje SelectedIndex na grupe;
    # gdyby to pole zostalo z poprzedniego filtra, "Usun z grupy" wypisalo by konto z grupy,
    # ktorej na liscie juz nie ma - i nic by tego nie zglosilo.
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

    # Wyczyszczenie listy gasi zaznaczenie, a razem z nim powod, dla ktorego "Usun z grupy"
    # bylo czynne. Bez tego przycisk zostaje zapalony nad pusta liscie.
    Set-JezykPrzyciskUsunGrupe -Okno $okno
}

<#
.SYNOPSIS
    Pokazuje grupy AD zalezionego konta w osobnym oknie z lista. Wolane z przycisku "Grupy AD".

.DESCRIPTION
    OSOBNE OKNO, A NIE MessageBox jak przy przycisku "!". Konto potrafi nalezec do
    kilkudziesieciu grup, a okno komunikatu rosnie z trescia i nie przewija sie - koniec
    listy wypadalby poza ekran i nie dalo by sie do niego dojsc. Lista przewija sie sama.

    ZRODLEM JEST $Script:OstatnieKonto, a nie osobna zmienna z grupami. Pokazane konto ma
    juz swoje jedno miejsce w pamieci i jest zerowane w Clear-JezykKonto, wiec druga kopia
    byla by wylacznie kolejna rzecza, ktora mozna zapomniec wyczyscic - a lista grup
    poprzedniego konta opisywala by KOGOS INNEGO niz reszta widoku.

    STRAZ STOI PRZED PIERWSZA KONTROLKA. Przycisk bywa czynny wylacznie wtedy, gdy grupy
    sa (Set-JezykPrzyciskGrupy), ale warunek sprawdzamy takze tutaj: puste okno z tytulem
    "(0)" nie mowiloby nic ponad to, co mowi wyszarzony przycisk.

    Nazwy grup przychodza z logiki JUZ POSORTOWANE (Get-JezykCzlonkostwaGrup) - okno nie sortuje
    ich po raz drugi, bo dwa miejsca ustalajace kolejnosc rozjezdzaja sie przy pierwszej zmianie.

    GEOMETRIA LICZY SIE PO DODANIU KONTROLEK DO OKNA. Wysokosc pola tekstowego i szerokosc
    etykiety wychodza dopiero z czcionki, a te kontrolka dziedziczy po oknie w chwili dodania;
    wysokosc listy przycina do calych wierszy IntegralHeight. Wpisane na sztywno wspolrzedne
    przestaja pasowac przy skalowaniu DPI - dlatego kazdy wiersz mierzy sie od sasiada, a okno
    od ostatniego z nich.
#>
function Show-JezykGrupyAd {
    $konto = $Script:OstatnieKonto
    if (-not $konto) { return }

    # STRAZ STOI PRZED PIERWSZA KONTROLKA i pyta DOKLADNIE O TO SAMO, co warunek
    # dostepnosci przycisku - jedna funkcja na oba miejsca, zeby nie dalo sie ich rozjechac.
    if (-not (Test-JezykJestPoCoOtwieracGrupy $konto)) { return }

    # PARY "nazwa + nazwa wyrozniajaca", a nie same nazwy: bez nazwy wyrozniajacej nie da
    # sie usunac konta z grupy, a nazwa sama w sobie nie jest w domenie jednoznaczna.
    $grupy          = @(Get-JezykParyGrup $konto.GrupyPelne)
    $wolnoZarzadzac = Test-JezykMoznaZarzadzacGrupami $konto
    # DRUGA OS, NIE TA SAMA: $wolnoZarzadzac pyta takze o konto, a kontakt w domenie z listy
    # dostaje w polu "Status:" zdanie, dlaczego nie da sie go dopisac. Poza domena z listy
    # w to pole nie pisze nic - okno otwiera sie tam wylacznie z grupami do przeczytania.
    $domenaZZarzadzaniem = Test-JezykWolnoZarzadzacGrupami $Script:Config.Domena

    # Kontakt loginu nie ma, wiec podpis spada na nazwe obiektu - ta sama zasada, co przy
    # etykiecie pierwszego pola w oknie glownym ("Login:" kontra "Nazwa:").
    $podpis = [string]$konto.Login
    if (-not $podpis) { $podpis = [string]$konto.NazwaObiektu }

    # Wymiary liczone ze stalych siatki okna glownego, zeby oba okna mialy ten sam rytm.
    $margines           = $Script:Margines
    $szerokosc          = $Script:SzerokoscKolumny + 2 * $margines
    $wysokoscListy      = 300
    $szerokoscPrzycisku = 90
    $odstepEtykiety     = 8
    $odstepPrzyciskow   = 8
    # Od pary "Usun z grupy"/"Dodaj" do etykiety "Status:". Mniej niz przerwa wiersza, bo
    # przyciski stoja wylacznie po prawej, a pod nimi lezy jeszcze caly wiersz etykiety -
    # z pelna przerwa zostawalo tam prawie trzydziesci pikseli pustki.
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
        # BEZ -Rejestruj: to okno powstaje na zadanie i ginie w finally { Dispose() }, wiec
        # czyta paleta obowiazujaca w chwili otwarcia i nigdy nie jest przemalowywane.
        Set-JezykWyglad $okno 'Okno'

        # Wysokosc przycisku ROWNA POLU, tak samo jak w oknie glownym. Pomiar wymaga czcionki
        # okna, wiec stoi tutaj, a nie w bloku wymiarow wyzej; wpisane 24 px bylo od pola
        # o dwa piksele wyzsze bez powodu.
        $wysokoscPrzycisku = Get-JezykWysokoscPola $okno.Font

        $lblFiltr = New-JezykEtykieta 'Szukaj grupy:' $margines $margines

        # Zwykly TextBox, a nie New-JezykPole: tamto pole jest ReadOnly, bo sluzy do pokazywania
        # odpowiedzi AD, i rejestruje sie w motywie. Tu pisze operator, a okno ginie z Dispose().
        $txtFiltr           = New-Object System.Windows.Forms.TextBox
        $txtFiltr.MaxLength = 256
        Set-JezykWyglad $txtFiltr 'Pole'

        $lista = New-Object System.Windows.Forms.ListBox
        Set-JezykWyglad $lista 'Lista'
        # Wysokosc przycieta do calych wierszy. Czesciowy wiersz na dole rozjezdzal zawartosc
        # z paskiem przewijania (pasek liczy zakres z liczby pozycji, lista przewija calymi
        # wierszami), a dojscie do konca listy szarpalo o ten ulamek wiersza. Samo przyciecie
        # system robi jednak dopiero przy tworzeniu uchwytu, czyli PO pomiarach - dlatego
        # liczy je wczesniej Set-JezykWysokoscListy, a wszystko pod lista mierzy sie od
        # $lista.Bottom juz przycietej listy.
        $lista.IntegralHeight = $true
        # Nazwy grup bywaja dluzsze niz kolumna; poziomy pasek daje je doczytac zamiast
        # ucinac w polowie.
        $lista.HorizontalScrollbar = $true
        # Pelna lista wisi na kontrolce, bo to ona jest filtrowana, i ginie razem z oknem.
        $lista.Tag = $grupy
        # Pole filtra musi trafic do swojej listy bez pomocy zmiennych lokalnych tej funkcji.
        $txtFiltr.Tag = $lista

        # --- WIERSZE ZARZADZANIA -------------------------------------------------------
        # Istnieja WYLACZNIE w domenie z listy DomenyZZarzadzaniemGrupami i tylko dla konta
        # (nie dla kontaktu). Puste ustawienie ma CHOWAC, a nie zostawiac element wyszarzony:
        # kontrolka, ktora w danym wdrozeniu nie zadziala nigdy, przestaje cokolwiek znaczyc -
        # ta sama zasada, co przy przycisku "Polacz".
        #
        # DWA PRZYCISKI, DWA ZRODLA GRUPY, i to jest jedyna rzecz, ktorej z samego wygladu
        # nie widac: "Dodaj" bierze nazwe Z POLA obok, a "Usun z grupy" - Z ZAZNACZENIA
        # NA LISCIE. Rozroznienie niosa stany: pierwszy zapala sie po rozpoznaniu nazwy
        # w AD, drugi po zaznaczeniu pozycji.
        $lblNazwaGrupy = New-JezykEtykieta 'Nazwa grupy:' $margines 0

        $txtGrupa           = New-Object System.Windows.Forms.TextBox
        $txtGrupa.MaxLength = 256
        Set-JezykWyglad $txtGrupa 'Pole'

        # NAPIS W Tag, A Text PUSTY - rysuje go Set-JezykRysunekNapisuPrzycisku, patrz tam.
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
        # Stan poczatkowy: nie ma jeszcze czego dodawac. Zapala sie dopiero po rozpoznaniu
        # nazwy w AD.
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
        # Pole "Status:" tego okna: odpowiedz "Sprawdz nazwy", wynik dodania i zdanie
        # otwierajace. DWIE LINIJKI z tego samego powodu, co w oknie glownym - komunikat
        # o odmowie uprawnien nie miesci sie w jednej, a operator czyta pole RAZ.
        #
        # Poza domena z listy pola NIE MA, a nie jest puste: nic go tam nie wypelni, a pusta
        # ramka z podpisem "Status:" wyglada jak odpowiedz, ktora nie nadeszla.
        $lblNotka = New-JezykEtykieta 'Status:' $margines 0

        $txtNotka           = New-Object System.Windows.Forms.TextBox
        $txtNotka.ReadOnly  = $true
        $txtNotka.Multiline = $true
        Set-JezykWyglad $txtNotka 'Pole'

        $lblNotka.Visible = $domenaZZarzadzaniem
        $txtNotka.Visible = $domenaZZarzadzaniem

        # "!" wlasny, bo Set-JezykInfo stoi na rejestrach okna GLOWNEGO. -BezRejestracji,
        # zeby po Dispose() nie zostal martwy uchwyt w $Script:KontrolkiMotywu.
        $btnInfo = New-JezykPrzyciskInfo 'Grupy' -BezRejestracji

        # NAPIS W Tag, A Text PUSTY - rysuje go Set-JezykRysunekNapisuPrzycisku, patrz tam.
        $btnZamknij           = New-Object System.Windows.Forms.Button
        $btnZamknij.Text      = ''
        $btnZamknij.Tag       = 'Zamknij'
        $btnZamknij.Size      = [System.Drawing.Size]::new($szerokoscPrzycisku, $wysokoscPrzycisku)
        $btnZamknij.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        Set-JezykWyglad $btnZamknij 'Przycisk'
        $btnZamknij.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
        $btnZamknij.DialogResult = [System.Windows.Forms.DialogResult]::OK

        # STAN OKNA WISI NA OKNIE. Procedury zdarzen nie widza zmiennych lokalnych tej
        # funkcji, a kontrolki tego okna musza odnalezc sie nawzajem - jedna tablica skrotow
        # zalatwia oba problemy i ginie razem z oknem, wiec nie ma jej czego czyscic.
        $okno.Tag = @{
            Podpis        = $podpis
            PoleFiltra    = $txtFiltr
            Lista         = $lista
            PoleGrupy     = $txtGrupa
            PrzyciskDodaj = $btnDodaj
            PrzyciskUsun  = $btnUsun
            Notka         = $txtNotka
            PrzyciskInfo  = $btnInfo
            Szczegoly     = ''
            Wybrana       = $null
            # Pary widoczne TERAZ na liscie, w jej kolejnosci - stad Get-JezykZaznaczonaGrupe
            # odwzorowuje SelectedIndex na grupe. Wypelnia je Update-JezykFiltrGrup.
            WidoczneGrupy = @()
        }

        # Pole filtra jest PIERWSZA kontrolka, ktora przyjmuje fokus, wiec dostaje go samo -
        # pisac mozna od razu po otwarciu, bez osobnej procedury na Shown.
        $okno.Controls.AddRange(@($lblFiltr, $txtFiltr, $lista,
                                  $lblNazwaGrupy, $txtGrupa, $btnSprawdz,
                                  $btnUsun, $btnDodaj,
                                  $lblNotka, $txtNotka, $btnInfo, $btnZamknij))

        # SZEROKOSC OKNA LICZONA Z WIERSZA, KTORY JEJ NAPRAWDE POTRZEBUJE. Kolumna okna
        # glownego jest stala liczba pikseli, a etykieta i oba przyciski rosna razem
        # z czcionka: przy "Rozmiarze tekstu" 150% na pole zostawaloby kilkanascie pikseli
        # albo mniej niz zero - i NIKT BY TEGO NIE POLICZYL, bo szerokosc pola liczy sie
        # od sasiadow. Minimum pola bierzemy z napisu przycisku, zeby i ono skalowalo sie
        # z czcionka zamiast byc kolejna wpisana liczba.
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
        # GORNY MARGINES TEN SAM, CO W OKNIE GLOWNYM - jego wlasna, nazwana liczba. Margines
        # boczny ($margines) zostawial pod paskiem tytulu dwanascie pikseli pustki.
        Set-JezykSrodekPionowy -Kontrolki @($lblFiltr, $txtFiltr) `
                               -Srodek ($Script:MarginesGorny + (Get-JezykPolowaWysokosci $txtFiltr.Height))

        $lista.Left   = $margines
        $lista.Width  = $szerokosc - 2 * $margines
        # PRZERWA MIEDZY WIERSZAMI TA SAMA, CO W OKNIE GLOWNYM. Margines okna ($margines)
        # opisuje ramke, a nie gestosc srodka - mieszanie obu zostawialo miedzy wierszami
        # polowe wiersza pustki wiecej, niz trzeba.
        $lista.Top    = $txtFiltr.Bottom + $Script:PrzerwaWierszy
        Set-JezykWysokoscListy $lista $wysokoscListy

        # Kazdy nastepny wiersz mierzy sie OD SASIADA. Gdy wierszy zarzadzania nie ma,
        # notka siada wprost pod lista i okno jest o te dwa wiersze nizsze.
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

            # Wiersz akcji: oba przyciski przy prawej krawedzi. Wspolrzedne "Usun z grupy"
            # brane OD SASIADA, zeby para jechala razem, a nie kazdy z wlasnej liczby.
            $btnDodaj.Left = $szerokosc - $margines - $btnDodaj.Width
            $btnUsun.Left  = $btnDodaj.Left - $odstepPrzyciskow - $btnUsun.Width
            $btnDodaj.Top  = $dolPoprzedniego + $Script:PrzerwaWierszy
            $btnUsun.Top   = $btnDodaj.Top
            $dolPoprzedniego = $btnDodaj.Bottom
            $przerwaNadNotka = $przerwaPodPrzyciskami
        }

        if ($domenaZZarzadzaniem) {
            # Notka ma WLASNA ETYKIETE po to, zeby "!" stanal dokladnie tam, gdzie stoi w oknie
            # glownym: Set-JezykPrzyciskPrzyEtykiecie konczy go razem z prawa krawedzia POLA.
            $lblNotka.Left   = $margines
            $lblNotka.Top    = $dolPoprzedniego + $przerwaNadNotka
            $txtNotka.Left   = $margines
            $txtNotka.Top    = $lblNotka.Top + $Script:OdstepPodEtykieta
            $txtNotka.Width  = $szerokosc - 2 * $margines
            # Druga linijka liczona z czcionki, nie wpisana - ta sama arytmetyka, co przy polach
            # "Status:" w oknie glownym.
            $txtNotka.Height = $txtNotka.PreferredHeight + [int][math]::Ceiling($okno.Font.GetHeight())
            # Etykieta lezy w oknie NAD polem (wczesniej w AddRange), wiec za wysoka zakrywa
            # jego gorna ramke - ta sama usterka, co kiedys w oknie glownym.
            Set-JezykEtykietaNadPolem $lblNotka
            Set-JezykPrzyciskPrzyEtykiecie $btnInfo $lblNotka $txtNotka
            $dolPoprzedniego = $txtNotka.Bottom
        }

        $btnZamknij.Left = $szerokosc - $margines - $szerokoscPrzycisku
        $btnZamknij.Top  = $dolPoprzedniego + $Script:PrzerwaWierszy

        $okno.ClientSize = [System.Drawing.Size]::new($szerokosc,
                               ($btnZamknij.Bottom + $margines))

        # Pasek tytulu i pasek przewijania listy - jedyne dwie rzeczy w tym oknie, ktorych
        # nie zalatwia kolor kontrolki. Siegniecie po Handle TWORZY uchwyt, wiec wywolanie
        # dziala mimo tego, ze okna jeszcze nie widac; ShowDialog i tak pokaze je za chwile.
        $ciemny = ($Script:Motyw -eq 'Ciemny')
        Set-JezykCiemnyPasekTytulu      $okno.Handle  -Ciemny:$ciemny
        Set-JezykCiemnyPasekPrzewijania $lista.Handle -Ciemny:$ciemny

        # Pierwsze wypelnienie idzie TA SAMA droga, co kazdy nacisniety klawisz - razem
        # z tytulem, ktory niesie licznik.
        Update-JezykFiltrGrup $txtFiltr

        # NOTKA OTWIERAJACA tam, gdzie pole bez niej nie tlumaczy tego, co widac. Pusta
        # lista sama nie mowi, czy konto nie ma grup, czy cos zawiodlo; a wiersza dodawania
        # brakuje kontaktowi z powodu, ktory warto nazwac - ale tylko tam, gdzie dodawanie
        # w ogole jest wlaczone, bo inaczej wiersza nie ma nikt i zdanie mylilo by tropy.
        $notka = ''
        if ($grupy.Count -eq 0) { $notka = 'To konto nie należy do żadnej grupy.' }
        if ($konto.Status -eq 'Kontakt' -and $domenaZZarzadzaniem) {
            $notka = 'Kontakt nie jest kontem w domenie - nie da się go dopisać do grupy.'
        }
        if ($notka) { Set-JezykNotkeGrup -Okno $okno -Tekst $notka }

        $txtFiltr.Add_TextChanged({ Update-JezykFiltrGrup $this })
        $lista.Add_MouseWheel({ Set-JezykPrzewijanieListy $this $_ })

        # "Usun z grupy" dziala na ZAZNACZONEJ pozycji, wiec jego dostepnosc jest stanem
        # zaznaczenia - a to zmienia sie takze bez udzialu myszy (strzalki, zawezenie filtra).
        $lista.Add_SelectedIndexChanged({ Set-JezykPrzyciskUsunGrupe -Okno $this.FindForm() })

        if ($wolnoZarzadzac) {
            # ZMIANA TEKSTU UNIEWAZNIA ROZPOZNANA GRUPE. Bez tego zapis poszedlby na nazwe
            # wyrozniajaca grupy, ktorej w polu juz nie ma - i nic by tego nie zdradzilo.
            $txtGrupa.Add_TextChanged({
                $stan = $this.FindForm().Tag
                if (-not $stan) { return }
                $stan.Wybrana = $null
                if ($stan.PrzyciskDodaj) { $stan.PrzyciskDodaj.Enabled = $false }
            })

            # ENTER MA ZNACZYC "Sprawdz nazwy", A NIE "Zamknij". Samo KeyDown tego nie
            # zalatwi, bo NIE DOSTAJE ENTERA WCALE: jednolinijkowe pole nie uwaza go za swoj
            # klawisz, wiec okno oddaje go AcceptButton jeszcze przed KeyDown - i Enter
            # zamykal okno w polowie wpisywania nazwy, choc obsluga nizej stala w kodzie.
            # PreviewKeyDown to jedyny etap PRZED przekazaniem klawisza przyciskowi okna:
            # oznaczony tam jako klawisz pola, Enter dochodzi do KeyDown.
            $txtGrupa.Add_PreviewKeyDown({
                if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $_.IsInputKey = $true }
            })

            # Handled i SuppressKeyPress: bez nich pole dostaje jeszcze znak Entera, ktorego
            # jednolinijkowe pole nie przyjmuje - i odpowiada systemowym dzwiekiem.
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

        # Pelna tresc pod "!" - wlasnym MessageBoxem, bo Show-JezykInformacja czyta
        # $Script:Informacje i $Script:TytulyInformacji, czyli rejestry okna glownego.
        $btnInfo.Add_Click({
            $okienko = $this.FindForm()
            $stan    = $okienko.Tag
            if (-not $stan -or -not $stan.Szczegoly) { return }
            [void][System.Windows.Forms.MessageBox]::Show($okienko, [string]$stan.Szczegoly,
                'Jeżyk - Grupy AD', [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        })

        # Esc zamyka. Enter takze - poza polem nazwy grupy, ktore przejmuje go wyzej: lista
        # zaweza sie po kazdym znaku, wiec w filtrze nie ma czego zatwierdzac.
        $okno.AcceptButton = $btnZamknij
        $okno.CancelButton = $btnZamknij

        [void]$okno.ShowDialog($Script:Kontrolki.Okno)
    }
    finally {
        # ShowDialog NIE zwalnia okna sam (w odroznieniu od Show) - bez tego kazde
        # klikniecie zostawialoby w procesie komplet uchwytow GDI po jednym oknie.
        if ($okno) { $okno.Dispose() }
    }
}

<#
.SYNOPSIS
    Pyta, ktora z rozpoznanych grup chodzilo - gdy "Sprawdz nazwy" trafilo w wiecej niz jedna.

.DESCRIPTION
    Ten sam szkielet, co Show-JezykWyborDysku. Pozycje numeruje Get-JezykWierszeGrup - ta sama
    funkcja, co liste grup konta, zeby dwie numeracje nie mogly sie rozjechac. Zaznaczenie
    mapuje sie na liste trafien INDEKS W INDEKS, bo Find-JezykGrupyPoNazwie odsiewa pozycje
    bez nazwy jeszcze w logice.

    WLASCICIELEM JEST OKNO GRUP, a nie okno glowne: to okno wstaje nad innym oknem modalnym,
    wiec podpiete pod glowne potrafiloby schowac sie za tym, z ktorego je otwarto.
#>
function Show-JezykWyborGrupy {
    param($Trafienia, $Wlasciciel)

    # WIERSZE I ZWRACANA POZYCJA Z JEDNEJ TABLICY. Get-JezykWierszeGrup numeruje po
    # Get-JezykParyGrup, ktory odsiewa nazwy z samych bialych znakow; indeks zaznaczenia
    # odniesiony do surowych trafien przesuwalby sie o jeden za kazda odsiana pozycja,
    # czyli "Dodaj" trafialoby w grupe z wiersza wyzej niz klikniety.
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

        # NAPIS W Tag, A Text PUSTY - rysuje go Set-JezykRysunekNapisuPrzycisku, patrz tam.
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

        # Geometria PO dodaniu kontrolek: wysokosc wiersza wychodzi z czcionki, a te
        # kontrolka dziedziczy po oknie dopiero w chwili dodania.
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

        # Dwuklik na liscie ma znaczyc to samo, co "Wybierz" - inaczej wybor dwoma
        # klknieciami wygladalby na nieskuteczny. Procedura nie widzi zmiennych tej
        # funkcji, wiec okno bierze sie z samej kontrolki.
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
# Udzialy administracyjne, ktore system zaklada sam na kazdym dysku (C$, D$, ...). Lista
# jest STALA i celowo nie stoi w $Script:Ustawienia: tamten blok opisuje ADRESY POLACZEN -
# domeny, kontrolery, serwer lokacji - czyli rzeczy, ktorych Jezyk nie ma prawa zgadywac.
# Litera dysku adresem nie jest. Nie pytamy o nia takze samej maszyny: okno ma otwierac sie
# od razu, a odpytanie o dyski byloby siodmym zadaniem w tle - dla dwoch pozycji na liscie.
$Script:LiteryDyskow = @('C', 'D')

<#
.SYNOPSIS
    Pyta, ktory udzial dyskowy pokazanej maszyny otworzyc. Oddaje LITERE albo pusty napis.

.DESCRIPTION
    OSOBNE OKNO, A NIE MessageBox: z komunikatu nie da sie niczego wybrac. Wzorem jest
    Show-JezykGrupyAd i szkielet jest ten sam - okno na zadanie, wyglad BEZ -Rejestruj
    (ginie w finally { Dispose() }, wiec czyta palete obowiazujaca w chwili otwarcia),
    geometria mierzona od sasiada, ShowDialog na oknie glownym.

    STRAZ STOI PRZED PIERWSZA KONTROLKA. Przycisk bywa czynny wylacznie przy zapamietanej
    maszynie, ale warunek sprawdzamy takze tutaj: bez nazwy nie ma z czego zlozyc sciezki,
    a okno pytajace o dysk nieznanej maszyny nie mialoby o czym pytac.

    ZRODLEM NAZWY JEST $Script:OstatniKomputer - ta sama zmienna, co przy "Pinguj"
    i "Polacz", czyli pisownia z AD, a nie z pola tekstowego.

    Funkcja ODDAJE WYNIK, w odroznieniu od okna grup, wiec wszystko, co po drodze cokolwiek
    zwraca (Items.Add, ShowDialog), musi isc przez [void] albo do zmiennej - inaczej do
    wyniku wpadnie smiec i wolajacy dostanie tablice zamiast litery.
#>
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

        # Wysokosc przycisku ROWNA POLU, tak samo jak w oknie glownym i w oknie grup.
        # Pomiar wymaga czcionki okna, wiec stoi za jej ustawieniem.
        $wysokoscPrzycisku = Get-JezykWysokoscPola $okno.Font

        $lista = New-Object System.Windows.Forms.ListBox
        Set-JezykWyglad $lista 'Lista'
        # Wysokosc przycieta do calych wierszy: czesciowy wiersz na dole wygladalby jak
        # pozycja, ktorej nie da sie dosiegnac. Paska przewijania ta lista nie dostanie
        # przy zadnej sensownej liczbie liter, wiec nie ma tu czego przemalowywac.
        $lista.IntegralHeight = $true

        foreach ($litera in $Script:LiteryDyskow) {
            # Napis skladany DO ZMIENNEJ: w argumencie metody przecinek nalezy do listy
            # argumentow, a nie do tablicy dla operatora -f.
            $pozycja = '{0}$' -f $litera
            [void]$lista.Items.Add($pozycja)
        }
        # Pierwsza pozycja zaznaczona od razu, zeby Enter dzialal bez siegania po mysz.
        if ($lista.Items.Count -gt 0) { $lista.SelectedIndex = 0 }

        # NAPIS W Tag, A Text PUSTY - rysuje go Set-JezykRysunekNapisuPrzycisku, patrz tam.
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

        # Geometria PO dodaniu kontrolek: wysokosc wiersza wychodzi z czcionki, a te
        # kontrolka dziedziczy po oknie dopiero w chwili dodania.
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

        # Dwuklik na liscie ma znaczyc to samo, co "Otworz" - inaczej wybor dwoma
        # kliknieciami wygladalby na nieskuteczny. Procedura nie widzi zmiennych tej
        # funkcji, wiec okno bierze sie z samej kontrolki.
        $lista.Add_DoubleClick({
            $this.FindForm().DialogResult = [System.Windows.Forms.DialogResult]::OK
        })

        $okno.AcceptButton = $btnOtworz
        $okno.CancelButton = $btnZamknij

        # Siegniecie po Handle TWORZY uchwyt, wiec wywolanie dziala mimo tego, ze okna
        # jeszcze nie widac.
        Set-JezykCiemnyPasekTytulu $okno.Handle -Ciemny:($Script:Motyw -eq 'Ciemny')

        $odpowiedz = $okno.ShowDialog($Script:Kontrolki.Okno)
        if ($odpowiedz -ne [System.Windows.Forms.DialogResult]::OK) { return '' }

        $wybrana = [string]$lista.SelectedItem
        if (-not $wybrana) { return '' }

        # Na liscie stoi "C$", a dalej idzie sama litera: znak dolara doklada
        # Open-JezykUdzialDysku, w jednym miejscu razem z reszta sciezki.
        return $wybrana.Substring(0, 1)
    }
    finally {
        # ShowDialog NIE zwalnia okna sam - bez tego kazde klikniecie zostawialoby
        # w procesie komplet uchwytow GDI po jednym oknie.
        if ($okno) { $okno.Dispose() }
    }
}

<#
.SYNOPSIS
    Buduje okno, wypelnia rejestr kontrolek i podpina zdarzenia.

.DESCRIPTION
    Szerokosc okna jest stala, a WYSOKOSC IDZIE ZA POKAZANYM PANELEM - nadaje ja
    Set-JezykWysokoscOkna, wolana i stad, i z kazdej zmiany trybu. Dotad rozmiar byl staly
    i wymierzony widokiem wyzszym, czyli kontem; widok komputera zostawial u dolu kilkaset
    pikseli pustki.
#>
function New-JezykForm {

    # ClientSize, a nie Size: podajemy rozmiar obszaru roboczego, bez ramki i paska tytulu,
    # wiec wspolrzedne kontrolek zgadzaja sie niezaleznie od motywu Windows.
    $form                 = New-Object System.Windows.Forms.Form
    $form.Text            = $Script:Config.TytulOkna
    # Tlo okna JAWNIE, a nie z domyslnego SystemColors.Control: to od niego dziedziczy
    # kolor kazda etykieta i kazdy znacznik, wiec to jedno przypisanie odpowiada za
    # wiekszosc powierzchni okna w obu motywach.
    Set-JezykWyglad $form 'Okno' -Rejestruj

    # CZCIONKA JAKO PIERWSZA, PRZED LICZENIEM CZEGOKOLWIEK. MessageBoxFont zamiast
    # zaszytego 'Segoe UI 9': to czcionka, ktorej system faktycznie uzywa w oknach
    # dialogowych - honoruje ustawienia uzytkownika i skalowanie DPI. Ustawiona na
    # formularzu, bo dzieci dziedzicza ja automatycznie.
    #
    # Od niej zalezy wysokosc pola, a od wysokosci pola - caly rytm siatki ponizej, wiec
    # nie da sie jej przypisac pozniej.
    $form.Font            = [System.Drawing.SystemFonts]::MessageBoxFont

    # RYTM SIATKI Z FAKTYCZNEJ WYSOKOSCI POLA, a nie z liczby wpisanej w naglowku pliku.
    # Wiersze stoja na stalych wspolrzednych, a pole rosnie z czcionka systemu: skok
    # wpisany na sztywno musialby obsluzyc najwieksza czcionke i przy zwyklej zostawialby
    # miedzy wierszami dwa razy wiecej pustki, niz trzeba.
    $wysokoscPola       = Get-JezykWysokoscPola $form.Font
    $Script:SkokWiersza = Get-JezykSkokWiersza $wysokoscPola

    # PIETRA PANELI RAZEM Z GORNYM PASEM, i z tego samego pomiaru. Gorny margines jest
    # stala, a oba wiersze nad panelem rosna z czcionka - pietro wpisane liczba zostawialo
    # nad panelem dokladnie tyle pustki, ile ubylo z gornego marginesu. Musi stac TUTAJ,
    # przed pierwsza wspolrzedna: z tych dwoch liczb bierze sie i polozenie listy wyboru,
    # i wysokosc okna.
    $Script:PanelBezListy = Get-JezykPietroBezListy $wysokoscPola
    $Script:PanelZListą   = $Script:PanelBezListy + $Script:PasListyWyboru

    # Pole "Status:" jest jedyne dwulinijkowe w calym oknie - niesie najdluzsze teksty.
    # TA SAMA ARYTMETYKA, ktora nadaje mu wysokosc w sekcji wyrownania: druga linijka to
    # wysokosc linii pisma, a nie liczba dobrana na oko. Liczona tutaj, bo z niej bierze
    # sie wysokosc obu paneli.
    $drugaLinia      = [int][math]::Ceiling($form.Font.GetHeight())
    $wysokoscStatusu = $wysokoscPola + $drugaLinia

    # DZIEWIEC WIERSZY (0-8). Osmy doszedl razem z polem "Adres IP" - pol polowkowych jest
    # jedenascie, czyli nieparzyscie, a trzy dolne potrzebuja calej szerokosci, wiec jedno
    # miejsce w siatce zostaje wolne i okno uroslo o jeden skok wiersza.
    # PANEL KONCZY SIE NA DOLNEJ KRAWEDZI POLA "Status:", a nie przerwe nizej: panel nie ma
    # ramki, wiec zapas pod ostatnim polem jest samym powietrzem - i doliczal sie do przerwy
    # nad podpisem autora.
    $wysokoscPanelu = (Get-JezykWierszPole 8) + $wysokoscStatusu

    # PAS PODPISU MIERZONY TUTAJ, bo z jego wysokosci bierze sie wysokosc okna. Czcionka
    # o punkt mniejsza niz w oknie, a z dwojga - kwadrat ikonki motywu albo linia pisma -
    # bierzemy WIEKSZE: inaczej albo ikonka jest przyciasna, albo napis zostaje ucinany od
    # dolu przy DPI 125-150%, gdzie pismo rosnie, a wpisana na sztywno liczba by nie urosla.
    $czcionkaPasa               = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size - 1)
    $Script:WysokoscPasaPodpisu = [Math]::Max($Script:BokIkonyMotywu,
                                              [int][Math]::Ceiling($czcionkaPasa.GetHeight()))

    # WYSOKOSCI OKNA NIE MA TUTAJ - nadaje ja Set-JezykWysokoscOkna na koncu tej funkcji,
    # tak samo jak przy kazdej pozniejszej zmianie trybu. Dwie arytmetyki wysokosci
    # rozjechalyby sie przy pierwszej zmianie siatki, a okno wstawaloby w innym rozmiarze,
    # niz dostaje po przelaczeniu na ten sam widok.
    #
    # AutoScroll jest zapora na okno wyzsze od ekranu i nie kosztuje nic, gdy okno sie
    # miesci: WinForms pokazuje pasek przewijania WYLACZNIE wtedy, gdy kontrolki wychodza
    # poza obszar roboczy okna. Wysokosc przycina Get-JezykWysokoscWEkranie, zeby pasek
    # mial sie kiedy pojawic - bez tego okno po prostu wystawaloby poza ekran.
    $form.AutoScroll = $true

    # Nierozciagliwa ramka, bo kontrolki sa pozycjonowane na sztywno i przy rozciaganiu
    # zostalyby w miejscu. Wysokosc zmienia sam program, przy zmianie trybu.
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $true
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen

    # Ikona jest opcjonalna i celowo nie przerywa startu: brakujacy plik to drobiazg
    # kosmetyczny i nie moze przeszkodzic w sprawdzeniu konta.
    $plikIkony = Join-Path $Script:KatalogSkryptu 'Ikona-Jezyk.ico'
    if (Test-Path -LiteralPath $plikIkony) {
        try   { $form.Icon = [System.Drawing.Icon]::new($plikIkony, 32, 32) }
        catch { }
    }

    # --- WIERSZ DOMENY I WIERSZ WYSZUKIWANIA -----------------------------------------
    # Wspolny slupek na etykiety, zeby obie listy zaczynaly sie w tej samej wspolrzednej.
    # Srodki obu wierszy licza sie DOPIERO W SEKCJI WYROWNANIA, bo biora sie z rzeczywistej
    # wysokosci listy domen - patrz tam.
    $slupekEtykiet = 70

    $lblDomena = New-JezykEtykieta 'Domena' $Script:Margines 0
    $lblPodaj  = New-JezykEtykieta 'Podaj'  $Script:Margines 0

    # Zmiana domeny przekierowuje wszystkie zapytania - wystarczy podmiana parametru -Server,
    # bo konto ma prawo odczytu we wszystkich domenach powiazanych zaufaniem.
    $cmbDomena               = New-Object System.Windows.Forms.ComboBox
    $cmbDomena.Left          = $slupekEtykiet
    $cmbDomena.Width         = 240
    $cmbDomena.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbDomena.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $cmbDomena 'Lista' -Rejestruj
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
    Set-JezykWyglad $cmbTryb 'Lista' -Rejestruj
    [void]$cmbTryb.Items.Add($Script:Config.TrybNazwa)
    [void]$cmbTryb.Items.Add($Script:Config.TrybKomputer)
    $cmbTryb.SelectedIndex = 0

    $przerwa = 16

    # NAPIS W Tag, A Text PUSTY - rysuje go Set-JezykRysunekNapisuPrzycisku w calym
    # prostokacie przycisku, dzieki czemu przycisk moze byc dokladnie tak wysoki, jak pole.
    $btnSzukaj           = New-Object System.Windows.Forms.Button
    $btnSzukaj.Text      = ''
    $btnSzukaj.Tag       = 'Szukaj'
    $btnSzukaj.Width     = 96
    # WYSOKOSC ROWNA POLU, i to ostatecznie. Nikt jej pozniej nie podnosi - napis rysuje
    # Set-JezykRysunekNapisuPrzycisku w calym prostokacie, wiec nie ma sie gdzie uciac.
    $btnSzukaj.Height    = $wysokoscPola
    $btnSzukaj.Left      = $Script:Margines + $Script:SzerokoscPelna - $btnSzukaj.Width
    $btnSzukaj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnSzukaj 'Przycisk' -Rejestruj

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
    Set-JezykWyglad $txtSzukaj 'Pole' -Rejestruj

    # Lista wyboru kont - widoczna wylacznie przy wyszukiwaniu czesciowym. DisplayMember
    # sprawia, ze pokazuje pole Opis, a kod ma pod reka caly obiekt kandydata.
    $cmbWynik               = New-Object System.Windows.Forms.ComboBox
    # Ta sama wspolrzedna, co gorna krawedz panelu bez listy - lista i panel zajmuja
    # w tym miejscu to samo pietro okna, wiec licza sie z jednej stalej.
    $cmbWynik.Location      = [System.Drawing.Point]::new($Script:Margines, $Script:PanelBezListy)
    $cmbWynik.Width         = $Script:SzerokoscPelna
    $cmbWynik.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    # FlatStyle = Flat z tego samego powodu, co przy dwoch listach wyzej: bez niego przy
    # wlaczonych stylach wizualnych BackColor jest ignorowany i lista zostalaby biala
    # w ciemnym motywie. Cena ta sama - kontrolka traci wyglad systemowy.
    $cmbWynik.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $cmbWynik 'Lista' -Rejestruj
    $cmbWynik.DisplayMember = 'Opis'
    $cmbWynik.Visible       = $false

    # --- PANEL: WIDOK KONTA ----------------------------------------------------------
    $pnlKonto      = New-Object System.Windows.Forms.Panel
    Set-JezykWyglad $pnlKonto 'Okno' -Rejestruj
    $pnlKonto.Size = [System.Drawing.Size]::new($Script:SzerokoscOkna, $wysokoscPanelu)

    # Werdykt: jedyny NAPIS w oknie, ktorego kolor zalezy od stanu konta (pola niosa stan
    # tlem), i jedyna kontrolka, ktorej tresc tez od niego zalezy. Wspolrzedna pionowa
    # ustawiana jest przez wyrownanie na koncu tej funkcji.
    $chkWerdykt           = New-JezykCheckbox '' $Script:Margines 0 18
    # Lewa wspolrzedna napisu tez z wyrownania - liczy sie od kwadratu, jak we flagach.
    # Napis startowy jest NEUTRALNY, a nie przykladowy. Szerokosc etykiety mierzy sie
    # i tak stala $Script:NajdluzszyWerdykt, wiec tresc niczego tu nie ustawia - a nazwa
    # jednego ze stanow konta, wpisana tu "na probe", zawedrowala juz raz do
    # Clear-JezykKonto i zostala tam jako werdykt wyczyszczonego okna.
    $lblWerdykt           = New-JezykEtykieta 'Nie sprawdzono' 0 0
    # Czcionka WYPROWADZONA z czcionki okna, a nie wpisana z nazwy - ma pozostac o punkt
    # wieksza i pogrubiona takze wtedy, gdy system uzywa innej czcionki dialogow.
    $lblWerdykt.Font      = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size + 1, [System.Drawing.FontStyle]::Bold)
    # ROLA "Okno" PRZED KOLOREM. Po tej rejestracji Set-JezykKolorPola poznaje, ze to
    # etykieta lezaca na panelu, a nie pole: stan konta maluje jej NAPIS, a tlem zostaje tlo
    # okna. Bez niej werdykt dostalby kolorowe tlo jak pole tekstowe - zielony albo czerwony
    # prostokat posrodku panelu.
    Set-JezykWyglad    $lblWerdykt 'Okno' -Rejestruj
    Set-JezykKolorPola $lblWerdykt 'Nieznany'

    # Jedyna czynna kontrolka w widoku i jedyna operacja zapisu w narzedziu. Widoczny
    # wylacznie w domenie z odblokowaniem - widocznosc i dostepnosc ustawia jedno miejsce,
    # Set-JezykPrzyciskOdblokuj w Jezyk-3-Widok.ps1.
    $btnOdblokuj           = New-Object System.Windows.Forms.Button
    $btnOdblokuj.Text      = ''
    $btnOdblokuj.Tag       = 'Odblokuj konto'
    $btnOdblokuj.Width     = 130
    # WYSOKOSC ROWNA POLU, a nie wpisane 26 px. Tamta liczba byla o cztery piksele wyzsza
    # od pol w oknie i po scisnieciu siatki przycisk wygladal przy nich na przerosniety.
    $btnOdblokuj.Height    = $wysokoscPola
    $btnOdblokuj.Left      = $Script:Margines + $Script:SzerokoscPelna - $btnOdblokuj.Width
    $btnOdblokuj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnOdblokuj 'Przycisk' -Rejestruj
    $btnOdblokuj.Enabled   = $false

    # Siatka faktow, z ktorych powstaje werdykt. Trzy rowne kolumny, wyliczane - poprzednie
    # odstepy wpisane recznie widac bylo golym okiem.
    $grpFlagi          = New-Object System.Windows.Forms.GroupBox
    Set-JezykWyglad $grpFlagi 'Okno' -Rejestruj
    $grpFlagi.Text     = ''
    $grpFlagi.Location = [System.Drawing.Point]::new($Script:Margines, 32)
    $grpFlagi.Size     = [System.Drawing.Size]::new($Script:SzerokoscPelna, 52)

    # WSPOLRZEDNE SA TU ZEROWE CELOWO - nadaje je wyrownanie na koncu tej funkcji, tak samo
    # jak przy werdykcie nizej. Znacznik zwiezy sie tam do szerokosci swojego napisu, a nie
    # da sie go wysrodkowac w slupku, zanim ta szerokosc bedzie znana - a znana jest dopiero
    # po odziedziczeniu czcionki okna, czyli po dodaniu kontrolki do okna.
    #
    # KWADRAT I NAPIS TO DWIE KONTROLKI, a nie znacznik z wlasnym tekstem. WinForms rozklada
    # wlasny napis znacznika po swojemu: odstepu od kwadratu nie da sie podac zadna
    # wlasciwoscia, a linia pisma wypada nizej niz srodek kwadratu. Rozdzielone daja sie
    # postawic na jednej linii i o jedna spacje od kwadratu (Get-JezykOdstepZnacznika).
    # Ta sama para, co przy werdykcie nizej.
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
    Set-JezykWyglad $btnInfoKomputerWspoldzielony 'InfoNiebieski' -Rejestruj

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
    $btnPinguj.Text      = ''
    $btnPinguj.Tag       = 'Pinguj'
    $btnPinguj.Width     = $szerokoscPingu
    $btnPinguj.Height    = $wysokoscPola
    $btnPinguj.Left      = $P + $W - $szerokoscPingu
    $btnPinguj.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnPinguj 'Przycisk' -Rejestruj
    $btnPinguj.Enabled   = $false
    $btnPinguj.TabStop   = $false

    # "Polacz" - zdalna konsola do tej samej maszyny. STOI NAD "PINGUJ", w linii etykiety,
    # za przyciskami "!". Ta czesc wiersza stoi pusta: etykieta i wykrzykniki koncza sie
    # razem z polem, przed prawa krawedzia kolumny, wiec przycisk nie zabral miejsca ZADNEMU polu
    # w oknie - ani nazwisku wyzej, ani nazwie maszyny obok, ani adresowi IP nizej. Panel
    # konta zostaje dziewieciowierszowy i okno nie uroslo ani o piksel.
    #
    # DWIE NIEZALEZNE OSIE, powod przy Set-JezykPrzyciskiZdalne: ten przycisk ZNIKA, gdy
    # nie ma sie z czym laczyc - a to znaczy TRZY rzeczy naraz: jest maszyna, jest sciezka
    # do konsoli i maszyna odpowiedziala na ping. Powod przy Set-JezykPrzyciskiZdalne, tam
    # stoi tez cena tej decyzji. Wspolrzedne dostaje na koncu, razem z calym wyrownaniem.
    $btnPolacz           = New-Object System.Windows.Forms.Button
    $btnPolacz.Text      = ''
    $btnPolacz.Tag       = 'Połącz'
    $btnPolacz.Width     = $szerokoscPingu
    $btnPolacz.Height    = $wysokoscPola
    $btnPolacz.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnPolacz 'Przycisk' -Rejestruj
    $btnPolacz.Visible   = $false
    $btnPolacz.TabStop   = $false

    # ADRES IP W OSOBNYM POLU, DOKLADNIE POD NAZWA MASZYNY. Doklejony do pola obok
    # wypchnalby z niego date ostatniej aktywnosci, a w kolumnie nie ma miejsca na oba
    # napisy naraz. Pion pod komputerem mowi bez slowa, ktorej maszyny adres to jest.
    #
    # Lewa polowa tego wiersza stala pusta - jako swiadoma cena za nieparzysta liczbe pol
    # polowkowych - i wlasnie ona przyjela adres MAC. Nowa kontrolka nie kosztowala przez
    # to ANI JEDNEJ wspolrzednej i nie podwyzszyla okna: MAC opisuje te sama karte, ktora
    # odpowiada pod adresem obok, wiec sasiedztwo jest tu takze merytoryczne.
    # Przycisk "!" jest NIEBIESKI - brak dopasowania to nie usterka, tylko inwentaryzacja
    # SCCM starsza od biezacej dzierzawy DHCP.
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

    # Dwie informacje "kontaktowe" w jednym wierszu: pod ktory numer zadzwonic i kogo
    # zapytac o zgode. Obie mieszcza sie w kolumnie, wiec nie zabieraja calej szerokosci.
    $lblTelefon  = New-JezykEtykieta 'Telefon:'  $L (Get-JezykWiersz 5)
    $txtTelefon  = New-JezykPole                 $L (Get-JezykWierszPole 5) $W
    $lblMenedzer = New-JezykEtykieta 'Przełożony:' $P (Get-JezykWiersz 5)
    $txtMenedzer = New-JezykPole                 $P (Get-JezykWierszPole 5) $W

    # KATALOG PRZED DATA LOGOWANIA, i o polowe wezszy niz dotad. Sciezka w drzewie
    # ("jezyk.pl/Uzytkownicy/Dzial IT") miesci sie w kolumnie tak samo jak telefon,
    # a pole jest zwyklym TextBoxem - dluzsza tresc przewija sie w nim sama i nadal
    # da sie ja zaznaczyc i skopiowac.
    #
    # ZWOLNIONA PRAWA POLOWA TEGO WIERSZA PRZYJELA GRUPY I LICENCJE. Nowy blok nie
    # kosztowal przez to ANI JEDNEJ wspolrzednej ani jednego wiersza - panel konta
    # zostaje dziewieciowierszowy i okno nie uroslo o piksel. Ta sama droga, ktora
    # weszly wczesniej jez i przycisk "Polacz": najpierw policz, co juz stoi puste.
    $lblKatalog = New-JezykEtykieta 'Katalog konta:' $L (Get-JezykWiersz 6)
    $txtKatalog = New-JezykPole                      $L (Get-JezykWierszPole 6) $W

    # Etykieta stoi w linii etykiet, przycisk w linii pol - czyli dokladnie tam, gdzie
    # w kazdym innym wierszu lezy pole tekstowe.
    #
    # SZEROKOSC LICZONA Z KOLUMNY ($W), a nie wpisana liczba: liczba zgadzalaby sie
    # tylko przy dzisiejszej szerokosci okna, a ta wylicza sie ze stalych.
    $lblGrupy = New-JezykEtykieta 'Grupy AD użytkownika:' $P (Get-JezykWiersz 6)

    # Wyszarzony do momentu, w ktorym znajdzie sie konto majace grupy - bez tego przycisk
    # otwieralby puste okno i nie mowil dlaczego. Dostepnoscia steruje JEDNO miejsce:
    # Set-JezykPrzyciskGrupy w Jezyk-3-Widok.ps1. Pion dostaje na koncu, z wyrownaniem.
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
    # Wysokosc WYLICZANA z ostatniego wiersza, a nie wpisana: dolozenie kolejnego pola nie
    # wymaga wtedy przeliczania jej na piechote. Panel jest nizszy od panelu konta i tak ma
    # zostac - widok komputera odpowiada na mniej pytan, a okno kurczy sie razem z nim
    # (Set-JezykWysokoscOkna czyta wysokosc wprost stad).
    # Bez zapasu pod ostatnim polem - ta sama arytmetyka, co w panelu konta wyzej.
    $pnlKomputer.Size    = [System.Drawing.Size]::new($Script:SzerokoscOkna,
                                                     ($kompWiersz5 + $Script:OdstepPodEtykieta +
                                                      $wysokoscStatusu))
    $pnlKomputer.Visible = $false

    $lblKompKatalog = New-JezykEtykieta 'Katalog komputera:' $Script:Margines $kompWiersz0
    $txtKompKatalog = New-JezykPole $Script:Margines ($kompWiersz0 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    # Droga ODWROTNA do pola "Ostatnio uzywany komputer" w widoku konta: tam z loginu
    # szukamy maszyny, tu z maszyny szukamy uzytkownika. Zrodlo to samo - inwentaryzacja
    # SCCM - wiec i tu przy etykiecie stoi przycisk "!" na wypadek jej milczenia.
    $lblKompUzytkownik = New-JezykEtykieta 'Ostatnio zalogowany użytkownik:' $Script:Margines $kompWiersz1
    $txtKompUzytkownik = New-JezykPole $Script:Margines ($kompWiersz1 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $btnInfoUzytkownik = New-JezykPrzyciskInfo 'Uzytkownik'

    # Wlasciciel obiektu w AD razem z data zalozenia - jedno pole, bo to jedna odpowiedz
    # na jedno pytanie. Przycisk NIEBIESKI, jak przy komputerze wspoldzielonym: to nie
    # usterka, tylko realna niejednoznacznosc TEGO wyniku - AD wpisuje jako wlasciciela
    # grupe, gdy obiekt zakladal czlonek Administratorow domeny, i nazwiska nie da sie
    # wtedy z niego odczytac. Zapala sie wylacznie wtedy, gdy pole nie nazywa osoby.
    $lblKompTworca = New-JezykEtykieta 'Dodany do AD przez:' $Script:Margines $kompWiersz2
    $txtKompTworca = New-JezykPole $Script:Margines ($kompWiersz2 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna
    $btnInfoTworca = New-JezykPrzyciskInfo 'Tworca'
    Set-JezykWyglad $btnInfoTworca 'InfoNiebieski' -Rejestruj

    # Konto komputera wylaczone w AD widac w "Centrum administracyjnym Active Directory"
    # wyszarzonym monitorkiem z kropka - nazwa obiektu wyglada wtedy tak samo jak zawsze,
    # wiec bez tego pola nie da sie tego z okna zauwazyc. Pole KOLOROWANE, bo niesie
    # werdykt: zielone wlaczone, czerwone wylaczone, neutralne "nie wiadomo".
    $lblKompWlaczone = New-JezykEtykieta 'Konto komputera w AD:' $Script:Margines $kompWiersz3
    $txtKompWlaczone = New-JezykPole $Script:Margines ($kompWiersz3 + $Script:OdstepPodEtykieta) $Script:SzerokoscPelna

    # Dostepnosc maszyny i jej karta sieciowa - ten sam komplet, co w widoku konta, tylko
    # po tej stronie okna maszyna jest TEMATEM, a nie znaleziskiem. Jedyny w tym panelu
    # wiersz o dwoch kolumnach: oba pola sa krotkie, a przycisk "Pinguj" potrzebuje prawego
    # brzegu - dokladnie jak tam.
    #
    # KOLOR SONDY NIESIE POLE ADRESU IP. Po tamtej stronie okna barwi sie napis z nazwa
    # maszyny, ale tutaj takiego pola nie ma: nazwe wpisuje operator, wiec nie ma czego
    # barwic. Adres jest przy tym wpisywany TAKZE wtedy, gdy maszyna milczy - DNS ja zna,
    # a to osobny fakt od tego, czy odpowiada.
    $lblKompMac = New-JezykEtykieta 'Adres MAC:' $Script:Margines $kompWiersz4
    $txtKompMac = New-JezykPole $Script:Margines ($kompWiersz4 + $Script:OdstepPodEtykieta) $Script:SzerokoscKolumny
    # Przycisk NIEBIESKI jak przy blizniaczym polu: brak dopasowania karty to zwykly,
    # spodziewany wynik (inwentaryzacja bywa starsza od dzierzawy DHCP), a nie usterka.
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

    # "Polacz" stoi NAD "Pinguj", w linii etykiety - tak samo jak w widoku konta. Tam
    # dzieli wiersz z wykrzyknikami, ktore koncza sie razem z polem, czyli przed nim;
    # tutaj etykieta 'Adres IP:' jest krotka i nie ma przy niej wykrzyknika, a reszta
    # wiersza stoi pusta az do prawego brzegu kolumny. Wspolrzedne i tak biora sie
    # Z SASIADA, nie z siatki.
    $btnKompPolacz           = New-Object System.Windows.Forms.Button
    $btnKompPolacz.Text      = ''
    $btnKompPolacz.Tag       = 'Połącz'
    $btnKompPolacz.Width     = $szerokoscPingu
    $btnKompPolacz.Height    = $wysokoscPola
    $btnKompPolacz.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnKompPolacz 'Przycisk' -Rejestruj
    $btnKompPolacz.Visible   = $false
    $btnKompPolacz.TabStop   = $false

    # "Dyski" staje OBOK "Polacz", a nie pod nim: pion tej kolumny jest domkniety - nad
    # "Pinguj" stoi "Polacz", a nad "Polacz" pole "Konto komputera w AD". W poziomie
    # miejsce jest, bo etykieta 'Adres IP:' konczy sie daleko przed prawym brzegiem.
    #
    # PRZYCISK ZNIKA I POJAWIA SIE, tak samo jak sasiad - rozni ich tylko to, ze "Dyski"
    # nie pyta o zadna sciezke z konfiguracji: udzialy administracyjne zaklada system sam.
    # Warunki obu stoja w Set-JezykPrzyciskiZdalne i tam tez jest napisane, dlaczego
    # chowamy je takze w stanie PRZEJSCIOWYM, wbrew regule od "Odblokuj konto".
    #
    # STAN POCZATKOWY IDZIE WIEC PRZEZ Visible, A NIE Enabled. Zostawione tu dawne
    # Enabled = $false przezylo by cale zycie okna - dostepnoscia nie steruje juz nic -
    # i przycisk bylby widoczny, ale trwale szary. Nic by tego nie zglosilo.
    $btnKompDyski           = New-Object System.Windows.Forms.Button
    $btnKompDyski.Text      = ''
    $btnKompDyski.Tag       = 'Dyski'
    $btnKompDyski.Width     = $szerokoscPingu
    $btnKompDyski.Height    = $wysokoscPola
    $btnKompDyski.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    Set-JezykWyglad $btnKompDyski 'Przycisk' -Rejestruj
    $btnKompDyski.Visible   = $false
    $btnKompDyski.TabStop   = $false

    # Dwie linijki, tak samo jak w widoku konta: to pole niesie komunikaty o niepowodzeniu
    # zapytania do SCCM, rownie dlugie. Jedno pole dwulinijkowe, a drugie jednolinijkowe
    # wygladaloby jak usterka.
    #
    # Przycisk "!" WYLACZNIE dla nieudanego uruchomienia zdalnej konsoli - pelna tresc
    # wyjatku razem ze sciezka z konfiguracji nie miesci sie w dwoch linijkach pola.
    # Na kazdej innej drodze gasnie, bo Status: sam z siebie niczego nie ukrywa.
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

    # PAS PODPISU: dwa napisy i ikonka motywu, wszystko na JEDNEJ LINII PISMA. Wysokosc
    # pasa ($Script:WysokoscPasaPodpisu) i jego czcionka sa policzone NA POCZATKU tej
    # funkcji, bo z tej samej liczby bierze sie wysokosc okna - dwie kopie rozjechalyby sie
    # przy pierwszej zmianie i podpis wyladowalby obok dolnej krawedzi.
    # Podpis autora lezy POZA panelami, wiec widac go w obu trybach.
    #
    # PION ZEROWY, jak przy etykietach gornego pasa: dol okna zmienia sie razem z trybem,
    # wiec pas podpisu dostaje wspolrzedna dopiero od Set-JezykWysokoscOkna - i tam stoi
    # jedyna kopia tego wzoru.
    $lblAutor           = New-JezykEtykieta ('Autor: ' + $Script:Config.Autor) `
                                            $Script:Margines 0
    Set-JezykWyglad $lblAutor 'Podpis' -Rejestruj
    $lblAutor.Font      = $czcionkaPasa

    # Numer wersji na DRUGIM koncu tego samego pasa - prawa polowa stala pusta, wiec napis
    # nie kosztuje ani jednego piksela wysokosci okna i widac go w obu trybach.
    #
    # Y BIERZEMY Z PODPISU, a nie drugie "- 20" wpisane wprost: dwie kopie tej samej
    # wspolrzednej rozjada sie przy pierwszej zmianie wysokosci pasa, a rozjazd o kilka
    # pikseli na dole okna jest dokladnie tym, czego nikt nie zauwazy w kodzie.
    # LEWA wspolrzedna zostaje policzona nizej, w sekcji wyrownania - patrz tam.
    $lblWersja           = New-JezykEtykieta ('Wersja: ' + $Script:Config.Wersja) $Script:Margines $lblAutor.Top
    Set-JezykWyglad $lblWersja 'Podpis' -Rejestruj
    $lblWersja.Font      = $lblAutor.Font

    # PRZYCISK MOTYWU - ksiezyc przy jasnym oknie, slonce przy ciemnym. Stoi w tym samym
    # pustym pasie, co oba napisy, wiec nie kosztuje ani jednego piksela wysokosci okna.
    # LEWA wspolrzedna zostaje policzona nizej, w sekcji wyrownania - patrz tam.
    #
    # BEZ RAMKI: ma wygladac jak ikonka wpisana w pas podpisu, a nie jak klawisz obok
    # dwoch szarych napisow. Wyzerowane marginesy wewnetrzne z tego samego powodu, co przy
    # przyciskach "!" - bez nich rysunek nie miesci sie w kwadracie.
    #
    # BOK Z WYSOKOSCI PASA, nie ze stalej: pudelko ikonki ma byc takie samo, jak pudelko
    # obu napisow - inaczej nie da sie ich postawic na jednej linii pisma.
    $btnMotyw           = New-Object System.Windows.Forms.Button
    $btnMotyw.Size      = [System.Drawing.Size]::new($Script:WysokoscPasaPodpisu, $Script:WysokoscPasaPodpisu)
    $btnMotyw.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMotyw.FlatAppearance.BorderSize = 0
    $btnMotyw.TabStop   = $false
    $btnMotyw.Padding   = [System.Windows.Forms.Padding]::new(0)
    $btnMotyw.Margin    = [System.Windows.Forms.Padding]::new(0)
    Set-JezykWyglad $btnMotyw 'Ikona' -Rejestruj
    $btnMotyw.Add_Paint({ Set-JezykRysunekMotywu -Grafika $_.Graphics -Bok $this.Width })

    # KWADRATY ZE STRZALKA dla trzech list rozwijanych - patrz New-JezykStrzalkaListy.
    # Wspolrzedne dostana nizej, w sekcji wyrownania: biora sie z list, a te znaja swoja
    # wysokosc dopiero po odziedziczeniu czcionki okna.
    $strzDomeny = New-JezykStrzalkaListy
    $strzTryb   = New-JezykStrzalkaListy
    $strzWynik  = New-JezykStrzalkaListy

    $form.Controls.AddRange(@($lblDomena, $cmbDomena, $lblPodaj, $cmbTryb,
                              $txtSzukaj, $jezSzukania, $btnSzukaj, $cmbWynik,
                              $pnlKonto, $pnlKomputer, $lblAutor, $lblWersja, $btnMotyw,
                              $strzDomeny, $strzTryb, $strzWynik))

    # NA SAM WIERZCH. W kolekcji Controls pozycja zero znaczy "najwyzej", a AddRange dokleja
    # na koniec, czyli NAJNIZEJ - kwadraty wyladowalyby pod listami, ktore maja zakrywac,
    # i nie byloby po nich sladu. WinForms nie zglasza tego niczym: kontrolka jest w oknie,
    # ma wspolrzedne i po prostu jej nie widac.
    foreach ($strzalka in @($strzDomeny, $strzTryb, $strzWynik)) {
        $form.Controls.SetChildIndex($strzalka, 0)
    }

    # --- WYROWNANIE W PIONIE ---------------------------------------------------------
    # CALE wyrownanie stoi TUTAJ, po dodaniu kontrolek do okna, i nie da sie go przeniesc
    # wyzej: kontrolka dziedziczy czcionke okna dopiero w momencie dodania, wiec kazdy pomiar
    # tekstu zrobiony wczesniej mierzylby czcionke domyslna.
    #
    # PRZYCISKI NIE ROSNA I NIE MA TU CZEGO PRZELICZAC: kazdy ma wysokosc pola, nadana przy
    # budowie, bo napis rysuje mu Set-JezykRysunekNapisuPrzycisku w calym prostokacie i nie
    # ma sie gdzie uciac.

    Set-JezykSrodekTekstu $lblDomena $cmbDomena.Height
    Set-JezykSrodekTekstu $lblPodaj  $cmbTryb.Height

    # OBA NAPISY PASA DOSTAJA PUDELKO O WYSOKOSCI IKONKI, a ich tekst srodkuje sie w nim.
    # Bez tego napis ma wysokosc SAMEGO TEKSTU (AutoSize), ikonka - swoja wlasna, a
    # srodkowanie jednego prostokata na drugim ustawia w jednej linii PROSTOKATY, a nie
    # linie pisma: ikonka wychodzila przez to nizej niz napis. To ten sam powod, dla
    # ktorego Set-JezykSrodekTekstu w ogole istnieje - patrz komentarz przy niej.
    #
    # Musi padac PRZED dosuwaniem do prawej: zdejmuje AutoSize i nadaje rozmiar, a
    # dosuwanie czyta juz Width.
    Set-JezykSrodekTekstu $lblAutor  $Script:WysokoscPasaPodpisu
    Set-JezykSrodekTekstu $lblWersja $Script:WysokoscPasaPodpisu

    # Napis z wersja dosuwamy do prawego marginesu DOPIERO TUTAJ i z tego samego powodu,
    # ktory opisuje komentarz nad ta sekcja: New-JezykEtykieta wlacza AutoSize, a etykieta
    # dziedziczy czcionke okna dopiero w momencie dodania - Width odczytany wczesniej
    # bylby zmierzony czcionka domyslna i napis wyladowalby obok marginesu, tym bardziej
    # przy DPI 125-150%.
    Set-JezykDoPrawej @($lblWersja) ($Script:SzerokoscOkna - $Script:Margines)

    # Ikonka motywu NA LEWO OD NAPISU Z WERSJA i liczona OD NIEGO, a nie od krawedzi okna:
    # napis ma AutoSize, wiec jego szerokosc zalezy od czcionki systemu i przy DPI 125-150%
    # rosnie. Liczba wpisana tutaj trzymalaby sie wylacznie przy 100% i przy wiekszej
    # czcionce ikonka wlazlaby pod napis.
    #
    # GORNA KRAWEDZ WPROST Z NAPISU: oba pudelka maja juz te sama wysokosc, wiec wspolna
    # gora znaczy wspolna linie pisma - i nie zalezy od tego, co policzyl AutoSize.
    $btnMotyw.Top = $lblWersja.Top
    Set-JezykDoPrawej @($btnMotyw) ($lblWersja.Left - $Script:OdstepIkonyMotywu)

    # Wysokosc jeza bierze sie z listy domen, a nie z liczby: pas ma rosnac razem z nia,
    # gdy czcionka systemu urosnie przy DPI 125-150%. Musi stac TUTAJ, bo dopiero teraz
    # lista zna swoja rzeczywista wysokosc.
    $jezSzukania.Height = $cmbDomena.Height

    # SRODEK PIERWSZEGO WIERSZA Z POMIARU TEJ LISTY, nie z wysokosci pola. Lista rozwijana
    # bierze wysokosc z ItemHeight i przy zwyklej czcionce jest o piksel nizsza od pola,
    # wiec margines liczony z pola wychodzil o piksel szerszy, niz mowi stala. Wysokosc
    # listy jest prawdziwa dopiero tutaj - po dodaniu jej do okna.
    $srodekDomeny = Get-JezykSrodekWiersza $cmbDomena.Height
    # Z PIERWSZEGO SRODKA, nie druga kopia tej samej liczby: dwie kopie rozjada sie przy
    # pierwszej zmianie gornego marginesu.
    $srodekPodaj  = $srodekDomeny + $Script:PasekDomeny

    Set-JezykSrodekPionowy @($lblDomena, $cmbDomena, $jezSzukania) $srodekDomeny
    Set-JezykSrodekPionowy @($lblPodaj, $cmbTryb, $txtSzukaj, $btnSzukaj) $srodekPodaj

    # KWADRATY ZE STRZALKA STAJA NA WIERZCHU SWOICH LIST - dopiero tutaj, bo dwie z nich
    # dostaly gorna krawedz linijke wyzej, a wysokosc znaja od WinForms.
    #
    # SZEROKOSC PRZYCISKU LISTY LICZY WINDOWS, tak samo jak szerokosc paska przewijania,
    # i przy DPI 125-150% jest inna. Liczba wpisana tutaj trzymalaby sie wylacznie
    # przy 100% i przy wiekszej czcionce zostawilaby po bokach jasne paski.
    $szerStrzalki = Get-JezykSzerokoscStrzalki
    Set-JezykStrzalkaListy $cmbDomena $strzDomeny $szerStrzalki
    Set-JezykStrzalkaListy $cmbTryb   $strzTryb   $szerStrzalki
    Set-JezykStrzalkaListy $cmbWynik  $strzWynik  $szerStrzalki

    # Lista kont pokazuje sie wylacznie przy wyszukiwaniu czesciowym, a jej kwadrat nie ma
    # po co wisiec nad pustym miejscem. Stan poczatkowy bierzemy Z LISTY, dalszy - z jej
    # zdarzenia (patrz sekcja ZDARZENIA): miejsc przelaczajacych ta liste jest kilka
    # i pierwsze zapomniane zostawiloby w oknie kwadrat bez listy.
    $strzWynik.Visible = $cmbWynik.Visible

    # Zapas nad wysokoscia tekstu jest konieczny: kwadrat ma stale 13 px i w ciasnym
    # prostokacie nie miescil sie razem z napisem.
    #
    # KWADRATY I NAPISY DOSTAJA JEDNO PUDELKO. Wspolna wysokosc i wspolna gorna krawedz to
    # jedyny sposob, zeby napis stal na linii pisma kwadratu, a nie pol piksela nizej -
    # ta sama zasada, co przy ikonce motywu i napisie z wersja w pasie podpisu.
    $wysokoscZnacznika = [int][math]::Ceiling($form.Font.GetHeight()) + 8
    foreach ($znacznik in @($chkAktywne, $chkZablokowane, $chkFlagaHasla,
                            $lblAktywne, $lblZablokowane, $lblFlagaHasla)) {
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
                             $obszarFlag.Left $obszarFlag.Width `
                             @($lblAktywne, $lblZablokowane, $lblFlagaHasla) `
                             (Get-JezykOdstepZnacznika $lblAktywne.Font)

    # PION LICZONY OD LINII RAMKI, A NIE OD DisplayRectangle. GroupBox rezerwuje u gory pasek
    # na tytul nawet wtedy, gdy tytul jest pusty - a DisplayRectangle zaczyna sie DOPIERO POD
    # tym paskiem. Srodkowanie w nim spychalo wiec cala trojke o pol paska w dol i napisy
    # siedzialy nizej niz srodek ramki, ktora widac na ekranie.
    #
    # Linia ramki biegnie przez SRODEK paska tytulu, wiec widoczne wnetrze zaczyna sie
    # w polowie jego wysokosci - stad dzielenie przez dwa, a nie pominiecie paska w calosci.
    # Floor, nie [int]: [int] w PowerShellu zaokragla i przy nieparzystym pasku dawalby
    # piksel roznicy miedzy jedna a druga stacja.
    $goraRamkiFlag = [int][Math]::Floor($obszarFlag.Top / 2)
    $srodekFlag    = $goraRamkiFlag +
                     [int][Math]::Floor(($grpFlagi.ClientSize.Height - $goraRamkiFlag) / 2)
    Set-JezykSrodekPionowy @($chkAktywne, $chkZablokowane, $chkFlagaHasla,
                             $lblAktywne, $lblZablokowane, $lblFlagaHasla) $srodekFlag

    # Przy werdykcie rownanie idzie w druga strone: napis jest wiekszy od reszty okna, wiec
    # to KWADRAT dostaje jego wysokosc.
    $wysokoscWerdyktu = $lblWerdykt.PreferredSize.Height + 4
    Set-JezykSrodekTekstu $lblWerdykt $wysokoscWerdyktu $Script:NajdluzszyWerdykt
    Set-JezykSrodekTekstu $chkWerdykt $wysokoscWerdyktu

    # NAPIS OD KWADRATU, TA SAMA REGULA, CO WE FLAGACH: jedna spacja - tyle ze spacja
    # czcionki werdyktu. Dotad stal na wpisanym "Margines + 24", czyli kilkanascie pikseli
    # za kwadratem. Szerokosc kwadratu jest znana dopiero po Set-JezykSrodekTekstu, stad
    # to miejsce.
    $lblWerdykt.Left = $chkWerdykt.Left + $chkWerdykt.Width +
                       (Get-JezykOdstepZnacznika $lblWerdykt.Font)

    Set-JezykSrodekPionowy @($chkWerdykt, $lblWerdykt, $btnOdblokuj) $Script:SrodekWerdyktu

    # OBA POLA "Status:" DOSTAJA DRUGA LINIJKE. Wysokosc liczona z czcionki, a nie wpisana:
    # PreferredHeight to wysokosc JEDNEJ linii razem z ramka, wiec dokladamy do niej
    # wysokosc kolejnej. Liczba wpisana na sztywno zgadzalaby sie wylacznie przy 100% DPI -
    # ta sama zasada, co przy $wysokoscZnacznika i Set-JezykSrodekPionowy.
    #
    # $drugaLinia policzona JUZ NA POCZATKU tej funkcji, bo z tej samej liczby bierze sie
    # wysokosc obu paneli ($wysokoscStatusu) - dwie kopie rozjechalyby sie przy pierwszej
    # zmianie i pole wystawaloby poza panel.
    foreach ($pole in @($txtStatus, $txtKompStatus)) {
        $pole.Height = $pole.PreferredHeight + $drugaLinia
    }

    # --- ETYKIETY NIE MOGA SIEGNAC SWOJEGO POLA --------------------------------------
    # Regula i jej powod - patrz Set-JezykEtykietaNadPolem. Ta sama funkcja przycina
    # etykiete "Status:" w oknie grup.
    foreach ($panel in @($pnlKonto, $pnlKomputer)) {
        foreach ($kontrolka in $panel.Controls) {
            if ($kontrolka -is [System.Windows.Forms.Label]) { Set-JezykEtykietaNadPolem $kontrolka }
        }
    }

    # --- PRZYCISKI "!" ---------------------------------------------------------------
    # Stawiane NA SAMYM KONCU wyrownania, bo pion licza z czcionki etykiet, a te dziedzicza
    # ja dopiero po dodaniu do okna - i po tym, jak wyrownanie wyzej poprzestawialo im
    # wspolrzedne pionowe.
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik,
                        $btnInfoKomputerWspoldzielony, $btnInfoTworca, $btnInfoMac,
                        $btnInfoMacMaszyny, $btnInfoStatusMaszyny)) {
        # Czcionka wyprowadzona z czcionki okna, jak przy werdykcie: wykrzyknik ma byc
        # pogrubiony takze wtedy, gdy system uzywa innej czcionki dialogow.
        $info.Font = [System.Drawing.Font]::new($form.Font.FontFamily, $form.Font.Size, [System.Drawing.FontStyle]::Bold)

        # NA WIERZCH PANELU. Wykrzyknik stoi na koncu pola, a dluga etykieta przy duzym
        # tekscie siega tam swoim pudelkiem - AddRange dodal ja wczesniej, czyli WYZEJ,
        # i zakrylaby przycisk. Ta sama pulapka, co przy kwadratach list rozwijanych.
        $info.Parent.Controls.SetChildIndex($info, 0)
    }

    # Przycisk "Pinguj" srodkuje sie w pionie na polu, ktore opisuje. Wysokosc pola liczy
    # sie z czcionki, wiec pomiar musi byc TUTAJ, po dodaniu kontrolek do okna.
    Set-JezykSrodekPionowy @($btnPinguj) `
        ($txtKomputerUzytkownika.Top + (Get-JezykPolowaWysokosci $txtKomputerUzytkownika.Height))

    # Przycisk grup srodkuje sie na polu KATALOGU, czyli na swoim sasiedzie z tego
    # samego wiersza - nie na wspolrzednej siatki. Wysokosc pola rosnie z czcionka,
    # wiec pion policzony ze stalych rozjechalby sie przy 125-150% DPI - a przycisk
    # ma wlasna wysokosc, liczona z napisu.
    Set-JezykSrodekPionowy @($btnGrupyAd) `
        ($txtKatalog.Top + (Get-JezykPolowaWysokosci $txtKatalog.Height))

    # "Polacz" LICZY SIE Z SASIADA, NIE Z SIATKI - i to jest tu istotne. Wysrodkowanie go
    # na etykiecie (tak, jak stoja przyciski "!") wygladaloby poprawnie przy 100% DPI
    # i dosuwalo sie do "Pinguj" na styk przy 125-150%: etykieta i pole dzieli STALE 20 px
    # ($Script:OdstepPodEtykieta), a wysokosc obu rosnie z czcionka. Odjete od gotowego Top
    # sasiada daje odstep, ktory nie zalezy od DPI w ogole.
    $odstepPionowyPolacz = 2
    $btnPolacz.Left = $btnPinguj.Left
    $btnPolacz.Top  = $btnPinguj.Top - $btnPolacz.Height - $odstepPionowyPolacz

    # WYZSZE PRZYCISKI ZJADAJA ZAPAS WIERSZA. Para ma na siebie stale 58 px skoku wiersza,
    # a przy duzym tekscie oba przyciski rosna z napisem - "Polacz" wszedlby wtedy od dolu
    # na pole "Imie i nazwisko". Zsuwamy wtedy OBA: pod "Pinguj" jest wolne az do pola
    # nastepnego wiersza, bo etykieta nad nim ("Adres IP:") stoi po lewej stronie kolumny.
    Set-JezykPonizejPola @($btnPolacz, $btnPinguj) $txtImieNazwisko $odstepPionowyPolacz

    # KAZDY WYKRZYKNIK KONCZY SIE RAZEM ZE SWOIM POLEM - powod przy
    # Set-JezykPrzyciskPrzyEtykiecie.
    #
    # CZERWONY I NIEBIESKI PRZY NAZWIE MASZYNY STOJA W TYM SAMYM MIEJSCU. Nie swieca nigdy
    # razem: blad SCCM konczy zapytanie, zanim wiadomo, czy maszyna jest wspoldzielona,
    # a Update-JezykKomputerWTle gasi niebieski przy kazdym bledzie. Dawniej para stala
    # obok siebie, wiec samotny czerwony - czyli zwykly przypadek - konczyl sie o caly
    # przycisk przed polem.
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoKomputer              $lblKomputerUzytkownika $txtKomputerUzytkownika
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoKomputerWspoldzielony $lblKomputerUzytkownika $txtKomputerUzytkownika
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoMac                   $lblKomputerMac         $txtKomputerMac
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoStatus                $lblStatus              $txtStatus
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoUzytkownik            $lblKompUzytkownik      $txtKompUzytkownik
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoTworca                $lblKompTworca          $txtKompTworca
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoMacMaszyny            $lblKompMac             $txtKompMac
    Set-JezykPrzyciskPrzyEtykiecie $btnInfoStatusMaszyny         $lblKompStatus          $txtKompStatus

    # Ta sama para przyciskow w widoku komputera i ta sama arytmetyka: "Pinguj" srodkuje
    # sie w pionie na polu, ktore opisuje, a "Polacz" odejmuje sie od jego gotowego Top.
    # Wspolrzedne z SASIADA, nie z siatki - pion pola rosnie z czcionka, a przyciski
    # z napisem.
    Set-JezykSrodekPionowy @($btnKompPinguj) `
        ($txtKompIp.Top + (Get-JezykPolowaWysokosci $txtKompIp.Height))

    $btnKompPolacz.Left = $btnKompPinguj.Left
    $btnKompPolacz.Top  = $btnKompPinguj.Top - $btnKompPolacz.Height - $odstepPionowyPolacz

    # "Dyski" dzieli wiersz z "Polacz" i bierze od niego OBIE wspolrzedne: wysokosc
    # przyciskow rosnie z czcionka, wiec wpisana liczba rozjechalaby te pare przy
    # pierwszym powiekszeniu tekstu w Windows.
    $btnKompDyski.Left = $btnKompPolacz.Left - $btnKompDyski.Width - $przerwaPingu
    $btnKompDyski.Top  = $btnKompPolacz.Top

    # To samo zsuniecie, co po drugiej stronie okna. Tu pole wiersz wyzej to "Konto
    # komputera w AD", a pod "Pinguj" jest wolne az do pola "Status:" - etykieta nad nim
    # stoi po lewej.
    Set-JezykPonizejPola @($btnKompDyski, $btnKompPolacz, $btnKompPinguj) `
                         $txtKompWlaczone $odstepPionowyPolacz

    # --- WIERSZE ZASILANE PRZEZ SCCM -------------------------------------------------
    # Co znika w domenie spoza DomenyZSccm - chowa i zsuwa Set-JezykUkladSccm. Opis stoi
    # PO wyrownaniu tylko dla porzadku: funkcja trzyma kontrolki, a nie ich wspolrzedne.
    #
    #   Wiersze - pola wierszy znikajacych W CALOSCI; od nich liczy sie zsuniecie. Wiersz
    #             e-maila w widoku konta nie znika, bo lewa polowa zostaje.
    #   Stale   - widoczne zawsze, gdy jest ich wiersz; powrot pokazuje je z powrotem.
    #   Zmienne - widocznosc ustawia kto inny ("!", "Polacz", "Dyski"); tu sa tylko chowane.
    #
    # NOWA KONTROLKA W TYCH WIERSZACH MUSI TU TRAFIC. Pominieta zostanie widoczna w domenie
    # bez SCCM - na miejscu wiersza, ktory wlasnie zniknal, czyli na polu, ktore tam wjechalo.
    #
    # POZA $Script:Kontrolki: rejestr trzyma kontrolki, a zestaw weryfikacyjny zaklada
    # atrape kontrolki pod kazdym kluczem, ktory widzi w kodzie.
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
        # Kwadraty ze strzalka - potrzebne procedurom zdarzen, ktore nie widza zmiennych
        # lokalnych tej funkcji.
        StrzalkaDomeny    = $strzDomeny
        StrzalkaTrybu     = $strzTryb
        StrzalkaListyKont = $strzWynik
        PanelKonto    = $pnlKonto
        PanelKomputer = $pnlKomputer
        # Pas podpisu - Set-JezykWysokoscOkna zjezdza z nim za dolna krawedzia okna przy
        # kazdej zmianie trybu, wiec musi go widziec z rejestru.
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
        TxtKomputerMac         = $txtKomputerMac
        PrzyciskPinguj         = $btnPinguj
        PrzyciskPolacz         = $btnPolacz
        # Widok zapala go i gasi - patrz Set-JezykPrzyciskGrupy w Jezyk-3-Widok.ps1.
        PrzyciskGrupyAd        = $btnGrupyAd
        TxtKatalog        = $txtKatalog
        TxtStatus         = $txtStatus

        TxtKomputerKatalog = $txtKompKatalog
        TxtKomputerStatus  = $txtKompStatus
        # Nazwa celowo inna niz TxtKomputerUzytkownika: tamto pole jest w widoku KONTA
        # i niesie MASZYNE, to jest w widoku KOMPUTERA i niesie UZYTKOWNIKA. Podobne
        # nazwy juz raz kusily, zeby wpisac wynik nie w to pole, co trzeba.
        TxtKomputerUzytkownikMaszyny = $txtKompUzytkownik
        TxtKomputerTworca            = $txtKompTworca
        TxtKomputerWlaczone          = $txtKompWlaczone
        # Ten sam sposob odrozniania, co wyzej: przyrostek "Maszyny" znaczy "widok
        # komputera". Bez niego TxtKomputerIp z widoku konta i to pole roznilyby sie
        # niczym, a wpisany w zle pole adres wyglada dokladnie tak samo jak dobry.
        TxtKomputerIpMaszyny         = $txtKompIp
        TxtKomputerMacMaszyny        = $txtKompMac
        PrzyciskPingujMaszyny        = $btnKompPinguj
        PrzyciskPolaczMaszyny        = $btnKompPolacz
        PrzyciskDyskiMaszyny         = $btnKompDyski

        # Przyciski "!". Klucze celowo nazwane "Info" + klucz z Set-JezykInfo - ta funkcja
        # skleja nazwe sama, wiec dolozenie kolejnego pola nie wymaga jej edycji.
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
    # W scriptblockach NIE MA odwolan do zmiennych lokalnych tej funkcji - te przestana
    # istniec, zanim zdarzenie sie wydarzy.
    $btnSzukaj.Add_Click({ Invoke-JezykSearch })

    # KWADRATY ZE STRZALKA: rysunek i klikniecie. Etykieta sama z siebie listy nie otwiera,
    # wiec klikniecie trzeba podac dalej - inaczej strzalka bylaby obrazkiem, ktory wyglada
    # jak przycisk i nic nie robi. Klikniecie w reszte listy otwiera ja tak jak dotad.
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

        # PO wszystkich Receive, nie przed nimi. Odpowiedz, ktora przyszla w tym takcie,
        # zdazyla juz zgasic notke - inaczej kolejna klatka kropek nadpisalaby wynik
        # i operator ogladalby "sprawdzanie" nad praca, ktora wlasnie sie skonczyla.
        Update-JezykKropkiSprawdzania

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
            -not $Script:ZadanieNumeru -and -not $Script:ZadanieDysku -and
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
    foreach ($info in @($btnInfoStatus, $btnInfoKomputer, $btnInfoUzytkownik,
                        $btnInfoKomputerWspoldzielony, $btnInfoTworca, $btnInfoMac,
                        $btnInfoMacMaszyny, $btnInfoStatusMaszyny)) {
        $info.Add_Click({ Show-JezykInformacja ([string]$this.Tag) })
    }

    # KAZDY PRZYCISK Z NAPISEM, a nie tylko te, ktore bywaja wylaczone: napis rysujemy sami
    # we WSZYSTKICH stanach, bo to on pozwala przyciskowi byc rownym polu. Pominiety przycisk
    # zostalby po prostu PUSTY - Text ma pusty, a napis siedzi w Tag. Kolor bierze sie
    # z palety i ze stanu Enabled, wiec jedna procedura wystarcza na wszystkie.
    foreach ($przycisk in @($btnSzukaj, $btnOdblokuj, $btnPinguj, $btnPolacz,
                            $btnGrupyAd, $btnKompPinguj, $btnKompPolacz, $btnKompDyski)) {
        $przycisk.Add_Paint({ Set-JezykRysunekNapisuPrzycisku -Przycisk $this -Grafika $_.Graphics })
    }

    $cmbDomena.Add_SelectedIndexChanged({
        $Script:Config.Domena = [string]$Script:Kontrolki.Domena.SelectedItem
        # Kontrolery innej domeny to inne maszyny - zapamietana lista przestaje obowiazywac.
        $Script:KontroleryCache = @{}
        # Set-JezykWidok czysci widok, a czyszczenie gasi przycisk odblokowania i ustawia
        # jego widocznosc dla NOWEJ domeny - nie ma wiec powodu przeliczac go tu osobno.
        Set-JezykWidok
    })

    $btnOdblokuj.Add_Click({ Invoke-JezykOdblokowanie })
    $btnPinguj.Add_Click({ Invoke-JezykPing })
    $btnPolacz.Add_Click({ Invoke-JezykPolacz })
    # Ta sama obsluga, tylko zaadresowana do drugiego panelu - widok podajemy JAWNIE,
    # bo to przycisk wie, do ktorego panelu nalezy, a nie stan listy trybu.
    $btnKompPinguj.Add_Click({ Invoke-JezykPing   -Widok Maszyna })
    $btnKompPolacz.Add_Click({ Invoke-JezykPolacz -Widok Maszyna })
    # Bez -Widok: ten przycisk stoi tylko w jednym panelu, wiec nie ma czego wskazywac.
    $btnKompDyski.Add_Click({ Invoke-JezykDyski })
    $btnGrupyAd.Add_Click({ Show-JezykGrupyAd })

    $btnMotyw.Add_Click({ Invoke-JezykPrzelaczenieMotywu })

    $cmbTryb.Add_SelectedIndexChanged({ Set-JezykWidok })
    $cmbWynik.Add_SelectedIndexChanged({ Invoke-JezykWyborKonta })

    # Focus() wywolany wczesniej nie zadziala - okna jeszcze nie widac. Z tego samego
    # powodu stoi tu druga czesc motywu: pasek tytulu i paski przewijania adresuje sie
    # UCHWYTEM OKNA, a ten powstaje dopiero teraz.
    $form.Add_Shown({
        $Script:Kontrolki.PoleSzukaj.Focus()
        Set-JezykMotywSystemowy

        # Wymiary list sa prawdziwe dopiero teraz - patrz Update-JezykOprawaList.
        Update-JezykOprawaList
    })

    # ... i jeszcze raz, gdyby ktorakolwiek z list zmienila rozmiar pozniej. Kwadrat ze
    # strzalka ma wspolrzedne wyliczone z listy, wiec musi isc za nia.
    foreach ($lista in @($cmbDomena, $cmbTryb, $cmbWynik)) {
        $lista.Add_SizeChanged({ Update-JezykOprawaList })
    }

    # WYSOKOSC OKNA I PION PASA PODPISU - tym samym wywolaniem, co przy kazdej pozniejszej
    # zmianie trybu, wiec okno wstaje dokladnie w tym rozmiarze, ktory dostaje po powrocie
    # na ten sam widok. WIDOK PODAJEMY JAWNIE: startowym trybem jest konto, a wolajacy
    # zawsze wie, czyj panel renderuje - zgadywanie ze stanu interfejsu jest tu pulapka
    # opisana przy Set-JezykWidok.
    Set-JezykWysokoscOkna $Script:PanelZListą $pnlKonto.Height

    # MOTYW NA SAMYM KONCU, gdy wszystkie kontrolki maja juz swoje role. Wczesniej czesc
    # z nich jeszcze nie istnieje, a nieprzemalowana kontrolka nie zglasza sie niczym -
    # po prostu zostaje jasna w ciemnym oknie.
    Set-JezykMotyw $Script:Motyw

    $form
}

#endregion
