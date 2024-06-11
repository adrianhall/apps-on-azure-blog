targetScope = 'resourceGroup'

param location string = resourceGroup().location
param resourceToken string
param tags object = {}
param lock object?

var cosmosDatabaseName = 'sma-db'
var cosmosContainerName = 'sma'
var cosmosThroughput = 500

var storageAccountType = 'Standard_LRS'

var appInsightsName = 'sma-appi-${resourceToken}'
var appServicePlanName = 'sma-asp-${resourceToken}'
var functionAppName = 'sma-fn-${resourceToken}'
var logAnalyticsName = 'sma-log-${resourceToken}'
var storageAccountName = 'fnstore${resourceToken}'

// Logging and monitoring
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.3.4' = {
  name: 'm-${logAnalyticsName}'
  params: {
    name: logAnalyticsName
    location: location
    lock: lock
    tags: tags

    dailyQuotaGb: 2
    dataRetention: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

module appInsights 'br/public:avm/res/insights/component:0.3.0' = {
  name: 'm-${appInsightsName}'
  params: {
    name: appInsightsName
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId

    applicationType: 'web'
    disableIpMasking: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: 30
  }
}

// Cosmos Database
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'sma-cosmos-${resourceToken}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: true
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  name: 'sma-cosmosdb-${resourceToken}'
  parent: cosmosAccount
  properties: {
    resource: { id: cosmosDatabaseName }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  name: 'sma-cosmoscontainer-${resourceToken}'
  parent: cosmosDatabase
  properties: {
    options: {
      throughput: cosmosThroughput
    }
    resource: {
      id: cosmosContainerName
      partitionKey: {
        paths: [ '/id' ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
  }
}

// Azure Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: { name: storageAccountType }
  kind: 'StorageV2'
  tags: tags
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: { name: 'Y1', tier: 'Dynamic' }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  tags: union(tags, { 'azd-service-name': 'social-media-automation' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.outputs.instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.outputs.instrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'DatabaseName'
          value: cosmosDatabase.name
        }
        {
          name: 'ContainerName'
          value: cosmosContainer.name
        }
        {
          name: 'CosmosDbEndpoint'
          value: cosmosAccount.properties.documentEndpoint
        }
      ]
    }
  }
}

module cosmosRoleAssignment '../modules/cosmos-role-assignment.bicep' = {
  name: 'm-sma-cosmos-role-${resourceToken}'
  params: {
    cosmosAccountName: cosmosAccount.name
    principalId: functionApp.identity.principalId
  }
}
