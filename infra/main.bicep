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
    location: 'global'
    tags: tags
  }
}

module wwwdomain 'modules/swa-custom-domain.bicep' = {
  name: 'www-custom-domain-${resourceToken}'
  scope: rg
  params: {
    name: 'www'
    zoneName: dnszone.outputs.name
    staticWebAppName: swa.outputs.name
  }
}

module apexdomain 'modules/swa-apex-domain.bicep' = {
  name: 'apex-custom-domain-${resourceToken}'
  scope: rg
  params: {
    zoneName: dnszone.outputs.name
    staticWebAppName: swa.outputs.name
  }
}

module customDomainReader 'modules/custom-domain-reader.bicep' = {
  name: 'custom-domain-reader-${resourceToken}'
  scope: rg
  params: {
    zoneName: apexdomain.outputs.domainName
    staticWebAppName: swa.outputs.name
  }
}

module txtRecord 'modules/txt-record.bicep' = {
  name: 'txt-record-${resourceToken}'
  scope: rg
  params: {
    zoneName: apexdomain.outputs.domainName
    validationToken: apexdomain.outputs.domainProperties.validationToken
  }
}
// ERROR: validationToken is not returned as part of the response.


output AZURE_LOCATION string = location
output SERVICE_URL string[] = [
  'https://${swa.outputs.defaultHostname}'
  'https://${wwwdomain.outputs.domainName}'
]
