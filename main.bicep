targetScope = 'subscription'

@metadata({
  description: 'Whether to create a new resource group (true) or use an existing one (false).'
})
param createNewResourceGroup bool = true

@metadata({
  description: 'Name of the target resource group.'
})
@minLength(1)
@maxLength(90)
param resourceGroupName string

@metadata({
  description: 'Primary Azure region for the resource group and infrastructure.'
})
param location string

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
  description: 'Name of the virtual network.'
})
@minLength(2)
@maxLength(64)
param vnetName string = 'vnet-elrehan-pilot'

@metadata({
  description: 'Address prefix for the virtual network (IPv4 CIDR).'
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
  description: 'Subnets array configured via dynamic UI grid.'
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
  description: 'Resource Group containing the existing virtual network. Defaults to target resource group if empty.'
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
  description: 'Network Security Group mode: new, existing, or none.'
})
@allowed([
  'new'
  'existing'
  'none'
])
param nsgMode string = 'new'

@metadata({
  description: 'Name of the Network Security Group to create.'
})
param nsgName string = 'nsg-elrehan-pilot'

@metadata({
  description: 'Name of an existing Network Security Group to associate.'
})
param existingNsgName string = ''

@metadata({
  description: 'Resource Group containing the existing NSG. Defaults to target resource group if empty.'
})
param existingNsgResourceGroup string = ''

// ==========================================
// 3. Routing (Route Table) Parameters
// ==========================================
@metadata({
  description: 'Route Table mode: new, existing, or none.'
})
@allowed([
  'new'
  'existing'
  'none'
])
param routeTableMode string = 'none'

@metadata({
  description: 'Name of the Route Table to create.'
})
param routeTableName string = 'rt-elrehan-pilot'

@metadata({
  description: 'Whether to disable BGP route propagation.'
})
param disableBgpRoutePropagation bool = false

@metadata({
  description: 'Name of an existing Route Table to associate.'
})
param existingRouteTableName string = ''

@metadata({
  description: 'Resource Group containing the existing Route Table.'
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

#disable-next-line use-safe-access
var effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags

var isLinux = (osType == 'Linux')
var isWindows = (osType == 'Windows')
var hasValidLinuxAuth = isLinux && !empty(adminSshPublicKey) && (startsWith(adminSshPublicKey, 'ssh-rsa') || startsWith(adminSshPublicKey, 'ssh-ed25519'))
var hasValidWindowsAuth = isWindows && !empty(adminPassword) && length(adminPassword) >= 12 && length(adminPassword) <= 123
var hasValidAuth = hasValidLinuxAuth || hasValidWindowsAuth

var configuredSubnetNames = [for s in subnets: s.name]
var isNewVnetSubnetValid = (vnetMode == 'new') && !empty(selectedSubnetName) && contains(configuredSubnetNames, selectedSubnetName)
var isExistingVnetSubnetValid = (vnetMode == 'existing') && !empty(selectedSubnetName) && ((addNewSubnet && selectedSubnetName == newSubnetName) || (!empty(existingSubnetName) && selectedSubnetName == existingSubnetName))
var isSubnetValid = isNewVnetSubnetValid || isExistingVnetSubnetValid

var authCheck = deployVm ? (!hasValidAuth ? fail('VM deployment is enabled, but valid authentication credentials were not provided. Linux requires an RSA (ssh-rsa) or ED25519 (ssh-ed25519) SSH public key; Windows requires a password between 12 and 123 characters satisfying complexity requirements.') : true) : true
var subnetCheck = deployVm ? (!isSubnetValid ? fail('VM deployment is enabled, but the selected subnet "${selectedSubnetName}" does not match any configured or existing subnet.') : true) : true

// 1. Conditional Resource Group provisioned at subscription scope
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = if (createNewResourceGroup) {
  name: resourceGroupName
  location: location
  tags: effectiveTags
}

// 2. Resource Group deployment module executing full infrastructure stack
module rgDeployment 'main-rg.bicep' = {
  name: 'rg-deployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [
    targetResourceGroup
  ]
  params: {
    location: location
    tags: effectiveTags
    vnetMode: vnetMode
    vnetName: vnetName
    addressPrefix: addressPrefix
    subnets: subnets
    existingVnetName: existingVnetName
    existingVnetResourceGroup: existingVnetResourceGroup
    existingSubnetName: existingSubnetName
    addNewSubnet: addNewSubnet
    newSubnetName: newSubnetName
    newSubnetPrefix: newSubnetPrefix
    nsgMode: nsgMode
    nsgName: nsgName
    existingNsgName: existingNsgName
    existingNsgResourceGroup: existingNsgResourceGroup
    routeTableMode: routeTableMode
    routeTableName: routeTableName
    disableBgpRoutePropagation: disableBgpRoutePropagation
    existingRouteTableName: existingRouteTableName
    existingRouteTableResourceGroup: existingRouteTableResourceGroup
    deployVm: deployVm
    osType: osType
    vmName: vmName
    vmSize: vmSize
    selectedSubnetName: selectedSubnetName
    adminUsername: adminUsername
    adminPassword: adminPassword
    adminSshPublicKey: adminSshPublicKey
  }
}

@description('Target resource group name.')
output resourceGroupName string = resourceGroupName

@description('Deployment region.')
output location string = location

@description('Resource ID of the virtual network.')
output vnetId string = rgDeployment.outputs.vnetId

@description('Name of the virtual network.')
output vnetName string = rgDeployment.outputs.vnetName

@description('Resource ID of the associated Network Security Group, if configured.')
output nsgId string = rgDeployment.outputs.nsgId

@description('Resource ID of the associated Route Table, if configured.')
output routeTableId string = rgDeployment.outputs.routeTableId

@description('Target subnet attached to the VM NIC.')
output targetSubnetAttached string = rgDeployment.outputs.targetSubnetAttached

@description('Indicates whether VM provisioning was activated in this execution.')
output vmProvisioned bool = rgDeployment.outputs.vmProvisioned && authCheck && subnetCheck

@description('Indicates whether required authentication parameters were successfully provided.')
output authConfigured bool = rgDeployment.outputs.authConfigured

@description('Resource ID of the virtual machine if provisioned.')
output vmId string = rgDeployment.outputs.vmId
