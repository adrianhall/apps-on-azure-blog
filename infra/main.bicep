targetScope = 'subscription'

@description('The environment name - a unique string that is used to identify THIS deployment.')
param environmentName string

@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The name of the DNS zone that will be created')
param zoneName string = 'apps-on-azure.net'

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
    name: '${environmentName}-web-${resourceToken}'
    location: location
    sku: 'Free'
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

module dnszone 'br/public:avm/res/network/dns-zone:0.3.0' = {
  name: 'dnszone-${resourceToken}'
  scope: rg
  params: {
    name: zoneName
    location: location
    tags: tags
  }
}

module wwwdomain 'modules/swa-custom-subdomain.bicep' = {
  name: 'www-custom-domain-${resourceToken}'
  scope: rg
  params: {
    name: 'www'
    zoneName: dnszone.outputs.name
    staticWebAppName: swa.outputs.name
  }
}

output AZURE_LOCATION string = location
output SERVICE_URL string[] = [
  'https://${swa.outputs.defaultHostname}'
  wwwdomain.outputs.domainName
]
