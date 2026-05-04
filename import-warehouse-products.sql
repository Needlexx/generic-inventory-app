-- ======================================================================
-- IMPORT WAREHOUSE PRODUCT LIST
-- ----------------------------------------------------------------------
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run: all inserts use ON CONFLICT DO NOTHING.
--
-- What this does:
--   1. Adds a WAREHOUSE entry to the hotels table.
--   2. Inserts all warehouse products (from ProductList CSV, 04/05/2026)
--      with their current On Hand quantities.
--   3. Skips rows marked "No longer available" / "DO NOT USE".
-- ======================================================================

-- 1. Add the WAREHOUSE hotel (if not already present)
insert into public.hotels (code, name)
values ('WAREHOUSE', 'SOS Warehouse')
on conflict (code) do nothing;

-- 2. Insert products
--    Columns used: product_code, name, category, quantity, unit
--    min_stock / max_stock left as NULL (warehouse manages its own thresholds)
insert into public.items
  (product_code, name, category, quantity, unit, hotel_id)
select
  v.product_code,
  v.name,
  v.category,
  v.quantity,
  v.unit,
  (select id from public.hotels where code = 'WAREHOUSE')
from (values
  ('1002',  'HiPP Organic Vegetables and Mozzarella Potato Bake Baby Food Jar 7+ Months 190g', 'Baby Provisions', 461,  'Jar'),
  ('1003',  'Hipp Organic Tasty Vegetable Risotto Baby Food Jar 6+ Months 125g',              'Baby Provisions', 994,  'Jar'),
  ('1004',  'Hipp Organic Spaghetti With Tomatoes Mozzarella Baby Food Jar 7+ Months 190g',  'Baby Provisions', 891,  'Jar'),
  ('1005',  'HiPP Organic Macaroni Cheese with Carrots and Peas Baby Food Jar 7+ Months 190g','Baby Provisions',807,  'Jar'),
  ('1006',  'Hipp Organic Creamed Porridge Breakfast Baby Food Jar 6+ Months 160g',          'Baby Provisions', 177,  'Jar'),
  ('1007',  'Hipp Organic Cheesy Potato Spinach Bake Baby Food Jar 6+ Months 125g',          'Baby Provisions', 999,  'Jar'),
  ('1008',  'Hipp Organic Carrots Peas Cauliflower Baby Food Jar 4+ Months 125g',            'Baby Provisions', 950,  'Jar'),
  ('1009',  'HiPP Organic Carrots and Peas Baby Food Jar 4+ Months 125g',                   'Baby Provisions', 460,  'Jar'),
  ('1010',  'HiPP Organic Banana Rice Cereal Baby Food Jar 6+ Months 125g',                 'Baby Provisions', 475,  'Jar'),
  ('1011',  'Hipp Organic Apple And Pear Baby Food Jar 4+ Months 125g',                     'Baby Provisions', 646,  'Jar'),
  ('1012',  'Ella''s Kitchen Organic Fruit Smoothie Pouches 90g',                           'Baby Provisions', 988,  'Pouch'),
  ('1013',  'Cow & Gate Porridge Baby Cereal 4-6+ Months 125g',                             'Baby Provisions', 351,  'Jar'),
  ('1014',  'Baby Likes Tomato Pasta Chicken 130g **HALAL**',                               'Baby Provisions', 131,  'Pouch'),
  ('1015',  'Baby Likes Rice & Chicken 130g **HALAL**',                                     'Baby Provisions', 301,  'Pouch'),
  ('1016',  'Baby Likes Butternut Squash, Rice & Lamb 130g **HALAL**',                      'Baby Provisions', 1016, 'Pouch'),
  ('1017',  'Baby Likes Carrot & Lamb Stew 130g **HALAL**',                                 'Baby Provisions', 65,   'Pouch'),
  ('1018',  'For Aisha Green Bean & Lamb Curry Tray Meals 10+ months 190g *HALAL*',         'Baby Provisions', 882,  'Tray'),
  ('1019',  'For Aisha Chicken & Sweet Potato Curry Tray Meals 10+ months 190g *HALAL*',    'Baby Provisions', 536,  'Pouch'),
  ('1020',  'For Aisha Salmon & Sweet Potato Mash Pouches 7+ months 130g *HALAL*',          'Baby Provisions', 0,    'Pouch'),
  ('1021',  'For Aisha Roast Lamb Dinner + Vegetables Pouches 7+ months 130g *HALAL*',      'Baby Provisions', 0,    'Pouch'),
  ('1022',  'For Aisha Moroccan Chicken Tagine Pouches 7+ months 130g *HALAL*',             'Baby Provisions', 117,  'Pouch'),
  ('1023',  'For Aisha Jamaican Jerk Chicken Pouches 7+ months 130g *HALAL*',               'Baby Provisions', 0,    'Pouch'),
  ('1024',  'For Aisha Chicken & Sweet Potato Curry Pouches 7+ months 130g *HALAL*',        'Baby Provisions', 81,   'Pouch'),
  ('1027',  'Hipp Organic Banana Yogurt Breakfast Baby Food Jar 6+ Months 125g',            'Baby Provisions', 293,  'Jar'),
  ('A1001', 'Toothbrush Adult (Individual Units)',                                           'Sanitation and Hygiene', 2850, 'Unit'),
  ('A1002', 'Toothpaste',                                                                   'Sanitation and Hygiene', 2738, 'Tube'),
  ('A1003', 'Kids Toothbrush age 3-5',                                                      'Sanitation and Hygiene', 781,  'Unit'),
  ('A1004', 'Kids Toothpaste 4+',                                                           'Baby Provisions',         1027, 'Unit'),
  ('A1005', 'Childrens Toothbrush age 0-2',                                                 'Sanitation and Hygiene', 655,  'Unit'),
  ('A1006', 'Childrens Toothpaste age 0-3',                                                 'Sanitation and Hygiene', 1886, 'Tube'),
  ('A1007', 'Disposable Razor (pack of 5s)',                                                'Sanitation and Hygiene', 2236, 'Pack'),
  ('A1008', 'Roll on deodorant',                                                            'Sanitation and Hygiene', 3133, 'Tube'),
  ('A1009', 'Shower Gel',                                                                   'Sanitation and Hygiene', 881,  'Bottle'),
  ('A1010', 'Shampoo',                                                                      'Sanitation and Hygiene', 879,  'Bottle'),
  ('A1011', 'Laser II Disposable Twin Blade Razors - IOA Only (counted in boxes)',          'Sanitation and Hygiene', 1353, 'Pack'),
  ('A1012', 'Face Mask (per box)',                                                          'Medical',                2790, 'Box'),
  ('A1013', 'Thermometer',                                                                  'Medical',                56,   'Unit'),
  ('A1014', 'Pregnancy Test (3 Pack)',                                                      'Medical',                120,  'Pack'),
  ('A1015', 'Covid Test (individual tests, not boxes)',                                     'Medical',                185,  'Box'),
  ('A1016', 'Disposable Toothbrush and Paste - IOA Only (250 box)',                        'Sanitation and Hygiene', 30,   'Box'),
  ('A1017', 'Sanitiser Hand Gel',                                                           'Medical',                91,   'Bottle'),
  ('A1018', 'Latex Free Gloves SMALL (counted per box)',                                   'Medical',                42,   'Box'),
  ('A1019', 'Latex Free Gloves MEDIUM (counted per box)',                                  'Medical',                40,   'Box'),
  ('A1020', 'Latex Free Gloves LARGE (counted per box)',                                   'Medical',                47,   'Box'),
  ('A1021', 'Latex Free Gloves XLARGE (counted per box)',                                  'Medical',                36,   'Box'),
  ('B1001', 'Sanitary Towels - Size 1',                                                    'Sanitation and Hygiene', 87,   'Pack'),
  ('B1002', 'Sanitary Towels - Size 2',                                                    'Sanitation and Hygiene', 559,  'Pack'),
  ('B1003', 'Sanitary Towels - Size 3',                                                    'Sanitation and Hygiene', 2091, 'Pack'),
  ('B1004', 'Sanitary Towels - Size 4 (Currently Unavailable)',                            'Sanitation and Hygiene', 0,    'Pack'),
  ('B1005', 'Sanitary Towels - Size 5',                                                    'Sanitation and Hygiene', 853,  'Pack'),
  ('B1006', 'Sanitary Towels - Night',                                                     'Sanitation and Hygiene', 1566, 'Pack'),
  ('B1007', 'Tampons - Size 2',                                                            'Sanitation and Hygiene', 275,  'Box'),
  ('B1008', 'Tampons - Size 4',                                                            'Sanitation and Hygiene', 489,  'Box'),
  ('C1001', 'Wooden Cot',                                                                  'Baby Provisions',        24,   'Unit'),
  ('C1002', 'Baby Changing Mat',                                                           'Baby Provisions',        116,  'Unit'),
  ('C1003', 'Potty',                                                                       'Baby Provisions',        86,   'Unit'),
  ('C1004', 'Blanket Set',                                                                 'Baby Provisions',        334,  'Unit'),
  ('C1005', 'Travel Cot Fitted Sheet',                                                     'Baby Provisions',        95,   'Unit'),
  ('C1006', 'Moses Basket Fitted Sheet 2 Pack',                                            'Baby Provisions',        104,  'Pack'),
  ('C1007', 'Baby Bath Tub',                                                               'Baby Provisions',        61,   'Unit'),
  ('C1008', 'Highchair',                                                                   'Baby Provisions',        42,   'Unit'),
  ('C1009', 'Moses Basket and Stand',                                                      'Baby Provisions',        66,   'Pack'),
  ('C1010', 'Nappy Sacks (100 sacks, 4 x 25)',                                            'Baby Provisions',        806,  'Pack'),
  ('C1011', 'Travel Cot',                                                                  'Baby Provisions',        18,   'Unit'),
  ('C1012', 'Wooden Cot Replacement Mattress',                                             'Baby Provisions',        19,   'Unit'),
  ('C1013', 'Ceramic Mugs',                                                               'Fixtures',               411,  'Unit'),
  ('C2001', 'SMA 1 PRO (On Recall - Not Available Until Further Notice)',                 'Baby Provisions',        21,   'Tub'),
  ('C2002', 'SMA 2 PRO',                                                                  'Baby Provisions',        171,  'Tub'),
  ('C2003', 'SMA 3 PRO',                                                                  'Baby Provisions',        96,   'Tub'),
  ('C2004', 'SMA Lactose Free (Special Request Only)',                                    'Baby Provisions',        13,   'Tub'),
  ('C2005', 'SMA Anti-Reflux',                                                            'Baby Provisions',        119,  'Tub'),
  ('c2006', 'Cow & Gate 1 (On Recall - Not Available Until Further Notice)',              'Baby Provisions',        0,    'Tub'),
  ('C2007', 'Cow & Gate 2',                                                               'Baby Provisions',        184,  'Tub'),
  ('C2008', 'Cow & Gate 3',                                                               'Baby Provisions',        172,  'Tub'),
  ('C2009', 'Cow & Gate 4',                                                               'Baby Provisions',        167,  'Tub'),
  ('C2010', 'Ceralac 6 months',                                                           'Baby Provisions',        125,  'Tub'),
  ('C2011', 'Ceralac 12 months',                                                          'Baby Provisions',        158,  'Tub'),
  ('C3001', 'SMA First Infant Ready to Use Formula 200ml (Special Request Only)',         'Baby Provisions',        0,    'Unit'),
  ('D1001', 'Johnsons Baby Bath Wash',                                                    'Baby Provisions',        345,  'Bottle'),
  ('D1002', 'Head & Toe Wash / Baby Bath',                                                'Baby Provisions',        466,  'Bottle'),
  ('D1003', 'Baby Lotion',                                                                'Baby Provisions',        498,  'Bottle'),
  ('D1004', 'Johnsons Baby Shampoo',                                                      'Baby Provisions',        372,  'Bottle'),
  ('D1005', 'Johnsons Baby Powder',                                                       'Baby Provisions',        365,  'Bottle'),
  ('D1006', 'Sudocrem',                                                                   'Baby Provisions',        371,  'Tub'),
  ('D1007', 'Johnsons Baby Oil',                                                          'Baby Provisions',        431,  'Bottle'),
  ('D1008', 'Nappy Wipes',                                                                'Baby Provisions',        1617, 'Pack'),
  ('D1010', 'Washing Up Liquid (Restricted Item)',                                        'Fixtures',               36,   'Bottle'),
  ('D1011', 'Black Bin Bags (1 Box - 200 bags)',                                          'Laundry',                36,   'Pack'),
  ('D1012', 'Green Bin Bags Laundry (1 Box - 200 bags)',                                  'Laundry',                268,  'Pack'),
  ('D2004', 'Aptamil Anti-Reflux',                                                        'Baby Provisions',        92,   'Tub'),
  ('D2005', 'Aptamil Lactose Free From Birth',                                            'Baby Provisions',        38,   'Tub'),
  ('D2006', 'Aptamil Advanced 1 (Special Request Only)',                                  'Baby Provisions',        6,    'Tub'),
  ('D2007', 'Aptamil Pepti 1 (Cows Milk Allergy)',                                       'Baby Provisions',        3,    'Tub'),
  ('D2008', 'Aptamil Advanced 2 (Special Request Only)',                                  'Baby Provisions',        3,    'Tub'),
  ('D2009', 'APTAMIL 1',                                                                  'Baby Provisions',        253,  'Tub'),
  ('D2010', 'APTAMIL 2',                                                                  'Baby Provisions',        278,  'Tub'),
  ('D2011', 'APTAMIL 3',                                                                  'Baby Provisions',        210,  'Tub'),
  ('D2012', 'Aptamil 4',                                                                  'Baby Provisions',        171,  'Tub'),
  ('D2013', 'Kendamil 1',                                                                 'Baby Provisions',        71,   'Tub'),
  ('D2014', 'Kendamil 2',                                                                 'Baby Provisions',        72,   'Tub'),
  ('D2015', 'Kendamil 3',                                                                 'Baby Provisions',        57,   'Tub'),
  ('E1001', 'Milton Cold Water Steriliser',                                               'Baby Provisions',        98,   'Unit'),
  ('E1002', 'Milton Sterilising Tablets (1 Box)',                                         'Baby Provisions',        654,  'Pack'),
  ('E1003', 'Milton Antibacterial Spray',                                                 'Baby Provisions',        66,   'Bottle'),
  ('E1004', 'Microwave Baby Bottle Steriliser',                                           'Baby Provisions',        8,    'Unit'),
  ('E1005', 'Children''s Plates',                                                         'Baby Provisions',        136,  'Pack'),
  ('E1006', 'Childrens Cutlery - Plastic',                                                'Baby Provisions',        253,  'Pack'),
  ('E1007', 'Baby Bottle Electronic Steriliser (Special Request)',                        'Baby Provisions',        9,    'Unit'),
  ('E1008', 'Baby Bottle Brushes',                                                        'Baby Provisions',        126,  'Unit'),
  ('E1009', 'Baby Bottles',                                                               'Baby Provisions',        694,  'Pack'),
  ('E1010', 'Breast Pads',                                                                'Baby Provisions',        105,  'Box'),
  ('E1011', 'Dummies',                                                                    'Baby Provisions',        1051, 'Unit'),
  ('E1012', 'Breast Pump',                                                                'Baby Provisions',        48,   'Unit'),
  ('E1013', 'Breast Milk Bags',                                                           'Baby Provisions',        784,  'Box'),
  ('E1014', 'Lanolin Nipple Cream',                                                       'Baby Provisions',        38,   'Tube'),
  ('E1015', 'Laundry Bags Zip (individual bags, not packs)',                              'Laundry',                285,  'Bag'),
  ('E1016', 'Sports Water Bottles',                                                       'Hydration',              2454, 'Bottle'),
  ('E1017', 'Children''s Bowls',                                                          'Baby Provisions',        65,   'Pack'),
  ('E1018', 'Children''s Cups',                                                           'Baby Provisions',        102,  'Pack'),
  ('f1001', 'Pull Ups Size 5',                                                            'Baby Provisions',        64,   'Pack'),
  ('f1002', 'Pull Ups Size 6 - Daytime',                                                  'Baby Provisions',        79,   'Pack'),
  ('f1003', 'Pull Ups Size 6 - Nighttime',                                                'Baby Provisions',        148,  'Pack'),
  ('f1004', 'Pull Ups Size 7',                                                            'Baby Provisions',        29,   'Pack'),
  ('F1005', 'Pull Ups Size 8',                                                            'Baby Provisions',        51,   'Pack'),
  ('F1006', 'Nappies Size 8',                                                             'Baby Provisions',        269,  'Pack'),
  ('F2001', 'Nappies Size 4',                                                             'Baby Provisions',        567,  'Pack'),
  ('F2002', 'Nappies Size 5',                                                             'Baby Provisions',        376,  'Pack'),
  ('F2003', 'Nappies Size 6',                                                             'Baby Provisions',        341,  'Pack'),
  ('F2004', 'Nappies Size 7',                                                             'Baby Provisions',        192,  'Pack'),
  ('G2001', 'Nappies Size 0',                                                             'Baby Provisions',        146,  'Pack'),
  ('G2002', 'Nappies Size 1',                                                             'Baby Provisions',        480,  'Pack'),
  ('G2003', 'Nappies Size 2',                                                             'Baby Provisions',        313,  'Pack'),
  ('G2004', 'Nappies Size 3',                                                             'Baby Provisions',        490,  'Pack'),
  ('Z1038', 'Silent Shredder',                                                            'Office',                 3,    'Unit')
) as v(product_code, name, category, quantity, unit)
where not exists (
  select 1 from public.items i
  where i.hotel_id = (select id from public.hotels where code = 'WAREHOUSE')
    and i.product_code = v.product_code
);

-- ======================================================================
-- VERIFICATION
-- ======================================================================
-- select count(*) from public.items
-- where hotel_id = (select id from public.hotels where code = 'WAREHOUSE');
-- → should return 125
--
-- select product_code, name, quantity, unit from public.items
-- where hotel_id = (select id from public.hotels where code = 'WAREHOUSE')
-- order by product_code;
-- ======================================================================
