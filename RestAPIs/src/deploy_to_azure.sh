#!/bin/bash
# chmod +x deploy_to_azure.sh
# ./deploy_to_azure.sh

# Log in to Azure
echo "Logging in to Azure..."
az login

# Ask the user if they want to use an existing resource group or create a new one
read -p "Do you want to use an existing resource group? (y/n): " use_existing_rg

if [ "$use_existing_rg" == "y" ]; then
    # Prompt for the existing resource group name
    read -p "Enter the name of the existing resource group: " resource_group

    # Get the location of the existing resource group
    location=$(az group show --name $resource_group --query location --output tsv)
    echo "Using existing resource group: $resource_group in location: $location"
else
    # Prompt for the new resource group name and location
    read -p "Enter the name of the new resource group: " resource_group
    read -p "Enter the location for the new resource group (e.g., eastus): " location

    # Create a new resource group
    echo "Creating resource group..."
    az group create --name $resource_group --location $location
fi

# Prompt for the Azure Container Registry name
read -p "Enter the name of the Azure Container Registry: " container_registry

# Check if the ACR exists
acr_exists=$(az acr check-name --name $container_registry --query nameAvailable --output tsv)
echo "Azure Container Registry check: $container_registry exists: $acr_exists"

if [ "$acr_exists" == "false" ]; then
    echo "Using existing Azure Container Registry: $container_registry"
else
    echo "Creating Azure Container Registry: $container_registry"
    az acr create --resource-group $resource_group --name $container_registry --sku Basic
fi

# Check if admin user is enabled for the Azure Container Registry
admin_user_enabled=$(az acr show --name $container_registry --query "adminUserEnabled" --output tsv)
if [ "$admin_user_enabled" == "false" ]; then
    echo "Enabling admin user for Azure Container Registry..."
    az acr update --name $container_registry --admin-enabled true
fi

# Log in to the Azure Container Registry
echo "Logging in to Azure Container Registry..."
az acr login --name $container_registry

# Change to the directory containing the Dockerfile
cd /c:/Repos/PythonApiApp/RestAPIs/src

# Build the Docker image
echo "Building Docker image..."
docker build -t pythonapiapp .

# Tag the Docker image
echo "Tagging Docker image..."
docker tag pythonapiapp $container_registry.azurecr.io/pythonapiapp:v1

# Push the Docker image to ACR
echo "Pushing Docker image to Azure Container Registry..."
docker push $container_registry.azurecr.io/pythonapiapp:v1

# Prompt for the Azure Container App Environment name
read -p "Enter the name of the Azure Container App Environment: " container_app_env

# Check if the Log Analytics Workspace exists
log_analytics_workspace=$(az monitor log-analytics workspace list --resource-group $resource_group --query "[0].name" --output tsv)

if [ -z "$log_analytics_workspace" ]; then
    # Prompt for the Log Analytics Workspace name
    read -p "Enter the name of the Log Analytics Workspace: " log_analytics_workspace

    # Create a new Log Analytics Workspace
    echo "Creating Log Analytics Workspace..."
    az monitor log-analytics workspace create --resource-group $resource_group --workspace-name $log_analytics_workspace --location $location
else
    echo "Using existing Log Analytics Workspace: $log_analytics_workspace"
fi

# Create an Azure Container App Environment
echo "Creating Azure Container App Environment..."
az containerapp env create --name $container_app_env --resource-group $resource_group --location $location --logs-workspace-id $(az monitor log-analytics workspace show --resource-group $resource_group --workspace-name $log_analytics_workspace --query customerId --output tsv) --logs-workspace-key $(az monitor log-analytics workspace get-shared-keys --resource-group $resource_group --workspace-name $log_analytics_workspace --query primarySharedKey --output tsv)

# Check if the environment was created successfully
env_exists=$(az containerapp env show --name $container_app_env --resource-group $resource_group --query name --output tsv)

if [ -z "$env_exists" ]; then
    echo "Failed to create Azure Container App Environment: $container_app_env"
    exit 1
fi

# Prompt for the Azure Container App name
read -p "Enter the name of the Azure Container App: " container_app_name

# Retrieve ACR credentials
acr_username=$(az acr credential show --name $container_registry --query "username" --output tsv)
acr_password=$(az acr credential show --name $container_registry --query "passwords[0].value" --output tsv)

# Create the Azure Container App

echo "Creating Azure Container App..."
az containerapp create --name $container_app_name --resource-group $resource_group --environment $container_app_env --image $container_registry.azurecr.io/pythonapiapp:v1 --target-port 8080 --ingress 'external' --registry-server $container_registry.azurecr.io --registry-username $acr_username --registry-password $acr_password --query properties.configuration.ingress.fqdn

# Output the FQDN of the deployed app
echo "Deployment complete. You can access your app at the following URL:"
az containerapp show --name $container_app_name --resource-group $resource_group --query properties.configuration.ingress.fqdn -o tsv
