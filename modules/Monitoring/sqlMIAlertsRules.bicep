// ====================================
// SQL Managed Instance Alert Rules Module
// ====================================

@description('SQL Managed Instance resource ID')
param sqlManagedInstanceId string

@description('SQL Managed Instance name (for naming alerts)')
param managedInstanceName string

@description('Action Group resource ID for notifications')
param actionGroupId string

@description('Enable alert rules')
param enableAlertRules bool = true

@description('Tags for alert rules')
param alertTags object = {}

@description('CPU utilization threshold percentage')
param cpuThreshold int = 90

@description('Storage utilization threshold percentage') 
param storageThreshold int = 85


// ====================================
// CPU Utilization Alert
// ====================================
resource cpuUtilizationAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableAlertRules) {
  name: 'ar-cpu-${managedInstanceName}'
  location: 'global'
  tags: alertTags
  properties: {
    description: 'Alert when CPU utilization exceeds ${cpuThreshold}%'
    severity: 3
    enabled: true
    scopes: [
      sqlManagedInstanceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'CPU percentage'
          metricName: 'avg_cpu_percent'
          metricNamespace: 'Microsoft.Sql/managedInstances'
          operator: 'GreaterThan'
          threshold: cpuThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

// ====================================
// Storage Utilization Alert
// ====================================
resource storageUtilizationAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableAlertRules) {
  name: 'ar-StorageSpace-${managedInstanceName}'
  location: 'global'
  tags: alertTags
  properties: {
    description: 'Alert when storage utilization exceeds ${storageThreshold}%'
    severity: 3
    enabled: true
    scopes: [
      sqlManagedInstanceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Storage space used percentage'
          metricName: 'storage_space_used_mb'
          metricNamespace: 'Microsoft.Sql/managedInstances'
          operator: 'GreaterThan'
          threshold: storageThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}


// ====================================
// IO Requests Alert
// ====================================
resource ioRequestsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableAlertRules) {
  name: 'ar-IO-${managedInstanceName}'
  location: 'global'
  tags: alertTags
  properties: {
    description: 'Alert when IO requests are Higher than Average'
    severity: 3
    enabled: true
    scopes: [
      sqlManagedInstanceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'IO Requests'
          metricName: 'io_requests'
          metricNamespace: 'Microsoft.Sql/managedInstances'
          operator: 'GreaterThan'  // Changed from 'GreaterOrLessThan'
          alertSensitivity: 'Low'
          failingPeriods: {
            numberOfEvaluationPeriods: 4
            minFailingPeriodsToAlert: 4
          }
          timeAggregation: 'Average'
          criterionType: 'DynamicThresholdCriterion'
          // Note: threshold is not needed for dynamic thresholds
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

// ====================================
// Outputs
// ====================================
@description('Alert rule resource IDs')
output alertRuleIds object = {
  cpuUtilization: enableAlertRules ? cpuUtilizationAlert.id : ''
  storageUtilization: enableAlertRules ? storageUtilizationAlert.id : ''
  ioRequests: enableAlertRules ? ioRequestsAlert.id : ''
}

@description('Alert rule names')
output alertRuleNames array = enableAlertRules ? [
  cpuUtilizationAlert.name
  storageUtilizationAlert.name
  ioRequestsAlert.name
] : []
