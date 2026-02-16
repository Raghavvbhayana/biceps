@description('Name of the Storage Account. Must be globally unique.')
param storageAccountName string

@description('Location for the Storage Account.')
param location string = resourceGroup().location

@description('Storage account SKU')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
])
param sku string = 'Standard_LRS'

@description('Storage account kind')
@allowed([
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
param kind string = 'StorageV2'

@description('Enable hierarchical namespace (for Data Lake Storage Gen2)')
param enableHierarchicalNamespace bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    isHnsEnabled: enableHierarchicalNamespace
  }
}

// ==========================================================
// Outputs
// ==========================================================

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name

@description('The primary connection string for the storage account')
@secure()
// FIXED: Using the resource symbol .listKeys() instead of the listKeys() function
output primaryConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
