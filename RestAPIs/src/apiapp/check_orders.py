from flask import request, jsonify

def check_orders():
    first_name = request.args.get("first_name")
    last_name = request.args.get("last_name")
    email = request.args.get("email")

    # For demonstration purposes, we'll just return the received data
    # In a real application, you would query your database or perform other logic here
    return jsonify({
        "message": "check_order request received",
        "first_name": first_name,
        "last_name": last_name,
        "email": email
    })