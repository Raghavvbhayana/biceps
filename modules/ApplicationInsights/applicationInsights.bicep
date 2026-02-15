@description('Location for resources')
param location string

@description('Name of the Application Insights resource')
param appInsightsName string

@description('Application Type (e.g., web, other)')
param appType string

@description('Tags to apply to the resource')
param tags object = {}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: appType
  tags: tags
  properties: {
    Application_Type: appType
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

output appInsightsId string = appInsights.id
@secure()
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
