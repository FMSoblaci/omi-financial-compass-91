-- Trigger 1: blokuj zapis dokumentu (INSERT/UPDATE) gdy data wpada w zablokowany przez raport okres
CREATE OR REPLACE FUNCTION public.enforce_document_date_not_locked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked boolean;
  v_user_role text;
BEGIN
  -- Nie blokuj jeśli data nie zmieniła się przy UPDATE
  IF TG_OP = 'UPDATE' AND OLD.document_date = NEW.document_date AND OLD.location_id = NEW.location_id THEN
    RETURN NEW;
  END IF;

  SELECT public.check_report_editing_blocked(NEW.location_id, NEW.document_date) INTO v_blocked;

  IF v_blocked THEN
    -- Pozwól adminowi/prowincjałowi (mogą mieć powody; nadal mają miękkie blokady w UI)
    SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();
    IF v_user_role IS NOT DISTINCT FROM 'admin' OR v_user_role IS NOT DISTINCT FROM 'prowincjal' THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Nie można zapisać dokumentu z datą % — okres %/% jest zablokowany przez istniejący raport',
      to_char(NEW.document_date, 'DD.MM.YYYY'),
      LPAD(EXTRACT(MONTH FROM NEW.document_date)::text, 2, '0'),
      EXTRACT(YEAR FROM NEW.document_date)::text;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_document_date_not_locked ON public.documents;
CREATE TRIGGER trg_enforce_document_date_not_locked
BEFORE INSERT OR UPDATE ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.enforce_document_date_not_locked();


-- Trigger 2: automatycznie regeneruj numer dokumentu gdy zmienia się miesiąc/rok daty
-- (chyba że użytkownik jawnie ustawił numer pasujący do nowego okresu)
CREATE OR REPLACE FUNCTION public.auto_regenerate_document_number()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_year int;
  v_old_month int;
  v_new_year int;
  v_new_month int;
  v_house_abbr text;
  v_expected_pattern text;
BEGIN
  v_old_year := EXTRACT(YEAR FROM OLD.document_date)::int;
  v_old_month := EXTRACT(MONTH FROM OLD.document_date)::int;
  v_new_year := EXTRACT(YEAR FROM NEW.document_date)::int;
  v_new_month := EXTRACT(MONTH FROM NEW.document_date)::int;

  -- Tylko gdy zmienił się miesiąc lub rok
  IF v_old_year = v_new_year AND v_old_month = v_new_month THEN
    RETURN NEW;
  END IF;

  -- Pobierz skrót domu
  SELECT house_abbreviation INTO v_house_abbr
  FROM public.location_settings WHERE location_id = NEW.location_id;
  IF v_house_abbr IS NULL THEN
    v_house_abbr := 'DOM';
  END IF;

  -- Wzorzec, jaki POWINIEN mieć numer dla nowej daty
  v_expected_pattern := '^' || v_house_abbr || '/' || v_new_year || '/' || LPAD(v_new_month::text, 2, '0') || '/[0-9]+$';

  -- Jeśli numer już pasuje do nowego okresu (ktoś go ręcznie zaktualizował), nie ruszaj
  IF NEW.document_number ~ v_expected_pattern THEN
    RETURN NEW;
  END IF;

  -- Wygeneruj nowy numer dla nowego miesiąca/roku
  NEW.document_number := public.generate_document_number(NEW.location_id, v_new_year, v_new_month);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_regenerate_document_number ON public.documents;
CREATE TRIGGER trg_auto_regenerate_document_number
BEFORE UPDATE OF document_date ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.auto_regenerate_document_number();