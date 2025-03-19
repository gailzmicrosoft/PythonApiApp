
//**************************************************************************/
// User input section 
//**************************************************************************/
@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'pycta'


// This will be user input later. For now it is hardcoded
@description('Container App ACR Username')
var containerAppUserName = 'chatbot-acr-username' 
var containerAppPassword = 'chatbot-acr-password'


/**************************************************************************/
// Resource name generation section
/**************************************************************************/
var trimmedResourcePrefixUser = length(resourcePrefixUser) > 5 ? substring(resourcePrefixUser, 0, 5) : resourcePrefixUser
var uniString = toLower(substring(uniqueString(subscription().id, resourceGroup().id), 0, 5))

var resourcePrefixRaw = '${trimmedResourcePrefixUser}${uniString}'
var resourcePrefix = toLower(resourcePrefixRaw)

var location = resourceGroup().location
var containerRegistryName = 'customchatbotcr' // use existing container registry
var containerRegistryUserName = 'customchatbotcr' // use existing container registry user name. 
var containerAppEnvName = '${resourcePrefix}env'
var containerAppName = '${resourcePrefix}app'
var logAnalyticsWorkspaceName = '${resourcePrefix}law'
var storageAccountNameStarter = '${resourcePrefix}storage'
var storageAccountName = toLower(replace(storageAccountNameStarter, '-', ''))


/**************************************************************************/
// Create a Key Vault and store the API key in it
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
resource kvsApiKey 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'x-api-key'
  properties: {
    value:'ChatbotApiKey'
  }
}


/**************************************************************************/
// Create a storage account and a container
/**************************************************************************/
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  dependsOn: [
    keyVault
  ]
}
// create blob service in the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  dependsOn: [
    keyVault
  ]
}

// create a container named mortgageapp in the storage account
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'chatbotappdata'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    keyVault
  ]
}


/**************************************************************************/
// Create container registry and log analytics workspace
/**************************************************************************/
// resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
//   name: containerRegistryName
//   location: location
//   sku: {
//     name: 'Basic'
//   }
//   properties: {
//     adminUserEnabled: true
//   }
// }



/**************************************************************************/
// Use existing container registry and log analytics workspace
/**************************************************************************/
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
  scope: resourceGroup('custom-chatbot-rg')
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: {
    displayName: 'Log Analytics Workspace'
  }
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
  dependsOn: [
    keyVault
  ]
}


/**************************************************************************/
// Create container app environment and container app
/**************************************************************************/
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-10-01').primarySharedKey
      }
    }
  }
  dependsOn: [
    keyVault
  ]
}
resource kvsContainerAppEnvName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'containerAppEnvName'
  properties: {
    value: containerAppEnvName
  }
}

resource kvsContainerAppUserName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: containerAppUserName
  properties: {
    value: containerAppUserName
  }
}
resource kvsContainerAppPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: containerAppPassword
  properties: {
    value: containerAppPassword
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          username: containerRegistryUserName
          passwordSecretRef: 'acr-password' // Updated to use Key Vault secret for ACR password
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value:containerRegistry.listCredentials().passwords[0].value // Use the ACR password from the container registry
          //value: listCredentials(containerRegistry.id, '2023-07-01').passwords[0].value // this does not work
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: '${containerRegistryName}.azurecr.io/pythonapiapp:v1'
          resources: {
            cpu: 1
            memory: '2.0Gi'
          }
        }
      ]
    }
  }
  dependsOn: [
    blobContainer
    keyVault
  ]
}


/**************************************************************************/
// Assign container app the role of blob data contributor to the storage account
/**************************************************************************/
resource containerAppIdentity 'Microsoft.App/containerApps@2023-05-01' existing = {
  name: containerAppName
}

// assign the role of blob data contributor to the container app
resource blobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, containerAppIdentity.id, 'BlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382b6b1f')
    principalId: containerAppIdentity.identity.principalId
  }
}


/**************************************************************************/
// Assign Key Vault Access Policy to the container app
/**************************************************************************/
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name:'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: containerApp.identity.principalId
        permissions: {
          secrets: [
            'create'
            'get'
            'list'
          ]
        }
      }
    ]
  }
}




