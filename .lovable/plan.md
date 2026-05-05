# Plan naprawy + rozszerzenia

## 1. Dokument modyfikuje się/zmienia numer mimo braku zapisu

### Co potwierdziłem analizując kod
- Zapisy do bazy (`documents.update`, `transactions.update/insert/delete`) **wykonywane są wyłącznie** w `onSubmit` (`DocumentDialog.tsx` ~990–1100). Samo otwarcie i zamknięcie dokumentu **nie wywołuje** zapisu — żaden `useEffect` ani `setInterval` nie pisze w tle.
- Trigger DB `update_documents_updated_at` (set_updated_at) odpala się tylko przy realnym `UPDATE` — więc bez zapisu data modyfikacji się nie zmienia.
- Trigger `enforce_document_number_matches_date` (dodany ostatnio) regeneruje numer **tylko jeśli wykonujemy UPDATE i numer nie pasuje do daty**. Bez UPDATE też nic nie robi.

Wniosek: opisany incydent ze zmianą numeru z marca na maj wynikał ze starej race-condition (już załatanej w poprzedniej iteracji). Po naprawie samo otworzenie/anulowanie nie modyfikuje dokumentu.

### Dodatkowe usztywnienia (defense in depth)
1. **`DocumentDialog.tsx`** – w efekcie obserwującym datę dla istniejących dokumentów (linie 654–678) **nie aktualizuj `originalDocumentDate.current` w callbacku watchera**. Aktualizuj go dopiero w `onSubmit` po udanym zapisie. Dzięki temu:
   - Jeśli użytkownik zmieni datę i kliknie Anuluj, formularz się resetuje i nic nie zostaje przepisane.
   - Wygenerowany numer ląduje tylko w stanie formularza (RHF), nie w DB.
2. **Form-level guard** – w `handleDialogOpenChange` / `handleConfirmClose` wyraźnie zerujemy `hasUnsavedChanges` zanim `onClose()`. Dodaj w `onSubmit` warunek: jeśli `form.formState.isDirty === false` i `transactions` nie zmieniły się względem stanu wczytanego (porównanie hash), **pomiń wywołanie `supabase.update`** — to ostatecznie eliminuje „milczące UPDATE bez zmian”.
3. **Trigger DB `enforce_updated_at_only_on_real_change`** – nowy `BEFORE UPDATE` na `documents`: jeśli wszystkie kolumny merytoryczne (`document_number`, `document_name`, `document_date`, `currency`, `exchange_rate`, `validation_errors`, `location_id`) są równe wartościom OLD, ustawia `NEW.updated_at = OLD.updated_at`. Gwarantuje, że żaden niezamierzony `UPDATE` (np. z innego ekranu) nie zaktualizuje stempla modyfikacji.
4. **Diagnostyka** – nowa tabela `documents_audit_log` (id, document_id, action, changed_columns jsonb, old_values jsonb, new_values jsonb, changed_by, changed_at) + trigger `AFTER INSERT OR UPDATE OR DELETE` na `documents`. Dzięki temu w razie kolejnych „dziwnych zdarzeń” mamy pełną ścieżkę audytu (kto/kiedy/co zmienił).

## 2. Tab na końcu ostatniej operacji nie tworzy nowej (poza nowymi dokumentami)

### Przyczyna
W `DocumentDialog.tsx` (linia 369) `InlineTransactionRow` jest auto-pokazywany **tylko dla nowych dokumentów** (`!document`). Dla edycji istniejącego/importowanego dokumentu pusty wiersz pojawia się dopiero po kliknięciu „Dodaj operację”, więc Tab z ostatniej kolumny ostatniej operacji wyskakuje poza tabelę zamiast utworzyć nowy wiersz.

### Naprawa
1. Zmienić warunek na: pokazuj `InlineTransactionRow` zawsze, gdy dialog jest otwarty i dokument nie jest zablokowany (`isOpen && !isFullyLocked && !isEditingBlocked`). Dotyczy obu sekcji: główne księgowanie i równoległe.
2. Po `onSave` w `InlineTransactionRow` (już istnieje `resetForm` z fokusem na opis) — stan zostaje, więc kolejne Tab→…→ostatnie pole zapisuje i tworzy następny wiersz automatycznie. Zachowanie identyczne dla nowych i edytowanych dokumentów.
3. **EditableTransactionRow → InlineTransactionRow przejście**: ostatnia komórka istniejącego wiersza to AccountCombobox „Ma”. Domyślny tab order DOM przeniesie focus do pierwszego inputa kolejnego renderowanego wiersza (pole „Opis” w InlineTransactionRow), więc gdy InlineTransactionRow będzie zawsze widoczny pod istniejącymi wierszami, Tab z ostatniego pola ostatniej operacji wpadnie wprost w opis nowej operacji. Brak dodatkowej logiki kursora.
4. Dla bezpieczeństwa dodać w InlineTransactionRow nasłuch `onKeyDown` na ostatnim AccountCombobox „Ma”: gdy `Tab` bez `Shift` i wiersz jest pełny i poprawny → wymuś `handleRowBlur` natychmiast (a nie dopiero po focusout poza wiersz), żeby zapis i reset focus były spójne.
5. Zweryfikować, że ten sam mechanizm działa w trybie księgowania równoległego (`parallelInlineFormRef`) — analogiczna zmiana warunku.

## 3. Baza wiedzy – pełny audyt i uzupełnienie

### Działania
1. Przejrzeć `KnowledgeBasePage.tsx` (1179 linii) — zinwentaryzować istniejące sekcje/tematy.
2. Porównać z faktyczną mapą funkcji aplikacji (Dokumenty, KPIR, Raporty, Budżet, Kalendarz, Administracja, MT940, kopia dokumentów, blokady okresów, generowanie numerów, opłata prowincjalna, multi-waluty NBP, role, kontakty, eksporty).
3. Uzupełnić brakujące tematy w treści Markdown sekcji wiedzy (każdy temat: po co, jak użyć krok-po-kroku, ograniczenia, FAQ).
4. Zaktualizować szczególnie dla niedawno wprowadzonych zmian: kopiowanie dokumentu („kopia – …”), automatyczna pierwsza data niezablokowanego okresu, ochrona numeru/daty przed race-condition, screenshoty w zgłaszaniu błędów (`html-to-image`).

## 4. Dodawanie materiałów użytkowników (screeny/filmy) w bazie wiedzy

### Schemat bazy (migracja)
```sql
-- bucket
insert into storage.buckets (id, name, public) values ('knowledge-user-media', 'knowledge-user-media', true);

-- tabela
create table public.knowledge_user_media (
  id uuid primary key default gen_random_uuid(),
  topic_key text not null,         -- np. "documents.copy", "budget.import"
  title text not null,
  description text,
  file_path text not null,         -- ścieżka w buckecie
  file_type text not null,         -- 'image' | 'video'
  mime_type text,
  file_size bigint,
  uploaded_by uuid not null,
  created_at timestamptz not null default now()
);
create index on public.knowledge_user_media(topic_key, created_at desc);

alter table public.knowledge_user_media enable row level security;

-- RLS
create policy "Wszyscy zalogowani widzą materiały" on public.knowledge_user_media
  for select to authenticated using (true);
create policy "Każdy zalogowany dodaje swoje materiały" on public.knowledge_user_media
  for insert to authenticated with check (uploaded_by = auth.uid());
create policy "Autor lub admin może usunąć" on public.knowledge_user_media
  for delete to authenticated using (
    uploaded_by = auth.uid() or get_user_role() = any(array['admin','prowincjal'])
  );

-- storage policies (public read, auth write)
create policy "Public read knowledge media" on storage.objects
  for select using (bucket_id = 'knowledge-user-media');
create policy "Auth upload knowledge media" on storage.objects
  for insert to authenticated with check (bucket_id = 'knowledge-user-media');
create policy "Owner/admin delete knowledge media" on storage.objects
  for delete to authenticated using (
    bucket_id = 'knowledge-user-media' and (
      owner = auth.uid() or
      exists (select 1 from profiles where id = auth.uid() and role = any(array['admin','prowincjal']))
    )
  );
```

### Frontend
1. Nowy komponent `src/pages/KnowledgeBase/UserMediaSection.tsx`:
   - Props: `topicKey: string`, `topicTitle: string`.
   - Sekcja na końcu każdej strony tematu KB (Akordeon „Materiały od użytkowników”).
   - Lista (grid responsywny):
     - Obrazy: thumbnail z lightboxem.
     - Filmy: `<video controls preload="metadata">` (mp4/webm; akceptowane także `.mov` jeśli przeglądarka obsłuży).
     - Pod każdym: tytuł, opis, autor (`profiles.name`), data, przycisk „Usuń” widoczny dla autora i adminów.
   - Formularz dodawania: pola `title` (wymagane), `description`, file input akceptujący `image/*,video/*`. Limit 50 MB.
   - Upload do bucketu `knowledge-user-media` w ścieżce `${topicKey}/${userId}/${uuid}.${ext}`, potem insert do tabeli.
   - Toasty + invalidacja React Query.
2. Wstawić `<UserMediaSection topicKey="..." />` na końcu każdej zakładki/sekcji w `KnowledgeBasePage.tsx` (kluczem jest stabilny slug tematu).
3. Bez paginacji w MVP — sortowanie najnowsze najpierw.
4. Walidacje po stronie klienta: typ pliku zgodny z `image/*` lub `video/*`, rozmiar ≤ 50 MB, tytuł wymagany.

## Pliki, które się zmienią
- `src/pages/Documents/DocumentDialog.tsx` — zmiany z punktów 1.1, 1.2, 2.1, 2.3.
- `src/pages/Documents/InlineTransactionRow.tsx` — guard Tab z punktu 2.4.
- `src/pages/KnowledgeBase/KnowledgeBasePage.tsx` — uzupełnienia treści (3) + osadzenie `UserMediaSection` (4).
- `src/pages/KnowledgeBase/UserMediaSection.tsx` — nowy komponent.
- nowa migracja SQL: trigger `enforce_updated_at_only_on_real_change`, tabela `documents_audit_log` + trigger, bucket + tabela `knowledge_user_media` + RLS.

## Czego NIE ruszamy
- Działającego mechanizmu generowania numerów po realnej zmianie miesiąca/roku przez użytkownika i jego zapisie — to celowe.
- Triggera `enforce_document_number_matches_date` — pełni rolę bramki bezpieczeństwa.
- Library `html2canvas` używanej w generatorach PDF.
