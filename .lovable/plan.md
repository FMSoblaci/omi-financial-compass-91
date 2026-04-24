## Problem

Zakładka **"Ograniczenia kont"** w Administracji ładuje się bardzo długo (kilkanaście sekund albo dłużej, zwłaszcza przy ~6000 kont). Użytkownik widzi tylko napis "Ładowanie..." przez długi czas.

## Przyczyna

W pliku `src/pages/Administration/AccountRestrictionsManagement.tsx` zapytanie do bazy pobiera konta paczkami **po 20 rekordów na raz** (`pageSize = 20`). Przy 6000+ kont oznacza to **~300 osobnych zapytań HTTP** do Supabase, jedno po drugim.

Dla porównania — centralny hook `useFilteredAccounts` używa `pageSize = 1000` (czyli ~6 zapytań zamiast 300) i nawet wtedy filtruje już zbędne dane.

Dodatkowo, do wyświetlenia tabeli ograniczeń **wcale nie potrzebujemy 6000 kont** — potrzebujemy tylko unikalnych **prefiksów numerów kont** (część przed pierwszym `-`), których jest zwykle kilkadziesiąt (np. `100`, `131`, `201`, `400`, `460`, `700` itd.).

## Rozwiązanie

Dwie zmiany w `AccountRestrictionsManagement.tsx`:

1. **Zwiększenie pageSize z 20 → 1000**  
   Natychmiastowy zysk: ~50× mniej zapytań HTTP. To samo, co robi `useFilteredAccounts`.

2. **Pobieranie tylko kolumny `number`**  
   Komponent używa wyłącznie `account.number` do wyciągnięcia prefiksu — `id`, `name`, `type` są pobierane niepotrzebnie. Mniejszy payload = szybsze ładowanie.

Opcjonalnie: dodać krótki komunikat "Ładowanie ~N kont…" zamiast samego "Ładowanie..." dla lepszego UX.

## Co się NIE zmieni

- Logika checkboxów, restrykcji i invalidacji cache pozostaje bez zmian.
- Tabela kategorii i nagłówek sticky (z poprzedniej zmiany) bez zmian.
- Brak zmian w bazie danych ani RLS.

## Pliki do edycji

- `src/pages/Administration/AccountRestrictionsManagement.tsx` — zmiana `pageSize` i `select(...)`.

## Oczekiwany efekt

Czas ładowania zakładki spadnie z kilkunastu sekund do **poniżej 1 sekundy** dla typowej bazy 6000 kont.
