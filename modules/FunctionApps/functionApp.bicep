@description('Name of the Function App')
param functionAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The runtime stack for the Function App (dotnet, dotnet-isolated, node, python, java, powershell, custom)')
@allowed([
  'dotnet'
  'dotnet-isolated'
  'node'
  'python'
  'java'
  'powershell'
  'custom'
])
param runtime string

@description('Operating system for the Function App')
@allowed(['Windows', 'Linux'])
param osType string = 'Windows'

@description('App Service Plan Resource ID')
param appServicePlanId string

@description('Tags to apply to all resources')
param tags object = {}

// ==========================================================
// Deploy Storage Account (sub-module)
// ==========================================================
@description('Name of the Storage Account for this Function App')
param storageAccountName string

module storage './StorageAccount/storageAccount.bicep' = {
  name: '${functionAppName}-storage'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

// ==========================================================
// Deploy Application Insights (sub-module)
// ==========================================================
param appInsightsName string 
module appInsights './ApplicationInsights/applicationinsights.bicep' = {
  name: '${functionAppName}-ai'
  params: {
    appInsightsName: appInsightsName
    location: location
    tags: tags
  }
}

// ==========================================================
// Deploy Function App
// ==========================================================
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: osType == 'Linux' ? 'functionapp,linux' : 'functionapp'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
        {
          name: 'AzureWebJobsStorage'
          // Redundant dependsOn removed because of this reference
          value: storage.outputs.primaryConnectionString
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          // Modern apps prefer Connection String over Instrumentation Key
          value: appInsights.outputs.appInsightsConnectionString
        }
      ]
      // Linux runtime version mapping
      linuxFxVersion: osType == 'Linux' && runtime == 'node' ? 'Node|18' : null
    }
    httpsOnly: true
  }
  // REMOVED: explicit dependsOn [storage, appInsights] as it is redundant
}

// ==========================================================
// Outputs
// ==========================================================
output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output functionAppDefaultHostName string = functionApp.properties.defaultHostName
output storageAccountId string = storage.outputs.storageAccountId
// Note: Outputting secrets like connection strings triggers a linter warning.
// In production, consider retrieving this via Key Vault references.
output storageAccountConnectionString string = storage.outputs.primaryConnectionString
output appInsightsId string = appInsights.outputs.appInsightsId
