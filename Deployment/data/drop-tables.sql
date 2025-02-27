-- PostgreSQL script to drop tables
-- Forcefully drop tables if they exist, including dependent objects
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;


-- PostgreSQL script to Truncate all data from tables
Truncate Table public.products;
Truncate Table public.customers;
Truncate Table public.orders;
