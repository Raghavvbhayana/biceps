//=========================================================
// Parameters
//=========================================================
@description('Name of the User Assigned Managed Identity')
param identityName string

@description('Location where the Managed Identity will be deployed')
param location string

@description('Tags to apply to the Managed Identity')
param tags object

//=========================================================
//  Identities
//=========================================================
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

//====================
// Outputs
//====================
@description('The principal ID of the managed identity')
output principalId string = userAssignedIdentity.properties.principalId

@description('The client ID of the managed identity')
output clientId string = userAssignedIdentity.properties.clientId

@description('The resource ID of the managed identity')
output resourceId string = userAssignedIdentity.id
