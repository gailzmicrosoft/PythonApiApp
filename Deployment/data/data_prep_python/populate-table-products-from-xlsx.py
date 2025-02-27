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

# Directory containing the Excel file
# xlsx_file_dir = r"C:\Repos\postgresql\data_prep_python\sample_data"
xlsx_file_dir = input('Enter the directory where the products-data.xlsx is located: ')

# Path to the Excel file
xlsx_file_path = os.path.join(xlsx_file_dir, 'products-data.xlsx')
print(f"Excel file path: {xlsx_file_path}")

# Check if the Excel file exists
if not os.path.exists(xlsx_file_path):
    print(f"Excel file does not exist: {xlsx_file_path}")
    sys.exit(1)

# Read the Excel file into a DataFrame, specifying the sheet name
df = pd.read_excel(xlsx_file_path, sheet_name='products')

# Strip whitespace from column names
df.columns = df.columns.str.strip()

# Insert data into the products table
for index, row in df.iterrows():
    cursor.execute(
        "INSERT INTO productstest (id, product_name, price, category, brand, product_description) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        (
            row['id'],
            row['product_name'],
            row['price'],
            row['category'],
            row['brand'],
            row['product_description']
        )
    )

print("Inserted rows from products-data.xlsx into the products table")

# Commit the transaction and close connections
conn.commit()
cursor.close()
conn.close()