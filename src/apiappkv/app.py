import os
import datetime
from flask import Flask, request, jsonify, render_template
from functools import wraps
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

app = Flask(__name__)

# Retrieve the Key Vault URI from the environment variable
key_vault_uri = os.environ.get("KEY_VAULT_URI'")
if not key_vault_uri:
    raise Exception("KEY_VAULT_URI environment variable is not set")

print(f"Key Vault URI: {key_vault_uri}")

# Initialize Azure Key Vault client
credential = DefaultAzureCredential()
secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)

# Retrieve the secret value for x-api-key from Azure Key Vault
try:
    SECRET_API_KEY = secret_client.get_secret('x-api-key').value
    managed_identity_name = secret_client.get_secret('mid-name').value
    managed_identity_id = secret_client.get_secret('mid-id').value


    print(f"Secret '{secret_name}' retrieved successfully.")


    print(f"Retrieved secret '{secret_name}' from Key Vault.")
except Exception as e:
    raise Exception(f"Failed to retrieve secret '{secret_name}' from Key Vault: {e}")


# Decorator to require API key
def require_api_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get("x-api-key")
        print(f"Received API key: {api_key}")  # Debugging line
        if not api_key:
            return jsonify({"error": "API key missing"}), 401
        if api_key != SECRET_API_KEY:
            return jsonify({"error": "Invalid API key"}), 403
        return f(*args, **kwargs)
    return decorated_function

@app.route("/check_orders", methods=["GET"])
@require_api_key
def check_orders():
    first_name = request.args.get("first_name")
    last_name = request.args.get("last_name")
    email = request.args.get("email")
    order_date = request.args.get("order_date")
    comments = request.args.get("comments")
  
    return jsonify({
        "message": "check_order request received",
        "first_name": first_name,
        "last_name": last_name,
        "email": email,
        "order_date": order_date,
        "comments": comments
    })

@app.route("/")
def hello():
    today = datetime.datetime.now()
    formatted_date = today.strftime("%Y-%m-%d %H:%M:%S")
    message = f"Welcome to the REST API App. Current date and time is: {formatted_date}"
    return (josonfy({"message": message}))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)