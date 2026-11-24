targetScope = 'resourceGroup'

@metadata({
  description: 'Azure region for the resources. Defaults to the target resource group location.'
})
param location string = resourceGroup().location

@metadata({
  description: 'Tags to apply to resources.'
})
param tags object = {}

// ==========================================
// 1. Networking Parameters
// ==========================================
@metadata({
  description: 'Deployment mode for Virtual Network: new (create new VNet) or existing (use existing VNet).'
})
@allowed([
  'new'
  'existing'
])
param vnetMode string = 'new'

@metadata({
  description: 'Name of the virtual network (used when vnetMode is new).'
})
@minLength(2)
@maxLength(64)
param vnetName string = 'vnet-elrehan-pilot'

@metadata({
  description: 'Address prefix for the virtual network (IPv4 CIDR, used when vnetMode is new).'
})
param addressPrefix string = '10.0.0.0/16'

@description('Subnet definition with name and addressPrefix.')
type subnetType = {
  @description('Name of the subnet.')
  @minLength(1)
  @maxLength(80)
  name: string

  @description('IPv4 CIDR address prefix for the subnet.')
  addressPrefix: string
}

@metadata({
  description: 'Subnets array configured via dynamic UI grid (used when vnetMode is new).'
})
@minLength(1)
param subnets subnetType[] = [
  {
    name: 'snet-workload'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'snet-management'
    addressPrefix: '10.0.2.0/24'
  }
]

@metadata({
  description: 'Name of the existing virtual network (used when vnetMode is existing).'
})
param existingVnetName string = ''

@metadata({
  description: 'Resource Group containing the existing virtual network. Defaults to current resource group if empty.'
})
param existingVnetResourceGroup string = ''

@metadata({
  description: 'Name of an existing subnet in the existing VNet to reference.'
})
param existingSubnetName string = ''

@metadata({
  description: 'Whether to create an additional subnet in the existing virtual network.'
})
param addNewSubnet bool = false

@metadata({
  description: 'Name of the additional subnet to create in the existing virtual network.'
})
param newSubnetName string = ''

@metadata({
  description: 'IPv4 CIDR prefix of the additional subnet to create in the existing virtual network.'
})
param newSubnetPrefix string = ''

// ==========================================
// 2. Security (NSG) Parameters
// ==========================================
@metadata({
  description: 'Network Security Group mode: new (create new NSG), existing (associate existing NSG), or none.'
})
@allowed([
  'new'
  'existing'
  'none'
])
param nsgMode string = 'new'

@metadata({
  description: 'Name of the Network Security Group to create (used when nsgMode is new).'
})
param nsgName string = 'nsg-elrehan-pilot'

@metadata({
  description: 'Name of an existing Network Security Group to associate (used when nsgMode is existing).'
})
param existingNsgName string = ''

@metadata({
  description: 'Resource Group containing the existing NSG. Defaults to current resource group if empty.'
})
param existingNsgResourceGroup string = ''

// ==========================================
// 3. Routing (Route Table) Parameters
// ==========================================
@metadata({
  description: 'Route Table mode: new (create new Route Table), existing (associate existing Route Table), or none.'
})
@allowed([
  'new'
  'existing'
  'none'
])
param routeTableMode string = 'none'

@metadata({
  description: 'Name of the Route Table to create (used when routeTableMode is new).'
})
param routeTableName string = 'rt-elrehan-pilot'

@metadata({
  description: 'Whether to disable BGP route propagation on the created Route Table.'
})
param disableBgpRoutePropagation bool = false

@metadata({
  description: 'Name of an existing Route Table to associate (used when routeTableMode is existing).'
})
param existingRouteTableName string = ''

@metadata({
  description: 'Resource Group containing the existing Route Table. Defaults to current resource group if empty.'
})
param existingRouteTableResourceGroup string = ''

// ==========================================
// 4. Virtual Machines Parameters
// ==========================================
@metadata({
  description: 'Pilot safety flag. When false, VM parameters are validated but VM deployment is skipped.'
})
param deployVm bool = false

@metadata({
  description: 'Operating system type for the pilot virtual machine.'
})
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

@metadata({
  description: 'Name of the pilot virtual machine.'
})
@minLength(1)
@maxLength(64)
param vmName string = 'vm-elrehan-pilot-01'

@metadata({
  description: 'Compute SKU selected via Azure size-selector.'
})
param vmSize string = 'Standard_D2s_v5'

@metadata({
  description: 'Subnet name where the pilot VM NIC attaches. Must match a configured or existing subnet name.'
})
param selectedSubnetName string = 'snet-workload'

@metadata({
  description: 'Administrator username for the VM.'
})
@minLength(1)
@maxLength(64)
param adminUsername string = 'azureuser'

@metadata({
  description: 'Administrator password for Windows VM. Required only when deployVm is true and osType is Windows.'
})
@secure()
param adminPassword string = ''

@metadata({
  description: 'SSH public key for Linux VM. Required only when deployVm is true and osType is Linux.'
})
@secure()
param adminSshPublicKey string = ''

// ==========================================
// Variables & Pre-Flight Validation Guards
// ==========================================
#disable-next-line use-safe-access
var effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags

var isLinux = (osType == 'Linux')
var isWindows = (osType == 'Windows')
var hasValidLinuxAuth = isLinux && !empty(adminSshPublicKey) && (startsWith(adminSshPublicKey, 'ssh-rsa') || startsWith(adminSshPublicKey, 'ssh-ed25519'))
var hasValidWindowsAuth = isWindows && !empty(adminPassword) && length(adminPassword) >= 12 && length(adminPassword) <= 123
var hasValidAuth = hasValidLinuxAuth || hasValidWindowsAuth

// Subnet validation logic
var configuredSubnetNames = [for s in subnets: s.name]
var isNewVnetSubnetValid = (vnetMode == 'new') && !empty(selectedSubnetName) && contains(configuredSubnetNames, selectedSubnetName)
var isExistingVnetSubnetValid = (vnetMode == 'existing') && !empty(selectedSubnetName) && ((addNewSubnet && selectedSubnetName == newSubnetName) || (!empty(existingSubnetName) && selectedSubnetName == existingSubnetName))
var isSubnetValid = isNewVnetSubnetValid || isExistingVnetSubnetValid

// Pre-flight fail() guards
var authCheck = deployVm ? (!hasValidAuth ? fail('VM deployment is enabled, but valid authentication credentials were not provided. Linux requires an RSA (ssh-rsa) or ED25519 (ssh-ed25519) SSH public key; Windows requires a password between 12 and 123 characters satisfying complexity requirements.') : true) : true
var subnetCheck = deployVm ? (!isSubnetValid ? fail('VM deployment is enabled, but the selected subnet "${selectedSubnetName}" does not match any configured or existing subnet.') : true) : true
var existingVnetCheck = (vnetMode == 'existing') ? (empty(existingVnetName) ? fail('vnetMode is set to existing, but existingVnetName was not provided.') : true) : true
var existingNsgCheck = (nsgMode == 'existing') ? (empty(existingNsgName) ? fail('nsgMode is set to existing, but existingNsgName was not provided.') : true) : true
var existingRtCheck = (routeTableMode == 'existing') ? (empty(existingRouteTableName) ? fail('routeTableMode is set to existing, but existingRouteTableName was not provided.') : true) : true

// Target resource group calculation for cross-RG existing resources
var effectiveVnetRg = empty(existingVnetResourceGroup) ? resourceGroup().name : existingVnetResourceGroup
var effectiveNsgRg = empty(existingNsgResourceGroup) ? resourceGroup().name : existingNsgResourceGroup
var effectiveRtRg = empty(existingRouteTableResourceGroup) ? resourceGroup().name : existingRouteTableResourceGroup

// ==========================================
// 1. Security (NSG) Provisioning
// ==========================================
module nsgModule 'modules/nsg.bicep' = if (nsgMode == 'new' && existingNsgCheck) {
  name: 'nsg-deployment'
  params: {
    location: location
    nsgName: nsgName
    osType: osType
    tags: effectiveTags
  }
}

var effectiveNsgId = (nsgMode == 'new') ? nsgModule.?outputs.nsgId ?? '' : ((nsgMode == 'existing' && existingNsgCheck) ? resourceId(effectiveNsgRg, 'Microsoft.Network/networkSecurityGroups', existingNsgName) : '')

// ==========================================
// 2. Routing (Route Table) Provisioning
// ==========================================
module routeTableModule 'modules/routeTable.bicep' = if (routeTableMode == 'new' && existingRtCheck) {
  name: 'routetable-deployment'
  params: {
    location: location
    routeTableName: routeTableName
    disableBgpRoutePropagation: disableBgpRoutePropagation
    tags: effectiveTags
  }
}

var effectiveRouteTableId = (routeTableMode == 'new') ? routeTableModule.?outputs.routeTableId ?? '' : ((routeTableMode == 'existing' && existingRtCheck) ? resourceId(effectiveRtRg, 'Microsoft.Network/routeTables', existingRouteTableName) : '')

// ==========================================
// 3. Networking Provisioning
// ==========================================
// Mode A: Create new Virtual Network
module networkModule 'modules/network.bicep' = if (vnetMode == 'new') {
  name: 'network-deployment'
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: addressPrefix
    subnets: subnets
    networkSecurityGroupId: effectiveNsgId
    routeTableId: effectiveRouteTableId
    tags: effectiveTags
  }
}

// Mode B: Deploy additional subnet into existing Virtual Network (supporting cross-RG)
module existingVnetSubnetModule 'modules/subnet.bicep' = if (vnetMode == 'existing' && addNewSubnet && existingVnetCheck) {
  name: 'existing-vnet-subnet-deployment'
  scope: resourceGroup(effectiveVnetRg)
  params: {
    vnetName: existingVnetName
    subnetName: newSubnetName
    addressPrefix: newSubnetPrefix
    networkSecurityGroupId: effectiveNsgId
    routeTableId: effectiveRouteTableId
  }
}

var effectiveVnetId = (vnetMode == 'new') ? (networkModule.?outputs.vnetId ?? '') : resourceId(effectiveVnetRg, 'Microsoft.Network/virtualNetworks', existingVnetName)
var effectiveVnetName = (vnetMode == 'new') ? (networkModule.?outputs.vnetName ?? '') : existingVnetName

// Subnet ID resolution for Compute
var targetSubnetId = (vnetMode == 'new') ? '${networkModule.?outputs.vnetId}/subnets/${selectedSubnetName}' : (addNewSubnet && selectedSubnetName == newSubnetName ? '${effectiveVnetId}/subnets/${newSubnetName}' : '${effectiveVnetId}/subnets/${selectedSubnetName}')

// ==========================================
// 4. Compute Provisioning
// ==========================================
module computeModule 'modules/compute.bicep' = if (deployVm) {
  name: 'compute-deployment'
  params: {
    location: location
    vmName: vmName
    osType: osType
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    adminSshPublicKey: adminSshPublicKey
    subnetId: (authCheck && subnetCheck) ? targetSubnetId : ''
    tags: effectiveTags
  }
}

// ==========================================
// Outputs
// ==========================================
@description('Deployment region.')
output location string = location

@description('Deployment mode used for Virtual Network.')
output vnetMode string = vnetMode

@description('Resource ID of the virtual network.')
output vnetId string = effectiveVnetId

@description('Name of the virtual network.')
output vnetName string = effectiveVnetName

@description('Resource ID of the associated Network Security Group, if configured.')
output nsgId string = effectiveNsgId

@description('Resource ID of the associated Route Table, if configured.')
output routeTableId string = effectiveRouteTableId

@description('Target subnet attached to the VM NIC.')
output targetSubnetAttached string = deployVm ? selectedSubnetName : ''

@description('Indicates whether VM provisioning was activated in this execution.')
output vmProvisioned bool = deployVm

@description('Indicates whether required authentication parameters were successfully provided.')
output authConfigured bool = hasValidAuth

@description('Resource ID of the virtual machine if provisioned.')
output vmId string = deployVm ? computeModule.?outputs.vmId ?? '' : ''
