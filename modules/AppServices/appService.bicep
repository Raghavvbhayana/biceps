param location string
param webAppName string
param appServicePlanName string
param appInsightsConnectionString string
param os string
param tags object 
@description('Resource ID of the user-assigned managed identity')
param identityResourceId string

@description('Custom App Settings for this Web App')
param appSettings array = []

@description('Custom siteConfig (runtime, stack, etc.) for this Web App')
param siteConfig object = {}

// Merge Application Insights settings with custom app settings
var allAppSettings = union(appSettings, [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~3'  // Updated to latest version
  }
])

resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: os == 'Linux' ? 'app,linux' : 'app'
  properties: {
    serverFarmId: resourceId('Microsoft.Web/serverfarms', appServicePlanName)
    httpsOnly: true  // Security best practice
    siteConfig: union(siteConfig, {
      minTlsVersion: '1.2'  // Security best practice
      ftpsState: 'Disabled'  // Security best practice
      appSettings: allAppSettings  // Use the merged app settings
    })
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
}
}

output webAppName string = appService.name
