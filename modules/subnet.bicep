@description('Name of the parent Virtual Network.')
param vnetName string

@description('Name of the subnet to create or update.')
param subnetName string

@description('IPv4 CIDR address prefix for the subnet.')
param addressPrefix string

@description('Optional Network Security Group ID to associate with the subnet.')
param networkSecurityGroupId string = ''

@description('Optional Route Table ID to associate with the subnet.')
param routeTableId string = ''

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: existingVnet
  name: subnetName
  properties: {
    addressPrefix: addressPrefix
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
    routeTable: !empty(routeTableId) ? {
      id: routeTableId
    } : null
  }
}

@description('Resource ID of the created or updated subnet.')
output subnetId string = subnet.id

@description('Name of the subnet.')
output subnetName string = subnet.name
