-- ======================================================================
-- WAREHOUSE STOCK — central inventory managed by the warehouse role.
-- ----------------------------------------------------------------------
-- Run this ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run: every statement is idempotent.
--
-- Prerequisite: add-second-hotel-migration.sql must already have been
-- applied (this migration depends on the public.is_warehouse() helper
-- and the user_profiles table it creates).
--
-- This table is NOT scoped by hotel_id. It's a single shared pool of
-- stock that the warehouse manager (James) holds before shipping out
-- to the hotels. Only users with role='warehouse' can read or write it.
-- ======================================================================

create table if not exists public.warehouse_items (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text not null,
  quantity integer not null default 0,
  unit text not null default 'pcs',
  min_stock integer not null default 5,
  product_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists warehouse_items_category_idx on public.warehouse_items(category);

-- Auto-update updated_at on every change
create or replace function public.warehouse_items_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists warehouse_items_touch on public.warehouse_items;
create trigger warehouse_items_touch
  before update on public.warehouse_items
  for each row execute function public.warehouse_items_touch_updated_at();

-- RLS — only the warehouse role can see or change this table
alter table public.warehouse_items enable row level security;
drop policy if exists "warehouse_only_warehouse_items" on public.warehouse_items;
create policy "warehouse_only_warehouse_items" on public.warehouse_items
  for all to authenticated
  using      (public.is_warehouse())
  with check (public.is_warehouse());

-- Realtime — broadcast inserts/updates/deletes so a second device
-- (e.g. James's tablet) sees changes instantly.
alter table public.warehouse_items replica identity full;
do $$
begin
  execute 'alter publication supabase_realtime add table public.warehouse_items';
exception when duplicate_object then null;
end $$;

-- ======================================================================
-- DONE. After running this:
--  - James can sign in and see the new "Warehouse view" toggle on the
--    Stock tab.
--  - He starts with an empty warehouse list and adds items as they
--    arrive from suppliers (Add Item button).
-- ======================================================================
