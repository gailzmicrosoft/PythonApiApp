
//**************************************************************************/
// User input section 
//**************************************************************************/
@description('Prefix to use for all resources.')
param resourcePrefixUser string = 'pycta'

@description('Postgresql Server Admin User Name')
param postgreSqlServerAdminUser string = 'chatbot_admin'

@description('Postgresql Server Admin Password.')
@secure()
param postgreSqlServerAdminPassword string 

var databaseName = 'chatbotdb'
@description('Postgresql Database - chatbotdb - User Name')
param dbUserName string = 'chatbot_user'

@description('Postgresql Database - chatbotdb - User Password.')
@secure()
param dbUserPassword string 

// This will be user input later. For now it is hardcoded
@description('Container App ACR Username')
var containerAppUserName = 'chatbot-acr-username' 
var containerAppPassword = 'chatbot-acr-password'


/**************************************************************************/
// Resource name generation section
/**************************************************************************/
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
// Create azure database for postgresql and database user
// and store the credentials in key vault
/**************************************************************************/

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: '${resourcePrefix}pgserver'
  location: location
  sku: {
    name: 'Standard_B8ms' // available SKUs: B1ms, B2ms, B4ms, B8ms, B16ms
    tier: 'Burstable'
  }
  properties: {
    createMode: 'Default'
    administratorLogin: postgreSqlServerAdminUser
    administratorLoginPassword: postgreSqlServerAdminPassword
    version: '11'
    highAvailability: {
      mode: 'Disabled'
    }
  }
}
resource kvsPostgreSqlserverName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_server_name'
  properties: {
    value: postgresqlServer.name
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
// create a key vault secret for the postgresql server admin user and password
resource kvsPostgreSqlserverAdminUser 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_admin'
  properties: {
    value:postgreSqlServerAdminUser
  }
}
resource kvsPostgreSqlserverAdminPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_admin_password'
  properties: {
    value: postgreSqlServerAdminPassword
  }
}

// create a database in the postgresql server
resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresqlServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'English_United States.1252'
  }
}
// Create database user in the postgresql server and store the credentials in key vault
var dbName = postgresqlDatabase.name
resource postgresqlUser 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2022-12-01' = {
  parent: postgresqlServer
  name: 'chatbotdbuser'
  properties: {
    value: 'CREATE USER ${dbUserName} WITH PASSWORD \'${dbUserPassword}\'; GRANT ALL PRIVILEGES ON DATABASE ${dbName} TO ${dbUserName};'
  }
}
resource kvsPostgreSqlDbName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql_db_name'
  properties: {
    value: databaseName
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
  name: 'customchatbotcr'
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
          username: containerAppUserName 
          passwordSecretRef: 'acr-password' 
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: listCredentials(containerRegistry.id, '2023-07-01').passwords[0].value
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
            'get'
            'list'
          ]
        }
      }
    ]
  }
}




