resource routeTable01 'Microsoft.Network/routeTables@2025-05-01' = {
  name: 'az104-06-routetable01'
  location: location
  properties: {
    routes: [
      {
        name: 'to-spoke2'
        properties: {
          addressPrefix: '10.63.0.0/22'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.60.0.10'
        }
      }
    ]
  }
}

// spoke 2's route table: send traffic to spoke 1 via ILB (which distributes to vm0/vm1)
resource routeTable02 'Microsoft.Network/routeTables@2025-05-01' = {
  name: 'az104-06-routetable02'
  location: location
  properties: {
    routes: [
      {
        name: 'to-spoke1'
        properties: {
          addressPrefix: '10.62.0.0/22'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.60.0.10'
        }
      }
    ]
  }
}
