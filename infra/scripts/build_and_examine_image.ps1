#.\build_and_push_image.ps1       
# Variables
#$acrName = "gailzxdnshsxdazurecr"  # Replace with your ACR name
$acrName = "gztempa5ladsskazurecr" 
$imageName = "pythonapiapptemp"
$imageTag = "latest"
$dockerfilePath = "../../src/Dockerfile_apiapp"  # Path to your Dockerfile in the src directory
$sourceCodePath = "../../src"  # Path to your source code directory

$imageFullName = "$acrName.azurecr.io/"+"$imageName"+":"+$imageTag


# Build the Docker image
docker build -t $imageFullName -f $dockerfilePath $sourceCodePath

docker images

docker inspect $imageFullName

docker history $imageFullName

docker run -it $imageFullName /bin/bash
docker run -it $imageFullName /bin/bash -c "ls -l /app"
