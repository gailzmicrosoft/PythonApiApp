from azure.identity import DefaultAzureCredential
import psycopg2
import psycopg2.extras
from psycopg2 import sql
import os
import pandas as pd
import logging

# Configuration parameters
key_vault_name = "key_vault_name_place_holder"
host_name = "yourserver.postgres.database.azure.com" # used for local testing
admin_principal_name = "yourAdmUserName" # used for local testing
identity_name = "identity_name_place_holder"
database_name = "postgres" # used for local testing
basrUrl = "basrUrl_place_holder"
admin_principal_password = "YourAdmUserPass"  # used for local testing
# change below to your own value for local testing:
basrUrl = "https://raw.githubusercontent.com/gailzmicrosoft/TestCode/main/infra/" # used for local testing

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def truncate_tables(cursor, tables):
    """
    Truncate the specified tables.
    """
    for table in tables:
        cursor.execute(sql.SQL("TRUNCATE TABLE {}").format(sql.Identifier(table)))
    logger.info("Tables truncated: %s", ", ".join(tables))

def load_table_from_csv(cursor, table_name, csv_file_path, columns):
    """
    Loads data from a CSV file into a specified PostgreSQL table.
    """
    df = pd.read_csv(csv_file_path)
    df.columns = df.columns.str.strip()
    rows = [tuple(row[col] for col in columns) for index, row in df.iterrows()]
    insert_query = sql.SQL("INSERT INTO {} ({}) VALUES %s").format(
        sql.Identifier(table_name),
        sql.SQL(', ').join(map(sql.Identifier, columns))
    )
    psycopg2.extras.execute_values(cursor, insert_query, rows)
    logger.info("Data loaded into %s table.", table_name)

def main():
    try:
        # Acquire the access token
        logger.info("Acquiring access token...")
        cred = DefaultAzureCredential()
        access_token = cred.get_token("https://ossrdbms-aad.database.windows.net/.default")
        logger.info("Access token acquired.")
        
        # Combine the token with the connection string to establish the connection.
        logger.info("Establishing database connection...")
        conn_string = (
            "host={0} user={1} dbname={2} password={3} sslmode=require".format(
        #       host_name, identity_name, database_name, access_token.token
               host_name, admin_principal_name, database_name, admin_principal_password
            )
        )
        
        conn = psycopg2.connect(conn_string)
        cursor = conn.cursor()
        logger.info("Database connection established.")

        try:
        # Truncate the tables
            truncate_tables(cursor, ["products", "customers", "orders"])
            conn.commit()
        except Exception as e:
            logger.error("An error occurred while truncating tables: %s", e)
            conn.rollback() # Rollback the transaction in case of error

        try:
        # Load data into the products table
            csv_file_path_products = os.path.join(basrUrl, 'data/postgresql_db_sample_data/products.csv')
            load_table_from_csv(cursor, 'products', csv_file_path_products, 
                ['id', 'product_name', 'price', 'category', 'brand', 'product_description'])
            conn.commit()
        except Exception as e:
            logger.error("An error occurred while loading products table: %s", e)
            conn.rollback() # Rollback the transaction in case of error

        try:
        # Load data into the customers table
            csv_file_path_customers = os.path.join(basrUrl, 'data/postgresql_db_sample_data/customers.csv')
            load_table_from_csv(cursor, 'customers', csv_file_path_customers, 
                ['id', 'first_name', 'last_name', 'gender', 'date_of_birth', 'age', 'email', 'phone', 'post_address', 'membership'])
            conn.commit()
        except Exception as e:
            logger.error("An error occurred while loading customers table: %s", e)
            conn.rollback() # Rollback the transaction in case of error
        
        try:
        # Load data into the orders table
            csv_file_path_orders = os.path.join(basrUrl, 'data/postgresql_db_sample_data/orders.csv')
            load_table_from_csv(cursor, 'orders', csv_file_path_orders, 
                ['id', 'customer_id', 'product_id', 'quantity', 'total', 'order_date', 'customer_first_name', 'customer_last_name', 'unit_price', 'category', 'brand', 'product_description', 'return_status'])
            conn.commit()
        except Exception as e:
            logger.error("An error occurred while loading orders table: %s", e)
            conn.rollback() # Rollback the transaction in case of error

    except Exception as e:
        logger.error("An error occurred while executint main program: %s", e)
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

if __name__ == "__main__":
    main()