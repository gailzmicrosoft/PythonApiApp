# Authentication with OAuth providers 

## Microsoft 

### Steps to Register Your Application with Microsoft:

1. **Register Your Application:**
   - Go to the [Azure Portal](vscode-file://vscode-app/c:/Users/gazho/AppData/Local/Programs/Microsoft VS Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html).
   - Navigate to "Azure Active Directory" > "App registrations".
   - Click "New registration".
   - Enter a name for your application.
   - Set the "Redirect URI" to `http://localhost:8080/auth`. (Select Public client / native desktop)
   - Click "Register".
2. **Obtain Client ID and Client Secret:**
   - After registering the application, go to the "Overview" page to get the "Application (client) ID".
   - Go to "Certificates & secrets" and create a new client secret. Copy the value of the client secret.

3. **Set Environment Variables:**

   Set the environment variables for `MICROSOFT_CLIENT_ID` and `MICROSOFT_CLIENT_SECRET` with the values obtained from the Azure Portal.

   **On Windows (PowerShell):**

   $Env:MICROSOFT_CLIENT_ID="your-microsoft-client-id"
   $Env:MICROSOFT_CLIENT_SECRET="your-microsoft-client-secret"

   **On macOS/Linux:**

   export MICROSOFT_CLIENT_ID="your-microsoft-client-id"
   export MICROSOFT_CLIENT_SECRET="your-microsoft-client-secret"

## Google 

1. **Ensure OAuth Client is Registered:**

   Make sure you have registered your application with Google and obtained the client ID and client secret. You can do this by following these steps:

   - Go to the [Google Cloud Console](vscode-file://vscode-app/c:/Users/gazho/AppData/Local/Programs/Microsoft VS Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html).
   - Create a new project or select an existing project.
   - Navigate to the "Credentials" page.
   - Click "Create credentials" and select "OAuth 2.0 Client IDs".
   - Configure the OAuth consent screen.
   - Create an OAuth client ID and secret. Make sure to set the authorized redirect URI to `http://localhost:8080/auth`.

2. **Set Environment Variables:**

   Set the environment variables for `YOUR_GOOGLE_CLIENT_ID` and `YOUR_GOOGLE_CLIENT_SECRET` with the values obtained from the Google Cloud Console.

   **On Windows (PowerShell):**

   $Env:GOOGLE_CLIENT_ID="your-google-client-id"
   $Env:GOOGLE_CLIENT_SECRET="your-google-client-secret"

   **On macOS/Linux:**

   export GOOGLE_CLIENT_ID="your-google-client-id"
   export GOOGLE_CLIENT_SECRET="your-google-client-secret"