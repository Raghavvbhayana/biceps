
//=========================================================
// Parameters
//=========================================================
@description('Name of the Azure Data Factory')
param dataFactoryName string

@description('Location where the Data Factory will be deployed')
param location string

@description('Tags to apply to the Data Factory')
param tags object = {}

//=========================================================
// Azure Data Factory Resource
//=========================================================
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
}

//=========================================================
// Outputs
//=========================================================
output dataFactoryId string = dataFactory.id
output dataFactoryNameOut string = dataFactory.name
