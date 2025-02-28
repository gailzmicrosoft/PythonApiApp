import os
from flask import Flask, request, jsonify
from functools import wraps

app = Flask(__name__)

# Replace 'SERVER_API_KEY' with your actual environment variable name
# This was set using a command like: export SERVER_API_KEY / $Env:SERVER_API_KEY="YourApiKeySample"
# Check the environment variable for the API key: echo $SERVER_API_KEY
# test this code by running: python app.py or use the command: python -m flask run 
# The test as a client in a terminal: curl -H "x-api-key:YourApiKeySample" http://localhost:8080/

#SECRET_API_KEY = os.environ.get("SERVER_API_KEY").strip()

# just for testing 
SECRET_API_KEY = "TestKey"

#curl -H "x-api-key:TestKey" http://localhost:8080/

print(f"Server Side Key set to: {SECRET_API_KEY}")  # Debugging line

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

    # For demonstration purposes, we'll just return the received data
    # In a real application, you would query your database or perform other logic here
    return jsonify({
        "message": "Order check received",
        "first_name": first_name,
        "last_name": last_name,
        "email": email
    })

@app.route("/")
def hello():
    return "Hello, World!"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)