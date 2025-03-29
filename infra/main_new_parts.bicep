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
param resourcePrefixUser string = 'gzbicep' // 

@description('Deployment Location')
param location string = 'eastus2'

@description('Initial valye of the x-api-key for REST API calls')
param xapikey string = 'PythonApiKey'

@description('PostgreSQL Server Admin Login')
param postgreServerAdminLogin string = 'ChatbotAdmin'

@description('PostgreSQL Server Admin Password')
@secure()
param postgreServerAdminPassword string = 'InitialPassword_to_be_changed_12345' // This should be stored in Key Vault


/**************************************************************************/
// Resource name generation section
/**************************************************************************/
var resourceTokenRaw = toLower(uniqueString(subscription().id, resourceGroup().name, resourcePrefixUser))
var trimmedToken = length(resourceTokenRaw) > 4 ? substring(resourceTokenRaw, 0, 4) : resourceTokenRaw
var resourcePrefixRaw = '${resourcePrefixUser}${trimmedToken}'
var resourcePrefixLong =toLower(replace(resourcePrefixRaw, '_', ''))
var resourcePrefix = length(resourcePrefixLong) > 8 ? substring(resourcePrefixLong, 0, 8) : resourcePrefixLong

var miName = '${resourcePrefix}MiD'
var acrName = '${resourcePrefix}azurecr'
var postreSQLServerName = '${resourcePrefix}pgserver'


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

output midObjectId string = managedIdentity.properties.principalId

// Assign the owner role to the managed identity
@description('This allows the managed identity of the container app to access the resource group')
resource assignMidOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, ownerRole)
  properties: {
    roleDefinitionId: ownerRole
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign the blob storage data contributor role to the managed identity
@description('This allows the managed identity of the container app to access the storage account')
resource assignMidToStorageDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, blobDataContributorRole)
  properties: {
    roleDefinitionId: blobDataContributorRole
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


// Assign the AcrPull role to the managed identity
@description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
resource assignMidToAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign the AcrPush role to the managed identity
@description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
resource assignMidToAcrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, acrPushRole)
  properties: {
    roleDefinitionId: acrPushRole
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
output managedIdentityId string = managedIdentity.id
output managedIdentityName string = managedIdentity.name

/**************************************************************************/
// Create a Key Vault
/**************************************************************************/
resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' = {
  name: '${resourcePrefix}KV'
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



resource kvsManagedIdentityName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'mid-name'
  properties: {
    value: managedIdentity.name
  }
}

resource kvsManagedIdentityId 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'mid-id'
  properties: {
    value: managedIdentity.id
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

// /**************************************************************************/
// // create azure postgres database resources 
// /**************************************************************************/
// // postgres db is automatically created when the flexible server is created
// resource postgreSqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
//   name: postreSQLServerName
//   location: location
//   identity: {
//     type: 'SystemAssigned, UserAssigned' // Enable both System-Assigned and User-Assigned Managed Identities
//     userAssignedIdentities: {
//       '${managedIdentity.id}': {} // Reference the User-Assigned Managed Identity
//     }
//   }
//   sku: {
//     name: 'Standard_B4ms' // available SKUs: B1ms, B2ms, B4ms, B8ms, B16ms
//     tier: 'Burstable'
//   }
//   properties: {
//     version: '11' // 11, 12, 13, 14
//     administratorLogin: postgreServerAdminLogin
//     administratorLoginPassword: postgreServerAdminPassword // This should be stored in Key Vault
//     authConfig: {
//       tenantId: subscription().tenantId
//       activeDirectoryAuth: 'Enabled'
//       passwordAuth: 'Enabled'
//     }
//     highAvailability: {
//       mode: 'Disabled'
//     }
//     storage: {
//       storageSizeGB: 32
//     }
//     backup: {
//       backupRetentionDays: 7
//       geoRedundantBackup: 'Disabled'
//     }
//     network: {
//       publicNetworkAccess: 'Enabled'
//     }
//     availabilityZone: '1' // Not all tiers support it. set to '' for 'Standard_B1ms' may work
//   }
// }


// resource waitForPostgreSqlServerScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: 'waitForPostgreSqlServerReady'
//   location: resourceGroup().location
//   kind: 'AzurePowerShell'
//   properties: {
//     azPowerShellVersion: '3.0'
//     scriptContent: 'start-sleep -Seconds 300'
//     cleanupPreference: 'Always'
//     retentionInterval: 'PT1H'
//   }
//   dependsOn: [
//     postgreSqlServer
//   ]
// }

// resource postgresConfigurations 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
//   name: 'azure.extensions'
//   parent: postgreSqlServer
//   properties: {
//     value: 'vector'
//     source: 'user-override'
//   }
//   dependsOn: [
//     waitForPostgreSqlServerScript
//   ]
// }

// This has not worked yet
// resource azureADAdministrator 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
//   parent: postgreSqlServer
//   name: managedIdentity.properties.principalId
//   properties: {
//     principalType: 'SERVICEPRINCIPAL'
//     principalName: managedIdentity.name
//     principalId: managedIdentity.properties.principalId
//     tenantId: subscription().tenantId
//   }
//   dependsOn: [
//     postgresConfigurations
//   ]
// }


resource kvsPostgreSqlServerName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql-server-name'
  properties: {
    value: postreSQLServerName
  }
}

resource kvsPostgreSqlServerEndPoint'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql-server-end-point'
  properties: {
    value: '${postreSQLServerName}.postgres.database.azure.com'
  }
}

resource kvsPostgreSqlDbName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql-db-name'
  properties: {
    value: 'postgres'
  }
}

resource kvsPostgreSqlAdminLogin 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql-admin-login'
  properties: {
    value: postgreServerAdminLogin
  }
}

resource kvsPostgreSqlAdminPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'postgresql-addmin-password'
  properties: {
    value: postgreServerAdminPassword
  }
}





// /**************************************************************************/
// // Azure Container Registry and Container Apps etc
// /**************************************************************************/

// resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
//   name: acrName
//   location: location
//   sku: {
//     name: 'Basic'
//   }
//   properties: {
//     adminUserEnabled: true
//   }
// }

// /**************************************************************************/
// // Store ACR credentials in Key Vault
// /**************************************************************************/

// resource kvsAcrLoginServer 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
//   parent: keyVault
//   name: 'acr-login-server'
//   properties: {
//     value: acrResource.properties.loginServer
//   }
// }
// resource kvsAcrUsername 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
//   parent: keyVault
//   name: 'acr-username'
//   properties: {
//     value: acrName
//   }
// }
// resource kvsAcrPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
//   parent: keyVault
//   name: 'acr-password'
//   properties: {
//     value: acrResource.listCredentials().passwords[0].value
//   }
// }



// resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
//   name: '${resourcePrefix}LogAnalytics'
//   location: location
//   properties: {
//     retentionInDays: 30
//     sku: {
//       name: 'PerGB2018' 
//     }
//   }
// }


// resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
//   name: '${resourcePrefix}AppInsights'
//   location: location
//   kind: 'web'
//   properties: {
//     Application_Type: 'web'
//     WorkspaceResourceId: logAnalytics.id
//   }
// }

// resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
//   name: '${resourcePrefix}ContainerAppsEnv'
//   location: location
//   properties: {
//     appLogsConfiguration: {
//       destination: 'log-analytics'
//       logAnalyticsConfiguration: {
//         customerId: logAnalytics.properties.customerId
//         sharedKey: logAnalytics.listKeys().primarySharedKey
//       }
//     }
//   }
// }

// var contextPath = 'https://github.com/gailzmicrosoft/PythonApiApp'
// var dockerFilePath = 'Dockerfile_root'


// /**************************************************************************/
// // ACR Task to Build and Push Docker Image
// /**************************************************************************/
// resource acrTask 'Microsoft.ContainerRegistry/registries/tasks@2019-04-01' = {
//   parent: acrResource
//   name: 'buildAndPushTask'
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
//       contextPath: contextPath
//       dockerFilePath: dockerFilePath
//       imageNames: [
//         '${acrResource.name}.azurecr.io/${dockerImageName}:${dockerImageTag}'
//       ]
//       isPushEnabled: true
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


// /**************************************************************************/
// // Some environment variables for the container app
// /**************************************************************************/

// var appEnvironVars = [
//   {
//     name: 'KEY_VAULT_URI'
//     value: keyVault.properties.vaultUri
//   }
//   {
//     name: 'MID_NAME'
//     value: managedIdentity.name
//   }
//   {
//     name: 'MID_ID'
//     value: managedIdentity.id
//   }
//   {
//     name: 'AZURE_STORAGE_ACCOUNT_NAME'
//     value: storageAccount.name
//   }
//   {
//     name: 'POSTGRESQL_SERVER_NAME'
//     value: postreSQLServerName
//   }
//   {
//     name: 'POSTGRESQL_SERVER_HOST'
//     value: '${postreSQLServerName}.postgres.database.azure.com'
//   }
//   {
//     name: 'POSTGRESQL_DB_NAME'
//     value: 'postgres'
//   }
//   {
//     name: 'APPLICATIONINSIGHTS_INSTRUMENTATION_KEY'
//     value: applicationInsights.properties.ConnectionString
//   }
// ]

// resource containerApps 'Microsoft.App/containerApps@2023-05-01' = {
//   name: '${resourcePrefix}cntrapp'
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
//       secrets: [
//         {
//           name: 'keyvault-uri'
//           value: keyVault.properties.vaultUri
//         }
//         {
//           name: 'x-api-key'
//           value: kvsApiKey.properties.secretUriWithVersion
//         }
//       ]
//       ingress: {
//         external: true
//         targetPort: 8080
//         traffic: [
//           {
//             latestRevision: true
//             weight: 100
//           }
//         ]
//       }
//       registries: [
//         {
//           server: '${acrResource.name}.azurecr.io'
//           identity: managedIdentity.id
//         }
//       ]
//     }
//     template: {
//       revisionSuffix: 'v1-${deploymentTimestamp}' // Generate a unique revision suffix using the current timestamp
//       containers: [
//         {
//           name: dockerImageName
//           image: '${acrResource.name}.azurecr.io/${dockerImageName}:${dockerImageTag}'
//           env: appEnvironVars
//           resources: {
//             cpu: 1
//             memory: '2.0Gi'
//           }
//         }
//         // {
//         //   name: 'nginx'
//         //   image: 'docker.io/library/nginx:latest'
//         //   env: appEnvironVars
//         //   resources: {
//         //     cpu: 1
//         //     memory: '2.0Gi'
//         //   }
//         // }

//       ]
//     }
//   }
//   dependsOn: [
//     acrTaskRun // Ensure the container app waits for the ACR Task Run to complete
//   ]
// }



//azure-cli --version
//2.70.0, 2.69.0, 2.68.0, 2.67.0, 2.66.1, 2.66.0, 2.65.0, 2.64.0, 2.63.0,
// 2.62.0, 2.61.0, 2.60.0, 2.59.0, 2.58.0, 2.57.0, 2.56.0, 2.55.0, 2.54.0, 2.53.1, 2.53.0, 2.52.0


/**************************************************************************/
// Create PostgreSQL tables 
/**************************************************************************/
var baseUrl = 'https://raw.githubusercontent.com/gailzmicrosoft/PythonApiApp/main/'
var arguments= '${baseUrl} ${resourceGroup().name} ${keyVault.name} ${postreSQLServerName}'
resource createPostgreSqlTables 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind:'AzureCLI'
  name: 'BashPythonCreateTablesScripts'
  location: location // Replace with your desired location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}' : {}
    }
  }
  properties: {
    azCliVersion: '2.52.0' // '2.52.0'
    primaryScriptUri: '${baseUrl}infra/scripts/python_create_tables_script.sh'
    arguments: arguments
    retentionInterval: 'PT1H' // Specify the desired retention interval
    cleanupPreference:'OnSuccess'
  }
}
