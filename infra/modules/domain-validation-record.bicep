targetScope = 'resourceGroup'

@description('The validation token')
param validationToken string?

@description('The name of the Azure DNS hosted DNS zone')
param zoneName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zoneName
}

resource domainValidationRecord 'Microsoft.Network/dnsZones/TXT@2023-07-01-preview' = if (validationToken != null) {
  name: '@'
  parent: dnsZone
  properties: {
    TTL: 60
    TXTRecords: [
      {
        value: [ validationToken ?? 'not-provided' ]
      }
    ]
  }
}
