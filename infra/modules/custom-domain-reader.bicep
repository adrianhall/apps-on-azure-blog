targetScope = 'resourceGroup'

@description('The name of the static web app service.')
param staticWebAppName string

@description('The name of the Azure DNS hosted DNS zone')
param zoneName string

resource staticSite 'Microsoft.Web/staticSites@2023-12-01' existing = {
  name: staticWebAppName
}

resource customDomain 'Microsoft.Web/staticSites/customDomains@2023-12-01' existing = {
  name: zoneName
  parent: staticSite
}

output domainProperties object = customDomain.properties
output domainName string = customDomain.name
