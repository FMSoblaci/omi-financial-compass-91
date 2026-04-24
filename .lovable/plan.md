## Wynik audytu bazy wiedzy

Przeanalizowałem dwa źródła dokumentacji aplikacji:

1. **`INSTRUKTAZ_SYSTEMU.md`** (834 linie, plik w repo) — statyczna dokumentacja, **nieużywana w aplikacji** (brak importów). Wersja 1.0, grudzień 2024.
2. **Baza wiedzy w UI** (`/baza-wiedzy` → zakładka „Notatki") — 25 artykułów w 7 kategoriach (`wprowadzenie`, `dokumenty`, `raporty`, `budzet`, `konta`, `administracja`, `faq`).

### Co jest dobrze opisane

Zakładka „Notatki" w bazie wiedzy zawiera solidne, ilustrowane przewodniki dla:
- Ról i uprawnień, Dashboard, Witaj w systemie
- Dokumentów, importu CSV/MT940, KPiR, walut obcych, drag&drop, walidacji
- Raportów (tworzenie + zatwierdzanie), wizualizacji
- Budżetu (planowanie, bateria realizacji, porównania, import z pliku prowincjalnego)
- Wyszukiwania kont, planu kont
- Administracji (użytkownicy, placówki, przypomnienia)
- FAQ (50 pytań) + słownika

### Krytyczne luki — funkcje nieopisane lub źle opisane

Po porównaniu z aktualnym kodem i zmianami z ostatnich tygodni stwierdziłem **9 istotnych braków**:

| # | Brakujące/nieaktualne | Problem |
|---|---|---|
| 1 | **Opłata prowincjalna („procent na prowincję")** | Auto-generowanie operacji read-only dla kont 400/700 — brak jakiegokolwiek artykułu, mimo że to świeża, krytyczna funkcja |
| 2 | **2FA i zaufane urządzenia** | Tylko 2 wzmianki w przeglądzie ról; brak osobnego przewodnika (jak działa kod e-mail, blokada konta po 3 próbach, rate limiting) |
| 3 | **Konto 210 — Intencje** | Świeży fix logiki Wn/Ma; brak wyjaśnienia dla ekonomów, jak prawidłowo księgować przyjęcie i odprawienie intencji |
| 4 | **Import Excel formularzowy** | Trzeci typ importu (obok CSV i MT940) — pominięty w artykule „Import Danych" |
| 5 | **Tworzenie kont analitycznych** | Proces 2-stopniowy z rollbackiem (Ustawienia → Konta) — brak instrukcji dla ekonoma |
| 6 | **Multi-lokalizacja** | Użytkownicy mogą mieć przypisane wiele placówek jednocześnie — brak opisu przełączania kontekstu |
| 7 | **Bilanse przechodnie 217/149** | Standard raportowania (świetlica, pieniądze w drodze) — brak w przewodniku raportów |
| 8 | **Konto 463 — restrykcja** | Zarezerwowane dla Administracji Prowincjalnej (kategoria 1); brak ostrzeżenia w słowniku/FAQ |
| 9 | **Markdown w zgłoszeniach błędów** | Świeżo dodana obsługa formatowania Markdown w odpowiedziach — brak wzmianki w przewodniku „Zgłoszeń błędów" |

### Plus: status pliku `INSTRUKTAZ_SYSTEMU.md`

Plik jest **przestarzały (grudzień 2024)** i niepowiązany z aplikacją. Zawiera m.in. nieaktualne pojęcia („Proboszcz" jako osobna rola podczas gdy w bazie są 4 role: ekonom, proboszcz, prowincjal, admin — proboszcz w UI ma role tylko nadzorczą), brak wszystkich 9 powyższych funkcji. **Sugeruję usunięcie pliku z repo** (nie jest używany) lub zostawienie do archiwum — do decyzji.

---

## Plan uzupełnienia bazy wiedzy

Dodam **9 nowych artykułów** do tabeli `admin_notes` (widocznych w `/baza-wiedzy` → Notatki) oraz zaktualizuję 2 istniejące artykuły. Wszystkie z formatowaniem Markdown (tabele, listy, emoji, bloki kodu — bo komponent `MarkdownRenderer` to obsługuje).

### Nowe artykuły

1. **`dokumenty` / 💸 Opłata prowincjalna („procent na prowincję") — przypięty**
   Jak działa auto-generowanie, kiedy się tworzy (Wn/Ma/oba), dlaczego jest read-only, gdzie konfiguracja (Administracja → Opłata prowincjalna), zachowanie przy imporcie.

2. **`administracja` / 🔐 Bezpieczeństwo — 2FA, kody e-mail, blokady — przypięty**
   Pełen przepływ logowania: kod 6-cyfrowy, zaufane urządzenia, blokada po 3 próbach, rate limiting, jak odblokować konto.

3. **`raporty` / 🕯️ Konto 210 — Intencje mszalne**
   Strona Ma = przyjęcie intencji (zwiększa zobowiązanie), strona Wn = odprawienie/przekazanie (zmniejsza zobowiązanie). Wzór salda: B.O. + przyjęte − odprawione. Z wyjaśnieniem dlaczego (konto pasywne).

4. **`dokumenty` / 📤 Import Excel formularzowy**
   Trzecia ścieżka importu obok CSV i MT940 — szablon, mapowanie, walidacja.

5. **`konta` / ➕ Tworzenie kont analitycznych — krok po kroku**
   Ekonom: Ustawienia → Konta → wybierz konto → „Dodaj analityczne", jak wygląda numer (XXX-Y-Z-suffix), kiedy jest wymagane (restrykcje na 4xx/7xx).

6. **`wprowadzenie` / 🏘️ Praca z wieloma placówkami**
   Dla użytkowników z dostępem do >1 lokalizacji — przełączanie kontekstu, gdzie widać która placówka jest aktywna.

7. **`raporty` / 🔁 Bilanse przechodnie — konta 217 i 149**
   Świetlica (217) i Pieniądze w drodze (149) — jak są obsługiwane w raportach miesięcznych.

8. **`konta` / 🚫 Konto 463 — ograniczenia**
   Zarezerwowane dla Administracji Prowincjalnej, ekonomowie z innych placówek nie mogą go użyć.

9. **`administracja` / 🐛 Zgłaszanie błędów + obsługa Markdown**
   Jak działa przycisk „Zgłoś błąd", co zostaje załączone (screenshot, przeglądarka), jak admin odpowiada, **i że odpowiedzi obsługują Markdown** (nagłówki, listy, tabele, kod).

### Aktualizacja istniejących

- **„📥 Import Danych - CSV i MT940"** → przemianowany na **„📥 Import Danych — CSV, MT940 i Excel"**, dodana sekcja o trzecim typie importu i wzmianka, że importery czekają aż dane prowincjalne się załadują (wskaźnik gotowości).
- **„👥 Role i Uprawnienia"** → dodać krótki paragraf o multi-lokalizacji.

### Implementacja techniczna

Wszystkie wpisy trafią do tabeli `admin_notes` jako migracja SQL (INSERT) z:
- `category` jednym z 7 istniejących
- `visible_to` = `{ekonom, proboszcz, prowincjal, admin}` (lub węższe gdzie sensowne)
- `pinned` = true dla 2 najważniejszych (opłata prowincjalna, bezpieczeństwo 2FA)
- `created_by` = istniejący admin (pobiorę pierwszy `id` z `profiles where role='admin'`)

### Pytanie otwarte

Czy plik **`INSTRUKTAZ_SYSTEMU.md`** (z grudnia 2024, nieużywany w UI) ma:
- (a) zostać usunięty z repo,
- (b) zostać zaktualizowany jako kanoniczna offline-dokumentacja,
- (c) zostać tak jak jest?

Jeśli (b) — dorzucę pełną aktualizację (~200 dodatkowych linii pokrywających 9 nowych obszarów). Jeśli (a) lub (c) — pomijam plik i skupiam się tylko na bazie wiedzy w UI.

---

## Co zrobi po Twojej akceptacji

1. Utworzę migrację SQL dodającą 9 nowych artykułów + aktualizację 2 istniejących.
2. (Opcjonalnie, zależnie od odpowiedzi powyżej) zaktualizuję lub usunę `INSTRUKTAZ_SYSTEMU.md`.
3. Po wdrożeniu: w `/baza-wiedzy` → Notatki będzie 34 artykuły pokrywające 100% aktualnych funkcji aplikacji.

Czas wykonania: ~5–7 minut.