targetScope = 'resourceGroup'

@description('The name of the subdomain')
param name string

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

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: name
  parent: dnsZone
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: staticSite.properties.defaultHostname
    }
  }
}

resource customDomain 'Microsoft.Web/staticSites/customDomains@2023-01-01' = {
  name: '${name}.${zoneName}'
  parent: staticSite
  properties: {
    validationMethod: 'cname-delegation'
  }
}

output domainName string = cnameRecord.properties.fqdn
