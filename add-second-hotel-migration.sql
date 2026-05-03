-- ======================================================================
-- ADD SECOND HOTEL — Best Western Wembley
-- ----------------------------------------------------------------------
-- Run this ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run: every statement is idempotent.
--
-- After running this migration, ASM/Welfare/SM accounts created with
-- email prefix `bwwembley...` are automatically scoped to Best Western;
-- accounts with prefix `hiwembley...` are scoped to Holiday Inn Wembley.
-- A separate `warehouse` role can be granted manually (see step 11).
-- ======================================================================

-- 1. hotels
create table if not exists public.hotels (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  created_at timestamptz not null default now()
);

insert into public.hotels (code, name) values
  ('HIWEMBLEY', 'Holiday Inn Wembley'),
  ('BWWEMBLEY', 'Best Western Wembley')
on conflict (code) do nothing;

-- 2. user_profiles  (one row per Supabase auth user → hotel + role)
create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  hotel_id uuid references public.hotels(id),     -- null for warehouse role
  role text not null default 'staff' check (role in ('staff','warehouse')),
  created_at timestamptz not null default now(),
  -- staff must have a hotel; warehouse must not
  constraint role_hotel_consistency check (
    (role = 'staff' and hotel_id is not null) or
    (role = 'warehouse' and hotel_id is null)
  )
);

-- 3. helper functions
create or replace function public.current_user_hotel()
returns uuid language sql stable security definer as $$
  select hotel_id from public.user_profiles where user_id = auth.uid();
$$;

create or replace function public.is_warehouse()
returns boolean language sql stable security definer as $$
  select coalesce(
    (select role = 'warehouse' from public.user_profiles where user_id = auth.uid()),
    false
  );
$$;

-- 4. add hotel_id column to the four data tables
--    - items
alter table public.items add column if not exists hotel_id uuid references public.hotels(id);
update public.items
  set hotel_id = (select id from public.hotels where code='HIWEMBLEY')
  where hotel_id is null;
alter table public.items alter column hotel_id set not null;
create index if not exists items_hotel_idx on public.items(hotel_id);

--    - transactions
alter table public.transactions add column if not exists hotel_id uuid references public.hotels(id);
update public.transactions
  set hotel_id = (select id from public.hotels where code='HIWEMBLEY')
  where hotel_id is null;
alter table public.transactions alter column hotel_id set not null;
create index if not exists transactions_hotel_idx on public.transactions(hotel_id);

--    - stock_counts
alter table public.stock_counts add column if not exists hotel_id uuid references public.hotels(id);
update public.stock_counts
  set hotel_id = (select id from public.hotels where code='HIWEMBLEY')
  where hotel_id is null;
alter table public.stock_counts alter column hotel_id set not null;
create index if not exists stock_counts_hotel_idx on public.stock_counts(hotel_id);

--    - deliveries
alter table public.deliveries add column if not exists hotel_id uuid references public.hotels(id);
update public.deliveries
  set hotel_id = (select id from public.hotels where code='HIWEMBLEY')
  where hotel_id is null;
alter table public.deliveries alter column hotel_id set not null;
create index if not exists deliveries_hotel_idx on public.deliveries(hotel_id);

-- 5. seed BW Wembley with HI Wembley's item list at quantity 0
--    (skips items that already exist by name in BW Wembley, so re-running is safe)
insert into public.items (name, category, quantity, unit, min_stock, max_stock, product_code, hotel_id)
select i.name, i.category, 0, i.unit, i.min_stock, i.max_stock, i.product_code,
       (select id from public.hotels where code='BWWEMBLEY')
from public.items i
where i.hotel_id = (select id from public.hotels where code='HIWEMBLEY')
  and not exists (
    select 1 from public.items i2
    where i2.hotel_id = (select id from public.hotels where code='BWWEMBLEY')
      and i2.name = i.name
  );

-- 6. backfill user_profiles: every existing auth user → HIWEMBLEY (staff)
insert into public.user_profiles (user_id, hotel_id, role)
select u.id, (select id from public.hotels where code='HIWEMBLEY'), 'staff'
from auth.users u
where not exists (select 1 from public.user_profiles p where p.user_id = u.id)
on conflict (user_id) do nothing;

-- 7. trigger: auto-map new auth users by email prefix
create or replace function public.assign_hotel_to_new_user()
returns trigger language plpgsql security definer as $$
declare
  hcode text;
  hid uuid;
begin
  if    lower(coalesce(new.email,'')) like 'bwwembley%' then hcode := 'BWWEMBLEY';
  elsif lower(coalesce(new.email,'')) like 'hiwembley%' then hcode := 'HIWEMBLEY';
  else  hcode := 'HIWEMBLEY';   -- fallback for unknown prefixes
  end if;
  select id into hid from public.hotels where code = hcode;
  insert into public.user_profiles (user_id, hotel_id, role) values (new.id, hid, 'staff')
    on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists assign_hotel_on_signup on auth.users;
create trigger assign_hotel_on_signup
  after insert on auth.users
  for each row execute function public.assign_hotel_to_new_user();

-- 8. RLS — replace the existing wide-open auth_all_* policies with hotel-scoped ones.
--    Warehouse role bypasses the hotel filter (sees all hotels).
drop policy if exists "auth_all_items" on public.items;
create policy "hotel_scoped_items" on public.items
  for all to authenticated
  using      (public.is_warehouse() or hotel_id = public.current_user_hotel())
  with check (public.is_warehouse() or hotel_id = public.current_user_hotel());

drop policy if exists "auth_all_transactions" on public.transactions;
create policy "hotel_scoped_transactions" on public.transactions
  for all to authenticated
  using      (public.is_warehouse() or hotel_id = public.current_user_hotel())
  with check (public.is_warehouse() or hotel_id = public.current_user_hotel());

drop policy if exists "auth_all_stock_counts" on public.stock_counts;
create policy "hotel_scoped_stock_counts" on public.stock_counts
  for all to authenticated
  using      (public.is_warehouse() or hotel_id = public.current_user_hotel())
  with check (public.is_warehouse() or hotel_id = public.current_user_hotel());

drop policy if exists "auth_all_deliveries" on public.deliveries;
create policy "hotel_scoped_deliveries" on public.deliveries
  for all to authenticated
  using      (public.is_warehouse() or hotel_id = public.current_user_hotel())
  with check (public.is_warehouse() or hotel_id = public.current_user_hotel());

-- 9. user_profiles RLS — every user can read their own profile (and only their own)
alter table public.user_profiles enable row level security;
drop policy if exists "self_read_user_profiles" on public.user_profiles;
create policy "self_read_user_profiles" on public.user_profiles
  for select to authenticated using (user_id = auth.uid());

-- 10. hotels RLS — any signed-in user can read the list (used to render the header / switcher)
alter table public.hotels enable row level security;
drop policy if exists "auth_read_hotels" on public.hotels;
create policy "auth_read_hotels" on public.hotels
  for select to authenticated using (true);

-- 11. realtime — make sure the new tables are part of the realtime publication
do $$
begin
  execute 'alter publication supabase_realtime add table public.hotels';
exception when duplicate_object then null;
end $$;

do $$
begin
  execute 'alter publication supabase_realtime add table public.user_profiles';
exception when duplicate_object then null;
end $$;

-- ======================================================================
-- DONE. Manual steps in the Supabase Dashboard:
-- ----------------------------------------------------------------------
-- A. Authentication → Users → Add user (Auto Confirm) for Best Western:
--      bwwembleyasm@sosproperty.co.uk
--      bwwembleywelfare@sosproperty.co.uk
--      (any other staff who need access)
--    The trigger above will auto-map them to BWWEMBLEY.
--
-- B. Authentication → Users → Add user for the warehouse manager (James):
--      e.g. warehouse@sosproperty.co.uk   (or james.warehouse@…)
--    Then run:
--
--      update public.user_profiles
--      set role = 'warehouse', hotel_id = null
--      where user_id = (select id from auth.users
--                       where email = 'warehouse@sosproperty.co.uk');
--
-- C. Verify:
--      select u.email, p.role, h.code, h.name
--      from auth.users u
--      join public.user_profiles p on p.user_id = u.id
--      left join public.hotels h on h.id = p.hotel_id
--      order by p.role, h.code, u.email;
-- ======================================================================
