@description('Location for the Key Vault')
param location string = resourceGroup().location

@description('Name of the Key Vault')
param keyVaultName string

@description('Tags for the Key Vault')
param tags object

@description('Object ID of the user or service principal that will have access to Key Vault')
param objectId string

@description('Tenant ID for the Key Vault')
param tenantId string = subscription().tenantId

@description('SKU name for the Key Vault')
@allowed(['standard', 'premium'])
param skuName string = 'standard'

@description('Enable soft delete for the Key Vault')
param enableSoftDelete bool = true

@description('Soft delete retention days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization for Key Vault')
param enableRbacAuthorization bool = false

@description('Network access rules for Key Vault')
param networkAcls object = {
  defaultAction: 'Allow'
  bypass: 'AzureServices'
}

// ============================
// Create Key Vault
// ============================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: enableRbacAuthorization
    networkAcls: networkAcls
    accessPolicies: enableRbacAuthorization ? [] : [
      {
        objectId: objectId
        tenantId: tenantId
        permissions: {
          keys: ['get', 'list', 'create', 'update', 'decrypt', 'encrypt']
          secrets: ['get', 'list', 'set', 'delete', 'recover', 'backup', 'restore']
          certificates: ['get', 'list', 'create', 'update', 'delete', 'recover', 'backup', 'restore']
        }
      }
    ]
  }
}



// ============================
// Outputs
// ============================
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri

