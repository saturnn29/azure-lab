// Internal Load Balancer - distributes traffic across hub NVA VMs (vm0, vm1)
resource ilb 'Microsoft.Network/loadBalancers@2025-05-01' = {
  name: 'az104-06-ilb'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          subnet: {
            id: vnet01.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.60.0.10'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'hub-nva-pool'
      }
    ]
    probes: [
      {
        name: 'ssh-probe'
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'ha-ports-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'az104-06-ilb', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'az104-06-ilb', 'hub-nva-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'az104-06-ilb', 'ssh-probe')
          }
          protocol: 'All'
          frontendPort: 0
          backendPort: 0
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}
