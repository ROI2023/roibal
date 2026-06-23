-- ROIBAL-APP: Track *when* a movement was actually paid, separately from its
-- (possibly different) projected due_date. This is what lets the dashboard
-- compute real cash-basis "Salidas del mes" — e.g. a credit card installment
-- counts as a June outflow when its card payment is registered in June,
-- regardless of which month it was originally due or purchased in.

alter table public.transaction_movements add column paid_date timestamp with time zone;

-- Best-effort backfill for existing data: due_date is the closest known proxy.
update public.transaction_movements
    set paid_date = due_date::timestamp with time zone
    where status = 'paid' and paid_date is null;

create index idx_transaction_movements_paid_date on public.transaction_movements(paid_date);
