-- Add 9 new knowledge base articles + update 2 existing
DO $$
DECLARE
  v_admin_id uuid := 'c921e54f-03d5-4cc0-a99e-b051a59a7e75';
BEGIN

-- 1. Opłata prowincjalna
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('💸 Opłata prowincjalna - "procent na prowincję"', 'dokumenty', true, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 💸 Opłata prowincjalna („procent na prowincję")

> ℹ️ **Funkcja w skrócie:** System automatycznie tworzy drugą operację „procent na prowincję" za każdym razem, gdy w dokumencie pojawi się konto z listy wyzwalającej. Nowa operacja jest w trybie **tylko do odczytu** (read-only) i nie da się jej zmodyfikować ani usunąć ręcznie — chyba że usuniesz operację bazową.

---

## 1. Kiedy automatycznie powstaje?

Operacja „procent na prowincję" jest tworzona, **gdy konto wyzwalające** (skonfigurowane w panelu administratora) pojawi się w transakcji po **którejkolwiek ze stron**:

| Strona Wn | Strona Ma | Czy się tworzy? |
|-----------|-----------|-----------------|
| Konto wyzwalające | Inne konto | ✅ TAK |
| Inne konto | Konto wyzwalające | ✅ TAK |
| Konto wyzwalające | Konto wyzwalające | ✅ TAK |
| Inne konto | Inne konto | ❌ NIE |

To dotyczy zarówno operacji **dodawanych ręcznie**, jak i pochodzących z **importu** (CSV, MT940, Excel formularzowy, KPiR).

## 2. Jak wygląda automatyczna operacja?

Bezpośrednio pod operacją bazową pojawia się druga operacja:

| Pole | Wartość |
|------|---------|
| **Opis** | „procent na prowincję" |
| **Kwota** | (kwota bazowa × procent) — np. 5% z 1000 zł = 50 zł |
| **Konto Wn** | Konto docelowe Wn (z konfiguracji) |
| **Konto Ma** | Konto docelowe Ma (z konfiguracji) |
| **Tryb** | 🔒 **Tylko do odczytu** |

> ⚠️ **Nie próbuj edytować ani usuwać tej operacji ręcznie.** Pola są wyszarzone, a przycisk usuń jest niedostępny.

## 3. Jak ją usunąć?

Usuń **operację bazową** (tę, która ją wywołała) — system automatycznie skasuje powiązaną opłatę prowincjalną.

## 4. Co jeśli zmienię kwotę bazową?

Po edycji kwoty bazowej system **automatycznie przeliczy** opłatę prowincjalną przy zapisie dokumentu.

## 5. Konfiguracja (tylko Admin / Prowincjał)

`Administracja → Opłata prowincjalna`

Konfiguruje się tutaj:

1. **Procent opłaty** (np. 5%)
2. **Konta docelowe** — Wn i Ma dla automatycznej operacji
3. **Konta wyzwalające** — lista prefiksów kont (np. 700, 701, 750), których pojawienie się aktywuje generowanie opłaty

> 💡 **Ważne:** Wszystkie pola muszą być wypełnione, żeby funkcja działała.

## 6. Import plików — synchronizacja

Przy imporcie plików system **czeka, aż dane konfiguracyjne się załadują**. Jeśli zaczniesz import zanim ustawienia opłaty prowincjalnej będą gotowe, zobaczysz komunikat ostrzegawczy. Poczekaj kilka sekund i spróbuj ponownie.

## 7. FAQ

**P: Operacja „procent na prowincję" się nie pojawiła — co robić?**
- Sprawdź, czy konto z transakcji jest na liście wyzwalających.
- Sprawdź, czy konfiguracja jest kompletna (procent > 0, oba konta docelowe wybrane).
- Odśwież stronę i spróbuj ponownie.

**P: Czy mogę zmienić kwotę automatycznej opłaty?**
- Nie. Aby zmienić kwotę, zmień **kwotę bazową** — system przeliczy automatycznie.

**P: Czy operacja „procent na prowincję" wlicza się do bilansu dokumentu?**
- Tak. To pełnoprawna operacja księgowa.
$MD$);

-- 2. 2FA i zaufane urządzenia
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('🔐 Bezpieczeństwo - 2FA, kody e-mail, blokady', 'administracja', true, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 🔐 Bezpieczeństwo logowania

System chroni dostęp do danych finansowych za pomocą **uwierzytelniania dwuskładnikowego (2FA)** opartego na jednorazowych kodach e-mail.

---

## 1. Pierwsze logowanie z nowego urządzenia

```
1. Wpisujesz e-mail i hasło
2. System wysyła 6-cyfrowy kod na Twój e-mail
3. Wpisujesz kod (ważny 10 minut)
4. Opcjonalnie: zaznacz „Zapamiętaj to urządzenie"
5. Jesteś zalogowany ✓
```

> 💡 Jeśli zaznaczysz **„Zapamiętaj urządzenie"**, przy kolejnych logowaniach z tego samego komputera/przeglądarki nie będziesz musiał wpisywać kodu przez 30 dni.

## 2. Zaufane urządzenia

`Ustawienia → Zaufane urządzenia`

Lista wszystkich urządzeń z aktywną sesją. Możesz:
- Zobaczyć **datę ostatniego logowania** każdego urządzenia
- **Usunąć urządzenie** — następne logowanie z niego znów wymusi kod 2FA

> ⚠️ **Zalecenie bezpieczeństwa:** Usuń urządzenia, których już nie używasz, oraz wszystkie cudze urządzenia (np. komputer pożyczony).

## 3. Blokada konta po nieudanych próbach

| Liczba błędnych prób | Skutek |
|----------------------|--------|
| 1–2 | Komunikat „Nieprawidłowe hasło" |
| **3** | ⛔ **Konto zablokowane na 15 minut** |
| Po odblokowaniu | Można próbować ponownie |

## 4. Zapomniane hasło

1. Strona logowania → **„Zapomniałem hasła"**
2. Podaj e-mail
3. Otrzymasz link resetujący (ważny 24h)
4. Ustaw nowe hasło (min. 8 znaków, w tym litera i cyfra)

## 5. Limit wysyłki kodów

Kody 2FA mają limit:
- Maksymalnie **5 kodów na 15 minut** dla jednego adresu e-mail
- Po przekroczeniu zobaczysz komunikat „Spróbuj za chwilę"

## 6. Co robić, gdy nie dochodzą e-maile?

1. Sprawdź folder **spam / wiadomości-śmieci**
2. Sprawdź czy adres e-mail jest poprawny w Twoim profilu
3. Skontaktuj się z administratorem — może wyłączyć 2FA tymczasowo lub zresetować Twoje hasło ręcznie

## 7. Dla administratorów: odblokowywanie kont

`Administracja → Użytkownicy → wybierz użytkownika → „Odblokuj"`

Możesz również:
- **Wymusić wylogowanie** ze wszystkich urządzeń (usuwa wszystkie zaufane urządzenia użytkownika)
- **Zresetować hasło** ręcznie (wysyła link e-mail)
$MD$);

-- 3. Konto 210 — Intencje
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('🕯️ Konto 210 - Intencje mszalne', 'raporty', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 🕯️ Konto 210 — Intencje mszalne

Konto 210 to **konto pasywne** — reprezentuje zobowiązanie wspólnoty wobec wiernych do odprawienia mszy w intencji, którą przyjęto.

---

## 1. Kierunki księgowania

| Operacja | Strona | Co się dzieje |
|----------|--------|---------------|
| **Przyjęcie intencji** (ofiara od wiernego) | **Ma 210** | Powstaje zobowiązanie ↑ |
| **Odprawienie intencji** (msza odprawiona) | **Wn 210** | Zobowiązanie maleje ↓ |
| **Oddanie intencji** (przekazanie innej parafii) | **Wn 210** | Zobowiązanie maleje ↓ |

### Przykład 1 — przyjęcie intencji

```
Wn: 100-X-Y-Z (Kasa)        100,00 zł
Ma: 210-X-Y-Z (Intencje)    100,00 zł
Opis: „Intencja za zmarłą Marię — od rodziny"
```

### Przykład 2 — odprawienie intencji

```
Wn: 210-X-Y-Z (Intencje)    100,00 zł
Ma: 700-X-Y-Z (Przychody)   100,00 zł
Opis: „Msza odprawiona 15.04 — int. za Marię"
```

## 2. Wzór salda w raporcie miesięcznym

```
Stan końcowy = B.O. + Przyjęte − Odprawione i oddane
```

W raporcie sekcja **B. Intencje** pokazuje:

| Początek miesiąca | Odprawione i oddane | Przyjęte | Stan końcowy |
|-------------------|---------------------|----------|--------------|
| (saldo z poprzedniego miesiąca) | (suma Wn 210 w miesiącu) | (suma Ma 210 w miesiącu) | (wyliczone) |

> ✅ **System wylicza stan końcowy automatycznie** — nie wpisuj go ręcznie.

## 3. Sprawdzenie zgodności z księgą intencji (Excel)

Stan końcowy z raportu **powinien być identyczny** ze stanem w Twojej księdze intencji prowadzonej osobno (np. w Excelu).

Jeśli się nie zgadzają:

1. ✅ Sprawdź, czy wszystkie przyjęcia intencji w danym miesiącu zaksięgowano po stronie **Ma 210**
2. ✅ Sprawdź, czy wszystkie odprawienia w danym miesiącu zaksięgowano po stronie **Wn 210**
3. ✅ Sprawdź saldo otwarcia — czy zgadza się ze stanem na koniec poprzedniego miesiąca
4. ✅ Sprawdź, czy nie ma operacji „przesuniętych" do innego miesiąca (data dokumentu)

## 4. Częste błędy

❌ **Księgowanie przyjęcia po stronie Wn 210** — to konto pasywne, więc Wn = zmniejszenie zobowiązania, czyli odwrotnie do intencji.

❌ **Mieszanie analityk** — zwróć uwagę, czy używasz właściwej analityki (np. `210-2-13` ≠ `210-4-2-1`). Każda placówka ma swoją.

❌ **Brakująca data** — operacja musi być datowana w bieżącym miesiącu raportu.

## 5. FAQ

**P: Saldo na koncie 210 wyszło ujemne — co to znaczy?**
O: Albo odprawiono więcej intencji niż przyjęto (możliwe przy oddawaniu intencji innym parafiom), albo gdzieś jest błąd księgowania. Skontaktuj się z prowincjałem.

**P: Czy stan końcowy powinien zgadzać się z liczbą fizycznych intencji w księdze?**
O: Tak — co do złotówki. Jeśli się nie zgadza, jest to sygnał do audytu wpisów.
$MD$);

-- 4. Import Excel formularzowy
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('📤 Import Excel formularzowy', 'dokumenty', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 📤 Import Excel formularzowy

Trzecia (obok CSV i MT940) ścieżka importu danych do dokumentów. Pozwala na masowe wprowadzenie operacji księgowych z arkusza w ujednoliconym formacie.

---

## 1. Kiedy używać?

| Sytuacja | Polecany format |
|----------|-----------------|
| Wyciąg z banku | **MT940** |
| Eksport z innego systemu | **CSV** |
| Ręcznie przygotowany arkusz | **Excel formularzowy** ✓ |
| Sumaryczne zestawienie miesięczne | **Excel formularzowy** ✓ |

## 2. Format pliku

`Dokumenty → Nowy dokument → Import Excel`

Po kliknięciu otrzymasz **wzorcowy szablon** do pobrania. Wymagane kolumny:

| Kolumna | Opis | Wymagane |
|---------|------|----------|
| **Data** | Data operacji (DD.MM.RRRR) | ✅ |
| **Opis** | Opis operacji | ✅ |
| **Kwota Wn** | Kwota po stronie Winien | ⚠️ jedna z dwóch |
| **Konto Wn** | Numer konta Wn (np. 401-2-3) | ⚠️ jedna z dwóch |
| **Kwota Ma** | Kwota po stronie Ma | ⚠️ jedna z dwóch |
| **Konto Ma** | Numer konta Ma | ⚠️ jedna z dwóch |
| **Waluta** | PLN, EUR, USD itd. | opcjonalnie (domyślnie PLN) |
| **Kurs** | Kurs do PLN | opcjonalnie (domyślnie 1) |

## 3. Walidacja przed importem

System sprawdzi:
- ✅ Wszystkie konta istnieją i są przypisane do Twojej placówki
- ✅ Suma Wn = suma Ma w każdej operacji
- ✅ Daty mieszczą się w bieżącym (lub edytowanym) miesiącu
- ✅ Kwoty są dodatnie

Operacje z błędami zostaną **wyświetlone na liście**, możesz je naprawić w arkuszu i zaimportować ponownie.

## 4. Automatyczne efekty importu

Przy imporcie system automatycznie:

- 🔄 Tworzy operacje „**procent na prowincję**" dla kont z listy wyzwalającej (zobacz: artykuł o opłacie prowincjalnej)
- 💱 Pobiera **kurs NBP** dla walut obcych (jeśli kolumna „Kurs" jest pusta)
- 🔢 Generuje numer dokumentu zgodnie ze schematem placówki

## 5. Dobre praktyki

> 💡 **Wskazówka:** Przed pierwszym importem zrób **kopię szablonu** i zapisz w lokalnym folderze. Nie zmieniaj nazw kolumn — system wymaga dokładnie tej samej nazwy.

> ⚠️ **Uwaga:** Po imporcie sprawdź sumy Wn i Ma w dokumencie. Powinny być równe. Jeśli nie — usuń dokument, popraw arkusz i zaimportuj ponownie.
$MD$);

-- 5. Tworzenie kont analitycznych
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('➕ Tworzenie kont analitycznych - krok po kroku', 'konta', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# ➕ Tworzenie kont analitycznych

Konta analityczne to **podkonta szczegółowe**, podrzędne wobec konta syntetycznego. Pozwalają na bardziej precyzyjne śledzenie wpływów i wydatków.

---

## 1. Struktura numeru

```
401  -  2  -  3  -  01
 │      │     │     │
 │      │     │     └── Numer analityki (sufiks)
 │      │     └──────── Numer placówki
 │      └────────────── Kategoria prowincji
 └───────────────────── Konto syntetyczne (np. 401 — Koszty)
```

**Przykład:** `401-2-3-01` = „Żywność", placówka 2-3, analityka 01.

## 2. Kto może tworzyć?

| Rola | Może tworzyć analityki? |
|------|-------------------------|
| Ekonom | ✅ TAK — dla swojej placówki |
| Proboszcz | ❌ NIE |
| Prowincjał | ✅ TAK — dla każdej placówki |
| Administrator | ✅ TAK — bez ograniczeń |

## 3. Krok po kroku (Ekonom)

1. Przejdź do `Ustawienia → Konta`
2. Znajdź **konto syntetyczne** (np. `401-2-3 — Koszty żywności`)
3. Kliknij ikonę **➕ „Dodaj analitykę"** przy tym koncie
4. Wypełnij formularz:
   - **Sufiks** (np. „01")
   - **Nazwa analityki** (np. „Żywność dla wspólnoty")
5. Kliknij **„Zapisz"**

> ✅ Konto pojawi się natychmiast i będzie dostępne we wszystkich modułach (Dokumenty, Raporty, Wyszukiwanie kont).

## 4. Kiedy analityka jest WYMAGANA?

Niektóre konta wymagają analityki przy każdym księgowaniu (system zablokuje zapis bez niej). Najczęściej dotyczy to:

- Kont kosztów (4xx) — dla precyzyjnego budżetowania
- Kont przychodów (7xx) — dla szczegółowych raportów
- Kont rozrachunków (2xx) — żeby identyfikować kontrahentów

System pokazuje czerwoną etykietę „**Wymagana analityka**" przy takim koncie.

## 5. Edycja i usuwanie

- **Edycja nazwy:** ekonom może edytować nazwę analityki swojej placówki
- **Usuwanie:** możliwe tylko jeśli na koncie **nie ma żadnych operacji**. Jeśli są — najpierw je usuń lub przeksięguj.

## 6. Częste błędy

❌ **Sufiks już istnieje** — system nie pozwala na duplikaty. Wybierz inny numer.

❌ **Próba użycia konta syntetycznego w dokumencie** — jeśli konto wymaga analityki, system nie pozwoli zapisać dokumentu z samym kontem syntetycznym (`401-2-3`). Musisz wybrać konkretną analitykę (`401-2-3-01`).

## 7. FAQ

**P: Stworzyłem analitykę, ale nie widzę jej w wyszukiwarce kont**
O: Odśwież stronę (Ctrl+F5). Lista kont jest cache'owana w przeglądarce.

**P: Czy mogę tworzyć analityki głębiej (np. 401-2-3-01-01)?**
O: System obsługuje tylko jeden poziom analityki. Jeśli potrzebujesz głębszej struktury, użyj kombinacji opisu operacji.
$MD$);

-- 6. Multi-lokalizacja
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('🏘️ Praca z wieloma placówkami', 'wprowadzenie', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 🏘️ Praca z wieloma placówkami

Niektórzy użytkownicy (np. ekonom prowincjalny lub proboszcz nadzorujący kilka domów) mają dostęp do **więcej niż jednej placówki**.

---

## 1. Jak rozpoznać, że masz wiele placówek?

Po zalogowaniu zobaczysz **menu wyboru placówki** w nagłówku (przy nazwie użytkownika):

```
[Marek Głowacki ▾]    [Placówka: Gorzów ▾]   [Wyloguj]
```

Jeśli menu wyboru się nie pojawia — masz dostęp tylko do jednej placówki (lub jesteś adminem/prowincjałem widzącym wszystkie).

## 2. Przełączanie kontekstu placówki

1. Kliknij menu **„Placówka: …"** w nagłówku
2. Wybierz placówkę z listy
3. Cała aplikacja **przełącza się na kontekst tej placówki**:
   - Dokumenty pokazują tylko jej dokumenty
   - Raporty — tylko jej raporty
   - Budżet — tylko jej budżet
   - Konta księgowe — tylko jej konta

> ⚠️ **Uwaga:** Operacja, którą tworzysz, **zostanie zapisana w aktywnej placówce**. Sprawdź kontekst zanim zapiszesz dokument.

## 3. Co widzą administratorzy i prowincjałowie?

Admin i prowincjał **widzą wszystkie placówki jednocześnie** — bez konieczności przełączania:

- **Dokumenty / Raporty / Budżety:** filtr „Placówka" pozwala zawęzić listę
- **Statystyki zbiorcze:** pokazują dane wszystkich placówek razem

## 4. Powiadomienia

Otrzymujesz powiadomienia o zdarzeniach **we wszystkich swoich placówkach** — niezależnie od tego, która jest aktywna.

## 5. Konfiguracja (Admin)

`Administracja → Użytkownicy → wybierz użytkownika → „Placówki"`

Admin może:
- Dodać użytkownikowi dostęp do dodatkowej placówki
- Odebrać dostęp do placówki
- Ustawić **placówkę domyślną** (ta, w której użytkownik loguje się jako pierwszej)

## 6. FAQ

**P: Stworzyłem dokument w niewłaściwej placówce — co robić?**
O: Usuń dokument i utwórz go ponownie po przełączeniu kontekstu. Dokumentów nie da się przenosić między placówkami.

**P: Czy mogę widzieć raporty z wszystkich moich placówek na jednym ekranie?**
O: Tylko admin i prowincjał mają taki widok zbiorczy. Pozostałe role muszą przełączać kontekst.
$MD$);

-- 7. Bilanse przechodnie 217/149
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('🔁 Bilanse przechodnie - konta 217 i 149', 'raporty', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 🔁 Bilanse przechodnie — konta 217 i 149

Niektóre konta wymagają **rozróżnienia operacji wewnętrznych** (między rachunkami tej samej placówki) od operacji rzeczywistych. System obsługuje to automatycznie dla dwóch kont:

---

## 1. Konto 217 — Świetlica

Konto pomocnicze do śledzenia środków świetlicy parafialnej (lub innej działalności pomocniczej).

### Struktura analityk

Najczęstszy podział:

| Numer | Znaczenie |
|-------|-----------|
| `217-X-Y-1` | **Rachunek bankowy parafii** |
| `217-X-Y-2` | **Rachunek bankowy świetlicy** |

### Przykład: przelew z parafii do świetlicy

```
Wn: 217-2-3-2 (Świetlica)    500,00 zł
Ma: 217-2-3-1 (Parafia)      500,00 zł
Opis: „Refundacja zakupów świetlicowych"
```

> ⚠️ **Uwaga na pomyłki:** Częstym źródłem niezgodności w „sumach przechodnich" jest pomylenie końcówki `-1` (parafia) z `-2` (świetlica). Zawsze sprawdź, do którego rachunku faktycznie wpłynęły środki.

## 2. Konto 149 — Pieniądze w drodze

Konto przejściowe dla operacji, które już opuściły jedno konto, ale jeszcze nie dotarły na drugie (np. przelew międzybankowy trwający kilka dni).

### Typowe użycie

```
Dzień 1 (wypłata z banku):
  Wn: 149 (Pieniądze w drodze)   1000,00 zł
  Ma: 130 (Bank)                  1000,00 zł

Dzień 3 (wpłata do kasy):
  Wn: 100 (Kasa)                  1000,00 zł
  Ma: 149 (Pieniądze w drodze)   1000,00 zł
```

> ✅ **Saldo konta 149 na koniec miesiąca powinno być zerowe** — chyba że faktycznie pieniądze są w drodze przez dłużej.

## 3. Jak system obsługuje to w raportach?

Raport miesięczny pokazuje dla obu kont:
- **Saldo otwarcia** (wyliczone z poprzednich miesięcy)
- **Obroty Wn** (przyjęcia)
- **Obroty Ma** (wydania)
- **Saldo końcowe**

System **automatycznie pomija operacje wewnętrzne** (gdzie obie strony to to samo konto syntetyczne) w sumach kontrolnych — żeby nie zawyżać obrotów.

## 4. Limit pobierania danych

⚠️ Dla placówek z **bardzo dużą liczbą operacji** (>1000 transakcji w okresie) obowiązuje limit pobierania w Supabase. Jeśli widzisz, że saldo otwarcia wygląda nieprawidłowo:

1. Skontaktuj się z administratorem
2. Może być potrzebne zwiększenie limitu lub zmiana sposobu agregacji historycznej

## 5. FAQ

**P: Saldo konta 149 jest niezerowe na koniec miesiąca — czy to błąd?**
O: Niekoniecznie. Jeśli przelew został zlecony 30. dnia miesiąca, a wpłynął 2. następnego — saldo będzie niezerowe. Sprawdź wyciąg bankowy.

**P: Konto 217 ma niezgodne sumy z wyciągami — co robić?**
O: Najczęściej to pomyłka analityki (parafia vs. świetlica). Sprawdź każdą operację po kolei.
$MD$);

-- 8. Konto 463
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('🚫 Konto 463 - ograniczenia użycia', 'konta', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 🚫 Konto 463 — Administracja Prowincjalna

Konto **463** jest **zarezerwowane** wyłącznie dla operacji Administracji Prowincjalnej. Większość placówek nie może go używać.

---

## 1. Kto może księgować na koncie 463?

✅ **Mogą:**
- Placówki o **kategorii prowincjalnej** (identyfikator zaczynający się od `1` — np. `1-1`, `1-2`)
- Administratorzy

❌ **Nie mogą:**
- Placówki o kategorii `2`, `3`, `4` itd. (zwykłe domy zakonne)
- Ekonomowie tych placówek

## 2. Co się stanie, gdy spróbuję go użyć?

System **zablokuje** wybór konta 463 w polach „Konto Wn" / „Konto Ma":

- W menu wyboru konto się **nie pojawi**
- W wyszukiwarce kont konto **nie będzie widoczne**
- Przy imporcie pliku CSV/MT940/Excel: pojawi się **błąd walidacji** „Konto niedostępne dla Twojej placówki"

## 3. Co zrobić, gdy potrzebuję zaksięgować coś podobnego?

Skontaktuj się z **prowincjałem** lub **ekonomem prowincjalnym** — oni mogą:
- Zaksięgować operację po stronie prowincji
- Doradzić, którego konta z Twojego planu kont użyć zamiast 463

## 4. Konfiguracja restrykcji (tylko Admin)

`Administracja → Konta → Restrykcje kont`

Admin może:
- Dodać nowy ograniczony prefiks
- Zmienić kategorie placówek mających dostęp
- Wymagać analityki dla danego prefiksu

> 💡 **Restrykcje są jednym z mechanizmów ochrony spójności planu kont** — zapobiegają księgowaniu na kontach, które nie należą do danej placówki.
$MD$);

-- 9. Markdown w zgłoszeniach
INSERT INTO admin_notes (title, category, pinned, visible_to, created_by, content) VALUES
('🐛 Zgłaszanie błędów i obsługa Markdown', 'administracja', false, ARRAY['ekonom','proboszcz','prowincjal','admin']::text[], v_admin_id,
$MD$# 🐛 Zgłaszanie błędów + obsługa Markdown w odpowiedziach

Każdy użytkownik może w dowolnym momencie zgłosić błąd lub sugestię. Administratorzy odpowiadają, a od kwietnia 2026 odpowiedzi obsługują **formatowanie Markdown**.

---

## 1. Jak zgłosić błąd

1. Kliknij przycisk **🐛 „Zgłoś błąd"** w prawym dolnym rogu (zawsze widoczny)
2. System **automatycznie zrobi screenshot** aktualnej strony
3. Wypełnij:
   - **Tytuł** (krótki opis problemu)
   - **Szczegółowy opis** (kroki do reprodukcji)
   - **Priorytet** (Niski / Średni / Wysoki / Krytyczny)
4. Opcjonalnie: dodaj **załączniki** (pliki, dodatkowe screenshoty)
5. Kliknij **„Wyślij"**

System dołączy automatycznie:
- 📸 Screenshot strony
- 🌐 Adres strony, na której byłeś
- 💻 Informacje o przeglądarce (typ, wersja)

> 📧 **Powiadomienia e-mail:** Administratorzy otrzymują e-mail o nowym zgłoszeniu. Ty otrzymasz e-mail z potwierdzeniem oraz kolejny przy każdej odpowiedzi.

## 2. Status zgłoszenia

| Status | Znaczenie |
|--------|-----------|
| 🆕 **Nowe** | Czeka na pierwszą odpowiedź administratora |
| 🔧 **W trakcie** | Administrator pracuje nad rozwiązaniem |
| ✅ **Rozwiązane** | Problem załatwiony |
| ❌ **Odrzucone** | Zgłoszenie nie zostało zaakceptowane (np. duplikat) |

Zmiana statusu również wysyła powiadomienie e-mail.

## 3. ✨ Markdown w konwersacji

W szczegółach zgłoszenia (`Administracja → Zgłoszenia błędów → wybierz zgłoszenie`) zarówno **opis pierwotny**, jak i **wszystkie odpowiedzi** są renderowane jako Markdown.

### Co działa?

| Składnia | Efekt |
|----------|-------|
| `# Nagłówek 1` | Duży nagłówek |
| `## Nagłówek 2` | Średni nagłówek |
| `**pogrubione**` | **pogrubione** |
| `*kursywa*` | *kursywa* |
| `` `kod inline` `` | `kod inline` |
| ` ```kod blok``` ` | Blok kodu z monospace |
| `- punkt` | Lista punktowana |
| `1. punkt` | Lista numerowana |
| `[link](https://...)` | Klikalny link |
| `> cytat` | Wyróżniony cytat |
| `---` | Pozioma linia |
| Tabele Markdown | Tabela z obramowaniem |

### Przykład profesjonalnej odpowiedzi (admin)

````markdown
## Diagnoza

Problem dotyczy konta **217-2-3-2**. Sprawdziłem ostatnie 30 operacji.

### Znalezione przyczyny

1. Operacje z dnia `12.04` mają błędną analitykę
2. Brakuje operacji „przesunięcia" z 30.04

### Rozwiązanie

Wystarczy:
- Edytować operacje z 12.04 (zmienić `-1` na `-2`)
- Dodać brakującą operację przesunięcia

> Po zmianach saldo powinno się zgadzać z wyciągiem.
````

## 4. Pole tekstowe — bez podglądu na żywo

Pole do wpisywania odpowiedzi pokazuje **surowy tekst Markdown** podczas pisania. Formatowanie pojawi się dopiero **po wysłaniu** odpowiedzi.

> 💡 **Wskazówka:** Jeśli chcesz zobaczyć podgląd formatowania, możesz użyć dowolnego edytora Markdown (np. dillinger.io) i skopiować gotowy tekst.

## 5. Załączniki w odpowiedziach

Administratorzy mogą dołączyć pliki do odpowiedzi (np. zrzuty ekranu, dokumenty Excel, PDF). Załączniki pojawią się jako klikalne linki w konwersacji.
$MD$);

-- 10. UPDATE artykułu o imporcie (dodaj sekcję Excel)
UPDATE admin_notes 
SET title = '📥 Import danych — CSV, MT940 i Excel',
    content = content || E'\n\n---\n\n## 🆕 Import Excel formularzowy\n\nOd 2026 r. dostępna jest **trzecia ścieżka importu** — Excel formularzowy. Pozwala na masowe wprowadzenie operacji z arkusza w ujednoliconym formacie.\n\n📖 Zobacz dedykowany artykuł: **„📤 Import Excel formularzowy"**\n\n## ⏱️ Synchronizacja z opłatą prowincjalną\n\nPrzy każdym imporcie system **czeka, aż dane konfiguracyjne** (lista kont prowincjalnych, ustawienia opłaty) **załadują się**. Jeśli zaczniesz import zbyt wcześnie:\n\n- Pojawi się komunikat „Konfiguracja jeszcze się ładuje — spróbuj za chwilę"\n- Przycisk importu zostanie tymczasowo zablokowany\n- Po 2–5 sekundach wszystko będzie gotowe\n\nDzięki temu **automatyczne operacje „procent na prowincję"** są zawsze prawidłowo generowane przy imporcie.',
    updated_at = now()
WHERE id = 'bbd23048-bc7f-4dbf-9744-06e68f0289d2';

-- 11. UPDATE artykułu o rolach (dodaj sekcję multi-lokalizacja)
UPDATE admin_notes
SET content = content || E'\n\n---\n\n## 🏘️ Wiele placówek dla jednego użytkownika\n\nNiektórzy użytkownicy (np. ekonom prowincjalny, proboszcz nadzorujący kilka domów) mogą mieć **dostęp do więcej niż jednej placówki jednocześnie**.\n\nW takim przypadku w nagłówku pojawia się **menu wyboru placówki** — wybierz, w której placówce chcesz aktualnie pracować. Cała aplikacja przełącza kontekst.\n\n📖 Zobacz dedykowany artykuł: **„🏘️ Praca z wieloma placówkami"**',
    updated_at = now()
WHERE id = '8f037534-f789-4b5d-8561-a8b919ec31e0';

END $$;