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

@description('Name of the Azure OpenAI Service')
param aiServicesName string = 'gailzopenaiservice'


param deploymentType string = 'GlobalStandard' // 'Standard' // 'Basic
param gptModelName string = 'gpt-4o-mini' // 'gpt-4o' // 'gpt-4o-turbo' // 'gpt-4o-turbo-16k' // 'gpt-4o-turbo-32k'
param azureOpenAIApiVersion string = '2024-07-18' // '2023-05-15' // '2023-05-01' // '2023-03-15-preview' // '2023-02-01-preview'
param gptDeploymentCapacity int = 1 // 1 // 2 // 3 // //https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits
param embeddingModel string = 'text-embedding-ada-002' // 'text-embedding-ada-002-v2' // 'text-embedding-ada-003' // 'text-embedding-ada-003-v2'
param embeddingDeploymentCapacity int =1 // 1 // 2 // 3 // 4 // 5


var aiModelDeployments = [
  {
    name: gptModelName
    model: gptModelName
    sku: {
      name: deploymentType
      capacity: gptDeploymentCapacity
    }
    raiPolicyName: 'Microsoft.Default'
  }
  {
    name: embeddingModel
    model: embeddingModel
    sku: {
      name: 'Standard'
      capacity: embeddingDeploymentCapacity
    }
    raiPolicyName: 'Microsoft.Default'
  }
]

/**************************************************************************/
// Resource name generation section
/**************************************************************************/
var resourceTokenRaw = toLower(uniqueString(subscription().id, rgName, resourcePrefixUser))
var trimmedToken = length(resourceTokenRaw) > 8 ? substring(resourceTokenRaw, 0, 8) : resourceTokenRaw
var resourcePrefixRaw = '${resourcePrefixUser}${trimmedToken}'
var resourcePrefix =toLower(replace(resourcePrefixRaw, '_', ''))

var miName = '${resourcePrefix}MiD'

var rgId = resourceId('Microsoft.Resources/resourceGroups', rgName)
var aiSearchName = '${resourcePrefix}-aisearch'

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
  name: '${toLower(resourcePrefix)}storage'
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
  name: '${resourcePrefix}${container.name}container'
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
    value:xapikey
  }
}


/**************************************************************************/
// App Service Plan and App Service
/**************************************************************************/
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${resourcePrefix}AppServicePlan'
  location: location
  kind: 'linux'
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    size: 'P1v3'
    family: 'P'
    capacity: 1
  }
  properties: {
    perSiteScaling: false
    reserved: true
  }

}


resource appService 'Microsoft.Web/sites@2024-04-01' = {
  name: '${resourcePrefix}AppService'
  location: location
  kind: 'app'
  tags:{
    displayName: 'Mortgage Advisor'
    environment: 'test'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    endToEndEncryptionEnabled:false
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11.9'
      appSettings: [
        {
          name:'ENVIRONMENT'
          value:'Release'
        }
        {
          name:'KEY_VAULT_URI'
          value: keyVault.properties.vaultUri
        }
      ]
      healthCheckPath:'/health' // Add this line to enable health check
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}



// /**************************************************************************/
// // Create AI Resources
// /**************************************************************************/
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    customSubDomainName: aiServicesName
    apiProperties: {
      statisticsEnabled: false
    }
  }
}

@batchSize(1)
resource aiServicesDeployments 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for aiModeldeployment in aiModelDeployments: {
  parent: aiServices //aiServices_m
  name: aiModeldeployment.name
  properties: {
    model: {
      format: 'OpenAI'
      name: aiModeldeployment.model
    }
    raiPolicyName: aiModeldeployment.raiPolicyName
  }
  sku:{
    name: aiModeldeployment.sku.name
    capacity: aiModeldeployment.sku.capacity
  }
}]

resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: aiSearchName
  location: location
  sku: {
    name: 'basic'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    networkRuleSet: {
      ipRules: []
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      apiKeyOnly: {}
    }
    semanticSearch: 'free'
  }
}



resource tenantIdEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'TENANT-ID'
  properties: {
    value: subscription().tenantId
  }
}


resource azureOpenAIApiKeyEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-OPENAI-KEY'
  properties: {
    value: aiServices.listKeys().key1 
  }
}

resource azureOpenAIDeploymentModel 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-OPEN-AI-DEPLOYMENT-MODEL'
  properties: {
    value: gptModelName
  }
}

resource azureOpenAIApiVersionEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-OPENAI-PREVIEW-API-VERSION'
  properties: {
    value: azureOpenAIApiVersion 
  }
}

resource azureOpenAIEndpointEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-OPENAI-ENDPOINT'
  properties: {
    value: aiServices.properties.endpoint //aiServices_m.properties.endpoint
  }
}

resource azureSearchAdminKeyEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-SEARCH-KEY'
  properties: {
    value: aiSearch.listAdminKeys().primaryKey
  }
}

resource azureSearchServiceEndpointEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-SEARCH-ENDPOINT'
  properties: {
    value: 'https://${aiSearch.name}.search.windows.net'
  }
}

resource azureSearchServiceEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-SEARCH-SERVICE'
  properties: {
    value: aiSearch.name
  }
}

resource azureSearchIndexEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-SEARCH-INDEX'
  properties: {
    value: 'transcripts_index'
  }
}

resource cogServiceEndpointEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'COG-SERVICES-ENDPOINT'
  properties: {
    value: aiServices.properties.endpoint
  }
}

resource cogServiceKeyEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'COG-SERVICES-KEY'
  properties: {
    value: aiServices.listKeys().key1
  }
}

resource cogServiceNameEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'COG-SERVICES-NAME'
  properties: {
    value: aiServicesName
  }
}

resource azureSubscriptionIdEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-SUBSCRIPTION-ID'
  properties: {
    value: subscription().subscriptionId
  }
}

resource resourceGroupNameEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-RESOURCE-GROUP'
  properties: {
    value: resourceGroup().name
  }
}

resource azureLocatioEntry 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'AZURE-LOCATION'
  properties: {
    value: location
  }
}
