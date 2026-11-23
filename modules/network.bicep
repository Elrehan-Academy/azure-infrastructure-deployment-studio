@description('Azure region for the virtual network resources.')
param location string = resourceGroup().location

@description('The name of the virtual network.')
@minLength(2)
@maxLength(64)
param vnetName string

@description('The top-level IPv4 CIDR address prefix for the virtual network.')
param addressPrefix string

@description('Subnet definition with name and addressPrefix.')
type subnetType = {
  @description('Name of the subnet.')
  @minLength(1)
  @maxLength(80)
  name: string

  @description('IPv4 CIDR address prefix for the subnet.')
  addressPrefix: string
}

@description('List of subnet objects with name and addressPrefix properties.')
@minLength(1)
param subnets subnetType[]

@description('Tags to apply to the virtual network.')
param tags object = {}

@description('Optional default Network Security Group ID to attach to subnets.')
param networkSecurityGroupId string = ''

// Duplicate subnet name validation
var subnetNames = [for s in subnets: toLower(s.name)]
var hasDuplicateSubnetNames = length(union(subnetNames, [])) != length(subnetNames)
var subnetNameCheck = hasDuplicateSubnetNames ? fail('Duplicate subnet names detected in subnets array. Subnet names must be unique.') : true

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        subnetNameCheck ? addressPrefix : addressPrefix
      ]
    }
    subnets: [
      for (subnet, i) in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          networkSecurityGroup: !empty(networkSecurityGroupId) ? {
            id: networkSecurityGroupId
          } : null
        }
      }
    ]
  }
}

@description('The resource ID of the created virtual network.')
output vnetId string = vnet.id

@description('The name of the created virtual network.')
output vnetName string = vnet.name

@description('The array of created subnets.')
output subnets array = [
  for (subnet, i) in subnets: {
    name: subnet.name
    id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnet.name)
    addressPrefix: subnet.addressPrefix
  }
]
