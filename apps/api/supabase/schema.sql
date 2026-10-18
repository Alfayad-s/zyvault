-- Run this once in the Supabase SQL editor.
-- The Nest API uses the service role key and filters every row by the signed-in user.

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('income', 'expense'))
);

-- Rows without user_id are the shared defaults; rows with one are that user's own categories.
alter table public.categories
  add column if not exists user_id uuid references auth.users (id) on delete cascade;
alter table public.categories add column if not exists icon text;
alter table public.categories drop constraint if exists categories_name_kind_key;
create unique index if not exists categories_owner_name_kind_idx on public.categories (
  coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name), kind
);

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  type text not null check (type in ('cash', 'bank')),
  opening_balance integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.accounts (id) on delete cascade,
  category_id uuid not null references public.categories (id),
  amount integer not null check (amount > 0),
  kind text not null check (kind in ('income', 'expense')),
  occurred_on date not null,
  note text,
  created_at timestamptz not null default now()
);

alter table public.accounts add column if not exists bank_id text;

create index if not exists accounts_user_id_idx on public.accounts (user_id);
create index if not exists transactions_user_month_idx
  on public.transactions (user_id, occurred_on desc);

alter table public.categories enable row level security;
alter table public.accounts enable row level security;
alter table public.transactions enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant select on public.categories to anon, authenticated, service_role;
grant select, insert, update, delete on public.accounts to authenticated, service_role;
grant select, insert, update, delete on public.transactions to authenticated, service_role;

drop policy if exists "categories are readable" on public.categories;
create policy "categories are readable" on public.categories
  for select using (user_id is null or auth.uid() = user_id);

drop policy if exists "users manage their accounts" on public.accounts;
create policy "users manage their accounts" on public.accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "users manage their transactions" on public.transactions;
create policy "users manage their transactions" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

insert into public.categories (name, kind, icon) values
  ('Salary', 'income', 'salary'),
  ('Business', 'income', 'business'),
  ('Freelance', 'income', 'freelance'),
  ('Interest', 'income', 'interest'),
  ('Refund', 'income', 'refund'),
  ('Gift received', 'income', 'gift-received'),
  ('Rental income', 'income', 'rental'),
  ('Other income', 'income', 'other-income'),
  ('Food', 'expense', 'food'),
  ('Groceries', 'expense', 'groceries'),
  ('Chai & coffee', 'expense', 'coffee'),
  ('Transport', 'expense', 'transport'),
  ('Fuel', 'expense', 'fuel'),
  ('Travel', 'expense', 'travel'),
  ('Rent', 'expense', 'rent'),
  ('Home', 'expense', 'home'),
  ('Bills', 'expense', 'bills'),
  ('Recharge', 'expense', 'recharge'),
  ('Subscriptions', 'expense', 'subscriptions'),
  ('Shopping', 'expense', 'shopping'),
  ('Personal care', 'expense', 'personal-care'),
  ('Health', 'expense', 'health'),
  ('Insurance', 'expense', 'insurance'),
  ('Education', 'expense', 'education'),
  ('Kids', 'expense', 'kids'),
  ('Pets', 'expense', 'pets'),
  ('Entertainment', 'expense', 'entertainment'),
  ('Gifts', 'expense', 'gifts'),
  ('EMI', 'expense', 'emi'),
  ('Investments', 'expense', 'investments'),
  ('Other', 'expense', 'other')
on conflict (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name), kind)
  do update set icon = excluded.icon;

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  month text not null check (month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  limit_amount integer not null check (limit_amount > 0),
  created_at timestamptz not null default now(),
  unique (user_id, category_id, month)
);

create index if not exists budgets_user_month_idx on public.budgets (user_id, month);

alter table public.budgets enable row level security;

grant select, insert, update, delete on public.budgets to authenticated, service_role;

drop policy if exists "users manage their budgets" on public.budgets;
create policy "users manage their budgets" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.scheduled_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.accounts (id) on delete cascade,
  category_id uuid not null references public.categories (id),
  amount integer not null check (amount > 0),
  kind text not null check (kind in ('income', 'expense')),
  note text,
  repeat text not null check (repeat in ('once', 'monthly')),
  day_of_month integer not null check (day_of_month between 1 and 31),
  next_on date not null,
  created_at timestamptz not null default now()
);

-- Optional time of day (HH:MM, the user's local time) for "today at 6pm" style plans.
alter table public.scheduled_transactions add column if not exists at_time text
  check (at_time is null or at_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');

create index if not exists scheduled_user_next_idx
  on public.scheduled_transactions (user_id, next_on);

alter table public.scheduled_transactions enable row level security;

grant select, insert, update, delete on public.scheduled_transactions to authenticated, service_role;

drop policy if exists "users manage their schedules" on public.scheduled_transactions;
create policy "users manage their schedules" on public.scheduled_transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Lending and borrowing with friends. These move account balances but are not income or spending.
create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  person text not null,
  type text not null check (type in ('lent', 'borrowed', 'got_back', 'paid_back')),
  amount integer not null check (amount > 0),
  account_id uuid references public.accounts (id) on delete set null,
  occurred_on date not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists debts_user_idx on public.debts (user_id, occurred_on desc);

alter table public.debts enable row level security;

grant select, insert, update, delete on public.debts to authenticated, service_role;

drop policy if exists "users manage their debts" on public.debts;
create policy "users manage their debts" on public.debts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Savings goals. Money put aside stays in the user's accounts; entries only earmark it.
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  icon text,
  target_amount integer not null check (target_amount > 0),
  target_date date,
  created_at timestamptz not null default now()
);

-- Positive amounts are added to the goal, negative amounts are taken out.
create table if not exists public.goal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  goal_id uuid not null references public.goals (id) on delete cascade,
  amount integer not null check (amount <> 0),
  occurred_on date not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists goals_user_idx on public.goals (user_id);
create index if not exists goal_entries_goal_idx on public.goal_entries (goal_id, occurred_on desc);

alter table public.goals enable row level security;
alter table public.goal_entries enable row level security;

grant select, insert, update, delete on public.goals to authenticated, service_role;
grant select, insert, update, delete on public.goal_entries to authenticated, service_role;

drop policy if exists "users manage their goals" on public.goals;
create policy "users manage their goals" on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "users manage their goal entries" on public.goal_entries;
create policy "users manage their goal entries" on public.goal_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Phones that receive push notifications (Firebase Cloud Messaging).
create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default 'android',
  utc_offset_minutes integer not null default 330,
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);

-- Pushes already sent, so a reminder or summary goes out once.
create table if not exists public.push_log (
  key text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  sent_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;
alter table public.push_log enable row level security;

grant select, insert, update, delete on public.device_tokens to service_role;
grant select, insert, update, delete on public.push_log to service_role;

notify pgrst, 'reload schema';
