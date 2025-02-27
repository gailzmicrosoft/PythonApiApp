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
xlsx_file_dir = input('Enter the directory where the customers-data.xlsx is located: ')

# Path to the Excel file
xlsx_file_path = os.path.join(xlsx_file_dir, 'customers-data.xlsx')
print(f"Excel file path: {xlsx_file_path}")

# Check if the Excel file exists
if not os.path.exists(xlsx_file_path):
    print(f"Excel file does not exist: {xlsx_file_path}")
    sys.exit(1)

# Read the Excel file into a DataFrame, specifying the sheet name
df = pd.read_excel(xlsx_file_path, sheet_name='customers')

# Strip whitespace from column names
df.columns = df.columns.str.strip()

# Insert data into the customers table
for index, row in df.iterrows():
    cursor.execute(
        "INSERT INTO customers (id, first_name, last_name, gender, date_of_birth, age, email, phone, post_address, membership) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
        (
            row['id'],
            row['first_name'],
            row['last_name'],
            row['gender'],
            row['date_of_birth'],
            row['age'],
            row['email'],
            row['phone'],
            row['post_address'],
            row['membership']
        )
    )

print("Inserted rows from customers-data.xlsx into the customers table")

# Commit the transaction and close connections
conn.commit()
cursor.close()
conn.close()