@description('Name of the Application Insights resource')
param appInsightsName string

@description('Location for Application Insights')
param location string = resourceGroup().location

@description('Tags to apply to Application Insights')
param tags object = {}

@description('Application Insights kind (always "web" for Function Apps)')
param kind string = 'web'

@description('Application type (web, java, etc.)')
param applicationType string = 'web'

// ==========================================================
// Resource: Application Insights
// ==========================================================
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: kind
  properties: {
    Application_Type: applicationType
  }
  tags: tags
}

// ==========================================================
// Outputs
// ==========================================================
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey

// ADD THIS LINE TO FIX THE ERROR
output appInsightsConnectionString string = appInsights.properties.ConnectionString
