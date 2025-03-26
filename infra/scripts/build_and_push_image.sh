#!/bin/bash

# Variables
ACR_NAME=$1
IMAGE_NAME=$2
IMAGE_TAG=$3
DOCKERFILE_PATH=$4
SOURCE_CODE_PATH=$5

# Log in to Azure Container Registry using managed identity
az acr login --name $ACR_NAME

# Build the Docker image
docker build -t $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG -f $DOCKERFILE_PATH $SOURCE_CODE_PATH

# Push the Docker image to ACR
docker push $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG