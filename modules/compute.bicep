@description('Azure region for compute resources.')
param location string = resourceGroup().location

@description('Name of the Virtual Machine.')
@minLength(1)
@maxLength(64)
param vmName string

@description('Operating System platform.')
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

@description('The VM SKU size.')
param vmSize string = 'Standard_D2s_v5'

@description('Administrator username for the VM.')
@minLength(1)
@maxLength(64)
param adminUsername string = 'azureuser'

@description('Administrator password for Windows VM. Required when osType is Windows.')
@secure()
param adminPassword string = ''

@description('SSH public key for Linux VM. Required when osType is Linux.')
@secure()
param adminSshPublicKey string = ''

@description('Subnet Resource ID where the VM NIC will be attached.')
param subnetId string

@description('Tags to apply to the VM and associated resources.')
param tags object = {}

var nicName = '${vmName}-nic'
var isLinux = (osType == 'Linux')
var isWindows = (osType == 'Windows')

// Internal module authentication validation
var hasValidLinuxAuth = isLinux && !empty(adminSshPublicKey) && (startsWith(adminSshPublicKey, 'ssh-rsa') || startsWith(adminSshPublicKey, 'ssh-ed25519'))
var hasValidWindowsAuth = isWindows && !empty(adminPassword) && length(adminPassword) >= 12 && length(adminPassword) <= 123
var hasValidAuth = hasValidLinuxAuth || hasValidWindowsAuth

var authCheck = !hasValidAuth ? fail('VM authentication error: Linux requires an RSA (ssh-rsa) or ED25519 (ssh-ed25519) SSH public key; Windows requires a password between 12 and 123 characters satisfying complexity requirements.') : true
var subnetCheck = empty(subnetId) ? fail('VM subnetId cannot be empty when provisioning compute resources.') : true

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: (authCheck && subnetCheck) ? subnetId : subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: isLinux ? {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      } : {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: take(vmName, 15)
      adminUsername: adminUsername
      // Windows authentication uses only adminPassword; Linux password authentication is strictly disabled
      adminPassword: isWindows ? adminPassword : null
      linuxConfiguration: isLinux ? {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      } : null
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

@description('Resource ID of the created virtual machine.')
output vmId string = vm.id

@description('Name of the created virtual machine.')
output vmName string = vm.name

@description('Resource ID of the created network interface.')
output nicId string = nic.id
