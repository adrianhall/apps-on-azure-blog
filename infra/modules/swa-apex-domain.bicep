targetScope = 'resourceGroup'

@description('The name of the static web app service.')
param staticWebAppName string

@description('The name of the Azure DNS hosted DNS zone')
param zoneName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zoneName
}

resource staticSite 'Microsoft.Web/staticSites@2023-12-01' existing = {
  name: staticWebAppName
}

resource apexDomain 'Microsoft.Web/staticSites/customDomains@2023-12-01' = {
  name: zoneName
  parent: staticSite
  properties: {
    validationMethod: 'dns-txt-token'
  }
}

output domainProperties object = apexDomain.properties
output domainName string = dnsZone.name
