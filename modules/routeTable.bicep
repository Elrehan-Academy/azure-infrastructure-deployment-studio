@description('Azure region for the route table resources.')
param location string = resourceGroup().location

@description('Name of the Route Table.')
@minLength(1)
@maxLength(80)
param routeTableName string

@description('Whether to disable BGP route propagation.')
param disableBgpRoutePropagation bool = false

@description('Tags to apply to the route table.')
param tags object = {}

@description('Route definition object type.')
type routeType = {
  @description('Name of the route.')
  name: string
  @description('Route properties.')
  properties: {
    @description('Destination CIDR address prefix.')
    addressPrefix: string
    @description('Next-hop type: VirtualAppliance, Internet, None, VirtualNetworkGateway, VnetLocal.')
    nextHopType: string
    @description('Next-hop IP address (required when nextHopType is VirtualAppliance).')
    nextHopIpAddress: string?
  }
}

@description('List of custom routes to add to the route table.')
param routes routeType[] = []

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: [
      for route in routes: {
        name: route.name
        properties: {
          addressPrefix: route.properties.addressPrefix
          nextHopType: route.properties.nextHopType
          nextHopIpAddress: (route.properties.nextHopType == 'VirtualAppliance') ? route.properties.?nextHopIpAddress : null
        }
      }
    ]
  }
}

@description('Resource ID of the created Route Table.')
output routeTableId string = routeTable.id

@description('Name of the created Route Table.')
output routeTableName string = routeTable.name
