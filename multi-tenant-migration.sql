-- ======================================================================
-- MULTI-TENANT MIGRATION — Phase 1 of 5
-- ----------------------------------------------------------------------
-- Run this ONCE in Supabase SQL Editor AFTER the original supabase-setup.sql
-- Safe to re-run: every statement is idempotent.
--
-- What this does:
--   1. Creates a hotels table (HI Wembley = first hotel)
--   2. Creates user_profiles table (role + hotel_id per user)
--   3. Adds hotel_id column to items / transactions / stock_counts / deliveries
--   4. Backfills all existing data into HI Wembley
--   5. Creates central warehouse_items + warehouse_shipments tables
--   6. Replaces RLS policies with hotel-scoped + head-sees-all rules
--   7. Adds an auth trigger that auto-assigns role/hotel from email pattern
--      e.g. 'wembley.welfare@sosproperty.co.uk' → role=welfare, hotel=WEMBLEY
-- ======================================================================

-- ============ 1. HOTELS ===============================================

create table if not exists public.hotels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,           -- short code used in email pattern (e.g. WEMBLEY)
  name text not null,                  -- full display name
  address text,
  created_at timestamptz not null default now()
);

-- Insert HI Wembley as the first hotel (idempotent)
insert into public.hotels (code, name)
values ('WEMBLEY', 'HI Wembley')
on conflict (code) do nothing;

-- ============ 2. USER PROFILES =======================================

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('head','asm','sm','welfare')),
  hotel_id uuid references public.hotels(id),
  full_name text,
  created_at timestamptz not null default now()
);

-- head has hotel_id = null; everyone else must belong to a hotel
alter table public.user_profiles
  drop constraint if exists user_profiles_role_hotel_check;
alter table public.user_profiles
  add constraint user_profiles_role_hotel_check
  check ((role = 'head' and hotel_id is null) or (role <> 'head' and hotel_id is not null));

create index if not exists user_profiles_hotel_idx on public.user_profiles(hotel_id);

-- ============ 3. HELPER FUNCTIONS (used by RLS) =======================

-- These are SECURITY DEFINER so RLS policies can use them safely.
create or replace function public.current_user_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.user_profiles where user_id = auth.uid();
$$;

create or replace function public.current_user_hotel()
returns uuid language sql stable security definer set search_path = public as $$
  select hotel_id from public.user_profiles where user_id = auth.uid();
$$;

create or replace function public.is_head()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'head' from public.user_profiles where user_id = auth.uid()), false);
$$;

-- ============ 4. ADD hotel_id TO EXISTING TABLES ======================

-- items
alter table public.items add column if not exists hotel_id uuid references public.hotels(id);
update public.items set hotel_id = (select id from public.hotels where code = 'WEMBLEY')
  where hotel_id is null;
alter table public.items alter column hotel_id set not null;
create index if not exists items_hotel_idx on public.items(hotel_id);

-- transactions
alter table public.transactions add column if not exists hotel_id uuid references public.hotels(id);
update public.transactions set hotel_id = (select id from public.hotels where code = 'WEMBLEY')
  where hotel_id is null;
alter table public.transactions alter column hotel_id set not null;
create index if not exists transactions_hotel_idx on public.transactions(hotel_id);

-- stock_counts
alter table public.stock_counts add column if not exists hotel_id uuid references public.hotels(id);
update public.stock_counts set hotel_id = (select id from public.hotels where code = 'WEMBLEY')
  where hotel_id is null;
alter table public.stock_counts alter column hotel_id set not null;
create index if not exists stock_counts_hotel_idx on public.stock_counts(hotel_id);

-- deliveries  (also gets a shipment_id link for warehouse-originated deliveries)
alter table public.deliveries add column if not exists hotel_id uuid references public.hotels(id);
update public.deliveries set hotel_id = (select id from public.hotels where code = 'WEMBLEY')
  where hotel_id is null;
alter table public.deliveries alter column hotel_id set not null;
create index if not exists deliveries_hotel_idx on public.deliveries(hotel_id);

alter table public.deliveries add column if not exists shipment_id uuid;  -- FK added below after warehouse_shipments exists
alter table public.deliveries add column if not exists discrepancy jsonb; -- per-line {expected, received, diff} when discrepancy detected

-- ============ 5. WAREHOUSE TABLES =====================================

-- Central warehouse stock — only Head can read/write.
create table if not exists public.warehouse_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  quantity integer not null default 0,
  unit text not null default 'pcs',
  product_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists warehouse_items_touch on public.warehouse_items;
create trigger warehouse_items_touch before update on public.warehouse_items
  for each row execute function public.touch_updated_at();

-- Shipments from warehouse to a hotel — created by Head.
-- On INSERT, a trigger automatically creates a 'pending' delivery at the receiving hotel.
create table if not exists public.warehouse_shipments (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id),
  shipped_by text not null,
  shipped_at timestamptz not null default now(),
  items jsonb not null,                   -- [{ id, name, category, unit, qty, product_code }]
  notes text,
  status text not null default 'shipped'  -- shipped | received | discrepancy | cancelled
    check (status in ('shipped','received','discrepancy','cancelled'))
);

create index if not exists warehouse_shipments_hotel_idx on public.warehouse_shipments(hotel_id, shipped_at desc);

-- Now wire up the deliveries.shipment_id foreign key
do $$
begin
  alter table public.deliveries
    add constraint deliveries_shipment_id_fkey
    foreign key (shipment_id) references public.warehouse_shipments(id) on delete set null;
exception when duplicate_object then null;
end $$;

-- ============ 6. AUTO-CREATE PENDING DELIVERY FROM SHIPMENT ===========

-- When Head ships products to a hotel, a 'pending' delivery row is created at
-- that hotel automatically. Welfare then records what actually arrived; if it
-- differs, the discrepancy is flagged for ASM/SM.
create or replace function public.create_delivery_from_shipment()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  total_units int;
  total_items int;
begin
  total_items := coalesce(jsonb_array_length(new.items), 0);
  select coalesce(sum((line->>'qty')::int), 0)
    into total_units
    from jsonb_array_elements(new.items) as line;

  insert into public.deliveries (
    hotel_id, submitted_by, items, notes, summary, status, shipment_id
  ) values (
    new.hotel_id,
    new.shipped_by,
    new.items,
    coalesce(new.notes, '') || ' (from warehouse shipment)',
    jsonb_build_object('totalItems', total_items, 'totalUnits', total_units, 'fromWarehouse', true),
    'pending',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists shipment_creates_delivery on public.warehouse_shipments;
create trigger shipment_creates_delivery
  after insert on public.warehouse_shipments
  for each row execute function public.create_delivery_from_shipment();

-- ============ 7. AUTH TRIGGER — auto-assign role + hotel from email ===

-- Email pattern: <hotelcode>.<role>@anything   →   e.g. wembley.welfare@sosproperty.co.uk
-- Special case:  head@anything                 →   role=head, hotel_id=null
-- Anything else: profile NOT created (admin must assign manually).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  local_part text;
  parts text[];
  parsed_role text;
  parsed_hotel_code text;
  matched_hotel uuid;
begin
  local_part := lower(split_part(new.email, '@', 1));

  -- Pattern 1: head user
  if local_part = 'head' or local_part like 'head.%' then
    insert into public.user_profiles (user_id, role, hotel_id)
    values (new.id, 'head', null)
    on conflict (user_id) do nothing;
    return new;
  end if;

  -- Pattern 2: hotelcode.role
  parts := string_to_array(local_part, '.');
  if array_length(parts, 1) >= 2 then
    parsed_hotel_code := upper(parts[1]);
    parsed_role := parts[2];
    if parsed_role in ('asm','sm','welfare') then
      select id into matched_hotel from public.hotels where code = parsed_hotel_code;
      if matched_hotel is not null then
        insert into public.user_profiles (user_id, role, hotel_id)
        values (new.id, parsed_role, matched_hotel)
        on conflict (user_id) do nothing;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============ 8. BACKFILL EXISTING USER PROFILES ======================

-- Any auth.users that already exist need a profile. We default them all to
-- 'asm' at HI Wembley — Head can re-assign anyone afterwards.
insert into public.user_profiles (user_id, role, hotel_id)
select u.id, 'asm', (select id from public.hotels where code = 'WEMBLEY')
from auth.users u
where not exists (select 1 from public.user_profiles p where p.user_id = u.id)
on conflict (user_id) do nothing;

-- ============ 9. RLS POLICIES =========================================

alter table public.hotels enable row level security;
alter table public.user_profiles enable row level security;
alter table public.warehouse_items enable row level security;
alter table public.warehouse_shipments enable row level security;

-- HOTELS — everyone authenticated can read; only head can write
drop policy if exists "auth_select_hotels" on public.hotels;
create policy "auth_select_hotels" on public.hotels
  for select to authenticated using (true);

drop policy if exists "head_write_hotels" on public.hotels;
create policy "head_write_hotels" on public.hotels
  for all to authenticated using (is_head()) with check (is_head());

-- USER_PROFILES — user can read their own profile; head can read/write all
drop policy if exists "self_read_profile" on public.user_profiles;
create policy "self_read_profile" on public.user_profiles
  for select to authenticated using (user_id = auth.uid() or is_head());

drop policy if exists "head_write_profiles" on public.user_profiles;
create policy "head_write_profiles" on public.user_profiles
  for all to authenticated using (is_head()) with check (is_head());

-- WAREHOUSE_ITEMS — head only
drop policy if exists "head_warehouse_items" on public.warehouse_items;
create policy "head_warehouse_items" on public.warehouse_items
  for all to authenticated using (is_head()) with check (is_head());

-- WAREHOUSE_SHIPMENTS — head writes; receiving hotel can read its own shipments
drop policy if exists "head_write_shipments" on public.warehouse_shipments;
create policy "head_write_shipments" on public.warehouse_shipments
  for all to authenticated using (is_head()) with check (is_head());

drop policy if exists "hotel_read_own_shipments" on public.warehouse_shipments;
create policy "hotel_read_own_shipments" on public.warehouse_shipments
  for select to authenticated
  using (is_head() or hotel_id = current_user_hotel());

-- ITEMS / TRANSACTIONS / STOCK_COUNTS / DELIVERIES — hotel-scoped + head-sees-all
-- Replaces the old "auth_all_*" wide-open policies.

drop policy if exists "auth_all_items" on public.items;
drop policy if exists "hotel_scoped_items" on public.items;
create policy "hotel_scoped_items" on public.items
  for all to authenticated
  using (is_head() or hotel_id = current_user_hotel())
  with check (is_head() or hotel_id = current_user_hotel());

drop policy if exists "auth_all_transactions" on public.transactions;
drop policy if exists "hotel_scoped_transactions" on public.transactions;
create policy "hotel_scoped_transactions" on public.transactions
  for all to authenticated
  using (is_head() or hotel_id = current_user_hotel())
  with check (is_head() or hotel_id = current_user_hotel());

drop policy if exists "auth_all_stock_counts" on public.stock_counts;
drop policy if exists "hotel_scoped_stock_counts" on public.stock_counts;
create policy "hotel_scoped_stock_counts" on public.stock_counts
  for all to authenticated
  using (is_head() or hotel_id = current_user_hotel())
  with check (is_head() or hotel_id = current_user_hotel());

drop policy if exists "auth_all_deliveries" on public.deliveries;
drop policy if exists "hotel_scoped_deliveries" on public.deliveries;
create policy "hotel_scoped_deliveries" on public.deliveries
  for all to authenticated
  using (is_head() or hotel_id = current_user_hotel())
  with check (is_head() or hotel_id = current_user_hotel());

-- ============ 10. REALTIME PUBLICATION FOR NEW TABLES =================

do $$ begin execute 'alter publication supabase_realtime add table public.warehouse_items'; exception when duplicate_object then null; end $$;
do $$ begin execute 'alter publication supabase_realtime add table public.warehouse_shipments'; exception when duplicate_object then null; end $$;
do $$ begin execute 'alter publication supabase_realtime add table public.user_profiles'; exception when duplicate_object then null; end $$;
do $$ begin execute 'alter publication supabase_realtime add table public.hotels'; exception when duplicate_object then null; end $$;

alter table public.warehouse_items replica identity full;
alter table public.warehouse_shipments replica identity full;
alter table public.user_profiles replica identity full;
alter table public.hotels replica identity full;

-- ======================================================================
-- VERIFY MIGRATION — run these and confirm before continuing to Phase 2:
-- ----------------------------------------------------------------------
--   select * from public.hotels;                          -- 1 row: HI Wembley
--   select count(*) from public.items where hotel_id is null;       -- 0
--   select count(*) from public.transactions where hotel_id is null; -- 0
--   select count(*) from public.user_profiles;            -- = number of existing users
--   select role, count(*) from public.user_profiles group by role;
-- ======================================================================
