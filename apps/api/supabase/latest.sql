-- Pending changes only. Run this in the Supabase SQL editor.
-- The rest of schema.sql is already on the database.

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

insert into public.categories (name, kind, icon) values
  ('Parents', 'expense', 'parents')
on conflict (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name), kind)
  do update set icon = excluded.icon;

-- Roles and the public feature switches. Paste this if the block above is already applied.

create table if not exists public.app_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member'))
);

create table if not exists public.app_features (
  key text primary key,
  enabled boolean not null default true
);

insert into public.app_features (key, enabled) values
  ('chat', true),
  ('intelligence', true),
  ('voice', true),
  ('bankSms', true),
  ('upiAlerts', true),
  ('creditCards', true),
  ('goals', true),
  ('people', true),
  ('budgets', true),
  ('plans', true)
on conflict (key) do nothing;

alter table public.app_roles enable row level security;
alter table public.app_features enable row level security;
drop policy if exists "users read their role" on public.app_roles;
create policy "users read their role" on public.app_roles
  for select using (auth.uid() = user_id);
drop policy if exists "signed-in users read features" on public.app_features;
create policy "signed-in users read features" on public.app_features
  for select using (auth.role() = 'authenticated');
grant select on public.app_roles to authenticated, service_role;
grant select, insert, update on public.app_roles to service_role;
grant select on public.app_features to authenticated, service_role;
grant select, insert, update on public.app_features to service_role;

notify pgrst, 'reload schema';

-- Shared card logos. Paste this after the blocks above are applied.

create table if not exists public.card_brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short text not null,
  logo_url text not null,
  mark_url text not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists card_brands_name_idx on public.card_brands (lower(name));
alter table public.card_brands enable row level security;
drop policy if exists "signed-in users read card brands" on public.card_brands;
create policy "signed-in users read card brands" on public.card_brands
  for select using (auth.role() = 'authenticated');
grant select on public.card_brands to authenticated, service_role;
grant insert, update on public.card_brands to service_role;

insert into public.app_roles (user_id, role)
values ('e97269af-82ca-4d97-8142-df670d736083', 'admin')
on conflict (user_id) do update set role = 'admin';

notify pgrst, 'reload schema';
