using './main.bicep'

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

// GLOBAL TAGS
param environmentTag string = 'Production'
param CreatedByTag string = 'Prateek Agarwal'
param clientTag string = 'CSTN'

// RESOURCE GROUP
param resourceGroupName string = 'rg-cstn-prod'
param location string = 'centralus'
param rgTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// VNET
param vnetName string = 'name of vnet'
param vnetAddressPrefix string = '10.20.0.0/16'
param subnetName string = 'default'
param subnetAddressPrefix string = '10.20.1.0/24'
param nsgName string = 'name of nsg'
param securityRules array = [
  {
    name: 'AllowHTTPS'
    properties: {
      description: 'Allow HTTPS traffic'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 1000
      direction: 'Inbound'
    }
  }
]
param vnetTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// STORAGE 
param storageAccountName string = 'name'        
param storageSkuName string = 'Standard_GRS'
param storageKind string = 'StorageV2'
param accessTier string = 'Hot'
param minimumTlsVersion string = 'TLS1_2'
param ipRules array = ['203.0.113.15', '198.51.100.24']
param ContainerNames array = ['inbound-container', 'outbound-container']
param storageTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// DATA FACTORY
param dataFactoryName string = 'name of data factory'
param dfTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// MANAGED IDENTITY
param identityName string = 'name of mi'
param identityTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// APP SERVICE PLANS
param appServicePlans array = [
  {
    name: 'name of app service plan'
    isLinux: false
    skuTier: 'PremiumV3'
    skuName: 'P1v3'
    capacity: 1
    tags: {
      Environment: environmentTag
      'Created By': createdByTag
      Client: clientTag
    }
  }
]

// APP INSIGHTS
param appInsightsName string = 'name of app insights'
param appType string = 'web'
param appInsightsTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// APP SERVICES
param appServiceTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}
param webApps array = [
  {
    name: 'name of web app'
    appServicePlanIndex: 0
    os: 'Windows'
  }
]

// KEY VAULT
param keyVaultName string = 'kv-cstn-prod'
param keyVaultTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}

// SQL MANAGED INSTANCE
param managedInstanceName string = 'name of sql mi'
param managedInstanceProperties object = { storageSizeInGB: 128 }
param sku object = { name: 'GP_Gen5'; tier: 'GeneralPurpose' }
param sqlmivnetName string = ' name of vnet for sql mi'
param sqlmivnetAddressPrefix string = '10.30.0.0/16'
param sqlmisubnetName string = 'name of subnet for sql mi'
param sqlmisubnetAddressPrefix string = '10.30.1.0/24'
param sqlmiTags object = {
  Environment: environmentTag
  'Created By': createdByTag
  Client: clientTag
}
param sqlmiPublicDataEndpointEnabled bool = false
param aadOnlyAuth bool = true
param sqlmiMinimalTlsVersion string = '1.2'
param entraIdAdminLogin string = 'admin@yourtenant.onmicrosoft.com'
param entraIdAdminSid string = '00000000-0000-0000-0000-000000000000'
param entraIdAdminPrincipalType string = 'User'
param entraIdTenantId string = tenant().tenantId
param sqlMInsgName string = 'name of sql mi admin'
param sqlMIRouteTableName string = 'name of route table for sql mi'

// MONITORING
param actionGroupName string = 'name of action group'
param actionGroupShortName string = 'name of action group short name'
param enableMonitoring bool = true
param dbaEmailAddress string = 'dba@company.com'
param cpuAlertThreshold int = 90
param storageAlertThreshold int = 85

// FUNCTION APPS
param functionApps array = [
  {
    name: 'name of function app'
    storageAccountName: storageAccountName
    runtime: 'dotnet'
    osType: 'Windows'
  }
]
