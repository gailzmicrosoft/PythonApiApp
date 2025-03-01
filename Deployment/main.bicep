
@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'pycta'

var trimmedResourcePrefixUser = length(resourcePrefixUser) > 5 ? substring(resourcePrefixUser, 0, 5) : resourcePrefixUser
var uniString = toLower(substring(uniqueString(subscription().id, resourceGroup().id), 0, 5))

var resourcePrefix = '${trimmedResourcePrefixUser}${uniString}'


var location = resourceGroup().location
var resourceGroupName = resourceGroup().name
var containerRegistryName = '${resourcePrefix}acr'
var containerAppEnvName = '${resourcePrefix}env'
var containerAppName = '${resourcePrefix}app'
var logAnalyticsWorkspaceName = '${resourcePrefix}law'
var storageAccountNameStarter = '${resourcePrefix}storage'
var storageAccountName = toLower(replace(storageAccountNameStarter, '-', ''))



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
}
// create blob service in the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

// create a container named mortgageapp in the storage account
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'mortgageapp'
  properties: {
    publicAccess: 'None'
  }
}



/**************************************************************************/
// Create container registry and log analytics workspace
/**************************************************************************/
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  sku: {
    name: 'PerGB2018'
  }
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: '2.0'
      dailyQuotaGb: 1
      maxDailyQuotaGb: 5
      maxRetentionLimitInDays: 730
    }
  }
}




/**************************************************************************/
// Create container app environment and container app
/**************************************************************************/
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-06-01').primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2021-03-01' = {
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
          username: containerRegistry.properties.adminUser.username
          passwordSecretRef: 'acrPassword'
        }
      ]
      secrets: [
        {
          name: 'acrPassword'
          value: listCredentials(containerRegistry.id, '2021-06-01-preview').passwords[0].value
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
            memory: '1.0Gi'
          }
        }
      ]
    }
  }
}
