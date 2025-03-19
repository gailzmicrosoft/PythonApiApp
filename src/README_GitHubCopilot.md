1. # Quick Start-Up Plan for Azure Container Apps

   ## Prerequisites
   1. **Azure Subscription**: Ensure you have an active Azure subscription.
   2. **Azure CLI**: Install the Azure CLI on your local machine. You can download it from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
   3. **Docker**: Install Docker on your local machine. You can download it from [here](https://www.docker.com/products/docker-desktop).

   ## Steps

   1. **Login to Azure**
       ```sh
       az login
       ```

   2. **Create a Resource Group**
       ```sh
       az group create --name myResourceGroup --location eastus
       ```

   3. **Create a Container Registry**
       ```sh
       az acr create --resource-group myResourceGroup --name myContainerRegistry --sku Basic
       ```

   4. **Login to the Container Registry**
       ```sh
       az acr login --name myContainerRegistry
       ```

   5. **Build and Push Your Docker Image**
       - Create a Dockerfile for your application if you don't have one.
       - Build the Docker image:
           ```sh
           docker build -t myContainerRegistry.azurecr.io/myapp:v1 .
           ```
       - Push the Docker image to the Azure Container Registry:
           ```sh
           docker push myContainerRegistry.azurecr.io/myapp:v1
           ```

   6. **Create a Log Analytics Workspace**
       ```sh
       az monitor log-analytics workspace create --resource-group myResourceGroup --workspace-name myLogAnalyticsWorkspace
       ```

   7. **Create a Container App Environment**
       ```sh
       az containerapp env create --name myContainerAppEnv --resource-group myResourceGroup --logs-workspace-id $(az monitor log-analytics workspace show --resource-group myResourceGroup --workspace-name myLogAnalyticsWorkspace --query customerId --output tsv) --logs-workspace-key $(az monitor log-analytics workspace get-shared-keys --resource-group myResourceGroup --workspace-name myLogAnalyticsWorkspace --query primarySharedKey --output tsv) --location eastus
       ```

   8. **Create a Container App**
       ```sh
       az containerapp create --name myContainerApp --resource-group myResourceGroup --environment myContainerAppEnv --image myContainerRegistry.azurecr.io/myapp:v1 --target-port 80 --ingress 'external' --registry-server myContainerRegistry.azurecr.io --registry-username $(az acr credential show --name myContainerRegistry --query username --output tsv) --registry-password $(az acr credential show --name myContainerRegistry --query passwords[0].value --output tsv)
       ```

   9. **Verify the Deployment**
       - Get the URL of the deployed container app:
           ```sh
           az containerapp show --name myContainerApp --resource-group myResourceGroup --query properties.configuration.ingress.fqdn --output tsv
           ```
       - Open the URL in your browser to verify that your application is running.

   ## Summary of Actions
   1. Install prerequisites (Azure CLI, Docker).
   2. Login to Azure.
   3. Create a resource group.
   4. Create and login to a container registry.
   5. Build and push your Docker image.
   6. Create a Log Analytics workspace.
   7. Create a Container App environment.
   8. Create and deploy a Container App.
   9. Verify the deployment.