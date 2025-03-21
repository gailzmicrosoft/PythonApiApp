# filepath: /C:/Repos/PythonApiApp/RestAPIs/src/app_oauth.py
import os
from flask import Flask, request, jsonify, redirect, url_for, session
from authlib.integrations.flask_client import OAuth
from functools import wraps
from check_orders import check_orders  # Import the check_orders function

app = Flask(__name__)
app.secret_key = 'random_secret_key'
oauth = OAuth(app)

# Configure OAuth provider (Microsoft)
oauth.register(
    name='microsoft',
    client_id=os.getenv('MICROSOFT_CLIENT_ID'),
    client_secret=os.getenv('MICROSOFT_CLIENT_SECRET'),
    authorize_url='https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    authorize_params=None,
    access_token_url='https://login.microsoftonline.com/common/oauth2/v2.0/token',
    access_token_params=None,
    refresh_token_url=None,
    redirect_uri='http://localhost:8080/auth',
    client_kwargs={'scope': 'openid profile email'}
)

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/')
def hello():
    return 'Hello, World!'

@app.route('/login')
def login():
    redirect_uri = url_for('auth', _external=True)
    return oauth.microsoft.authorize_redirect(redirect_uri)

@app.route('/auth')
def auth():
    token = oauth.microsoft.authorize_access_token()
    user_info = oauth.microsoft.parse_id_token(token)
    session['user'] = user_info
    return redirect(url_for('hello'))

@app.route('/check_orders', methods=['GET'])
@login_required
def check_orders_route():
    return check_orders()

if __name__ == '__main__':
    app.run(port=8080)