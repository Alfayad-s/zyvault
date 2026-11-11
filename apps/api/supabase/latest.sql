-- Pending changes only. Run this in the Supabase SQL editor.
-- The rest of schema.sql is already on the database.

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
