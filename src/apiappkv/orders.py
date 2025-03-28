import psycopg2
from psycopg2.extras import RealDictCursor
import logging
from azure.identity import DefaultAzureCredential


# Database connection configuration
DB_CONFIG = {
    "dbname": "your_database_name",
    "user": "your_database_user",
    "password": "your_database_password",
    "host": "your_database_host",
    "port": 5432  # Default PostgreSQL port
}

key_vault_name = "key_vault_name_place_holder"
host_name = "host_name_place_holder"
admin_principal_name = "admin_principal_name_place_holder"
identity_name = "identity_name_place_holder"
database_name = "database_name_place_holder"

def get_orders(first_name, last_name, email, order_date, comments):
    """
    Fetch orders from the PostgreSQL database based on the provided filters.
    """
    try:
        # Connect to the PostgreSQL database
        connection = psycopg2.connect(**DB_CONFIG)
        cursor = connection.cursor(cursor_factory=RealDictCursor)

        # Build the SQL query with optional filters
        query = """
        SELECT * FROM orders
        WHERE (%s IS NULL OR first_name = %s)
          AND (%s IS NULL OR last_name = %s)
          AND (%s IS NULL OR email = %s)
          AND (%s IS NULL OR order_date = %s)
        """
        params = (first_name, first_name, last_name, last_name, email, email, order_date, order_date, comments, f"%{comments}%")

        # Execute the query
        cursor.execute(query, params)
        orders = cursor.fetchall()

        # Close the cursor and connection
        cursor.close()
        connection.close()

        return orders

    except Exception as e:
        print(f"Error fetching orders: {e}")
        return {"error": "Failed to fetch orders from the database"}