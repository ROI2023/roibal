-- ROIBAL-APP: Generalize categories to support income, track account
-- balances over time, and rename transaction_payments -> transaction_movements
-- with signed amounts (+ income / - expense) instead of always-positive "payments".

-- =========================================================
-- 1. Categories: expense vs income
-- =========================================================
alter table public.categories
    add column type varchar(10) not null default 'expense' check (type in ('expense', 'income'));

insert into public.categories (name, icon_name, type) values
('Salario', 'savings', 'income'),
('Honorarios', 'trending_up', 'income'),
('Otros ingresos', 'receipt', 'income');

-- =========================================================
-- 2. Accounts: track initial balance + last update separately
--    from the running current_balance (now maintained by trigger, see below)
-- =========================================================
alter table public.accounts
    add column initial_balance numeric(15, 2) not null default 0.00,
    add column last_update timestamp with time zone not null default timezone('utc'::text, now());

update public.accounts set initial_balance = current_balance;

-- =========================================================
-- 3. Rename transaction_payments -> transaction_movements
-- =========================================================
alter table public.transaction_payments rename to transaction_movements;

alter table public.transaction_movements rename constraint transaction_payments_pkey to transaction_movements_pkey;
alter table public.transaction_movements rename constraint chk_installment_range to chk_movement_installment_range;
alter table public.transaction_movements rename constraint transaction_payments_currency_check to transaction_movements_currency_check;
alter table public.transaction_movements rename constraint transaction_payments_installment_number_check to transaction_movements_installment_number_check;
alter table public.transaction_movements rename constraint transaction_payments_status_check to transaction_movements_status_check;
alter table public.transaction_movements rename constraint transaction_payments_total_installments_check to transaction_movements_total_installments_check;
alter table public.transaction_movements rename constraint transaction_payments_account_id_fkey to transaction_movements_account_id_fkey;
alter table public.transaction_movements rename constraint transaction_payments_transaction_id_fkey to transaction_movements_transaction_id_fkey;
alter table public.transaction_movements rename constraint transaction_payments_user_id_fkey to transaction_movements_user_id_fkey;

alter index idx_transaction_payments_user_id rename to idx_transaction_movements_user_id;
alter index idx_transaction_payments_due_date rename to idx_transaction_movements_due_date;

-- Amounts become signed: positive = money in, negative = money out.
alter table public.transaction_movements drop constraint transaction_payments_amount_check;
alter table public.transaction_movements add constraint transaction_movements_amount_check check (amount <> 0);

-- All pre-existing rows were expense payments (always-positive); they now
-- represent money leaving the account, so flip them negative.
update public.transaction_movements set amount = -amount;

drop policy "transaction_payments_select" on public.transaction_movements;
drop policy "transaction_payments_insert" on public.transaction_movements;
drop policy "transaction_payments_update" on public.transaction_movements;
drop policy "transaction_payments_delete" on public.transaction_movements;

create policy "transaction_movements_select" on public.transaction_movements
    for select using (user_id = auth.uid());
create policy "transaction_movements_insert" on public.transaction_movements
    for insert with check (user_id = auth.uid());
create policy "transaction_movements_update" on public.transaction_movements
    for update using (user_id = auth.uid());
create policy "transaction_movements_delete" on public.transaction_movements
    for delete using (user_id = auth.uid());

-- =========================================================
-- 4. Keep accounts.current_balance + last_update in sync with paid
--    movements, so clients never have to recompute balances themselves.
--    Only 'paid' movements affect the balance; 'pending' installments
--    (future due dates) do not until they transition to 'paid'.
-- =========================================================
create or replace function public.apply_transaction_movement_to_balance()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' then
        if new.status = 'paid' then
            update public.accounts
                set current_balance = current_balance + new.amount,
                    last_update = timezone('utc'::text, now())
                where id = new.account_id;
        end if;
        return new;
    end if;

    if tg_op = 'UPDATE' then
        if old.status = 'paid' then
            update public.accounts
                set current_balance = current_balance - old.amount,
                    last_update = timezone('utc'::text, now())
                where id = old.account_id;
        end if;
        if new.status = 'paid' then
            update public.accounts
                set current_balance = current_balance + new.amount,
                    last_update = timezone('utc'::text, now())
                where id = new.account_id;
        end if;
        return new;
    end if;

    if tg_op = 'DELETE' then
        if old.status = 'paid' then
            update public.accounts
                set current_balance = current_balance - old.amount,
                    last_update = timezone('utc'::text, now())
                where id = old.account_id;
        end if;
        return old;
    end if;

    return null;
end;
$$;

create trigger trg_transaction_movements_balance
    after insert or update or delete on public.transaction_movements
    for each row execute function public.apply_transaction_movement_to_balance();
