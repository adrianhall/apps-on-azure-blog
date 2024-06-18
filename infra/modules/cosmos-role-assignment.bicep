@description('The name of the Cosmos DB account that we will use for SQL Role Assignments')
param cosmosAccountName string

@description('The Principal Id that we will grant the role assignment to.')
param principalId string

var roleDefinitionId = guid('sql-role-definition-', principalId, account.id)
var roleAssignmentId = guid(roleDefinitionId, principalId, account.id)
var roleDefinitionName = 'Read and Write all containers'
var dataActions = [
  'Microsoft.DocumentDB/databaseAccounts/readMetadata'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
]

resource account 'Microsoft.DocumentDB/databaseAccounts@2021-11-15-preview' existing = {
  name: cosmosAccountName
}

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-11-15-preview' = {
  parent: account
  name: roleDefinitionId
  properties: {
    roleName: roleDefinitionName
    type: 'CustomRole'
    assignableScopes: [ account.id ]
    permissions: [
      { dataActions: dataActions }
    ]
  }
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-11-15-preview' = {
  parent: account
  name: roleAssignmentId
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: principalId
    scope: account.id
  }
}
