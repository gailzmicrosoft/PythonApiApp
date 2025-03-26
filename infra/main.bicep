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
    value: acrResource.properties.adminUserEnabled ? acrResource.properties.loginServer : ''
  }
}
resource kvsAcrPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'acr-password'
  properties: {
    value: acrResource.listCredentials().passwords[0].value
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


// Prepare input for the ACR Task
var baseURL = 'https://raw.githubusercontent.com/gailzmicrosoft/PythonApiApp/main'
var DOCKERFILE_PATH = '${baseURL}/src/Dockerfile_apiapp'
var SOURCE_CODE_PATH = '${baseURL}/src'

resource acrTask 'Microsoft.ContainerRegistry/registries/tasks@2019-04-01' = {
  parent: acrResource
  name: 'buildAndPushImageTask'
  location: location
  properties: {
    status: 'Enabled'
    platform: {
      os: 'Linux'
      architecture: 'amd64'
    }
    agentConfiguration: {
      cpu: 2
    }
    step: {
      type: 'Docker'
      contextPath: SOURCE_CODE_PATH
      dockerFilePath: DOCKERFILE_PATH
      imageNames: [
        '${acrResource.name}.azurecr.io/${dockerImageName}:${dockerImageTag}'
      ]
      isPushEnabled: true
      noCache: false
    }
    trigger: {
      sourceTriggers: []
      baseImageTrigger: {
        status: 'Enabled'
        name: 'baseImageTrigger'
        baseImageTriggerType: 'All'
      }
    }
  }
}

resource acrTaskRun 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
  parent: acrResource
  name: 'buildAndPushTaskRun'
  location: location
  properties: {
    runRequest: {
      type: 'TaskRunRequest'
      taskId: acrTask.id
    }
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



// // test images
// var testImageName = 'nginx'
// var testImageURL = 'docker.io/library/nginx:latest'
// var dockerImageURL = '${acrResource.name}.azurecr.io/${dockerImageName}:${dockerImageTag}'

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
//       registries: [
//         {
//           server: acrResource.properties.loginServer
//           username: '@Microsoft.KeyVault/Vaults/${keyVault.name}/Secrets/acr-username'
//           passwordSecretRef: '@Microsoft.KeyVault/Vaults/${keyVault.name}/Secrets/acr-password'
//         }
//       ]
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
