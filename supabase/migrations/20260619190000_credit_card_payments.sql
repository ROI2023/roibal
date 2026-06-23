-- ROIBAL-APP: Support "Pagar tarjeta" — paying off a credit card statement
-- from one or more real accounts (banco/efectivo/billetera). The payment
-- itself is a transfer between accounts (no category), separate from any
-- interest/fees/taxes charged by the card, which are recorded as a normal
-- expense transaction so they don't get lost.

alter table public.transactions add column is_transfer boolean not null default false;

alter table public.transactions alter column category_id drop not null;

alter table public.transactions add constraint transactions_transfer_category_check
  check (
    (is_transfer and category_id is null) or
    (not is_transfer and category_id is not null)
  );
