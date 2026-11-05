// Jezyk.exe - rozpakowuje pliki Jezyka do %TEMP% i uruchamia je przez Windows PowerShell 5.1 (README: Kod > Jezyk-Exe.cs).
// Zabraniam modyfikacji i dalszego rozwoju skryptu bez:
// - Wcześniejszego pozwolenia na modyfikację kodu przez osobę trzecią.
// - Uwzględnienia mnie (kacp3rn) jako głównego autora skryptu.

// Kompiluje go Jezyk-Kompilator.cmd kompilatorem C# 5 z .NET Framework 4.x - bez nowszej skladni.

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

// Wersje pliku i produktu dopisuje kompilator (Jezyk-Wersja.cs z Jezyk-1-Srodowisko.ps1) - drugi taki atrybut tutaj to blad kompilacji.
[assembly: AssemblyTitle("Jeżyk")]
[assembly: AssemblyProduct("Jeżyk")]
[assembly: AssemblyCopyright("kacp3rn")]

public static class JezykExe
{
    // Tyle najwyzej czeka start na folder aktualizacji; potem rusza wersja z komputera, bez komunikatu.
    public const int LimitSprawdzaniaMs = 3000;
    public const int LimitKopiowaniaMs  = 30000;

    // Wiekszy plik na pewno nie jest Jezyk.exe - nie czytamy go z sieci.
    private const long NajwiekszyExe = 20L * 1024 * 1024;

    private const uint MB_YESNO         = 0x4;
    private const uint MB_ICONERROR     = 0x10;
    private const uint MB_ICONQUESTION  = 0x20;
    private const uint MB_ICONWARNING   = 0x30;
    private const uint MB_SETFOREGROUND = 0x10000;
    private const int  IDYES            = 6;

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBoxW(IntPtr okno, string tresc, string tytul, uint styl);

    public static int Main()
    {
        try
        {
            // Uwaga: uchwyt katalogu biezacego dziedziczy proces potomny - zmieniamy go przed startem (README: Kod > Jezyk-Exe.cs).
            string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            Environment.CurrentDirectory = windows;

            Assembly exe        = Assembly.GetExecutingAssembly();
            string   sciezkaExe = exe.Location;

            // Weryfikator nowej wersji - zadna jego awaria nie moze zatrzymac startu Jezyka.
            try
            {
                SprzatnijPoAktualizacji(sciezkaExe);

                string ustawienia = TrescZasobu(exe, "Jezyk-1-Srodowisko.ps1");
                string wersja     = WartoscUstawienia(ustawienia, "Wersja");
                string wersjaZdalna;
                string zdalny = SprawdzAktualizacje(sciezkaExe, WartoscUstawienia(ustawienia, "FolderAktualizacji"),
                                                    wersja, LimitSprawdzaniaMs, out wersjaZdalna);

                if (zdalny != null &&
                    MessageBoxW(IntPtr.Zero, TrescPytania(wersja, wersjaZdalna), "Jeżyk - nowa wersja",
                                MB_YESNO | MB_ICONQUESTION | MB_SETFOREGROUND) == IDYES)
                {
                    string blad = Zaktualizuj(sciezkaExe, zdalny, wersjaZdalna, LimitKopiowaniaMs);
                    if (blad == null)
                    {
                        using (Process.Start(NowyStartExe(sciezkaExe, windows))) { }
                        return 0;
                    }
                    MessageBoxW(IntPtr.Zero, "Nie udało się zaktualizować Jeżyka: " + blad +
                                "\n\nUruchamiam wersję z tego komputera.", "Jeżyk - nowa wersja",
                                MB_ICONWARNING | MB_SETFOREGROUND);
                }
            }
            catch (Exception) { }

            string katalog = RozpakujPliki(exe, Path.Combine(Path.GetTempPath(), "Jezyk-exe"), DateTime.Now);

            string powershell = SciezkaPowershella(windows, Environment.Is64BitOperatingSystem,
                                                   Environment.Is64BitProcess);
            if (!File.Exists(powershell))
            {
                throw new FileNotFoundException("Nie znaleziono Windows PowerShella: " + powershell);
            }

            using (Process.Start(NowyStart(powershell, Path.Combine(katalog, "Kod-Jezyk.ps1"), windows))) { }
            return 0;
        }
        catch (Exception blad)
        {
            MessageBoxW(IntPtr.Zero, "Jeżyk nie mógł się uruchomić.\n\n" + blad.Message, "Jeżyk", MB_ICONERROR);
            return 1;
        }
    }

    // Swiezy folder na kazde uruchomienie - nic nie nadpisujemy pod dzialajaca kopia. Oddaje jego sciezke.
    public static string RozpakujPliki(Assembly zrodlo, string baza, DateTime teraz)
    {
        UsunStareKopie(baza, teraz.AddHours(-1));

        string katalog = Path.Combine(baza,
            teraz.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture) + "-" + Process.GetCurrentProcess().Id);
        Directory.CreateDirectory(katalog);

        foreach (string nazwa in zrodlo.GetManifestResourceNames())
        {
            using (Stream wejscie = zrodlo.GetManifestResourceStream(nazwa))
            using (FileStream wyjscie = File.Create(Path.Combine(katalog, nazwa)))
            {
                wejscie.CopyTo(wyjscie);
            }
        }
        return katalog;
    }

    // Kasuje kopie utworzone przed granica - mlodsze moga jeszcze wczytywac pliki. Nieudane sprzatanie nie blokuje startu.
    public static void UsunStareKopie(string baza, DateTime granica)
    {
        if (!Directory.Exists(baza)) return;

        string[] kopie;
        try { kopie = Directory.GetDirectories(baza); }
        catch (IOException) { return; }
        catch (UnauthorizedAccessException) { return; }

        foreach (string kopia in kopie)
        {
            try
            {
                if (Directory.GetCreationTime(kopia) < granica) Directory.Delete(kopia, true);
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }

    // Pelna sciezka powershell.exe; proces 32-bitowy widzi pod System32 katalog SysWOW64, wiec dostaje Sysnative.
    // Sklejana wprost: Path.Combine laczy wedlug biezacej platformy, a wynik ma byc zawsze sciezka windowsowa.
    public static string SciezkaPowershella(string windows, bool system64, bool proces64)
    {
        string system = (system64 && !proces64) ? "Sysnative" : "System32";
        return windows.TrimEnd('\\') + "\\" + system + "\\WindowsPowerShell\\v1.0\\powershell.exe";
    }

    // -STA dla WinForms; bez okna konsoli; PowerShell startuje w %SystemRoot%, nie w folderze exe.
    public static ProcessStartInfo NowyStart(string powershell, string skrypt, string windows)
    {
        ProcessStartInfo start = new ProcessStartInfo(powershell,
            "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + skrypt + "\"");
        start.UseShellExecute  = false;
        start.CreateNoWindow   = true;
        start.WorkingDirectory = windows;
        return start;
    }

    // --- WERYFIKATOR NOWEJ WERSJI ---------------------------------------------------------

    // Tekst wkompilowanego pliku (UTF-8, bez BOM) albo pusty napis, gdy takiego zasobu nie ma.
    public static string TrescZasobu(Assembly zrodlo, string nazwa)
    {
        using (Stream wejscie = zrodlo.GetManifestResourceStream(nazwa))
        {
            if (wejscie == null) return "";
            using (StreamReader czytnik = new StreamReader(wejscie, Encoding.UTF8, true))
            {
                return czytnik.ReadToEnd();
            }
        }
    }

    // Wartosc klucza z bloku ustawien ("Klucz = 'wartosc'") albo pusty napis.
    // Uwaga: kotwica na poczatku linii - zdalny exe przeszukujemy w calosci (README: Kod > Jezyk-Exe.cs).
    public static string WartoscUstawienia(string tekst, string klucz)
    {
        if (string.IsNullOrEmpty(tekst) || string.IsNullOrEmpty(klucz)) return "";

        Match trafienie = Regex.Match(tekst,
            "(?m)^[ \\t]*" + Regex.Escape(klucz) + "[ \\t]*=[ \\t]*(?:'([^'\\r\\n]*)'|\"([^\"\\r\\n]*)\")");
        if (!trafienie.Success) return "";
        return trafienie.Groups[1].Success ? trafienie.Groups[1].Value : trafienie.Groups[2].Value;
    }

    // Wersja zapisana w pliku exe: czesci .ps1 leza w nim bajt w bajt, wiec linia "Wersja = '...'" tez.
    public static string WersjaZPliku(string sciezka)
    {
        FileInfo plik = new FileInfo(sciezka);
        if (!plik.Exists || plik.Length > NajwiekszyExe) return "";
        return WartoscUstawienia(Encoding.UTF8.GetString(File.ReadAllBytes(sciezka)), "Wersja");
    }

    // Czy wersja zdalna jest nowsza: liczba po pierwszej kropce to ulamek dziesietny (v0.49 < v0.5 < v0.51 < v0.6),
    // dalsze liczby to kolejne czlony (v0.5 < v0.5.1, v0.5.0 to v0.5).
    public static bool CzyNowsza(string lokalna, string zdalna)
    {
        string[] a = LiczbyWersji(lokalna);
        string[] b = LiczbyWersji(zdalna);
        if (a == null || b == null) return false;

        for (int i = 0; i < Math.Max(a.Length, b.Length); i++)
        {
            string x = i < a.Length ? a[i] : "0";
            string y = i < b.Length ? b[i] : "0";
            int roznica;
            if (i == 1)
            {
                // Ulamek: cyfry dopelnione zerami z prawej do rownej dlugosci (5 to 50, 05 zostaje 05).
                int dlugosc = Math.Max(x.Length, y.Length);
                roznica = string.CompareOrdinal(x.PadRight(dlugosc, '0'), y.PadRight(dlugosc, '0'));
            }
            else
            {
                roznica = int.Parse(x, CultureInfo.InvariantCulture).CompareTo(int.Parse(y, CultureInfo.InvariantCulture));
            }
            if (roznica != 0) return roznica < 0;
        }
        return false;
    }

    // Liczby z napisu wersji (cyfry jak w napisie - w ulamku licza sie zera wiodace) albo null,
    // gdy nie ma zadnej albo ktoras sie nie miesci.
    private static string[] LiczbyWersji(string wersja)
    {
        MatchCollection liczby = Regex.Matches(wersja ?? "", "[0-9]+");
        if (liczby.Count == 0) return null;

        string[] wynik = new string[liczby.Count];
        for (int i = 0; i < liczby.Count; i++)
        {
            int liczba;
            if (!int.TryParse(liczby[i].Value, NumberStyles.None, CultureInfo.InvariantCulture, out liczba)) return null;
            wynik[i] = liczby[i].Value;
        }
        return wynik;
    }

    // Wynik pracy w watku tla albo null po terminie - niedostepny udzial potrafi milczec dziesiatki sekund.
    // Kazdy wyjatek to null: wyjatek, ktory wyszedlby z watku, zamknalby caly proces.
    public static string ZTerminem(Func<string> praca, int limitMs)
    {
        string wynik = null;
        Thread watek = new Thread(() =>
        {
            try { wynik = praca(); }
            catch (Exception) { wynik = null; }
        });
        watek.IsBackground = true;
        watek.Start();
        return watek.Join(limitMs) ? wynik : null;
    }

    // Sciezka nowszego Jezyk.exe z folderu aktualizacji albo null: bez folderu, bez odpowiedzi w terminie, bez nowszej wersji.
    public static string SprawdzAktualizacje(string sciezkaExe, string folder, string wersjaLokalna,
                                             int limitMs, out string wersjaZdalna)
    {
        wersjaZdalna = "";
        if (string.IsNullOrEmpty(sciezkaExe) || string.IsNullOrEmpty(folder)) return null;

        string zdalny;
        try
        {
            zdalny = Path.Combine(folder, "Jezyk.exe");

            // Exe uruchomiony prosto z folderu aktualizacji jest juz ta wersja.
            char[] ukosniki = new char[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar };
            string folderExe = Path.GetDirectoryName(Path.GetFullPath(sciezkaExe)).TrimEnd(ukosniki);
            if (string.Equals(Path.GetFullPath(folder).TrimEnd(ukosniki), folderExe, StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }
        }
        catch (ArgumentException)     { return null; }
        catch (NotSupportedException) { return null; }
        catch (IOException)           { return null; }

        string wersja = ZTerminem(() => WersjaZPliku(zdalny), limitMs);
        if (string.IsNullOrEmpty(wersja) || !CzyNowsza(wersjaLokalna, wersja)) return null;

        wersjaZdalna = wersja;
        return zdalny;
    }

    // Podmienia ten exe na zdalny: kopia obok (.nowy), sprawdzenie wersji, zamiana nazw. Null = gotowe, inaczej opis bledu.
    // Uwaga: dzialajacego exe nie da sie nadpisac, da sie zmienic mu nazwe - stad .stary (README: Kod > Jezyk-Exe.cs).
    public static string Zaktualizuj(string sciezkaExe, string zdalny, string wersjaZdalna, int limitMs)
    {
        string nowy  = sciezkaExe + ".nowy";
        string stary = sciezkaExe + ".stary";

        // Kazda porazka konczy sie opisem dla operatora, a nie cisza - kliknal "Tak".
        string blad = ZTerminem(() =>
        {
            try { File.Copy(zdalny, nowy, true); return ""; }
            catch (Exception e) { return e.Message; }
        }, limitMs);
        if (blad == null)  { UsunCicho(nowy); return "folder sieciowy nie odpowiada."; }
        if (blad.Length > 0) { UsunCicho(nowy); return blad; }

        // Urwana albo podmieniona kopia nie ma tej wersji, ktora proponowalismy.
        string pobrana;
        try { pobrana = WersjaZPliku(nowy); }
        catch (Exception e) { UsunCicho(nowy); return e.Message; }
        if (pobrana != wersjaZdalna)
        {
            UsunCicho(nowy);
            return "pobrany plik nie zawiera wersji " + (wersjaZdalna ?? "").Trim() + ".";
        }

        try
        {
            if (File.Exists(stary)) File.Delete(stary);
            File.Move(sciezkaExe, stary);
        }
        catch (Exception e) { UsunCicho(nowy); return e.Message; }

        try { File.Move(nowy, sciezkaExe); }
        catch (Exception e)
        {
            // Bez nowego pliku na miejscu wraca stary - inaczej skrot operatora wskazywalby pustke.
            try { File.Move(stary, sciezkaExe); }
            catch (Exception) { }
            UsunCicho(nowy);
            return e.Message;
        }
        return null;
    }

    // Sprzata po poprzedniej aktualizacji; stary proces mogl sie jeszcze nie zamknac - wtedy przy nastepnym starcie.
    public static void SprzatnijPoAktualizacji(string sciezkaExe)
    {
        if (string.IsNullOrEmpty(sciezkaExe)) return;
        UsunCicho(sciezkaExe + ".stary");
        UsunCicho(sciezkaExe + ".nowy");
    }

    public static string TrescPytania(string lokalna, string zdalna)
    {
        return "Dostępna jest nowa wersja Jeżyka.\n\n" +
               "Na tym komputerze: " + (lokalna ?? "").Trim() + "\n" +
               "W folderze sieciowym: " + (zdalna ?? "").Trim() + "\n\n" +
               "Zaktualizować teraz?";
    }

    // Start podmienionego exe - sam rozpakuje nowa wersje i nie zapyta drugi raz.
    public static ProcessStartInfo NowyStartExe(string sciezkaExe, string windows)
    {
        ProcessStartInfo start = new ProcessStartInfo(sciezkaExe);
        start.UseShellExecute  = false;
        start.WorkingDirectory = windows;
        return start;
    }

    private static void UsunCicho(string sciezka)
    {
        try { if (File.Exists(sciezka)) File.Delete(sciezka); }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
