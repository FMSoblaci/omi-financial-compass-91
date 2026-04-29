CREATE OR REPLACE FUNCTION public.duplicate_document(p_document_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_source_doc documents%ROWTYPE;
  v_new_doc_id uuid;
  v_new_doc_number text;
  v_new_doc_name text;
  v_target_date date := CURRENT_DATE;
  v_user_role text;
  v_user_location_ids uuid[];
  v_blocked boolean;
  v_attempts int := 0;
BEGIN
  SELECT * INTO v_source_doc FROM documents WHERE id = p_document_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dokument źródłowy nie istnieje';
  END IF;

  SELECT role INTO v_user_role FROM profiles WHERE id = auth.uid();
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'Brak autoryzacji';
  END IF;

  IF v_user_role NOT IN ('admin', 'prowincjal') THEN
    SELECT ARRAY_AGG(location_id) INTO v_user_location_ids
    FROM user_locations WHERE user_id = auth.uid();

    IF v_user_location_ids IS NULL OR NOT (v_source_doc.location_id = ANY(v_user_location_ids)) THEN
      IF NOT EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid() AND location_id = v_source_doc.location_id
      ) THEN
        RAISE EXCEPTION 'Brak uprawnień do tego dokumentu';
      END IF;
    END IF;
  END IF;

  -- Znajdź pierwszą datę z niezablokowanym okresem (max 60 miesięcy w przód)
  LOOP
    SELECT check_report_editing_blocked(v_source_doc.location_id, v_target_date) INTO v_blocked;
    EXIT WHEN NOT v_blocked;

    v_attempts := v_attempts + 1;
    IF v_attempts > 60 THEN
      RAISE EXCEPTION 'Nie znaleziono dostępnego okresu w ciągu najbliższych 60 miesięcy';
    END IF;

    -- Przeskocz na 1. dzień kolejnego miesiąca
    v_target_date := (date_trunc('month', v_target_date) + INTERVAL '1 month')::date;
  END LOOP;

  v_new_doc_number := generate_document_number(
    v_source_doc.location_id,
    EXTRACT(YEAR FROM v_target_date)::int,
    EXTRACT(MONTH FROM v_target_date)::int
  );

  IF v_source_doc.document_name ILIKE 'kopia - %' THEN
    v_new_doc_name := v_source_doc.document_name;
  ELSE
    v_new_doc_name := 'kopia - ' || COALESCE(v_source_doc.document_name, '');
  END IF;

  INSERT INTO documents (
    document_number, document_name, document_date, location_id,
    user_id, currency, exchange_rate
  ) VALUES (
    v_new_doc_number,
    v_new_doc_name,
    v_target_date,
    v_source_doc.location_id,
    auth.uid(),
    v_source_doc.currency,
    v_source_doc.exchange_rate
  )
  RETURNING id INTO v_new_doc_id;

  INSERT INTO transactions (
    document_id, location_id, user_id, date,
    debit_account_id, credit_account_id,
    amount, debit_amount, credit_amount,
    description, settlement_type, currency, exchange_rate,
    document_number, display_order, is_parallel
  )
  SELECT
    v_new_doc_id, v_source_doc.location_id, auth.uid(), v_target_date,
    t.debit_account_id, t.credit_account_id,
    t.amount, t.debit_amount, t.credit_amount,
    t.description, t.settlement_type, t.currency, t.exchange_rate,
    v_new_doc_number, t.display_order, COALESCE(t.is_parallel, false)
  FROM transactions t
  WHERE t.document_id = p_document_id
    AND COALESCE(t.is_split_transaction, false) = false
    AND t.parent_transaction_id IS NULL;

  RETURN v_new_doc_id;
END;
$function$;