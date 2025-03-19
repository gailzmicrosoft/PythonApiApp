import psycopg2
import random
from datetime import datetime, timedelta
import os
import sys
import getpass

# Adjust these with your own DB connection info
dbhost = "yourpostgresqlserver.postgres.database.azure.com"
dbname = "yourdbname"
sslmode = "prefer"

dbuser = input('Enter your PostgreSQL DB username: ')
password = getpass.getpass(prompt='Enter your PostgreSQL password: ')

conn_string = f"host={dbhost} dbname={dbname} user={dbuser} password={password} sslmode={sslmode}"

def get_random_date(start_year=2023, end_year=2024):
    """Generate a random date between start_year-01-01 and end_year-12-31."""
    start_date = datetime(start_year, 1, 1)
    end_date = datetime(end_year, 12, 31)
    delta = (end_date - start_date).days
    random_days = random.randint(0, delta)
    return start_date + timedelta(days=random_days)

try:
    # Connect to the database
    conn = psycopg2.connect(conn_string)
    cursor = conn.cursor()
    print("Connection established")

    # Get all customers
    cursor.execute("SELECT id, first_name, last_name FROM public.customers")
    customers = cursor.fetchall()  # List of (id, first_name, last_name)

    # Get all products
    cursor.execute("SELECT id, product_name, price, category, brand, product_description FROM public.products")
    products = cursor.fetchall()  # List of (id, product_name, price, category, brand, product_description)

    if not customers or not products:
        print("No data found in customers or products table. Please ensure they have rows.")
        sys.exit(0)

    orders_to_generate = 300
    for i in range(orders_to_generate):
        random_customer = random.choice(customers)
        random_product = random.choice(products)
        
        # Unpack the random customer
        customer_id, customer_first_name, customer_last_name = random_customer
        
        # Unpack the random product
        product_id, product_name, price, category, brand, product_description = random_product
        
        # Generate random quantity and order date
        quantity = random.randint(1, 5)
        order_date = get_random_date(2023, 2024)
        total = price * quantity
        
        order_id = i + 1  # Order ID can be the loop index + 1
        # Insert into orders table
        cursor.execute(
            """
            INSERT INTO public.orders
            ( 
                id,
                customer_id,
                product_id,
                quantity,
                total,
                order_date,
                customer_first_name,
                customer_last_name,
                unit_price,
                category,
                brand,
                product_description
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                order_id,
                customer_id,
                product_id,
                quantity,
                total,
                order_date,
                customer_first_name,
                customer_last_name,
                price,
                category,
                brand,
                product_description
            )
        )
    conn.commit()
    print(f"Successfully inserted {orders_to_generate} random orders.")
except (Exception, psycopg2.DatabaseError) as error:
    print(f"Error: {error}")
    if conn:
        conn.rollback()
finally:
    if conn:
        cursor.close()
        conn.close()
        print("Connection closed")