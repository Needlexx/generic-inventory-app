-- ======================================================================
-- HI Wembley Inventory — Supabase one-time setup
-- ----------------------------------------------------------------------
-- Run this ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run: all statements are idempotent.
-- ======================================================================

-- Extensions (pg_cron is in 'extensions' schema on Supabase)
create extension if not exists pg_cron with schema extensions;

-- ============ TABLES ==================================================

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  quantity integer not null default 0,
  unit text not null default 'pcs',
  min_stock integer not null default 5,
  max_stock integer not null default 20,
  product_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists items_category_idx on public.items(category);
create index if not exists items_product_code_idx on public.items(product_code);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_name text not null,
  user_room text,
  staff_name text,
  items jsonb not null,
  notes text,
  photo_path text,
  created_at timestamptz not null default now()
);
create index if not exists transactions_created_at_idx on public.transactions(created_at desc);

create table if not exists public.settings (
  id int primary key default 1,
  data jsonb not null default '{}'::jsonb,
  constraint settings_singleton check (id = 1)
);
insert into public.settings (id, data) values (1, '{}') on conflict (id) do nothing;

-- Auto-update timestamp on items
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists items_touch_updated_at on public.items;
create trigger items_touch_updated_at
  before update on public.items
  for each row execute function public.touch_updated_at();

-- ============ ROW-LEVEL SECURITY ======================================
-- Any authenticated user can do everything; anon users cannot read/write.

alter table public.items enable row level security;
alter table public.transactions enable row level security;
alter table public.settings enable row level security;

drop policy if exists "auth_all_items" on public.items;
create policy "auth_all_items" on public.items
  for all to authenticated using (true) with check (true);

drop policy if exists "auth_all_transactions" on public.transactions;
create policy "auth_all_transactions" on public.transactions
  for all to authenticated using (true) with check (true);

drop policy if exists "auth_all_settings" on public.settings;
create policy "auth_all_settings" on public.settings
  for all to authenticated using (true) with check (true);

-- ============ STORAGE BUCKET POLICIES =================================
-- Requires the 'inventory-photos' bucket to exist (create it in the UI).
-- These policies let authenticated users read/write/delete photos in that bucket.

drop policy if exists "auth_select_inventory_photos" on storage.objects;
create policy "auth_select_inventory_photos" on storage.objects
  for select to authenticated using (bucket_id = 'inventory-photos');

drop policy if exists "auth_insert_inventory_photos" on storage.objects;
create policy "auth_insert_inventory_photos" on storage.objects
  for insert to authenticated with check (bucket_id = 'inventory-photos');

drop policy if exists "auth_update_inventory_photos" on storage.objects;
create policy "auth_update_inventory_photos" on storage.objects
  for update to authenticated using (bucket_id = 'inventory-photos');

drop policy if exists "auth_delete_inventory_photos" on storage.objects;
create policy "auth_delete_inventory_photos" on storage.objects
  for delete to authenticated using (bucket_id = 'inventory-photos');

-- ============ DAILY 28-DAY PURGE (pg_cron) ============================
-- Runs every day at 03:00 UTC. Deletes transactions older than 28 days.
-- Storage photos are cleaned up by the client on startup (orphan sweep).

-- Remove any previous schedule with the same name, then schedule fresh:
do $$
begin
  perform cron.unschedule('purge-old-transactions');
exception when others then null;
end $$;

select cron.schedule(
  'purge-old-transactions',
  '0 3 * * *',
  $$ delete from public.transactions where created_at < now() - interval '28 days'; $$
);

-- ======================================================================
-- DONE. Next manual steps (do these in the Supabase Dashboard):
-- ----------------------------------------------------------------------
-- 1. Storage → New bucket → name: inventory-photos → Private → Save
-- 2. Authentication → Users → Add user (email + password) ×20
--    (Tick "Auto Confirm User" so they can sign in immediately)
-- 3. Authentication → Providers → Email → turn OFF "Enable signups"
--    (blocks self-registration — admin-created accounts only)
-- ======================================================================
