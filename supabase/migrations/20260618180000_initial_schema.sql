-- ROIBAL-APP: Initial schema
-- Multi-tenant (shared tables + user_id + RLS), per DDA section 2 "Arquitectura Multiusuario Segura"

create extension if not exists "uuid-ossp";

-- =========================================================
-- 1. Categories (global defaults + user-created custom ones)
-- =========================================================
create table public.categories (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade,
    name varchar(100) not null,
    icon_name varchar(50) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

comment on column public.categories.user_id is 'NULL = global default category visible to everyone; set = user-owned custom category';

-- =========================================================
-- 2. Accounts (cash, credit card, investment)
-- =========================================================
create table public.accounts (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    name varchar(100) not null,
    type varchar(20) not null check (type in ('cash', 'credit_card', 'investment')),
    currency varchar(3) not null check (currency in ('ARS', 'USD')),
    current_balance numeric(15, 2) not null default 0.00,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- =========================================================
-- 3. Recurring expense templates (rent, subscriptions, etc.)
-- =========================================================
create table public.recurring_expenses (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    description varchar(255) not null,
    category_id uuid not null references public.categories(id) on delete restrict,
    account_id uuid not null references public.accounts(id) on delete restrict,
    currency varchar(3) not null check (currency in ('ARS', 'USD')),
    amount numeric(15, 2) not null check (amount > 0),
    cycle_type varchar(20) not null check (cycle_type in ('monthly_day', 'every_n_days')),
    cycle_day int check (cycle_day between 1 and 31),
    interval_days int check (interval_days > 0),
    start_date date not null,
    months_to_generate int not null default 12 check (months_to_generate > 0),
    is_active boolean not null default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,

    constraint chk_cycle_fields check (
        (cycle_type = 'monthly_day' and cycle_day is not null)
        or (cycle_type = 'every_n_days' and interval_days is not null)
    )
);

-- =========================================================
-- 4. Transactions / Purchases
-- =========================================================
create table public.transactions (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    description varchar(255) not null,
    category_id uuid not null references public.categories(id) on delete restrict,
    recurring_expense_id uuid references public.recurring_expenses(id) on delete set null,
    currency varchar(3) not null check (currency in ('ARS', 'USD')),
    total_amount numeric(15, 2) not null check (total_amount >= 0),
    transaction_date timestamp with time zone not null default timezone('utc'::text, now()),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

comment on column public.transactions.transaction_date is 'When the expense actually happened (may differ from created_at, e.g. OCR-extracted ticket date)';

-- =========================================================
-- 5. Transaction Payments / Installments
-- Core table for split payments and the 6-12 month due-date map
-- =========================================================
create table public.transaction_payments (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    transaction_id uuid not null references public.transactions(id) on delete cascade,
    account_id uuid not null references public.accounts(id) on delete restrict,
    currency varchar(3) not null check (currency in ('ARS', 'USD')),
    amount numeric(15, 2) not null check (amount > 0),
    installment_number int not null default 1 check (installment_number >= 1),
    total_installments int not null default 1 check (total_installments >= 1),
    due_date date not null,
    status varchar(20) not null default 'paid' check (status in ('paid', 'pending')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,

    constraint chk_installment_range check (installment_number <= total_installments)
);

-- =========================================================
-- 6. Budgets (per category, per month)
-- =========================================================
create table public.budgets (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    category_id uuid not null references public.categories(id) on delete cascade,
    currency varchar(3) not null check (currency in ('ARS', 'USD')),
    amount numeric(15, 2) not null check (amount >= 0),
    period_year int not null check (period_year >= 2020),
    period_month int not null check (period_month between 1 and 12),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,

    unique (user_id, category_id, period_year, period_month)
);

-- =========================================================
-- Indexes
-- =========================================================
create index idx_categories_user_id on public.categories(user_id);
create index idx_accounts_user_id on public.accounts(user_id);
create index idx_recurring_expenses_user_id on public.recurring_expenses(user_id);
create index idx_transactions_user_id on public.transactions(user_id);
create index idx_transactions_date on public.transactions(transaction_date);
create index idx_transaction_payments_user_id on public.transaction_payments(user_id);
create index idx_transaction_payments_due_date on public.transaction_payments(due_date, status);
create index idx_budgets_user_id on public.budgets(user_id);

-- =========================================================
-- Row Level Security
-- =========================================================
alter table public.categories enable row level security;
alter table public.accounts enable row level security;
alter table public.recurring_expenses enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_payments enable row level security;
alter table public.budgets enable row level security;

-- Categories: everyone can read globals + their own; users only manage their own
create policy "categories_select" on public.categories
    for select using (user_id is null or user_id = auth.uid());
create policy "categories_insert" on public.categories
    for insert with check (user_id = auth.uid());
create policy "categories_update" on public.categories
    for update using (user_id = auth.uid());
create policy "categories_delete" on public.categories
    for delete using (user_id = auth.uid());

-- Accounts
create policy "accounts_select" on public.accounts
    for select using (user_id = auth.uid());
create policy "accounts_insert" on public.accounts
    for insert with check (user_id = auth.uid());
create policy "accounts_update" on public.accounts
    for update using (user_id = auth.uid());
create policy "accounts_delete" on public.accounts
    for delete using (user_id = auth.uid());

-- Recurring expenses
create policy "recurring_expenses_select" on public.recurring_expenses
    for select using (user_id = auth.uid());
create policy "recurring_expenses_insert" on public.recurring_expenses
    for insert with check (user_id = auth.uid());
create policy "recurring_expenses_update" on public.recurring_expenses
    for update using (user_id = auth.uid());
create policy "recurring_expenses_delete" on public.recurring_expenses
    for delete using (user_id = auth.uid());

-- Transactions
create policy "transactions_select" on public.transactions
    for select using (user_id = auth.uid());
create policy "transactions_insert" on public.transactions
    for insert with check (user_id = auth.uid());
create policy "transactions_update" on public.transactions
    for update using (user_id = auth.uid());
create policy "transactions_delete" on public.transactions
    for delete using (user_id = auth.uid());

-- Transaction payments
create policy "transaction_payments_select" on public.transaction_payments
    for select using (user_id = auth.uid());
create policy "transaction_payments_insert" on public.transaction_payments
    for insert with check (user_id = auth.uid());
create policy "transaction_payments_update" on public.transaction_payments
    for update using (user_id = auth.uid());
create policy "transaction_payments_delete" on public.transaction_payments
    for delete using (user_id = auth.uid());

-- Budgets
create policy "budgets_select" on public.budgets
    for select using (user_id = auth.uid());
create policy "budgets_insert" on public.budgets
    for insert with check (user_id = auth.uid());
create policy "budgets_update" on public.budgets
    for update using (user_id = auth.uid());
create policy "budgets_delete" on public.budgets
    for delete using (user_id = auth.uid());

-- =========================================================
-- Default global categories (user_id null = visible to all)
-- =========================================================
insert into public.categories (name, icon_name) values
('Food & Groceries', 'restaurant'),
('Transport', 'directions_car'),
('Utilities & Services', 'receipt'),
('Leisure & Entertainment', 'local_play'),
('Investments', 'trending_up'),
('Other', 'help_outline');
