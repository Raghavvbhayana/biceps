@description('Location for all resources')
param location string 

@description('Name of the Virtual Network')
param vnetName string

@description('Address prefix for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Name of the subnet for SQL Managed Instance')
param subnetName string

@description('Subnet address prefix for SQL Managed Instance')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('Name of the SQL Managed Instance')
param managedInstanceName string

@description('Tags for SQL Managed Instance')
param tags object

@description('Identity configuration for SQL Managed Instance')
param identity object 

@description('Properties for SQL Managed Instance')
param managedInstanceProperties object

@description('SKU configuration for SQL Managed Instance')
param sku object 

@description('Array of database configurations to be created')
param managedDatabases array = [
  {
    name: 'defaultdb'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    tags: {}
  }
]

@description('Entra ID admin login name')
param entraIdAdminLogin string

@description('Entra ID admin object ID (User or Group)')
param entraIdAdminSid string

@description('Enable Azure AD-only authentication (disables SQL authentication)')
param aadOnlyAuth bool = true

@description('Entra ID admin principal type')
@allowed(['User', 'Group', 'Application'])
param entraIdAdminPrincipalType string = 'User'

@description('Entra ID tenant ID')
param entraIdTenantId string = tenant().tenantId

@description('Enable public endpoint for SQL Managed Instance')
param publicDataEndpointEnabled bool = true

@description('Minimum TLS version for SQL Managed Instance')
@allowed(['1.0', '1.1', '1.2'])
param minimalTlsVersion string = '1.2'

@description('Primary User Assigned Identity Resource ID')
param primaryUserAssignedIdentityId string = ''

@description('Name of NSG for SQL Managed Instance')
param sqlMInsgName string 

@description('Name of Route Table for SQL Managed Instance')
param sqlMIRouteTableName string

// ============================
// Create Network Security Group with ALL Required Rules
// ============================
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: sqlMInsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // REQUIRED: Management inbound rules
      {
        name: 'allow_management_inbound'
        properties: {
          description: 'Allow management traffic inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '9000'
            '9003'
            '1438'
            '1440'
            '1452'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      // REQUIRED: Health probe inbound
      {
        name: 'allow_health_probe_inbound'
        properties: {
          description: 'Allow health probe traffic from Azure Load Balancer'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      // REQUIRED: Internal subnet communication
      {
        name: 'allow_misubnet_inbound'
        properties: {
          description: 'Allow MI subnet internal traffic inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      // SQL connectivity rules
      {
        name: 'allow_tds_inbound'
        properties: {
          description: 'Allow access to data'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'allow_tds_inbound_public'
        properties: {
          description: 'Allow public access to data (public endpoint)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3342'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
      {
        name: 'allow_redirect_inbound'
        properties: {
          description: 'Allow inbound redirect traffic to Managed Instance inside the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '11000-11999'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
        }
      }
      {
        name: 'allow_geodr_inbound'
        properties: {
          description: 'Allow inbound geo-dr traffic inside the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5022'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 1200
          direction: 'Inbound'
        }
      }
      // Deny all other inbound (REQUIRED to be at lower priority)
      {
        name: 'deny_all_inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      
      // OUTBOUND RULES - ALL REQUIRED
      // Management outbound
      {
        name: 'allow_management_outbound'
        properties: {
          description: 'Allow management traffic outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '12000'
          ]
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      // Internal subnet communication outbound
      {
        name: 'allow_misubnet_outbound'
        properties: {
          description: 'Allow MI subnet internal traffic outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
        }
      }
      // REQUIRED: Azure Active Directory
      {
        name: 'allow_aad_outbound'
        properties: {
          description: 'Allow Azure Active Directory outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 300
          direction: 'Outbound'
        }
      }
      // REQUIRED: OneDsCollector (Telemetry)
      {
        name: 'allow_oneds_outbound'
        properties: {
          description: 'Allow OneDsCollector outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'OneDsCollector'
          access: 'Allow'
          priority: 400
          direction: 'Outbound'
        }
      }
      // REQUIRED: Storage services - Central US
      {
        name: 'allow_storage_centralus_outbound'
        properties: {
          description: 'Allow Storage Central US outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'Storage.centralus'
          access: 'Allow'
          priority: 500
          direction: 'Outbound'
        }
      }
      // REQUIRED: Storage services - East US 2
      {
        name: 'allow_storage_eastus2_outbound'
        properties: {
          description: 'Allow Storage East US 2 outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'Storage.eastus2'
          access: 'Allow'
          priority: 600
          direction: 'Outbound'
        }
      }
      // SQL connectivity outbound rules
      {
        name: 'allow_linkedserver_outbound'
        properties: {
          description: 'Allow outbound linked server traffic inside the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
      {
        name: 'allow_redirect_outbound'
        properties: {
          description: 'Allow outbound redirect traffic to Managed Instance inside the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '11000-11999'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1100
          direction: 'Outbound'
        }
      }
      {
        name: 'allow_geodr_outbound'
        properties: {
          description: 'Allow outbound geo-dr traffic inside the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5022'
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1200
          direction: 'Outbound'
        }
      }
      // Deny all other outbound (REQUIRED to be at lower priority)
      {
        name: 'deny_all_outbound'
        properties: {
          description: 'Deny all other outbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Outbound'
        }
      }
    ]
  }
}

// ============================
// Create Route Table with ALL Required Routes
// ============================
resource routeTable 'Microsoft.Network/routeTables@2024-07-01' = {
  name: sqlMIRouteTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      // REQUIRED: Exact subnet route
      {
        name: 'subnet-${replace(subnetAddressPrefix, '/', '-')}-to-vnetlocal'
        properties: {
          addressPrefix: subnetAddressPrefix
          nextHopType: 'VnetLocal'
        }
      }
      // REQUIRED: Azure Active Directory
      {
        name: 'mi-AzureActiveDirectory'
        properties: {
          addressPrefix: 'AzureActiveDirectory'
          nextHopType: 'Internet'
        }
      }
      // REQUIRED: OneDsCollector
      {
        name: 'mi-OneDsCollector'
        properties: {
          addressPrefix: 'OneDsCollector'
          nextHopType: 'Internet'
        }
      }
      // REQUIRED: Storage Central US
      {
        name: 'mi-Storage.centralus'
        properties: {
          addressPrefix: 'Storage.centralus'
          nextHopType: 'Internet'
        }
      }
      // REQUIRED: Storage East US 2
      {
        name: 'mi-Storage.eastus2'
        properties: {
          addressPrefix: 'Storage.eastus2'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

// ============================
// Create Virtual Network
// ============================
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
          }
          delegations: [
            {
              name: 'managedinstancedelegation'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    nsg
    routeTable
  ]
}

// ============================
// Create SQL Managed Instance
// ============================
resource managedSqlInstance 'Microsoft.Sql/managedInstances@2024-11-01-preview' = {
  name: managedInstanceName
  location: location
  identity: identity
  sku: sku
  tags: tags
  properties: union(managedInstanceProperties, {
    subnetId: vnet.properties.subnets[0].id
    administrators: {
      login: entraIdAdminLogin
      sid: entraIdAdminSid
      tenantId: entraIdTenantId
      principalType: entraIdAdminPrincipalType
      azureADOnlyAuthentication: aadOnlyAuth
    }
    publicDataEndpointEnabled: publicDataEndpointEnabled
    restrictOutboundNetworkAccess: 'Disabled'
    minimalTlsVersion: minimalTlsVersion
    primaryUserAssignedIdentityId: !empty(primaryUserAssignedIdentityId) ? primaryUserAssignedIdentityId : null
  })
  dependsOn: [
    vnet
  ]
}

// ============================
// Create SQL Database in Managed Instance
// ============================
resource sqlDatabases 'Microsoft.Sql/managedInstances/databases@2024-11-01-preview' = [for database in managedDatabases: {
  parent: managedSqlInstance
  name: database.name
  location: location
  tags: contains(database, 'tags') ? database.tags : tags
  properties: {
    collation: contains(database, 'collation') ? database.collation : 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: contains(database, 'catalogCollation') ? database.catalogCollation : 'SQL_Latin1_General_CP1_CI_AS'
    createMode: contains(database, 'createMode') ? database.createMode : 'Default'
    storageContainerUri: contains(database, 'storageContainerUri') ? database.storageContainerUri : null
    sourceDatabaseId: contains(database, 'sourceDatabaseId') ? database.sourceDatabaseId : null
    restorePointInTime: contains(database, 'restorePointInTime') ? database.restorePointInTime : null
    storageContainerSasToken: contains(database, 'storageContainerSasToken') ? database.storageContainerSasToken : null
    recoverableDatabaseId: contains(database, 'recoverableDatabaseId') ? database.recoverableDatabaseId : null
    longTermRetentionBackupResourceId: contains(database, 'longTermRetentionBackupResourceId') ? database.longTermRetentionBackupResourceId : null
  }
  dependsOn: [
    managedSqlInstance
  ]
}]

// ============================
// Outputs
// ============================
output managedInstanceFqdn string = managedSqlInstance.properties.fullyQualifiedDomainName
output managedInstanceId string = managedSqlInstance.id
output databaseIds array = [for (database, i) in managedDatabases: {
  name: database.name
  id: sqlDatabases[i].id
}]
output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
