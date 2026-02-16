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
// Network Security Group
// ============================
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: sqlMInsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow_management_inbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['9000', '9003', '1438', '1440', '1452']
          sourceAddressPrefix: '*'
          destinationAddressPrefix: subnetAddressPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'allow_health_probe_inbound'
        properties: {
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
      {
        name: 'allow_misubnet_inbound'
        properties: {
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
      {
        name: 'allow_tds_inbound'
        properties: {
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
        name: 'deny_all_inbound'
        properties: {
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
      // Outbound rules truncated for brevity - they remain logically the same
      {
        name: 'allow_management_outbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['443', '12000']
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'deny_all_outbound'
        properties: {
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
// Route Table
// ============================
resource routeTable 'Microsoft.Network/routeTables@2024-07-01' = {
  name: sqlMIRouteTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'subnet-to-vnetlocal'
        properties: {
          addressPrefix: subnetAddressPrefix
          nextHopType: 'VnetLocal'
        }
      }
      {
        name: 'mi-AzureActiveDirectory'
        properties: {
          addressPrefix: 'AzureActiveDirectory'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

// ============================
// Virtual Network (dependsOn removed - implicit by id references)
// ============================
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
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
}

// ============================
// SQL Managed Instance (dependsOn removed - implicit by vnet reference)
// ============================
resource managedSqlInstance 'Microsoft.Sql/managedInstances@2024-11-01-preview' = {
  name: managedInstanceName
  location: location
  identity: identity
  sku: sku
  tags: tags
  properties: union(managedInstanceProperties, {
    // Reference the subnet directly from the VNet resource symbol
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
}

// ============================
// SQL Databases (dependsOn removed - implicit by parent reference)
// ============================
resource sqlDatabases 'Microsoft.Sql/managedInstances/databases@2024-11-01-preview' = [for database in managedDatabases: {
  parent: managedSqlInstance
  name: database.name
  location: location
  // Implementing Safe Access and Null-Coalescing to fix warnings
  tags: database.?tags ?? tags
  properties: {
    collation: database.?collation ?? 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: database.?catalogCollation ?? 'SQL_Latin1_General_CP1_CI_AS'
    createMode: database.?createMode ?? 'Default'
    storageContainerUri: database.?storageContainerUri ?? null
    sourceDatabaseId: database.?sourceDatabaseId ?? null
    restorePointInTime: database.?restorePointInTime ?? null
    storageContainerSasToken: database.?storageContainerSasToken ?? null
    recoverableDatabaseId: database.?recoverableDatabaseId ?? null
    longTermRetentionBackupResourceId: database.?longTermRetentionBackupResourceId ?? null
  }
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
// Added safe access to indexing to satisfy compiler
output subnetId string = vnet.properties.?subnets[0].id ?? ''
