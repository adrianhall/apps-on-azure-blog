targetScope = 'resourceGroup'

@description('The validation token')
param validationToken string

@description('The name of the Azure DNS hosted DNS zone')
param zoneName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zoneName
}

resource txtRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '@'
  parent: dnsZone
  properties: {
    TTL: 3600
    TXTRecords: [
      { value: [ validationToken ] }
    ]
  }
}
