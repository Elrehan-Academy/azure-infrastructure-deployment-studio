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
  description: 'Subnet name where the pilot VM NIC attaches. Must match a configured subnet name.'
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

// Handle tags input: unpack nested tags if passed via Microsoft.Common.TagsByResource or keep flat dictionary
#disable-next-line use-safe-access
var effectiveTags = contains(tags, 'Microsoft.Resources/deployments') ? tags['Microsoft.Resources/deployments'] : tags

// Authentication verification: Linux requires ssh-rsa or ssh-ed25519; Windows requires 12-123 character password
var isLinux = (osType == 'Linux')
var isWindows = (osType == 'Windows')
var hasValidLinuxAuth = isLinux && !empty(adminSshPublicKey) && (startsWith(adminSshPublicKey, 'ssh-rsa') || startsWith(adminSshPublicKey, 'ssh-ed25519'))
var hasValidWindowsAuth = isWindows && !empty(adminPassword) && length(adminPassword) >= 12 && length(adminPassword) <= 123
var hasValidAuth = hasValidLinuxAuth || hasValidWindowsAuth

// Subnet validation: selectedSubnetName must match one of the configured subnets when deployVm is true
var configuredSubnetNames = [for s in subnets: s.name]
var isSubnetValid = !empty(selectedSubnetName) && contains(configuredSubnetNames, selectedSubnetName)

// Explicit validation failure guards (no silent fallback or silent suppression)
var authCheck = deployVm ? (!hasValidAuth ? fail('VM deployment is enabled, but valid authentication credentials were not provided. Linux requires an RSA (ssh-rsa) or ED25519 (ssh-ed25519) SSH public key; Windows requires a password between 12 and 123 characters satisfying complexity requirements.') : true) : true
var subnetCheck = deployVm ? (!isSubnetValid ? fail('VM deployment is enabled, but the selected subnet "${selectedSubnetName}" does not match any configured subnet in the subnets array.') : true) : true

// 1. Conditional Resource Group provisioned at subscription scope
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = if (createNewResourceGroup) {
  name: resourceGroupName
  location: location
  tags: effectiveTags
}

// 2. Networking module provisioned into target resource group
module networkModule 'modules/network.bicep' = {
  name: 'network-deployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [
    targetResourceGroup
  ]
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: addressPrefix
    subnets: subnets
    tags: effectiveTags
  }
}

// 3. Compute module conditionally provisioned if deployVm is true, guarded by explicit pre-flight validation
module computeModule 'modules/compute.bicep' = if (deployVm) {
  name: 'compute-deployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    vmName: vmName
    osType: osType
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    adminSshPublicKey: adminSshPublicKey
    subnetId: (authCheck && subnetCheck) ? '${networkModule.outputs.vnetId}/subnets/${selectedSubnetName}' : ''
    tags: effectiveTags
  }
}

@description('Target resource group name.')
output resourceGroupName string = resourceGroupName

@description('Deployment region.')
output location string = location

@description('Resource ID of the virtual network.')
output vnetId string = networkModule.outputs.vnetId

@description('Name of the virtual network.')
output vnetName string = networkModule.outputs.vnetName

@description('Created subnets metadata.')
output subnets array = networkModule.outputs.subnets

@description('Target subnet attached to the VM NIC.')
output targetSubnetAttached string = deployVm ? selectedSubnetName : ''

@description('Indicates whether VM provisioning was activated in this execution.')
output vmProvisioned bool = deployVm

@description('Indicates whether required authentication parameters were successfully provided.')
output authConfigured bool = hasValidAuth

@description('Resource ID of the virtual machine if provisioned.')
output vmId string = deployVm ? computeModule!.outputs.vmId : ''
