
@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'pycta'

var trimmedResourcePrefixUser = length(resourcePrefixUser) > 5 ? substring(resourcePrefixUser, 0, 5) : resourcePrefixUser
var uniString = toLower(substring(uniqueString(subscription().id, resourceGroup().id), 0, 5))

var resourcePrefix = '${trimmedResourcePrefixUser}${uniString}'


var location = resourceGroup().location
//var resourceGroupName = resourceGroup().name
var containerRegistryName = '${resourcePrefix}acr'
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
}
// create blob service in the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

// create a container named mortgageapp in the storage account
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'chatbotappdata'
  properties: {
    publicAccess: 'None'
  }
}


/**************************************************************************/
// Create container registry and log analytics workspace
/**************************************************************************/
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  sku: {
    name: 'PerGB2018' // Available SKUs: Free, PerNode, PerGB2018, Standalone, CapacityReservation
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
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2023-05-01').primarySharedKey
      }
    }
  }
}

var containerAppUserName = 'acr-username' // Update the username to comply with naming rules
var containerAppPassword = 'acr-password' // Update the password to comply with naming rules
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
          username: containerAppUserName 
          passwordSecretRef: 'acr-password' 
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: listCredentials(containerRegistry.id, '2023-05-01').passwords[0].value
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
}


/**************************************************************************/
// Create azure database for postgresql and database user
// and store the credentials in key vault
/**************************************************************************/
// pycta6gfb6pgserver
resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: '${resourcePrefix}pgserver'
  location: location
  sku: {
    name: 'Standard_D2s_v3'
    tier: 'Burstable'
  }
  properties: {
    createMode: 'Default'
    administratorLogin: 'adminuser'
    administratorLoginPassword: 'P@ssw0rd12345!_to_be_changed_admin'
    version: '11'
    highAvailability: {
      mode: 'Disabled'
    }
  }
}
resource kvsPostgreSqlserverAdminUser 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_admin'
  properties: {
    value:postgresqlServer.properties.administratorLogin
  }
}

resource kvsPostgreSqlserverAdminPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_admin_password'
  properties: {
    value: postgresqlServer.properties.administratorLoginPassword
  }
}

// create a database in the postgresql server
resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresqlServer
  name: 'chatbotdb'
  properties: {
    charset: 'UTF8'
    collation: 'English_United States.1252'
  }
}

// create a firewall rule to allow access to the postgresql server from the container app
resource postgresqlFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
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

/**************************************************************************/
// Create database user in the postgresql server
// and store the credentials in key vault
/**************************************************************************/
var dbUserName = 'chatdbuser'
var dbUserPassword = 'P@ssw0rd12345!_to_be_changed_dbuser'
var dbName = postgresqlDatabase.name
resource postgresqlUser 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2022-12-01' = {
  parent: postgresqlServer
  name: 'chatbotdbuser'
  properties: {
    value: 'CREATE USER ${dbUserName} WITH PASSWORD \'${dbUserPassword}\'; GRANT ALL PRIVILEGES ON DATABASE ${dbName} TO ${dbUserName};'
  }
}
resource kvsPostgreSqlDbUser 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_db_user_name'
  properties: {
    value:dbUserName
  }
}
resource kvsPostgreSqlDbUserPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_db_user_password'
  properties: {
    value: dbUserPassword
  }
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
