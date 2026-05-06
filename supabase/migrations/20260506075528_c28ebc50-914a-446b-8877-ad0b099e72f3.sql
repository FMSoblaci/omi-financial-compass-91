-- Per-account override percentage
ALTER TABLE public.provincial_fee_accounts
  ADD COLUMN IF NOT EXISTS fee_percentage NUMERIC NULL;

-- Exclusion table: location excluded from fee for given trigger account
CREATE TABLE IF NOT EXISTS public.provincial_fee_account_exclusions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  provincial_fee_account_id UUID NOT NULL REFERENCES public.provincial_fee_accounts(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES public.locations(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (provincial_fee_account_id, location_id)
);

ALTER TABLE public.provincial_fee_account_exclusions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can read provincial fee exclusions"
  ON public.provincial_fee_account_exclusions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage provincial fee exclusions"
  ON public.provincial_fee_account_exclusions FOR ALL
  TO authenticated
  USING (get_user_role() = ANY (ARRAY['admin'::text, 'prowincjal'::text]))
  WITH CHECK (get_user_role() = ANY (ARRAY['admin'::text, 'prowincjal'::text]));

CREATE INDEX IF NOT EXISTS idx_pfa_exclusions_account ON public.provincial_fee_account_exclusions(provincial_fee_account_id);
CREATE INDEX IF NOT EXISTS idx_pfa_exclusions_location ON public.provincial_fee_account_exclusions(location_id);