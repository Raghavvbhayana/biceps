// ====================================
// Action Group Module for Notifications
// ====================================

@description('Name for the action group')
param actionGroupName string

@description('Short name for the action group (max 12 characters)')
param actionGroupShortName string

@description('Tags for the action group')
param tags object = {}

@description('Email receivers configuration')
param emailReceivers array = [
  {
    name: 'DBA Team'
    emailAddress: 'dba-team@yourcompany.com'
    useCommonAlertSchema: true
  }
]

@description('Enable or disable the action group')
param enabled bool = true

// ====================================
// Action Group Resource
// ====================================
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: enabled
    emailReceivers: emailReceivers
  }
}

// ====================================
// Outputs
// ====================================
@description('Action Group Resource ID')
output actionGroupId string = actionGroup.id

@description('Action Group Resource Name')
output actionGroupName string = actionGroup.name
