using './main.bicep'

// ===============================================================
// CONDITIONAL DEPLOYMENT FLAGS 
// ===============================================================
param deployVnet = false
param deployStorage = true
param deployDataFactory = false
param deployManagedIdentity = true 
param deployAppServicePlans = false
param deployAppInsights = false
param deployAppServices = false
param deployKeyVault = true
param deploySqlManagedInstance = false
param deployMonitoring = false
param deployFunctionApps = false

// ===============================================================
// RESOURCE GROUP & LOCATION
// ===============================================================
param resourceGroupName = 'RnD-RaghavRG'
param location = 'eastus'
param rgTags = {
  Environment: 'Production'
  CreatedBy: 'Prateek Agarwal'
  Client: 'CSTN'
}

// ===============================================================
// VIRTUAL NETWORK
// ===============================================================
param vnetName = 'vnet-cstn-prod-001'
param vnetAddressPrefix = '10.20.0.0/16'
param subnetName = 'snet-default'
param subnetAddressPrefix = '10.20.1.0/24'
param nsgName = 'nsg-cstn-prod-001'
param securityRules = [
  {
    name: 'AllowHTTPS'
    properties: {
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
param vnetTags = {
  Environment: 'Production'
}

// ===============================================================
// STORAGE ACCOUNT
// ===============================================================
param storageAccountName = 'stcstnprodadls001' 
param storageSkuName = 'Standard_GRS'
param storageKind = 'StorageV2'
param accessTier = 'Hot'
param minimumTlsVersion = 'TLS1_2'
param ipRules = []
param ContainerNames = [
  'inbound-container'
  'outbound-container'
]
param storageTags = {
  Environment: 'Production'
}

// ===============================================================
// DATA FACTORY & INSIGHTS
// ===============================================================
param dataFactoryName = 'adf-cstn-prod-001'
param dfTags = {
  Environment: 'Production'
}
param appInsightsName = 'appi-cstn-prod-001'
param appType = 'web'
param appInsightsTags = { 
  Environment: 'Production' 
}

// ===============================================================
// IDENTITY & SECURITY
// ===============================================================
param identityName = 'id-cstn-prod-msi'
param identityTags = {
  Environment: 'Production'
}
param keyVaultName = 'kv-cstn-prod-001'
param keyVaultTags = {
  Environment: 'Production'
}

// ===============================================================
// SQL MANAGED INSTANCE & MONITORING
// ===============================================================
param managedInstanceName = 'sqlmi-cstn-prod'
param managedInstanceProperties = {
  licenseType: 'BasePrice'
  vCores: 4
  storageSizeInGB: 256
}
param sku = {
  name: 'GP_Gen5'
  tier: 'GeneralPurpose'
  family: 'Gen5'
  capacity: 4
}
param sqlmivnetName = 'vnet-sql-mi'
param sqlmivnetAddressPrefix = '10.30.0.0/16'
param sqlmisubnetName = 'ManagedInstance'
param sqlmisubnetAddressPrefix = '10.30.1.0/24'
param sqlMIRouteTableName = 'rt-sql-mi'
param sqlMInsgName = 'nsg-sql-mi'

param entraIdAdminLogin = 'admin@cstn.org'
param entraIdAdminSid = '00000000-0000-0000-0000-000000000000'
param entraIdAdminPrincipalType = 'User'

param sqlmiTags = {
  Environment: 'Production'
}
param managedDatabases = []
param dbaEmailAddress = 'dba@cstn.org'
param actionGroupName = 'ag-sql-alerts'
param actionGroupShortName = 'sqlalert'

// ===============================================================
// COMPUTE ARRAYS (Now filled with empty defaults to prevent errors)
// ===============================================================
param appServicePlans = []
param webApps = []
param appServiceTags = {
  Environment: 'Production'
}
param functionApps = []
