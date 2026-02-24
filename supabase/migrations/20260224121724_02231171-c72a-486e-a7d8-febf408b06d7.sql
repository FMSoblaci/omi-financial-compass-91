
-- Update budget_plans UPDATE policies to allow economists to edit rejected budgets
-- Drop and recreate the two UPDATE policies

DROP POLICY IF EXISTS "Budżety - UPDATE dla wszystkich ról" ON budget_plans;
CREATE POLICY "Budżety - UPDATE dla wszystkich ról" ON budget_plans
FOR UPDATE TO authenticated
USING (
  CASE
    WHEN (get_user_role() = 'ekonom') THEN (location_id = get_user_location_id() AND status IN ('draft', 'rejected'))
    WHEN (get_user_role() = ANY(ARRAY['admin', 'prowincjal'])) THEN true
    ELSE false
  END
)
WITH CHECK (
  CASE
    WHEN (get_user_role() = 'ekonom') THEN (location_id = get_user_location_id() AND status IN ('draft', 'submitted'))
    WHEN (get_user_role() = ANY(ARRAY['admin', 'prowincjal'])) THEN true
    ELSE false
  END
);

DROP POLICY IF EXISTS "Ekonomowie mogą edytować budżety draft swojej lokalizacji" ON budget_plans;
CREATE POLICY "Ekonomowie mogą edytować budżety draft i rejected swojej lokalizacji" ON budget_plans
FOR UPDATE TO authenticated
USING (
  ((get_user_role() = 'ekonom' AND location_id = get_user_location_id() AND status IN ('draft', 'rejected'))
   OR (get_user_role() = ANY(ARRAY['admin', 'prowincjal'])))
)
WITH CHECK (
  ((get_user_role() = 'ekonom' AND location_id = get_user_location_id() AND status IN ('draft', 'submitted'))
   OR (get_user_role() = ANY(ARRAY['admin', 'prowincjal'])))
);

-- Update budget_items policy to allow operations on rejected budgets
DROP POLICY IF EXISTS "Ekonomowie zarządzają items swojego budżetu" ON budget_items;
CREATE POLICY "Ekonomowie zarządzają items swojego budżetu" ON budget_items
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM budget_plans bp
    WHERE bp.id = budget_items.budget_plan_id
    AND (
      (get_user_role() = 'ekonom' AND bp.location_id = get_user_location_id() AND bp.status IN ('draft', 'submitted', 'rejected'))
      OR (get_user_role() = ANY(ARRAY['admin', 'prowincjal']))
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM budget_plans bp
    WHERE bp.id = budget_items.budget_plan_id
    AND (
      (get_user_role() = 'ekonom' AND bp.location_id = get_user_location_id() AND bp.status IN ('draft', 'submitted', 'rejected'))
      OR (get_user_role() = ANY(ARRAY['admin', 'prowincjal']))
    )
  )
);
