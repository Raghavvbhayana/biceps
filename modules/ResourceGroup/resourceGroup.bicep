targetScope = 'subscription'
//=========================================================
// Parameters
//=========================================================
@description('Name of the resource group')
param resourceGroupName string

@description('Location for the resource group')
param location string
param tags object
//=========================================================
// Resource Group
//=========================================================
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags:tags
}
//====================
// Outputs
//====================
output rgName string = rg.name
output rgLocation string = rg.location
