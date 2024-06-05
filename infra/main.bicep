targetScope = 'subscription'

@description('The environment name - a unique string that is used to identify THIS deployment.')
param environmentName string

@description('The name of the Azure region that will be used for the deployment.')
param location string

var resourceToken = uniqueString(subscription().subscriptionId, environmentName, location)
var tags = { 'azd-env-name': environmentName}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module swa 'br/public:avm/res/web/static-site:0.3.0' = {
  name: 'swa-${resourceToken}'
  scope: rg
  params: {
    name: 'swa-${environmentName}'
    location: location
    sku: 'Free'
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

output AZURE_LOCATION string = location
output SERVICE_URL string = 'https://${swa.outputs.defaultHostname}'
