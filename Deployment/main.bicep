
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
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2024-03-01').primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
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
          value: listCredentials(containerRegistry.id, '2024-03-01').passwords[0].value
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


/**************************************************************************/
// Create azure database for postgresql and database user
/**************************************************************************/
resource postgresqlServer 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: '${resourcePrefix}pgserver'
  location: location
  properties: {
    createMode: 'Default'
    administratorLogin: 'adminuser'
    administratorLoginPassword: 'P@ssw0rd1234!'
    sslEnforcement: 'Enabled'
    storageProfile: {
      storageMB: 5120
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    version: '11'
  }
}
// create a database in the postgresql server
resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  parent: postgresqlServer
  name: 'chatbotdbr'
  properties: {
    charset: 'UTF8'
    collation: 'English_United States.1252'
  }
}


// create a firewall rule to allow access to the postgresql server from the container app
resource postgresqlFirewallRule 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  parent: postgresqlServer
  name: 'AllowContainerApp'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
  dependsOn: [
    containerApp
  ]
}
// create a database user in the postgresql server
resource postgresqlUser 'Microsoft.DBforPostgreSQL/servers/databases/users@2017-12-01' = {
  parent: postgresqlDatabase
  name: 'chatbotdbuser'
  properties: {
    password: 'P@ssw0rd1234!'
    roles: [
      'db_datareader','db_datawriter'
    ]
  }
}


