# Variables
$acrName = "gailzxdnshsxdazurecr"  # Replace with your ACR name
$imageName = "pythonapiapp"
$imageTag = "latest"
$dockerfilePath = "Dockerfile_apiapp"  # Path to your Dockerfile in the src directory
$sourceCodePath = "."  # Path to your source code directory

$imageBuildAndPush = "$acrName.azurecr.io/"+"$imageName"+":"+$imageTag


# Log in to Azure
az login

# Log in to Azure Container Registry
az acr login --name $acrName

# Build the Docker image
docker build -t $imageBuildAndPush -f $dockerfilePath $sourceCodePath

# Push the Docker image to ACR
docker push $imageBuildAndPush