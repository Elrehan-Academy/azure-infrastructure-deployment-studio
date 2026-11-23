using './main.bicep'

param createNewResourceGroup = true
param resourceGroupName = 'rg-elrehan-pilot-demo'
param location = 'westeurope'

param tags = {
  Environment: 'Pilot'
  Project: 'Elrehan Azure Deployment Wizard'
  ManagedBy: 'Bicep'
  Sprint: '1.2'
}

param vnetName = 'vnet-elrehan-pilot'
param addressPrefix = '10.0.0.0/16'

param subnets = [
  {
    name: 'snet-workload'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'snet-management'
    addressPrefix: '10.0.2.0/24'
  }
]

param deployVm = false
param osType = 'Linux'
param vmName = 'vm-elrehan-pilot-01'
param vmSize = 'Standard_D2s_v5'
param selectedSubnetName = 'snet-workload'
param adminUsername = 'azureuser'
param adminPassword = ''
param adminSshPublicKey = ''
