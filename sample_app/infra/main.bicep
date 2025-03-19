//################################################################################################################################
//# Author(s): Dr. Gail Zhou & GitHub CoPiLot
//# Last Updated: March 2025
//################################################################################################################################

targetScope = 'resourceGroup'


@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'sampleapp'

@description('OpenAI model configuration')
param model object = {
  name: 'gpt-4o-mini'
  version: '2024-07-18'
  capacity: 1
}

/**************************************************************************/
// Resource name generation section
/**************************************************************************/
var resourceTokenRaw = toLower(uniqueString(subscription().id, resourceGroup().id, resourcePrefixUser))
var trimmedToken = length(resourceTokenRaw) > 8 ? substring(resourceTokenRaw, 0, 8) : resourceTokenRaw
var tokenProcessed =toLower(replace(trimmedToken, '_', ''))
var resourcePrefix = '${resourcePrefixUser}${tokenProcessed}'


var location = resourceGroup().location
//var subscriptionId = subscription().id

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



/**************************************************************************/
// Create Azure Open AI Service
/**************************************************************************/
resource openAIService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${resourcePrefix}AiService'
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName:'${resourcePrefix}AiService'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
        defaultAction: 'Allow'
    }
  }
}

/**************************************************************************/
// define Open AI models 
/**************************************************************************/
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' =  {
  parent: openAIService
  name: '${resourcePrefix}OpenAiModel'
  sku: {
    name: 'Standard'
    capacity: model.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.name
      version: model.version
      sourceAccount: openAIService.id
    }
  }
}

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
    value:'AppApiKey'
  }
}

resource kvsOpenAIServiceId 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'openai-service-id'
  properties: {
    value: openAIService.id
  }
}
resource kvsOpenAIServiceKey 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'openai-service-key'
  properties: {
    value: openAIService.listKeys().key1
  }
}
resource kvsOpenAIServiceEndpoint 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'openai-service-endpoint'
  properties: {
    value: openAIService.properties.endpoint
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

/**************************************************************************/
// Assign Key Vault Access Policy to App Service
/**************************************************************************/
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-11-01' = {
  name:'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appService.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

/**************************************************************************/
// Assign App Service Identity the Contributor role for the Resource Group
/**************************************************************************/
//var resourceGroupContributorRoleID = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var resourceGroupContributorRoleID = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource appServiceRoleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appService.id, 'Contributor')
  scope: resourceGroup()
  properties: {
    //roleDefinitionId: '${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${resourceGroupContributorRoleID}'
    roleDefinitionId: resourceGroupContributorRoleID
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

/**************************************************************************/
// Assign App Service Identity the Storage Blob Data Contributor role for the Storage Account
/**************************************************************************/
//var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobDataContributorRoleID = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource roleAssignmentStorageBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appService.id, 'StorageBlobDataContributor')
  scope: resourceGroup()
  properties: {
    //roleDefinitionId: '${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${storageBlobDataContributorRoleID}'
    roleDefinitionId: storageBlobDataContributorRoleID
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    //scope: storageAccount.id
    //scope: resourceGroup().id
  }
}

