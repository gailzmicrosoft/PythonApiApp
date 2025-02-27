-- SQL script to create tables for a prototype e-commerce PostgreSQL database

-- Create the products table
--DROP TABLE IF EXISTS public.products;
CREATE TABLE IF NOT EXISTS public.products
(
    id integer,
    product_name character varying(100) COLLATE pg_catalog."default" NOT NULL,
    price numeric(10,2) NOT NULL,
    category character varying(50) COLLATE pg_catalog."default",
    brand character varying(50) COLLATE pg_catalog."default",
    product_description text COLLATE pg_catalog."default"
);

-- Create the customers table
--DROP TABLE IF EXISTS public.customers;
CREATE TABLE public.customers
(
    id integer,
    first_name character varying(50) COLLATE pg_catalog."default",
    last_name character varying(50) COLLATE pg_catalog."default",
    gender character varying(10) COLLATE pg_catalog."default",
    date_of_birth date,
    age integer,
    email character varying(100) COLLATE pg_catalog."default",
    phone character varying(20) COLLATE pg_catalog."default",
    post_address character varying(255) COLLATE pg_catalog."default",
    membership character varying(50) COLLATE pg_catalog."default"
);

-- Create the orders table
--DROP TABLE IF EXISTS public.orders;
CREATE TABLE public.orders
(
    id integer,
    customer_id integer,
    product_id integer,
    quantity integer,
    total numeric(10,2),
    order_date date,
    customer_first_name character varying(50) COLLATE pg_catalog."default",
    customer_last_name character varying(50) COLLATE pg_catalog."default",
    unit_price numeric(10,2),
    category character varying(50) COLLATE pg_catalog."default",
    brand character varying(50) COLLATE pg_catalog."default",
    product_description text COLLATE pg_catalog."default",
    return_status BOOLEAN DEFAULT FALSE
);