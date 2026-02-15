// Parameters
param storageAccountName string
param location string
param tags object
param storageSkuName string
param storageKind string
param accessTier string
param minimumTlsVersion string
param ipRules array
param ContainerNames array = [] // Default to empty array

// Storage Account Resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: storageKind
  sku: {
    name: storageSkuName
  }
  properties: {
    isHnsEnabled: true
    accessTier: accessTier
    minimumTlsVersion: minimumTlsVersion
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: ipRules
    }
  }
}

// Child Resource: Blob Services
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// This loop runs 0 times for Dev and 1 time for Prod
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for name in ContainerNames: {
  parent: blobServices
  name: name
}]

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
