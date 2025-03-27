#### **Set Up Azure Credentials in GitHub Secrets**

1. Go to your GitHub repository.

2. Navigate to **Settings > Secrets and variables > Actions > New repository secret**.

3. Add the following secrets:

   - ```
     AZURE_CREDENTIALS
     ```

     : JSON output of an Azure service principal for authentication.

     - Create a service principal using the Azure CLI:

       az ad sp create-for-rbac --name "github-actions" --sdk-auth --role contributor --scopes /subscriptions/<subscription-id>

       Replace

        

       ```
       <subscription-id>
       ```

        

       with your Azure subscription ID.

     - Copy the JSON output and save it as the `AZURE_CREDENTIALS` secret.

   - `ACR_NAME`: Your Azure Container Registry name (e.g., `gztempa5ladsskazurecr`).

------

#### 2. **Create a GitHub Actions Workflow**

Create a file named `.github/workflows/build-and-deploy.yml` in your repository.

name: Build and Deploy to Azure

on:
  push:
    branches:
      - main  # Trigger workflow on push to the main branch

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
    
    - name: Log in to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Log in to Azure Container Registry
      run: |
        az acr login --name ${{ secrets.ACR_NAME }}
    
    - name: Build and Push Docker Image
      run: |
        docker build -t ${{ secrets.ACR_NAME }}.azurecr.io/pythonapiapptemp:latest .
        docker push ${{ secrets.ACR_NAME }}.azurecr.io/pythonapiapptemp:latest

  deploy-to-containerapp:
    runs-on: ubuntu-latest
    needs: build-and-push  # Run this job after the build-and-push job

    steps:
    - name: Log in to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy to Azure Container App
      run: |
        az containerapp update \
          --name <container-app-name> \
          --resource-group <resource-group-name> \
          --image ${{ secrets.ACR_NAME }}.azurecr.io/pythonapiapptemp:latest

### Explanation of the Workflow

1. **Triggers:**

   - The workflow is triggered when you push changes to the `main` branch.

2. **Job 1: Build and Push Docker Image**

   - **Checkout Code:** Pulls the code from the repository.
   - **Log in to Azure:** Authenticates with Azure using the `AZURE_CREDENTIALS` secret.
   - **Log in to ACR:** Logs into Azure Container Registry.
   - **Build and Push Docker Image:** Builds the Docker image and pushes it to ACR.

3. **Job 2: Deploy to Azure Container App**

   - **Log in to Azure:** Authenticates with Azure.
   - **Deploy to Container App:** Updates the container app to use the new Docker image.

   

### Best Practices

1. **Use Versioned Tags:**

   - Instead of using `latest`, use versioned tags (e.g., `v1`, `v2`) for better traceability.

2. **Test Locally:**

   - Test your Docker image locally before pushing it to ACR.

3. **Monitor Workflows:**

   - Use the **Actions** tab in GitHub to monitor workflow runs and debug issues.

4. **Secure Secrets:**

   - Store sensitive information like Azure credentials in GitHub Secrets.

5. **Automate Infrastructure Deployment:**

   - Use your `main.bicep` file to provision infrastructure (e.g., ACR, Container Apps) and GitHub Actions for CI/CD.

6. ### Summary

   - **GitHub Actions Concepts:**
     - Workflows automate tasks like building, testing, and deploying code.
     - Jobs and steps define the workflow's structure.
     - Secrets securely store sensitive information.
   - **How to Use GitHub Actions:**
     - Set up Azure credentials in GitHub Secrets.
     - Create a workflow to build and push Docker images to ACR.
     - Deploy the updated image to Azure Container Apps.
   - **Integration with `main.bicep`:**
     - Use `main.bicep` to provision infrastructure.
     - Use GitHub Actions to automate the build and deployment process.

   This approach ensures a clean separation of concerns and enables a robust CI/CD pipeline for your application.