@description('Name of the App Service Plan')
param appServicePlanName string

@description('Location for the App Service Plan')
param location string

@description('SKU tier for the App Service Plan')
@allowed(['Free', 'Shared', 'Basic', 'Standard', 'Premium', 'PremiumV2', 'PremiumV3'])
param skuTier string

@description('SKU name/size for the App Service Plan')
@allowed(['F1', 'D1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param skuName string

@description('Number of workers (instances) for the App Service Plan')
@minValue(1)
@maxValue(100)
param capacity int = 1

@description('Tags to apply to the App Service Plan')
param tags object 

@description('Set to true for Linux, false for Windows')
param isLinux bool = false

@description('Enable zone redundancy (requires Premium SKU)')
param zoneRedundant bool = false

@description('Enable per-site scaling')
param perSiteScaling bool = false

@description('Maximum elastic worker count')
param maximumElasticWorkerCount int = 1

//=========================================================
// Variables
//=========================================================
var isZoneRedundantSupported = contains(['Premium', 'PremiumV2', 'PremiumV3'], skuTier)
var actualZoneRedundant = zoneRedundant && isZoneRedundantSupported

//=========================================================
// Resource: App Service Plan
//=========================================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: union(tags, {
  })
  sku: {
    tier: skuTier
    name: skuName
    capacity: capacity
  }
  properties: {
    reserved: isLinux
    perSiteScaling: perSiteScaling
    maximumElasticWorkerCount: maximumElasticWorkerCount
    zoneRedundant: actualZoneRedundant
  }
  kind: isLinux ? 'linux' : 'app'
}

//=========================================================
// Outputs
//=========================================================
output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name
output appServicePlanLocation string = appServicePlan.location
output appServicePlanKind string = appServicePlan.kind
output skuInfo object = appServicePlan.sku
output isLinuxPlan bool = isLinux
