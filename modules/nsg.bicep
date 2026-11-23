@description('Azure region for the network security group.')
param location string = resourceGroup().location

@description('Name of the Network Security Group.')
param nsgName string

@description('Tags to apply to the NSG.')
param tags object = {}

@description('Operating system type to configure default inbound management rule.')
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: osType == 'Linux' ? 'Allow-SSH-Inbound' : 'Allow-RDP-Inbound'
        properties: {
          description: 'Allows remote management inbound traffic.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: osType == 'Linux' ? '22' : '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

@description('Resource ID of the created Network Security Group.')
output nsgId string = nsg.id

@description('Name of the created Network Security Group.')
output nsgName string = nsg.name
