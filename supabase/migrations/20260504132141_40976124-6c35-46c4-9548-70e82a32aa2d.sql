-- Trigger: gwarantuje że document_number zawsze pasuje do document_date
CREATE OR REPLACE FUNCTION public.enforce_document_number_matches_date()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year int;
  v_month int;
  v_house_abbr text;
  v_expected_pattern text;
BEGIN
  v_year := EXTRACT(YEAR FROM NEW.document_date)::int;
  v_month := EXTRACT(MONTH FROM NEW.document_date)::int;

  SELECT house_abbreviation INTO v_house_abbr
  FROM public.location_settings
  WHERE location_id = NEW.location_id;

  IF v_house_abbr IS NULL THEN
    v_house_abbr := 'DOM';
  END IF;

  v_expected_pattern := '^' || v_house_abbr || '/' || v_year || '/' || LPAD(v_month::text, 2, '0') || '/[0-9]+$';

  IF NEW.document_number IS NULL OR NEW.document_number !~ v_expected_pattern THEN
    NEW.document_number := public.generate_document_number(NEW.location_id, v_year, v_month);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_document_number_matches_date ON public.documents;
CREATE TRIGGER trg_enforce_document_number_matches_date
BEFORE INSERT OR UPDATE OF document_number, document_date, location_id ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.enforce_document_number_matches_date();

-- Jednorazowa naprawa istniejących rozjechanych dokumentów
DO $$
DECLARE
  r record;
  v_house_abbr text;
  v_pattern text;
  v_new_number text;
BEGIN
  FOR r IN
    SELECT d.id, d.location_id, d.document_date, d.document_number
    FROM public.documents d
  LOOP
    SELECT house_abbreviation INTO v_house_abbr
    FROM public.location_settings WHERE location_id = r.location_id;
    IF v_house_abbr IS NULL THEN v_house_abbr := 'DOM'; END IF;

    v_pattern := '^' || v_house_abbr || '/' || EXTRACT(YEAR FROM r.document_date)::int
                 || '/' || LPAD(EXTRACT(MONTH FROM r.document_date)::int::text, 2, '0')
                 || '/[0-9]+$';

    IF r.document_number !~ v_pattern THEN
      v_new_number := public.generate_document_number(
        r.location_id,
        EXTRACT(YEAR FROM r.document_date)::int,
        EXTRACT(MONTH FROM r.document_date)::int
      );

      UPDATE public.documents SET document_number = v_new_number WHERE id = r.id;
      UPDATE public.transactions SET document_number = v_new_number WHERE document_id = r.id;
    END IF;
  END LOOP;
END $$;