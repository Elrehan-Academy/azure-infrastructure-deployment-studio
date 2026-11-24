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

@description('Security rule definition type.')
type securityRuleType = {
  @description('Name of the security rule.')
  name: string
  @description('Security rule properties.')
  properties: {
    @description('Rule description.')
    description: string?
    @description('Network protocol: Tcp, Udp, Icmp, Esp, Ah, or Asterisk.')
    protocol: string
    @description('Source port or range (*, 80, 1024-65535).')
    sourcePortRange: string
    @description('Destination port or range (*, 22, 80, 443, 3389).')
    destinationPortRange: string
    @description('Source address prefix (CIDR, ServiceTag, or VirtualNetwork). Never exposed to internet by default.')
    sourceAddressPrefix: string
    @description('Destination address prefix.')
    destinationAddressPrefix: string
    @description('Access: Allow or Deny.')
    access: string
    @description('Priority between 100 and 4096.')
    priority: int
    @description('Direction: Inbound or Outbound.')
    direction: string
  }
}

@description('Custom security rules to configure in the NSG.')
param customSecurityRules securityRuleType[] = []

// Default baseline secure rule: Allows internal VirtualNetwork management only (no public Internet exposure)
var defaultManagementRule = {
  name: osType == 'Linux' ? 'Allow-SSH-Internal' : 'Allow-RDP-Internal'
  properties: {
    description: 'Allows remote management inbound from internal VirtualNetwork only (secure default).'
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

var effectiveRules = empty(customSecurityRules) ? [
  defaultManagementRule
] : customSecurityRules

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      for rule in effectiveRules: {
        name: rule.name
        properties: {
          description: rule.properties.?description ?? 'Custom security rule'
          protocol: rule.properties.protocol
          sourcePortRange: rule.properties.sourcePortRange
          destinationPortRange: rule.properties.destinationPortRange
          sourceAddressPrefix: rule.properties.sourceAddressPrefix
          destinationAddressPrefix: rule.properties.destinationAddressPrefix
          access: rule.properties.access
          priority: rule.properties.priority
          direction: rule.properties.direction
        }
      }
    ]
  }
}

@description('Resource ID of the created Network Security Group.')
output nsgId string = nsg.id

@description('Name of the created Network Security Group.')
output nsgName string = nsg.name
