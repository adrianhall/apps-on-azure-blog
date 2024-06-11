targetScope = 'resourceGroup'

param environmentName string
param location string = resourceGroup().location
param lock object?
param resourceToken string
param tags object = {}
param zoneName string


module swa 'br/public:avm/res/web/static-site:0.3.0' = {
  name: 'swa-${resourceToken}'
  params: {
    name: '${environmentName}-web-${resourceToken}'
    location: location
    lock: lock
    sku: 'Standard'
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

module dnszone 'br/public:avm/res/network/dns-zone:0.3.0' = {
  name: 'dnszone-${resourceToken}'
  params: {
    name: zoneName
    location: 'global'
    lock: lock
    tags: tags
  }
}

module wwwdomain '../modules/swa-custom-domain.bicep' = {
  name: 'www-custom-domain-${resourceToken}'
  params: {
    name: 'www'
    zoneName: dnszone.outputs.name
    staticWebAppName: swa.outputs.name
  }
}

module apexdomain '../modules/swa-apex-domain.bicep' = {
  name: 'apex-custom-domain-${resourceToken}'
  params: {
    zoneName: dnszone.outputs.name
    staticWebAppName: swa.outputs.name
  }
}

output serviceUrls string[] = [
  'https://${swa.outputs.defaultHostname}'
  'https://${wwwdomain.outputs.domainName}'
  'https://${apexdomain.outputs.domainName}'
]
