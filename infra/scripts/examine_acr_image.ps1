# Variables
$acrName = "gztempa5ladsskazurecr"  # Replace with your ACR name
$imageName = "pythonapiapptemp"     # Replace with your image name
$imageTag = "latest"                # Replace with your image tag

$imageFullName = "$acrName.azurecr.io/"+"$imageName"+":"+$imageTag
# Log in to Azure
Write-Host "Logging in to Azure..."
az login

# Log in to Azure Container Registry
Write-Host "Logging in to Azure Container Registry..."
az acr login --name $acrName

# Pull the image from ACR
Write-Host "Pulling the image from ACR..."
docker pull $imageFullName

# List local Docker images
Write-Host "Listing local Docker images..."
docker images

# Inspect the image metadata
Write-Host "Inspecting the Docker image metadata..."
docker inspect $imageFullName

# View the image layers
Write-Host "Viewing the image layers..."
docker history $imageFullName

# Run a container interactively to examine its contents
Write-Host "Running the image interactively..."
docker run -it $imageFullName /bin/bash

# Optional: Run a specific command inside the container
Write-Host "Listing files in the /app directory..."
docker run -it $imageFullName /bin/bash -c "ls -l /app"