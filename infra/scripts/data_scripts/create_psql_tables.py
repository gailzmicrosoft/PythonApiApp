# version 1.2
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import psycopg2
from psycopg2 import sql
import logging
import sys


################################################################################################
# Initialization: 
# Parameters and logging 
# Retrieve secrets from Azure Key Vault
################################################################################################

# Placeholder for Key Vault name
key_vault_name = "key_vault_name_place_holder"

# If you want to test the code loaclly: 
postgresql_end_point  = "postgresql_end_point _place_holder"
postgresql_admin_login  = "postgresql_admin_login _place_holder"
mid_name = "mid_name_place_holder"
postgresql_db_name = "postgresql_db_name_place_holder"


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logging.info("Starting the script...")
# Retrieve secrets from Key Vault

try:
    logging.info(f"Retrieving secrets from Key Vault '{key_vault_name}'...")
    key_vault_uri = f"https://{key_vault_name}.vault.azure.net/"
    credential = DefaultAzureCredential()
    secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)
    postgresql_end_point = secret_client.get_secret("postgresql-server-end-point").value
    postgresql_admin_login = secret_client.get_secret("postgresql-admin-login").value
    mid_name = secret_client.get_secret("mid-name").value
    postgresql_db_name = secret_client.get_secret("postgresql-db-name").value

    logging.info(f"Retrieved values from Key Vault:")
    logging.info(f"PostgreSql End Point: {postgresql_end_point}")
    logging.info(f"Admin Principal Name: {postgresql_admin_login}")
    logging.info(f"Managed Identity Name: {mid_name}")
    logging.info(f"Database Name: {postgresql_db_name}")

except Exception as e:
    logging.error(f"An error occurred while retrieving secrets: {e}")
    sys.exit(1)

# The rest of your script (e.g., database connection and table creation) goes here...

# Grant Permission Function
def grant_permissions(cursor, db_name, schema_name, principal_name):
    """
    Grants database and schema-level permissions to a specified principal.
    """
    try:
        logging.info(f"Granting permissions to principal: {principal_name}")

        # Check if the principal exists in the database
        cursor.execute(
            sql.SQL("SELECT 1 FROM pg_roles WHERE rolname = {principal}").format(
                principal=sql.Literal(principal_name)
            )
        )
        if cursor.fetchone() is None:
            logging.info(f"Principal '{principal_name}' does not exist. Creating it...")
            add_principal_user_query = sql.SQL(
                "SELECT * FROM pgaadauth_create_principal({principal}, false, false)"
            )
            cursor.execute(
                add_principal_user_query.format(
                    principal=sql.Literal(principal_name),
                )
            )

        # Grant CONNECT on database
        grant_connect_query = sql.SQL("GRANT CONNECT ON DATABASE {database} TO {principal}")
        cursor.execute(
            grant_connect_query.format(
                database=sql.Identifier(db_name),
                principal=sql.Identifier(principal_name),
            )
        )
        logging.info(f"Granted CONNECT on database '{db_name}' to '{principal_name}'")

        # Grant SELECT, INSERT, UPDATE, DELETE on schema tables
        grant_permissions_query = sql.SQL(
            "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA {schema} TO {principal}"
        )
        cursor.execute(
            grant_permissions_query.format(
                schema=sql.Identifier(schema_name),
                principal=sql.Identifier(principal_name),
            )
        )
        logging.info(f"Granted table-level permissions on schema '{schema_name}' to '{principal_name}'")

    except Exception as e:
        logging.error(f"Error granting permissions to '{principal_name}': {e}")
        raise

#####################################################################################################
# Main Program
#####################################################################################################
try:
    # Acquire the access token
    logging.info("Acquiring access token...")
    cred = DefaultAzureCredential()
    access_token = cred.get_token("https://ossrdbms-aad.database.windows.net/.default")
    logging.info("Access token acquired successfully.")

    # Combine the token with the connection string to establish the connection
    logging.info("Establishing connection to the PostgreSQL server...")
    conn_string = "host={0} user={1} dbname={2} password={3} sslmode=require".format(
         postgresql_end_point, mid_name, postgresql_db_name, access_token.token
    )

    # # Below can be used for local testing. Swap code with above code using azure identity. 
    # postgresql_end_point = ''
    # postgresql_admin_login = ''
    # postgresql_admin_password = ''
    # postgresql_db_name = 'postgres'
    # # conn_string = "host={0} user={1} dbname={2} password={3} sslmode=require".format(
    # #      postgresql_end_point, postgresql_admin_login, postgresql_db_name, postgresql_admin_password
    # # )

    conn = psycopg2.connect(conn_string)
    cursor = conn.cursor()
    logging.info("Connection established successfully.")

    # Drop and recreate the products table
    logging.info("Dropping and recreating the 'products' table...")
    cursor.execute("DROP TABLE IF EXISTS products")
    conn.commit()

    create_products_sql = """
    CREATE TABLE IF NOT EXISTS products
    (
        id integer,
        product_name character varying(100),
        price numeric(10,2) NOT NULL,
        category character varying(50),
        brand character varying(50),
        product_description text
    );
    """
    cursor.execute(create_products_sql)
    conn.commit()
    logging.info("'products' table created successfully.")

    # Drop and recreate the customers table
    logging.info("Dropping and recreating the 'customers' table...")
    cursor.execute("DROP TABLE IF EXISTS customers")
    conn.commit()

    create_customers_sql = """
    CREATE TABLE customers
    (
        id integer,
        first_name character varying(50),
        last_name character varying(50),
        gender character varying(10),
        date_of_birth date,
        age integer,
        email character varying(100),
        phone character varying(20),
        post_address character varying(255),
        membership character varying(50)
    );
    """
    cursor.execute(create_customers_sql)
    conn.commit()
    logging.info("'customers' table created successfully.")

    # Drop and recreate the orders table
    logging.info("Dropping and recreating the 'orders' table...")
    cursor.execute("DROP TABLE IF EXISTS orders")
    conn.commit()

    create_orders_sql = """
    CREATE TABLE orders
    (
        id integer,
        customer_id integer,
        customer_first_name character varying(50),
        customer_last_name character varying(50),
        customer_gender character varying(10),
        customer_age integer,
        customer_email character varying(100),
        customer_phone character varying(20),
        order_date date,
        product_id integer,
        product_name character varying(100),
        quantity integer,
        unit_price numeric(10,2),
        total numeric(10,2),
        category character varying(50),
        brand character varying(50),
        product_description text,
        return_status BOOLEAN DEFAULT FALSE
    );
    """
    cursor.execute(create_orders_sql)
    conn.commit()
    logging.info("'orders' table created successfully.")

    # Add Vector extension
    logging.info("Adding 'vector' extension...")
    cursor.execute("CREATE EXTENSION IF NOT EXISTS vector CASCADE;")
    conn.commit()

    cursor.execute("DROP TABLE IF EXISTS vector_store;")
    conn.commit()

    create_vs_sql = """
    CREATE TABLE IF NOT EXISTS vector_store(
        id text,
        title text,
        chunk integer,
        chunk_id text,
        "offset" integer,
        page_number integer,
        content text,
        source text,
        metadata text,
        content_vector public.vector(1536)
    );
    """
    cursor.execute(create_vs_sql)
    conn.commit()

    cursor.execute(
        "CREATE INDEX vector_store_content_vector_idx ON vector_store USING hnsw (content_vector vector_cosine_ops);"
    )
    conn.commit()
    logging.info("'vector_store' table and index created successfully.")

    # Grant permissions to the admin principal if provided
    if postgresql_admin_login and postgresql_admin_login.strip():
        logging.info(f"Granting permissions to admin principal: {postgresql_admin_login}")
        grant_permissions(cursor, postgresql_db_name, "public", postgresql_admin_login)
        conn.commit()

    # Grant permissions to the additional principal if provided
    if mid_name and mid_name.strip():
        logging.info(f"Granting permissions to identity: {mid_name}")
        grant_permissions(cursor, postgresql_db_name, "public", mid_name)
        conn.commit()

    # Set default privileges for future tables in the public schema
    logging.info("Setting default privileges for future tables in the 'public' schema...")
    cursor.execute("""
        ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT ALL PRIVILEGES ON TABLES TO azure_pg_admin;
    """)
    conn.commit()
    logging.info("Default privileges set successfully.")

except Exception as e:
    logging.error(f"An error occurred: {e}")
finally:
    # Close the cursor and connection
    if 'cursor' in locals() and cursor:
        cursor.close()
    if 'conn' in locals() and conn:
        conn.close()
    logging.info("Database connection closed.")