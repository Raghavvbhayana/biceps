
using './main.bicep'

//===============================================================
// CONDITIONAL DEPLOYMENT FLAGS
//===============================================================
param deployRG bool = false
param deployVnet bool = false
param deployStorage bool = false
param deployDataFactory bool = false
param deployManagedIdentity bool = true
param deployAppServicePlans bool = false
param deployAppInsights bool = false
param deployAppServices bool = false
param deployKeyVault bool = true
param deploySqlManagedInstance bool = false
param deployMonitoring bool = false
param deployFunctionApps bool = false

// param resourceGroupName = 'RnD-RaghvRG'
// param location = 'eastus' 
/*
=============================================================================
   Resource Group Configuration
=============================================================================
- resourceGroupName:   Naming convention should include env + region.
- location:            Azure region where resources are deployed.
- rgTags:              Apply mandatory tags for cost tracking & compliance.
==============================================================================
*/
param resourceGroupName = ''    // Resource group name
param location = ''                  // Azure region for deployment
param rgTags = {
  Environment: ''        // Must always match deployment environment
  CreatedBY: ''     // Responsible team
  Client: ''     // Client name
}


/*
================================================================================
   Virtual Network Configuration - Children's Nebraska Production
================================================================================
- vnetName:             Production VNet name, must follow naming standards.
- vnetAddressPrefix:    CIDR block for VNet. Ensure no overlap with other VNets.
- subnetName:           Name of subnet where app services/databases will connect.
- subnetAddressPrefix:  CIDR for the subnet (subset of VNet range).
- nsgName:              Network Security Group name following naming convention.
- location:             Azure region for deployment.
- tags:                 Tags for ownership, billing, and compliance.
================================================================================
*/

// // Virtual Network Configuration
param vnetName = ''                    // VNet name for production
param vnetAddressPrefix = '10.20.0.0/16'                         // Primary CIDR block for VNet
param subnetName = ''               // Name of the subnet
param subnetAddressPrefix = '10.20.1.0/24'                       // Subnet CIDR (subset of VNet range)

// Network Security Group Configuration
param nsgName = ''                     // NSG name following conventions
// Security Rules for NSG
param securityRules = [ 

  {
    name: 'AllowHTTPS'
    properties: {
      description: 'Allow HTTPS traffic from internet for web applications'
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
  {
    name: 'AllowSSH'
    properties: {
      description: 'Allow SSH from management/jumpbox subnet for administrative access'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: '10.20.0.0/28'                        // Management subnet range
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 1030
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowRDPFromManagement'
    properties: {
      description: 'Allow RDP from management subnet for Windows servers'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: '10.20.0.0/28'                        //  subnet range
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 1040
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyDirectSSHFromInternet'
    properties: {
      description: 'Explicitly deny SSH from internet for security'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 2000
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyDirectRDPFromInternet'
    properties: {
      description: 'Explicitly deny RDP from internet for security'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 2010
      direction: 'Inbound'
    }
  }
  {
    name: 'DenyAllOtherInbound'
    properties: {
      description: 'Deny all other inbound traffic not explicitly allowed'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 4000
      direction: 'Inbound'
    }
  }
]
param vnetTags = {
  Environment: ''              // Must always match deployment environment
  CreatedBy: ''          // Responsible team member
  Client: ''           // Client name for billing/tracking
}


/*
==========================================================
   Storage Account Configuration
==========================================================
- storageAccountName:   Must be globally unique, lowercase only.
- storageSkuName:       Redundancy type. In prod, use GRS or ZRS.
- storageKind:          "StorageV2" recommended for modern workloads.
- accessTier:           Hot/Cold. "Hot" = frequently accessed data.
- minimumTlsVersion:    Enforces secure TLS for all connections.
- ipRules:              Allowed public IPs. Limit to corp ranges.
- inbound/outbound:     Containers used for ETL / file storage.
- storageTags:          Tags for tracking and governance.
==========================================================
*/
param storageAccountName = ''             // Must be globally unique, lowercase only
param storageSkuName = 'Standard_GRS'                   // Use GRS or ZRS in production for redundancy
param storageKind = 'StorageV2'                         // "StorageV2" is recommended for most scenarios      
param accessTier = 'Hot'                                // "Hot" for frequently accessed data
param minimumTlsVersion = 'TLS1_2'                      // Enforce secure TLS for all connections
param ipRules = [
  '203.0.113.15'                                        // Example: Corporate VPN
  '198.51.100.24'                                       // Example: On-prem firewall
]
param ContainerNames = [            // Container Names for inbound and outbound data
  'inbound-container'
  'outbound-container'
]
param storageTags = {
  Environment: ''        // Must always match deployment environment
  CreatedBY: ''     // Responsible team
  Client: ''     // Client name
}

/*
==========================================================
   Data Factory Configuration
==========================================================
- dataFactoryName:   Must be unique within region.
- dfTags:            Track usage, owner, project.
==========================================================
*/
param dataFactoryName = ''         // Data Factory name
param dfTags = {
  Environment: ''        // Must always match deployment environment
  CreatedBY: ''     // Responsible team
  Client: ''     // Client name
}

/*
==========================================================
   App Service Plans (Hosting Pools)
==========================================================
- Multiple plans defined: one Windows (dotnet) + one Linux (node).
- skuTier/skuName:     Controls performance & cost.
- capacity:            Number of worker instances (scalability).
- runtimeStack:        Only needed for Linux (e.g., NODE|18-lts).
- tags:                Add role, OS, language for clarity.
==========================================================
*/
param appServicePlans = [
  {
    name: ''        // Windows plan for .NET apps
    isLinux: false
    skuTier: 'PremiumV3'  // Use Premium in production
    skuName: 'P1v3'
    capacity: 1
    tags: {
      Environment: ''        // Must always match deployment environment
      CreatedBY: ''     // Responsible team
      Client: ''     // Client name
      os: 'Windows' 
      language: ''
    }
  }
  {
    name: ''     // Linux plan
    isLinux: true
    skuTier: 'PremiumV3'                 // Use Premium in production
    skuName: 'P2v3'
    capacity: 1
    tags: {
      Environment: ''        // Must always match deployment environment
      CreatedBY: ''     // Responsible team
      Client: ''     // Client name
      os: 'Linux'
      language: ''
    }
  }
]

/*
==========================================================
   Application Insights
==========================================================
- appInsightsName:  Must be globally unique.
- appType:          "web" for web apps.
- appInsightsTags:  Track resource for observability.
==========================================================
*/
param appInsightsName = ''  // Application Insights name, Must be globally unique
param appType = 'web'
param appInsightsTags = {
  Environment: ''        // Must always match deployment environment
  CreatedBY: ''     // Responsible team
  Client: ''     // Client name
}

/*
==========================================================
   App services
==========================================================
- webApps: Array of apps, each mapped to App Service Plans.
- os:      Windows/Linux (must match hosting plan type).
- siteConfig: Defines health check, runtime version, alwaysOn.
- appSettings: Key-value configs. DO NOT store secrets here.
==========================================================
*/

param webApps = [
  {
    name: ''    // App service name 1
    os: 'Windows'
    appServicePlanIndex: 0 // maps to Windows ASP above
    tags: {
      Environment: ''       // Must always match deployment environment
      client: ''    // Client name
      CreatedBY: ''  // Responsible team
    }
    siteConfig: {
      netFrameworkVersion: 'v6.0'
      alwaysOn: true
      healthCheckPath: '/health'
    }
    appSettings: [
      { name: 'ENVIRONMENT', value: 'Production' }
      { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
    ]
  }
  {
    name: ''  // App service name 2
    os: 'Linux'
    appServicePlanIndex: 1 // maps to Linux ASP above
    tags: {
      Environment: ''       // Must always match deployment environment
      client: ''    // Client name
      CreatedBY: '' // Responsible team
    }
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      healthCheckPath: '/api/health'
    }
    appSettings: [
      { name: 'ENVIRONMENT', value: 'Production' }
      { name: 'NODE_ENV', value: 'Production' }
    ]
  }
]
   param appServiceTags = {
    Environment: ''        // Must always match deployment environment
    CreatedBY: ''     // Responsible team
    Client: ''     // Client name
  }

/*
==========================================================
   Managed Identity
==========================================================
- identityName:   User-assigned managed identity name.
- identityTags:   Tags for traceability.
- Use:            Assign to Web Apps, ADF, SQLMI for secure KV access.
==========================================================
*/
param identityName = 'demo-mi'     // Managed Identity name
param identityTags = {
  Environment: 'demo'        // Must always match deployment environment
  CreatedBY: 'demo'     // Responsible team
  Client: 'demo'     // Client name
}

/*
==========================================================
   Key Vault
==========================================================
- keyVaultName:            Must follow org security standards.
- keyVaultTags:            Track project, owner, department.
==========================================================
*/
param keyVaultName = 'demo-kv' //  Key Vault name
param keyVaultTags = {
  Environment: 'demo'        // Must always match deployment environment
  CreatedBY: 'demo'     // Responsible team
  Client: 'demo'     // Client name
}
/*
==========================================================
   SQL Managed Instance
==========================================================
- managedInstanceName:     SQL MI instance name.
- managedInstanceProperties: Performance & configuration.
- sku:                     Defines edition, vCores, compute family.
- sqlAdminLogin:           Admin login (not SA).
- sqlAdminPassword:        Must be passed securely via pipeline/Key Vault.
- Networking:              Dedicated subnet for SQL MI.
==========================================================
*/
param managedInstanceName = '' // Name of SQL MI instance
param managedInstanceProperties = {                        // Performance & configuration
  licenseType: 'BasePrice'
  vCores: 4
  storageSizeInGB: 256
  collation: 'SQL_Latin1_General_CP1_CI_AS'
  timezoneId: 'UTC'
  proxyOverride: 'Proxy'
}
param sku = {                                               // SKU information
  name: 'GP_Gen5'
  tier: 'GeneralPurpose'
  family: 'Gen5'
  capacity: 4
}
param aadOnlyAuth = true
param entraIdAdminLogin = ''  // or group name
param entraIdAdminSid = ''  // Object ID
param entraIdAdminPrincipalType = 'User'  // or 'Group'
param sqlmiTags = {
  Environment: ''        // Must always match deployment environment
  CreatedBY: ''     // Responsible team
  Client: ''     // Client name
}

// Networking for SQL MI
param sqlmivnetName = '' // Vnet name of SQLMI
param sqlmivnetAddressPrefix = '10.30.0.0/16'
param sqlmisubnetName = 'ManagedInstance'           // Subnet name for SQLMI
param sqlMIRouteTableName = '' // Route Table name for SQLMI subnet
param sqlMInsgName = ''  // NSG name for SQLMI subnet
param sqlmisubnetAddressPrefix = '10.30.1.0/24'


// Default database created
param managedDatabases = [
  {
    name: 'ORBIS'  // Name of the database 1
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    tags: {
      Environment: ''         // Must always match deployment environment
      CreatedBY: ''     // Responsible team
      Client: ''            // Client name
    }
  }
  {
    name: 'PDP_Staging' // Name of the database 2
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    tags: {
      Environment: ''         // Must always match deployment environment
      CreatedBY: ''     // Responsible team
      Client: ''            // Client name
    }
  }
  {
    name: 'PeriopInsights' // Name of the database 3
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'DATABASE_DEFAULT'
    tags: {
      Environment: ''         // Must always match deployment environment
      CreatedBY: ''     // Responsible team
      Client: ''            // Client name
    }
  }
  {
    name: 'RevMaxReporting' // Name of the database 4
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    tags: {
      Environment: ''         // Must always match deployment environment
      CreatedBY: ''     // Responsible team
      Client: ''            // Client name
    }
  }
]
param sqlmiPublicDataEndpointEnabled = true
param sqlmiMinimalTlsVersion = '1.2'

param actionGroupName = '' // Action Group for SQL MI alerts
param actionGroupShortName = 'Compliance'   // Short name for notifications
param enableMonitoring = true                     
param dbaEmailAddress = '' // DBA email for alerts
param cpuAlertThreshold = 90
param storageAlertThreshold = 85





//=============================================================================
//   Function App Configuration
//=============================================================================

// @description('Function Apps configuration array')
param functionApps  = [
  {
    name: ''  // Function App name
    runtime: ''           // Runtime stack
    osType: 'Windows'            // OS type
    storageAccountName: '' // Associated storage account    
    tags: {
      Environment: ''
      CreatedBy: ''
      Client: ''
    }
  }
  {
    name: ''     // Function App name
    runtime: ''           // Runtime stack
    osType: 'Linux'           // OS type
    storageAccountName: '' // Associated storage account    
    tags: {
      Environment: ''
      CreatedBy: ''
      Client: ''
    }
  }
]
