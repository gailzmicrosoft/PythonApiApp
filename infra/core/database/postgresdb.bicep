
param location string
param managedIdentityObjectId string
param managedIdentityObjectName string
@description('The name of the SQL logical server.')
param serverName string = 'postgressqlserver'
param additionalDatabase string   // if it is same as postgres or it is empty, it will not be created. 

param administratorLogin string = 'InitialLogin_to_be_changed_12345!'
param administratorLoginPassword string // This is not used. 
param serverEdition string = 'Burstable'
param skuSizeGB int = 32
param dbInstanceType string = 'Standard_B1ms'
// param haMode string = 'ZoneRedundant'
param availabilityZone string = '1'
param allowAllIPsFirewall bool = false
param allowAzureIPsFirewall bool = false
@description('PostgreSQL version')
@allowed([
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param version string = '16'

resource serverName_resource 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: serverName
  location: location
  sku: {
    name: dbInstanceType
    tier: serverEdition
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    authConfig: {
      tenantId: subscription().tenantId
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      storageSizeGB: skuSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    availabilityZone: availabilityZone
  }
}

output postgresSqLServerName string = serverName_resource.name
output postgresSqLServerFQN string = '${serverName_resource.name}.postgres.database.azure.com'
output postgreSqlServerAdminLogin string = serverName_resource.properties.administratorLogin
output postgreSqlDatabaseName string = 'postgres'

// Create additional database if specified and not equal to 'postgres' 
resource additionalDB 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = if (!empty(additionalDatabase) && additionalDatabase != 'postgres') {
  name: additionalDatabase
  parent: serverName_resource
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}
output additionalDatabaseName string = additionalDB.name


resource delayScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'waitForServerReady'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '3.0'
    scriptContent: 'start-sleep -Seconds 300'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    serverName_resource
  ]
}

resource configurations 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-12-01-preview' = {
  name: 'azure.extensions'
  parent: serverName_resource
  properties: {
    value: 'vector'
    source: 'user-override'
  }
  dependsOn: [
    delayScript
  ]
}

resource azureADAdministrator 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  parent: serverName_resource
  name: managedIdentityObjectId
  properties: {
    principalType: 'SERVICEPRINCIPAL'
    principalName: managedIdentityObjectName
    tenantId: subscription().tenantId
  }
  dependsOn: [
    configurations
  ]
}


resource firewall_all 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = if (allowAllIPsFirewall) {
  parent: serverName_resource
  name: 'allow-all-IPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
  dependsOn: [
    azureADAdministrator
  ]
}

resource firewall_azure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = if (allowAzureIPsFirewall) {
  parent: serverName_resource
  name: 'allow-all-azure-internal-IPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    azureADAdministrator
  ]
}

output postgresDbOutput object = {
  postgresSQLName: serverName_resource.name
  postgreSQLServerName: '${serverName_resource.name}.postgres.database.azure.com'
  postgreSQLDatabaseName: 'postgres'
  postgreSQLDbUser: administratorLogin
  sslMode: 'Require'
}
