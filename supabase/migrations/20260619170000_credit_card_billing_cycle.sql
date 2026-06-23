-- ROIBAL-APP: Credit card billing cycle (closing day / due day), needed to
-- compute the correct payment date for purchases and installments shown in
-- Salidas Proyectadas.

alter table public.accounts add column closing_day integer;
alter table public.accounts add column due_day integer;

alter table public.accounts add constraint accounts_closing_day_check
  check (closing_day is null or (closing_day between 1 and 31));

alter table public.accounts add constraint accounts_due_day_check
  check (due_day is null or (due_day between 1 and 31));

alter table public.accounts add constraint accounts_credit_card_dates_check
  check (
    (type = 'credit_card' and closing_day is not null and due_day is not null)
    or (type <> 'credit_card' and closing_day is null and due_day is null)
  );
