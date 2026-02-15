@description('Deployment location for the virtual network')
param location string

@description('Name of the virtual network')
param vnetName string

@description('Address prefix for the virtual network (e.g., 10.0.0.0/16)')
param vnetAddressPrefix string

@description('Name of the subnet')
param subnetName string

@description('Address prefix for the subnet (e.g., 10.0.1.0/24)')
param subnetAddressPrefix string

@description('Name of the Network Security Group')
param nsgName string

@description('Security rules for the NSG')
param securityRules array = []

@description('Tags to apply to the virtual network')
param tags object = {}

//=========================================================
// Network Security Group
//=========================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

//=========================================================
// Vnet
//=========================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
        }
      }
    ]
  }
}

//====================
// Outputs
//====================
output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
output nsgId string = nsg.id
output vnetName string = vnet.name
output subnetName string = vnet.properties.subnets[0].name
output nsgName string = nsg.name
