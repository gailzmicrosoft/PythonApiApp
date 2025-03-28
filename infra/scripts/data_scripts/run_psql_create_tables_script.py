# version 1.0 
from azure.identity import DefaultAzureCredential
import psycopg2
from psycopg2 import sql

key_vault_name = "key_vault_name_place_holder"
host_name = "host_name_place_holder"
admin_principal_name = "admin_principal_name_place_holder"
identity_name = "identity_name_place_holder"
database_name= "database_name_place_holder"


# Grant Permission Function
def grant_permissions(cursor, db_name, schema_name, principal_name):
    """
    Grants database and schema-level permissions to a specified principal.
    Parameters:
    - cursor: psycopg2 cursor object for database operations.
    - db_name: Name of the database to grant CONNECT permission.
    - schema_name: Name of the schema to grant table-level permissions.
    - principal_name: Name of the principal (role or user) to grant permissions.
    """
    # Check if the principal exists in the database
    cursor.execute(
        sql.SQL("SELECT 1 FROM pg_roles WHERE rolname = {principal}").format(
            principal=sql.Literal(principal_name)
        )
    )
    if cursor.fetchone() is None:
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
    print(f"Granted CONNECT on database '{db_name}' to '{principal_name}'")

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
# end of grant_permissions function

##########################################################################################
# Program starts here
##########################################################################################
# Acquire the access token
cred = DefaultAzureCredential()
access_token = cred.get_token("https://ossrdbms-aad.database.windows.net/.default")

# Combine the token with the connection string to establish the connection.
# The identity name is used as the username in the connection string.
conn_string = "host={0} user={1} dbname={2} password={3} sslmode=require".format(
    host_name, identity_name, database_name, access_token.token
)
conn = psycopg2.connect(conn_string)
cursor = conn.cursor()

# Drop and recreate the products table
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

# Drop and recreate the customers table
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

# Drop and recreate the orders table
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

# Add Vector extension
cursor.execute("CREATE EXTENSION IF NOT EXISTS vector CASCADE;")
conn.commit()

cursor.execute("DROP TABLE IF EXISTS vector_store;")
conn.commit()

create_vs_sql= """
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

# Grant permissions to the admin principal if provided
if admin_principal_name and admin_principal_name.strip():
    grant_permissions(cursor, database_name, "public", admin_principal_name)
    conn.commit()
    
# Grant permissions to the additional principal if provided
if identity_name and identity_name.strip():
    grant_permissions(cursor, database_name, "public", identity_name)
    conn.commit()

# Set default privileges for future tables in the public schema
cursor.execute("""
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO azure_pg_admin;
""")
conn.commit()


cursor.close()
conn.close()
