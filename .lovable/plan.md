
## Weryfikacja zgłoszenia Piotra Osowskiego

**Zgłoszenie jest zasadne — w aplikacji jest błąd księgowy na koncie 210 (Intencje).**

Użytkownik trafnie zauważył, że saldo intencji w systemie się nie zgadza. Przeanalizowałem rzeczywiste księgowania w bazie i znalazłem błąd, który jest nawet poważniejszy niż użytkownik podejrzewał.

## Co znalazłem w bazie

Wszystkie księgowania intencji w systemie wyglądają tak samo (przykłady z 04.2026):

```
Wn: 100-4-2-1 (Kasa)        100,00 zł
Ma: 210-4-2-1 (Intencje)    100,00 zł     -- "1 int Paweł" (przyjęcie intencji)
```

Czyli **przyjęcie intencji** (wpływ gotówki, powstanie zobowiązania) księgowane jest po stronie **Ma** konta 210. To jest zgodne z naturą konta 210 — to konto pasywne (zobowiązanie wobec wiernych do odprawienia mszy).

## Gdzie jest błąd

W kodzie `src/components/reports/ReportViewFull.tsx` (linie 145–146 i 194–238) strony są opisane **odwrotnie do konwencji księgowej**:

```ts
// Intentions data (account 210)
let intentions210Received = 0;          // Wn - przyjęte         ❌ ŹLE
let intentions210CelebratedGiven = 0;   // Ma - odprawione i oddane ❌ ŹLE
```

W rzeczywistości:
- **Strona Ma 210** = przyjęcie intencji (powstanie zobowiązania)
- **Strona Wn 210** = odprawienie/oddanie intencji (zmniejszenie zobowiązania)

A następnie wzór końcowy w `ReportIntentionsTable.tsx` (linia 25) też jest pomylony, bo używa źle nazwanych zmiennych:

```ts
const calculatedClosing = data.openingBalance + data.received - data.celebratedAndGiven;
```

W efekcie program faktycznie robi to, na co skarży się użytkownik — **dodaje do BO odprawione (Ma) i odejmuje przyjęte (Wn)** zamiast odwrotnie.

## Dodatkowy problem — saldo otwarcia

Saldo otwarcia konta 210 (`openingBalances.get('210')`) jest liczone jako `debit - credit` (typowo dla kont aktywnych). Dla konta pasywnego 210 powinno być `credit - debit`. Trzeba to zweryfikować w hooku liczącym opening balances i ewentualnie odwrócić znak dla konta 210.

## Plan naprawy

### 1. `src/components/reports/ReportViewFull.tsx`
Zamienić przypisanie stron na zgodne z konwencją księgową:
- Strona **Ma** konta 210 → `intentionsReceived` (przyjęte)
- Strona **Wn** konta 210 → `intentionsCelebratedGiven` (odprawione i oddane)

Poprawić również komentarze przy zmiennych, żeby nie wprowadzały w błąd następnego programisty.

### 2. `src/components/reports/ReportIntentionsTable.tsx`
Wzór jest poprawny pod względem formuły (`BO + przyjęte − odprawione`) — pod warunkiem, że dane wchodzą poprawnie. Po naprawie punktu 1 będzie działał prawidłowo. Zostawić bez zmian (lub tylko poprawić komentarze).

### 3. Saldo otwarcia konta 210
Sprawdzić w `ReportViewFull.tsx` (linie 37–98 — useQuery `openingBalances`), jak liczone jest BO dla 210. Jeżeli używany jest wzór typowy dla kont aktywnych (`debit − credit`), trzeba dodać wyjątek dla 210, żeby liczyć `credit − debit`. To sprawdzę przy implementacji i dostosuję.

### 4. Weryfikacja w innych miejscach
Te same dane są używane w eksporcie do Excela (`ExportToExcelFull.tsx`) — sprawdzić, czy tam też trzeba poprawić logikę stron Wn/Ma dla konta 210.

## Pliki do modyfikacji
- `src/components/reports/ReportViewFull.tsx` (główna naprawa)
- `src/components/reports/ReportIntentionsTable.tsx` (ewentualne poprawki komentarzy)
- `src/components/reports/ExportToExcelFull.tsx` (weryfikacja i ewentualna naprawa)

## Co zobaczy użytkownik po naprawie
Saldo końcowe intencji w raporcie miesięcznym będzie się zgadzało z księgą intencji prowadzoną w Excelu. Wzór będzie poprawnie działał: `Stan końcowy = BO + Przyjęte − Odprawione`.
