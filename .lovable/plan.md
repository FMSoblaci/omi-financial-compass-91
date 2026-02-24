

# Plan naprawy dwoch bledow

## Bug 1: Odeslanie budzetu do poprawki z komentarzem + edycja roku

### Analiza problemu

Trzy powiazane usterki:

1. **Odrzucenie budzetu** uzywa `prompt()` (brzydkie okienko przegladarki) zamiast porządnego formularza z textarea - jak w raportach miesięcznych (`ReportApprovalActions.tsx`).

2. **Rok budzetu zablokowany przy edycji** - linia 526 w `BudgetForm.tsx`: `disabled={isEditing}` blokuje pole roku zawsze przy edycji, nawet gdy budżet jest odrzucony i wymaga korekty.

3. **RLS policy blokuje edycje odrzuconego budzetu** - obecna polityka UPDATE na `budget_plans` pozwala ekonomom edytowac tylko budzety ze statusem `draft`. Po odrzuceniu (status = `rejected`) ekonom nie moze edytowac budzetu. Trzeba dodac `rejected` do listy dozwolonych statusow.

### Zmiany

**Plik: `src/pages/Budget/BudgetView.tsx`**
- Zamiast `prompt()` w `handleReject` - dodac state na `rejectionReason` i `showRejectDialog`
- Dodac komponent Dialog/Card z Textarea do wpisania powodu odrzucenia (wzorowane na ReportApprovalActions)
- Prowincjal/admin wpisuje uwagi w textarea, klika "Odrzuc" - status zmienia sie na `rejected`

**Plik: `src/pages/Budget/BudgetForm.tsx`**
- Linia 526: zmienic `disabled={isEditing}` na `disabled={isEditing && budget?.status !== 'rejected'}` - odblokowanie roku dla odrzuconych budzetow
- Analogicznie dla lokalizacji (linia 535)

**Migracja SQL (RLS)**:
- Zaktualizowac polityki UPDATE na `budget_plans` - dodac `'rejected'` do listy dozwolonych statusow w USING clause dla ekonomow
- Zaktualizowac polityki na `budget_items` analogicznie - dodac `'rejected'`
- Przy zapisie odrzuconego budzetu po edycji, status wraca do `draft`

---

## Bug 2: Brak kwot Wn/Ma w eksporcie Excel dla kont 200 i 201

### Analiza problemu

W `AccountSearchPage.tsx` (linie 470-473) eksport do Excela porownuje `t.debit_account_id === selectedAccount.id` i `t.credit_account_id === selectedAccount.id`.

Dla kont nadrzednych (syntetycznych) jak **200** i **201**, transakcje uzyja kont analitycznych (np. `200-2-17`, `201-2-17-2`). Ich `debit_account_id` / `credit_account_id` to ID podkonta, a nie konta 200.

Dlatego oba warunki zwracaja `false` i kwoty Wn/Ma sa zerowe.

Obliczenia sum (`totals`, linia 204) uzywaja `relatedAccountIdsSet` (zbiór wszystkich powiazanych kont) i dzialaja poprawnie. Eksport tego nie robi.

### Zmiana

**Plik: `src/pages/AccountSearch/AccountSearchPage.tsx`**
- W funkcji `handleExportToExcel` (linie 469-473) - zamiast `selectedAccount.id` uzyc `relatedAccountIdsSet`:

```text
Przed:
  const isDebit = t.debit_account_id === selectedAccount.id;
  const isCredit = t.credit_account_id === selectedAccount.id;

Po:
  const relatedSet = new Set(relatedAccountIds);
  const isDebit = relatedSet.has(t.debit_account_id);
  const isCredit = relatedSet.has(t.credit_account_id);
```

Dzieki temu eksport bedzie spójny z obliczeniami sum wyswietlanymi na ekranie.

---

## Podsumowanie zmian

| Zmiana | Plik | Opis |
|--------|------|------|
| Dialog odrzucenia budzetu | BudgetView.tsx | Textarea + Dialog zamiast prompt() |
| Odblokowanie roku | BudgetForm.tsx | disabled tylko gdy status != rejected |
| RLS policy | Migracja SQL | Dodanie 'rejected' do dozwolonych statusow edycji |
| Excel export kwoty | AccountSearchPage.tsx | Uzycie relatedAccountIds zamiast selectedAccount.id |

