import requests

# Configuration
API_BASE_URL = "http://localhost:8080"  # Change this to your Azure Container App URL when deployed
API_KEY = "PythonApiKey"  # Replace with the actual API key retrieved from Azure Key Vault

def test_check_orders():
    # Define the endpoint and query parameters
    endpoint = f"{API_BASE_URL}/check_orders"
    params = {
        "first_name": "John",
        "last_name": "Doe",
        "email": "john.doe@example.com",
        "order_date": "2025-03-27",
        "comments": "This is a test order"
    }

    # Define the headers
    headers = {
        "x-api-key": API_KEY
    }

    try:
        # Make the GET request
        response = requests.get(endpoint, headers=headers, params=params)

        # Check the response status code
        if response.status_code == 200:
            print("Request was successful!")
            print("Response JSON:")
            print(response.json())
        elif response.status_code == 401:
            print("Error: API key is missing or not provided.")
        elif response.status_code == 403:
            print("Error: Invalid API key.")
        else:
            print(f"Error: Received unexpected status code {response.status_code}")
            print("Response Text:")
            print(response.text)
    except Exception as e:
        print(f"An error occurred while making the request: {e}")

if __name__ == "__main__":
    print("Testing the /check_orders endpoint...")
    test_check_orders()