//**************************************************************
//  Deployment - Bicep Template
//**************************************************************

targetScope = 'resourceGroup' 

//===============================================================
// CONDITIONAL DEPLOYMENT FLAGS
//===============================================================
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

param location string = 'eastus'

// //===========================
// // Virtual Network Parameters
// //===========================
param vnetName string
param vnetAddressPrefix string
param subnetName string = 'default'
param subnetAddressPrefix string
param vnetTags object
param nsgName string      
param securityRules array                                        

// //========================
// // Virtual Network Module
// //========================
module vnetModule 'modules/Vnet/vNet.bicep' = if (deployVnet) {
  name: 'vnetDeployment'
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
}

// //===============================
// // Storage Account Parameters
// //===============================
param storageAccountName string
param storageSkuName string = 'Standard_LRS'
param storageKind string = 'StorageV2'
param accessTier string = 'Hot'
param minimumTlsVersion string = 'TLS_2'
param ipRules array
param ContainerNames array
param storageTags object

// //========================
// // Storage Account Module
// //========================
module storageAccountModule 'modules/StorageAccount/storageAccount.bicep' = if (deployStorage) {
  name: 'storageAccountDeployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: storageTags
    storageSkuName: storageSkuName
    storageKind: storageKind
    accessTier: accessTier
    minimumTlsVersion: minimumTlsVersion
    ipRules: ipRules
    ContainerNames: ContainerNames
  }
}

// //=========================
// // Data Factory Parameters
// //========================
param dataFactoryName string
param dfTags object

module datafactory 'modules/AzureDataFactory/azureDataFactory.bicep' = if (deployDataFactory) {
  name: 'datafactoryDeployment'
  params: {
    dataFactoryName: dataFactoryName
    location: location
    tags: dfTags
  }
}

//==========================
// Deploy App service Plan
//==========================
param appServicePlans array

module appServicePlanModules 'modules/AppServicePlans/appServicePlan.bicep' = [for (plan, index) in appServicePlans: if (deployAppServicePlans) {
  name: 'appServicePlanDeployment-${index}'
  params: {
    appServicePlanName: plan.name
    location: location
    skuTier: plan.skuTier
    skuName: plan.skuName
    capacity: plan.capacity
    tags: plan.tags
    isLinux: plan.isLinux
    zoneRedundant: contains(plan, 'zoneRedundant') ? plan.zoneRedundant : false
    perSiteScaling: contains(plan, 'perSiteScaling') ? plan.perSiteScaling : false
    maximumElasticWorkerCount: contains(plan, 'maximumElasticWorkerCount') ? plan.maximumElasticWorkerCount : 1
  }
}]

// ============================
// Parameters App Insights Module
// ============================
param appInsightsName string
param appType string = 'web'
param appInsightsTags object = {}

module appInsightsModule 'modules/ApplicationInsights/applicationInsights.bicep' = if (deployAppInsights) {
  name: 'appInsightsDeploy'
  params: {
    location: location
    appInsightsName: appInsightsName
    appType: appType
    tags: appInsightsTags
  }
}

// //=================
// // Parameters for App Service
// //=================
param appServiceTags object
param webApps array

module appServicesModule 'modules/AppServices/appService.bicep' = [for (webApp, i) in webApps: if (deployAppServices && deployAppServicePlans) {
  name: '${webApp.name}-deploy'
  params: {
    location: location
    webAppName: webApp.name
    // Accessing the output of the specific plan index defined in the webApp object
    appServicePlanName: appServicePlanModules[webApp.appServicePlanIndex].outputs.appServicePlanName
    appInsightsConnectionString: deployAppInsights ? appInsightsModule.outputs.appInsightsConnectionString : '' 
    tags: union(appServiceTags, webApp.tags)
    appSettings: webApp.appSettings
    siteConfig: webApp.siteConfig
    os: webApp.os
    identityResourceId: deployManagedIdentity ? managedIdentityModule.outputs.resourceId : ''
  }
}]

// //===========================================
// // User Assigned Managed Identity Parameters
// //===========================================
param identityName string
param identityTags object

module managedIdentityModule 'modules/ManagedIdentity/managedIdentity.bicep' = if (deployManagedIdentity) {
  name: 'managedIdentityDeployment'
  params: {
    identityName: identityName
    location: location
    tags: identityTags
  }
}

// // // ============================
// // // Parameters Key Vault Module
// // // ============================
param keyVaultName string
param keyVaultTags object = {}

module keyVaultModule 'modules/KeyVault.bicep/keyVault.bicep' = if (deployKeyVault) {
  name: 'keyVaultDeployment'
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: keyVaultTags
    objectId: deployManagedIdentity ? managedIdentityModule.outputs.principalId : ''
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
}

// // //====================================
// // // Parameters for SQL Managed Instance
// // // ==================================
param managedInstanceName string
param managedInstanceProperties object
param sku object
param sqlmivnetName string
param sqlmivnetAddressPrefix string = '10.0.0.0/16'
param sqlmisubnetName string
param sqlmisubnetAddressPrefix string = '10.0.0.0/24'
param managedDatabases array = []
param sqlmiTags object = {}
param sqlmiPublicDataEndpointEnabled bool = true
param aadOnlyAuth bool = true
param sqlmiMinimalTlsVersion string = '1.2'
param entraIdAdminLogin string
param entraIdAdminSid string
param entraIdAdminPrincipalType string = 'User'
param entraIdTenantId string = tenant().tenantId
param sqlMInsgName string 
param sqlMIRouteTableName string

module sqlManagedInstanceModule 'modules/ManagedSqlInstance/managedSqlInstance.bicep' = if (deploySqlManagedInstance && deployManagedIdentity && deployKeyVault) {
  name: 'sqlManagedInstanceDeployment'
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
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${managedIdentityModule.outputs.resourceId}': {}
      }
    }
    primaryUserAssignedIdentityId: managedIdentityModule.outputs.resourceId
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

// // ====================================
// // Parameters for Action Group Module
// // ====================================
param actionGroupName string
param actionGroupShortName string
param enableMonitoring bool = true
param dbaEmailAddress string 

module actionGroupModule 'modules/Monitoring/actionGroup.bicep' = if (deployMonitoring && deploySqlManagedInstance) {
  name: 'actionGroupDeployment'
  params: {
    actionGroupName: actionGroupName
    actionGroupShortName: actionGroupShortName
    tags: sqlmiTags
    emailReceivers: [
      {
        name: 'DBA Team'
        emailAddress: dbaEmailAddress
        useCommonAlertSchema: true
      }
    ]
    enabled: true
  }
}

// // ====================================
// // Deploy SQL MI Alert Rules Module
// // ====================================
param cpuAlertThreshold int = 90
param storageAlertThreshold int = 85

module sqlMiAlertRulesModule 'modules/Monitoring/sqlMIAlertsRules.bicep' = if (deployMonitoring && deploySqlManagedInstance) {
  name: 'sqlMiAlertRulesDeployment'
  params: {
    sqlManagedInstanceId: sqlManagedInstanceModule.outputs.managedInstanceId
    managedInstanceName: managedInstanceName
    actionGroupId: actionGroupModule.outputs.actionGroupId
    enableAlertRules: enableMonitoring
    alertTags: sqlmiTags
    cpuThreshold: cpuAlertThreshold
    storageThreshold: storageAlertThreshold
  }
}

// ==========================================
// Modules: Function Apps
// ==========================================
param functionApps array

module functionAppModules 'modules/FunctionApps/functionApp.bicep' = [for (func, index) in functionApps: if (deployFunctionApps && deployAppServicePlans) {
  name: 'functionAppDeployment-${index}'
  params: {
    storageAccountName: func.storageAccountName
    functionAppName: func.name
    location: location
    appInsightsName: appInsightsName
    runtime: func.runtime
    osType: func.osType
    // Links to the Plan at the same index in the loop
    appServicePlanId: appServicePlanModules[index].outputs.appServicePlanId
    tags: func.tags
  }
}]
