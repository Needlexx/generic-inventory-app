-- ============================================================
-- Add cost column to items table (warehouse only)
-- Run once in Supabase SQL Editor. Safe to re-run.
-- ============================================================
-- Stores the unit cost (£) for each warehouse product.
-- Site-hotel items can have cost = NULL — the frontend
-- only displays cost when signed in as the warehouse role.
-- ============================================================

alter table public.items
  add column if not exists cost numeric(10, 2) default null;

-- No RLS changes needed: cost is just not shown in the site UI.
