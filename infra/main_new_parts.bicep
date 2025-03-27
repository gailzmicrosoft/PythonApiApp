//################################################################################################################################
//# Author(s): Dr. Gail Zhou & GitHub CoPiLot
//# Last Updated: March 2025
//################################################################################################################################

targetScope = 'resourceGroup'
//targetScope = 'subscription'

@description('Timestamp for generating unique revision suffix')
param deploymentTimestamp string = utcNow('yyyyMMddHHmm')
//param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'gztemp' // gzpython used in gaiye-python-app-rg

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
var acrName = '${resourcePrefix}azurecr'


var dockerImageName = 'chatbotapp' // This image must be built and pushed to the container registry already
var dockerImageTag = 'latest' // This image must be built and pushed to the container registry already


var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var acrPushRole = resourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
var ownerRole = resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var blobDataContributorRole = resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

/**************************************************************************/
// Create Mid and Assign all necessary roles
/**************************************************************************/
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: miName
  location: location
}

// // Assign the owner role to the managed identity
// @description('This allows the managed identity of the container app to access the resource group')
// resource assignMidOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id, managedIdentity.id, ownerRole)
//   properties: {
//     roleDefinitionId: ownerRole
//     principalId: managedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

// // Assign the blob storage data contributor role to the managed identity
// @description('This allows the managed identity of the container app to access the storage account')
// resource assignMidToStorageDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id, managedIdentity.id, blobDataContributorRole)
//   properties: {
//     roleDefinitionId: blobDataContributorRole
//     principalId: managedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }


// // Assign the AcrPull role to the managed identity
// @description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
// resource assignMidToAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id, managedIdentity.id, acrPullRole)
//   properties: {
//     roleDefinitionId: acrPullRole
//     principalId: managedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

// // Assign the AcrPush role to the managed identity
// @description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
// resource assignMidToAcrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id, managedIdentity.id, acrPushRole)
//   properties: {
//     roleDefinitionId: acrPushRole
//     principalId: managedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

//***************************************************************************/
// Use Below code if are reusing prior deployments 
/***************************************************************************/
@description('This allows the managed identity of the container app to access the resource group')
resource assignMidOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: guid(resourceGroup().id, managedIdentity.id, ownerRole)
}
@description('This allows the managed identity of the container app to access the storage account')
resource assignMidToStorageDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: guid(resourceGroup().id, managedIdentity.id, blobDataContributorRole)
}
@description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
resource assignMidToAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: guid(resourceGroup().id, managedIdentity.id, acrPullRole)
}

@description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
resource assignMidToAcrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: guid(resourceGroup().id, managedIdentity.id, acrPushRole)
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
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          secrets: [
            'get'
            'set'
          ]
        }
      }
    ]
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


var blobContainerList = [ { name: 'raw' }, { name: 'processed' }, { name: 'results' } ]
resource blobContainerListResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for blobContainer in blobContainerList: {
  name: blobContainer.name
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
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

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
resource kvsAcrUsername 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'acr-username'
  properties: {
    value: acrName
  }
}
resource kvsAcrPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'acr-password'
  properties: {
    value: acrResource.listCredentials().passwords[0].value
  }
}



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


// // Prepare input for the ACR Task
// var baseURL = 'https://raw.githubusercontent.com/gailzmicrosoft/PythonApiApp/main'
// var DOCKERFILE_PATH = '${baseURL}/src/Dockerfile_apiapp'
// var SOURCE_CODE_PATH = '${baseURL}/src'

// resource acrTask 'Microsoft.ContainerRegistry/registries/tasks@2019-04-01' = {
//   parent: acrResource
//   name: 'buildAndPushImageTask'
//   location: location
//   properties: {
//     status: 'Enabled'
//     platform: {
//       os: 'Linux'
//       architecture: 'amd64'
//     }
//     agentConfiguration: {
//       cpu: 2
//     }
//     step: {
//       type: 'Docker'
//       contextPath: SOURCE_CODE_PATH
//       dockerFilePath: DOCKERFILE_PATH
//       imageNames: [
//         '${acrResource.name}.azurecr.io/${dockerImageName}:${dockerImageTag}'
//       ]
//       isPushEnabled: true
//       noCache: false
//     }
//     trigger: {
//       sourceTriggers: []
//       baseImageTrigger: {
//         status: 'Enabled'
//         name: 'baseImageTrigger'
//         baseImageTriggerType: 'All'
//       }
//     }
//   }
// }

// resource acrTaskRun 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
//   parent: acrResource
//   name: 'buildAndPushTaskRun'
//   location: location
//   properties: {
//     runRequest: {
//       type: 'TaskRunRequest'
//       taskId: acrTask.id
//     }
//   }
// }




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



// test images
var testImageName = 'pythonapiapptemp'
var testImageTag = 'latest' // This image must be built and pushed to the container registry already
//var testImageURL = 'docker.io/library/nginx:latest'
var acrServerFQN = '${acrResource.name}.azurecr.io'
var dockerImageURL = '${acrResource.name}.azurecr.io/${dockerImageName}:${dockerImageTag}'
var testDockerImageURL = '${acrResource.name}.azurecr.io/${testImageName}:${testImageTag}'

resource containerApps 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${resourcePrefix}cntrapp'
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
      secrets: [
        {
          name: 'keyvault-uri'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'x-api-key'
          value: kvsApiKey.properties.secretUriWithVersion
        }
      ]
      ingress: {
        external: true
        targetPort: 8080
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: acrServerFQN
          identity: managedIdentity.id
          // Username and passsword are not needed if using managed identity
          // username: kvsAcrUsername.properties.value
          // passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      //revisionMode: 'Multiple'
      revisionSuffix: 'v1-${deploymentTimestamp}' // Generate a unique revision suffix using the current timestamp
      containers: [
        {
          name: testImageName
          image: testDockerImageURL
          env: appEnvironVars
          resources: {
            cpu: 1
            memory: '2.0Gi'
          }
        }
        // {
        //   name: 'nginx'
        //   image: 'docker.io/library/nginx:latest'
        //   env: appEnvironVars
        //   resources: {
        //     cpu: 1
        //     memory: '2.0Gi'
        //   }
        // }
        // {
        //   name: dockerImageName
        //   image: dockerImageURL
        //   env: appEnvironVars
        //   resources: {
        //     cpu: 1
        //     memory: '2.0Gi'
        //   }
        // }
      ]
    }
  }
}
