# filepath: /c:/Repos/PythonApiApp/RestAPIs/src/client.py
import requests

# Define the API endpoint and the API key
url = "http://localhost:8080/"
headers = {"x-api-key":"YourApiKeySample"}

# Make a GET request to the API
response = requests.get(url, headers=headers)

# Print the response
print(f"Status Code: {response.status_code}")
print(f"Response Body: {response.text}")