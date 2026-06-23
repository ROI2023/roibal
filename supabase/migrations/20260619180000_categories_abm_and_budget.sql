-- ROIBAL-APP: Categories become a per-user ABM (no more shared NULL-user_id
-- rows that any user could mutate). The previous default categories now live
-- only as hardcoded suggestions in the app's "Nueva categoría" screen.
-- Also adds a recurring monthly budget per category, used to chart spending
-- vs. budget for the month.

delete from public.categories where user_id is null;

alter table public.categories alter column user_id set not null;

drop policy categories_select on public.categories;
create policy categories_select on public.categories
  for select using (user_id = auth.uid());

alter table public.categories add column budget_amount numeric(15,2);

alter table public.categories add constraint categories_budget_amount_check
  check (budget_amount is null or budget_amount >= 0);
