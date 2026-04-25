-- ======================================================================
-- ADD HOTELS — replace the placeholder names with your real hotels.
-- ----------------------------------------------------------------------
-- The "code" field is what users will type in their email address. It
-- must be ALPHANUMERIC, no spaces, UPPERCASE.
--   Example: code = 'HARROW' →  email = harrow.welfare@sosproperty.co.uk
--
-- Run this AFTER multi-tenant-migration.sql has been applied.
-- Safe to re-run: existing codes are skipped.
-- ======================================================================

insert into public.hotels (code, name) values
  -- ('CODE',      'Display Name'),
  ('HOTEL02',    'Hotel 2'),
  ('HOTEL03',    'Hotel 3'),
  ('HOTEL04',    'Hotel 4'),
  ('HOTEL05',    'Hotel 5'),
  ('HOTEL06',    'Hotel 6'),
  ('HOTEL07',    'Hotel 7'),
  ('HOTEL08',    'Hotel 8'),
  ('HOTEL09',    'Hotel 9'),
  ('HOTEL10',    'Hotel 10'),
  ('HOTEL11',    'Hotel 11'),
  ('HOTEL12',    'Hotel 12'),
  ('HOTEL13',    'Hotel 13'),
  ('HOTEL14',    'Hotel 14'),
  ('HOTEL15',    'Hotel 15'),
  ('HOTEL16',    'Hotel 16'),
  ('HOTEL17',    'Hotel 17'),
  ('HOTEL18',    'Hotel 18'),
  ('HOTEL19',    'Hotel 19'),
  ('HOTEL20',    'Hotel 20'),
  ('HOTEL21',    'Hotel 21'),
  ('HOTEL22',    'Hotel 22'),
  ('HOTEL23',    'Hotel 23'),
  ('HOTEL24',    'Hotel 24'),
  ('HOTEL25',    'Hotel 25'),
  ('HOTEL26',    'Hotel 26'),
  ('HOTEL27',    'Hotel 27'),
  ('HOTEL28',    'Hotel 28'),
  ('HOTEL29',    'Hotel 29'),
  ('HOTEL30',    'Hotel 30'),
  ('HOTEL31',    'Hotel 31'),
  ('HOTEL32',    'Hotel 32'),
  ('HOTEL33',    'Hotel 33'),
  ('HOTEL34',    'Hotel 34'),
  ('HOTEL35',    'Hotel 35')
on conflict (code) do nothing;

-- To rename a hotel later:
--   update public.hotels set name = 'Real Name' where code = 'HOTEL02';
--
-- To change a code (rare — invalidates that hotel's email pattern):
--   update public.hotels set code = 'HARROW' where code = 'HOTEL02';
