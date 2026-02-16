//**************************************************************
//  Deployment -  Bicep Template
//**************************************************************

// targetScope = 'resourceGroup'

//===============================================================
// CONDITIONAL DEPLOYMENT FLAGS
//===============================================================
param deployRG bool 
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

param resourceGroupName string = 'RnD-RaghavRG'    // Resource group name
param location string = 'eastus'                  // Azure region for deployment
// //====================
// // Resource Group Parameters
// //====================
// @description('Name of the resource group to create or use')
// param resourceGroupName string

// @description('Location for all resources')
// param location string = 'eastus'

// @description('Tags for Resource Group')
// param rgTags object

// //========================
// // Resource Group Module
// //=========================
// module rgModule 'modules/ResourceGroup/resourceGroup.bicep' = if (deployRG) {
//   name: 'rgDeployment'
//   params: {
//     resourceGroupName: resourceGroupName
//     location: location
//     tags: rgTags
//   }
// }

// //===========================
// // Virtual Network Parameters
// //===========================
@description('Name of the virtual network')
param vnetName string

@description('Address prefix for the virtual network')
param vnetAddressPrefix string

@description('Subnet name inside the virtual network')
param subnetName string = 'default'

@description('Address prefix for the subnet')
param subnetAddressPrefix string

@description('Tags for Virtual Network')
param vnetTags object

@description('NSG name following naming conventions')
param nsgName string      

@description('NSG security rules array')
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
  // dependsOn: [
  //   rgModule
  // ]
}

// //===============================
// // Storage Account Parameters
// //===============================
@description('Name of the storage account')
param storageAccountName string

@description('SKU for the storage account')
param storageSkuName string = 'Standard_LRS'

@description('Kind of storage account')
param storageKind string = 'StorageV2'

@description('Access tier for the storage account')
param accessTier string = 'Hot'

@description('Minimum TLS version')
param minimumTlsVersion string = 'TLS1_2'

@description('IP Rules for the storage account firewall')
param ipRules array

@description('Container names for inbound and outbound data')
param ContainerNames array

@description('Tags for Storage Account')
param storageTags object

// //========================
// // Storage Account Module
// //========================
module storageAccountModule 'modules/StorageAccount/storageAccount.bicep' = if (deployStorage && deployVnet) {
  name: 'storageAccountDeployment'
   
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: storageTags
    storageSkuName: storageSkuName
    storageKind: storageKind
    accessTier: accessTier
    minimumTlsVersion: minimumTlsVersion
    // vnetResourceId: deployVnet ? vnetModule.outputs.vnetId : null
    // subnetName: subnetName
    ipRules: ipRules
    ContainerNames: ContainerNames
  }
  // dependsOn: [
  //   rgModule
  // ]
}

// //=========================
// // Data Factory Parameters
// //========================
@description('Name of the Data Factory')
param dataFactoryName string

@description('Tags for Data Factory')
param dfTags object

//====================
// Data Factory Module
//====================
module datafactory 'modules/AzureDataFactory/azureDataFactory.bicep' = if (deployDataFactory) {
  name: 'datafactoryDeployment'
   
  params: {
    dataFactoryName: dataFactoryName
    location: location
    tags: dfTags
  }
  // dependsOn: [
  //   rgModule
  // ]
}
//==========================
// Deploy App service Plan
//==========================
@description('Array of App Service Plan configurations')
param appServicePlans array

module appServicePlanModules 'modules/AppServicePlans/appServicePlan.bicep' = if (deployAppServicePlans) [for (plan, index) in appServicePlans: {
  name: 'name'
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
  // dependsOn: [
  //   rgModule
  // ]
}]
// ============================
// Parameters App Insights Module
// ============================
@description('Name of the Application Insights instance')
param appInsightsName string

@description('Application type for Application Insights (e.g., web, other)')
param appType string = 'web'

@description('Tags to apply to resources')
param appInsightsTags object = {}

// ============================
// Deploy App Insights Module
// ============================
module appInsightsModule 'modules/ApplicationInsights/applicationInsights.bicep' = if (deployAppInsights) {
  name: 'appInsightsDeploy'
   
  params: {
    location: location
    appInsightsName: appInsightsName
    appType: appType
    tags: appInsightsTags
  }
  // dependsOn: [
  //   rgModule
  // ]
}

// //=================
// // Parameters for App Service
// //=================
@description('Tags to apply to shared resources')
param appServiceTags object

@description('Array of Web App configurations')
param webApps array

// ==================
// App Service Deploy
//===================
module appServicesModule 'modules/AppServices/appService.bicep' = if (deployAppServices && deployAppServicePlans) [for (webApp, i) in webApps: {
  name: '${webApp.name}-deploy'
   
  params: {
    location: location
    webAppName: webApp.name
    appServicePlanName: appServicePlanModules[webApp.appServicePlanIndex].outputs.appServicePlanName
    appInsightsConnectionString: deployAppInsights ? appInsightsModule.outputs.appInsightsConnectionString : null 
    tags: union(appServiceTags, webApp.tags)
    appSettings: webApp.appSettings
    siteConfig: webApp.siteConfig
    os: webApp.os
    identityResourceId: deployManagedIdentity ? managedIdentityModule.outputs.resourceId : null
  }
}]

// //===========================================
// // User Assigned Managed Identity Parameters
// //===========================================
@description('Name of the User Assigned Managed Identity')
param identityName string

@description('Tags to apply to the managed identity')
param identityTags object


// //=========================
// // Managed Identity Module
// //=========================
module managedIdentityModule 'modules/ManagedIdentity/managedIdentity.bicep' = if (deployManagedIdentity) {
  name: 'managedIdentityDeployment'
   
  params: {
    identityName: identityName
    location: location
    tags: identityTags
  }
  // dependsOn: [
  //   rgModule
  // ]
}



// // // ============================
// // // Parameters Key Vault Module
// // // ============================
@description('Name of the Key Vault')
param keyVaultName string

@description('Tags for Key Vault')
param keyVaultTags object = {}


// // // ============================
// // // Deploy Key Vault Module
// // // ============================
module keyVaultModule 'modules/KeyVault.bicep/keyVault.bicep' = if (deployKeyVault) {
  name: 'keyVaultDeployment'
   
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: keyVaultTags
    objectId: deployManagedIdentity ? managedIdentityModule.outputs.principalId : null
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
dependsOn: deployManagedIdentity ? [managedIdentityModule] : []
}
// // //====================================
// // // Parameters for SQL Managed Instance
// // // ==================================

@description('Name of the SQL Managed Instance')
param managedInstanceName string

@description('Properties for SQL Managed Instance')
param managedInstanceProperties object

@description('SKU configuration')
param sku object

@description('Name of the Virtual Network for SQL MI')
param sqlmivnetName string

@description('Address prefix for the Virtual Network')
param sqlmivnetAddressPrefix string = '10.0.0.0/16'

@description('Name of the subnet for SQL MI')
param sqlmisubnetName string

@description('Address prefix for the subnet')
param sqlmisubnetAddressPrefix string = '10.0.0.0/24'

@description('Array of database configurations to be created')
param managedDatabases array = [
  {
    name: 'defaultdb'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    tags: {}
  }
]

@description('Tags for SQL Managed Instance')
param sqlmiTags object = {}

@description('Enable public endpoint for SQL Managed Instance')
param sqlmiPublicDataEndpointEnabled bool = true

@description('Enable Azure AD-only authentication (disables SQL authentication)')
param aadOnlyAuth bool = true

@description('Minimum TLS version for SQL Managed Instance')
@allowed(['1.0', '1.1', '1.2'])
param sqlmiMinimalTlsVersion string = '1.2'

@description('Entra ID admin login name')
param entraIdAdminLogin string

@description('Entra ID admin object ID (User or Group)')
param entraIdAdminSid string

@description('Entra ID admin principal type')
@allowed(['User', 'Group', 'Application'])
param entraIdAdminPrincipalType string = 'User'

@description('Entra ID tenant ID')
param entraIdTenantId string = tenant().tenantId

@description('Name of NSG for SQL Managed Instance')
param sqlMInsgName string 

@description('Name of Route Table for SQL Managed Instance')
param sqlMIRouteTableName string


// // ====================================
// // Deploy SQL Managed Instance Module
// // ====================================

module sqlManagedInstanceModule 'modules/ManagedSqlInstance/managedSqlInstance.bicep' = if (deploySqlManagedInstance && deployManagedIdentity && deployKeyVault) {
  name: 'sqlManagedInstanceDeployment'
   
  dependsOn: [
    keyVaultModule
  ]
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

@description('Name of the Action Group')
param actionGroupName string

@description('Action Group Short Name')
param actionGroupShortName string

@description('Enable SQL MI monitoring and alerts')
param enableMonitoring bool = true

@description('Email address for DBA notifications')
param dbaEmailAddress string 


// // ====================================
// // Deploy Action Group Module
// // ====================================
module actionGroupModule 'modules/Monitoring/actionGroup.bicep' = if (deployMonitoring && deploySqlManagedInstance && deployManagedIdentity && deployKeyVault) {
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
  dependsOn: [
    sqlManagedInstanceModule
  ]
}

// // ====================================
// // Parameters for SQL MI Alert Rules Module
// // ====================================
  @description('CPU utilization alert threshold')
  param cpuAlertThreshold int = 90

  @description('Storage utilization alert threshold')
  param storageAlertThreshold int = 85


// // ====================================
// // Deploy SQL MI Alert Rules Module
// // ====================================

module sqlMiAlertRulesModule 'modules/Monitoring/sqlMIAlertsRules.bicep' = if (deployMonitoring && deploySqlManagedInstance && deployManagedIdentity && deployKeyVault) {
  name: 'sqlMiAlertRulesDeployment'
   
  dependsOn: [
    actionGroupModule
  ]
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



@description('Array of Function App configurations')
param functionApps array
// ==========================================
// Modules: Function Apps
// ==========================================
module functionAppModules 'modules/FunctionApps/functionApp.bicep' = if (deployFunctionApps && deployAppServicePlans) [for (func, index) in functionApps: {
  name: 'functionAppDeployment-${index}'
   
  params: {
    storageAccountName: func.storageAccountName
    functionAppName: func.name
    location: location
    appInsightsName: appInsightsName
    runtime: func.runtime
    osType: func.osType
    appServicePlanId: appServicePlanModules[index].outputs.appServicePlanId
    tags: func.tags
  }
  dependsOn: [
    appServicePlanModules
  ]
}]
