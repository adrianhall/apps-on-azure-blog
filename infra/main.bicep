targetScope = 'subscription'

@description('The environment name - a unique string that is used to identify THIS deployment.')
param environmentName string

@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The name of the DNS zone that will be created')
param zoneName string = 'apps-on-azure.net'

var resourceToken = uniqueString(subscription().subscriptionId, environmentName, location)
var tags = { 'azd-env-name': environmentName}
var lock = { kind: 'CanNotDelete' }

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module jekyllSite './app/jekyll.bicep' = {
  name: 'jekyll-${resourceToken}'
  scope: rg
  params: {
    environmentName: environmentName
    location: location
    lock: lock
    resourceToken: resourceToken
    tags: union(tags, { 'module-name': 'jekyll' })
    zoneName: zoneName
  }
}

module socialMediaPoster './app/social-media.bicep' = {
  name: 'social-media-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: union(tags, { 'module-name': 'sma' })
  }
}

module budget 'br/public:avm/res/consumption/budget:0.3.3' = {
  name: 'budget-${resourceToken}'
  params: {
    amount: 10
    name: 'apps-on-azure-budget-${resourceToken}'
    contactEmails: [
      'photoadrian@outlook.com'
    ]
    location: location

    category: 'Cost'
    resourceGroupFilter: [ rg.name ]
    resetPeriod: 'BillingMonth'
    thresholds: [ 100, 125, 150, 200 ]
  }
}

output AZURE_LOCATION string = location
output SERVICE_URL string[] = jekyllSite.outputs.serviceUrls
