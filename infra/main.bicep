//################################################################################################################################
//# Author(s): Dr. Gail Zhou & GitHub CoPiLot
//# Last Updated: March 2025
//################################################################################################################################

targetScope = 'resourceGroup'
//targetScope = 'subscription'

@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'gailz'

@description('Deployment Location')
param location string = 'eastus2'

@description('Name of the resource group to be used')
param rgName string ='gaiye-test-rg'

@description('Initial valye of the x-api-key for REST API calls')
param xapikey string = 'PythonApiKey'

/**************************************************************************/
// Resource name generation section
/**************************************************************************/
var resourceTokenRaw = toLower(uniqueString(subscription().id, rgName, resourcePrefixUser))
var trimmedToken = length(resourceTokenRaw) > 8 ? substring(resourceTokenRaw, 0, 8) : resourceTokenRaw
var resourcePrefixRaw = '${resourcePrefixUser}${trimmedToken}'
var resourcePrefix =toLower(replace(resourcePrefixRaw, '_', ''))

var miName = '${resourcePrefix}MiD'

var rgId = resourceId('Microsoft.Resources/resourceGroups', rgName)


var dockerImageName = 'pythonapiapp' // This image must be built and pushed to the container registry already
var dockerImageTag = 'latest' // This image must be built and pushed to the container registry already


// test images
var dockerImageURLTest = 'docker.io/library/nginx:latest'



/**************************************************************************/
// Create Mid and Assign all necessary roles
/**************************************************************************/

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: miName
  location: location
}


//See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#owner')
resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // role definition id for owner role
}

@description('This is the ACR pull role definition')
resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // role definition for azure container registry pull 
}

@description('This is the blob storage data contributor role definition')
resource blobStorageDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // role definition for azure blob storage data contributor 
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rgId, managedIdentity.id, ownerRoleDefinition.id)
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: ownerRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

// Assign the ACR pull role to the managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rgId, managedIdentity.id, acrPullRoleDefinition.id)
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: acrPullRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

// Assign the blob storage data contributor role to the managed identity
resource blobStorageDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rgId, managedIdentity.id, blobStorageDataContributorRoleDefinition.id)
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: blobStorageDataContributorRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}


/**************************************************************************/
// Create a Key Vault
/**************************************************************************/
resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' = {
  name: '${resourcePrefix}KeyVault'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

/**************************************************************************/
// Create a storage account and a container
/**************************************************************************/
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${resourcePrefix}storage'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
// create blob service in the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}


var containerList = [ { name: 'raw' }, { name: 'processed' }, { name: 'results' } ]
resource containerListResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for container in containerList: {
  name: container.name
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}]



resource kvsStorageAccountName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'azure-storage-account-name'
  properties: {
    value: storageAccount.name
  }
}

resource kvsApiKey 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'x-api-key'
  properties: {
    value: xapikey
  }
}


/**************************************************************************/
// Azure Container Registry and Container Apps etc
/**************************************************************************/

resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${resourcePrefix}azurecr'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}


// Assign the AcrPush role to the managed identity
// The AcrPush role allows the managed identity to push images to the ACR
resource acrPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rgId, managedIdentity.id, '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush role definition ID
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalType: 'ServicePrincipal'
  }
}



//output acrAdminPassword string = acrResource.listCredentials().passwords[0].value
///output acrAdminPassword string = acrResource.listCredentials().passwords.[0].value


/**************************************************************************/
// Store ACR credentials in Key Vault
/**************************************************************************/

resource kvsAcrLoginServer 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'acr-login-server'
  properties: {
    value: acrResource.properties.loginServer
  }
}

resource kvsAcrAdminUsername 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'acr-admin-username'
  properties: {
    value: acrResource.listCredentials(acrResource.id).username
  }
}

// Not ablt to get password from ACR
// resource kvsAcrPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
//   parent: keyVault
//   name: 'acr-password'
//   properties: {
//     value: listCredentials(acrResource.id).adminPasswords[0].value
//   }
// }


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${resourcePrefix}LogAnalytics'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018' 
    }
  }
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourcePrefix}AppInsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${resourcePrefix}ContainerAppsEnv'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Prepare input for the bash script
var baseURL = 'https://raw.githubusercontent.com/gailzmicrosoft/TestCode/main/'
var DOCKERFILE_PATH = '${baseURL}src/Dockerfile'
var SOURCE_CODE_PATH = '${baseURL}src'
// ACR_NAME=$1
// IMAGE_NAME=$2
// IMAGE_TAG=$3
// DOCKERFILE_PATH=$4
// SOURCE_CODE_PATH=$5

var bashScriptArguments = '${acrResource.name} ${dockerImageName} ${dockerImageTag} ${DOCKERFILE_PATH} ${SOURCE_CODE_PATH}'

resource callBashScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind:'AzureCLI'
  name: 'runBashToBuildandPushDockerImage'
  location: location // Replace with your desired location
  identity: {
    type: 'UserAssigned'
    
    userAssignedIdentities: {
      '${managedIdentity.id}' : {}
    }
  }
  properties: {
    azCliVersion: '2.52.0'
    primaryScriptUri: '${baseURL}scripts/build_and_push_image.sh'
    arguments: bashScriptArguments
    retentionInterval: 'PT1H' // Specify the desired retention interval
    cleanupPreference:'OnSuccess'
  }
}


/**************************************************************************/
// Some environment variables for the container app
/**************************************************************************/

var appEnvironVars = [
  {
    name: 'KEY_VAULT_URI'
    value: keyVault.properties.vaultUri
  }
  {
    name: 'APPLICATIONINSIGHTS_INSTRUMENTATION_KEY'
    value: applicationInsights.properties.ConnectionString
  }
]

/**************************************************************************/
// Create a container app
/**************************************************************************/


resource containerAppsTest 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${resourcePrefix}conapp'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}' : {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      revisionSuffix: 'v1'
      containers: [
        {
          name: 'test-docker-image-name'  // must be lowercase. dash is accepted 
          image: dockerImageURLTest
          env: appEnvironVars
          resources: {
            cpu: 1
            memory: '2.0Gi'
          }
        }
      ]
    }
  }
}


// var updatedDockerImageURL = '${acrResource.id}.azurecr.io/${dockerImageName}:${dockerImageTag}'

// resource containerApps 'Microsoft.App/containerApps@2023-05-01' = {
//   name: '${resourcePrefix}conapp'
//   location: location
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${managedIdentity.id}' : {}
//     }
//   }
//   properties: {
//     environmentId: containerAppsEnvironment.id
//     configuration: {
//       ingress: {
//         external: true
//         targetPort: 80
//         traffic: [
//           {
//             latestRevision: true
//             weight: 100
//           }
//         ]
//       }
//     }
//     template: {
//       revisionSuffix: 'v1'
//       containers: [
//         {
//           name: dockerImageName
//           image: dockerImageURL
//           env: appEnvironVars
//           resources: {
//             cpu: 1
//             memory: '2.0Gi'
//           }
//         }
//       ]
//     }
//   }
// }
