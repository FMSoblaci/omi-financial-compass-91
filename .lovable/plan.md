
## 1. Indywidualny % dla każdego konta wyzwalającego

**Stan obecny:** `provincial_fee_settings.fee_percentage` jest jedna globalna wartość. Wszystkie konta z `provincial_fee_accounts` używają tego samego procentu.

**Zmiana:**
- Migracja: dodać kolumnę `fee_percentage NUMERIC` (nullable) do `provincial_fee_accounts`. Jeśli `NULL` → fallback do globalnej wartości (kompatybilność wstecz).
- UI `ProvincialFeeManagement.tsx`: w tabeli prefiksów dodać edytowalne pole "% opłaty" obok prefiksu (osobny `update` mutation per wiersz). Globalne pole pozostaje jako wartość domyślna z opisem "stosowana, gdy konto nie ma własnego %".
- Hook `useProvincialFee.ts`: zmienić `triggerPrefixes` z `string[]` na `Array<{prefix, fee_percentage|null}>`. W `createProvincialFeeTransaction` i `generateProvincialFeesForImport` wybrać % na podstawie konta wyzwalającego (z preferencją wartości per-account, fallback do globalnej). Jeśli oba konta wyzwalające - użyć tego z wyższym priorytetem (najpierw debit).

## 2. Wykluczanie lokalizacji z opłaty per konto

**Zmiana:**
- Migracja: nowa tabela `provincial_fee_account_exclusions`:
  - `id uuid pk`, `provincial_fee_account_id uuid` (ref do `provincial_fee_accounts.id`), `location_id uuid`, `created_at`.
  - UNIQUE `(provincial_fee_account_id, location_id)`.
  - RLS: SELECT dla wszystkich zalogowanych, ALL dla admin/prowincjal.
- UI: w wierszu prefiksu nowy przycisk "Wykluczone lokalizacje" → popover/multi-select listy lokalizacji. Pokazuje liczbę wykluczeń.
- Hook `useProvincialFee.ts`: dociągnąć mapę wykluczeń. Nowy parametr w `shouldCreateProvincialFee*` — `locationId`. Jeśli prefiks pasuje, ale `locationId` jest na liście wykluczeń tego prefiksu → zwróć `false`.
- `DocumentDialog.tsx` i importery: przekazać `selectedLocationId` do funkcji sprawdzających.
- Edge function `generate_provincial_fee_for_document` (jeśli istnieje po stronie SQL) — sprawdzić, czy nie trzeba zaktualizować analogicznie. Jeżeli tylko frontend generuje opłatę, pomijamy.

## 3. Naprawa rozbijania kwot (split)

**Zdiagnozowany bug** w `DocumentDialog.tsx` `handleSplitTransaction` (linia ~1428):

Gdy operacja jest „już rozbita" (jedna strona pusta — typowe dla skopiowanych dokumentów i importów MT940/CSV), kod liczy:
```
totalDebit = SUMA Wn ze WSZYSTKICH operacji dokumentu
totalCredit = SUMA Ma ze WSZYSTKICH operacji dokumentu
balanceAmount = |totalDebit - totalCredit|
```
i tworzy nową operację na różnicę całego dokumentu, **nie** różnicę pojedynczej operacji. To dokładnie opisuje użytkownik: „bierze kwotę z całości dokumentu, nie z pojedynczej operacji".

Dla nowych operacji, gdzie obie strony są wypełnione, bug nie występuje — kod liczy `|debitAmount - creditAmount|` z pojedynczej operacji. Działa dobrze.

**Naprawa:**
- Zastąpić logikę „already split" mechanizmem grupującym po klikniętym wierszu:
  - Jeśli operacja ma jedną stronę pustą → znaleźć powiązaną „grupę rozbicia" (operacje sąsiednie z tym samym brakującym/uzupełniającym kontem lub powiązane przez `parent_transaction_id`/wspólny opis przy imporcie). Najprostsze i deterministyczne: rozbijanie zawsze odnosi się do **kwoty z drugiej, wypełnionej strony tej samej operacji**. Czyli:
    - Jeśli `debit_amount > 0` i `credit_amount` puste → nowa operacja ma `credit_amount = debit_amount` (lub odwrotnie), z pustym kontem do uzupełnienia. Użytkownik ręcznie wprowadza konto.
  - Alternatywnie (preferowane przez UX): otworzyć `TransactionSplitDialog` z `targetAmount = max(debit_amount, credit_amount)` tej **jednej** operacji, by użytkownik świadomie podzielił właśnie tę kwotę na kilka kont.
- Wybór: użyć opcji z dialogiem dla operacji z jedną pustą stroną — tak samo jak dla operacji z obiema stronami. To ujednolica UX i eliminuje bug.

**Audyt pokrewnych ścieżek:**
- Nowy dokument (obie strony wypełnione): `|debit - credit|` z pojedynczej operacji — OK.
- Edycja istniejącej operacji: ta sama funkcja — OK po naprawie.
- Skopiowany dokument: operacje są skopiowane z istniejącymi `debit_amount`/`credit_amount` (linia ~1556 `handleCopySelected` zeruje konta, ale zachowuje kwoty). Po naprawie split zachowuje się tak samo dla skopiowanych jak dla nowych.
- Import MT940/CSV: tworzy operacje z jedną stroną pustą — po naprawie split otwiera dialog z kwotą tej konkretnej operacji, nie sumą całego dokumentu.

## Pliki do zmian

- `supabase/migrations/...` — nowe kolumny + tabela wykluczeń + RLS
- `src/pages/Administration/ProvincialFeeManagement.tsx` — edycja % per wiersz, dialog wykluczeń
- `src/hooks/useProvincialFee.ts` — nowa struktura prefiksów, parametr `locationId`, użycie per-account %
- `src/pages/Documents/DocumentDialog.tsx` — wywołania `shouldCreateProvincialFee*` z `locationId`; przepisanie gałęzi „already split" w `handleSplitTransaction` na otwarcie dialogu z poprawną kwotą bazową
- ewentualnie `Mt940ImportDialog.tsx`, `CsvImportDialog.tsx`, `ExcelFormImportDialog.tsx`, `KpirImportDialog.tsx` — przekazanie `locationId` do generatora opłat
