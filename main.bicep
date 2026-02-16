//**************************************************************
//  Deployment - Bicep Template (Production Environment)
//**************************************************************
targetScope = 'resourceGroup'

//===============================================================
// CONDITIONAL DEPLOYMENT FLAGS
//===============================================================
param deployRG bool = false
param deployVnet bool = false
param deployStorage bool = false
param deployDataFactory bool = false
param deployManagedIdentity bool = false
param deployAppServicePlans bool = false
param deployAppInsights bool = false
param deployAppServices bool = false
param deployKeyVault bool = true
param deploySqlManagedInstance bool = false
param deployMonitoring bool = false
param deployFunctionApps bool = false

// COMMON PARAMETERS
param resourceGroupName string
param location string
param rgTags object

// 1. RESOURCE GROUP
module rgModule './modules/ResourceGroup/resourceGroup.bicep' = if (deployRG) {
  name: 'rgDeployment'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    tags: rgTags
  }
}

// 2. VIRTUAL NETWORK
param vnetName string
param vnetAddressPrefix string
param subnetName string = 'default'
param subnetAddressPrefix string
param vnetTags object
param nsgName string
param securityRules array

module vnetModule './modules/Vnet/vNet.bicep' = if (deployVnet) {
  name: 'vnetDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    tags: vnetTags
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetName: subnetName
    subnetAddressPrefix: subnetAddressPrefix
    nsgName: nsgName
    securityRules: securityRules
  }
  dependsOn: [rgModule]
}

// 3. STORAGE ACCOUNT  
param storageAccountName string            
param storageSkuName string = 'Standard_LRS'
param storageKind string = 'StorageV2'
param accessTier string = 'Hot'
param minimumTlsVersion string = 'TLS1_2'
param ipRules array
param ContainerNames array
param storageTags object

module storageAccountModule './modules/StorageAccount/storageAccount.bicep' = if (deployStorage) {
  name: 'storageAccountDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    storageAccountName: storageAccountName      
    location: location
    tags: storageTags
    storageSkuName: storageSkuName
    storageKind: storageKind
    accessTier: accessTier
    minimumTlsVersion: minimumTlsVersion
    vnetId: deployVnet ? vnetModule.outputs.vnetId : ''
    subnetName: subnetName
    ipRules: ipRules
    ContainerNames: ContainerNames
  }
  dependsOn: [rgModule]
}

// 4. MANAGED IDENTITY
param identityName string
param identityTags object

module managedIdentityModule './modules/ManagedIdentity/managedIdentity.bicep' = if (deployManagedIdentity) {
  name: 'managedIdentityDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    identityName: identityName
    location: location
    tags: identityTags
  }
  # dependsOn: [rgModule]
}

// 5. DATA FACTORY
param dataFactoryName string
param dfTags object

module datafactory './modules/AzureDataFactory/azureDataFactory.bicep' = if (deployDataFactory) {
  name: 'datafactoryDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    dataFactoryName: dataFactoryName
    location: location
    tags: dfTags
  }
  dependsOn: [rgModule]
}

// 6. APP SERVICE PLANS
param appServicePlans array

module appServicePlanModules './modules/AppServicePlans/appServicePlan.bicep' = if (deployAppServicePlans) [for (plan, index) in appServicePlans: {
  name: 'appServicePlanDeployment-${index}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appServicePlanName: plan.name
    location: location
    skuTier: plan.skuTier
    skuName: plan.skuName
    capacity: plan.capacity
    tags: plan.tags
    isLinux: plan.isLinux
    zoneRedundant: plan.?zoneRedundant ?? false
    perSiteScaling: plan.?perSiteScaling ?? false
    maximumElasticWorkerCount: plan.?maximumElasticWorkerCount ?? 1
  }
  dependsOn: [rgModule]
}]

// 7. APP INSIGHTS
param appInsightsName string
param appType string = 'web'
param appInsightsTags object = {}

module appInsightsModule './modules/ApplicationInsights/applicationInsights.bicep' = if (deployAppInsights) {
  name: 'appInsightsDeploy'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    appInsightsName: appInsightsName
    appType: appType
    tags: appInsightsTags
  }
  dependsOn: [rgModule]
}

// 8. KEY VAULT
param keyVaultName string
param keyVaultTags object = {}

module keyVaultModule './modules/KeyVault/keyVault.bicep' = if (deployKeyVault) {
  name: 'keyVaultDeployment'
  scope: resourceGroup(RnD-RaghavRG)
  params: {
    location: centralus
    keyVaultName: keyVaultName
    tags: keyVaultTags
    objectId: deployManagedIdentity ? managedIdentityModule.outputs.principalId : subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    skuName: 'standard'
    enableRbacAuthorization: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  // dependsOn: [managedIdentityModule]
}

// 9. APP SERVICES
param appServiceTags object
param webApps array = [{}]  

module appServicesModule './modules/AppServices/appService.bicep' = if (deployAppServices) [for (webApp, i) in webApps: {
  name: '${webApp.name}-deploy'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    webAppName: webApp.name ?? 'defaultapp'
    appServicePlanName: deployAppServicePlans ? appServicePlanModules[webApp.appServicePlanIndex ?? 0].outputs.appServicePlanName : ''
    appInsightsConnectionString: deployAppInsights ? appInsightsModule.outputs.appInsightsConnectionString : ''
    tags: union(appServiceTags, webApp.tags ?? {})
    appSettings: webApp.appSettings ?? {}
    siteConfig: webApp.siteConfig ?? {}
    os: webApp.os ?? 'Windows'
    identityResourceId: deployManagedIdentity ? managedIdentityModule.outputs.resourceId : ''
  }
  dependsOn: [appServicePlanModules]
}]

// 10. SQL MANAGED INSTANCE
param managedInstanceName string
param managedInstanceProperties object
param sku object
param sqlmivnetName string
param sqlmivnetAddressPrefix string = '10.0.0.0/16'
param sqlmisubnetName string
param sqlmisubnetAddressPrefix string = '10.0.0.0/24'
param managedDatabases array = [{ name: 'defaultdb'; collation: 'SQL_Latin1_General_CP1_CI_AS'; tags: {} }]
param sqlmiTags object = {}
param sqlmiPublicDataEndpointEnabled bool = true
param aadOnlyAuth bool = true
@allowed(['1.0', '1.1', '1.2']) param sqlmiMinimalTlsVersion string = '1.2'
param entraIdAdminLogin string
param entraIdAdminSid string
@allowed(['User', 'Group', 'Application']) param entraIdAdminPrincipalType string = 'User'
param entraIdTenantId string = tenant().tenantId
param sqlMInsgName string
param sqlMIRouteTableName string

module sqlManagedInstanceModule './modules/ManagedSqlInstance/managedSqlInstance.bicep' = if (deploySqlManagedInstance) {
  name: 'sqlManagedInstanceDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [keyVaultModule]
  params: {
    location: location
    vnetName: sqlmivnetName
    vnetAddressPrefix: sqlmivnetAddressPrefix
    subnetName: sqlmisubnetName
    sqlMInsgName: sqlMInsgName
    sqlMIRouteTableName: sqlMIRouteTableName
    subnetAddressPrefix: sqlmisubnetAddressPrefix
    managedInstanceName: managedInstanceName
    tags: sqlmiTags
    identity: deployManagedIdentity ? { type: 'UserAssigned'; userAssignedIdentities: { '${managedIdentityModule.outputs.resourceId}': {} } } : { type: 'SystemAssigned' }
    primaryUserAssignedIdentityId: deployManagedIdentity ? managedIdentityModule.outputs.resourceId : ''
    managedInstanceProperties: managedInstanceProperties
    sku: sku
    managedDatabases: managedDatabases
    entraIdAdminLogin: entraIdAdminLogin
    entraIdAdminSid: entraIdAdminSid
    aadOnlyAuth: aadOnlyAuth
    entraIdAdminPrincipalType: entraIdAdminPrincipalType
    entraIdTenantId: entraIdTenantId
    publicDataEndpointEnabled: sqlmiPublicDataEndpointEnabled
    minimalTlsVersion: sqlmiMinimalTlsVersion
  }
}

// 11. MONITORING - ACTION GROUP
param actionGroupName string
param actionGroupShortName string
param enableMonitoring bool = true
param dbaEmailAddress string
param cpuAlertThreshold int = 90
param storageAlertThreshold int = 85

module actionGroupModule './modules/Monitoring/actionGroup.bicep' = if (deployMonitoring && enableMonitoring) {
  name: 'actionGroupDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    actionGroupName: actionGroupName
    actionGroupShortName: actionGroupShortName
    tags: sqlmiTags
    emailReceivers: [{ name: 'DBA Team'; emailAddress: dbaEmailAddress; useCommonAlertSchema: true }]
    enabled: true
  }
  dependsOn: [sqlManagedInstanceModule]
}

// 12. MONITORING - ALERT RULES
module sqlMiAlertRulesModule './modules/Monitoring/sqlMIAlertsRules.bicep' = if (deployMonitoring && enableMonitoring) {
  name: 'sqlMiAlertRulesDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [actionGroupModule]
  params: {
    sqlManagedInstanceId: deploySqlManagedInstance ? sqlManagedInstanceModule.outputs.managedInstanceId : ''
    managedInstanceName: managedInstanceName
    actionGroupId: deployMonitoring ? actionGroupModule.outputs.actionGroupId : ''
    enableAlertRules: enableMonitoring
    alertTags: sqlmiTags
    cpuThreshold: cpuAlertThreshold
    storageThreshold: storageAlertThreshold
  }
}

// 13. FUNCTION APPS
param functionApps array = [{}]

module functionAppModules './modules/FunctionApps/functionApp.bicep' = if (deployFunctionApps) [for (func, index) in functionApps: {
  name: 'functionAppDeployment-${index}'
  scope: resourceGroup(resourceGroupName)
  params: {
    storageAccountName: func.storageAccountName ?? storageAccountName
    functionAppName: func.name ?? 'defaultfunc'
    location: location
    appInsightsName: deployAppInsights ? appInsightsName : ''
    runtime: func.runtime ?? 'dotnet'
    osType: func.osType ?? 'Windows'
    appServicePlanId: deployAppServicePlans ? appServicePlanModules[index].outputs.appServicePlanId : ''
    tags: func.tags ?? {}
  }
  dependsOn: [appServicePlanModules]
}]
