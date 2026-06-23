-- ROIBAL-APP: Add 'savings_wallet' as a valid account type (Cuentas y Billeteras:
-- cajas de ahorro and virtual wallets like Mercado Pago / Ualá).

alter table public.accounts drop constraint accounts_type_check;

alter table public.accounts add constraint accounts_type_check
  check (type in ('cash', 'credit_card', 'investment', 'savings_wallet'));
