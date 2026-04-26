
/ public IP for Application Gateway
resource appGwPublicIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'az104-06-pip-appgw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Application Gateway - public entry point, backends are spoke VMs
// traffic: internet -> App GW -> ILB (via UDR) -> hub VM (NVA) -> spoke VM
resource appGw 'Microsoft.Network/applicationGateways@2025-05-01' = {
  name: 'az104-06-appgw'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGwIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appgw-ip-config'
        properties: {
          subnet: {
            id: vnet01.properties.subnets[2].id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'public-frontend'
        properties: {
          publicIPAddress: {
            id: appGwPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-443'
        properties: {
          port: 443
        }
      }
    ]
    sslCertificates: [
      {
        name: 'appgw-cert'
        properties: {
          keyVaultSecretId: '${keyVault.properties.vaultUri}secrets/appgw-cert'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'spoke-vms-pool'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.62.0.4'
            }
            {
              ipAddress: '10.63.0.4'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
        }
      }
    ]
    httpListeners: [
      {
        name: 'https-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'az104-06-appgw', 'public-frontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'az104-06-appgw', 'port-443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', 'az104-06-appgw', 'appgw-cert')
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routing-rule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'az104-06-appgw', 'https-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'az104-06-appgw', 'spoke-vms-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'az104-06-appgw', 'http-settings')
          }
        }
      }
    ]
  }
}
// route table for App Gateway subnet: force spoke-bound traffic through the hub ILB
resource routeTableAppGw 'Microsoft.Network/routeTables@2025-05-01' = {
  name: 'az104-06-routetable-appgw'
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
