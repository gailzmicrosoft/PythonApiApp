#!/bin/bash
# chmod +x push-image-to-acr.sh
# ./push-image-to-acr.sh

# Log in to Azure
echo "Logging in to Azure..."
az login

# Default values
default_resource_group="custom-chatbot-rg"
default_container_registry="customchatbotcr"
default_docker_image_name="pythonapiapp"
version="latest"  # Corrected assignment of the version variable

# Prompt for the Resource Group name with a default value
read -p "Enter the name of the Resource Group [$default_resource_group]: " resource_group
resource_group=${resource_group:-$default_resource_group}

# Prompt for the Azure Container Registry name with a default value
read -p "Enter the name of the Azure Container Registry [$default_container_registry]: " container_registry
container_registry=${container_registry:-$default_container_registry}

# Prompt for the Docker image name with a default value
read -p "Enter the name of the Docker image [$default_docker_image_name]: " docker_image_name
docker_image_name=${docker_image_name:-$default_docker_image_name}

# Check if the ACR exists
acr_exists=$(az acr check-name --name $container_registry --query nameAvailable --output tsv)
echo "Azure Container Registry check: $container_registry exists: $acr_exists"

if [ "$acr_exists" == "false" ]; then
    echo "Using existing Azure Container Registry: $container_registry"
else
    echo "Azure Container Registry not found: $container_registry"
    exit 1
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

# Tag the Docker image
echo "Tagging Docker image..."
docker tag $docker_image_name $container_registry.azurecr.io/$docker_image_name:$version

# Push the Docker image to ACR
echo "Pushing Docker image to Azure Container Registry..."
docker push $container_registry.azurecr.io/$docker_image_name:$version
# Check if the push was successful
if [ $? -eq 0 ]; then
    echo "Docker image pushed successfully to Azure Container Registry: $container_registry"
else
    echo "Failed to push Docker image to Azure Container Registry: $container_registry"
    exit 1
fi

# Log out from Azure
echo "Logging out from Azure..."
az logout
echo "Script completed."