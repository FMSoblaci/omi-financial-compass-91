# Plan naprawy: numeracja dokumentów + screenshoty błędów

## Problem 1: Numer dokumentu rozjeżdża się z datą (race condition)

### Przyczyna
W `DocumentDialog.tsx` zmiana daty wywołuje async `generateDocumentNumber()`. Gdy użytkownik zmienia datę kilka razy szybko (marzec → maj → marzec) i klika "Zapisz" zanim ostatnie wywołanie wróci, formularz wysyła `document_date=2026-03-01` razem z `document_number=DOMKOD/2026/05/001`. Trigger `auto_regenerate_document_number` nie reaguje, bo porównuje tylko `OLD.document_date` vs `NEW.document_date` (bez sprawdzania czy numer pasuje do daty).

### Rozwiązanie — 3 warstwy obrony

**Warstwa 1 — DB trigger (twarda gwarancja)**
Nowa migracja: trigger `BEFORE INSERT OR UPDATE` na `documents`, który:
- Wyliczy oczekiwany wzorzec `^{ABBR}/{YYYY}/{MM}/[0-9]+$` z `NEW.document_date` i `location_settings.house_abbreviation`
- Jeśli `NEW.document_number` NIE pasuje do wzorca → wywoła `generate_document_number(...)` i nadpisze `NEW.document_number`
- Działa zawsze, niezależnie od tego co przyjdzie z UI

**Warstwa 2 — Frontend (UX, blokada zapisu w trakcie generowania)**
W `src/pages/Documents/DocumentDialog.tsx`:
- Dodać flagę `isGeneratingNumber` ustawianą na `true` przed `generateDocumentNumber()` i `false` w `finally`
- Sekwencyjne wywołania (anulowanie poprzednich) — przechowywać `lastRequestId` (ref z licznikiem), w handlerze ignorować odpowiedź jeśli ID się nie zgadza z aktualnym
- Przycisk "Zapisz" wyłączony gdy `isGeneratingNumber === true` + spinner z napisem "Generowanie numeru…"

**Warstwa 3 — Naprawa istniejących danych (jednorazowo)**
W tej samej migracji, po utworzeniu triggera:
```sql
UPDATE documents d
SET document_number = generate_document_number(d.location_id, EXTRACT(YEAR FROM d.document_date)::int, EXTRACT(MONTH FROM d.document_date)::int)
WHERE d.document_number !~ ('^[A-Z]+/' || EXTRACT(YEAR FROM d.document_date) || '/' || LPAD(EXTRACT(MONTH FROM d.document_date)::text,2,'0') || '/[0-9]+$');
```
Dodatkowo zsynchronizować `transactions.document_number` z `documents.document_number` po update'cie.

⚠️ Skutek uboczny: dokument "PARIBAS - marzec" odzyska numer marcowy (np. `DOMKOD/2026/03/010`), a "zarezerwowany" numer majowy zostanie zwolniony.

---

## Problem 2: Screenshoty w zgłoszeniach błędów nie działają

### Przyczyna
`html2canvas` nie obsługuje nowoczesnego CSS używanego w projekcie: `oklch()`, `color-mix()`, `conic-gradient`, niektórych zmiennych CSS — silently zawodzi lub zwraca puste/zniekształcone obrazy. Logi konsoli to potwierdzają.

### Rozwiązanie

**Zamiana biblioteki: `html2canvas` → `html-to-image`**
- `html-to-image` używa SVG `foreignObject` i obsługuje `oklch`, `color-mix` i nowoczesny CSS
- Mniejsza, szybsza, lepiej utrzymywana

**Zmiany w `package.json`:**
- Dodać `html-to-image`
- Usunąć `html2canvas` (po sprawdzeniu że nie jest używany gdzie indziej — `rg "html2canvas"` znalazło 2 miejsca: `ErrorReportButton.tsx`, `KpirDocumentDialog.tsx`)

**Zmiany w `src/components/ErrorReportButton.tsx`:**
- `import { toPng } from 'html-to-image'`
- `const dataUrl = await toPng(document.body, { cacheBust: true, pixelRatio: 1, backgroundColor: '#ffffff', filter: (node) => !(node as HTMLElement).classList?.contains?.('error-report-button-ignore') })`
- Zachować obecny try/catch + toast

**Zmiany w `src/pages/KPIR/KpirDocumentDialog.tsx`:**
- Analogiczna zamiana — `toPng(dialogElement, { backgroundColor: '#ffffff', filter: ... })`
- Zachować obecny `onclone`-podobny efekt: filter usuwający overlay (`[data-radix-dialog-overlay]`)

**Walidacja po zrobieniu screena:**
- Sprawdzić że `dataUrl.length > 1000` (sanity check przeciw pustym obrazkom)
- Jeśli mniejszy — toast "Nie udało się zrobić screenshota" i otworzyć dialog bez obrazka

---

## Pliki do zmiany

1. **Nowa migracja SQL** — trigger walidujący numer↔data + jednorazowy fix istniejących dokumentów + sync transactions
2. **`src/pages/Documents/DocumentDialog.tsx`** — flagi `isGeneratingNumber`, sekwencyjne requesty, blokada przycisku Zapisz
3. **`src/components/ErrorReportButton.tsx`** — `html2canvas` → `html-to-image`
4. **`src/pages/KPIR/KpirDocumentDialog.tsx`** — `html2canvas` → `html-to-image`
5. **`package.json`** — `+html-to-image`, `-html2canvas`

## Konsekwencje
- Numer dokumentu **gwarantowanie** zgodny z datą — nawet przy najgorszej race condition czy ręcznej manipulacji
- Trigger `auto_regenerate_document_number` zostaje (działa szybciej w typowym przypadku zmiany miesiąca), nowy trigger to "safety net"
- Istniejące rozjechane dokumenty zostaną naprawione automatycznie przy migracji
- Screenshoty będą działać na wszystkich stronach z nowoczesnym CSS
