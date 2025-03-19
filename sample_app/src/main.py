from flask import Flask, request, jsonify
from azure.ai.openai import OpenAIClient
from azure.core.credentials import AzureKeyCredential
import os
from functools import wraps

app = Flask(__name__)

# Initialize Azure OpenAI client
openai_api_key = os.getenv('AZURE_OPENAI_API_KEY')
openai_endpoint = os.getenv('AZURE_OPENAI_ENDPOINT')
api_key = os.getenv('APP_API_KEY')
client = OpenAIClient(endpoint=openai_endpoint, credential=AzureKeyCredential(openai_api_key))

def require_api_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        request_api_key = request.headers.get('x-api-key')
        if request_api_key and request_api_key == api_key:
            return f(*args, **kwargs)
        else:
            return jsonify({"message": "Unauthorized"}), 401
    return decorated_function

@app.route('/set_master_prompt', methods=['POST'])
@require_api_key
def set_master_prompt():
    data = request.json
    prompt = data.get('prompt')
    # Save the master prompt (this can be saved to a database or a file)
    # For simplicity, we'll just return it
    return jsonify({"message": "Master prompt set successfully", "prompt": prompt})

@app.route('/generate_sample_document', methods=['POST'])
@require_api_key
def generate_sample_document():
    data = request.json
    prompt = data.get('prompt')
    response = client.completions.create(
        engine="davinci",
        prompt=prompt,
        max_tokens=500
    )
    return jsonify({"document": response.choices[0].text})

if __name__ == '__main__':
    app.run(debug=True)