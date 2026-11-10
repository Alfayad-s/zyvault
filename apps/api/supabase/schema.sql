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
  type text not null check (type in ('cash', 'bank', 'credit')),
  opening_balance integer not null default 0,
  card_kind text,
  limit_amount integer,
  bill_day integer,
  due_day integer,
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
  card_effect text,
  card_id uuid references public.accounts (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.accounts add column if not exists bank_id text;
alter table public.accounts add column if not exists card_kind text;
alter table public.accounts add column if not exists limit_amount integer;
alter table public.accounts add column if not exists bill_day integer;
alter table public.accounts add column if not exists due_day integer;
do $$
declare name text;
begin
  for name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'accounts'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%cash%'
      and pg_get_constraintdef(con.oid) not ilike '%credit%'
  loop
    execute format('alter table public.accounts drop constraint %I', name);
  end loop;
end $$;
alter table public.accounts drop constraint if exists accounts_type_check;
alter table public.accounts
  add constraint accounts_type_check check (type in ('cash', 'bank', 'credit'));
alter table public.accounts drop constraint if exists accounts_card_kind_check;
alter table public.accounts
  add constraint accounts_card_kind_check check (card_kind is null or card_kind in ('fd', 'bank'));
alter table public.accounts drop constraint if exists accounts_card_days_check;
alter table public.accounts
  add constraint accounts_card_days_check check (
    (bill_day is null or bill_day between 1 and 28)
    and (due_day is null or due_day between 1 and 28)
  );
alter table public.accounts drop constraint if exists accounts_credit_fields_check;
alter table public.accounts
  add constraint accounts_credit_fields_check check (
    type <> 'credit'
    or (
      card_kind in ('fd', 'bank')
      and limit_amount > 0
      and (card_kind = 'fd' or (bill_day is not null and due_day is not null))
    )
  );

alter table public.transactions add column if not exists card_effect text;
alter table public.transactions add column if not exists card_id uuid references public.accounts (id) on delete set null;
alter table public.transactions drop constraint if exists transactions_card_effect_check;
alter table public.transactions
  add constraint transactions_card_effect_check check (card_effect is null or card_effect in ('spend', 'payment'));

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
  ('Parents', 'expense', 'parents'),
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

-- Financial intelligence. Additive tables. Amounts are paise.
create table if not exists public.financial_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  emergency_reserve integer not null default 0 check (emergency_reserve >= 0),
  monthly_discretionary_limit integer check (monthly_discretionary_limit is null or monthly_discretionary_limit >= 0),
  essential_categories jsonb not null default '["rent","bills","emi","insurance","recharge"]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.financial_forecasts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  horizon_days integer not null check (horizon_days in (7, 15, 30, 60, 90)),
  assumptions jsonb not null default '[]'::jsonb,
  generated_at timestamptz not null default now()
);
create index if not exists financial_forecasts_user_idx
  on public.financial_forecasts (user_id, horizon_days, generated_at desc);

create table if not exists public.forecast_daily_points (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  forecast_id uuid not null references public.financial_forecasts (id) on delete cascade,
  date date not null,
  projected_balance integer not null,
  confirmed_in integer not null default 0,
  confirmed_out integer not null default 0,
  estimated_in integer not null default 0,
  estimated_out integer not null default 0,
  unique (forecast_id, date)
);
create index if not exists forecast_daily_points_user_idx on public.forecast_daily_points (user_id, forecast_id);

create table if not exists public.financial_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists financial_insights_user_idx on public.financial_insights (user_id, created_at desc);

create table if not exists public.insight_evidence (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  insight_id uuid not null references public.financial_insights (id) on delete cascade,
  label text not null,
  amount integer
);

create table if not exists public.financial_scenarios (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  input jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists financial_scenarios_user_idx on public.financial_scenarios (user_id, created_at desc);

create table if not exists public.spending_anomalies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  fingerprint text not null,
  kind text not null,
  severity text not null check (severity in ('info', 'watch')),
  reason text not null,
  amount integer,
  occurred_on date,
  category_name text,
  transaction_id uuid,
  detected_at timestamptz not null default now(),
  unique (user_id, fingerprint)
);

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  updated_at timestamptz not null default now()
);
create index if not exists ai_conversations_user_idx on public.ai_conversations (user_id, updated_at desc);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  body text not null,
  language text not null default 'en',
  created_at timestamptz not null default now()
);
create index if not exists ai_messages_conversation_idx on public.ai_messages (conversation_id, created_at);

create table if not exists public.agent_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  status text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.agent_tool_calls (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  run_id uuid not null references public.agent_runs (id) on delete cascade,
  tool_name text not null,
  duration_ms integer,
  status text not null
);

create table if not exists public.financial_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  rating text not null check (rating in ('up', 'down')),
  insight_id uuid references public.financial_insights (id) on delete set null,
  message_id uuid references public.ai_messages (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.finance_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  queue text not null,
  status text not null check (status in ('queued', 'running', 'completed', 'failed')),
  idempotency_key text not null,
  error text,
  result_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index if not exists finance_jobs_user_idx on public.finance_jobs (user_id, created_at desc);

alter table public.financial_profiles enable row level security;
alter table public.financial_forecasts enable row level security;
alter table public.forecast_daily_points enable row level security;
alter table public.financial_insights enable row level security;
alter table public.insight_evidence enable row level security;
alter table public.financial_scenarios enable row level security;
alter table public.spending_anomalies enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.agent_runs enable row level security;
alter table public.agent_tool_calls enable row level security;
alter table public.financial_feedback enable row level security;
alter table public.finance_jobs enable row level security;

grant select, insert, update, delete on public.financial_profiles to authenticated, service_role;
grant select, insert, update, delete on public.financial_forecasts to authenticated, service_role;
grant select, insert, update, delete on public.forecast_daily_points to authenticated, service_role;
grant select, insert, update, delete on public.financial_insights to authenticated, service_role;
grant select, insert, update, delete on public.insight_evidence to authenticated, service_role;
grant select, insert, update, delete on public.financial_scenarios to authenticated, service_role;
grant select, insert, update, delete on public.spending_anomalies to authenticated, service_role;
grant select, insert, update, delete on public.ai_conversations to authenticated, service_role;
grant select, insert, update, delete on public.ai_messages to authenticated, service_role;
grant select, insert, update, delete on public.agent_runs to authenticated, service_role;
grant select, insert, update, delete on public.agent_tool_calls to authenticated, service_role;
grant select, insert, update, delete on public.financial_feedback to authenticated, service_role;
grant select, insert, update, delete on public.finance_jobs to authenticated, service_role;

drop policy if exists "users manage their financial profile" on public.financial_profiles;
create policy "users manage their financial profile" on public.financial_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their forecasts" on public.financial_forecasts;
create policy "users manage their forecasts" on public.financial_forecasts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their forecast points" on public.forecast_daily_points;
create policy "users manage their forecast points" on public.forecast_daily_points
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their insights" on public.financial_insights;
create policy "users manage their insights" on public.financial_insights
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their insight evidence" on public.insight_evidence;
create policy "users manage their insight evidence" on public.insight_evidence
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their scenarios" on public.financial_scenarios;
create policy "users manage their scenarios" on public.financial_scenarios
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their anomalies" on public.spending_anomalies;
create policy "users manage their anomalies" on public.spending_anomalies
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their advisor chats" on public.ai_conversations;
create policy "users manage their advisor chats" on public.ai_conversations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their advisor messages" on public.ai_messages;
create policy "users manage their advisor messages" on public.ai_messages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their agent runs" on public.agent_runs;
create policy "users manage their agent runs" on public.agent_runs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their tool calls" on public.agent_tool_calls;
create policy "users manage their tool calls" on public.agent_tool_calls
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their feedback" on public.financial_feedback;
create policy "users manage their feedback" on public.financial_feedback
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their finance jobs" on public.finance_jobs;
create policy "users manage their finance jobs" on public.finance_jobs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

notify pgrst, 'reload schema';
