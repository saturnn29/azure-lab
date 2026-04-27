// hub's virtual network and its 2 subnets and each contains 1 virtual machine
resource vnet01 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'az104-06-vnet01'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.60.0.0/22'
      ]
    }
    subnets: [
      {
        name: 'Subnet0'
        properties: {
          addressPrefix: '10.60.0.0/24'
        }
      }
      {
        name: 'Subnet1'
        properties: {
          addressPrefix: '10.60.1.0/24'
        }
      }
      {
        name: 'Subnet-appgw'
        properties: {
          addressPrefix: '10.60.3.224/27'
          routeTable: {
            id: routeTableAppGw.id
          }
        }
      }
    ]
  }
}

// spoke 1 and its 1 subnet contains only 1 virtual machine
resource vnet2 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'az104-06-vnet2'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.62.0.0/22'
      ]
    }
    subnets: [
      {
        name: 'Subnet0'
        properties: {
          addressPrefix: '10.62.0.0/24'
          routeTable: {
            id: routeTable01.id
          }
        }
      }
    ]
  }
}

// spoke 2 and its 1 subnet contains only 1 virtual machine
resource vnet3 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'az104-06-vnet3'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.63.0.0/22'
      ]
    }
    subnets: [
      {
        name: 'Subnet0'
        properties: {
          addressPrefix: '10.63.0.0/24'
          routeTable: {
            id: routeTable02.id
          }
        }
      }
    ]
  }
}

resource sshKey 'Microsoft.Compute/sshPublicKeys@2025-04-01' existing = {
  name: 'dl-lab-key'
}

// NSG for hub VMs (private) - allows ICMP from VNet and health probes from Azure LB
resource nsgHubPrivate 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'az104-06-nsg-hub-private'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-icmp'
        properties: {
          priority: 100
          protocol: 'Icmp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'allow-lb-health-probe'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-http-transit'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}
// public IP for bastion VM
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'az104-06-pip-bastion'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NSG for bastion VM - allows SSH and ICMP from internet
resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'az104-06-nsg-bastion'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-icmp'
        properties: {
          priority: 110
          protocol: 'Icmp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// hub's NICs (private - no public IPs, registered in ILB backend pool)
resource nics 'Microsoft.Network/networkInterfaces@2025-05-01' = [
  for i in range(0, 2): {
    name: 'az104-06-nic${i}'
    location: location
    properties: {
      enableIPForwarding: true
      networkSecurityGroup: {
        id: nsgHubPrivate.id
      }
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: vnet01.properties.subnets[i].id
            }
            privateIPAllocationMethod: 'Dynamic'
            loadBalancerBackendAddressPools: [
              {
                id: ilb.properties.backendAddressPools[0].id
              }
            ]
          }
        }
      ]
    }
  }
]

// bastion NIC - in vnet01 Subnet0 with public IP
resource bastionNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'az104-06-nic-bastion'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsgBastion.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet01.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
}


// hub's 2 virtual machines with its own NICs
resource vms 'Microsoft.Compute/virtualMachines@2025-04-01' = [
  for i in range(0, 2): {
    name: 'az104-06-vm${i}'
    location: location
    properties: {
      hardwareProfile: {
        vmSize: 'Standard_B1ls'
      }
      osProfile: {
        computerName: 'az104-06-vm${i}'
        adminUsername: adminUsername
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: sshKey.properties.publicKey
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-focal'
          sku: '20_04-lts'
          version: 'latest'
        }
        osDisk: {
          name: 'az104-06-vm${i}-osdisk'
          caching: 'ReadWrite'
          createOption: 'FromImage'
          diskSizeGB: 30
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: nics[i].id
          }
        ]
      }
    }
  }
]

// bastion VM - single public entry point to SSH into all private VMs
resource bastionVM 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'az104-06-vm-bastion'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    osProfile: {
      computerName: 'az104-06-vm-bastion'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKey.properties.publicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
      osDisk: {
        name: 'az104-06-vm-bastion-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 30
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: bastionNic.id
        }
      ]
    }
  }
}

// NSG for spoke VMs - allows inbound SSH
resource nsgSpokes 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'az104-06-nsg-spokes'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-icmp'
        properties: {
          priority: 110
          protocol: 'Icmp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'allow-http'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

// spoke 1's NIC
resource nic2 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'az104-06-nic2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet2.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgSpokes.id
    }
  }
}

// spoke 2's NIC
resource nic3 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'az104-06-nic3'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet3.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgSpokes.id
    }
  }
}

// spoke 1's 1 virtual machine
resource vm2 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'az104-06-vm2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    osProfile: {
      computerName: 'az104-06-vm2'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKey.properties.publicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
      osDisk: {
        name: 'az104-06-vm2-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 30
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2.id
        }
      ]
    }
  }
}

// spoke 2's 1 virtual machine
resource vm3 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'az104-06-vm3'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    osProfile: {
      computerName: 'az104-06-vm3'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKey.properties.publicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
      osDisk: {
        name: 'az104-06-vm3-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 30
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic3.id
        }
      ]
    }
  }
}
