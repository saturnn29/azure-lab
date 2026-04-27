// 1. User-Assigned Managed Identity for Application Gateway
resource appGwIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'az104-06-appgw-identity'
  location: location
}

// 3. Key Vault to store the SSL Certificate
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
  }
}

// 4. Automation Account (with System-Assigned Managed Identity)
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: 'az104-06-automation'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

// 5. Role Assignments
// 5a. Automation Account -> Key Vault (Key Vault Certificates Officer)
resource kvRoleAutoAcc 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, automationAccount.id, 'kv-cert-officer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a4417e6f-fecd-4de8-b567-7b0420556985'
    )
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 5b. Application Gateway Identity -> Key Vault (Key Vault Secrets User)
resource kvRoleAppGw 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appGwIdentity.id, 'kv-secrets-user')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: appGwIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
