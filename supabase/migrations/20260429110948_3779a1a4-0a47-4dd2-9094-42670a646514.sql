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
  v_today date := CURRENT_DATE;
  v_user_role text;
  v_user_location_ids uuid[];
  v_blocked boolean;
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

  SELECT check_report_editing_blocked(v_source_doc.location_id, v_today) INTO v_blocked;
  IF v_blocked THEN
    RAISE EXCEPTION 'Nie można skopiować dokumentu — bieżący okres (%) jest zablokowany przez istniejący raport', to_char(v_today, 'MM/YYYY');
  END IF;

  v_new_doc_number := generate_document_number(
    v_source_doc.location_id,
    EXTRACT(YEAR FROM v_today)::int,
    EXTRACT(MONTH FROM v_today)::int
  );

  -- Domyślna nazwa: "kopia - <oryginał>" (bez dublowania prefiksu)
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
    v_today,
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
    v_new_doc_id, v_source_doc.location_id, auth.uid(), v_today,
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