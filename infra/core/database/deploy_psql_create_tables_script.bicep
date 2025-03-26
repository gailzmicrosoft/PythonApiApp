@description('Specifies the location for resources.')
param location string
param baseUrl string
param keyVaultName string 
param postgreSqlServerName string // Name of the PostgreSQL server, e.g. 'myserver'
param postgresSqlServerFQN string // fully qualified server name, e.g. 'myserver.postgres.database.azure.com'
param postgreSqlDbName string // Name of the PostgreSQL database, e.g. 'mydb'
param adminPrincipalName string
param identity string // Fully qualified resource ID for the managed identity. 
param identityName string // Name of the managed identity

var myArguments= '${baseUrl} ${resourceGroup().name} ${keyVaultName} ${postgreSqlServerName} ${postgresSqlServerFQN} ${postgreSqlDbName} ${adminPrincipalName} ${identityName}'

resource create_index_create_tables 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind:'AzureCLI'
  name: 'runPythonWithBashScriptCreateTables'
  location: location // Replace with your desired location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity}' : {}
    }
  }
  properties: {
    azCliVersion: '2.52.0'
    primaryScriptUri: '${baseUrl}scripts/run_python_create_tables_script.sh'
    arguments: myArguments
    retentionInterval: 'PT1H' // Specify the desired retention interval
    cleanupPreference:'OnSuccess'
  }
}

