import psycopg2
import pandas as pd
import urllib.parse
import os
import sys
import getpass

# Read URI parameters from the environment
dbhost = "yourpostgresqlserver.postgres.database.azure.com"
dbname = "yourdbname"
sslmode = "prefer"

# Prompt the user for the password securely
dbuser = input('Enter your PostgreSQL DB username: ')
password = getpass.getpass(prompt='Enter your PostgreSQL password: ')

# Connection string
conn_string = f"host={dbhost} dbname={dbname} user={dbuser} password={password} sslmode={sslmode}"

# Connect to the PostgreSQL server
conn = psycopg2.connect(conn_string)
print("Connection established")
cursor = conn.cursor()

# Print the current working directory
current_directory = os.getcwd()
print(f"Current working directory: {current_directory}")

# csv_file_dir = r"C:\Repos\postgresql\data_prep_python\sample_data"
csv_file_dir = input('Enter the directory where the products.csv is located: ')

csv_file_path = os.path.join(csv_file_dir, 'products.csv')
print(f"CSV file path: {csv_file_path}")

#
# Check if the CSV file exists
if not os.path.exists(csv_file_path):
    print(f"CSV file does not exist: {csv_file_path}")
    sys.exit(1)

# Read the CSV file into a DataFrame
df = pd.read_csv(csv_file_path)

# Insert data into the product table
for index, row in df.iterrows():
    cursor.execute(
        "INSERT INTO products (id, product_name, price, category, brand, product_description) VALUES (%s, %s, %s, %s, %s, %s)",
        (row['id'], row['product_name'], row['price'], row['category'], row['brand'], row['product_description'])
    )

print("Inserted rows from products.csv into the products table")

# Clean up
conn.commit()
cursor.close()
conn.close()