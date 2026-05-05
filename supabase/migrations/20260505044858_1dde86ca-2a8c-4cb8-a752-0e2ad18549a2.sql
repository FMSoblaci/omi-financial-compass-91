
-- 1) Trigger: zachowaj updated_at przy braku realnych zmian
CREATE OR REPLACE FUNCTION public.preserve_documents_updated_at_on_no_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.document_number IS NOT DISTINCT FROM OLD.document_number
       AND NEW.document_name IS NOT DISTINCT FROM OLD.document_name
       AND NEW.document_date IS NOT DISTINCT FROM OLD.document_date
       AND NEW.currency IS NOT DISTINCT FROM OLD.currency
       AND NEW.exchange_rate IS NOT DISTINCT FROM OLD.exchange_rate
       AND NEW.location_id IS NOT DISTINCT FROM OLD.location_id
       AND NEW.validation_errors IS NOT DISTINCT FROM OLD.validation_errors
    THEN
      NEW.updated_at := OLD.updated_at;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_preserve_documents_updated_at ON public.documents;
CREATE TRIGGER trg_preserve_documents_updated_at
BEFORE UPDATE ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.preserve_documents_updated_at_on_no_change();

-- 2) Audyt dokumentów
CREATE TABLE IF NOT EXISTS public.documents_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid,
  action text NOT NULL,
  changed_columns jsonb,
  old_values jsonb,
  new_values jsonb,
  changed_by uuid,
  changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_documents_audit_log_document ON public.documents_audit_log(document_id, changed_at DESC);

ALTER TABLE public.documents_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admini widzą audyt dokumentów"
ON public.documents_audit_log
FOR SELECT
USING (get_user_role() = ANY (ARRAY['admin','prowincjal']));

CREATE OR REPLACE FUNCTION public.log_documents_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_changed jsonb := '{}'::jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.documents_audit_log(document_id, action, new_values, changed_by)
    VALUES (NEW.id, 'INSERT', to_jsonb(NEW), auth.uid());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.document_number IS DISTINCT FROM OLD.document_number THEN
      v_changed := v_changed || jsonb_build_object('document_number', jsonb_build_object('old', OLD.document_number, 'new', NEW.document_number));
    END IF;
    IF NEW.document_name IS DISTINCT FROM OLD.document_name THEN
      v_changed := v_changed || jsonb_build_object('document_name', jsonb_build_object('old', OLD.document_name, 'new', NEW.document_name));
    END IF;
    IF NEW.document_date IS DISTINCT FROM OLD.document_date THEN
      v_changed := v_changed || jsonb_build_object('document_date', jsonb_build_object('old', OLD.document_date, 'new', NEW.document_date));
    END IF;
    IF NEW.currency IS DISTINCT FROM OLD.currency THEN
      v_changed := v_changed || jsonb_build_object('currency', jsonb_build_object('old', OLD.currency, 'new', NEW.currency));
    END IF;
    IF NEW.exchange_rate IS DISTINCT FROM OLD.exchange_rate THEN
      v_changed := v_changed || jsonb_build_object('exchange_rate', jsonb_build_object('old', OLD.exchange_rate, 'new', NEW.exchange_rate));
    END IF;
    IF NEW.location_id IS DISTINCT FROM OLD.location_id THEN
      v_changed := v_changed || jsonb_build_object('location_id', jsonb_build_object('old', OLD.location_id, 'new', NEW.location_id));
    END IF;
    IF NEW.validation_errors IS DISTINCT FROM OLD.validation_errors THEN
      v_changed := v_changed || jsonb_build_object('validation_errors', 'changed');
    END IF;

    IF v_changed <> '{}'::jsonb THEN
      INSERT INTO public.documents_audit_log(document_id, action, changed_columns, old_values, new_values, changed_by)
      VALUES (NEW.id, 'UPDATE', v_changed, to_jsonb(OLD), to_jsonb(NEW), auth.uid());
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.documents_audit_log(document_id, action, old_values, changed_by)
    VALUES (OLD.id, 'DELETE', to_jsonb(OLD), auth.uid());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_documents_audit ON public.documents;
CREATE TRIGGER trg_log_documents_audit
AFTER INSERT OR UPDATE OR DELETE ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.log_documents_audit();

-- 3) Materiały użytkowników w bazie wiedzy
CREATE TABLE IF NOT EXISTS public.knowledge_user_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_key text NOT NULL,
  title text NOT NULL,
  description text,
  file_path text NOT NULL,
  file_type text NOT NULL CHECK (file_type IN ('image','video')),
  mime_type text,
  file_size bigint,
  uploaded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_knowledge_user_media_topic ON public.knowledge_user_media(topic_key, created_at DESC);

ALTER TABLE public.knowledge_user_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Wszyscy zalogowani widzą materiały KB"
ON public.knowledge_user_media FOR SELECT
TO authenticated USING (true);

CREATE POLICY "Każdy zalogowany dodaje swoje materiały KB"
ON public.knowledge_user_media FOR INSERT
TO authenticated WITH CHECK (uploaded_by = auth.uid());

CREATE POLICY "Autor lub admin może usunąć materiał KB"
ON public.knowledge_user_media FOR DELETE
TO authenticated USING (
  uploaded_by = auth.uid() OR get_user_role() = ANY(ARRAY['admin','prowincjal'])
);

-- Bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('knowledge-user-media', 'knowledge-user-media', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "Public read knowledge user media" ON storage.objects;
CREATE POLICY "Public read knowledge user media"
ON storage.objects FOR SELECT
USING (bucket_id = 'knowledge-user-media');

DROP POLICY IF EXISTS "Auth upload knowledge user media" ON storage.objects;
CREATE POLICY "Auth upload knowledge user media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'knowledge-user-media');

DROP POLICY IF EXISTS "Owner or admin delete knowledge user media" ON storage.objects;
CREATE POLICY "Owner or admin delete knowledge user media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'knowledge-user-media' AND (
    owner = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ANY(ARRAY['admin','prowincjal']))
  )
);
