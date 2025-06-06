#.\build_and_push_image.ps1       
# Variables
#$acrName = "gailzxdnshsxdazurecr"  # Replace with your ACR name
$acrName = "gztempa5ladsskazurecr" 
$imageName = "pythonapiapptemp"
$imageTag = "latest"
$dockerfilePath = "../../src/Dockerfile_apiapp"  # Path to your Dockerfile in the src directory
$sourceCodePath = "../../src"  # Path to your source code directory

$imageFullName = "$acrName.azurecr.io/"+"$imageName"+":"+$imageTag

# Log in to Azure
az login

# Log in to Azure Container Registry
az acr login --name $acrName

# Build the Docker image
docker build -t $imageFullName -f $dockerfilePath $sourceCodePath

# Push the Docker image to ACR
docker push $imageFullName